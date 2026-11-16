---
name: una-sesion-yala-por-maquina
description: Orden de Jürgen 2026-11-05 — en cada Mac solo una sesión de Yala a la vez (chocan los simuladores); si ves otra viva, pausa sin tocar simulador ni CI de UI
metadata:
  type: feedback
---

En una máquina (Mini o Max) solo puede correr UNA sesión de Yala a la vez. Si al llegar al gate el `sim-lock`
dice que el turno es de otra sesión de Yala (otro worktree `Yala-…`), no se compite: se para sin tocar el simulador
ni lanzar checks que pidan el turno (`gate-ci-checks.sh` también lo pide, por `sim-lock-test.sh`), y se retoma cuando
el bot avisa que la otra cerró. Anotarlo en «Saltado o asumido sin preguntar».

**Why:** el 2026-11-05 los lotes N3 y N4 corrían a la vez en la Max; el simulador compartido dejó tres corridas de
XCUITest muertas con «Timed out waiting for AX loaded notification» y Jürgen ordenó la pausa.

**How to apply:** antes del primer XCUITest, `bash qa/scripts/sim-lock.sh --estado`; si lo tiene otro worktree de
Yala, pregunta al bot en vez de hacer cola larga o reiniciar el simulador. Tras retomar, un fetch: la otra sesión
probablemente mergeó sobre los mismos ficheros. Ver [[feedback_carril_espera_a_cola_a]].
