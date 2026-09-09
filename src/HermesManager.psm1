Set-StrictMode -Version 2.0

$script:ManagerVersion = '1.0.0'
$script:DefaultImage = 'nousresearch/hermes-agent:latest'

function Get-HermesRoot {
    [CmdletBinding()]
    param([string]$Root)

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Split-Path -Parent $PSScriptRoot
    }
    return [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
}

function Write-Utf8File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Initialize-HermesLayout {
    [CmdletBinding()]
    param([string]$Root)

    $resolvedRoot = Get-HermesRoot -Root $Root
    foreach ($relative in @('agents', 'bin', 'logs', 'trash')) {
        $path = Join-Path $resolvedRoot $relative
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }

    $settingsPath = Join-Path $resolvedRoot 'settings.json'
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        $settings = [ordered]@{
            schema = 1
            hermes_image = $script:DefaultImage
            docker_start_timeout_seconds = 120
            ollama_windows_url = 'http://localhost:11434'
        }
        Write-Utf8File -Path $settingsPath -Content (($settings | ConvertTo-Json -Depth 4) + "`n")
    }
    return $resolvedRoot
}

function Get-HermesSettings {
    [CmdletBinding()]
    param([string]$Root)

    $resolvedRoot = Initialize-HermesLayout -Root $Root
    $settingsPath = Join-Path $resolvedRoot 'settings.json'
    $settings = Get-Content -Raw -Encoding UTF8 -LiteralPath $settingsPath | ConvertFrom-Json
    if (-not $settings.hermes_image) {
        throw "settings.json no contiene hermes_image."
    }
    return $settings
}

function ConvertTo-HermesAgentName {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    $normalized = $Name.Trim().ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD)
    $builder = [Text.StringBuilder]::new()
    foreach ($character in $normalized.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($character) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($character)
        }
    }
    $slug = $builder.ToString().Normalize([Text.NormalizationForm]::FormC)
    $slug = [regex]::Replace($slug, '[^a-z0-9]+', '-')
    $slug = $slug.Trim('-')
    if ($slug.Length -lt 2 -or $slug.Length -gt 48 -or $slug -notmatch '^[a-z0-9][a-z0-9-]*[a-z0-9]$') {
        throw 'El nombre debe producir un identificador de 2 a 48 caracteres (letras, números y guiones).'
    }
    return $slug
}

function Get-HermesAgentPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Root
    )

    $resolvedRoot = Get-HermesRoot -Root $Root
    $slug = ConvertTo-HermesAgentName -Name $Name
    return Join-Path (Join-Path $resolvedRoot 'agents') $slug
}

function New-HermesAgentFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Purpose,
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Purpose)) {
        throw 'Debes indicar para qué servirá el agente.'
    }
    $resolvedRoot = Initialize-HermesLayout -Root $Root
    $slug = ConvertTo-HermesAgentName -Name $Name
    $agentPath = Get-HermesAgentPath -Name $slug -Root $resolvedRoot
    if (Test-Path -LiteralPath $agentPath) {
        throw "El agente '$slug' ya existe."
    }

    foreach ($relative in @('data', 'data\home', 'data\workspace', 'data\logs')) {
        New-Item -ItemType Directory -Path (Join-Path $agentPath $relative) -Force | Out-Null
    }

    $composeTemplate = @'
name: hermes-__SLUG__

