[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Command = 'menu',
    [Parameter(Position = 1)][string]$AgentName,
    [Parameter(Position = 2)][string]$AliasName,
    [ValidateSet('es', 'en')][string]$Language = 'es',
    [switch]$Confirmar
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Import-Module (Join-Path $Root 'src\HermesManager.psm1') -Force
. (Join-Path $Root 'src\HermesLocalization.ps1')
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

function Write-LocalizedManagerLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    Write-HermesManagerLog -Root $Root -Level $Level -Message (ConvertTo-HermesLocalizedText -Text $Message)
}
Initialize-HermesLayout -Root $Root | Out-Null

if ($Host.Name -eq 'ConsoleHost') {
    try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
}

function Show-Banner {
    Clear-Host
    Write-Host '========================================' -ForegroundColor DarkCyan
    Write-Host '            HERMES MANAGER' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor DarkCyan
    Write-Host 'Agentes sencillos sobre Docker, sin tocar Docker.'
    Write-Host
}

function Wait-ForUser {
    Write-Host
    [void](Read-Host $(if ($Language -eq 'en') { 'Press Enter to continue' } else { 'Pulsa Intro para continuar' }))
}

function Read-YesNo {
    param([Parameter(Mandatory)][string]$Prompt, [bool]$Default = $true)
    $suffix = if ($Language -eq 'en') {
        if ($Default) { '[Y/n]' } else { '[y/N]' }
    } else {
        if ($Default) { '[S/n]' } else { '[s/N]' }
    }
    if ($Language -eq 'en') {
        if ($Prompt -match 'configurar ahora') { $Prompt = 'Do you want to configure the provider and model now?' }
        elseif ($Prompt -match 'iniciar el agente') { $Prompt = 'Do you want to start the agent now?' }
        elseif ($Prompt -match 'papelera de Hermes') {
            $agentName = [regex]::Match($Prompt, "'([^']+)'").Groups[1].Value
            $Prompt = "Move '$agentName' to the Hermes trash?"
        }
    }
    while ($true) {
        $answer = (Read-Host "$Prompt $suffix").Trim().ToLowerInvariant()
        if (-not $answer) { return $Default }
        if ($answer -in @('s', 'si', 'sí', 'y', 'yes')) { return $true }
        if ($answer -in @('n', 'no')) { return $false }
        Write-Host 'Responde s o n.' -ForegroundColor Yellow
    }
}

function Select-Agent {
    param([string]$RequestedName)
    if ($RequestedName) { return (Get-HermesAgent -Name $RequestedName -Root $Root).Name }
    $agents = @(Get-HermesAgents -Root $Root)
    if (-not $agents.Count) { throw 'Todavía no hay agentes. Elige Crear agente.' }
    Write-Host 'Agentes:' -ForegroundColor Cyan
    for ($index = 0; $index -lt $agents.Count; $index++) {
        Write-Host ("  {0}. {1} ({2})" -f ($index + 1), $agents[$index].DisplayName, $agents[$index].Name)
    }
    $selection = Read-Host $(if ($Language -eq 'en') { 'Number or name' } else { 'Número o nombre' })
    $number = 0
    if ([int]::TryParse($selection, [ref]$number) -and $number -ge 1 -and $number -le $agents.Count) {
        return $agents[$number - 1].Name
    }
    return (Get-HermesAgent -Name $selection -Root $Root).Name
}

