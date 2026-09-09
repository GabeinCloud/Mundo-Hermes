@echo off
title Activar alias globales de Hermes
setlocal
set "HERMES_MANAGER_ROOT=%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HERMES_MANAGER_ROOT%Activar alias globales.ps1"
echo.
pause
