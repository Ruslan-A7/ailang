# Автор: Ruslan_A7 (RA7). Розробник: Ruslan_A7 з Codex (GPT-6), OpenAI.
# Створено з використанням AILang. RA7 Open Free License: https://ra7.iuid.cc/LICENSE. Версія 0.4.0.
$script:ProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$script:StateRoot = Join-Path $script:ProjectRoot '.Стан/Автоматизація'
function Assert-LocalPath([string]$Path) {
    $absolute = [IO.Path]::GetFullPath($Path)
    if (!$absolute.StartsWith($script:ProjectRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Шлях поза проєктом' }
    $cursor = $absolute
    while ($cursor -and $cursor -ne $script:ProjectRoot) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -Force -LiteralPath $cursor).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Посилання у шляху стану заборонені' }
        }
        $cursor = Split-Path -Parent $cursor
    }
    return $absolute
}
function Get-AILangRoot { return $script:ProjectRoot }
function Read-AILangHistory {
    $path = Assert-LocalPath (Join-Path $script:StateRoot 'Історія.json')
    if (!(Test-Path -LiteralPath $path)) { return @() }
    try { return @(Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json) }
    catch { throw 'Історія пошкоджена; збережіть файл перед ручним виправленням' }
}
function Add-AILangHistory([string]$Kind,[string]$Prompt,[string]$Session) {
    $null = Assert-LocalPath $script:StateRoot
    $null = New-Item -ItemType Directory -Path $script:StateRoot -Force
    $path = Assert-LocalPath (Join-Path $script:StateRoot 'Історія.json')
    $temp = Assert-LocalPath (Join-Path $script:StateRoot 'Історія.tmp')
    $entries = @(Read-AILangHistory) + @([pscustomobject]@{utc=[DateTime]::UtcNow.ToString('o');kind=$Kind;prompt=$Prompt;session=$Session})
    # Надіслані запити не вилучаються: користувач може повторно обрати будь-який із них.
    $sent = @($entries | Where-Object kind -eq 'прийнято queue')
    $drafts = @($entries | Where-Object kind -ne 'прийнято queue' | Select-Object -Last 300)
    $entries = @(@($sent) + @($drafts) | Sort-Object utc)
    ConvertTo-Json -InputObject $entries -Depth 6 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $path -Force
}
function Get-AILangStatePath([string]$Name) {
    if ($Name -notmatch '^[\p{L}\p{N}_.-]+$') { throw 'Некоректна назва файла стану' }
    $null = Assert-LocalPath $script:StateRoot
    $null = New-Item -ItemType Directory -Path $script:StateRoot -Force
    return (Assert-LocalPath (Join-Path $script:StateRoot $Name))
}
Export-ModuleMember -Function Get-AILangRoot,Read-AILangHistory,Add-AILangHistory,Get-AILangStatePath
