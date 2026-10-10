---
description: Qué frena el merge en el CI de GitHub (qa.yml) y qué solo avisa — los unit bloquean desde el 2026-10-10, la UI no. Se carga al tocar el workflow o sus scripts.
paths:
  - ".github/workflows/qa.yml"
  - "qa/scripts/ci-*.sh"
---

# CI de GitHub: qué frena el merge

El ruleset de `2.1` exige tres checks: `tests`, `coverage-index` y `gateway`. El auto-merge
(ADR-054 de casa) mergea en cuanto los tres salen verdes. Leerlo cuesta un comando:
`gh api repos/jur211296/Yala/rulesets/24270515`.

| Qué | ¿Frena el merge? | Dónde |
|---|---|---|
| Unit pure-logic y context-based | **Sí**, desde el 2026-10-10 | job `tests` |
| UI (XCUITest) | No: advisory y solo en la nocturna | job `ui` |
| El aviso a Grok | No, salvo que no quede ningún canal | job `aviso` |

## La regla: un unit en rojo pone `tests` en rojo

- **Nunca `continue-on-error` en un paso de unit.** GitHub pinta de verde un paso así aunque
  `xcodebuild` salga con 65, y el PR entra en cola con el rojo dentro. Pasó: `UploadOrderTests` y
  `PrivateSessionMarkTests` entraron en `2.1` en rojo (3 y 7 de octubre). El banco
  `qa/scripts/ci-unit-bloqueante-test.sh`, en `coverage-index`, falla si vuelve.
- **Un flaky se cubre con reintento acotado, nunca con advisory.** Los dos pasos usan
  `ci-reintentar-rojos.sh`: repite solo los casos rojos, hasta 3 vueltas, y en un PR verde no cuesta
  nada. El flaky lleva su ticket (hoy `spike-r3-eje-4b-flaky-en-suite-completa`).
- **Nunca `-retry-tests-on-failure` en un paso de unit.** Con Swift Testing repite la selección
  entera, no el caso: un rojo triplica el paso y el tope de 45 min del job lo cancela.
- **Context-based corre aunque pure-logic salga en rojo** (`if: !cancelled() && build ok`). Si se
  saltara, el aviso leería ese `skipped` como «la suite no llegó a correr».

Volver a poner un paso de unit en advisory es una decisión de Jürgen, no un arreglo. Ticket del
cambio: `ci-warns-but-does-not-block`.

## El tope del job cancela, y una cancelación también frena

Un job `tests` que agota sus 45 min sale `cancelled`, y un check requerido cancelado también
bloquea el merge. Eso no lo trajo la promoción de los unit. Medido del 30-sep al 10-oct: 7 de 280
runs de PR y push, seis por el reintento viejo que triplicaba pure-logic (retirado el 6-oct) y uno
por un runner lento (build de 23 min frente a 13-15). Se relanza el job
(`gh run rerun <id> --failed`); quitar el tope no es la salida. Ticket:
`ci-tests-job-ceiling-cancels-green-runs`.
