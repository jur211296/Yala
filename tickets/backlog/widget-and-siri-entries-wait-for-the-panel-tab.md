---
id: widget-and-siri-entries-wait-for-the-panel-tab
status: backlog
priority: low
area: routing
created: 2026-10-11
updated: 2026-10-11
source: encargo 2026-10-11-entradas-widget-siri-segundo-plano (pregunta abierta del ticket widget-and-siri-entries-lost-on-background)
---

# Voz, imagen o nuevo registro desde un widget o Siri esperan sin aviso a que vuelvas al Panel

## Qué pasa (medido en el código y en XCUITest, 2026-10-11)

`yala://voice-entry`, `image-entry` y `new-transaction` (widgets de entrada rápida, «Registrar con Siri», Centro de
Control) encolan su hoja para el Panel, pero no piden `.navigate(.panel)`. Si la app estaba en Estadísticas, Planificación
u otra pestaña, el toque trae Yala delante y no pasa nada: la hoja sale cuando la persona vuelve al Panel por su cuenta
(`PanelShell.drainPanelIfActive` solo drena con el Panel delante). `WidgetEntryBackgroundUITests` lo recorre así.

La foto compartida sí lleva al Panel (`enqueueSharedImage`), y desde el 2026-10-11 lo hace sin cerrar la hoja de otra
pestaña (`entry-to-panel-closes-sheets-of-other-tabs`).

## Qué hay que decidir

Si estas entradas deben llevar al Panel como la foto compartida. Si sí, es una línea por entrada en
`AppBootstrapper.executeAction` (y su fila en `docs/entry-points.md`); la espera por una hoja abierta ya la cubre el
Panel.
