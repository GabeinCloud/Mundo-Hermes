# Changelog

Todos los cambios relevantes se documentarán aquí.

## 1.2.1 - 2026-09-10

- README y guías alineados con los paquetes separados `English` y `Spanish`.
- Enlaces directos a la última Release e instrucciones claras sobre los archivos `Source code` automáticos de GitHub.
- Contenido real de cada ZIP descrito sin mencionar pruebas que no se distribuyen.

## 1.2.0 - 2026-09-10

- Paquetes de Release separados para español e inglés.
- El paquete inglés excluye lanzadores, documentación y pruebas en español.
- Traducción completa de errores, estados, confirmaciones y archivos generados para agentes ingleses.
- Guía de instalación, política de seguridad y aviso legal disponibles en inglés.

## 1.1.0 - 2026-09-10

- Instalador y gestor disponibles con mensajes y comandos en español o inglés.
- Accesos directos y alias ingleses separados para no duplicar la lógica del gestor.
- Documentación ampliada sobre el propósito del proyecto, Releases y datos privados.

## 1.0.0 - 2026-09-09

- Primera versión pública para Windows.
- Creación y gestión de agentes Hermes aislados en Docker.
- Instalador sin privilegios de administrador.
- Selección interactiva de la carpeta de instalación.
- Alias globales por agente.
- Actualización de imágenes preservando datos.
- Descarga bajo demanda de la imagen externa, sin incluir imágenes Docker en la Release.
- Imagen predeterminada fijada a un digest OCI multi-arquitectura verificado.
- Validación estricta de destinos de instalación y marcadores de desinstalación.
- Comprobaciones que impiden empaquetar exportaciones Docker u OCI.
- Guía reproducible con instalación sencilla, verificación SHA-256 opcional y descripción de toda la configuración generada.
- Integración opcional con Ollama.
- Pruebas de aplicación, instalación y contenido de Releases.
