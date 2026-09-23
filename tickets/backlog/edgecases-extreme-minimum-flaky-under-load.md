---
id: edgecases-extreme-minimum-flaky-under-load
status: backlog
priority: low
area: testing
created: 2026-09-05
updated: 2026-09-23
source: rojo clasificado en el gate de group-joiner-flag-consumers-still-narrow
---

# `test_extremeMinimumAmountSaves` falla en lote y pasa solo

## Qué se observó, medido el 2026-09-05

Corriendo cinco suites XCUITest en una sola invocación (`GroupMembersAdminUITests`, `GroupsSmokeUITests`,
`GroupsEmptyStateUITests`, `EdgeCasesUITests`, `WelcomeFreshStartAlertUITests` — 19 tests), falló uno:

```
YalaUITests/Support/XCUIApplication+Yala.swift:208: error:
-[YalaUITests.EdgeCasesUITests test_extremeMinimumAmountSaves] : XCTAssertTrue failed —
No apareció la pantalla de éxito de la transacción (transaction_success_accept) — el guardado no completó.
```

Re-corrida **la misma suite en aislamiento**, los 2 tests pasan (`test_extremeMinimumAmountSaves` en
32.5 s). En el lote había tardado 37.7 s antes de rendirse.

## Por qué NO es el cambio que lo destapó

El gate corría el fix de identidad de Grupos (`group-joiner-flag-consumers-still-narrow`). Este test
guarda una transacción **personal** y no pasa por ninguna ruta de identidad de Grupos. Las tres suites
de Grupos del mismo lote pasaron, y los 6038 unit tests también.

## La hipótesis, sin comprobar

Espera por un elemento de UI que bajo carga (cinco suites seguidas, simulador ya caliente) tarda más
que su timeout. No se midió cuál es ese timeout ni si es el mismo patrón que ya se corrigió el
2026-08-04 en este test (el falso verde que afirmaba el regreso al Panel con el sheet aún puesto).

**Antes de perseguirlo**: `bash qa/scripts/disk-report.sh`. En la corrida donde falló había 26 GB
libres, por encima del umbral, así que el disco NO lo explica esa vez — pero es lo primero que se
descarta si reaparece.

## Segunda medición, el mismo día

Re-corrido **el lote entero de cinco suites** tras el arreglo de la review adversarial: **19 tests, 0
fallos**, `test_extremeMinimumAmountSaves` incluido. O sea, en el mismo montaje que lo tumbó una vez,
pasó a la siguiente. Va **1 fallo de 2 corridas del lote**, más 1 de 1 en aislamiento — muestra
demasiado pequeña para concluir nada salvo que no es determinista.

## Qué haría falta

Reproducirlo: correr el mismo lote de cinco suites unas cuantas veces y contar. Un fallo de 1 en N no
justifica tocar el test; uno de 1 en 3 sí, y entonces el arreglo es el timeout de la espera, no el
guardado.

## Medición del 2026-09-06 (Frank, desde `groups-archived-group-rejects-join`)

**No es flaky bajo carga: es determinista, y el nombre del ticket induce a error.** Medido hoy en
local, aislado y sin nada más corriendo:

- Falla con mis cambios (39,3 s) **y falla igual con `ContentView.swift` revertido a HEAD** (36,3 s)
  ⇒ preexistente, no de ninguna rama en vuelo.
- **Falla también corriéndolo SOLO**, que es lo que lo separa de sus vecinos: en la misma tanda,
  `QuickActionsFavoritesUITests` y `TransactionsCrudUITests` fallan dentro de una tanda y **pasan
  aislados** (47 s y 37 s). Ésos sí son carga; éste no.
- Cae en `XCUIApplication+Yala.swift:208`, esperando `transaction_success_accept`: la pantalla de
  éxito de la transacción no aparece en 10 s.

⇒ Subir el timeout del helper —que ayudaría a los otros dos— **no arreglará éste**. Hay algo que
impide que el guardado complete con ese importe. Y un aviso de método pagado hoy: ese mismo síntoma,
en esa misma línea, lo produjo también un **bug real** introducido en esta sesión (una alerta con el
label del botón dependiendo del `@State`). ⇒ el síntoma no identifica la causa; hay que bisecar.



## Medición del 2026-09-07 (noche) — «es determinista» no se sostiene

La entrada del 6-sep concluía: **«No es flaky bajo carga: es determinista… Falla también
corriéndolo SOLO»**. Medido hoy con el reproductor de cinco suites, `test_extremeMinimumAmountSaves`
**pasó 12 corridas seguidas** (12/12, dentro de tanda las doce), con el disco a 25 GB y también a
12 GB forzados, y con el swap lleno. Un test que pasa doce veces seguidas no es determinista en
rojo. Lo que aquella medición tenía delante era, con toda probabilidad, otra cosa.

