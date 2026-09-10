[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ModulePath = Join-Path $ProjectRoot 'src\HermesManager.psm1'
Import-Module $ModulePath -Force

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

$TemporaryBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$TestRoot = Join-Path $TemporaryBase ('hermes-manager-core-test-' + [Guid]::NewGuid().ToString('N'))

try {
    Initialize-HermesLayout -Root $TestRoot | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $TestRoot 'agents')) 'Crea el directorio agents'
    Assert-True (Test-Path -LiteralPath (Join-Path $TestRoot 'bin')) 'Crea el directorio de alias'
    Assert-True (Test-Path -LiteralPath (Join-Path $TestRoot 'logs')) 'Crea el directorio logs'
    Assert-True (Test-Path -LiteralPath (Join-Path $TestRoot 'trash')) 'Crea la papelera interna'
    Assert-True (Test-Path -LiteralPath (Join-Path $TestRoot 'settings.json')) 'Crea settings.json'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $TestRoot 'state'))) 'No crea directorios sin uso'

    Assert-Equal (ConvertTo-HermesAgentName -Name 'Publicación Ágil') 'publicacion-agil' 'Normaliza nombres Unicode'
    Assert-Equal (ConvertTo-HermesAgentName -Name '  Research Agent  ') 'research-agent' 'Normaliza espacios'

    $invalidRejected = $false
    try { ConvertTo-HermesAgentName -Name '!' | Out-Null } catch { $invalidRejected = $true }
    Assert-True $invalidRejected 'Rechaza identificadores inválidos'

    $agent = New-HermesAgentFiles -Name 'Publicación Ágil' -Purpose 'Preparar contenido para redes.' -Root $TestRoot
    Assert-Equal $agent.Name 'publicacion-agil' 'Devuelve el identificador creado'
    Assert-True (Test-Path -LiteralPath (Join-Path $agent.Path 'compose.yaml')) 'Genera compose.yaml'
    Assert-True (Test-Path -LiteralPath (Join-Path $agent.Path 'agent.json')) 'Genera metadatos'
    Assert-True (Test-Path -LiteralPath (Join-Path $agent.Path 'data\SOUL.md')) 'Genera identidad SOUL.md'
    Assert-True (Test-Path -LiteralPath (Join-Path $agent.Path 'data\.env')) 'Genera entorno privado'
    Assert-True (Test-Path -LiteralPath (Join-Path $agent.Path 'data\workspace')) 'Genera espacio persistente'

    $compose = Get-Content -Raw -LiteralPath (Join-Path $agent.Path 'compose.yaml')
    Assert-True ($compose -match 'name: hermes-publicacion-agil') 'Compose usa proyecto aislado'
    Assert-True ($compose -match 'container_name: hermes-publicacion-agil') 'Compose usa contenedor aislado'
    Assert-True ($compose -match '\./data:/opt/data:rw') 'Los datos se enlazan dentro del agente'
    Assert-True ($compose -match 'nousresearch/hermes-agent@sha256:41b9ed005cebcb3d3fb45206ce27cfb0356ba99b190c0924bab5141b15ad8e71') 'Compose fija la imagen predeterminada por digest'
    Assert-True ($compose -notmatch ':latest') 'Compose no usa etiquetas de imagen mutables'
    Assert-True ($compose -match 'no-new-privileges:true') 'Activa no-new-privileges'
    Assert-True ($compose -match 'cap_drop:\s*\r?\n\s*- ALL') 'Elimina capacidades por defecto'
    Assert-True ($compose -notmatch [regex]::Escape($TestRoot)) 'Compose no contiene rutas absolutas'

    $metadata = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $agent.Path 'agent.json') | ConvertFrom-Json
    Assert-Equal $metadata.purpose 'Preparar contenido para redes.' 'Conserva la finalidad'
    Assert-Equal $metadata.name 'publicacion-agil' 'Conserva el identificador'

    $agents = @(Get-HermesAgents -Root $TestRoot)
    Assert-Equal $agents.Count 1 'Lista agentes válidos'
    Assert-Equal $agents[0].DisplayName 'Publicación Ágil' 'Lista el nombre visible'

    $duplicateRejected = $false
    try { New-HermesAgentFiles -Name 'Publicación Ágil' -Purpose 'Duplicado' -Root $TestRoot | Out-Null } catch { $duplicateRejected = $true }
    Assert-True $duplicateRejected 'Rechaza agentes duplicados'

    $aliasResult = New-HermesAgentAlias -Name 'publicacion-agil' -Alias 'pub' -Root $TestRoot -SkipPathRegistration
    Assert-Equal $aliasResult.Alias 'pub' 'Crea un alias corto'
    Assert-True (Test-Path -LiteralPath (Join-Path $TestRoot 'bin\pub.cmd')) 'Genera el lanzador dentro de bin'
    $aliasLauncher = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $TestRoot 'bin\pub.cmd')
    Assert-True ($aliasLauncher -match 'hermes\.cmd" abrir publicacion-agil') 'El alias abre el agente correcto'
    Assert-Equal (Get-HermesAgent -Name 'publicacion-agil' -Root $TestRoot).TerminalAlias 'pub' 'Guarda el alias en los metadatos'

    $reservedRejected = $false
    try { New-HermesAgentAlias -Name 'publicacion-agil' -Alias 'docker' -Root $TestRoot -SkipPathRegistration | Out-Null } catch { $reservedRejected = $true }
    Assert-True $reservedRejected 'Rechaza alias reservados'

    New-HermesAgentFiles -Name 'Editor' -Purpose 'Editar textos.' -Root $TestRoot | Out-Null
    $duplicateAliasRejected = $false
    try { New-HermesAgentAlias -Name 'editor' -Alias 'pub' -Root $TestRoot -SkipPathRegistration | Out-Null } catch { $duplicateAliasRejected = $true }
    Assert-True $duplicateAliasRejected 'Impide compartir un alias entre agentes'
    Move-HermesAgentToTrash -Name 'editor' -Root $TestRoot | Out-Null

    $fakeDocker = Join-Path $TestRoot 'fake-docker.cmd'
    $fakeLog = Join-Path $TestRoot 'fake-docker.log'
    $fakeDockerContent = @'
