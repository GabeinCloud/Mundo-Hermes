@echo off
title Instalar Hermes Manager para Windows
setlocal
set "PACKAGE_ROOT=%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%scripts\Install-HermesManager.ps1" -ChooseInstallPath
set "RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %RESULT%