services:
  agent:
    image: ${HERMES_IMAGE:-nousresearch/hermes-agent:latest}
    container_name: hermes-__SLUG__
    command: ["gateway", "run"]
    restart: unless-stopped
    read_only: true
    working_dir: /opt/data/workspace
    env_file:
      - ./data/.env
    environment:
      HERMES_HOME: /opt/data
      HERMES_WRITE_SAFE_ROOT: /opt/data
      HOME: /opt/data/home
      HERMES_UID: "10000"
      HERMES_GID: "10000"
      HERMES_YOLO_MODE: "0"
      API_SERVER_ENABLED: "false"
      HERMES_DASHBOARD: "0"
      PYTHONDONTWRITEBYTECODE: "1"
      OLLAMA_HOST: ${OLLAMA_HOST:-http://host.docker.internal:11434}
    volumes:
      - ./data:/opt/data:rw
    networks:
      - private
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - FOWNER
      - SETGID
      - SETUID
    pids_limit: 256
    mem_limit: 4g
    cpus: 2.0
    stop_grace_period: 30s
    tmpfs:
      - /tmp:rw,noexec,nosuid,nodev,size=512m
      - /var/tmp:rw,noexec,nosuid,nodev,size=256m
      - /run:rw,exec,nosuid,nodev,size=64m

networks:
  private:
    driver: bridge
'@
    $compose = $composeTemplate.Replace('__SLUG__', $slug)
    Write-Utf8File -Path (Join-Path $agentPath 'compose.yaml') -Content ($compose.TrimStart() + "`n")

    $safeTitle = $Name.Trim()
    $soul = @"
# $safeTitle

## Función

$($Purpose.Trim())

## Forma de trabajo

- Pide la información que falte antes de actuar.
- Explica de forma breve qué va a hacer.
- Conserva sus datos únicamente dentro de `/opt/data`.
- No afirma que una operación terminó hasta haberla comprobado.
"@
    Write-Utf8File -Path (Join-Path $agentPath 'data\SOUL.md') -Content ($soul.TrimStart() + "`n")

    $environment = @'
# Este archivo permanece dentro de la carpeta del agente.
# El asistente oficial de Hermes añadirá aquí o en config.yaml la configuración necesaria.
OLLAMA_HOST=http://host.docker.internal:11434
'@
    Write-Utf8File -Path (Join-Path $agentPath 'data\.env') -Content ($environment.TrimStart() + "`n")

    $metadata = [ordered]@{
        schema = 1
        name = $slug
        display_name = $safeTitle
        purpose = $Purpose.Trim()
        created_at = [DateTime]::UtcNow.ToString('o')
        manager_version = $script:ManagerVersion
    }
    Write-Utf8File -Path (Join-Path $agentPath 'agent.json') -Content (($metadata | ConvertTo-Json -Depth 4) + "`n")

    return [pscustomobject]@{
        Name = $slug
        DisplayName = $safeTitle
        Purpose = $Purpose.Trim()
        Path = $agentPath
    }
}

function Get-HermesAgents {
    [CmdletBinding()]
    param([string]$Root)

    $resolvedRoot = Initialize-HermesLayout -Root $Root
    $agentsRoot = Join-Path $resolvedRoot 'agents'
    $result = @()
    foreach ($directory in @(Get-ChildItem -LiteralPath $agentsRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
        $metadataPath = Join-Path $directory.FullName 'agent.json'
        $composePath = Join-Path $directory.FullName 'compose.yaml'
        if (-not (Test-Path -LiteralPath $metadataPath) -or -not (Test-Path -LiteralPath $composePath)) { continue }
        try {
            $metadata = Get-Content -Raw -Encoding UTF8 -LiteralPath $metadataPath | ConvertFrom-Json
            $aliasProperty = $metadata.PSObject.Properties['terminal_alias']
            $result += [pscustomobject]@{
                Name = [string]$metadata.name
                DisplayName = [string]$metadata.display_name
                Purpose = [string]$metadata.purpose
                TerminalAlias = if ($aliasProperty) { [string]$aliasProperty.Value } else { '' }
                Path = $directory.FullName
                CreatedAt = [string]$metadata.created_at
            }
        } catch {
            Write-Warning "No se pudo leer $metadataPath"
        }
    }
    return @($result)
}

function Get-HermesAgent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Root
    )

    $slug = ConvertTo-HermesAgentName -Name $Name
    $agent = @(Get-HermesAgents -Root $Root | Where-Object Name -eq $slug)
    if ($agent.Count -ne 1) { throw "No existe el agente '$slug'." }
    return $agent[0]
}

function ConvertTo-HermesAliasName {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Alias)

    $normalized = ConvertTo-HermesAgentName -Name $Alias
    $reserved = @(
        'assoc', 'break', 'call', 'cd', 'chdir', 'cls', 'cmd', 'color', 'copy',
        'date', 'del', 'dir', 'docker', 'echo', 'endlocal', 'erase', 'exit',
        'for', 'ftype', 'git', 'goto', 'help', 'if', 'md', 'mkdir', 'mklink',
        'move', 'path', 'pause', 'popd', 'powershell', 'prompt', 'pushd',
        'python', 'rd', 'rem', 'ren', 'rename', 'rmdir', 'set', 'setlocal',
        'shift', 'start', 'time', 'title', 'type', 'ver', 'verify', 'vol', 'where'
    )
    if ($normalized -in $reserved) {
        throw "El alias '$normalized' está reservado por Windows o por una herramienta común."
    }
    return $normalized
}

function Get-HermesBinPath {
    [CmdletBinding()]
    param([string]$Root)

    $resolvedRoot = Initialize-HermesLayout -Root $Root
    return Join-Path $resolvedRoot 'bin'
}

