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

function Invoke-CapturedPowerShell {
    param([Parameter(Mandatory)][string]$Arguments, [string[]]$InputLines = @())

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = 'powershell.exe'
    $startInfo.Arguments = $Arguments
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    foreach ($line in $InputLines) { $process.StandardInput.WriteLine($line) }
    $process.StandardInput.Close()
    $output = $process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return [pscustomobject]@{ Output = $output; ExitCode = $process.ExitCode }
}

$requiredFiles = @(
    'Instalar.cmd', 'Desinstalar.cmd', 'Hermes Manager.cmd', 'hermes.cmd',
    'Install (English).cmd', 'Uninstall (English).cmd',
    'Hermes Manager (English).cmd', 'hermes-en.cmd',
    'Activate global aliases (English).cmd',
    'HermesManager.ps1', 'settings.json', 'README.md', 'README.es.md',
    'GUIA-INSTALACION.md', 'LICENSE', 'NOTICE.md', 'SECURITY.md',
    'INSTALLATION-GUIDE.md', 'NOTICE.en.md', 'SECURITY.en.md',
    'CONTRIBUTING.md', 'CHANGELOG.md', 'src\HermesManager.psm1',
    'scripts\Install-HermesManager.ps1', 'scripts\Uninstall-HermesManager.ps1',
    'scripts\Build-Release.ps1', 'src\HermesLocalization.ps1', '.github\workflows\test.yml'
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
$EnglishReleaseInstallRoot = Join-Path $TempRoot 'installed-from-english-release'
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
    $zips = @(Get-ChildItem -LiteralPath $ReleaseRoot -Filter '*.zip' -File)
    Assert-Equal $zips.Count 2 'Genera los ZIP de Release en español e inglés'
    foreach ($zip in $zips) {
        Assert-True (Test-Path -LiteralPath ($zip.FullName + '.sha256')) "Genera checksum SHA-256 para $($zip.Name)"
        $expectedHash = (Get-Content -Raw -LiteralPath ($zip.FullName + '.sha256')).Split(' ')[0].Trim()
        $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip.FullName).Hash.ToLowerInvariant()
        Assert-Equal $actualHash $expectedHash "Checksum publicado coincide: $($zip.Name)"
    }

    $spanishZip = @($zips | Where-Object Name -like '*-Spanish.zip')[0]
    $englishZip = @($zips | Where-Object Name -like '*-English.zip')[0]
    Assert-True ($null -ne $spanishZip) 'Genera paquete español'
    Assert-True ($null -ne $englishZip) 'Genera paquete inglés'

    $spanishExpandedRoot = Join-Path $ExpandedRoot 'Spanish'
    $englishExpandedRoot = Join-Path $ExpandedRoot 'English'
    Expand-Archive -LiteralPath $spanishZip.FullName -DestinationPath $spanishExpandedRoot
    Expand-Archive -LiteralPath $englishZip.FullName -DestinationPath $englishExpandedRoot
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
    $spanishPackageRoot = Get-ChildItem -LiteralPath $spanishExpandedRoot -Directory | Select-Object -First 1
    $englishPackageRoot = Get-ChildItem -LiteralPath $englishExpandedRoot -Directory | Select-Object -First 1
    Assert-True (Test-Path -LiteralPath (Join-Path $spanishPackageRoot.FullName 'Instalar.cmd')) 'Paquete español contiene Instalar.cmd'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $spanishPackageRoot.FullName 'Install.cmd'))) 'Paquete español excluye Install.cmd'
    Assert-True (Test-Path -LiteralPath (Join-Path $englishPackageRoot.FullName 'Install.cmd')) 'Paquete inglés contiene Install.cmd'
    Assert-True (Test-Path -LiteralPath (Join-Path $englishPackageRoot.FullName 'INSTALLATION-GUIDE.md')) 'Paquete inglés contiene guía inglesa'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $englishPackageRoot.FullName 'Instalar.cmd'))) 'Paquete inglés excluye Instalar.cmd'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $englishPackageRoot.FullName 'README.es.md'))) 'Paquete inglés excluye README español'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $englishPackageRoot.FullName 'GUIA-INSTALACION.md'))) 'Paquete inglés excluye guía española'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $englishPackageRoot.FullName 'tests'))) 'Paquete inglés excluye pruebas españolas'

    if ($spanishPackageRoot) {
        $releaseInstaller = Join-Path $spanishPackageRoot.FullName 'scripts\Install-HermesManager.ps1'
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $releaseInstaller -InstallPath $ReleaseInstallRoot -Language es -NoPath -NoShortcut -NoTests
        if ($LASTEXITCODE -ne 0) { throw "La instalación desde el ZIP terminó con código $LASTEXITCODE" }
        Assert-True (Test-Path -LiteralPath (Join-Path $ReleaseInstallRoot '.hermes-manager-install.json')) 'El ZIP español se instala correctamente'
    }
    if ($englishPackageRoot) {
        $releaseInstaller = Join-Path $englishPackageRoot.FullName 'scripts\Install-HermesManager.ps1'
        $englishOutput = @(& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $releaseInstaller -InstallPath $EnglishReleaseInstallRoot -Language en -NoPath -NoShortcut -NoTests 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "La instalación desde el ZIP inglés terminó con código $LASTEXITCODE" }
        Assert-True (Test-Path -LiteralPath (Join-Path $EnglishReleaseInstallRoot '.hermes-manager-install.json')) 'El ZIP inglés se instala correctamente'
        Assert-True (($englishOutput -join "`n") -match 'INSTALLED SUCCESSFULLY') 'Instalador inglés muestra confirmación en inglés'
        Assert-True (($englishOutput -join "`n") -notmatch 'INSTALADO|Versión|Carpeta|También|Pulsa|Escribe') 'Instalador inglés no muestra mensajes españoles'

        $managerScript = Join-Path $EnglishReleaseInstallRoot 'HermesManager.ps1'
        $englishMenuResult = Invoke-CapturedPowerShell -Arguments "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$managerScript`" menu -Language en" -InputLines @('0')
        $englishMenu = $englishMenuResult.Output
        Assert-Equal $englishMenuResult.ExitCode 0 'Menú inglés termina correctamente'
        Assert-True ($englishMenu -match 'Create agent' -and $englishMenu -match 'Open conversation' -and $englishMenu -match 'Diagnostics' -and $englishMenu -match 'Exit') 'Menú inglés muestra todas sus opciones en inglés'
        Assert-True ($englishMenu -notmatch 'Crear agente|Abrir conversación|Elige una opción|Diagnóstico|Salir') 'Menú inglés no muestra opciones españolas'

        $englishError = @(& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $EnglishReleaseInstallRoot 'HermesManager.ps1') start missing-agent -Language en 2>&1) -join "`n"
        Assert-True ($englishError -match "Agent 'missing-agent' does not exist") 'Errores del gestor inglés están traducidos'

        Import-Module (Join-Path $EnglishReleaseInstallRoot 'src\HermesManager.psm1') -Force
        New-HermesAgentFiles -Name 'Writer' -Purpose 'Draft articles.' -Root $EnglishReleaseInstallRoot -Language en | Out-Null
        New-HermesAgentAlias -Name 'writer' -Alias 'writer' -Root $EnglishReleaseInstallRoot -SkipPathRegistration | Out-Null
        $englishSoul = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $EnglishReleaseInstallRoot 'agents\writer\data\SOUL.md')
        $englishEnvironment = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $EnglishReleaseInstallRoot 'agents\writer\data\.env')
        $englishAlias = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $EnglishReleaseInstallRoot 'bin\writer.cmd')
        Assert-True ($englishSoul -match '## Purpose' -and $englishSoul -match '## Working style') 'Agentes ingleses generan SOUL.md en inglés'
        Assert-True ($englishEnvironment -match 'This file remains inside the agent folder') 'Agentes ingleses generan comentarios de entorno en inglés'
        Assert-True ($englishAlias -match 'hermes-en\.cmd" chat writer') 'Alias inglés utiliza comando inglés'

        $englishUninstaller = Join-Path $EnglishReleaseInstallRoot 'scripts\Uninstall-HermesManager.ps1'
        $englishUninstallResult = Invoke-CapturedPowerShell -Arguments "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$englishUninstaller`" -Language en" -InputLines @('CANCEL')
        Assert-Equal $englishUninstallResult.ExitCode 0 'Desinstalador inglés permite cancelar'
        Assert-True ($englishUninstallResult.Output -match 'Operation cancelled') 'Desinstalador inglés muestra resultado en inglés'
        Assert-True ($englishUninstallResult.Output -notmatch 'Operación|carpeta|agente|datos|Escribe') 'Desinstalador inglés no muestra mensajes españoles'

        $englishUserFiles = @('README.md', 'INSTALLATION-GUIDE.md', 'SECURITY.en.md', 'NOTICE.en.md',
            'Install.cmd', 'Uninstall.cmd', 'Hermes Manager.cmd', 'Activate global aliases.cmd', 'Activate global aliases.ps1')
        $englishUserText = ($englishUserFiles | ForEach-Object {
            Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $englishPackageRoot.FullName $_)
        }) -join "`n"
        Assert-True ($englishUserText -notmatch 'Instalar\.cmd|Desinstalar\.cmd|Abrir conversación|Crear agente|Elige una opción|GUIA-INSTALACION|README\.es') 'Archivos de usuario ingleses no remiten a la variante española'
    }
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