**Y hay una segunda vía por la que este test aparece en rojo sin serlo** (medido en
[[rojo-xcuitest-runner-muere-tras-el-primer-caso]]): cuando otra sesión corre XCUITest sobre el mismo
simulador, el runner muere y `test_extremeMinimumAmountSaves` sale listado en `Failing tests` **sin
haber impreso una sola línea de fallo**. Salió así en las dos reproducciones de esa medición.

⇒ **Antes de anotar nada aquí: `grep -c "Test Case .* failed"` sobre el log.** Si da 0, el test no
falló — murió el runner. Y `bash qa/scripts/sim-libre.sh` antes de correr, o la muestra no vale.

Sobre el contexto de la observación original: allí se decía que con **26 GB libres** el disco «no lo
explica esa vez». Es correcto, y ahora se puede afirmar más fuerte: el disco no lo explica **nunca**
— también pasa a 12 GB.

## Tercera observación, 2026-09-10 — la muestra sube a 2 de 3, y el lote ya es la suite ENTERA

Gate del bloque [I] (`cloud-sign-in-discovers-account-kind`), con la suite **completa** de `YalaUITests`
en una sola invocación: **136 pasados, 1 fallado**, y el fallado es este, con el **mismo mensaje y la misma
línea** del helper (`XCUIApplication+Yala.swift:218`, era `:208`). **Cero reinicios del runner**, así que no
es la colisión de dos corridas — es un rojo de test de verdad.

Re-corrido **aislado** en el mismo árbol y el mismo simulador: **los 2 tests pasan**, éste en **30,1 s**
(las otras veces: 32,5 s aislado, ~37,7 s antes de rendirse en lote). El perfil se repite exacto.

**Qué añade esta observación, además de una muestra:**

- **El lote ya no son cinco suites: es la suite entera** (137 casos). El fenómeno escala con la carga y no
  con qué suites concretas la acompañan, lo que refuerza la hipótesis del timeout bajo carga frente a
  cualquier interacción entre suites.
- **Descarta el diff del día como causa, y conviene decir por qué no basta con que «pase aislado»**: el
  síntoma —«el guardado no completó»— es *exactamente* el de la trampa del `.alert` de `ContentView`
  (`.claude/rules/swiftui-ds.md`), donde un cambio de presentación inerte rompió el guardado de una
  transacción y el rojo salió en un área sin relación. Y ese gate tocaba `ContentView`. Lo que lo zanja no
  es el razonamiento sino que **este fenómeno ya estaba medido el 2026-09-05, en un árbol sin ese diff**.
- El disco estaba en **23 GB**, por debajo del umbral de 25. No es descartable como en la primera
  observación (que tenía 26 GB), así que la carga de disco vuelve a la lista de sospechosos — aunque la
  medición del 2026-09-07 (12 corridas verdes con el disco forzado a 12 GB) le quita peso.

**Va 2 fallos de 3 corridas en lote, 0 de 2 en aislamiento.** Sigue sin ser determinista, pero ya no es
«una vez»: en un gate con la suite entera, este test cae la mitad de las veces.

## Cuarta observación, 2026-09-15 — el mismo comando en los dos árboles

Gate de `groups-channel-seal-has-no-reachable-producer`, paso 3: `EdgeCasesUITests` +
`WelcomeFreshStartAlertUITests` (4 casos) en una sola invocación, con el centinela vigilando cada corrida.

| Árbol | Corrida | Este test | Centinela |
|---|---|---|---|
| Rama del PR | 1 | **falla**, 39,1 s | 0 (solo) |
| Rama del PR | 2 | pasa, 30,5 s | 0 (solo) |
| `68a07208d` limpio | 1 | pasa, 31,7 s | 1: no vale (2 runners simultáneos) |
| `68a07208d` limpio | 2 | pasa, 30,5 s | 0 (solo) |

- **Mismo binario, un rojo y un verde, sin nadie más en el simulador.** Con este comando va 1 fallo de 3
  corridas válidas, en un lote de solo 4 casos: no hace falta la carga de la suite entera.
- **El rojo es el lento**: agota los 10 s del helper esperando `transaction_success_accept`. Es la firma de
  una espera que no llega, no la de un runner que muere.
- **Lo que lo separa del PR es una muestra imposible, no la estadística.** El PR solo tocaba el loop de
  sync de Grupos, y todo ese código sale en el primer `guard` de `sessionCheck()`. Este test lanza con
  `cloudSession: false`, el default de `launchForUITest`, así que no lo ejecuta.
- La línea del aserto se ha vuelto a mover: hoy es `XCUIApplication+Yala.swift:229`
  (`dismissTransactionSuccess`).
- Disco: 24 GB libres al empezar la sesión y 16 GB al acabar las corridas. No se midió en el instante del
  rojo; los dos valores están por debajo del umbral de 25.

## Quinta observación, 2026-09-16 — en lote de seis clases, y aislado pasa 2 de 2

