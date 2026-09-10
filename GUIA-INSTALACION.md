# Guía de instalación pública

Esta guía permite reproducir la configuración de Hermes Manager en otro equipo. El repositorio y el ZIP contienen únicamente scripts, documentación y la plantilla que genera Docker Compose. No contienen el código de Hermes Agent, una imagen Docker exportada, modelos ni datos de agentes.

## 1. Instalar Docker Desktop

1. Descarga Docker Desktop desde <https://www.docker.com/products/docker-desktop/>.
2. Instálalo utilizando WSL 2.
3. Reinicia Windows si se solicita.
4. Abre Docker Desktop y espera a que el motor esté listo.

## 2. Instalar Hermes Manager

1. Descarga `Hermes-Manager-Windows-<versión>.zip` desde GitHub Releases.
2. Descomprime el ZIP.
3. Haz doble clic en `Instalar.cmd` dentro de la carpeta descomprimida.
4. Pulsa Intro para instalar en `%LOCALAPPDATA%\HermesManager` o escribe otra carpeta.
5. Espera a que terminen las comprobaciones.
6. Abre el acceso directo **Hermes Manager**.

El ZIP ya contiene todo lo necesario para instalar el gestor: scripts, configuraciones, documentación y pruebas. No contiene Docker Desktop, Hermes Agent, modelos ni datos privados. Docker descarga la imagen de Hermes automáticamente cuando se necesita por primera vez.

La ruta recomendada no necesita permisos de administrador. También puedes elegir otra ubicación donde tu usuario tenga permiso de escritura. La carpeta debe estar vacía o contener una instalación reconocida de Hermes Manager.

El instalador copia los archivos del gestor, crea `agents`, `bin`, `logs` y `trash`, añade `bin` al `PATH` del usuario, ejecuta las pruebas y crea el acceso directo. No instala Docker, no descarga Hermes durante la instalación y no modifica el `PATH` del sistema.

### Verificación opcional

También puedes descargar el archivo `.sha256` publicado junto al ZIP para comprobar manualmente su integridad. Guarda ambos en la misma carpeta y ejecuta:

```powershell
$zip = '.\Hermes-Manager-Windows-<versión>.zip'
$esperado = ((Get-Content "$zip.sha256") -split '\s+')[0]
$actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
if ($actual -ne $esperado) { throw 'El ZIP no coincide con el checksum publicado.' }
'Checksum correcto'
```

Para instalar no necesitas clonar el repositorio. Descarga el ZIP de la sección **Releases**. Los enlaces **Source code (zip)** y **Source code (tar.gz)** de GitHub contienen el código fuente y no sustituyen al paquete de instalación.

## 3. Crear un agente

1. Elige **Crear agente**.
2. Introduce el nombre y su finalidad.
3. Acepta o cambia el alias de terminal sugerido.
4. Configura el proveedor y modelo mediante el asistente de Hermes Agent.
5. Inicia el agente.

Durante la configuración o el primer inicio, Docker descarga la versión aprobada de `nousresearch/hermes-agent` si no está disponible localmente. La referencia está fijada por digest para que el contenido no pueda cambiar sin una actualización explícita de Hermes Manager. La descarga se realiza desde el registro configurado por Docker y puede tardar varios minutos.

## 4. Archivos que se generan

Cada agente se guarda en `<carpeta de instalación>\agents\<nombre>`:

| Ruta | Contenido |
| --- | --- |
| `compose.yaml` | Configuración reproducible del contenedor. |
| `agent.json` | Nombre, finalidad, fecha de creación y alias. |
| `data\SOUL.md` | Identidad y forma de trabajo indicadas al crear el agente. |
| `data\.env` | Variables utilizadas por el contenedor. Puede contener datos sensibles. |
| `data\config.yaml` | Configuración creada por el asistente de Hermes, si corresponde. |
| `data\home` | Directorio personal persistente del proceso. |
| `data\workspace` | Documentos y trabajo persistente. |
| `data\logs` | Registros propios del agente. |

No subas al repositorio ni a incidencias `agents/`, `bin/`, `logs/`, `trash/`, archivos `.env`, `config.yaml` o `.hermes-manager-install.json`. Pueden contener credenciales, conversaciones, registros y rutas específicas del equipo.

La plantilla aplica estas decisiones:

