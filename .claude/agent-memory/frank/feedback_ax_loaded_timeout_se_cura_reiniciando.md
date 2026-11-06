---
name: ax-loaded-timeout-se-cura-reiniciando
description: «Timed out waiting for AX loaded notification» con 0 casos: reiniciar el iPhone 17 Pro y calentar con un caso suelto; repetir sin reiniciar no sirve
metadata:
  type: feedback
---

Si el runner de XCUITest muere con «The test runner failed to initialize for UI testing (Timed out waiting for AX
loaded notification)», la corrida no ejecutó nada: es entorno, no test. Repetirla tal cual volvió a fallar igual (2 de
2, 2026-11-06). Lo que la curó: `simctl shutdown` + `boot` del iPhone 17 Pro, y un caso suelto de calentamiento antes del
subconjunto del gate (verde a la primera).

**Why:** salió tras tener dos simuladores arrancados (el SE de una reproducción y el 17 Pro) con el disco a 13 GB; el
centinela decía «estuviste solo», así que no era una colisión.

**How to apply:** al ver ese mensaje, no relances el gate: apaga cualquier simulador extra, reinicia el 17 Pro, corre un
caso suelto y luego el subconjunto. Si creas un simulador para reproducir (el SE), apágalo y bórralo en cuanto acabes,
antes del gate. Relacionado: [[el-carril-espera-a-cola-a]].
