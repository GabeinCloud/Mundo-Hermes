[CmdletBinding()]
param(
    [string]$InstallPath = (Join-Path $env:LOCALAPPDATA 'HermesManager'),
    [switch]$ChooseInstallPath,
    [switch]$NoPath,
    [switch]$NoShortcut,
    [switch]$NoTests,
    [ValidateSet('es', 'en')][string]$Language = 'es'
)

$ErrorActionPreference = 'Stop'
$SourceRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
. (Join-Path $SourceRoot 'src\HermesLocalization.ps1')
Set-HermesLanguage -Language $Language

function Write-Host {
    param(
        [Parameter(Position = 0)][object[]]$Object,
        [switch]$NoNewline,
        [Nullable[ConsoleColor]]$ForegroundColor,
        [Nullable[ConsoleColor]]$BackgroundColor,
        [string]$Separator = ' '
    )
    Write-HermesLocalizedHost -Object $Object -NoNewline:$NoNewline -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor -Separator $Separator
}

function Read-Host {
    param([string]$Prompt)
    Read-HermesLocalizedHost -Prompt $Prompt
}

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
    'Hermes Manager (English).cmd', 'hermes-en.cmd',
    'Install (English).cmd', 'Uninstall (English).cmd',
    'Activate global aliases (English).cmd',
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
    'Activar alias globales.ps1', 'GUIA-INSTALACION.md', '.gitignore',
    'Install (English).cmd', 'Uninstall (English).cmd',
    'Activate global aliases (English).cmd', 'Hermes Manager (English).cmd',
    'hermes-en.cmd'
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
call "%~dp0..\__MANAGER_LAUNCHER__" %*
exit /b %ERRORLEVEL%
'@
$managerLauncher = if ($Language -eq 'en') { 'Hermes Manager (English).cmd' } else { 'Hermes Manager.cmd' }
$globalLauncher = $globalLauncher.Replace('__MANAGER_LAUNCHER__', $managerLauncher)
$encoding = [Text.UTF8Encoding]::new($false)
$globalCommand = if ($Language -eq 'en') { 'hermes-manager-en.cmd' } else { 'hermes-manager.cmd' }
[IO.File]::WriteAllText((Join-Path $DestinationRoot "bin\$globalCommand"), $globalLauncher.TrimStart() + "`r`n", $encoding)

if (-not $NoPath) {
    Install-HermesAliasPath -Root $DestinationRoot | Out-Null
}

if (-not $NoShortcut) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    if ($desktop) {
        $shortcutName = if ($Language -eq 'en') { 'Hermes Manager (English).lnk' } else { 'Hermes Manager.lnk' }
        $shortcutPath = Join-Path $desktop $shortcutName
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = Join-Path $DestinationRoot $managerLauncher
        $shortcut.WorkingDirectory = $DestinationRoot
        $shortcut.Description = if ($Language -eq 'en') { 'Open Hermes Manager' } else { 'Abrir Hermes Manager' }
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
