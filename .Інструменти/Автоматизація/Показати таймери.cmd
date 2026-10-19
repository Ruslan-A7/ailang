@rem AILang v0.5.0. Author: Ruslan_A7 (RA7). Developer: RA7 with Codex (GPT-6), OpenAI.
@rem Created using AILang. License: https://ra7.iuid.cc/LICENSE
@echo off
setlocal
if not exist "%~dp0Launch.ps1" goto missing
start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File "%~dp0Launch.ps1"
if errorlevel 1 goto failed
exit /b 0
:missing
echo AILang: Launch.ps1 is missing. Restore the complete automation folder.
pause
exit /b 1
:failed
echo AILang: Windows PowerShell could not start.
pause
exit /b 1
