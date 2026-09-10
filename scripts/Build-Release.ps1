[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [string]$Version,
    [ValidateSet('all', 'es', 'en')][string]$Language = 'all'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $ProjectRoot 'artifacts' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\')

Import-Module (Join-Path $ProjectRoot 'src\HermesManager.psm1') -Force
if (-not $Version) { $Version = Get-HermesManagerVersion }
if ($Version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') { throw "Versión no válida: $Version" }

if (-not (Test-Path -LiteralPath $OutputDirectory)) { New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null }

function New-HermesReleasePackage {
    param([ValidateSet('es', 'en')][string]$PackageLanguage)

    $languageName = if ($PackageLanguage -eq 'en') { 'English' } else { 'Spanish' }
    $packageName = "Hermes-Manager-Windows-$Version-$languageName"
    $stagingRoot = Join-Path $OutputDirectory $packageName
    $zipPath = Join-Path $OutputDirectory "$packageName.zip"
    $hashPath = "$zipPath.sha256"

    foreach ($path in @($stagingRoot, $zipPath, $hashPath)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
    }
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

    $fileMap = if ($PackageLanguage -eq 'en') {
        @(
            @('LICENSE', 'LICENSE'),
            @('NOTICE.en.md', 'NOTICE.en.md'), @('README.md', 'README.md'),
            @('INSTALLATION-GUIDE.md', 'INSTALLATION-GUIDE.md'), @('SECURITY.en.md', 'SECURITY.en.md'),
            @('Install (English).cmd', 'Install.cmd'), @('Uninstall (English).cmd', 'Uninstall.cmd'),
            @('Activate global aliases (English).cmd', 'Activate global aliases.cmd'),
            @('Activate global aliases.ps1', 'Activate global aliases.ps1'),
            @('Hermes Manager (English).cmd', 'Hermes Manager.cmd'), @('hermes-en.cmd', 'hermes-en.cmd'),
            @('HermesManager.ps1', 'HermesManager.ps1'), @('settings.json', 'settings.json')
        )
    } else {
        @(
            @('.gitignore', '.gitignore'), @('LICENSE', 'LICENSE'), @('NOTICE.md', 'NOTICE.md'),
            @('README.es.md', 'README.md'), @('GUIA-INSTALACION.md', 'GUIA-INSTALACION.md'),
            @('SECURITY.md', 'SECURITY.md'), @('Instalar.cmd', 'Instalar.cmd'),
            @('Desinstalar.cmd', 'Desinstalar.cmd'), @('Activar alias globales.cmd', 'Activar alias globales.cmd'),
            @('Activar alias globales.ps1', 'Activar alias globales.ps1'),
            @('Hermes Manager.cmd', 'Hermes Manager.cmd'), @('hermes.cmd', 'hermes.cmd'),
            @('HermesManager.ps1', 'HermesManager.ps1'), @('settings.json', 'settings.json')
        )
    }

    foreach ($mapping in $fileMap) {
        $source = Join-Path $ProjectRoot $mapping[0]
        $destination = Join-Path $stagingRoot $mapping[1]
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Falta el archivo requerido: $($mapping[0])" }
        Copy-Item -LiteralPath $source -Destination $destination
    }
    if ($PackageLanguage -eq 'en') {
        $readmePath = Join-Path $stagingRoot 'README.md'
        $readme = Get-Content -Raw -Encoding UTF8 -LiteralPath $readmePath
        $readme = $readme -replace '(?m)^\[Español\]\(README\.es\.md\)\r?\n\r?\n', ''
        $readme = $readme -replace '(?s)\r?\n## Development\r?\n.*?(?=\r?\n## Security and license)', ''
        [IO.File]::WriteAllText($readmePath, $readme, [Text.UTF8Encoding]::new($false))
    }

    foreach ($directory in @('src', 'scripts')) {
        New-Item -ItemType Directory -Path (Join-Path $stagingRoot $directory) -Force | Out-Null
    }
    foreach ($relative in @('src\HermesManager.psm1', 'src\HermesLocalization.ps1',
            'scripts\Install-HermesManager.ps1', 'scripts\Uninstall-HermesManager.ps1')) {
        Copy-Item -LiteralPath (Join-Path $ProjectRoot $relative) -Destination (Join-Path $stagingRoot $relative)
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

    Write-Host "RELEASE_BUILD_PASS ($languageName)" -ForegroundColor Green
    Write-Host "ZIP: $zipPath"
    Write-Host "SHA256: $($hash.Hash.ToLowerInvariant())"
    return [pscustomobject]@{ Language = $PackageLanguage; Zip = $zipPath; HashFile = $hashPath; SHA256 = $hash.Hash.ToLowerInvariant() }
}

$languages = if ($Language -eq 'all') { @('es', 'en') } else { @($Language) }
return @($languages | ForEach-Object { New-HermesReleasePackage -PackageLanguage $_ })
