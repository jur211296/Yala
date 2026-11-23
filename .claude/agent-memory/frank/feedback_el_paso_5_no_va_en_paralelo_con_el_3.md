---
name: el-paso-5-no-va-en-paralelo-con-el-3
description: gate-ci-checks a la vez que el paso 2 o el 3 sale rojo (sim-lock-test espera turno y agota 300 s, o ve «ocupado»); solo, verde. Repetido el 22-nov
metadata:
  type: feedback
---

El 2026-11-11 (lote 2.3 · Planificación, un estado) lancé `gate-ci-checks.sh` en segundo plano mientras el paso 3
corría. El XCUITest murió por el timeout de AX ([[ax-loaded-timeout-se-cura-reiniciando]]) y `sim-lock-test.sh`, que
entró en cola detrás, salió con 4 rojos («la foto no se cuenta a sí misma: 6 de 6 fotos dijeron ocupado»). Repetido
solo, con el simulador en reposo: 37/37. No toqué `qa/scripts`.

**Why:** el banco mide procesos reales de la máquina; con un runner que se está muriendo cerca, ve «ocupado».

**How to apply:** el paso 5 va después del 3, no a la vez. Si sale ese rojo sin haber tocado `qa/scripts`, repite el
banco solo antes de buscar un bug.

**Volví a hacerlo el 2026-11-22** (bienvenida tras cuenta lista), esta vez contra el paso **2**: con `YalaTests` entero
en cola, el banco esperó su turno y cayó por su tope de 300 s; además la carga tumbó una prueba de tiempos
(`FotoWidgetPorEtapasTests`, 3/3 sola). La regla vale para los pasos 2 y 3: el 5 se lanza cuando no hay nada más en el
simulador, aunque parezca que la cola lo resuelve.
