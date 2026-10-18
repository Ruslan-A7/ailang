@echo off
start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Normal -File "%~dp0deferred-monitor.ps1"
