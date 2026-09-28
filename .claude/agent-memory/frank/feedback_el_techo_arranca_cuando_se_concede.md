---
name: el-techo-arranca-cuando-se-concede
description: Un techo de confianza nuevo se ancla al instante en que se CONCEDE la confianza, no a un reloj anterior que ya estaba corriendo
metadata:
  type: feedback
---

El reloj de un techo nuevo arranca cuando se concede lo que acota, no en el sello de una espera anterior que "ya había".

**Why:** 2026-09-28, `wipe-division-exclusion-trusts-the-origin-to-converge`. Anclé las 72 h de la promesa en `Awaiting.since`
(desde que el receptor esperaba el reparto) por reusar el campo. La lente de sync lo tumbó: un reparto que llega tarde, o un
receptor que no arranca en días, daba la promesa por vencida en el MISMO arranque que la apuntaba — cero margen para el
origen, y copias dobles si acababa de converger.

**How to apply:** al poner un techo, pregunta «¿desde cuándo tiene la otra parte ocasión de cumplir?» y usa ese instante.
Si reutilizas un sello existente, escribe el caso «la concesión llega tarde» y comprueba que no vence en el acto. Pariente de
[[un-plazo-nuevo-se-clava-con-sus-dos-vecinos]] y [[el-techo-que-se-resetea-no-es-un-techo]].
