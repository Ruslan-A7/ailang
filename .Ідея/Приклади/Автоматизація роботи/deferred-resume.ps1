param(
    [ValidateRange(0, 604800)][int]$DelaySeconds = 0,
    [string]$Thread = $env:CODEX_THREAD_ID,
    [ValidateSet('first','cycle')][string]$Mode = 'first',
    [switch]$Repeat,
    [string]$CodexExecutable = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'automation-common.ps1')
$context = Get-AutomationContext
if ($DelaySeconds -eq 0) { $DelaySeconds = if ($Mode -eq 'first') { [int]$context.Settings.FirstDelaySeconds } else { [int]$context.Settings.CycleDelaySeconds } }
if ($Thread -notmatch '^[a-fA-F0-9-]{36}$') { throw 'Потрібен ідентифікатор поточної розмови Codex.' }
$projectRoot = $context.ProjectRoot
$stateRoot = $context.StateRoot
New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
$stopPath = Join-Path $stateRoot 'stop'
$statusPath = Join-Path $stateRoot ($Mode + '.json')
function Write-State([hashtable]$value) {
    $value['interval_seconds'] = $DelaySeconds
    # Монітор може одночасно читати файл; тимчасове блокування не зупиняє відлік.
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($value | ConvertTo-Json))
    for ($attempt=0; $attempt -lt 10; $attempt++) {
        try {
            $stream = [IO.File]::Open($statusPath,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
            try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
            return
        } catch [IO.IOException] { Start-Sleep -Milliseconds 100 }
    }
}
$mutex = [Threading.Mutex]::new($false, ($context.MutexPrefix + $Mode + '_' + $Thread))
if (!$mutex.WaitOne(0)) { throw 'Таймер для цієї розмови вже працює.' }
try {
    # Запланований процес не успадковує PATH розширення VS Code.
    if (!$CodexExecutable -or !(Test-Path -LiteralPath $CodexExecutable -PathType Leaf)) {
        $CodexExecutable = $context.Settings.CodexExecutable
        if (!$CodexExecutable) { $CodexExecutable = (Get-Command codex.exe -CommandType Application -ErrorAction Stop).Source }
    }
    if (!(Test-Path -LiteralPath $CodexExecutable -PathType Leaf)) { throw 'Виконуваний файл Codex не знайдено.' }
    $message = Get-Content -LiteralPath $context.MessagePath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($message)) { throw 'Текст відкладеного запиту порожній.' }
    do {
    if (Test-Path -LiteralPath $stopPath) { return }
    $remaining = [double]$DelaySeconds
    $lastTick = [DateTimeOffset]::UtcNow
    $pausePath = Join-Path $stateRoot 'pause'
    while ($remaining -gt 0 -or (Test-Path -LiteralPath $pausePath)) {
        if (Test-Path -LiteralPath $stopPath) {
            Write-State @{ pid=$PID; state='cancelled'; updated_utc=[DateTimeOffset]::UtcNow.ToString('o') }
            return
        }
        $now = [DateTimeOffset]::UtcNow
        $paused = Test-Path -LiteralPath $pausePath
        if (!$paused) { $remaining = [Math]::Max(0, $remaining - ($now-$lastTick).TotalSeconds) }
        $lastTick = $now
        $due = $now.AddSeconds($remaining)
        Write-State @{ pid=$PID; due_utc=$due.ToString('o'); remaining_seconds=[Math]::Ceiling($remaining); state=$(if ($paused) {'paused'} else {'waiting'}); updated_utc=$now.ToString('o') }
        if ($remaining -gt 0 -or $paused) { Start-Sleep -Seconds 1 }
    }
    if (Test-Path -LiteralPath $stopPath) { return }

    Write-State @{ pid=$PID; state='sending'; due_utc=$due.ToString('o'); updated_utc=[DateTimeOffset]::UtcNow.ToString('o') }
    & $CodexExecutable -C $projectRoot queue --thread $Thread --message $message
    if ($LASTEXITCODE -ne 0) { throw 'Codex не прийняв відкладений запит. Автоматичні повтори вимкнені.' }
    Write-State @{ due_utc=$due.ToString('o'); state='queued'; updated_utc=[DateTimeOffset]::UtcNow.ToString('o') }
    } while ($Repeat)
} catch {
    Write-State @{ state='failed'; due_utc=$due.ToString('o'); remaining_seconds=$remaining; exception_type=$_.Exception.GetType().Name; error_code=$_.Exception.HResult; error_tag=$_.FullyQualifiedErrorId; message='Помилка виконання таймера. Автоматичний повтор вимкнений.' }
    throw
} finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
