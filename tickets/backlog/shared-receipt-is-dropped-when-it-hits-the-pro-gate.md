---
id: shared-receipt-is-dropped-when-it-hits-the-pro-gate
status: backlog
priority: low
area: pro, image entry, share extension
created: 2026-10-19
updated: 2026-10-19
source: lote decidido 2.2 · 06 — Yala Pro (encargo 2026-10-19-lote-decidido-2-2-06-yala-pro, PR #561)
---

# Un recibo compartido que choca con «Función Pro» se descarta y, tras comprar, la hoja de foto sale vacía

## Qué pasa

Siendo gratis, compartir una foto o un PDF a Yala (extensión de compartir, o soltar un recibo en el iPad) choca con la puerta de Pro: `AppBootstrapper.enqueueSharedImage` descarta el lote (`removePendingImageBatch`) y presenta «Función Pro». Si la persona compra ahí, desde el lote 06 «Comenzar» abre el registro por imagen (`openAIEntryAfterUnlock(.image)`), pero **sin** la foto que había compartido: tiene que volver a compartirla.

## Medido

Por lectura, en la review adversarial del lote 06 (lente de compra y presentaciones). No reproducido en el simulador.

## Arreglo probable

Conservar el lote pendiente mientras «Función Pro» está abierta y, si se compra, reabrir el registro por imagen con él (el camino de `pendingSharedImageURL`). Si no se compra, descartarlo al cerrar como hoy.
