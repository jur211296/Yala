---
id: nocturna-del-9-sep-dejo-cuatro-xcuitest-en-rojo
status: backlog
priority: high
area: "testing, qa"
created: 2026-09-09
updated: 2026-10-01
source: run 34354119553 (nocturna de 2.1, 2026-09-09) — encontrado al arreglar el avisador
---

# La nocturna del 9-sep dejó cuatro XCUITest en rojo y nadie se enteró

## Qué pasa

La corrida nocturna de `2.1` del 2026-09-09 (`34354119553`) ejecutó la suite completa de UI con
este resultado, leído del log del run:

```
Executed 145 tests, with 12 failures
```

Los 12 fallos son **cuatro casos distintos** contados con sus reintentos
(`-retry-tests-on-failure`):

| Suite | Caso |
|---|---|
| `EdgeCasesUITests` | `test_extremeMinimumAmountSaves` |
| `InboxConvertToGroupUITests` | `test_convertDraftToGroupExpense_preservesDraftDate` |
| `QuickActionsFavoritesUITests` | `test_saveAsFavoriteFromTransactionAppearsInList` |
| `TransactionsCrudUITests` | `test_createTransaction` |

`GroupInviteOnboardingUITests` aparece como suite fallida en el log pero ninguno de sus casos
figura entre los fallos finales: pasó al reintentar.

**Al 2026-09-11 los cuatro SIGUEN rojos, y eso ya no es un dato de una sola noche.** La nocturna
del 11-sep (run `34600912200`, `ba618216`) dio `Executed 149 tests, with 13 failures`, y el
desglose es el mismo cuarteto con sus reintentos:

| Caso | reintentos rojos |
|---|---|
| `QuickActionsFavoritesUITests test_saveAsFavoriteFromTransactionAppearsInList` | 3 |
| `InboxConvertToGroupUITests test_convertDraftToGroupExpense_preservesDraftDate` | 3 |
| `EdgeCasesUITests test_extremeMinimumAmountSaves` | 3 |
| `TransactionsCrudUITests test_createTransaction` | 2 |
| `PanelDashboardUITests test_freshInstallShowsFourSectionsByDefault` | 1 (pasó al reintentar) |
| `GroupsSmokeUITests test_groupExpenseFromTabFAB` | 1 (pasó al reintentar) |

Dos noches con **tres** reintentos rojos seguidos en los tres primeros es mala señal para la
hipótesis «flaky de runner frío»: un flaky que falla 3/3 en dos noches distintas no es un flaky.
Medido de pasada al refutar `welcome-chooser-uitests-cannot-reach-the-chooser`, que NO es este
conjunto — en esa misma corrida los siete del Welcome pasaron.

**El aviso de esos rojos no llegó a nadie.** El paso que avisa salió con `Invalid API key`
(`ticket ci-avisador-de-rojos-advisory-tiene-la-clave-mal`, ya cerrado), así que la única señal
fue un `tests: fail` que parecía —y en parte era— un fallo del avisador. Este ticket existe
porque al arreglar el canal apareció lo que el canal no había podido entregar.

## Medido otra vez el 2026-09-15: `test_freshInstallShowsFourSectionsByDefault`

Gate del PR del guard del iCloud-KV (`icloud-kv-prefs-cross-sessions-on-a-lent-phone`), **cuatro corridas sobre
el MISMO árbol**, todas con `sim-libre.sh --vigilar` sin intrusos: pasó (28,3 s), **falló** (20,7 s), pasó
(30,3 s), pasó (30,0 s). El rojo fue el primer caso de una corrida lanzada justo después de que el harness
matara la anterior por memoria, y cayó en `PanelDashboardUITests.swift:138` —«No apareció el toggle de
accounts»— a los 5 s de tocar `panel_sections_config`: el sheet de secciones no mostró sus toggles a tiempo.
Con el árbol idéntico en las cuatro, no es una regresión de ese PR; es la misma intermitencia que esta tabla
ya tenía como «1 (pasó al reintentar)».

## Medido el 2026-10-01: en un iPhone SE falla SIEMPRE

`test_freshInstallShowsFourSectionsByDefault` en `YalaLane-Adapt-iPhone-SE` (iOS 27.0, por UDID, con
`sim-libre.sh --vigilar` sin intrusos): **rojo 3 de 3** en el árbol del PR `iphone-large-models-use-the-extra-width` y
**rojo 1 de 1 en un worktree limpio de `2.1` (`f8c893cb3`)**, siempre en `PanelDashboardUITests.swift:138` con «No
apareció el toggle de latestRecords» —el cuarto de la lista—. En `YalaLane-Adapt-iPhone-ProMax`, con el mismo binario,
verde. No es intermitencia: en una pantalla de 667 pt el cuarto toggle de la hoja de secciones no llega a existir sin
desplazar (inferido, no medido el árbol). El test necesita desplazarse por la hoja, o el gate solo es honesto en
iPhones altos.

## Lo que hay que hacer

- [ ] Reproducir los cuatro en local y clasificarlos: flaky de runner frío (la Lista Negra ya
      recoge esa familia para XCUITest) o regresión real. **No dar por buena la clasificación
      sin bisecar**: dos rojos idénticos en un log pueden tener causas opuestas.
- [ ] `test_createTransaction` es el más sospechoso de los cuatro por lo que cubre —crear una
      transacción es el camino central de la app— y por la fecha: la sesión del 2026-09-09 tocó
      el guardado al cambiar la divisa de una cuenta (PR #118). Empezar por ahí.
- [ ] Si alguno es regresión, ticket propio con su arreglo. Si es flaky, a la Lista Negra con
      la fecha de comprobación, que caduca.

## Por qué `high`

Son XCUITest de caminos centrales (crear transacción, guardar favorito, convertir borrador a
gasto de grupo) que llevan al menos desde el 9-sep en rojo **sin que nadie lo supiera**, y la
suite de UI ya no corre en los PR: solo en la nocturna. Si estos cuatro se quedan, la nocturna
pasa a ser un rojo permanente, y un rojo permanente se deja de mirar — que es como se llega
otra vez a «el CI llevaba semanas en verde con ocho tests en rojo».
