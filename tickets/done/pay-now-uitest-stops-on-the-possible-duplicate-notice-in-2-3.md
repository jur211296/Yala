---
id: pay-now-uitest-stops-on-the-possible-duplicate-notice-in-2-3
status: backlog
priority: medium
area: "planning, scheduled-payments, uitests"
created: 2026-11-06
updated: 2026-11-06
source: "gate del lote de productividad 2.3 (hormiga, logos, sugerencias)"
---

# «Pagar ahora» no cierra su formulario en el XCUITest de 2.3

## Qué pasa

`ScheduledPaymentsLoteP1UITests/test_payNow_savesAndReturnsToThePayment_withoutTheInboxSuccessScreen` cae en la línea 54
(«Guardar no cerró el formulario»). Medido el 2026-11-06 en `origin/2.3` limpio (96237f150), con el simulador solo
(centinela 0): rojo en la base y en la rama del lote de productividad, que no toca ese flujo.

En el último fotograma del vídeo, el formulario «Pagar ahora el del 15 de noviembre» tiene encima, atenuado, un bloque
**«Posible duplicado»** con «Guardar de todas formas». La hipótesis (sin medir) es que el aviso de duplicado se lleva el
toque de «Guardar» o lo deja esperando una segunda confirmación que el test no da. Puede depender del día: el seed
(`scheduledSeedDay: 1`) y un registro del mismo pago cerca de hoy.

## Hecho cuando

Se sabe si el aviso de duplicado debe salir al pagar ahora un pago planificado (decisión de producto) y el test pasa
estable en `2.3`, o el test cubre ese aviso.
