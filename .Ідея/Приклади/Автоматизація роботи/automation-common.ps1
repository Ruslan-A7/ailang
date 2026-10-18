# Спільні публічні параметри. Цей файл сам не запускає жодних процесів.
function Get-AutomationContext {
    $settings = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'automation.config.psd1')
    $projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $settings.ProjectRoot))
    if (!(Test-Path -LiteralPath $projectRoot -PathType Container)) { throw 'Папку проєкту не знайдено.' }
    if ($settings.TaskPrefix -notmatch '^[a-zA-Z0-9_-]{1,40}$') { throw 'Некоректний префікс завдань.' }
    foreach ($key in @('FirstDelaySeconds','CycleDelaySeconds')) {
        if ([int]$settings[$key] -lt 1 -or [int]$settings[$key] -gt 604800) { throw 'Затримка має становити від 1 до 604800 секунд.' }
    }
    if ([IO.Path]::IsPathRooted($settings.StateDirectory)) { throw 'Папка стану має бути відносною до проєкту.' }
    $stateRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $settings.StateDirectory))
    $boundary = $projectRoot.TrimEnd([char[]]@('\','/')) + [IO.Path]::DirectorySeparatorChar
    if (!$stateRoot.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)) { throw 'Папка стану має залишатися всередині проєкту.' }
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $identity = ([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($projectRoot.ToLowerInvariant())))).Replace('-','').Substring(0,12) }
    finally { $hash.Dispose() }
    [pscustomobject]@{
        Settings = $settings
        ProjectRoot = $projectRoot
        StateRoot = $stateRoot
        TaskPrefix = $settings.TaskPrefix + '-' + $identity
        MutexPrefix = 'Local\' + $settings.TaskPrefix + '_' + $identity + '_'
        MessagePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $settings.MessageFile))
    }
}
