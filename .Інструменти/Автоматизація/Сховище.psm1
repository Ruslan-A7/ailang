# Автор: Ruslan_A7 (RA7). Розробник: Ruslan_A7 з Codex (GPT-6), OpenAI.
# Створено з використанням AILang. RA7 Open Free License: https://ra7.iuid.cc/LICENSE. Версія 0.6.2.
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
    $script:HistoryWrapped = $false
    $script:HistorySkipped = 0
    if (!(Test-Path -LiteralPath $path)) { return }
    try { $decoded = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)) }
    catch { throw 'Історія пошкоджена; оригінал збережений без змін' }
    $pending = [Collections.Generic.Stack[object]]::new()
    if ($null -ne $decoded) { $pending.Push($decoded) }
    $visited = 0
    while ($pending.Count) {
        if (++$visited -gt 100000) { throw 'Історія завелика для безпечного відновлення; оригінал не змінено' }
        $node = $pending.Pop()
        if ($node -is [Array]) {
            for ($index=$node.Length-1; $index -ge 0; $index--) { if ($null -ne $node[$index]) { $pending.Push($node[$index]) } }
        } elseif ($node.PSObject.Properties['kind'] -and $node.PSObject.Properties['prompt']) {
            # Явні скалярні поля: не серіалізувати оболонки PowerShell value/Count.
            [pscustomobject]@{utc=[string]$node.utc;kind=[string]$node.kind;prompt=[string]$node.prompt;session=[string]$node.session}
        } elseif ($node.PSObject.Properties['value']) {
            $script:HistoryWrapped = $true
            if ($null -ne $node.value) { $pending.Push($node.value) }
        } else { $script:HistorySkipped++ }
    }
}
function Add-AILangHistory([string]$Kind,[string]$Prompt,[string]$Session) {
    $null = Assert-LocalPath $script:StateRoot
    $null = New-Item -ItemType Directory -Path $script:StateRoot -Force
    $path = Assert-LocalPath (Join-Path $script:StateRoot 'Історія.json')
    $temp = Assert-LocalPath (Join-Path $script:StateRoot 'Історія.tmp')
    $entries = [Collections.Generic.List[object]]::new()
    foreach ($record in Read-AILangHistory) { $entries.Add($record) }
    if ($script:HistoryWrapped -or $script:HistorySkipped) {
        $backup = Assert-LocalPath (Join-Path $script:StateRoot 'Історія-до-v0.6.0.json')
        if (!(Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $path -Destination $backup }
    }
    $entries.Add([pscustomobject]@{utc=[DateTime]::UtcNow.ToString('o');kind=$Kind;prompt=$Prompt;session=$Session})
    # Надіслані запити не вилучаються: користувач може повторно обрати будь-який із них.
    $sent = @($entries.ToArray() | Where-Object kind -eq 'прийнято queue')
    $drafts = @($entries.ToArray() | Where-Object kind -ne 'прийнято queue' | Select-Object -Last 300)
    $normalized = [Collections.Generic.List[object]]::new()
    foreach ($record in @($sent)+@($drafts)) {
        $normalized.Add([pscustomobject]@{utc=[string]$record.utc;kind=[string]$record.kind;prompt=[string]$record.prompt;session=[string]$record.session})
    }
    $json = ConvertTo-Json -InputObject ([object[]]$normalized.ToArray()) -Depth 4
    [IO.File]::WriteAllText($temp,$json,[Text.UTF8Encoding]::new($true))
    Move-Item -LiteralPath $temp -Destination $path -Force
}
function Get-AILangHistoryNotice {
    if ($script:HistorySkipped) { return 'Частину старих записів було обрізано попередньою серіалізацією. Оригінал буде збережений у резервній копії; доступні записи відновлено.' }
    if ($script:HistoryWrapped) { return 'Старі вкладені записи розпізнано. При наступному збереженні буде створено резервну копію та виправлено формат.' }
    return ''
}
function Repair-AILangHistory {
    $records=[Collections.Generic.List[object]]::new()
    foreach ($record in Read-AILangHistory) { $records.Add($record) }
    $skipped=$script:HistorySkipped
    $wrapped=$script:HistoryWrapped
    $path=Get-AILangStatePath 'Історія.json'
    if (($wrapped -or $skipped) -and (Test-Path -LiteralPath $path)) {
        $backup=Get-AILangStatePath 'Історія-до-v0.6.0.json'
        if (!(Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $path -Destination $backup }
        $temp=Get-AILangStatePath 'Історія.tmp'
        $json=ConvertTo-Json -InputObject ([object[]]$records.ToArray()) -Depth 4
        [IO.File]::WriteAllText($temp,$json,[Text.UTF8Encoding]::new($true))
        Move-Item -LiteralPath $temp -Destination $path -Force
    }
    return [pscustomobject]@{recovered=$records.Count;sent=@($records.ToArray() | Where-Object kind -eq 'прийнято queue').Count;unrecoverable=$skipped;normalized=$wrapped}
}
function Get-AILangStatePath([string]$Name) {
    if ($Name -notmatch '^[\p{L}\p{N}_.-]+$') { throw 'Некоректна назва файла стану' }
    $null = Assert-LocalPath $script:StateRoot
    $null = New-Item -ItemType Directory -Path $script:StateRoot -Force
    return (Assert-LocalPath (Join-Path $script:StateRoot $Name))
}
Export-ModuleMember -Function Get-AILangRoot,Read-AILangHistory,Add-AILangHistory,Get-AILangStatePath,Get-AILangHistoryNotice,Repair-AILangHistory
