@echo off
title Desinstalar Hermes Manager para Windows
setlocal
set "PACKAGE_ROOT=%~dp0"
pushd "%TEMP%"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%scripts\Uninstall-HermesManager.ps1"
set "RESULT=%ERRORLEVEL%"
popd
echo.
pause
exit /b %RESULT%
