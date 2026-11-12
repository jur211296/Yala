---
name: el-paso-5-no-va-en-paralelo-con-el-3
description: lanzar gate-ci-checks mientras corre el XCUITest del gate tumbó 4 casos de sim-lock-test («6 de 6 fotos ocupado»); aislado dio 37/37
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
