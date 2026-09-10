# Política de seguridad

## Versiones compatibles

Solo la versión publicada más reciente recibe correcciones de seguridad.

## Informar de una vulnerabilidad

No abras una incidencia pública que incluya claves, archivos `.env`, `config.yaml`, conversaciones, registros completos o datos personales. Utiliza el canal privado de seguridad de GitHub del repositorio.

Incluye únicamente la versión de Hermes Manager, versión de Windows y Docker Desktop, pasos mínimos, impacto y registros redactados.

## Modelo de seguridad

- La Release no contiene imágenes Docker. Docker descarga la imagen externa configurada cuando se necesita.
- La imagen predeterminada de `nousresearch/hermes-agent` está fijada por digest para impedir cambios silenciosos. Verifica y actualiza explícitamente ese digest cuando adoptes una nueva versión.
- Los agentes se ejecutan en contenedores endurecidos con sistema de archivos de solo lectura, capacidades reducidas y `no-new-privileges`.
- No se monta el socket de Docker dentro de los agentes.
- No se publican puertos por defecto.
- La red bridge permite conexiones salientes hacia proveedores y servicios configurados; no ofrece aislamiento de Internet.
- Los datos persistentes permanecen en la carpeta de instalación.
- La imagen ejecutada puede leer y modificar el directorio `data` del agente, incluidas las credenciales que el usuario configure allí.
- Los alias son archivos `.cmd` locales y se valida que no colisionen con comandos existentes.
- El generador de Releases rechaza datos de ejecución y exportaciones de imágenes de contenedor.

Hermes Manager no puede proteger claves que el usuario copie, publique o conceda a herramientas de terceros. Rota inmediatamente cualquier clave expuesta.
