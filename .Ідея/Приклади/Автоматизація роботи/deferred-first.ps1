param(
    [string]$Thread = $env:CODEX_THREAD_ID,
    [ValidateRange(0,604800)][int]$DelaySeconds = 0
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'automation-common.ps1')
$context = Get-AutomationContext
if ($DelaySeconds -eq 0) { $DelaySeconds = [int]$context.Settings.FirstDelaySeconds }
if ($Thread -notmatch '^[a-fA-F0-9-]{36}$') { throw 'Потрібен ідентифікатор розмови Codex.' }
# Новий відлік починається лише після завершення попередніх таймерів цієї розмови.
$stateRoot=$context.StateRoot
New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
$stop=Join-Path $stateRoot 'stop'
New-Item -ItemType File -Path $stop -Force | Out-Null
$locks=[Collections.Generic.List[Threading.Mutex]]::new()
try {
    foreach ($suffix in @('','first_','cycle_')) {
        $lock=[Threading.Mutex]::new($false,($context.MutexPrefix+$suffix+$Thread))
        try { $acquired=$lock.WaitOne(35000) } catch [Threading.AbandonedMutexException] { $acquired=$true }
        if (!$acquired) { $lock.Dispose(); throw 'Попередній таймер ще не завершився.' }
        $locks.Add($lock)
    }
    Remove-Item -LiteralPath $stop -Force
    Remove-Item -LiteralPath (Join-Path $stateRoot 'pause') -Force -ErrorAction SilentlyContinue
} finally {
    foreach ($lock in $locks) { $lock.ReleaseMutex(); $lock.Dispose() }
}
& (Join-Path $PSScriptRoot 'deferred-launch.ps1') -Thread $Thread -Mode first -DelaySeconds $DelaySeconds
& (Join-Path $PSScriptRoot 'deferred-launch.ps1') -Thread $Thread -Mode monitor
