# Cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/);
las versiones siguen `MAJOR.MINOR.PATCH` (ver `docs/release.md`, §4).

## [1.0.0] — pendiente de publicar

Primera versión.

### Funciones

- Línea de tiempo de tus fotos y videos agrupada por año, mes, día y momento.
- Calendario mensual con la foto de portada y la cantidad de cada día, y pantalla
  con todos los momentos de un día.
- Visor a pantalla completa: zoom en fotos (pellizco y doble toque), reproducción
  de video con pausa y barra de avance, y deslizamiento entre los recuerdos del día.
- Ajustes: estado del acceso a la galería, estado de la sincronización con
  "Volver a escanear", qué guarda la app, versión y licencias.
- Soporte de acceso limitado a la galería (Android 14+ e iOS 14+).

### Privacidad

- 100 % local: sin cuentas, servidores, analíticas ni permiso de Internet.
- La app no lee ni guarda la ubicación de las fotos.
- Sin copia de seguridad en la nube de los datos de la app.

### Rendimiento y robustez

- Sincronización incremental (milisegundos cuando no hay cambios) con
  reanudación si se interrumpe.
- Línea de tiempo perezosa: un mes con miles de fotos construye solo lo visible.
- Fechas dudosas (relojes sin configurar, fechas futuras) se tratan como
  "sin fecha" en vez de desordenar la línea de tiempo.
- Cada pantalla con error permite reintentar.
