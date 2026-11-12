---
name: barrido-filtro-doble-minimo-qa
description: Criterio de Jürgen del 2026-10-24 para el barrido de QA — a su iPhone solo llega lo grave Y no validable en sim/tests; los vistos buenos van uno por mensaje, fuera de la tanda
metadata:
  type: feedback
---

Jürgen quiere probar **lo menos posible**. A la tanda del iPhone solo va lo que cumple las dos: (1) un fallo rompería
gravemente un flujo principal **y** (2) no se puede validar bien en el simulador ni con los tests que hay. Todo lo
demás va a `done`: accesibilidad y tamaños, edge cases de pocos usuarios, cards con XCUITest del flujo entero (aunque
pidan «sesión real») y lo que el simulador reproduce.

Los vistos buenos visuales no van en la tanda ni en un solo lote: Frank, el bot, se los manda **una pregunta por
mensaje, con sus fotos**, y él aprueba al momento.

**Why:** lo pidió en el 1:1 del 2026-10-24 (13:39 Lima), tras un barrido de 72 cards que aún le dejaba cosas «por si
acaso». Ya lo había dicho para la accesibilidad el 14-oct ([[feedback-qa-sin-accesibilidad]]).

**How to apply:** en cada barrido, ante la duda el item no va a la tanda. Si al repasarla encuentras un item que
cumple solo una de las dos condiciones, sácalo. La skill `/barrido-qa` §2 y §4 lo concreta; no aflojes el filtro
aunque una nota antigua o un ticket digan «probar en teléfono real». Relacionado:
[[barrido-una-card-que-ya-fallo-no-va-a-la-tanda]].
