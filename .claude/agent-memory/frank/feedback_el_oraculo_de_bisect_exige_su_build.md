---
name: el-oraculo-de-bisect-exige-su-build
description: En una bisección con build-for-testing + test-without-building, un build fallido deja correr el binario ANTERIOR y da un veredicto falso; el oráculo debe salir 125 (skip) si no ve «TEST BUILD SUCCEEDED»
metadata:
  type: feedback
---

El oráculo de una bisección comprueba que SU build pasó antes de leer el test; si no, sale 125 (skip).

**Why:** el 2026-10-27 (S12b, selectores de «Detalles» en Yala IA) `test-without-building` corrió el `.app` del
punto anterior cuando el build de `43daa3354` falló, y dio un «verde» que movía la bisección al sitio equivocado.
Además ese fallo de build era del incremental: relanzado, el commit compilaba y daba rojo. Y la hipótesis del ticket
(«el lote 07») era falsa — el primer rojo era #602.

**How to apply:** en el script del oráculo, `grep -q "TEST BUILD SUCCEEDED" build.log || exit 125`; antes de creer
un «no compila» ajeno, relanza una vez ([[rojo-de-compilacion-en-fichero-ajeno]]). Mide el extremo «bueno» de la
hipótesis del ticket antes de bisecar desde él ([[la-premisa-del-encargo-tambien-se-mide]]).
