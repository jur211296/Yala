---
id: shared-photo-waits-silently-behind-an-open-panel-sheet
status: backlog
priority: medium
area: image
created: 2026-10-10
updated: 2026-10-10
source: decisión pendiente del encargo 2026-10-10-share-image-reading-does-not-always-start
---

# Una foto compartida espera en silencio detrás de una hoja abierta del Panel

## Qué pasa (medido en simulador)

Si al compartir la foto Yala tiene abierta una hoja del Panel —la Bandeja, la hoja de lectura de una foto anterior, un
formulario—, la lectura espera a que esa hoja se cierre y arranca sola al cerrarla
(`SharedImageEntryUITests.test_inboxOpen_…`, `test_background_twice_…`). Es lo que pedía el encargo. Pero mientras la
hoja siga abierta, Yala no dice nada: quien compartió ve la Bandeja como la dejó y puede pensar que la lectura no
arrancó, y cerrar la app del todo. Es una explicación posible del reporte del 10-oct («a veces no arranca hasta
reiniciar»), no medida en su iPhone.

## Opciones para Jürgen

- **A — Dejarlo así** (esperar en silencio y arrancar al cerrar).
- **B — Que la foto compartida cierre las hojas sin datos por guardar** (Bandeja sin edición abierta, hoja de lectura
  en «elige una foto», información de un widget) y arranque; las que tienen datos sin guardar siguen esperando.
- **C — Esperar, pero decirlo**: un aviso breve («Tu foto se leerá al cerrar esto»).

Recomendación: B. Es lo que la persona espera al compartir, y lo que ya pasa con las hojas de otras pestañas.
