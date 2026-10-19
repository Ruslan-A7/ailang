# Автор: Ruslan_A7 (RA7). Розробник: RA7 з Codex (GPT-6), OpenAI.
# Створено з використанням AILang. RA7 Open Free License: https://ra7.iuid.cc/LICENSE. Версія 0.6.4.
param(
    [Parameter(Mandatory=$true)][string]$RequestId,
    [Parameter(Mandatory=$true)][guid]$SessionId,
    [Parameter(Mandatory=$true)][ValidateSet('manual','automatic')][string]$Mode,
    [Parameter(Mandatory=$true)][ValidateSet('requested','assessed','approved','denied','executed','failed')][string]$Decision,
    [Parameter(Mandatory=$true)][ValidateSet('scheduler','agent','user','auto_review')][string]$Source,
    [Parameter(Mandatory=$true)][string]$Action,
    [Parameter(Mandatory=$true)][string]$Reason
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Схвалення.psm1')
Add-AILangDecision @PSBoundParameters
