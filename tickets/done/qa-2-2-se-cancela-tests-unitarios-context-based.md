---
id: qa-2-2-se-cancela-tests-unitarios-context-based
status: done
priority: medium
area: ci
created: 2026-10-26
updated: 2026-10-26
source: card tablero-qa-2-2-se-cancela-tests-unitarios-contex-9y84 (run 40422732167)
qa-status: needs-testing
qa-notes: mirar que el job tests del PR y del push a 2.2 tras el merge cierren en verde y por debajo de 80 min
---

# El QA de la punta de 2.2 se cancela «en context-based»: no era un cuelgue

## Qué se midió

Run 40422732167 (push a `2.2`, HEAD `85c5a77`), job `tests` cancelado a los 63,6 min. Tiempos por
paso, de la API de Actions:

| paso | este run | mediana verde 24-26 oct |
|---|---|---|
| Build for testing | 28,6 min | 14,0 |
| Unit pure-logic | 30,9 min (todo verde) | 16,5 |
| Unit context-based | 1,8 min — **cortado** | 2,4 |

El paso context-based no se colgó: el tope de 60 min del JOB lo cortó al minuto y medio. Es el
mismo cuadro que `ci-tests-job-ceiling-cancels-green-runs` (24-oct). El arreglo de aquel día subió
el tope de 45 a 60, y el trabajo lo ha vuelto a alcanzar: la nocturna 40094866869 ya cerró en
verde a 53,5 min.

Dos causas:

1. **Un unit que salía a CloudKit.** «`_testReset` devuelve el seam a producción»
   (`PrivateSessionAppleIDWitnessTests`) llamaba al fetch real de `PrivateSessionAppleIDWitness` y
   esperaba el «no hay cuenta» de `cloudd`: **47 s** en el run verde siguiente, **393 s** en el
   cancelado. Sus +346 s cubren, ellos solos, toda la diferencia del «Test run» entre los dos runs (1 335 s frente a 1 036 s). Era la única llamada real a
   CloudKit de toda la suite (`[CK] Error fetching user record ID` sale una vez por run).
2. **El runner.** El build compiló el mismo código en 28,6 min que otros runs compilan en 14.

## Qué se hizo

- El seam `identityFetcher` pasa a opcional: `nil` es el fetch de producción. `_testReset()` lo
  pone a `nil` y el test comprueba `identityFetcher == nil` sin llamar a nada. La copia duplicada
  del closure de producción que vivía en `_testReset()` desaparece. Producción no cambia.
- Topes re-medidos en `qa.yml` sobre 67 jobs del 24 al 26-oct: job 60 → 80, build 30 → 40,
  pure-logic 35 → 45. Context-based se queda en 10: un cuelgue real de ese paso sigue cortando a
  los 10 min, con el job vivo para contarlo.
- `.claude/rules/ci-qa.md`: el caso y «un unit no habla con la red».

## Lo que no se tocó

Los tres escaneos de código fuente de ~50 s cada uno (`everyProductionConstruction_passesAnAttestProvider`,
`productionConstructions_injectTheLiveProvider_neverAnExplicitNil`, `everyMetricsCanaryHasAnEmitter`)
son trabajo, no espera, y su tiempo es estable entre runs. Acelerarlos es otro encargo.

Cerrado en el barrido de QA 2026-10-30: criterio estricto (filtro doble); motivo y evidencia en docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md.
