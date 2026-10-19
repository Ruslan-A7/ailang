# Автор: Ruslan_A7 (RA7). Розробник: RA7 з Codex (GPT-6), OpenAI.
# Створено з використанням AILang. RA7 Open Free License: https://ra7.iuid.cc/LICENSE. Версія 0.6.5.
param([ValidateRange(5,60)][int]$TimeoutSeconds=25)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Codex-Rpc.psm1')
try {
    $result=Invoke-AILangRpc -Method 'account/rateLimits/read' -TimeoutSeconds $TimeoutSeconds
    $bucket=$result.rateLimits
    if ($result.rateLimitsByLimitId -and $result.rateLimitsByLimitId.codex) { $bucket=$result.rateLimitsByLimitId.codex }
    $windows=[Collections.Generic.List[object]]::new()
    foreach ($name in @('primary','secondary')) {
        $window=$bucket.$name
        if ($null -eq $window) { continue }
        if ($null -eq $window.usedPercent -or $null -eq $window.windowDurationMins) { throw 'rpc_protocol' }
        $used=[double]$window.usedPercent
        $minutes=[int]$window.windowDurationMins
        if ([double]::IsNaN($used) -or $used -lt 0 -or $used -gt 100 -or $minutes -le 0) { throw 'rpc_protocol' }
        $reset=$null
        if ($window.resetsAt) { $reset=[DateTimeOffset]::FromUnixTimeSeconds([long]$window.resetsAt).UtcDateTime.ToString('o') }
        $windows.Add([pscustomobject]@{minutes=$minutes;remaining=(100-$used);resetUtc=$reset})
    }
    if (!$windows.Count) { throw 'rpc_protocol' }
    [pscustomobject]@{status='known';source='codex-app-server';checkedUtc=[DateTime]::UtcNow.ToString('o');windows=$windows.ToArray();code='';reason=''}
} catch {
    $code=[string]$_.Exception.Message
    if ($code -notin @('cli_not_found','cli_start','rpc_timeout','rpc_closed','rpc_auth','rpc_network','rpc_unsupported','rpc_protocol','rpc_error')) { $code='rpc_protocol' }
    [pscustomobject]@{status='unknown';source='codex-app-server';checkedUtc=[DateTime]::UtcNow.ToString('o');windows=@();code=$code;reason=(Get-AILangRpcReason $code)}
}
