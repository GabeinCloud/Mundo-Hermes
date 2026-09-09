[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProjectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
$script:Passed = 0
$script:Failed = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:Passed++
        Write-Host "PASS: $Name" -ForegroundColor Green
    } else {
        $script:Failed++
        Write-Host "FAIL: $Name" -ForegroundColor Red
    }
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Name)
    Assert-True -Condition ($Actual -eq $Expected) -Name "$Name (esperado='$Expected', real='$Actual')"
}

$requiredFiles = @(
    'Instalar.cmd', 'Desinstalar.cmd', 'Hermes Manager.cmd', 'hermes.cmd',
    'HermesManager.ps1', 'settings.json', 'README.md', 'README.en.md',
    'GUIA-INSTALACION.md', 'LICENSE', 'NOTICE.md', 'SECURITY.md',
    'CONTRIBUTING.md', 'CHANGELOG.md', 'src\HermesManager.psm1',
    'scripts\Install-HermesManager.ps1', 'scripts\Uninstall-HermesManager.ps1',
    'scripts\Build-Release.ps1', '.github\workflows\test.yml'
)
foreach ($relative in $requiredFiles) {
    Assert-True (Test-Path -LiteralPath (Join-Path $ProjectRoot $relative) -PathType Leaf) "Archivo público presente: $relative"
}

foreach ($runtimeDirectory in @('agents', 'bin', 'logs', 'trash')) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $runtimeDirectory))) "Repositorio limpio sin $runtimeDirectory"
}

$imagePayloads = @(Get-ChildItem -Force -Recurse -File -LiteralPath $ProjectRoot | Where-Object {
    $_.Name -match '(?i)\.(?:tar|tar\.gz|tgz|img|vhd|vhdx|qcow2)$' -or $_.Name -eq 'oci-layout'
})
Assert-Equal $imagePayloads.Count 0 'Repositorio sin imágenes ni exportaciones de contenedores'

