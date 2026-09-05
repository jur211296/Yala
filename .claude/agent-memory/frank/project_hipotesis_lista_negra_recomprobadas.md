---
name: hipotesis-lista-negra-recomprobadas
description: Qué hipótesis de la Lista Negra volví a comprobar y cuándo. Caducan. El 2026-09-05 el runner de XCUITest corrió en local sin problemas, contra lo que dicen el coverage-index y el CLAUDE.md.
metadata:
  type: project
---

**Registro de re-comprobaciones.** Una hipótesis de la Lista Negra caduca cuando cambia el entorno
(Xcode, macOS, runtime, disco), y la regla del repo obliga a re-medirla antes de darla por buena.
Aquí queda **cuándo la miré yo y qué salió** — el veredicto vivo está en su fuente, no aquí.

## «El runner de XCUITest está roto en la Mac local» — NO se reprodujo el 2026-09-05

**Dónde se afirma:** `qa/coverage-index.json`, área `session-sign-out`, dice *«XCUITest determinista
del cover posible via el seam DEBUG — diferido hasta plan CI (runner roto en la Mac local, Lista
Negra M1)»*.

**Qué medí:** en el gate del ticket `secondary-guest-exit-lock-and-outbox` corrí tres suites de
`YalaUITests` (`ProfileSettingsUITests`, `YalaAccountUITests`, `SecondarySessionGateUITests`) con la
scheme `Yala Dev` en el iPhone 17 Pro. **8 tests, 0 fallos, `TEST SUCCEEDED`** en ~130 s. Ni un
`RequestDenied` ni un `xctrunner` que no lanza. El disco estaba en 27 GiB libres, por encima del
umbral de 25.

**Qué NO prueba:** que el runner esté sano *siempre*. Los dos síntomas conocidos son dependientes
del entorno —disco lleno, y apagar el simulador entre corridas (`testing.md` L91)— así que esto dice
«hoy, con disco holgado y sin apagar el simulador, corre», no «la hipótesis era falsa».

**How to apply:** cuando un documento diga que los XCUITest no se pueden correr en local, **pruébalo
antes de diferir trabajo por ello** — cuesta una corrida. Si falla, mira primero
`bash qa/scripts/disk-report.sh` y si el simulador se apagó entre corridas, antes de anotarlo como
roto. Y si vuelve a correr verde, actualiza la afirmación en su fuente: el diferimiento que justifica
ya no se sostiene solo.

Relacionado: [[mis-mediciones-fallan-por-el-filtro]] — el décimo caso de esa ficha es justo el error
inverso, culpar al entorno sin leer el error entero.
