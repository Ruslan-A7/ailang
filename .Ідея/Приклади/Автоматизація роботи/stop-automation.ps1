$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'automation-common.ps1')
$context = Get-AutomationContext
New-Item -ItemType Directory -Path $context.StateRoot -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $context.StateRoot 'stop') -Force | Out-Null
Write-Output 'Стоп-файл створено. Уже переданий запит потрібно скасувати в Codex окремо.'
