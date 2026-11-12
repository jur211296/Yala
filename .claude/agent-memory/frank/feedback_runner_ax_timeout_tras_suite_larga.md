---
name: runner-ax-timeout-tras-suite-larga
description: XCUITest que muere con «Timed out waiting for AX loaded notification» tras correr YalaTests entero: reiniciar el simulador, no repetir a ciegas
metadata:
  type: feedback
---

Tras correr `YalaTests` entero (13.636 casos, ~6 min) en el mismo simulador, las dos corridas siguientes de XCUITest
murieron sin ejecutar un caso: `YalaUITests-Runner … failed to initialize for UI testing (Timed out waiting for AX loaded
notification)`, exit 65, `** TEST FAILED **`. Disco con 15 GB libres y centinela limpio: no era ni disco ni otra sesión.
`simctl shutdown` + `boot` + `bootstatus -b` + ~20 s de asiento, y la tercera pasó 14/14. Medido el 2026-11-12 en la Mini,
iOS 27.2, gate del lote de Registros 2.3.

**Why:** repetir igual gastó 1,5 min de presupuesto de UI por intento sin cambiar nada; el simulador se queda con la
accesibilidad colgada.

**How to apply:** si un XCUITest sale con esa línea y cero `Test Case`, no lo cuentes como rojo ni lo repitas tal cual:
reinicia el simulador una vez y vuelve a lanzar con `test-without-building`. Relacionado: [[el-carril-espera-a-cola-a]].
