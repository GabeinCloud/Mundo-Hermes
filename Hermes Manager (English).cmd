@echo off
title Hermes Manager (English)
setlocal
set "HERMES_MANAGER_ROOT=%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HERMES_MANAGER_ROOT%HermesManager.ps1" -Language en menu
if errorlevel 1 pause