function Show-AgentList {
    $agents = @(Get-HermesAgents -Root $Root)
    if (-not $agents.Count) {
        Write-Host 'No hay agentes creados.' -ForegroundColor Yellow
        return
    }
    $dockerReady = Test-HermesDockerEngine
    $rows = foreach ($agent in $agents) {
        $status = if (-not $dockerReady) {
            if ($Language -eq 'en') { 'NOT CHECKED' } else { 'SIN COMPROBAR' }
        } elseif (Test-HermesAgentRunning -Name $agent.Name -Root $Root) {
            if ($Language -eq 'en') { 'RUNNING' } else { 'EN MARCHA' }
        } else {
            if ($Language -eq 'en') { 'STOPPED' } else { 'DETENIDO' }
        }
        if ($Language -eq 'en') {
            [pscustomobject]@{
                Name = $agent.DisplayName
                Id = $agent.Name
                Alias = $(if ($agent.TerminalAlias) { $agent.TerminalAlias } else { '-' })
                Status = $status
                Purpose = $agent.Purpose
            }
        } else {
            [pscustomobject]@{
                Nombre = $agent.DisplayName
                Id = $agent.Name
                Alias = $(if ($agent.TerminalAlias) { $agent.TerminalAlias } else { '-' })
                Estado = $status
                Funcion = $agent.Purpose
            }
        }
    }
    $rows | Format-Table -AutoSize -Wrap
}

function New-AgentInteractive {
    param([string]$RequestedName)
    Show-Banner
    Write-Host 'CREAR AGENTE' -ForegroundColor Green
    Write-Host $(if ($Language -eq 'en') { 'The manager will keep its identity, configuration and data in its own folder.' } else { 'El gestor guardará su identidad, configuración y datos en una carpeta propia.' })
    Write-Host
    $displayName = $RequestedName
    if (-not $displayName) { $displayName = Read-Host $(if ($Language -eq 'en') { 'Agent name (example: publisher)' } else { 'Nombre del agente (ejemplo: publisher)' }) }
    $purpose = Read-Host $(if ($Language -eq 'en') { 'What will it be used for?' } else { '¿Para qué servirá?' })
    $agent = New-HermesAgentFiles -Name $displayName -Purpose $purpose -Root $Root -Language $Language
    Write-LocalizedManagerLog -Message "Agente creado: $($agent.Name)"
    Write-Host
    Write-Host "Agente '$($agent.DisplayName)' creado." -ForegroundColor Green
    Write-Host "Datos: $($agent.Path)"

    $aliasName = Read-Host $(if ($Language -eq 'en') { "Alias to open it from any terminal [$($agent.Name)]" } else { "Alias para abrirlo desde cualquier terminal [$($agent.Name)]" })
    if (-not $aliasName) { $aliasName = $agent.Name }
    $aliasResult = New-HermesAgentAlias -Name $agent.Name -Alias $aliasName -Root $Root
    Write-LocalizedManagerLog -Message "Alias creado: $($aliasResult.Alias) -> $($agent.Name)"
    Write-Host "Alias creado: escribe '$($aliasResult.Alias)' en una terminal nueva." -ForegroundColor Green

    if (Read-YesNo -Prompt '¿Quieres configurar ahora el proveedor y el modelo?' -Default $true) {
        Write-Host
        Write-Host $(if ($Language -eq 'en') { 'Hermes will open its official setup assistant. Answers will remain inside the agent folder.' } else { 'Hermes abrirá su asistente oficial. Las respuestas quedarán dentro de la carpeta del agente.' }) -ForegroundColor Cyan
        Initialize-HermesAgentConfiguration -Name $agent.Name -Root $Root
        Write-LocalizedManagerLog -Message "Configuración ejecutada: $($agent.Name)"
    }
    if (Read-YesNo -Prompt '¿Quieres iniciar el agente ahora?' -Default $true) {
        Start-HermesAgent -Name $agent.Name -Root $Root
        Write-LocalizedManagerLog -Message "Agente iniciado: $($agent.Name)"
        Write-Host "'$($agent.Name)' está en marcha." -ForegroundColor Green
    }
}

function Invoke-ConfigureAgent {
    param([string]$RequestedName)
    $name = Select-Agent -RequestedName $RequestedName
    Initialize-HermesAgentConfiguration -Name $name -Root $Root
    Write-LocalizedManagerLog -Message "Configuración ejecutada: $name"
}

