param([string]$Thread = $env:CODEX_THREAD_ID,[ValidateRange(0,604800)][int]$DelaySeconds = 0)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'automation-common.ps1')
$context = Get-AutomationContext
if ($DelaySeconds -eq 0) { $DelaySeconds = [int]$context.Settings.CycleDelaySeconds }
if ($Thread -notmatch '^[a-fA-F0-9-]{36}$') { throw 'Потрібен ідентифікатор розмови Codex.' }
if (Test-Path -LiteralPath (Join-Path $context.StateRoot 'stop')) { return }
& (Join-Path $PSScriptRoot 'deferred-launch.ps1') -Thread $Thread -Mode cycle -DelaySeconds $DelaySeconds
& (Join-Path $PSScriptRoot 'deferred-launch.ps1') -Thread $Thread -Mode monitor
