---
id: pay-now-uitest-stops-on-the-possible-duplicate-notice-in-2-3
status: done
priority: medium
area: "planning, scheduled-payments, uitests"
created: 2026-11-06
updated: 2026-11-22
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

## Cierre (2026-11-22)

Medido el 2026-11-22 (sesión nocturna «pruebas de interfaz rojas de 2.3», Max): **verde en la nocturna de 2.3 del 22-nov** (run 44991989046, sobre b27dcc084, runner del CI iOS 27.0) y **verde en local** sobre origin/2.3 = ea35c1234 (iPhone 17 Pro, iOS 27.2, `Yala Dev`, cola del simulador; 9 casos de los 8 tickets en una corrida, 9/9).

Pasa (61 s en la nocturna, 27 s en local), sin el aviso de posible duplicado. Inferido: el «Posible duplicado» venía de la semilla, que el 19-nov dejó de fabricar un borrador que igualaba un transporte del día (commit 57d54796a); no hizo falta decidir nada de producto. Sin cambios.