function Invoke-StartAgent {
    param([string]$RequestedName)
    $name = Select-Agent -RequestedName $RequestedName
    Start-HermesAgent -Name $name -Root $Root
    Write-LocalizedManagerLog -Message "Agente iniciado: $name"
    Write-Host "'$name' está en marcha." -ForegroundColor Green
}

function Invoke-OpenAgent {
    param([string]$RequestedName)
    $name = Select-Agent -RequestedName $RequestedName
    Write-Host "Abriendo conversación con '$name'. Escribe /exit para salir." -ForegroundColor Cyan
    Open-HermesAgentChat -Name $name -Root $Root
}

function Invoke-StopAgent {
    param([string]$RequestedName)
    $name = Select-Agent -RequestedName $RequestedName
    Stop-HermesAgent -Name $name -Root $Root
    Write-LocalizedManagerLog -Message "Agente detenido: $name"
    Write-Host "'$name' está detenido." -ForegroundColor Green
}

function Invoke-UpdateAgent {
    param([string]$RequestedName)
    if ($RequestedName -and $RequestedName.ToLowerInvariant() -eq 'todos') {
        $agents = @(Get-HermesAgents -Root $Root)
        if (-not $agents.Count) { throw 'No hay agentes que actualizar.' }
        foreach ($agent in $agents) {
            Write-Host "Actualizando $($agent.Name)..." -ForegroundColor Cyan
            Update-HermesAgent -Name $agent.Name -Root $Root
            Write-LocalizedManagerLog -Message "Agente actualizado: $($agent.Name)"
        }
        Write-Host 'Todos los agentes están actualizados.' -ForegroundColor Green
        return
    }
    $name = Select-Agent -RequestedName $RequestedName
    Update-HermesAgent -Name $name -Root $Root
    Write-LocalizedManagerLog -Message "Agente actualizado: $name"
    Write-Host "'$name' está actualizado." -ForegroundColor Green
}

function Invoke-DeleteAgent {
    param([string]$RequestedName, [switch]$AlreadyConfirmed)
    $name = Select-Agent -RequestedName $RequestedName
    if (-not $AlreadyConfirmed -and -not (Read-YesNo -Prompt "¿Mover '$name' a la papelera de Hermes?" -Default $false)) {
        Write-Host 'Operación cancelada.'
        return
    }
    $destination = Remove-HermesAgent -Name $name -Root $Root
    Write-LocalizedManagerLog -Message "Agente movido a la papelera: $name"
    Write-Host "Agente retirado. Copia recuperable: $destination" -ForegroundColor Green
}

function Invoke-AgentAlias {
    param([string]$RequestedName, [string]$RequestedAlias)
    $name = Select-Agent -RequestedName $RequestedName
    $agent = Get-HermesAgent -Name $name -Root $Root
    $aliasName = $RequestedAlias
    if (-not $aliasName) {
        $suggested = if ($agent.TerminalAlias) { $agent.TerminalAlias } else { $agent.Name }
        $aliasName = Read-Host $(if ($Language -eq 'en') { "Short alias [$suggested]" } else { "Alias corto [$suggested]" })
        if (-not $aliasName) { $aliasName = $suggested }
    }
    $result = New-HermesAgentAlias -Name $name -Alias $aliasName -Root $Root
    Write-LocalizedManagerLog -Message "Alias creado: $($result.Alias) -> $name"
    Write-Host "Alias listo: $($result.Alias)" -ForegroundColor Green
    if ($result.UserPathAdded) {
        Write-Host 'Abre una terminal nueva para utilizarlo desde cualquier carpeta.' -ForegroundColor Yellow
    } else {
        Write-Host "En una terminal nueva, escribe '$($result.Alias)' para abrir el agente."
    }
}

function Show-Models {
    $models = @(Get-HermesOllamaModels -Root $Root)
    if (-not $models.Count) {
        Write-Host 'Ollama no está disponible o no tiene modelos instalados.' -ForegroundColor Yellow
        return
    }
    Write-Host 'Modelos locales disponibles para los agentes:' -ForegroundColor Cyan
    $models | ForEach-Object { Write-Host "  - $_" }
}

