@echo off
title Uninstall Hermes Manager for Windows
setlocal
set "PACKAGE_ROOT=%~dp0"
pushd "%TEMP%"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%scripts\Uninstall-HermesManager.ps1" -Language en
set "RESULT=%ERRORLEVEL%"
popd
echo.
pause
exit /b %RESULT%
