[CmdletBinding()]
param(
    [switch]$RemoveAllData,
    [ValidateSet('es', 'en')][string]$Language = 'es'
)

$ErrorActionPreference = 'Stop'
$InstallRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
. (Join-Path $InstallRoot 'src\HermesLocalization.ps1')
Set-HermesLanguage -Language $Language
$env:HERMES_MANAGER_LANGUAGE = $Language

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

function Stop-HermesUninstallation {
    param([Parameter(Mandatory)][string]$Message)
    throw (ConvertTo-HermesLocalizedText -Text $Message)
}
$installPathRoot = [IO.Path]::GetPathRoot($InstallRoot)
if (-not $InstallRoot.Equals($installPathRoot, [StringComparison]::OrdinalIgnoreCase)) {
    $InstallRoot = $InstallRoot.TrimEnd('\')
}
$markerPath = Join-Path $InstallRoot '.hermes-manager-install.json'
if (-not (Test-Path -LiteralPath $markerPath)) {
    Stop-HermesUninstallation "No es una instalación reconocida de Hermes Manager: $InstallRoot"
}
try {
    $marker = Get-Content -Raw -Encoding UTF8 -LiteralPath $markerPath | ConvertFrom-Json
    $markerInstallPath = [IO.Path]::GetFullPath([string]$marker.install_path).TrimEnd('\')
} catch {
    Stop-HermesUninstallation "El marcador de instalación no es válido: $markerPath"
}
if ($marker.schema -ne 1 -or
    $marker.product -ne 'Hermes Manager for Windows' -or
    -not $markerInstallPath.Equals($InstallRoot, [StringComparison]::OrdinalIgnoreCase)) {
    Stop-HermesUninstallation "El marcador no corresponde a esta instalación: $markerPath"
}
foreach ($relative in @('HermesManager.ps1', 'src\HermesManager.psm1', 'scripts\Uninstall-HermesManager.ps1')) {
    if (-not (Test-Path -LiteralPath (Join-Path $InstallRoot $relative) -PathType Leaf)) {
        Stop-HermesUninstallation "La instalación está incompleta; no se borrará la carpeta: falta $relative"
    }
}

if ($RemoveAllData) {
    if ($InstallRoot.Equals($installPathRoot, [StringComparison]::OrdinalIgnoreCase)) {
        Stop-HermesUninstallation "Se rechazó el borrado de una raíz de unidad: $InstallRoot"
    }
    $protectedRoots = @(
        $env:USERPROFILE, $env:LOCALAPPDATA, $env:APPDATA,
        $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:SystemRoot,
        [IO.Path]::GetTempPath().TrimEnd('\')
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        [IO.Path]::GetFullPath($_).TrimEnd('\')
    }
    if (@($protectedRoots | Where-Object { $_.Equals($InstallRoot, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0) {
        Stop-HermesUninstallation "Se rechazó el borrado de una ruta protegida: $InstallRoot"
    }
    $installItem = Get-Item -Force -LiteralPath $InstallRoot
    if (($installItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        Stop-HermesUninstallation "Se rechazó el borrado de un enlace o punto de reanálisis: $InstallRoot"
    }
}

$modulePath = Join-Path $InstallRoot 'src\HermesManager.psm1'
Import-Module $modulePath -Force
$agents = @(Get-HermesAgents -Root $InstallRoot)

Write-Host $(if ($Language -eq 'en') { 'Hermes Manager will be removed from PATH and its shortcut will be deleted.' } else { 'Hermes Manager se retirará del PATH y se eliminará el acceso directo.' }) -ForegroundColor Yellow
if ($agents.Count) {
    Write-Host $(if ($Language -eq 'en') { "This installation has $($agents.Count) agent(s)." } else { "Hay $($agents.Count) agente(s) en esta instalación." })
    if (-not $RemoveAllData) {
        Write-Host $(if ($Language -eq 'en') { 'Data will NOT be deleted. Use -RemoveAllData only after making a backup.' } else { 'Los datos NO se eliminarán. Utiliza -RemoveAllData únicamente después de crear una copia de seguridad.' }) -ForegroundColor Yellow
    }
}

$confirmation = Read-Host $(if ($Language -eq 'en') { 'Type UNINSTALL to continue' } else { 'Escribe DESINSTALAR para continuar' })
$expectedConfirmation = if ($Language -eq 'en') { 'UNINSTALL' } else { 'DESINSTALAR' }
if ($confirmation -cne $expectedConfirmation) {
    Write-Host $(if ($Language -eq 'en') { 'Operation cancelled.' } else { 'Operación cancelada.' })
    exit 0
}

if ($RemoveAllData -and $agents.Count) {
    $dataConfirmation = Read-Host $(if ($Language -eq 'en') { 'Type DELETE DATA to permanently delete all agents' } else { 'Escribe ELIMINAR DATOS para borrar permanentemente todos los agentes' })
    $expectedDataConfirmation = if ($Language -eq 'en') { 'DELETE DATA' } else { 'ELIMINAR DATOS' }
    if ($dataConfirmation -cne $expectedDataConfirmation) { Stop-HermesUninstallation 'No se confirmó el borrado de datos.' }
    foreach ($agent in $agents) { Stop-HermesAgent -Name $agent.Name -Root $InstallRoot }
}

$binPath = Get-HermesBinPath -Root $InstallRoot
$userPath = [string][Environment]::GetEnvironmentVariable('Path', 'User')
$remaining = @($userPath -split ';' | Where-Object {
    -not [string]::IsNullOrWhiteSpace($_) -and
    -not $_.Trim().TrimEnd('\').Equals($binPath, [StringComparison]::OrdinalIgnoreCase)
})
[Environment]::SetEnvironmentVariable('Path', $(if ($remaining.Count) { ($remaining -join ';') + ';' } else { $null }), 'User')

$shortcutPaths = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Hermes Manager.lnk'),
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Hermes Manager (English).lnk')
)
foreach ($shortcutPath in $shortcutPaths) {
    if (Test-Path -LiteralPath $shortcutPath) { Remove-Item -LiteralPath $shortcutPath -Force }
}

if ($RemoveAllData) {
    Remove-Item -LiteralPath $InstallRoot -Recurse -Force
    Write-Host $(if ($Language -eq 'en') { 'Hermes Manager and all its data were deleted.' } else { 'Hermes Manager y todos sus datos fueron eliminados.' }) -ForegroundColor Green
} else {
    Write-Host $(if ($Language -eq 'en') { 'Global access removed. The folder and agents were kept:' } else { 'Accesos globales eliminados. La carpeta y los agentes se conservaron:' }) -ForegroundColor Green
    Write-Host $InstallRoot
}
