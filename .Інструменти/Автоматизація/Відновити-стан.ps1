# Автор: Ruslan_A7 (RA7). Розробник: RA7 з Codex (GPT-6), OpenAI.
# Створено з використанням AILang. RA7 Open Free License: https://ra7.iuid.cc/LICENSE. Версія 0.6.0.
param([switch]$ReadLimits,[switch]$UpdateName)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Сховище.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Сеанс.psm1') -Force
$report=Repair-AILangHistory
$settings=Read-AILangPreferences
if (!$settings.session) {
    foreach ($entry in @(Read-AILangHistory | Sort-Object utc -Descending)) {
        $candidate=[guid]::Empty
        if ([guid]::TryParse($entry.session,[ref]$candidate) -and $candidate -ne [guid]::Empty) { $settings.session=$candidate.ToString(); $settings.name=''; break }
    }
}
try { $settings.codexExecutable=Resolve-AILangCodex } catch {}
Save-AILangPreferences -Session $settings.session -Name $settings.name -CodexExecutable $settings.codexExecutable
$quota=$null
$nameAvailable=[bool]$settings.name
if ($UpdateName -and $settings.session) {
    $metadata=& (Join-Path $PSScriptRoot 'Адаптери/Назва-Codex.ps1') -SessionId $settings.session
    if ($metadata.status -eq 'known' -and $metadata.name) {
        $settings.name=$metadata.name
        $nameAvailable=$true
        Save-AILangPreferences -Session $settings.session -Name $settings.name -CodexExecutable $settings.codexExecutable
    }
}
if ($ReadLimits) {
    $job=Start-Job -ScriptBlock {param($adapter) $ErrorActionPreference='Stop'; & $adapter} -ArgumentList (Join-Path $PSScriptRoot 'Адаптери/Ліміти-Codex.ps1')
    try {
        $null=Wait-Job -Job $job -Timeout 35
        if ($job.State -ne 'Completed') { throw 'Фонове читання не завершилося' }
        $quota=Receive-Job -Job $job -ErrorAction Stop | Select-Object -Last 1
    } finally { if ($job.State -eq 'Running') { Stop-Job -Job $job }; Remove-Job -Job $job }
}
[pscustomobject]@{recovered=$report.recovered;sent=$report.sent;unrecoverable=$report.unrecoverable;backupCreated=$report.normalized;sessionSaved=[bool]$settings.session;cliLocated=[bool]$settings.codexExecutable;nameAvailable=$nameAvailable;quota=$quota} | ConvertTo-Json -Depth 7
