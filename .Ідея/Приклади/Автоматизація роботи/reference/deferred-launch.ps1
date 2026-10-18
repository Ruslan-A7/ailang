param(
    [Parameter(Mandatory=$true)][string]$Thread,
    [ValidateSet('first','cycle','monitor')][string]$Mode,
    [ValidateRange(1,604800)][int]$DelaySeconds = 18000
)
$ErrorActionPreference = 'Stop'
if ($Thread -notmatch '^[a-fA-F0-9-]{36}$') { throw 'Некоректний ідентифікатор розмови.' }
$projectRoot = Split-Path -Parent $PSScriptRoot
$script = if ($Mode -eq 'monitor') { Join-Path $PSScriptRoot 'deferred-monitor.ps1' } else { Join-Path $PSScriptRoot 'deferred-resume.ps1' }
$style = if ($Mode -eq 'monitor') { 'Normal' } else { 'Hidden' }
$arguments = '-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle '+$style+' -File "'+$script+'"'
if ($Mode -ne 'monitor') {
	$codexCommand = Get-Command codex.exe -CommandType Application -ErrorAction Stop
	$arguments += ' -CodexExecutable "'+$codexCommand.Source+'"'
    $arguments += ' -Thread '+$Thread+' -Mode '+$Mode+' -DelaySeconds '+$DelaySeconds
    if ($Mode -eq 'cycle') { $arguments += ' -Repeat' }
}
# Планувальник не прив’язує таймер до термінала, який може закритися після команди.
$name = 'ScrapHunterMan-Deferred-'+$Mode+'-'+$Thread
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments -WorkingDirectory $projectRoot
$settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $name -Action $action -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $name