function Show-Diagnostics {
    $dockerPath = Get-HermesDockerPath
    $dockerReady = Test-HermesDockerEngine
    $settings = Get-HermesSettings -Root $Root
    $agents = @(Get-HermesAgents -Root $Root)
    $models = @(Get-HermesOllamaModels -Root $Root)
    Write-Host 'DIAGNÓSTICO HERMES MANAGER' -ForegroundColor Cyan
    Write-Host ("  Carpeta:         {0}" -f $Root)
    Write-Host ("  Versión gestor:  {0}" -f (Get-HermesManagerVersion))
    Write-Host ("  Imagen Hermes:   {0}" -f $settings.hermes_image)
    Write-Host ("  Docker CLI:      {0}" -f $(if ($dockerPath) { $dockerPath } else { 'NO ENCONTRADO' }))
    Write-Host ("  Motor Docker:    {0}" -f $(if ($dockerReady) { 'LISTO' } else { 'DETENIDO/NO DISPONIBLE' }))
    Write-Host ("  Agentes:         {0}" -f $agents.Count)
    Write-Host ("  Modelos Ollama:  {0}" -f $models.Count)
    if (-not $dockerPath) { Write-Host 'Instala Docker Desktop para poder iniciar agentes.' -ForegroundColor Yellow }
}

function Show-Help {
        if ($Language -eq 'en') {
                Write-Host @'
EASY USE
    Double-click "Hermes Manager (English).cmd" to open the menu.

OPTIONAL COMMANDS
    hermes-en.cmd create [name]       Create and configure an agent
    hermes-en.cmd setup [name]        Configure provider/model again
    hermes-en.cmd start [name]        Start the instance
    hermes-en.cmd chat [name]         Chat with the agent
    hermes-en.cmd stop [name]         Stop the instance
    hermes-en.cmd update [name]       Download and apply the current Hermes image
    hermes-en.cmd update all          Update all agents
    hermes-en.cmd remove [name]       Move the agent to the internal trash
    hermes-en.cmd alias [agent] [alias] Create or change its global alias
    hermes-en.cmd list                Show agents and status
    hermes-en.cmd models              Show local Ollama models
    hermes-en.cmd doctor              Check requirements
'@
                return
        }
    Write-Host @'
USO FÁCIL
  Haz doble clic en "Hermes Manager.cmd" para abrir el menú.

COMANDOS OPCIONALES
  hermes crear [nombre]       Crear y configurar un agente
  hermes configurar [nombre] Volver a configurar proveedor/modelo
  hermes iniciar [nombre]     Iniciar la instancia
  hermes abrir [nombre]       Conversar con el agente
  hermes detener [nombre]     Detener la instancia
  hermes actualizar [nombre]  Descargar y aplicar Hermes reciente
  hermes actualizar todos     Actualizar todos los agentes
  hermes eliminar [nombre]    Mover el agente a la papelera interna
  hermes alias [agente] [alias] Crear o cambiar su alias global
  hermes listar               Mostrar agentes y estado
  hermes modelos              Mostrar modelos locales de Ollama
  hermes diagnostico          Comprobar requisitos
'@
}

