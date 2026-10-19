# Автор: Ruslan_A7 (RA7). Розробник: RA7 з Codex (GPT-6), OpenAI.
# Створено з використанням AILang. RA7 Open Free License: https://ra7.iuid.cc/LICENSE. Версія 0.6.3.
param([Parameter(Mandatory=$true)][guid]$SessionId)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Codex-Rpc.psm1')
try {
    $result=Invoke-AILangRpc -Method 'thread/read' -Params @{threadId=$SessionId.ToString();includeTurns=$false}
    $root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..')).TrimEnd('\','/')
    if ($result.thread.cwd -and ![string]::Equals([IO.Path]::GetFullPath([string]$result.thread.cwd).TrimEnd('\','/'),$root,[StringComparison]::OrdinalIgnoreCase)) { throw 'thread_project_mismatch' }
    $name=[string]$result.thread.name
    [pscustomobject]@{status='known';session=$SessionId.ToString();name=$name;reason=if ($name) {''} else {'Codex не надав назву цього чату'}}
} catch {
    [pscustomobject]@{status='unknown';session=$SessionId.ToString();name='';reason='Назва недоступна через Codex; UUID збережений і може використовуватися без назви'}
}
