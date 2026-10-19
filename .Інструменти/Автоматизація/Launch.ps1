# Автор: Ruslan_A7 (RA7). Розробник: RA7 з Codex (GPT-6), OpenAI.
# Створено з використанням AILang. RA7 Open Free License: https://ra7.iuid.cc/LICENSE. Версія 0.6.3.
param()
$ErrorActionPreference = 'Stop'
try {
    & (Join-Path $PSScriptRoot 'Планувальник.ps1')
} catch {
    # Не виводити вміст історії/запитів із сирого Exception.Message.
    $kind = $_.Exception.GetType().Name
    $line = $_.InvocationInfo.ScriptLineNumber
    $message = "Не вдалося відкрити планувальник AILang.`nТип помилки: $kind; рядок: $line.`nПеревірте наявність усіх файлів пакета та доступність PowerShell/WPF."
    try {
        Add-Type -AssemblyName PresentationFramework
        $null = [Windows.MessageBox]::Show($message,'AILang — помилка запуску','OK','Error')
    } catch { Write-Error 'AILang: startup failed; PowerShell/WPF or package files are unavailable.' -ErrorAction Continue }
    exit 1
}
