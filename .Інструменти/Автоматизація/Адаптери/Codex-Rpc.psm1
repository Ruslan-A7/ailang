# Автор: Ruslan_A7 (RA7). Розробник: RA7 з Codex (GPT-6), OpenAI.
# Створено з використанням AILang. RA7 Open Free License: https://ra7.iuid.cc/LICENSE. Версія 0.6.0.
Import-Module (Join-Path $PSScriptRoot '../Сеанс.psm1')
Import-Module (Join-Path $PSScriptRoot '../Сховище.psm1')
function Get-AILangRpcReason([string]$Code) {
    switch ($Code) {
        cli_not_found { 'Не знайдено codex.exe. Оберіть файл кнопкою Codex.exe.' }
        cli_start { 'Codex CLI не вдалося запустити.' }
        rpc_timeout { 'Codex не відповів за відведений час. Повторіть читання квот.' }
        rpc_closed { 'Codex завершив канал до відповіді.' }
        rpc_auth { 'Налаштований вхід Codex недоступний або потребує оновлення.' }
        rpc_network { 'Codex не зміг отримати дані через мережу або сервер.' }
        rpc_unsupported { 'Установлений Codex не підтримує цей метод.' }
        rpc_protocol { 'Неочікуваний формат відповіді Codex.' }
        default { 'Codex повернув помилку. Перевірте доступність CLI та вхід.' }
    }
}
function Invoke-AILangRpc {
    param([ValidateSet('account/rateLimits/read','thread/read')][string]$Method,[hashtable]$Params=@{},[int]$TimeoutSeconds=25)
    $process = $null
    $stage = 'cli_start'
    try {
        $executable = Resolve-AILangCodex
        $info = [Diagnostics.ProcessStartInfo]::new()
        $info.FileName=$executable
        # Ізольований stdio-сервер, а не проксі до зайнятого спільного daemon.
        $info.Arguments='--no-daemon app-server --stdio'
        $info.WorkingDirectory=(Get-AILangRoot)
        $info.UseShellExecute=$false; $info.CreateNoWindow=$true
        $info.RedirectStandardInput=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
        $info.StandardOutputEncoding=[Text.Encoding]::UTF8
        $process=[Diagnostics.Process]::Start($info)
        $stderrDrain=$process.StandardError.BaseStream.CopyToAsync([IO.Stream]::Null)
        $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
        $process.StandardInput.AutoFlush=$true
        $initialize=@{id=1;method='initialize';params=@{clientInfo=@{name='ailang_tools';title='AILang';version='0.6.0'}}}
        $process.StandardInput.WriteLine(($initialize | ConvertTo-Json -Depth 8 -Compress))
        foreach ($expected in @(1,2)) {
            $stage='rpc_timeout'
            $response=$null
            while ([DateTime]::UtcNow -lt $deadline) {
                $pending=$process.StandardOutput.ReadLineAsync()
                $remaining=[int][Math]::Max(1,($deadline-[DateTime]::UtcNow).TotalMilliseconds)
                if (!$pending.Wait($remaining)) { throw 'rpc_timeout' }
                if ($null -eq $pending.Result) { throw 'rpc_closed' }
                try { $message=ConvertFrom-Json -InputObject $pending.Result } catch { throw 'rpc_protocol' }
                if ($null -ne $message.id -and $message.id -eq $expected) { $response=$message; break }
                # Серверні запити авторизації не реалізуємо вручну й не читаємо токени.
                if ($message.method -and $null -ne $message.id) { throw 'rpc_auth' }
            }
            if (!$response) { throw 'rpc_timeout' }
            if ($response.error) {
                $details=([string]$response.error.message).ToLowerInvariant()
                if ($response.error.code -eq -32601) { throw 'rpc_unsupported' }
                if ($details -match '401|403|not.logged|auth|api.key|token') { throw 'rpc_auth' }
                if ($details -match 'network|connect|fetch|sending request|unavailable') { throw 'rpc_network' }
                throw 'rpc_error'
            }
            if ($expected -eq 1) {
                $process.StandardInput.WriteLine('{"method":"initialized","params":{}}')
                $process.StandardInput.WriteLine((@{id=2;method=$Method;params=$Params} | ConvertTo-Json -Depth 8 -Compress))
            } else { return $response.result }
        }
    } catch {
        $code=[string]$_.Exception.Message
        if ($code -notin @('cli_not_found','rpc_timeout','rpc_closed','rpc_auth','rpc_network','rpc_unsupported','rpc_protocol','rpc_error')) { $code=$stage }
        throw [InvalidOperationException]::new($code)
    } finally {
        if ($process) {
            try { if (!$process.HasExited) { $process.Kill(); $null=$process.WaitForExit(2000) } } catch {}
            $process.Dispose()
        }
    }
}
Export-ModuleMember -Function Invoke-AILangRpc,Get-AILangRpcReason
