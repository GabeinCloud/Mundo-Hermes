@echo off
title Enable Hermes global aliases (English)
setlocal
set "HERMES_MANAGER_ROOT=%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HERMES_MANAGER_ROOT%Activar alias globales.ps1" -Language en
echo.
pause
