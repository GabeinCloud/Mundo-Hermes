@echo off
title Enable Hermes global aliases (English)
setlocal
set "HERMES_MANAGER_ROOT=%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HERMES_MANAGER_ROOT%Activate global aliases.ps1"
echo.
pause
