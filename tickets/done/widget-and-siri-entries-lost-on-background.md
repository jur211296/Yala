---
id: widget-and-siri-entries-lost-on-background
status: done
priority: low
area: routing
created: 2026-10-10
updated: 2026-10-11
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

## Resuelto (2026-10-11)

Al pasar a segundo plano, `AppRouter.resetTransients` aparca en `DeferredIntentBuffer` las entradas de voz, imagen y
nuevo registro (y el consentimiento de IA que piden) que seguían en cola, y vuelven por el drenaje del buffer en la
siguiente vuelta a primer plano o en el arranque. Caducan si la app pasa fuera más de 15 min
(`DeferredIntentBufferLogic.parkedEntryTTL`). La hoja de Yala Pro no se aparca.

Medido: `WidgetEntryBackgroundUITests` (Estadísticas delante → enlace desde fuera → segundo plano → vuelta → al ir al
Panel se abre la voz / el Nuevo registro) y `WidgetAndSiriEntriesBackgroundTests`.

La otra pregunta de este ticket —si deben llevar al Panel— sigue abierta en
`widget-and-siri-entries-wait-for-the-panel-tab`.
