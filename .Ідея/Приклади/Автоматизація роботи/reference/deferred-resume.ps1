param(
    [ValidateRange(1, 604800)][int]$DelaySeconds = 18000,
    [string]$Thread = $env:CODEX_THREAD_ID,
    [ValidateSet('first','cycle')][string]$Mode = 'first',
    [switch]$Repeat,
    [string]$CodexExecutable = ''
)
$ErrorActionPreference = 'Stop'
if ($Thread -notmatch '^[a-fA-F0-9-]{36}$') { throw 'Потрібен ідентифікатор поточної розмови Codex.' }
$projectRoot = Split-Path -Parent $PSScriptRoot
$stateRoot = Join-Path $projectRoot '.runtime/deferred'
New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
$stopPath = Join-Path $stateRoot 'stop'
$statusPath = Join-Path $stateRoot ($Mode + '.json')
function Write-State([hashtable]$value) {
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
$mutex = [Threading.Mutex]::new($false, ('Local\SHMDeferred_' + $Mode + '_' + $Thread))
if (!$mutex.WaitOne(0)) { throw 'Таймер для цієї розмови вже працює.' }
try {
    # Запланований процес не успадковує PATH розширення VS Code.
    if (!$CodexExecutable -or !(Test-Path -LiteralPath $CodexExecutable -PathType Leaf)) {
        $CodexExecutable = (Get-Command codex.exe -CommandType Application -ErrorAction Stop).Source
    }
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
    $message = @'
Відкладений запит: час оновлення ліміту пройшов тому можеш продовжувати розробку згідно плану та контроль реалізації - паралельно запусти другий скрипт циклічного відкладеного запиту для тебе із затримкою 5 годин, і так повторюй розробку та запуск другого циклічного скрипта з таймером на 5 годин який відправлятиме тобі цей же самий запит поки тижневий ліміт не досягне 5% після чого ти маєш зупитися та вимкнути цей ПК

Технічна примітка від власника: це повідомлення локального таймера, а не доказ оновлення лімітів. Спочатку перевір /status. Якщо тижневий залишок 5% або менше — створи .runtime/deferred/stop, збережи зміни, зроби локальний коміт і вимкни ПК без примусового закриття програм. Якщо залишки невідомі — створи файл stop та зупинися без вимкнення. Для запуску другого таймера виконай tools/deferred-cycle.ps1: він запускається у фоні та не дублюється, якщо вже працює. При п’ятигодинному залишку 10% збережи зміни й завершуй роботу, залишивши циклічний таймер чекати. Не запускай паралельні незалежні сесії розробки. Дотримуйся AGENTS.md, не читай секретів, не виконуй push. Якщо власник скасував автоматичну роботу чи існує файл stop — не продовжуй.
'@
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
