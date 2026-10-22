---
id: welcome-chooser-uitests-cannot-reach-the-chooser
status: discarded
priority: high
area: "testing, onboarding"
created: 2026-09-11
updated: 2026-09-11
source: "medido el 2026-09-11 al correr el gate de `groups-invite-on-a-mirrored-store-crosses-data`; bisecado contra un worktree limpio de `2.1` (`1a9cbb83`)"
---

# Siete XCUITest del Welcome no pasan del Hero, y llevan así al menos desde el 11-sep

**Why: Discarded 2026-09-11. La premisa es falsa y está refutada con tres mediciones
independientes: los siete casos PASAN. El rojo no venía del árbol — venía de la máquina donde se
midió. No hay nada que arreglar en el producto ni en los tests; lo que sí quedaba abierto era el
hueco de método que produjo el falso positivo, y ése se cierra en este mismo PR
(`qa/scripts/sim-libre.sh --vigilar`).**

## Lo que se midió para descartarlo

Las dos suites son **byte-idénticas** entre la revisión que el ticket bisecó y la de hoy:
`git diff --stat 1a9cbb83..bef5c134 -- YalaUITests/` toca **un solo fichero**, y es
`GroupsAssociationRowUITests.swift`. O sea, entre las dos mediciones estos siete casos no
cambiaron ni una línea, así que cualquier diferencia de resultado venía de fuera de ellos.

| # | Dónde | Qué | Resultado |
|---|---|---|---|
| 1 | local · `bef5c134` (`2.1` de hoy) | las dos suites aisladas, simulador ya arrancado | **11/11 verde**, 0 fallos, 152 s |
| 2 | local · `1a9cbb83` (**la revisión que el ticket bisecó**) | las mismas dos suites, mismo simulador | **11/11 verde**, 0 fallos, 141 s |
| 3 | CI · nocturna del 2026-09-11 (run `34600912200`, `ba618216`) | suite COMPLETA, 149 casos, runner limpio de GitHub | **los 11 pasan** |

La nº 2 es la que cierra la puerta: es exactamente el árbol donde el ticket dice haber
reproducido los siete rojos «dos veces».

La nº 3 es independiente de esta máquina y además contesta la pregunta del orden —si la causa
fuera contaminación entre suites, la tanda completa de 149 casos la habría enseñado—. En esa
misma corrida hay **13 fallos**: son los cuatro casos de
`nocturna-del-9-sep-dejo-cuatro-xcuitest-en-rojo` con sus reintentos, más dos que pasaron al
reintentar (`PanelDashboardUITests test_freshInstallShowsFourSectionsByDefault` y
`GroupsSmokeUITests test_groupExpenseFromTabFAB`). Ninguno del Welcome.

## Por qué la hipótesis del ticket no podía ser

El ticket apuntaba a `WelcomeHeroView.handleEmpezar()`: «un encaminamiento nuevo del Hero (el
faro, la sonda de iCloud, el sub-chooser) que se lleva el tap antes de que el chooser se monte».

**El Hero no encamina nada.** `handleEmpezar()` son cuatro líneas —guard de doble tap, háptico,
`onContinue()`— y su docblock lo dice desde el 2026-08-11: «al tap "Empezar" el flow va SIEMPRE
al Chooser». Su único consumidor es `WelcomeFlowContainer`, cuyo `case .hero` hace
`goTo(.chooser)` y nada más. El faro no está en ese camino: se consulta en `handleNewBranch()`,
**después** del chooser. Leerlo costaba un grep, y habría bastado para no abrir el ticket.

## Qué lo produjo, entonces

**Medido**: el rojo no viene del árbol (tabla de arriba). **Lo que sigue es la explicación
candidata, no una medición**, y va escrita como tal.

