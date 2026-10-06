---
id: ci-one-red-in-pure-logic-triples-the-step-and-the-job-ceiling-cancels-it
status: backlog
priority: high
area: ci
created: 2026-10-06
updated: 2026-10-06
source: encargo 2026-10-06-pr369-tests-job-times-out-in-pure-logic (PR #369 cancelado tres veces)
---

# Un solo rojo en pure-logic triplica el paso y el tope del job lo cancela: el rojo advisory acaba bloqueando el merge

## Qué se midió

El paso `Unit tests (YalaTests pure-logic)` de `.github/workflows/qa.yml` corre con
`-retry-tests-on-failure`. Con Swift Testing, `xcodebuild` no repite el test que falló: **repite la suite entera**
hasta 3 veces («Retrying tests on failure. Running tests repeatedly up to 3 times»). Medido en los logs:

| run | rama | tests ejecutados | paso pure-logic | desenlace del job |
|---|---|---|---|---|
| 37434626440 (sano) | 2.1 | 8 954 en 880 suites | 13 min | success |
| 37417460535 (×2) | #369 | 26 889 en 2 643 suites | 26 y 29 min | cancelado (el context-based murió a medias) |
| 37436494168 | #369 | 26 913 en 2 643 suites | 28 min | cancelado en pure-logic |
| 37325431444 | 2.1, 2026-10-05 | 26 511 en 2 589 suites | 30 min | cancelado |
| 37083625365 · 37088395186 | 2.1, 2026-10-03 | — | 28 y 27 min | success por poco |

26 889 = 3 × 8 963. Con el build en 13-15 min, tres vueltas de ~9 min más el arranque pasan del tope de 45 min del
job (`timeout-minutes` del job `tests`) antes de que salte el de 30 del paso. El tope del JOB cancela, y
`continue-on-error` no rescata una cancelación (está escrito en el propio `qa.yml`).

En #369 el rojo era determinista (un test que dependía del idioma del simulador, arreglado en el propio PR). En
37325431444 era el flaky conocido de `SpikeR3ContainerReleaseTests` (eje 4a/4b), que acabó pasando en la tercera
vuelta («passed after 1510 seconds») y aun así el job se canceló.

## Por qué importa

- **El paso es advisory y deja de serlo según cuánto tarde.** Un rojo rápido sale `outcome: failure`, el job termina
  verde y el aviso de rojos advisory lo cuenta. El mismo rojo con tres vueltas cancela el job: `tests` sale rojo, el
  ruleset de `2.1` lo exige y el auto-merge se queda bloqueado.
- **El diagnóstico se pierde.** El job cancelado parece un cuelgue («pure-logic se corta por tiempo»), no un test en
  rojo. El aviso tampoco ayuda: lee `cancelled`, no el test que falló. Este encargo entero salió de ahí.
- **Recurre.** Tres días distintos en cuatro (10-03, 10-05, 10-06), y el flaky de SpikeR3 sigue abierto.

## Opciones (sin decidir)

1. **Reintentar solo lo que falló**: correr una vez sin reintento y, si hay rojos, sacar sus identificadores del
   `.xcresult` (`xcresulttool get test-results tests`) y repetir solo esos con `-only-testing`. Conserva el rescate
   del flaky y cuesta segundos. Es la opción que mejor encaja con «el paso es advisory».
2. **Quitar `-retry-tests-on-failure`** del paso: un rojo es un rojo y el aviso lo cuenta. El comentario del propio
   paso dice que «-retry no converge», aunque 37325431444 sí convergió.
3. **`-test-iterations 2`**: tope de dos vueltas. Con el build de hoy queda al límite (≈ 14 + 2 × 10 + arranque).
4. Subir el tope del job: no arregla nada, solo mueve el borde.

Antes de elegir, medir si el reintento repite la suite entera también con XCTest o solo con Swift Testing: aquí
solo se midió el segundo.