function Show-Menu {
    while ($true) {
        Show-Banner
        $agents = @(Get-HermesAgents -Root $Root)
        Write-Host ("Agentes configurados: {0}" -f $agents.Count)
        Write-Host
        if ($Language -eq 'en') {
            Write-Host @'
  1. Create agent
  2. Open conversation
  3. Start agent
  4. Stop agent
  5. Configure provider/model
  6. Update agent
  7. List agents
  8. Local models
  9. Remove agent
  A. Create or change terminal alias
  D. Diagnostics
  0. Exit
'@
        } else {
            Write-Host '  1. Crear agente'
            Write-Host '  2. Abrir conversación'
            Write-Host '  3. Iniciar agente'
            Write-Host '  4. Detener agente'
            Write-Host '  5. Configurar proveedor/modelo'
            Write-Host '  6. Actualizar agente'
            Write-Host '  7. Listar agentes'
            Write-Host '  8. Modelos locales'
            Write-Host '  9. Eliminar agente'
            Write-Host '  A. Crear o cambiar alias de terminal'
            Write-Host '  D. Diagnóstico'
            Write-Host '  0. Salir'
        }
        Write-Host
        $choice = (Read-Host $(if ($Language -eq 'en') { 'Choose an option' } else { 'Elige una opción' })).Trim().ToLowerInvariant()
        try {
            switch ($choice) {
                '1' { New-AgentInteractive; Wait-ForUser }
                '2' { Show-Banner; Invoke-OpenAgent; Wait-ForUser }
                '3' { Show-Banner; Invoke-StartAgent; Wait-ForUser }
                '4' { Show-Banner; Invoke-StopAgent; Wait-ForUser }
                '5' { Show-Banner; Invoke-ConfigureAgent; Wait-ForUser }
                '6' { Show-Banner; Invoke-UpdateAgent; Wait-ForUser }
                '7' { Show-Banner; Show-AgentList; Wait-ForUser }
                '8' { Show-Banner; Show-Models; Wait-ForUser }
                '9' { Show-Banner; Invoke-DeleteAgent; Wait-ForUser }
                'a' { Show-Banner; Invoke-AgentAlias; Wait-ForUser }
                'd' { Show-Banner; Show-Diagnostics; Wait-ForUser }
                '0' { return }
                default { Write-Host 'Opción no válida.' -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
            }
        } catch {
            Write-LocalizedManagerLog -Level ERROR -Message $_.Exception.Message
            Write-Host
            Write-Host ('ERROR: ' + (ConvertTo-HermesLocalizedText -Text $_.Exception.Message)) -ForegroundColor Red
            Wait-ForUser
        }
    }
}

$normalizedCommand = $Command.Trim().ToLowerInvariant()
try {
    switch ($normalizedCommand) {
        { $_ -in @('', 'menu') } { Show-Menu; break }
        { $_ -in @('crear', 'create', 'nuevo') } { New-AgentInteractive -RequestedName $AgentName; break }
        { $_ -in @('configurar', 'setup', 'configure') } { Invoke-ConfigureAgent -RequestedName $AgentName; break }
        { $_ -in @('iniciar', 'start') } { Invoke-StartAgent -RequestedName $AgentName; break }
        { $_ -in @('abrir', 'chat', 'open') } { Invoke-OpenAgent -RequestedName $AgentName; break }
        { $_ -in @('detener', 'stop') } { Invoke-StopAgent -RequestedName $AgentName; break }
        { $_ -in @('actualizar', 'update') } { Invoke-UpdateAgent -RequestedName $AgentName; break }
        { $_ -in @('eliminar', 'remove', 'delete') } { Invoke-DeleteAgent -RequestedName $AgentName -AlreadyConfirmed:$Confirmar; break }
        { $_ -in @('alias', 'atajo') } { Invoke-AgentAlias -RequestedName $AgentName -RequestedAlias $AliasName; break }
        { $_ -in @('listar', 'list') } { Show-AgentList; break }
        { $_ -in @('modelos', 'models') } { Show-Models; break }
        { $_ -in @('diagnostico', 'doctor', 'diagnostics') } { Show-Diagnostics; break }
        { $_ -in @('ayuda', 'help', '--help', '-h') } { Show-Help; break }
        { $_ -in @('version', '--version') } { Write-Host (Get-HermesManagerVersion); break }
        default { throw "Comando desconocido: $Command. Usa 'hermes ayuda'." }
    }
} catch {
    Write-LocalizedManagerLog -Level ERROR -Message $_.Exception.Message
    Write-Host ('ERROR: ' + (ConvertTo-HermesLocalizedText -Text $_.Exception.Message)) -ForegroundColor Red
    exit 1
}
