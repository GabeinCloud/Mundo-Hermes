@echo off
title Install Hermes Manager for Windows
setlocal
set "PACKAGE_ROOT=%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%scripts\Install-HermesManager.ps1" -ChooseInstallPath -Language en
set "RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %RESULT%