function Install-HermesAliasPath {
    [CmdletBinding()]
    param([string]$Root)

    $binPath = Get-HermesBinPath -Root $Root
    $userPath = [string][Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim().TrimEnd('\') })
    $alreadyInstalled = @($entries | Where-Object { $_.Equals($binPath, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
    if (-not $alreadyInstalled) {
        $newEntries = @($entries) + $binPath
        [Environment]::SetEnvironmentVariable('Path', (($newEntries -join ';') + ';'), 'User')
        if (-not ('HermesManager.EnvironmentBroadcast' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace HermesManager {
    public static class EnvironmentBroadcast {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
            uint flags, uint timeout, out UIntPtr result);
    }
}
'@
        }
        $broadcastResult = [UIntPtr]::Zero
        [void][HermesManager.EnvironmentBroadcast]::SendMessageTimeout(
            [IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, 'Environment',
            0x0002, 5000, [ref]$broadcastResult)
    }

    $processEntries = @(([string]$env:Path) -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim().TrimEnd('\') })
    if (@($processEntries | Where-Object { $_.Equals($binPath, [StringComparison]::OrdinalIgnoreCase) }).Count -eq 0) {
        $env:Path = ([string]$env:Path).TrimEnd(';') + ';' + $binPath
    }
    return (-not $alreadyInstalled)
}

function New-HermesAgentAlias {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Alias,
        [string]$Root,
        [switch]$SkipPathRegistration
    )

    $resolvedRoot = Initialize-HermesLayout -Root $Root
    $agent = Get-HermesAgent -Name $Name -Root $resolvedRoot
    $aliasName = ConvertTo-HermesAliasName -Alias $Alias
    $binPath = Get-HermesBinPath -Root $resolvedRoot
    $aliasPath = Join-Path $binPath "$aliasName.cmd"

    foreach ($otherAgent in @(Get-HermesAgents -Root $resolvedRoot)) {
        if ($otherAgent.Name -ne $agent.Name -and $otherAgent.TerminalAlias -eq $aliasName) {
            throw "El alias '$aliasName' ya pertenece al agente '$($otherAgent.Name)'."
        }
    }

    $commands = @(Get-Command $aliasName -All -ErrorAction SilentlyContinue)
    foreach ($command in $commands) {
        $sourcePath = if ($command.Path) { [System.IO.Path]::GetFullPath($command.Path) } else { '' }
        if (-not $sourcePath -or -not $sourcePath.Equals($aliasPath, [StringComparison]::OrdinalIgnoreCase)) {
            throw "El alias '$aliasName' colisiona con el comando existente '$($command.Source)'."
        }
    }

    if ($agent.TerminalAlias -and $agent.TerminalAlias -ne $aliasName) {
        Remove-HermesAgentAlias -Name $agent.Name -Root $resolvedRoot
    }

    $launcher = @"
@echo off
rem HERMES_MANAGER_ALIAS=$($agent.Name)
setlocal
call "%~dp0..\hermes.cmd" abrir $($agent.Name)
exit /b %ERRORLEVEL%
"@
    Write-Utf8File -Path $aliasPath -Content ($launcher.TrimStart() + "`r`n")

    $metadataPath = Join-Path $agent.Path 'agent.json'
    $metadata = Get-Content -Raw -Encoding UTF8 -LiteralPath $metadataPath | ConvertFrom-Json
    $metadata | Add-Member -NotePropertyName terminal_alias -NotePropertyValue $aliasName -Force
    $metadata | Add-Member -NotePropertyName manager_version -NotePropertyValue $script:ManagerVersion -Force
    Write-Utf8File -Path $metadataPath -Content (($metadata | ConvertTo-Json -Depth 6) + "`n")

    $pathAdded = $false
    if (-not $SkipPathRegistration) {
        $pathAdded = Install-HermesAliasPath -Root $resolvedRoot
    }
    return [pscustomobject]@{
        Agent = $agent.Name
        Alias = $aliasName
        Path = $aliasPath
        UserPathAdded = $pathAdded
    }
}

function Remove-HermesAgentAlias {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name, [string]$Root)

    $resolvedRoot = Initialize-HermesLayout -Root $Root
    $agent = Get-HermesAgent -Name $Name -Root $resolvedRoot
    if (-not $agent.TerminalAlias) { return }
    $aliasPath = Join-Path (Get-HermesBinPath -Root $resolvedRoot) "$($agent.TerminalAlias).cmd"
    if (Test-Path -LiteralPath $aliasPath) {
        $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $aliasPath
        if ($content -notmatch ('(?m)^rem HERMES_MANAGER_ALIAS=' + [regex]::Escape($agent.Name) + '\r?$')) {
            throw "El archivo '$aliasPath' no pertenece al agente '$($agent.Name)'."
        }
        Remove-Item -LiteralPath $aliasPath -Force
    }

    $metadataPath = Join-Path $agent.Path 'agent.json'
    $metadata = Get-Content -Raw -Encoding UTF8 -LiteralPath $metadataPath | ConvertFrom-Json
    [void]$metadata.PSObject.Properties.Remove('terminal_alias')
    Write-Utf8File -Path $metadataPath -Content (($metadata | ConvertTo-Json -Depth 6) + "`n")
}

function Get-HermesDockerPath {
    [CmdletBinding()]
    param()

    if ($env:HERMES_MANAGER_DOCKER -and (Test-Path -LiteralPath $env:HERMES_MANAGER_DOCKER)) {
        return $env:HERMES_MANAGER_DOCKER
    }
    $command = Get-Command docker -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'),
        (Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin\docker.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

function Get-DockerDesktopPath {
    [CmdletBinding()]
    param()

    $candidates = @(
        (Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Docker\Docker\Docker Desktop.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\Docker Desktop.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    $uninstallRoots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $dockerApp = Get-ItemProperty $uninstallRoots -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq 'Docker Desktop' } | Select-Object -First 1
    if ($dockerApp -and $dockerApp.InstallLocation) {
        $candidate = Join-Path $dockerApp.InstallLocation 'Docker Desktop.exe'
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

function Test-HermesDockerEngine {
    [CmdletBinding()]
    param()

    $docker = Get-HermesDockerPath
    if (-not $docker) { return $false }
    try {
        & $docker info --format '{{.ServerVersion}}' *> $null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Start-HermesDockerEngine {
    [CmdletBinding()]
    param([int]$TimeoutSeconds = 120)

    if (Test-HermesDockerEngine) { return }
    $desktop = Get-DockerDesktopPath
    if (-not $desktop) {
        throw 'Docker Desktop no está disponible. Instálalo o ábrelo y vuelve a intentarlo.'
    }
    Start-Process -FilePath $desktop -WindowStyle Hidden | Out-Null
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Seconds 2
        if (Test-HermesDockerEngine) { return }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Docker Desktop no estuvo listo después de $TimeoutSeconds segundos."
}

function Invoke-HermesDocker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$Capture,
        [switch]$IgnoreExitCode
    )

    $docker = Get-HermesDockerPath
    if (-not $docker) { throw 'No se encontró docker.exe.' }
    if ($Capture) {
        $output = @(& $docker @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0 -and -not $IgnoreExitCode) {
            throw "Docker terminó con código $exitCode.`n$($output -join "`n")"
        }
        return @($output)
    }
    & $docker @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0 -and -not $IgnoreExitCode) {
        throw "Docker terminó con código $exitCode."
    }
}

function Invoke-HermesCompose {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$Root,
        [switch]$Capture
    )

    $agent = Get-HermesAgent -Name $Name -Root $Root
    $settings = Get-HermesSettings -Root $Root
    $composeFile = Join-Path $agent.Path 'compose.yaml'
    $previousImage = $env:HERMES_IMAGE
    try {
        $env:HERMES_IMAGE = [string]$settings.hermes_image
        $dockerArguments = @('compose', '--project-directory', $agent.Path, '-f', $composeFile) + $Arguments
        return Invoke-HermesDocker -Arguments $dockerArguments -Capture:$Capture
    } finally {
        if ($null -eq $previousImage) { Remove-Item Env:HERMES_IMAGE -ErrorAction SilentlyContinue }
        else { $env:HERMES_IMAGE = $previousImage }
    }
}

function Test-HermesAgentRunning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Root
    )

    if (-not (Test-HermesDockerEngine)) { return $false }
    $output = @(Invoke-HermesCompose -Name $Name -Root $Root -Arguments @('ps', '-q', 'agent') -Capture)
    return (($output -join '').Trim().Length -gt 0)
}

function Start-HermesAgent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name, [string]$Root)

    $settings = Get-HermesSettings -Root $Root
    Start-HermesDockerEngine -TimeoutSeconds ([int]$settings.docker_start_timeout_seconds)
    Invoke-HermesCompose -Name $Name -Root $Root -Arguments @('up', '-d', '--remove-orphans')
}

function Stop-HermesAgent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name, [string]$Root)

    $settings = Get-HermesSettings -Root $Root
    Start-HermesDockerEngine -TimeoutSeconds ([int]$settings.docker_start_timeout_seconds)
    Invoke-HermesCompose -Name $Name -Root $Root -Arguments @('down', '--remove-orphans')
}

function Open-HermesAgentChat {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name, [string]$Root)

    $settings = Get-HermesSettings -Root $Root
    Start-HermesDockerEngine -TimeoutSeconds ([int]$settings.docker_start_timeout_seconds)
    Invoke-HermesCompose -Name $Name -Root $Root -Arguments @('run', '--rm', '--no-deps', 'agent', 'chat')
}

function Initialize-HermesAgentConfiguration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name, [string]$Root)

    $settings = Get-HermesSettings -Root $Root
    Start-HermesDockerEngine -TimeoutSeconds ([int]$settings.docker_start_timeout_seconds)
    Invoke-HermesCompose -Name $Name -Root $Root -Arguments @('run', '--rm', '--no-deps', 'agent', 'setup')
}

function Update-HermesAgent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name, [string]$Root)

    $settings = Get-HermesSettings -Root $Root
    Start-HermesDockerEngine -TimeoutSeconds ([int]$settings.docker_start_timeout_seconds)
    $wasRunning = Test-HermesAgentRunning -Name $Name -Root $Root
    Invoke-HermesCompose -Name $Name -Root $Root -Arguments @('pull', 'agent')
    if ($wasRunning) {
        Invoke-HermesCompose -Name $Name -Root $Root -Arguments @('up', '-d', '--remove-orphans', 'agent')
    }
}

function Move-HermesAgentToTrash {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name, [string]$Root)

    $resolvedRoot = Initialize-HermesLayout -Root $Root
    $agent = Get-HermesAgent -Name $Name -Root $resolvedRoot
    Remove-HermesAgentAlias -Name $agent.Name -Root $resolvedRoot
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $destination = Join-Path (Join-Path $resolvedRoot 'trash') "$timestamp-$($agent.Name)"
    Move-Item -LiteralPath $agent.Path -Destination $destination
    return $destination
}

function Remove-HermesAgent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name, [string]$Root)

    Stop-HermesAgent -Name $Name -Root $Root
    return Move-HermesAgentToTrash -Name $Name -Root $Root
}

function Get-HermesOllamaModels {
    [CmdletBinding()]
    param([string]$Root)

    $settings = Get-HermesSettings -Root $Root
    $url = ([string]$settings.ollama_windows_url).TrimEnd('/') + '/api/tags'
    try {
        $response = Invoke-RestMethod -Method Get -Uri $url -TimeoutSec 3
        return @($response.models | ForEach-Object { $_.name } | Sort-Object)
    } catch {
        return @()
    }
}

function Write-HermesManagerLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO',
        [string]$Root
    )

    $resolvedRoot = Initialize-HermesLayout -Root $Root
    $line = '{0} [{1}] {2}' -f ([DateTime]::UtcNow.ToString('o')), $Level, ($Message -replace "[\r\n]+", ' ')
    Add-Content -LiteralPath (Join-Path $resolvedRoot 'logs\manager.log') -Value $line -Encoding UTF8
}

function Get-HermesManagerVersion { return $script:ManagerVersion }

Export-ModuleMember -Function @(
    'Get-HermesRoot', 'Initialize-HermesLayout', 'Get-HermesSettings',
    'ConvertTo-HermesAgentName', 'Get-HermesAgentPath', 'New-HermesAgentFiles',
    'Get-HermesAgents', 'Get-HermesAgent', 'ConvertTo-HermesAliasName',
    'Get-HermesBinPath', 'Install-HermesAliasPath', 'New-HermesAgentAlias',
    'Remove-HermesAgentAlias', 'Get-HermesDockerPath',
    'Get-DockerDesktopPath', 'Test-HermesDockerEngine', 'Start-HermesDockerEngine',
    'Invoke-HermesDocker', 'Invoke-HermesCompose', 'Test-HermesAgentRunning',
    'Start-HermesAgent', 'Stop-HermesAgent', 'Open-HermesAgentChat',
    'Initialize-HermesAgentConfiguration', 'Update-HermesAgent',
    'Move-HermesAgentToTrash', 'Remove-HermesAgent', 'Get-HermesOllamaModels',
    'Write-HermesManagerLog', 'Get-HermesManagerVersion'
)