Gate de `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest`, paso 3: las seis clases del cruce con el índice
(`CurrencySettingsUITests`, `EdgeCasesUITests`, `ForeignCurrencyAccountSeedUITests`, `GroupsAssociationRowUITests`,
`StorageMigrationAttestUITests`, `WelcomeFreshStartAlertUITests`, 15 casos) en una sola invocación.

| Corrida | Este test | Centinela | Reinicios |
|---|---|---|---|
| Lote de 15 casos | **falla**, 34,1 s | 0 (solo) | 0 |
| Aislado, iteración 1 | pasa, 29,8 s | 0 (solo) | 0 |
| Aislado, iteración 2 | pasa, 29,5 s | 0 (solo) | 0 |

- **La misma firma**: agota la espera de `transaction_success_accept`, ahora en `XCUIApplication+Yala.swift:241`.
- **Otra muestra imposible**: el PR solo cambia comportamiento dentro de `StorageSettingsView` (la tarjeta de la nube) y en
  `StorageRowGateLogic.offersCloudMigrationEntry`, que solo llama esa pantalla. Este test guarda una transacción desde el
  FAB del Panel y nunca abre Perfil.
- Con esta, **3 fallos en lote y 0 en aislamiento** en las observaciones con centinela o reinicios contados.
- Disco: 30 GB libres al empezar la sesión.


## Otra observación, 2026-09-17 (gate de `reinstall-without-network-has-no-cloud-door`)

Mismo síntoma, mismo test, mismo mensaje (`transaction_success_accept` que no aparece, a los 36 s).
Lote de cinco suites: `EdgeCasesUITests` · `WelcomeFreshStartAlertUITests` · `OnboardingFlowUITests` ·
`WelcomeChooserUITests` · `FullModeActivationChooserUITests` — 18 tests, 1 fallo. **Centinela en 0 en
las cuatro corridas**, así que ninguna estuvo pisada: el rojo no es una colisión de simulador.

Las cuatro medidas, en orden, sobre el MISMO lote y el MISMO código:

| Corrida | Árbol | Alcance | Resultado |
|---|---|---|---|
| 1 | con el diff | las 5 suites | 18 tests, **1 fallo** |
| 2 | base `f93bb4005`, limpio | `EdgeCasesUITests` sola | 2 tests, 0 fallos |
| 3 | con el diff | `EdgeCasesUITests` sola | 2 tests, 0 fallos |
| 4 | con el diff | las 5 suites | 18 tests, **0 fallos** |

La 4 es la que zanja: la 1 y la 4 son la misma condición exacta y dan resultados opuestos, así que el
rojo no lo explica ningún diff. Refuerza lo que ya dice este ticket —«falla en lote y pasa solo»— y
añade que **tampoco falla siempre en lote**.


---

## Segunda observación, 2026-09-21: otro caso, misma forma

En el gate de `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out`, el mismo lote de cuatro suites
(`StorageMigrationAttestUITests`, `StorageMigrationIdentityBlockUITests`, `EdgeCasesUITests`,
`WelcomeFreshStartAlertUITests`) dio **verde una vez y rojo la siguiente**, con un caso distinto:

```
YalaUITests/Flows/StorageMigrationAttestUITests.swift:47: error:
-[…] test_withoutAppAttest_storageDoesNotOfferTheCloud] : XCTAssertTrue failed —
No aparece la fila «¿Dónde viven tus datos?» en Ajustes.
```

Falla en la **navegación previa**, no en la aserción del caso. Re-corrida la suite aislada: verde en 38 s.

**Lo que lo zanja no es la re-corrida, es la muestra imposible.** Entre la corrida verde y la roja, el diff de
producción fue **el mismo**: lo único que cambió en el árbol entre una y otra fueron comentarios y ficheros de test
(comprobado con `git diff -U0 -- Yala/` filtrando comentarios). El mismo binario dio los dos veredictos, así que la
causa no está en el código bajo prueba. El centinela (`sim-libre.sh --vigilar`) salió **0** en las dos corridas, así
que tampoco fue otra sesión pisando el simulador — que es la otra explicación habitual y la que hay que descartar
antes de llamarlo flaky.

El lote rojo tardó **249 s**; el verde, **195 s**. Encaja con la hipótesis de arriba: bajo carga el `waitForExistence`
de la navegación se queda corto. Ahora son **dos** casos distintos, de dos suites distintas, con la misma forma — lo
que refuerza que el sitio a mirar es el timeout compartido de los helpers de navegación, no cada caso.

## Otra aparición · 2026-09-23 (gate de `adopt-effect-retries-forever-with-no-ceiling`)

Lote de 9 suites (31 casos, `Yala Dev`, iPhone 17 Pro 26.5, centinela 0: solo durante toda la corrida): falló con el mismo
mensaje (`transaction_success_accept` no apareció). `EdgeCasesUITests` sola, dos veces seguidas con el centinela a 0: 2/2
verde las dos. El diff de esa sesión no toca el guardado de transacciones.
