@echo off
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0DinhDuoc-Key-Manager.ps1"
if errorlevel 1 pause
