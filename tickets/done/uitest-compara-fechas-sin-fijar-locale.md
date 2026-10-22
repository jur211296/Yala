---
id: uitest-compara-fechas-sin-fijar-locale
status: done
priority: medium
area: testing
created: 2026-09-05
updated: 2026-10-07
source: medido al clasificar los rojos del CI en el PR #64
---

# Un XCUITest compara fechas formateadas y falla por el idioma del runner, no por el bug que dice

## Qué pasa, medido el 2026-09-05

`InboxConvertToGroupUITests.test_convertDraftToGroupExpense_preservesDraftDate` falla en el CI así:

```
YalaUITests/Flows/InboxConvertToGroupUITests.swift:165: XCTAssertEqual failed:
("2 set.") is not equal to ("Sep 2") - El form de conversión no conservó la fecha
```

**El form SÍ conservó la fecha.** Los dos valores son el 2 de septiembre; lo que difiere es el idioma
con que el runner formatea el mes. El mensaje del test acusa de algo que no ocurrió, que es lo caro:
quien lo lea al clasificar un CI en rojo perseguirá la conversión de borradores del Inbox.

## Que es preexistente está medido, no supuesto

Falla igual en `2.1` sin ningún cambio encima: comparados el run del PR #64 (`33949352997`) y el de
`2.1` (`33944039295`), la lista de XCUITest en rojo es **idéntica** — este, más
`EdgeCasesUITests.test_extremeMinimumAmountSaves`,
`QuickActionsFavoritesUITests.test_saveAsFavoriteFromTransactionAppearsInList` y
`TransactionsCrudUITests.test_createTransaction`. 11 fallos en la base y 12 en el PR: los mismos
cuatro tests, un reintento más.

## Por qué no se ve en el gate local

El simulador local corre en el idioma del Mac y el runner del CI no. Un `/gate` en verde no protege
de esto, y el paso de UI del CI es **advisory** (`continue-on-error`), así que el job sale `success`
con los 12 dentro. El verde del CI no dice que los XCUITest pasaran.

## Qué haría falta

Fijar el idioma del test (`-AppleLanguages`/`-AppleLocale` en `launchArguments`, que es como ya se
inyectan los otros hooks de XCUITest) o comparar contra un valor formateado con el mismo
`DateFormatter` que usa la app, en vez de contra un literal en inglés. **Antes de arreglarlo, mirar
si los otros tres rojos comparten causa**: dos de ellos también tocan pantallas con fechas.

Y de paso, corregir el mensaje del assert: hoy afirma «no conservó la fecha» cuando lo que sabe es
«el texto no coincide».

---

## Medición del 2026-09-06 (Frank, desde `groups-archived-group-rejects-join`)

Los cuatro rojos de arriba se citaron aquí como un bloque con **una** causa sospechada (el locale).
Medidos hoy **en local**, uno por uno, no se comportan igual — y la diferencia importa para quien
venga a arreglarlos:

- **`QuickActionsFavoritesUITests.test_saveAsFavoriteFromTransactionAppearsInList` PASA en local**
  sobre `2.1` limpio (comprobado en un worktree desde `e28a93ec`: verde en 50,7 s). Encaja con lo que
  este ticket ya explica —el runner del CI no corre en el idioma del Mac—, así que su rojo es del CI y
  no se reproduce aquí.
- **`EdgeCasesUITests.test_extremeMinimumAmountSaves` FALLA también en local**, y **no por una fecha**:
  cae en `XCUIApplication+Yala.swift:208`, esperando `transaction_success_accept` — la pantalla de
  éxito de la transacción no aparece en 10 s. Comprobado que es preexistente revirtiendo
  `ContentView.swift` a HEAD: falla igual.

- **`TransactionsCrudUITests.test_createTransaction` PASA aislado** (36,9 s) y **falla dentro de una
  tanda** de 4 suites. Mismo patrón que `QuickActionsFavorites`, que también pasa aislado (47 s) y cae
  en tanda.