- sistema de archivos del contenedor de solo lectura;
- un único volumen escribible, `data`, montado en `/opt/data`;
- `no-new-privileges`, eliminación de capacidades y solo las capacidades mínimas añadidas;
- límites de 2 CPU, 4 GB de memoria y 256 procesos;
- directorios temporales en memoria con `noexec`, salvo `/run` por compatibilidad;
- red bridge propia sin puertos publicados;
- modo YOLO y servidor API desactivados por defecto.

La red permite conexiones salientes. Son necesarias para acceder al proveedor configurado; no debe describirse como una red sin Internet.

## 5. Elegir o fijar la imagen

La imagen utilizada está en `<carpeta de instalación>\settings.json`:

```json
"hermes_image": "nousresearch/hermes-agent@sha256:41b9ed005cebcb3d3fb45206ce27cfb0356ba99b190c0924bab5141b15ad8e71"
```

El digest identifica exactamente el índice OCI aprobado, con manifiestos para `linux/amd64` y `linux/arm64`. **Actualizar agente** descarga o verifica esa misma imagen; no cambia silenciosamente a otra versión. Las nuevas versiones de Hermes Manager podrán actualizar el digest después de verificar una nueva publicación del proveedor.

Para usar otra versión de forma consciente, sustituye el valor por una etiqueta inmutable acompañada de su digest publicado por el proveedor:

```json
"hermes_image": "nousresearch/hermes-agent:<versión>@sha256:<digest>"
```

Hermes Manager pasa ese valor a Docker Compose. No descarga, almacena ni redistribuye la imagen dentro de su ZIP. Antes de cambiar una versión o digest, comprueba que existe en el registro oficial del proyecto.

## 6. Abrirlo desde una terminal

Cierra las terminales abiertas durante la instalación y abre una nueva. Escribe el alias elegido:

```powershell
redactor
```

Hermes Manager rechaza alias reservados o que colisionen con comandos existentes.

## 7. Reproducir la operación manualmente

La carpeta generada también puede utilizarse sin el menú. Abre PowerShell dentro de la carpeta del agente y ejecuta:

```powershell
docker compose run --rm --no-deps agent setup
docker compose up -d --remove-orphans
docker compose run --rm --no-deps agent chat
docker compose down --remove-orphans
docker compose pull agent
```

`setup` configura el proveedor, `up` inicia el agente, `chat` abre una conversación, `down` lo detiene y `pull` descarga la imagen configurada. Los datos permanecen en `data`.

## 8. Modelos locales

Instala y abre Ollama en Windows. Hermes Manager detecta sus modelos mediante `http://localhost:11434` y los contenedores se conectan mediante `http://host.docker.internal:11434`.

## 9. Actualizar

- Para Hermes Agent, utiliza **Actualizar agente** en el menú. Esta acción descarga o verifica la imagen fijada y conserva `data`. Para recibir una imagen aprobada más reciente, actualiza primero Hermes Manager.
- Para Hermes Manager, descarga una Release nueva, ejecuta su `Instalar.cmd` y selecciona la misma carpeta. Los agentes y datos existentes se conservan.

## 10. Copia de seguridad y desinstalación

Antes de borrar una instalación, detén los agentes y copia la carpeta `agents` a una ubicación segura. Esa carpeta contiene toda la configuración persistente y puede incluir credenciales.

Ejecuta `Desinstalar.cmd`. De forma predeterminada se eliminan el acceso directo y el registro en `PATH`, pero se conservan los agentes. El borrado completo requiere ejecutar el script con `-RemoveAllData` y dos confirmaciones explícitas.

El borrado completo solo se permite cuando el marcador identifica el producto, el esquema y la ruta exacta, están presentes los archivos del gestor y la raíz no es una ruta protegida ni un enlace.

## 11. Solución de problemas

- **Docker no encontrado:** instala Docker Desktop y ábrelo al menos una vez.
- **Motor detenido:** abre Docker Desktop y espera hasta que esté listo.
- **Alias no reconocido:** abre una terminal nueva o ejecuta `Activar alias globales.cmd`.
- **Alias equivocado:** ejecuta `Get-Command <alias> -All` y elimina cualquier función antigua que tenga prioridad.
- **Proveedor o modelo incorrecto:** utiliza **Configurar proveedor/modelo**.
