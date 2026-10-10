---
id: widget-and-siri-entries-lost-on-background
status: backlog
priority: low
area: routing
created: 2026-10-10
updated: 2026-10-10
source: auditoría de puntos de entrada del encargo 2026-10-10-share-image-reading-does-not-always-start
---

# Voz, imagen o nuevo registro desde un widget o Siri se pierden si la app pasa a segundo plano antes

## Qué pasa (inferido del código, sin reproducir)

`yala://voice-entry`, `image-entry` y `new-transaction` (widgets de entrada rápida y los intents de Siri que abren la
app) producen intents transitorios sin fuente durable. Si la app pasa a segundo plano antes de presentarlos —por ejemplo
porque había una hoja abierta y el Panel los retenía—, `AppRouter.resetTransients` los tira y nadie los vuelve a pedir.
Tampoco piden `.navigate(.panel)`: si la persona está en otra pestaña, esperan a que vuelva al Panel.

## Qué haría falta decidir

Si una entrada desde fuera debe llevar al Panel (como la foto compartida) y si debe sobrevivir a un segundo plano.
Hoy es coherente con «lo pediste y no lo viste, vuelve a tocarlo»; la foto compartida no lo es porque trae un fichero.

Ver `docs/entry-points.md`.