⇒ **No son cuatro instancias de la misma causa, y al menos dos ni siquiera son deterministas.** El
patrón medido hoy, sobre 133 casos en seis tandas: los tres que fallaron **crean o guardan una
transacción** y los tres caen en el mismo helper (`transaction_success_accept`), pero
`TransactionsCrud` y `QuickActionsFavorites` pasan al correrlos solos, mientras `EdgeCases` falla
también aislado. ⇒ hay **dos** cosas mezcladas aquí: una fragilidad por CARGA (la espera de 10 s del
helper no llega cuando la máquina va justa) y, en `EdgeCases`, un fallo propio. Fijar el locale no
arregla ninguna de las dos.

Contexto de la máquina ese día, porque cambia cómo leer estos números: 8-13 GB libres (umbral 25) y
presión de memoria suficiente para que el sistema **matara** la corrida de `xcodebuild` tres veces.
Antes de perseguir estos tres, correr `bash qa/scripts/disk-report.sh` y repetirlos aislados.

Sugerencia barata antes de tocar nada: subir el timeout de `dismissTransactionSuccess()` (hoy 10 s)
tiene el mismo argumento que ya se aceptó para el paso lento de `PaywallInboxAlertRoutingUITests`
—45 s y no 10, "el umbral solo se consume en el caso malo"— y quitaría el ruido de carga sin tapar el
fallo de `EdgeCases`, que agota cualquier margen.

**Aviso de método, pagado hoy:** ese mismo helper de la línea 208 es el que delató un bug REAL
introducido en otra sesión (una alerta con el label del botón dependiendo del `@State` dejaba la vista
sin alcanzar `idle` y el guardado no completaba). ⇒ **un fallo en `transaction_success_accept` no se
archiva como «rojo conocido» sin bisecar contra el árbol base**: el síntoma es idéntico en los dos
casos y solo esa medición los distingue.



---

## Nota del 2026-09-07 (noche): el rojo del locale es real; los tres vecinos «de tanda», no siempre

Este ticket sigue en pie tal cual para lo suyo: `…preservesDraftDate` compara un mes formateado
contra un literal en inglés y eso es un rojo de aserción de verdad, con su línea de fallo y su
mensaje. **Nada de lo de abajo lo toca.**

Lo que sí cambia es cómo leer a los otros tres que se citan aquí como bloque. Medido en
[[rojo-xcuitest-runner-muere-tras-el-primer-caso]]: dos corridas de XCUITest sobre el mismo simulador
se derriban entre sí y sacan a `QuickActionsFavorites.test_saveAsFavorite…`,
`TransactionsCrud.test_createTransaction` y `EdgeCases.test_extremeMinimumAmountSaves` en el bloque
`Failing tests` **sin una sola línea `Test Case … failed`** — los tres salieron así, literalmente,
en las dos reproducciones. Es el mismo trío que aquí se explicaba por «fragilidad por CARGA».

⇒ Al clasificar un CI o un gate en rojo, el `grep -c "Test Case .* failed"` separa las dos familias
antes de mirar ningún test. Y el paso de UI del CI sigue siendo `continue-on-error`, así que el
aviso de este ticket —«el verde del CI no dice que los XCUITest pasaran»— vale igual.

## Cerrado el 2026-10-07

Arreglado en [[advisory-ui-tests-fail-every-retry]]: la expectativa se formatea con el locale que se fija a la app
(`XCUIApplication.uiTestLocaleIdentifier`), y el mensaje del assert dice «no coincide» en vez de «no conservó».
Control rojo 2/2 con la expectativa vieja y el runner en inglés (`-testLanguage en`). Los otros rojos que este
ticket listaba no compartían causa: `EdgeCases` y `QuickActionsFavorites` eran la carrera de la guía de primeros
pasos (mismo ticket).
