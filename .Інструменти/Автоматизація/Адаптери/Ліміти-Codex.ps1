# Автор: Ruslan_A7 (RA7). Розробник: Ruslan_A7 з Codex (GPT-6), OpenAI.
# Створено з використанням AILang. RA7 Open Free License: https://ra7.iuid.cc/LICENSE. Версія 0.3.0.
param([ValidateRange(5,60)][int]$TimeoutSeconds = 20)
$ErrorActionPreference = 'Stop'
$process = $null
try {
    $command = Get-Command codex.exe -ErrorAction Stop
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $command.Source
    $info.Arguments = 'app-server --stdio'
    $info.WorkingDirectory = (Get-Location).Path
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [Text.Encoding]::UTF8
    $process = [Diagnostics.Process]::Start($info)
    $stderrDrain = $process.StandardError.ReadToEndAsync()
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    function Send-Rpc($message) {
        $process.StandardInput.WriteLine(($message | ConvertTo-Json -Depth 12 -Compress))
        $process.StandardInput.Flush()
    }
    function Read-Rpc([int]$responseId) {
        while ([DateTime]::UtcNow -lt $deadline) {
            $pending = $process.StandardOutput.ReadLineAsync()
            $remaining = [int][Math]::Max(1,($deadline - [DateTime]::UtcNow).TotalMilliseconds)
            if (!$pending.Wait($remaining)) { throw 'rpc_timeout' }
            if ($null -eq $pending.Result) { throw 'rpc_closed' }
            $message = $pending.Result | ConvertFrom-Json
            if ($null -ne $message.id -and $message.id -eq $responseId) {
                if ($message.error) { throw 'rpc_error' }
                return $message.result
            }
        }
        throw 'rpc_timeout'
    }
    Send-Rpc @{id=1;method='initialize';params=@{clientInfo=@{name='ailang_limits';title='AILang limits';version='0.3.0'}}}
    $null = Read-Rpc 1
    Send-Rpc @{method='initialized';params=@{}}
    Send-Rpc @{id=2;method='account/rateLimits/read'}
    $result = Read-Rpc 2
    $bucket = $result.rateLimits
    if ($result.rateLimitsByLimitId -and $result.rateLimitsByLimitId.codex) { $bucket = $result.rateLimitsByLimitId.codex }
    $windows = @()
    foreach ($name in @('primary','secondary')) {
        $window = $bucket.$name
        if ($null -eq $window) { continue }
        if ($null -eq $window.usedPercent -or $null -eq $window.windowDurationMins) { throw 'invalid_window' }
        $used = [double]$window.usedPercent
        $minutes = [int]$window.windowDurationMins
        if ($used -lt 0 -or $used -gt 100 -or $minutes -le 0) { throw 'invalid_window' }
        $reset = $null
        if ($window.resetsAt) { $reset = [DateTimeOffset]::FromUnixTimeSeconds([long]$window.resetsAt).UtcDateTime.ToString('o') }
        $windows += [pscustomobject]@{minutes=$minutes;remaining=(100-$used);resetUtc=$reset}
    }
    if (!$windows.Count) { throw 'no_windows' }
    [pscustomobject]@{status='known';source='codex-app-server';checkedUtc=[DateTime]::UtcNow.ToString('o');windows=$windows}
} catch {
    # Не повертати сирі RPC, stderr або повідомлення сервера: вони можуть містити приватні дані.
    [pscustomobject]@{status='unknown';source='codex-app-server';checkedUtc=[DateTime]::UtcNow.ToString('o');windows=@();reason='CLI, авторизація, мережа або протокол недоступні'}
} finally {
    if ($process) {
        try { if (!$process.HasExited) { $process.Kill(); $null = $process.WaitForExit(2000) } } catch {}
        $process.Dispose()
    }
}
