[CmdletBinding()]
param(
    [string]$InstallPath = (Join-Path $env:LOCALAPPDATA 'HermesManager'),
    [switch]$ChooseInstallPath,
    [switch]$NoPath,
    [switch]$NoShortcut,
    [switch]$NoTests
)

$ErrorActionPreference = 'Stop'
$SourceRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')

if (-not $env:OS -or $env:OS -ne 'Windows_NT') {
    throw 'Esta versión de Hermes Manager solo admite Windows.'
}
if ($ChooseInstallPath) {
    Write-Host 'CARPETA DE INSTALACIÓN' -ForegroundColor Cyan
    Write-Host "Pulsa Intro para utilizar: $InstallPath"
    $selectedPath = Read-Host 'O escribe otra carpeta'
    if (-not [string]::IsNullOrWhiteSpace($selectedPath)) {
        $InstallPath = [Environment]::ExpandEnvironmentVariables($selectedPath.Trim().Trim('"'))
    }
    Write-Host
}

$DestinationRoot = [IO.Path]::GetFullPath($InstallPath)
$destinationPathRoot = [IO.Path]::GetPathRoot($DestinationRoot)
if (-not $DestinationRoot.Equals($destinationPathRoot, [StringComparison]::OrdinalIgnoreCase)) {
    $DestinationRoot = $DestinationRoot.TrimEnd('\')
}

if ([string]::IsNullOrWhiteSpace($DestinationRoot) -or $DestinationRoot.Equals($destinationPathRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Ruta de instalación no válida: $DestinationRoot"
}

$requiredSourceFiles = @(
    'Hermes Manager.cmd', 'hermes.cmd',
    'HermesManager.ps1', 'settings.json', 'README.md', 'README.es.md',
    'LICENSE', 'NOTICE.md', 'CHANGELOG.md', 'SECURITY.md', 'CONTRIBUTING.md'
)
foreach ($relative in $requiredSourceFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot $relative) -PathType Leaf)) {
        throw "El paquete está incompleto: falta $relative"
    }
}

$markerPath = Join-Path $DestinationRoot '.hermes-manager-install.json'
if (Test-Path -LiteralPath $DestinationRoot) {
    $existingItems = @(Get-ChildItem -Force -LiteralPath $DestinationRoot -ErrorAction Stop)
    if ($existingItems.Count -gt 0 -and $DestinationRoot -ne $SourceRoot) {
        try {
            $existingMarker = Get-Content -Raw -Encoding UTF8 -LiteralPath $markerPath | ConvertFrom-Json
            $markerInstallPath = [IO.Path]::GetFullPath([string]$existingMarker.install_path).TrimEnd('\')
            $validMarker = $existingMarker.schema -eq 1 -and
                $existingMarker.product -eq 'Hermes Manager for Windows' -and
                $markerInstallPath.Equals($DestinationRoot, [StringComparison]::OrdinalIgnoreCase)
        } catch {
            $validMarker = $false
        }
        if (-not $validMarker) {
            throw "La carpeta de destino no está vacía y no es una instalación reconocida: $DestinationRoot"
        }
    }
} else {
    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
}

$copyFiles = $requiredSourceFiles + @(
    'Instalar.cmd', 'Desinstalar.cmd', 'Activar alias globales.cmd',
    'Activar alias globales.ps1', 'GUIA-INSTALACION.md', '.gitignore'
)
$copyDirectories = @('src', 'scripts', 'tests')

if ($DestinationRoot -ne $SourceRoot) {
    foreach ($relative in $copyFiles) {
        $source = Join-Path $SourceRoot $relative
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $DestinationRoot $relative) -Force
        }
    }
    foreach ($relative in $copyDirectories) {
        $source = Join-Path $SourceRoot $relative
        $destination = Join-Path $DestinationRoot $relative
        if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
        Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    }
}

$modulePath = Join-Path $DestinationRoot 'src\HermesManager.psm1'
Import-Module $modulePath -Force
Initialize-HermesLayout -Root $DestinationRoot | Out-Null
$version = Get-HermesManagerVersion

$globalLauncher = @'
@echo off
setlocal
call "%~dp0..\Hermes Manager.cmd" %*
exit /b %ERRORLEVEL%
'@
$encoding = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $DestinationRoot 'bin\hermes-manager.cmd'), $globalLauncher.TrimStart() + "`r`n", $encoding)

if (-not $NoPath) {
    Install-HermesAliasPath -Root $DestinationRoot | Out-Null
}

if (-not $NoShortcut) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    if ($desktop) {
        $shortcutPath = Join-Path $desktop 'Hermes Manager.lnk'
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = Join-Path $DestinationRoot 'Hermes Manager.cmd'
        $shortcut.WorkingDirectory = $DestinationRoot
        $shortcut.Description = 'Abrir Hermes Manager'
        $shortcut.Save()
    }
}

$marker = [ordered]@{
    schema = 1
    product = 'Hermes Manager for Windows'
    version = $version
    installed_at = [DateTime]::UtcNow.ToString('o')
    install_path = $DestinationRoot
}
[IO.File]::WriteAllText($markerPath, (($marker | ConvertTo-Json -Depth 4) + "`n"), $encoding)

if (-not $NoTests) {
    $testScript = Join-Path $DestinationRoot 'tests\Test-HermesManager.ps1'
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $testScript
    if ($LASTEXITCODE -ne 0) { throw 'Las pruebas de Hermes Manager han fallado.' }
}

Write-Host
Write-Host 'HERMES MANAGER INSTALADO CORRECTAMENTE' -ForegroundColor Green
Write-Host "Versión: $version"
Write-Host "Carpeta: $DestinationRoot"
Write-Host 'Abre una terminal nueva y escribe: hermes-manager'
Write-Host 'También puedes utilizar el acceso directo del escritorio.'
