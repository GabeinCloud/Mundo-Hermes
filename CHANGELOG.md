# Changelog

Todos los cambios relevantes se documentarán aquí.

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
