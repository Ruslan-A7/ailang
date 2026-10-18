param([string]$Thread = $env:CODEX_THREAD_ID)
$ErrorActionPreference='Stop'
if ($Thread -notmatch '^[a-fA-F0-9-]{36}$') { throw 'Потрібен ідентифікатор розмови Codex.' }
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot '../.runtime/deferred/stop')) { return }
& (Join-Path $PSScriptRoot 'deferred-launch.ps1') -Thread $Thread -Mode cycle -DelaySeconds 18000
& (Join-Path $PSScriptRoot 'deferred-launch.ps1') -Thread $Thread -Mode monitor
