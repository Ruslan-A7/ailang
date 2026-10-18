# Автор: Ruslan_A7 (RA7). Розробник: RA7 з Codex (GPT-6), OpenAI.
# Створено з використанням AILang. RA7 Open Free License: https://ra7.iuid.cc/LICENSE. Версія 0.4.0.
Import-Module (Join-Path $PSScriptRoot 'Сховище.psm1')
function Add-AILangDecision {
    param(
        [Parameter(Mandatory=$true)][string]$RequestId,
        [Parameter(Mandatory=$true)][guid]$SessionId,
        [Parameter(Mandatory=$true)][ValidateSet('manual','automatic')][string]$Mode,
        [Parameter(Mandatory=$true)][ValidateSet('requested','assessed','approved','denied','executed','failed')][string]$Decision,
        [Parameter(Mandatory=$true)][ValidateSet('scheduler','agent','user','auto_review')][string]$Source,
        [Parameter(Mandatory=$true)][string]$Action,
        [Parameter(Mandatory=$true)][string]$Reason
    )
    if ([string]::IsNullOrWhiteSpace($RequestId) -or [string]::IsNullOrWhiteSpace($Action) -or [string]::IsNullOrWhiteSpace($Reason)) { throw 'Запис рішення потребує ID, дії та обґрунтування' }
    if ($Decision -in @('approved','denied') -and $Source -notin @('user','auto_review')) { throw 'Оцінка агента чи запуск таймера не є фактичним рішенням рецензента' }
    if ($Action.Length -gt 2000 -or $Reason.Length -gt 4000) { throw 'Опис рішення завеликий; залиште несекретний зміст' }
    $path = Get-AILangStatePath 'Схвалення.jsonl'
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $identity = [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($path.ToLowerInvariant()))).Replace('-','') }
    finally { $hash.Dispose() }
    $mutex = [Threading.Mutex]::new($false,('Local\AILangAudit' + $identity))
    $locked = $false
    try {
        try { $locked = $mutex.WaitOne(5000) } catch [Threading.AbandonedMutexException] { $locked = $true }
        if (!$locked) { throw 'Журнал рішень зайнятий' }
        $record = [ordered]@{utc=[DateTime]::UtcNow.ToString('o');requestId=$RequestId;session=$SessionId.ToString();mode=$Mode;decision=$Decision;source=$Source;action=$Action;reason=$Reason}
        $line = ($record | ConvertTo-Json -Compress) + [Environment]::NewLine
        [IO.File]::AppendAllText($path,$line,[Text.UTF8Encoding]::new($false))
    } finally {
        if ($locked) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}
function Read-AILangDecisions {
    $path = Get-AILangStatePath 'Схвалення.jsonl'
    if (!(Test-Path -LiteralPath $path)) { return @() }
    $lines = @(Get-Content -LiteralPath $path -Encoding UTF8 | Select-Object -Last 300)
    foreach ($line in $lines) {
        if (![string]::IsNullOrWhiteSpace($line)) {
            try { $line | ConvertFrom-Json } catch { throw 'Журнал рішень пошкоджений або ще записується; повторіть читання' }
        }
    }
}
Export-ModuleMember -Function Add-AILangDecision,Read-AILangDecisions
