[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $ProjectRoot 'artifacts' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\')

Import-Module (Join-Path $ProjectRoot 'src\HermesManager.psm1') -Force
if (-not $Version) { $Version = Get-HermesManagerVersion }
if ($Version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') { throw "Versión no válida: $Version" }

$packageName = "Hermes-Manager-Windows-$Version"
$stagingRoot = Join-Path $OutputDirectory $packageName
$zipPath = Join-Path $OutputDirectory "$packageName.zip"
$hashPath = "$zipPath.sha256"

if (-not (Test-Path -LiteralPath $OutputDirectory)) { New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null }
foreach ($path in @($stagingRoot, $zipPath, $hashPath)) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
}
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

$files = @(
    '.gitignore', 'LICENSE', 'NOTICE.md', 'README.md', 'README.es.md',
    'GUIA-INSTALACION.md', 'SECURITY.md', 'CONTRIBUTING.md', 'CHANGELOG.md',
    'Instalar.cmd', 'Desinstalar.cmd', 'Activar alias globales.cmd',
    'Activar alias globales.ps1', 'Hermes Manager.cmd',
    'hermes.cmd', 'HermesManager.ps1', 'settings.json',
    'Install (English).cmd', 'Uninstall (English).cmd',
    'Activate global aliases (English).cmd',
    'Hermes Manager (English).cmd', 'hermes-en.cmd'
)
foreach ($relative in $files) {
    $source = Join-Path $ProjectRoot $relative
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Falta el archivo requerido: $relative" }
    Copy-Item -LiteralPath $source -Destination (Join-Path $stagingRoot $relative)
}
foreach ($relative in @('src', 'scripts', 'tests')) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot $relative) -Destination (Join-Path $stagingRoot $relative) -Recurse
}

$forbidden = @('agents', 'bin', 'logs', 'trash', '.git', '.env', '.hermes-manager-install.json', 'config.yaml')
$stagedItems = @(Get-ChildItem -Force -Recurse -LiteralPath $stagingRoot)
foreach ($item in $stagedItems) {
    $relative = $item.FullName.Substring($stagingRoot.Length).TrimStart('\')
    foreach ($name in $forbidden) {
        if (($relative -split '\\') -contains $name) { throw "Contenido privado prohibido en Release: $relative" }
    }
    if (-not $item.PSIsContainer -and
        ($item.Name -match '(?i)\.(?:tar|tar\.gz|tgz|img|vhd|vhdx|qcow2)$' -or $item.Name -eq 'oci-layout')) {
        throw "Una Release no puede incluir imágenes o exportaciones de contenedores: $relative"
    }
}

Compress-Archive -LiteralPath $stagingRoot -DestinationPath $zipPath -CompressionLevel Optimal
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath
[IO.File]::WriteAllText($hashPath, ($hash.Hash.ToLowerInvariant() + "  " + [IO.Path]::GetFileName($zipPath) + "`n"), [Text.UTF8Encoding]::new($false))
Remove-Item -LiteralPath $stagingRoot -Recurse -Force

Write-Host 'RELEASE_BUILD_PASS' -ForegroundColor Green
Write-Host "ZIP: $zipPath"
Write-Host "SHA256: $($hash.Hash.ToLowerInvariant())"
return [pscustomobject]@{ Zip = $zipPath; HashFile = $hashPath; SHA256 = $hash.Hash.ToLowerInvariant() }
