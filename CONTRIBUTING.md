# Contribuir

Gracias por mejorar Hermes Manager for Windows.

## Antes de enviar cambios

1. No incluyas carpetas `agents`, `bin`, `logs` o `trash`.
2. No incluyas claves, archivos `.env`, configuraciones reales ni conversaciones.
3. No incluyas imágenes Docker, exportaciones OCI, modelos ni discos virtuales.
4. Mantén compatibilidad con Windows PowerShell 5.1.
5. Utiliza rutas relativas y evita nombres de usuario o rutas personales.
6. Ejecuta las dos suites de pruebas.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-HermesManager.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-PublicPackage.ps1"
```

Los cambios de seguridad, almacenamiento, Docker, instalación o borrado deben incluir pruebas específicas.