El ticket se midió «al correr el gate de `groups-invite-on-a-mirrored-store-crosses-data`», y su
bisección abrió un worktree limpio **mientras esa misma sesión seguía trabajando**. En esta
máquina hay un solo simulador y **14 worktrees**, todos apuntando a `iPhone 17 Pro` con el mismo
bundle id (`com.jurgenschmidt.yala.dev`). Dos corridas simultáneas no solo se derriban el runner
—eso ya estaba medido el 2026-09-07—: la segunda **instala su `.app` encima**, y desde ese
instante la primera tapea un binario que no es el suyo. El síntoma de eso no es «Restarting
after unexpected exit» sino una espera que se agota con su línea de fallo y su mensaje de
aserto: exactamente el log que el ticket cita.

Y encaja con lo que esa sesión estaba arreglando, que era justo esto (de su propio commit
`5bb3b4ea`): «la pantalla no se renderizaba en su propio estado objetivo — el drain baja el
cover y el consumidor lo sube en la misma vuelta síncrona, así que el step pedido se ignoraba en
silencio». Un árbol intermedio con esa mitad a medias deja el cover **en el Hero**, que es el
síntoma descrito. Ese árbol nunca llegó a ser un commit, así que hoy no se puede medir: por eso
es hipótesis y no conclusión.

## Lo que sí queda hecho

- `qa/scripts/sim-libre.sh` gana el modo **`--vigilar <pid>`**: un centinela que mira durante
  toda la corrida y dice al final si estuviste solo. La comprobación de antes caducaba en el
  instante siguiente, y una corrida dura entre 3 y 40 minutos.
- `.claude/rules/testing.md`: el corolario de clasificación de rojos («sin línea de fallo ⇒
  murió el runner; con línea ⇒ es un rojo de test») estaba **incompleto**, y es el que hizo
  clasificar esto como bug del producto.
- Ticket nuevo para lo que no cabe aquí: `un-solo-simulador-para-catorce-worktrees`.

## Si vuelve a aparecer

Antes de reabrir: correr las dos suites **aisladas**, con `bash qa/scripts/sim-libre.sh` antes y
`--vigilar` durante. Si con el centinela en verde los siete siguen rojos, entonces sí hay algo, y
este descarte no lo tapa.

---

## El ticket original, tal como se escribió

### Qué está roto

Siete casos, en dos suites, fallan **en `2.1` sin ningún cambio encima**:

| Suite | Caso | Lo que no aparece |
|---|---|---|
| `WelcomeChooserUITests` | `testExistingChooser_withCloudConfigured_showsThreeCards_andGoogleIntro` | la card de restaurar iCloud |
| `WelcomeChooserUITests` | `testNewChooser_withCloudConfigured_showsBothCards_andCloudCardOpensSignUp` | la card de privacidad total |
| `WelcomeChooserUITests` | `testNewBranch_withBeacon_routesToSignIn_andCreateAnotherOpensTheFullChooser` | el encaminamiento del faro |
| `WelcomeChooserUITests` | `testNewBranch_withUnknownBeaconMethod_saysTheGenericOrigin` | el origen genérico |
| `WelcomeChooserUITests` | `testGroupsOrganizer_createCardWalksToTheGroupForm` | la puerta del organizador |
| `SecondarySessionGateUITests` | `test_organizerGate_inSecondarySession_blocksWithItsOwnScreen` | la pantalla de la visita |
| `SecondarySessionGateUITests` | `test_organizerGate_withLocalCorpus_returnsToNeutralInsteadOfBlocking` | la vuelta al neutro |

Del log de `WelcomeChooserUITests`:

```
t = 5.39s  Waiting 60.0s for "welcome_hero_cta" Button to exist
t = 6.51s  Tap "welcome_hero_cta" Button
t = 6.97s  Waiting 10.0s for "welcome_chooser_restore" Button to exist   ← se agota
```

⇒ lo que hay que mirar es **qué hace `WelcomeHeroView.handleEmpezar()` hoy bajo `-uitest`**.
