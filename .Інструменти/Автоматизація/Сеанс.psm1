# Автор: Ruslan_A7 (RA7). Розробник: RA7 з Codex (GPT-6), OpenAI.
# Створено з використанням AILang. RA7 Open Free License: https://ra7.iuid.cc/LICENSE. Версія 0.6.3.
Import-Module (Join-Path $PSScriptRoot 'Сховище.psm1')
function Read-AILangPreferences {
    $path = Get-AILangStatePath 'Сеанс.json'
    if (!(Test-Path -LiteralPath $path)) { return [pscustomobject]@{session='';name='';codexExecutable=''} }
    try {
        $value = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($path,[Text.Encoding]::UTF8))
        return [pscustomobject]@{session=[string]$value.session;name=[string]$value.name;codexExecutable=[string]$value.codexExecutable}
    } catch { throw 'Не вдалося прочитати локальні параметри сеансу. Файл не перезаписано.' }
}
function Save-AILangPreferences([string]$Session,[string]$Name,[string]$CodexExecutable) {
    if ($Session) {
        $id = [guid]::Empty
        if (![guid]::TryParse($Session,[ref]$id) -or $id -eq [guid]::Empty) { return }
        $Session = $id.ToString()
    }
    if ($CodexExecutable -and ([IO.Path]::GetFileName($CodexExecutable) -ine 'codex.exe' -or !(Test-Path -LiteralPath $CodexExecutable -PathType Leaf))) { throw 'Потрібен наявний codex.exe' }
    $path = Get-AILangStatePath 'Сеанс.json'
    $temp = Get-AILangStatePath 'Сеанс.tmp'
    $value = [ordered]@{session=$Session;name=$Name;codexExecutable=$CodexExecutable}
    [IO.File]::WriteAllText($temp,($value | ConvertTo-Json),[Text.UTF8Encoding]::new($true))
    Move-Item -LiteralPath $temp -Destination $path -Force
}
function Resolve-AILangCodex {
    $settings = Read-AILangPreferences
    if ($settings.codexExecutable -and (Test-Path -LiteralPath $settings.codexExecutable -PathType Leaf)) { return $settings.codexExecutable }
    $command = Get-Command codex.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    throw 'cli_not_found'
}
Export-ModuleMember -Function Read-AILangPreferences,Save-AILangPreferences,Resolve-AILangCodex
