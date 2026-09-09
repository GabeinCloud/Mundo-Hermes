# Hermes Manager for Windows

[English](README.en.md)

Configuración reproducible y gestor comunitario para crear agentes Hermes con Docker Desktop sin tener que escribir Docker Compose a mano.

> Este proyecto no es oficial ni está afiliado a Nous Research. La Release no incluye Hermes ni ninguna imagen Docker. Docker descarga la imagen pública externa `nousresearch/hermes-agent` cuando se necesita por primera vez.

## Instalación rápida

### Requisitos

- Windows 10 u 11 de 64 bits.
- Virtualización y WSL 2 habilitados.
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y abierto.

No necesitas instalar Python, Git, PowerShell 7 ni Hermes directamente en Windows. Ollama solo es necesario para modelos locales.

### Desde una Release de GitHub

1. Descarga `Hermes-Manager-Windows-<versión>.zip` desde **Releases**.
2. Descomprime el ZIP.
3. Haz doble clic en `Instalar.cmd`.
4. Pulsa Intro para usar la carpeta recomendada o escribe otra carpeta de instalación.
5. Espera a que terminen las comprobaciones.
6. Abre **Hermes Manager** desde el acceso directo del escritorio.

Eso es todo. El ZIP incluye el instalador, los scripts, las configuraciones, la documentación y las pruebas del gestor. No incluye Docker Desktop ni la imagen de Hermes: Docker descarga esa imagen automáticamente al configurar o iniciar el primer agente.

La carpeta recomendada es `%LOCALAPPDATA%\HermesManager`, pero puedes elegir otra durante la instalación. No se necesitan permisos de administrador si la ubicación elegida permite escribir al usuario. El instalador registra la carpeta `bin` de esa instalación en el `PATH` del usuario.

#### Verificación opcional de la descarga

La Release también publica un archivo `.sha256`. No es necesario para instalar, pero permite comprobar manualmente que el ZIP descargado no está dañado ni ha sido modificado. Se publica fuera del ZIP porque un archivo no puede verificar su propia descarga.

```powershell
$zip = '.\Hermes-Manager-Windows-<versión>.zip'
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

No publiques ni adjuntes esa carpeta a incidencias. Los directorios de datos, alias, registros, estado y papelera están excluidos por `.gitignore` y por el generador de Releases.

Consulta [GUIA-INSTALACION.md](GUIA-INSTALACION.md) para reproducir paso a paso la configuración, conocer todos los archivos generados y fijar una versión o digest concreto de la imagen.

## Comandos opcionales

```powershell
hermes-manager
# Los siguientes ejemplos usan la carpeta recomendada:
& "$env:LOCALAPPDATA\HermesManager\hermes.cmd" crear redactor
& "$env:LOCALAPPDATA\HermesManager\hermes.cmd" actualizar todos
```

## Actualización

- **Actualizar agente** descarga la imagen configurada y conserva sus datos.
- Para actualizar Hermes Manager, ejecuta `Instalar.cmd` desde una Release más reciente y elige la misma carpeta utilizada anteriormente. El instalador sustituye solo los archivos de programa.

## Desarrollo

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-HermesManager.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-PublicPackage.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Build-Release.ps1"
```

## Seguridad y licencia

Consulta [SECURITY.md](SECURITY.md), [NOTICE.md](NOTICE.md) y [LICENSE](LICENSE). No incluyas claves, configuraciones de agentes ni registros en informes públicos.
