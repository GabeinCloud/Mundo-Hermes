# Hermes Manager for Windows

[English](README.md)

Configuración reproducible y gestor comunitario para crear agentes Hermes con Docker Desktop sin tener que escribir Docker Compose a mano.

> Este proyecto no es oficial ni está afiliado a Nous Research. La Release no incluye Hermes ni ninguna imagen Docker. Docker descarga la imagen pública externa `nousresearch/hermes-agent` cuando se necesita por primera vez.

## Por qué existe este proyecto

Ejecutar Hermes en Windows implica preparar Docker Desktop, una configuración de Compose, los datos persistentes de cada agente y varios comandos habituales. Hermes Manager reúne esas piezas en un flujo pequeño y reproducible: crea agentes aislados, mantiene sus datos separados, los configura mediante el asistente oficial y permite iniciarlos o actualizarlos sin escribir Docker Compose a mano. Es una capa comunitaria de comodidad alrededor de Hermes, no un sustituto de Hermes ni de Docker Desktop.

## Instalación rápida

### Requisitos

- Windows 10 u 11 de 64 bits.
- Virtualización y WSL 2 habilitados.
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y abierto.

No necesitas instalar Python, Git, PowerShell 7 ni Hermes directamente en Windows. Ollama solo es necesario para modelos locales.

### Desde una Release de GitHub

1. Abre [Releases](https://github.com/GabeinCloud/Mundo-Hermes/releases/latest) y descarga `Hermes-Manager-Windows-<versión>-Spanish.zip`.
2. Descomprime el ZIP.
3. Haz doble clic en `Instalar.cmd`.
4. Pulsa Intro para usar la carpeta recomendada o escribe otra carpeta de instalación.
5. Espera a que terminen las comprobaciones.
6. Abre **Hermes Manager** desde el acceso directo del escritorio.

Eso es todo. El ZIP incluye el instalador, los archivos del gestor, la configuración y la documentación en español. No incluye Docker Desktop ni la imagen de Hermes: Docker descarga esa imagen automáticamente al configurar o iniciar el primer agente.

La carpeta recomendada es `%LOCALAPPDATA%\HermesManager`, pero puedes elegir otra durante la instalación. No se necesitan permisos de administrador si la ubicación elegida permite escribir al usuario. El instalador registra la carpeta `bin` de esa instalación en el `PATH` del usuario.

No necesitas ejecutar `git clone` para instalar o utilizar Hermes Manager. La página de **Releases** contiene el paquete preparado para usuarios. Los ZIP de **Source code** que muestra GitHub contienen el código fuente del repositorio y están destinados al desarrollo, no a la instalación normal.

La Release publica paquetes separados para español e inglés. El ZIP español contiene únicamente la experiencia y documentación para usuarios en español; el ZIP inglés utiliza nombres, menús, mensajes, archivos generados y documentación en inglés. Solo se mantiene la Release más reciente.

Dentro de **Assets**, elige el ZIP cuyo nombre termina en `-Spanish.zip`. No utilices los archivos automáticos **Source code (zip)** o **Source code (tar.gz)** para instalar: son copias del repositorio, no instaladores preparados.

#### Verificación opcional de la descarga

La Release también publica un archivo `.sha256`. No es necesario para instalar, pero permite comprobar manualmente que el ZIP descargado no está dañado ni ha sido modificado. Se publica fuera del ZIP porque un archivo no puede verificar su propia descarga.

```powershell
$zip = '.\Hermes-Manager-Windows-<versión>-Spanish.zip'
$esperado = ((Get-Content "$zip.sha256") -split '\s+')[0]
$actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
if ($actual -ne $esperado) { throw 'El ZIP no coincide con el checksum publicado.' }
```

## Crear el primer agente

1. Abre `Hermes Manager`.
2. Selecciona **1. Crear agente**.
3. Indica nombre y finalidad.
4. Elige un alias corto, por ejemplo `redactor` o `dev`.
5. Completa el asistente oficial de proveedor y modelo.
6. Inicia el agente.

Al configurar o iniciar el primer agente, Docker descarga Hermes desde el registro si la imagen todavía no existe en el equipo. Esa descarga no forma parte del instalador ni de este repositorio. Después abre una terminal nueva y escribe únicamente su alias:

```powershell
redactor
```

## Funciones

- Generar una configuración Docker Compose reproducible por agente.
- Separar los datos de cada agente y no publicar puertos por defecto.
- Configurar proveedor y modelo con el asistente de Hermes.
- Iniciar, detener y abrir conversaciones.
- Actualizar uno o todos los agentes.
- Detectar modelos locales de Ollama.
- Crear alias globales sin copiar scripts fuera de la instalación.
- Mover agentes retirados a una papelera recuperable.
- Diagnosticar Docker sin exponer secretos.

La configuración generada utiliza un sistema de archivos de contenedor de solo lectura, elimina capacidades por defecto, impide ganar privilegios y limita CPU, memoria y procesos. La red Docker separa los agentes y permite salida a Internet para los proveedores configurados; no es una red sin conexión.

## Datos y privacidad

Cada agente guarda su identidad, configuración, claves, conversaciones y documentos en `<carpeta de instalación>\agents\<nombre>\data`.

No publiques ni adjuntes esa carpeta a incidencias. Los directorios de datos, alias, registros y papelera están excluidos por `.gitignore` y por el generador de Releases.

No subas nunca `agents/`, `bin/`, `logs/`, `trash/`, `.env`, `config.yaml` ni `.hermes-manager-install.json`. Esas rutas pueden contener credenciales, conversaciones, registros o datos específicos de la instalación.

Consulta [GUIA-INSTALACION.md](GUIA-INSTALACION.md) para reproducir paso a paso la configuración, conocer todos los archivos generados y fijar una versión o digest concreto de la imagen.

## Comandos opcionales

```powershell
hermes-manager
# Los siguientes ejemplos usan la carpeta recomendada:
& "$env:LOCALAPPDATA\HermesManager\hermes.cmd" crear redactor
& "$env:LOCALAPPDATA\HermesManager\hermes.cmd" actualizar todos
```

## Actualización

- **Actualizar agente** descarga o verifica la imagen fijada por digest y conserva sus datos. Una nueva versión del gestor puede publicar un digest actualizado.
- Para actualizar Hermes Manager, ejecuta `Instalar.cmd` desde una Release más reciente y elige la misma carpeta utilizada anteriormente. El instalador sustituye solo los archivos de programa.

## Desarrollo

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-HermesManager.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-PublicPackage.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Build-Release.ps1"
```

## Seguridad y licencia

Consulta [SECURITY.md](SECURITY.md), [NOTICE.md](NOTICE.md) y [LICENSE](LICENSE). No incluyas claves, configuraciones de agentes ni registros en informes públicos.