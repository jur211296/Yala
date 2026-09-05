---
id: uitest-compara-fechas-sin-fijar-locale
status: backlog
priority: medium
area: testing
created: 2026-09-05
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