$textFiles = @(Get-ChildItem -Force -Recurse -File -LiteralPath $ProjectRoot | Where-Object {
    $_.Extension -in @('.ps1', '.psm1', '.cmd', '.md', '.json', '.yml', '.gitignore', '.gitattributes') -or $_.Name -in @('LICENSE')
})
$personalPatterns = @(
    ('C:' + '\Mundo Hermes'),
    ('C:' + '\Mundo-Hermes'),
    ('C:' + '\Users\' + 'Gabe')
)
foreach ($pattern in $personalPatterns) {
    $matches = @($textFiles | Select-String -SimpleMatch $pattern -ErrorAction SilentlyContinue)
    Assert-Equal $matches.Count 0 "Sin ruta personal: $pattern"
}

$parseTargets = @($textFiles | Where-Object { $_.Extension -in @('.ps1', '.psm1') })
foreach ($target in $parseTargets) {
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($target.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    Assert-Equal $errors.Count 0 "Sintaxis PowerShell: $($target.Name)"
}

$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hermes-manager-public-test-' + [Guid]::NewGuid().ToString('N'))
$InstallRoot = Join-Path $TempRoot 'installed'
$InteractiveInstallRoot = Join-Path $TempRoot 'installed in chosen folder'
$ReleaseInstallRoot = Join-Path $TempRoot 'installed-from-release'
$ReleaseRoot = Join-Path $TempRoot 'release'
$ExpandedRoot = Join-Path $TempRoot 'expanded'
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

try {
    $installer = Join-Path $ProjectRoot 'scripts\Install-HermesManager.ps1'
    Write-Output $InteractiveInstallRoot | & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $installer -ChooseInstallPath -NoPath -NoShortcut -NoTests
    if ($LASTEXITCODE -ne 0) { throw "La instalación interactiva terminó con código $LASTEXITCODE" }
    Assert-True (Test-Path -LiteralPath (Join-Path $InteractiveInstallRoot '.hermes-manager-install.json')) 'Permite elegir una carpeta de instalación'

    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $installer -InstallPath $InstallRoot -NoPath -NoShortcut -NoTests
    if ($LASTEXITCODE -ne 0) { throw "El instalador terminó con código $LASTEXITCODE" }

    Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot '.hermes-manager-install.json')) 'Instalación crea marcador verificable'
    Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'bin\hermes-manager.cmd')) 'Instalación crea comando global'
    foreach ($runtimeDirectory in @('agents', 'bin', 'logs', 'trash')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot $runtimeDirectory) -PathType Container) "Instalación crea $runtimeDirectory"
    }
    Assert-Equal @(Get-ChildItem -Force -LiteralPath (Join-Path $InstallRoot 'agents')).Count 0 'Instalación comienza sin agentes'

    $unsafeRoot = Join-Path $TempRoot 'carpeta-ajena'
    $unsafeSource = Join-Path $unsafeRoot 'src'
    New-Item -ItemType Directory -Path $unsafeSource -Force | Out-Null
    $unsafeSentinel = Join-Path $unsafeSource 'no-borrar.txt'
    [IO.File]::WriteAllText($unsafeSentinel, 'conservar', [Text.UTF8Encoding]::new($false))
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $installer -InstallPath $unsafeRoot -NoPath -NoShortcut -NoTests -Force 2>$null
    $unsafeInstallExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    Assert-True ($unsafeInstallExitCode -ne 0) 'El instalador rechaza -Force sobre una carpeta ajena'
    Assert-True (Test-Path -LiteralPath $unsafeSentinel) 'El instalador no modifica una carpeta ajena'

    $markerPath = Join-Path $InstallRoot '.hermes-manager-install.json'
    $originalMarker = Get-Content -Raw -Encoding UTF8 -LiteralPath $markerPath
    $alteredMarker = $originalMarker | ConvertFrom-Json
    $alteredMarker.product = 'Otro producto'
    [IO.File]::WriteAllText($markerPath, (($alteredMarker | ConvertTo-Json -Depth 4) + "`n"), [Text.UTF8Encoding]::new($false))
    $uninstaller = Join-Path $InstallRoot 'scripts\Uninstall-HermesManager.ps1'
    $ErrorActionPreference = 'Continue'
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $uninstaller 2>$null
    $alteredMarkerExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    Assert-True ($alteredMarkerExitCode -ne 0) 'El desinstalador rechaza un marcador alterado'
    Assert-True (Test-Path -LiteralPath $InstallRoot) 'Un marcador alterado no permite borrar la instalación'
    [IO.File]::WriteAllText($markerPath, $originalMarker, [Text.UTF8Encoding]::new($false))

    $sentinelDirectory = Join-Path $InstallRoot 'agents\preservar\data'
    New-Item -ItemType Directory -Path $sentinelDirectory -Force | Out-Null
    $sentinelPath = Join-Path $sentinelDirectory 'sentinel.txt'
    [IO.File]::WriteAllText($sentinelPath, 'preservar', [Text.UTF8Encoding]::new($false))
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $installer -InstallPath $InstallRoot -NoPath -NoShortcut -NoTests
    if ($LASTEXITCODE -ne 0) { throw "La actualización terminó con código $LASTEXITCODE" }
    Assert-True (Test-Path -LiteralPath $sentinelPath) 'Actualizar preserva los datos de agentes'

    $builder = Join-Path $ProjectRoot 'scripts\Build-Release.ps1'
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $builder -OutputDirectory $ReleaseRoot
    if ($LASTEXITCODE -ne 0) { throw "El generador de Release terminó con código $LASTEXITCODE" }
    $zip = Get-ChildItem -LiteralPath $ReleaseRoot -Filter '*.zip' -File | Select-Object -First 1
    Assert-True ($null -ne $zip) 'Genera ZIP de Release'
    Assert-True (Test-Path -LiteralPath ($zip.FullName + '.sha256')) 'Genera checksum SHA-256'

    Expand-Archive -LiteralPath $zip.FullName -DestinationPath $ExpandedRoot
    $entries = @(Get-ChildItem -Force -Recurse -LiteralPath $ExpandedRoot)
    $forbiddenNames = @('agents', 'bin', 'logs', 'trash', '.git', '.env', 'config.yaml', '.hermes-manager-install.json')
    foreach ($name in $forbiddenNames) {
        $found = @($entries | Where-Object { $_.Name -eq $name })
        Assert-Equal $found.Count 0 "Release excluye $name"
    }
    $releaseImagePayloads = @($entries | Where-Object {
        -not $_.PSIsContainer -and ($_.Name -match '(?i)\.(?:tar|tar\.gz|tgz|img|vhd|vhdx|qcow2)$' -or $_.Name -eq 'oci-layout')
    })
    Assert-Equal $releaseImagePayloads.Count 0 'Release sin imágenes ni exportaciones de contenedores'
    Assert-True (@($entries | Where-Object { $_.Name -eq 'Instalar.cmd' }).Count -eq 1) 'Release contiene instalador'
    Assert-True (@($entries | Where-Object { $_.Name -eq 'README.md' }).Count -eq 1) 'Release contiene README'

    $releasePackageRoot = Get-ChildItem -LiteralPath $ExpandedRoot -Directory | Where-Object {
        $_.Name -like 'Hermes-Manager-Windows-*'
    } | Select-Object -First 1
    Assert-True ($null -ne $releasePackageRoot) 'Release contiene una raíz versionada'
    if ($releasePackageRoot) {
        $releaseInstaller = Join-Path $releasePackageRoot.FullName 'scripts\Install-HermesManager.ps1'
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $releaseInstaller -InstallPath $ReleaseInstallRoot -NoPath -NoShortcut -NoTests
        if ($LASTEXITCODE -ne 0) { throw "La instalación desde el ZIP terminó con código $LASTEXITCODE" }
        Assert-True (Test-Path -LiteralPath (Join-Path $ReleaseInstallRoot '.hermes-manager-install.json')) 'El ZIP publicado se instala correctamente'
    }

    $expectedHash = (Get-Content -Raw -LiteralPath ($zip.FullName + '.sha256')).Split(' ')[0].Trim()
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip.FullName).Hash.ToLowerInvariant()
    Assert-Equal $actualHash $expectedHash 'Checksum publicado coincide con el ZIP'
} finally {
    $resolvedTemp = [IO.Path]::GetFullPath($TempRoot)
    if ($resolvedTemp.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedTemp) -like 'hermes-manager-public-test-*' -and
        (Test-Path -LiteralPath $resolvedTemp)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

Write-Host
Write-Host ("RESULTADO PAQUETE PÚBLICO: {0}/{1} PASS" -f $script:Passed, ($script:Passed + $script:Failed)) -ForegroundColor Cyan
if ($script:Failed -gt 0) { exit 1 }
exit 0
