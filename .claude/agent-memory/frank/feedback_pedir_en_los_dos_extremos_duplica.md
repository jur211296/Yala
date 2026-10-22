---
name: pedir-en-los-dos-extremos-duplica
description: Una reparación pedida en dos dispositivos duplica si re-hace TODO y no un delta; busca el indicio de que el otro ya reparó antes de pedir
metadata:
  type: feedback
---

Antes de hacer que un segundo dispositivo «también pida» una reparación, mide si esa reparación es un DELTA o re-hace
todo. Si re-hace todo, dos que la corren antes de cruzarse por el espejo crean cada uno su copia.

**Why:** 2026-09-27, encargo `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged`. La decisión del encargo
era «el receptor también pide la convergencia», y la apliqué tal cual con un docblock que decía «inocuo: la misma carrera
que cualquier gasto de grupo». La lente de dinero lo tumbó: la convergencia re-puentea TODO el histórico, no el delta
que llega por sync, así que el duplicado era permanente y aprobable dos veces. El arreglo fue pedir solo con un indicio
de que el otro ya reparó (filas posteriores a la señal).

**How to apply:** ante «que X también lo pida / lo haga», pregunta (1) ¿cuánto re-hace?, (2) ¿qué indicio local dice que
el otro extremo ya lo hizo? Y trata «es la misma carrera que ya existe» como una afirmación a medir: compara el TAMAÑO de
las dos carreras, no solo su forma. Relacionado: [[la-premisa-del-encargo-tambien-se-mide]], [[review-adversarial-caza-lo-mio]].
