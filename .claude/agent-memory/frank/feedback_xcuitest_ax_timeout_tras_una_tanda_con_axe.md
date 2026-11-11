---
name: xcuitest-ax-timeout-tras-una-tanda-con-axe
description: tras ~40 min conduciendo el simulador con axe, el XCUITest no arranca («Timed out waiting for AX loaded»); reiniciar el simulador lo cura
metadata:
  type: feedback
---

Tras una tanda larga de capturas conduciendo el simulador con `axe` (describe-ui, tap, swipe; sin teclear), las dos
corridas siguientes de XCUITest murieron sin ejecutar un caso: `YalaUITests-Runner … failed to initialize for UI testing
(Underlying Error: Timed out waiting for AX loaded notification)`, exit 65, centinela en 0. Disco y carga, bien.
Apagar el simulador, arrancarlo, `bootstatus -b` y 45 s de espera, todo dentro de `sim-lock.sh`: la corrida siguiente
dio 23/23 en verde (lote 07 de 2.3, 2026-11-10, Max).

**Why:** el rojo no tiene línea de fallo y cae antes del primer caso: es entorno, no código, y repetir sin reiniciar da
lo mismo.

**How to apply:** si haces capturas con `axe` antes del gate, reinicia el simulador al acabar la tanda y antes del
XCUITest. Si ya salió el AX timeout, no repitas a ciegas: reinicia. Relacionado: [[conducir-simulador-con-axe]] y la
regla de `testing.md` de no apagar entre corridas (vale para corridas seguidas, no para salir de este estado).
Y los chips de Estadísticas a veces ignoran el primer `axe tap --id`: comprueba con `describe-ui` y repite.

**No hace falta `axe` para caer ahí** (lote 10 de 2.3, 2026-11-10, Max): simulador recién arrancado, `YalaTests`
entero (13.435 casos) y justo después el XCUITest del gate → el mismo AX timeout. La misma cura (reiniciar dentro de
`sim-lock.sh` + 45 s) dio la corrida buena. Tras una tanda larga de unit tests, reinicia antes del XCUITest.
