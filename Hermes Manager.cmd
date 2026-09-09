@echo off
title Hermes Manager
setlocal
set "HERMES_MANAGER_ROOT=%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HERMES_MANAGER_ROOT%HermesManager.ps1" menu
if errorlevel 1 pause
