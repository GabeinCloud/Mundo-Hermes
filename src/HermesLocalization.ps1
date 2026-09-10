Set-StrictMode -Version 2.0

$script:HermesLanguage = 'es'

function Set-HermesLanguage {
    param([ValidateSet('es', 'en')][string]$Language = 'es')
    $script:HermesLanguage = $Language
}

function ConvertTo-HermesLocalizedText {
    param([AllowEmptyString()][string]$Text)

    if ($script:HermesLanguage -ne 'en' -or [string]::IsNullOrEmpty($Text)) { return $Text }

    $translations = [ordered]@{
        '========================================' = '========================================'
        '            HERMES MANAGER' = '            HERMES MANAGER'
        'Agentes sencillos sobre Docker, sin tocar Docker.' = 'Simple agents on Docker, without touching Docker.'
        'Pulsa Intro para continuar' = 'Press Enter to continue'
        'Responde s o n.' = 'Answer y or n.'
        'Todavía no hay agentes. Elige Crear agente.' = 'There are no agents yet. Choose Create agent.'
        'Agentes:' = 'Agents:'
        'Número o nombre' = 'Number or name'
        'No hay agentes creados.' = 'No agents created.'
        'CREAR AGENTE' = 'CREATE AGENT'
        'El gestor guardará su identidad, configuración y datos en una carpeta propia.' = 'The manager will keep its identity, configuration and data in its own folder.'
        'Nombre del agente (ejemplo: publisher)' = 'Agent name (example: publisher)'
        '¿Para qué servirá?' = 'What will it be used for?'
        '¿Quieres configurar ahora el proveedor y el modelo?' = 'Do you want to configure the provider and model now?'
        '¿Quieres iniciar el agente ahora?' = 'Do you want to start the agent now?'
        'Agente ''{0}'' creado.' = 'Agent ''{0}'' created.'
        'Datos: {0}' = 'Data: {0}'
        'Alias para abrirlo desde cualquier terminal [{0}]' = 'Alias to open it from any terminal [{0}]'
        'Alias creado: escribe ''{0}'' en una terminal nueva.' = 'Alias created: type ''{0}'' in a new terminal.'
        'Hermes abrirá su asistente oficial. Las respuestas quedarán dentro de la carpeta del agente.' = 'Hermes will open its official setup assistant. Answers will remain inside the agent folder.'
        '''{0}'' está en marcha.' = '''{0}'' is running.'
        'Abriendo conversación con ''{0}''. Escribe /exit para salir.' = 'Opening a conversation with ''{0}''. Type /exit to exit.'
        '''{0}'' está detenido.' = '''{0}'' is stopped.'
        'Actualizando {0}...' = 'Updating {0}...'
        'Todos los agentes están actualizados.' = 'All agents are up to date.'
        '''{0}'' está actualizado.' = '''{0}'' is up to date.'
        'Operación cancelada.' = 'Operation cancelled.'
        '¿Mover ''{0}'' a la papelera de Hermes?' = 'Move ''{0}'' to the Hermes trash?'
        'Agente retirado. Copia recuperable: {0}' = 'Agent removed. Recoverable copy: {0}'
        'Alias corto [{0}]' = 'Short alias [{0}]'
        'Alias listo: {0}' = 'Alias ready: {0}'
        'Abre una terminal nueva para utilizarlo desde cualquier carpeta.' = 'Open a new terminal to use it from any folder.'
        'En una terminal nueva, escribe ''{0}'' para abrir el agente.' = 'In a new terminal, type ''{0}'' to open the agent.'
        'Ollama no está disponible o no tiene modelos instalados.' = 'Ollama is unavailable or has no installed models.'
        'Modelos locales disponibles para los agentes:' = 'Local models available to agents:'
        'DIAGNÓSTICO HERMES MANAGER' = 'HERMES MANAGER DIAGNOSTICS'
        '  Versión gestor:  {0}' = '  Manager version:  {0}'
        '  Imagen Hermes:   {0}' = '  Hermes image:     {0}'
        '  Docker CLI:      {0}' = '  Docker CLI:       {0}'
        '  Motor Docker:    {0}' = '  Docker engine:    {0}'
        '  Agentes:         {0}' = '  Agents:           {0}'
        '  Modelos Ollama:  {0}' = '  Ollama models:    {0}'
        'NO ENCONTRADO' = 'NOT FOUND'
        'LISTO' = 'READY'
        'DETENIDO/NO DISPONIBLE' = 'STOPPED/UNAVAILABLE'
        'Instala Docker Desktop para poder iniciar agentes.' = 'Install Docker Desktop to start agents.'
        'USO FÁCIL' = 'EASY USE'
        'Haz doble clic en "Hermes Manager.cmd" para abrir el menú.' = 'Double-click "Hermes Manager (English).cmd" to open the menu.'
        'COMANDOS OPCIONALES' = 'OPTIONAL COMMANDS'
        '  Crear y configurar un agente' = '  Create and configure an agent'
        '  Volver a configurar proveedor/modelo' = '  Configure provider/model again'
        '  Iniciar la instancia' = '  Start the instance'
        '  Conversar con el agente' = '  Chat with the agent'
        '  Detener la instancia' = '  Stop the instance'
        '  Descargar y aplicar Hermes reciente' = '  Download and apply the current Hermes image'
        '  Actualizar todos los agentes' = '  Update all agents'
        '  Mover el agente a la papelera interna' = '  Move the agent to the internal trash'
        '  Crear o cambiar su alias global' = '  Create or change its global alias'
        '  Mostrar agentes y estado' = '  Show agents and status'
        '  Mostrar modelos locales de Ollama' = '  Show local Ollama models'
        '  Comprobar requisitos' = '  Check requirements'
        'Agentes configurados: {0}' = 'Configured agents: {0}'
        '  1. Crear agente' = '  1. Create agent'
        '  2. Abrir conversación' = '  2. Open conversation'
        '  3. Iniciar agente' = '  3. Start agent'
        '  4. Detener agente' = '  4. Stop agent'
        '  5. Configurar proveedor/modelo' = '  5. Configure provider/model'
        '  6. Actualizar agente' = '  6. Update agent'
        '  7. Listar agentes' = '  7. List agents'
        '  8. Modelos locales' = '  8. Local models'
        '  9. Eliminar agente' = '  9. Remove agent'
        '  A. Crear o cambiar alias de terminal' = '  A. Create or change terminal alias'
        '  D. Diagnóstico' = '  D. Diagnostics'
        '  0. Salir' = '  0. Exit'
        'Elige una opción' = 'Choose an option'
        'Opción no válida.' = 'Invalid option.'
        'ERROR: ' = 'ERROR: '
        'CARPETA DE INSTALACIÓN' = 'INSTALLATION FOLDER'
        'Pulsa Intro para utilizar: {0}' = 'Press Enter to use: {0}'
        'O escribe otra carpeta' = 'Or enter another folder'
        'HERMES MANAGER INSTALADO CORRECTAMENTE' = 'HERMES MANAGER INSTALLED SUCCESSFULLY'
        'Versión: {0}' = 'Version: {0}'
        'Carpeta: {0}' = 'Folder: {0}'
        'Abre una terminal nueva y escribe: hermes-manager' = 'Open a new terminal and type: hermes-manager-en'
        'También puedes utilizar el acceso directo del escritorio.' = 'You can also use the desktop shortcut.'
        'Abrir Hermes Manager' = 'Open Hermes Manager'
        'Hermes Manager se retirará del PATH y se eliminará el acceso directo.' = 'Hermes Manager will be removed from PATH and its shortcut will be deleted.'
        'Hay {0} agente(s) en esta instalación.' = 'This installation has {0} agent(s).'
        'Los datos NO se eliminarán. Utiliza -RemoveAllData únicamente después de crear una copia de seguridad.' = 'Data will NOT be deleted. Use -RemoveAllData only after making a backup.'
        'Escribe DESINSTALAR para continuar' = 'Type UNINSTALL to continue'
        'Escribe ELIMINAR DATOS para borrar permanentemente todos los agentes' = 'Type DELETE DATA to permanently delete all agents'
        'No se confirmó el borrado de datos.' = 'Data deletion was not confirmed.'
        'Hermes Manager y todos sus datos fueron eliminados.' = 'Hermes Manager and all its data were deleted.'
        'Accesos globales eliminados. La carpeta y los agentes se conservaron:' = 'Global access removed. The folder and agents were kept:'
        'ALIAS GLOBALES ACTIVADOS' = 'GLOBAL ALIASES ENABLED'
        'Ruta: {0}' = 'Path: {0}'
        'Disponibles:' = 'Available:'
        'Abre una terminal nueva antes de utilizarlos.' = 'Open a new terminal before using them.'
        'La ruta ya estaba registrada. Puedes abrir una terminal nueva y utilizarlos.' = 'The path was already registered. Open a new terminal to use them.'
        'Las comprobaciones de instalación terminaron correctamente.' = 'Installation checks completed successfully.'
    }

    $result = $Text
    foreach ($entry in $translations.GetEnumerator()) {
        $result = $result.Replace($entry.Key, $entry.Value)
    }
    $result = $result -replace 'USO .CIL', 'EASY USE'
    $result = $result -replace '^El gestor guardar. su identidad, configuraci.n y datos en una carpeta propia\.$', 'The manager will keep its identity, configuration and data in its own folder.'
    $result = $result -replace '^.Para qu. servir.$', 'What will it be used for?'
    $result = $result -replace '^.Quieres configurar ahora el proveedor y el modelo.$', 'Do you want to configure the provider and model now?'
    $result = $result -replace '^.Quieres iniciar el agente ahora.$', 'Do you want to start the agent now?'
    $result = $result -replace 'Haz doble clic en "Hermes Manager\.cmd" para abrir el men..', 'Double-click "Hermes Manager (English).cmd" to open the menu.'
    $result = $result -replace '  Crear y configurar un agente', '  Create and configure an agent'
    $result = $result -replace '  Volver a configurar proveedor/modelo', '  Configure provider/model again'
    $result = $result -replace '  Conversar con el agente', '  Chat with the agent'
    $result = $result -replace '  Crear o cambiar su alias global', '  Create or change its global alias'
    $result = $result -replace 'Elige una opci.n', 'Choose an option'
    $result = $result -replace '  D\. Diagn.stico', '  D. Diagnostics'
    $result = $result -replace 'Agente ''([^'']+)'' creado\.', 'Agent ''$1'' created.'
    $result = $result -replace 'Datos: (.+)', 'Data: $1'
    $result = $result -replace 'Actualizando (.+)\.\.\.', 'Updating $1...'
    $result = $result -replace '''([^'']+)'' est. en marcha\.', '''$1'' is running.'
    $result = $result -replace '''([^'']+)'' est. detenido\.', '''$1'' is stopped.'
    $result = $result -replace '''([^'']+)'' est. actualizado\.', '''$1'' is up to date.'
    $result = $result -replace '^Versi.n: ', 'Version: '
    $result = $result -replace '^Carpeta: ', 'Folder: '
    $result = $result -replace '^Tambi.n puedes utilizar el acceso directo del escritorio\.$', 'You can also use the desktop shortcut.'
    $result = $result -replace '^Pulsa Intro para utilizar: ', 'Press Enter to use: '
    $result = $result -replace '^Ruta: ', 'Path: '
    $result = $result -replace '^Hay (\d+) agente\(s\) en esta instalaci.n\.$', 'This installation has $1 agent(s).'
    $result = $result -replace '^.Mover ''([^'']+)'' a la papelera de Hermes\?$', 'Move ''$1'' to the Hermes trash?'
    $result = $result -replace '^Alias para abrirlo desde cualquier terminal \[([^\]]+)\]$', 'Alias to open it from any terminal [$1]'
    $result = $result -replace '^Alias creado: escribe ''([^'']+)'' en una terminal nueva\.$', 'Alias created: type ''$1'' in a new terminal.'
    $result = $result -replace '^Abriendo conversaci.n con ''([^'']+)''\. Escribe /exit para salir\.$', 'Opening a conversation with ''$1''. Type /exit to exit.'
    $result = $result -replace '^Agente retirado\. Copia recuperable: (.+)$', 'Agent removed. Recoverable copy: $1'
    $result = $result -replace '^Alias corto \[([^\]]+)\]$', 'Short alias [$1]'
    $result = $result -replace '^Alias listo: (.+)$', 'Alias ready: $1'
    $result = $result -replace '^En una terminal nueva, escribe ''([^'']+)'' para abrir el agente\.$', 'In a new terminal, type ''$1'' to open the agent.'
    $result = $result -replace '^Agentes configurados: (\d+)$', 'Configured agents: $1'
    $result = $result -replace '^  Carpeta:\s+(.+)$', '  Folder:           $1'
    $result = $result -replace '^  Versi.n gestor:\s+(.+)$', '  Manager version:  $1'
    $result = $result -replace '^  Imagen Hermes:\s+(.+)$', '  Hermes image:     $1'
    $result = $result -replace '^  Motor Docker:\s+(.+)$', '  Docker engine:    $1'
    $result = $result -replace '^  Agentes:\s+(.+)$', '  Agents:           $1'
    $result = $result -replace '^  Modelos Ollama:\s+(.+)$', '  Ollama models:    $1'
    $result = $result -replace '^Agente creado: (.+)$', 'Agent created: $1'
    $result = $result -replace '^Alias creado: (.+)$', 'Alias created: $1'
    $result = $result -replace '^Configuraci.n ejecutada: (.+)$', 'Configuration completed: $1'
    $result = $result -replace '^Agente iniciado: (.+)$', 'Agent started: $1'
    $result = $result -replace '^Agente detenido: (.+)$', 'Agent stopped: $1'
    $result = $result -replace '^Agente actualizado: (.+)$', 'Agent updated: $1'
    $result = $result -replace '^Agente movido a la papelera: (.+)$', 'Agent moved to trash: $1'
    $result = $result -replace '^Comando desconocido: (.+)\. Usa ''hermes ayuda''\.$', 'Unknown command: $1. Use ''hermes-en.cmd help''.'
    $result = $result -replace '^settings\.json no contiene hermes_image\.$', 'settings.json does not contain hermes_image.'
    $result = $result -replace '^settings\.json debe fijar hermes_image mediante @sha256:<digest>\.$', 'settings.json must pin hermes_image with @sha256:<digest>.'
    $result = $result -replace '^El nombre debe producir un identificador de 2 a 48 caracteres \(letras, n.meros y guiones\)\.$', 'The name must produce an identifier of 2 to 48 characters (letters, numbers and hyphens).'
    $result = $result -replace '^Debes indicar para qu. servir. el agente\.$', 'You must specify what the agent will be used for.'
    $result = $result -replace '^El agente ''([^'']+)'' ya existe\.$', 'Agent ''$1'' already exists.'
    $result = $result -replace '^No existe el agente ''([^'']+)''\.$', 'Agent ''$1'' does not exist.'
    $result = $result -replace '^El alias ''([^'']+)'' est. reservado por Windows o por una herramienta com.n\.$', 'Alias ''$1'' is reserved by Windows or a common tool.'
    $result = $result -replace '^El alias ''([^'']+)'' ya pertenece al agente ''([^'']+)''\.$', 'Alias ''$1'' already belongs to agent ''$2''.'
    $result = $result -replace '^El alias ''([^'']+)'' colisiona con el comando existente ''([^'']+)''\.$', 'Alias ''$1'' conflicts with existing command ''$2''.'
    $result = $result -replace '^El archivo ''([^'']+)'' no pertenece al agente ''([^'']+)''\.$', 'File ''$1'' does not belong to agent ''$2''.'
    $result = $result -replace '^No se pudo leer (.+)$', 'Could not read $1'
    $result = $result -replace '^Docker Desktop no est. disponible\. Inst.lalo o .brelo y vuelve a intentarlo\.$', 'Docker Desktop is unavailable. Install or open it and try again.'
    $result = $result -replace '^Docker Desktop no estuvo listo despu.s de (\d+) segundos\.$', 'Docker Desktop was not ready after $1 seconds.'
    $result = $result -replace '^No se encontr. docker\.exe\.$', 'docker.exe was not found.'
    $result = $result -replace '^Docker termin. con c.digo (\d+)\.$', 'Docker exited with code $1.'
    $result = $result -replace '^Docker termin. con c.digo (\d+)\.', 'Docker exited with code $1.'
    $result = $result -replace '^No hay agentes que actualizar\.$', 'There are no agents to update.'
    $result = $result -replace '^No hay alias configurados\. Abre Hermes Manager y utiliza la opci.n A\.$', 'No aliases are configured. Open Hermes Manager and use option A.'
    $result = $result -replace '^No se pudo registrar (.+) en el PATH del usuario\.$', 'Could not add $1 to the user PATH.'
    $result = $result -replace '^Esta versi.n de Hermes Manager solo admite Windows\.$', 'This version of Hermes Manager supports Windows only.'
    $result = $result -replace '^Ruta de instalaci.n no v.lida: (.+)$', 'Invalid installation path: $1'
    $result = $result -replace '^El paquete est. incompleto: falta (.+)$', 'The package is incomplete; missing $1'
    $result = $result -replace '^La carpeta de destino no est. vac.a y no es una instalaci.n reconocida: (.+)$', 'The destination folder is not empty and is not a recognized installation: $1'
    $result = $result -replace '^Las pruebas de Hermes Manager han fallado\.$', 'Hermes Manager checks failed.'
    $result = $result -replace '^No es una instalaci.n reconocida de Hermes Manager: (.+)$', 'This is not a recognized Hermes Manager installation: $1'
    $result = $result -replace '^El marcador de instalaci.n no es v.lido: (.+)$', 'The installation marker is invalid: $1'
    $result = $result -replace '^El marcador no corresponde a esta instalaci.n: (.+)$', 'The marker does not match this installation: $1'
    $result = $result -replace '^La instalaci.n est. incompleta; no se borrar. la carpeta: falta (.+)$', 'The installation is incomplete; the folder will not be deleted: missing $1'
    $result = $result -replace '^Se rechaz. el borrado de una ra.z de unidad: (.+)$', 'Refused to delete a drive root: $1'
    $result = $result -replace '^Se rechaz. el borrado de una ruta protegida: (.+)$', 'Refused to delete a protected path: $1'
    $result = $result -replace '^Se rechaz. el borrado de un enlace o punto de rean.lisis: (.+)$', 'Refused to delete a link or reparse point: $1'
    return $result
}

function Write-HermesLocalizedHost {
    param(
        [object[]]$Object,
        [switch]$NoNewline,
        [Nullable[ConsoleColor]]$ForegroundColor,
        [Nullable[ConsoleColor]]$BackgroundColor,
        [string]$Separator = ' '
    )
    $translated = @($Object | ForEach-Object {
        if ($_ -is [string]) { ConvertTo-HermesLocalizedText -Text $_ } else { $_ }
    })
    $writeParameters = @{ Object = $translated; Separator = $Separator }
    if ($NoNewline) { $writeParameters.NoNewline = $true }
    if ($null -ne $ForegroundColor) { $writeParameters.ForegroundColor = $ForegroundColor }
    if ($null -ne $BackgroundColor) { $writeParameters.BackgroundColor = $BackgroundColor }
    Microsoft.PowerShell.Utility\Write-Host @writeParameters
}

function Read-HermesLocalizedHost {
    param([string]$Prompt)
    return Microsoft.PowerShell.Utility\Read-Host (ConvertTo-HermesLocalizedText -Text $Prompt)
}