@echo off
echo %*>>"%HERMES_FAKE_DOCKER_LOG%"
if "%1"=="info" echo 27.0.0
if "%7"=="ps" echo fake-container-id
exit /b 0
'@
    [IO.File]::WriteAllText($fakeDocker, $fakeDockerContent, [Text.ASCIIEncoding]::new())
    $previousDocker = $env:HERMES_MANAGER_DOCKER
    $previousLog = $env:HERMES_FAKE_DOCKER_LOG
    try {
        $env:HERMES_MANAGER_DOCKER = $fakeDocker
        $env:HERMES_FAKE_DOCKER_LOG = $fakeLog
        Assert-True (Test-HermesDockerEngine) 'Detecta un motor Docker disponible'
        Start-HermesAgent -Name 'publicacion-agil' -Root $TestRoot
        Initialize-HermesAgentConfiguration -Name 'publicacion-agil' -Root $TestRoot
        Open-HermesAgentChat -Name 'publicacion-agil' -Root $TestRoot
        Update-HermesAgent -Name 'publicacion-agil' -Root $TestRoot
        Stop-HermesAgent -Name 'publicacion-agil' -Root $TestRoot
        $dockerCalls = Get-Content -Raw -LiteralPath $fakeLog
        Assert-True ($dockerCalls -match 'up -d --remove-orphans') 'Inicio traduce a Docker Compose'
        Assert-True ($dockerCalls -match 'run --rm --no-deps agent setup') 'Configuración usa el asistente oficial'
        Assert-True ($dockerCalls -match 'run --rm --no-deps agent chat') 'Abrir inicia el chat oficial'
        Assert-True ($dockerCalls -match 'pull agent') 'Actualización descarga la imagen configurada'
        Assert-True ($dockerCalls -match 'down --remove-orphans') 'Detención limpia la instancia'
    } finally {
        if ($null -eq $previousDocker) { Remove-Item Env:HERMES_MANAGER_DOCKER -ErrorAction SilentlyContinue }
        else { $env:HERMES_MANAGER_DOCKER = $previousDocker }
        if ($null -eq $previousLog) { Remove-Item Env:HERMES_FAKE_DOCKER_LOG -ErrorAction SilentlyContinue }
        else { $env:HERMES_FAKE_DOCKER_LOG = $previousLog }
    }

    $trashPath = Move-HermesAgentToTrash -Name 'publicacion-agil' -Root $TestRoot
    Assert-True (Test-Path -LiteralPath $trashPath) 'Eliminar mueve a papelera recuperable'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $TestRoot 'bin\pub.cmd'))) 'Eliminar retira también el alias'
    Assert-Equal @(Get-HermesAgents -Root $TestRoot).Count 0 'El agente deja de figurar tras retirarlo'

    $settings = Get-HermesSettings -Root $TestRoot
    Assert-Equal $settings.hermes_image 'nousresearch/hermes-agent@sha256:41b9ed005cebcb3d3fb45206ce27cfb0356ba99b190c0924bab5141b15ad8e71' 'Usa la imagen oficial configurable fijada por digest'
    Assert-True ($null -eq $settings.PSObject.Properties['manager_version']) 'Mantiene settings limitado a opciones configurables'
    Assert-True ($null -eq $settings.PSObject.Properties['ollama_container_url']) 'No genera opciones sin consumidor'

    $parseTargets = @(
        (Join-Path $ProjectRoot 'HermesManager.ps1'),
        (Join-Path $ProjectRoot 'Activar alias globales.ps1'),
        (Join-Path $ProjectRoot 'src\HermesManager.psm1'),
        $PSCommandPath
    )
    foreach ($target in $parseTargets) {
        $tokens = $null
        $errors = $null
        [Management.Automation.Language.Parser]::ParseFile($target, [ref]$tokens, [ref]$errors) | Out-Null
        Assert-Equal $errors.Count 0 "Sintaxis PowerShell válida: $(Split-Path -Leaf $target)"
    }
} finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($TestRoot)
    $isSafeTestPath = $resolvedTestRoot.StartsWith($TemporaryBase, [StringComparison]::OrdinalIgnoreCase) -and
        ((Split-Path -Leaf $resolvedTestRoot) -like 'hermes-manager-core-test-*')
    if ($isSafeTestPath -and (Test-Path -LiteralPath $resolvedTestRoot)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}

Write-Host
Write-Host ("RESULTADO: {0}/{1} PASS" -f $script:Passed, ($script:Passed + $script:Failed)) -ForegroundColor Cyan
if ($script:Failed -gt 0) { exit 1 }
exit 0
