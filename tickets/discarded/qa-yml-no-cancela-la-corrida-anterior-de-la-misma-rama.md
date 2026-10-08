---
id: qa-yml-no-cancela-la-corrida-anterior-de-la-misma-rama
status: discarded
priority: medium
area: ci
created: 2026-09-09
updated: 2026-10-07
source: medido al hacer varios pushes en el PR #123
---

# Cada push a una rama de PR encola otra suite entera y no cancela la anterior

Why: Discarded 2026-10-07, con OK de Jürgen (2026-10-07, 21:50 Lima). `qa.yml` ya cancela la corrida anterior de un PR (`25a71f999`, 2026-09-30): `concurrency` agrupa por número de PR con `cancel-in-progress` solo en `pull_request`, y en `2.1` cada push conserva su corrida, como pedía este ticket.

## Qué pasa

`qa.yml` **no declara `concurrency`**. Cada push a una rama de encargo abre una corrida nueva del
job `tests` (~22 min de runner `macos-26` en un PR, hasta 150 en la nocturna) y **deja viva la
anterior**, que ya está obsoleta: prueba un commit que nadie va a mergear.

Medido el 2026-09-09 sobre los 100 últimos runs, contando solo los de `pull_request`:

| Corridas | Rama |
|---|---|
| 4 | `encargo/2026-09-08-bulk-update-account-l…` |
| 4 | `encargo/2026-09-08-chat-rows-with-unsign…` |
| 4 | `encargo/2026-09-09-barrido-qa-fx-desbloq…` |
| 4 | `encargo/2026-09-09-ci-avisador-de-rojos-…` |

No es un caso raro: es lo que hace **toda** rama de encargo, porque una sesión empuja varias
veces. La última fila es esta misma sesión, así que el dato incluye lo que costó medirlo.

El workflow ya se preocupó una vez de este gasto: el filtro `push: branches: ["2.1","1.0"]` está
ahí porque una rama de ticket disparaba **dos** runs del mismo commit (97,4 + 102,4 min, medido el
2026-09-01). El agujero que queda es el otro: varios commits de la misma rama, en paralelo.

## Por qué no es solo dinero

Tres corridas de la misma rama en vuelo **compiten por el runner de simulador**, y este repo ya
tiene documentado que dos corridas sobre un simulador se pisan («el runner no muere de memoria: lo
pisa otra sesión»). Además, cada corrida obsoleta que termina puede entregar su propio aviso de
rojos sobre un commit que ya no existe en la rama.

## Lo que hay que hacer

- [ ] `concurrency: { group: qa-${{ github.ref }}, cancel-in-progress: true }`, pero **solo para
      `pull_request`**: en `2.1` cancelar la corrida en vuelo perdería la cobertura del commit
      anterior, que sí se mergeó y sí hay que probar. El grupo tiene que distinguir los dos casos.
- [ ] Comprobar la interacción con el job `aviso`: al cancelar un run, `!cancelled()` hace que el
      aviso **no** corra, que es lo correcto (una corrida superada no tiene nada que contar). Si
      alguien vuelve a poner `always()` ahí, cada push generaría un falso «la suite no llegó a
      correr» — ese ya se midió en producción el 2026-09-09 (run `34418566857`).
- [ ] La nocturna tiene su propio grupo en `nocturna-vigilante.yml` con `cancel-in-progress:
      false` y una razón escrita. No romperlo: son dos preguntas distintas.
