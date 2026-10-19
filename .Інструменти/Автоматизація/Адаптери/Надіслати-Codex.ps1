# Автор: Ruslan_A7 (RA7). Розробник: Ruslan_A7 з Codex (GPT-6), OpenAI.
# Створено з використанням AILang. RA7 Open Free License: https://ra7.iuid.cc/LICENSE. Версія 0.6.2.
param(
    [Parameter(Mandatory=$true)][guid]$SessionId,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Prompt,
    [Parameter(Mandatory=$true)][string]$ProjectRoot,
    [ValidateSet('manual','automatic')][string]$ApprovalMode = 'manual'
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $ProjectRoot -PathType Container)) { throw 'Папка проєкту недоступна' }
Import-Module (Join-Path $PSScriptRoot '../Сеанс.psm1')
$executable = Resolve-AILangCodex
# Доставка через queue в наявний чат, без запуску незалежної exec-сесії.
# Невизначений результат не повторюється: запит уже міг бути прийнятий сервером.
if ($SessionId -eq [guid]::Empty) { throw 'Потрібен дійсний UUID сеансу' }
if ($Prompt.Length -gt 24000) { throw 'Запит перевищує 24000 символів; скоротіть його для командного рядка Windows' }
function ConvertTo-WindowsArgument([string]$Value) {
    # Правила argv Windows: подвоїти зворотні слеші перед лапкою та перед завершальною лапкою.
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}
$process = $null
try {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $executable
    # Командний рядок передається без shell. Текст кодується як один аргумент, а не виконується.
    $info.Arguments = '-C ' + (ConvertTo-WindowsArgument ([IO.Path]::GetFullPath($ProjectRoot))) + ' queue --thread ' + $SessionId.ToString() + ' --message ' + (ConvertTo-WindowsArgument $Prompt)
    if ($ApprovalMode -eq 'automatic') {
        $info.Arguments += ' --approve-for-me'
    } else {
        # Не успадковувати auto_review від попереднього автоматичного виклику.
        $info.Arguments += ' -s workspace-write -c ' + (ConvertTo-WindowsArgument 'approval_policy="on-request"') + ' -c ' + (ConvertTo-WindowsArgument 'approvals_reviewer="user"')
    }
    if ($info.Arguments.Length -gt 30000) { throw 'Запит після екранування задовгий для Windows; скоротіть його' }
    $info.WorkingDirectory = [IO.Path]::GetFullPath($ProjectRoot)
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($info)
    # Дренувати обидва потоки без накопичення приватного виводу агента в журналі/історії.
    $stdoutDrain = $process.StandardOutput.BaseStream.CopyToAsync([IO.Stream]::Null)
    $stderrDrain = $process.StandardError.BaseStream.CopyToAsync([IO.Stream]::Null)
    $process.WaitForExit()
    $stdoutDrain.Wait()
    $stderrDrain.Wait()
    if ($process.ExitCode -ne 0) { throw 'Queue завершилася помилкою; перевірте чат перед повтором' }
} finally {
    if ($process) { $process.Dispose() }
}
