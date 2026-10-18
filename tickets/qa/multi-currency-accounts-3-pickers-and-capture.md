---
id: multi-currency-accounts-3-pickers-and-capture
status: qa
priority: medium
area: "accounts, currency, transactions, budgets, capture"
created: 2026-10-10
updated: 2026-10-18
source: multi-currency-accounts (entrega 3 de A1, decidida por Jürgen el 2026-10-09/10)
---

# Tarjeta multidivisa, entrega 3: elegir la tarjeta en todas partes y que la divisa decida la línea

## Qué cambia para el usuario

Al registrar un gasto elige «Visa BCP» y la app lo apunta en la línea de la divisa del importe: un
gasto en dólares va a la línea en dólares sin que tenga que pensarlo (decisión 6). En ningún selector,
filtro ni presupuesto ve su tarjeta partida en dos cuentas.

Contexto y decisiones: [`multi-currency-accounts`](multi-currency-accounts.md) y
[`docs/multi-currency-accounts-impact-2026-10.md`](../../docs/multi-currency-accounts-impact-2026-10.md),
secciones 2.4, 2.8, 2.13-2.15 y 4-6.

## Alcance

1. **Selector de cuentas anidado** (`AccountSelectorSheet`): la tarjeta, con sus líneas debajo. Elegir
   la tarjeta es la acción por defecto; elegir una línea concreta sigue siendo posible.
2. **Resolver tarjeta + divisa → línea.** Una función pura, la misma para todas las entradas:
   - la divisa del importe coincide con una línea, o con la principal: esa cuenta;
   - no coincide con ninguna: la principal, con el aviso de divisa que ya existe hoy. **No** crea una
     línea por su cuenta.
3. **Entradas que la usan:**
   - formulario de transacción (`NewTransactionView` / `NewTransactionViewModel`): hoy fija la divisa a
     la de la cuenta al elegirla (`NewTransactionView.swift:422-425`);
   - chat (`ChatTransactionDraft.effectiveCurrencyCode`, `ChatAssistantViewModel`);
   - voz (`VoiceRecordingView`, su copia de `findAccount`) e imagen (`DraftBuilder.findAccount(byCurrency:)`);
   - Siri (`SiriDraftService`) y Apple Pay (`ApplePayDraftService`, que hoy resuelve el símbolo
     ambiguo con la última cuenta usada);
   - la aprobación de borradores de la Bandeja, programados y favoritos, que toman la divisa de la
     cuenta al aprobarse.
4. **Filtros por cuenta.** Elegir la tarjeta incluye sus líneas: los 17 ficheros de
   `selectedAccountIDs` (`rg --type swift -n 'selectedAccountIDs' Yala`).
5. **Presupuestos.** Un presupuesto que apunta a la tarjeta cuenta los gastos de sus líneas: los 8
   ficheros de `resolvedAccountIDs` y `BudgetsViewModel.swift:571-573`.
6. **Selectores que hoy excluyen `isSystemAccount`**: revisados uno a uno para que traten las líneas
   como parte de su tarjeta, no como cuentas sueltas ni como cuentas de sistema.
7. **Importación CSV con varias divisas** (`ImportCurrencyMappingSheet`): ofrece las líneas de la
   tarjeta como destino de cada divisa.

## Fuera de alcance

La vista de la tarjeta (entrega 2). Informes y export (entrega 4). Cambiar cómo se comporta una
cuenta de una sola divisa: sin líneas, todo sigue igual.

## Ficheros implicados

- `Yala/App/Views/Transactions/AccountSelectorSheet.swift`,
  `Yala/App/Views/Transactions/NewTransactionView.swift`,
  `Yala/App/ViewModels/NewTransactionViewModel.swift`
- `Yala/App/Models/ChatTransactionDraft.swift`, `Yala/App/ViewModels/ChatAssistantViewModel.swift`
- `Yala/App/Views/Voice/VoiceRecordingView.swift`, `Yala/App/Services/DraftBuilder.swift`,
  `Yala/App/Views/Image/ImageSelectionView.swift`
- `Yala/App/Services/SiriDraftService.swift`, `Yala/App/Services/ApplePayDraftService.swift`
- `Yala/Services/DraftService.swift` y los editores de programados y favoritos
- `Yala/App/ViewModels/BudgetsViewModel.swift` y los ficheros de `resolvedAccountIDs`
- Los 17 ficheros de `selectedAccountIDs`
- `Yala/App/Views/Import/ImportCurrencyMappingSheet.swift`
- `qa/coverage-index.json`: `transactions-core-crud`, `fx-conversion-persistence`,
  `currency-filter-statistics`, `groups-bridge-personal`

## Criterio de hecho

- [x] Suite de la función tarjeta + divisa → línea: coincide con línea, coincide con principal, no
      coincide con ninguna (va a la principal y no crea línea), cuenta sin líneas (sin cambios).
- [x] Cada entrada del punto 3 tiene un test que, con la tarjeta y un importe en USD, guarda la
      transacción en la línea USD: formulario, chat, voz, imagen, Siri, Apple Pay y aprobación de
      borrador.
- [x] `ApplePayDraftServiceTests` y `ChatDraftAccountCurrencyTests` siguen en verde: con cuentas sin
      líneas nada cambia.
- [x] El selector enseña la tarjeta una vez con las líneas anidadas; XCUITest con el seed de tarjeta
      de dos líneas. Los UITests que eligen cuenta con `account_selector_row_` (BEGINSWITH) siguen
      eligiendo la cuenta que querían.
- [x] Filtro: elegir la tarjeta en Registros enseña los movimientos de las dos líneas; test.
- [x] Presupuesto con la tarjeta: un gasto en la línea USD cuenta, convertido; test.
- [x] Barrido documentado en el PR: `rg` de `selectedAccountIDs`, `resolvedAccountIDs` e
      `isSystemAccount` en selectores, con cada sitio revisado y su veredicto.
- [x] `/gate` en verde.

## Dependencias

- Depende de: [`multi-currency-accounts-1-model-and-sync`](../done/multi-currency-accounts-1-model-and-sync.md).
- Es la que permite publicar la función: sin ella, la entrega 2 enseña una tarjeta que en los
  selectores sale partida.

## Entregado (2026-10-18, PR contra 2.2)

Medido antes de empezar: la coordenada del ticket `NewTransactionView.swift:422-425` estaba desfasada (hoy `:439-443`); el
formulario no tiene selector de divisa (la divisa es la de la cuenta) e `InboxDraft` no guarda divisa; no existía un «aviso de
divisa distinta» concreto en la captura. Las decisiones que eso abrió están en el Paso 0 del encargo
(`encargos/lanzados/2026-10-18-tarjeta-varias-divisas-entrega-3.md`) y en el PR.

- **Función única** `AccountCardLogic.route` (tarjeta + divisa → principal o línea; sin coincidencia, la principal marcada
  `isFallback`; nunca crea una línea; una cuenta sin líneas vuelve igual).
- **Selector anidado** (`AccountSelectorSheet`): la tarjeta una vez («PEN · USD») y sus líneas debajo, sangradas. Tocar la
  tarjeta guarda su cuenta en la divisa del importe (`routingCurrency`); tocar una línea, esa línea. Con divisa fija (grupos)
  la lista sigue plana. Los ids `account_selector_row_` no cambian y la tarjeta va antes que su línea.
- **Formulario:** la pastilla de cuenta dice la tarjeta y al lado van sus divisas; elegir divisa elige la línea. El prellenado
  desde chat y desde un favorito pasa por la función.
- **Chat:** elegir la tarjeta en el borrador conserva la divisa dictada y apunta a su línea; una línea elegida a mano se respeta.
- **Voz, imagen, Siri:** por la divisa dictada con `DraftBuilder.findAccount` (una línea es una cuenta más de su divisa). La voz
  deja su copia; la regla común ya no elige cuentas de sistema de Grupos.
- **Apple Pay:** con el símbolo ambiguo (`$`), si la última cuenta usada es de una tarjeta cuya divisa no se escribe con `$`
  (soles) y la tarjeta tiene una cuenta que sí (su línea en dólares), el pago va a esa línea. Una tarjeta en pesos sigue como
  antes: `$` son pesos.
- **Bandeja:** al aprobar desde la hoja, la tarjeta sale con sus pastillas de divisa; el selector conserva la divisa del borrador.
- **Programados:** el borrador pasa por la función con la divisa del pago (`ScheduledPaymentDraftService.draftAccount`); el menú
  del editor pone cada línea detrás de su tarjeta.
- **Importación CSV con varias divisas:** elegir una cuenta de una tarjeta rellena las otras divisas sin asignar con sus líneas.
- **Filtros:** elegir la tarjeta incluye sus líneas en todo lector del filtro de sesión (`SessionState.selectedAccountIDs`
  normaliza al escribir); quitarla las quita; una línea elegida sola se respeta. El filtro ofrece solo la tarjeta y la píldora y
  el contador cuentan tarjetas. «Filtrar por esta cuenta» desde la tarjeta o su ficha ya incluye las líneas.
- **Presupuestos:** un presupuesto de la tarjeta cuenta los gastos de sus líneas, convertidos (`Budget.spendingAccountIDs`, en
  los dos sitios que calculan gasto), también los de una línea archivada (archivar no decide la suma). Lo guardado y lo que
  sincroniza no cambia. El editor ofrece solo la tarjeta.
- **Review adversarial** (tres lentes, 2026-10-18): Apple Pay con tarjeta en pesos, pastillas en un gasto de grupo (Caso A),
  línea archivada (presupuesto y programado) y filtro con una línea vinculada después: arreglados en este PR, cada uno con
  su test. Pendiente (entrega 4): el conector `mcp/` y el filtro del export.
- Tests: `AccountCardRouteTests`, `AccountCardCaptureTests`, `ApplePayDraftServiceTests` (`multiCurrencyCard_*`) y el XCUITest
  `AccountCardPickersUITests` (selector, filtro y presupuesto con el seed `tarjeta-dos-lineas`).
- Agrupada en la misma sesión (card «Quitar del Panel la línea «Entró … − salió …» bajo el hero»): el hero ya no repite los
  importes de las pastillas, y estas se leen «Entró …»/«Salió …» en VoiceOver. Clave `panel.hero.flowCaption` borrada de los 16
  idiomas.

Queda para la entrega 4: informes, flujo de caja y exportación por tarjeta (el filtro del export y el de pagos programados, que
no tiene pantalla, no se tocaron).

## Guion de QA en el iPhone (Jürgen)

Con el build de 2.2 de este PR y una tarjeta tuya con línea en dólares (la de la entrega 2):

1. «Nuevo registro» → «Cuenta»: tu tarjeta sale una vez, con sus divisas debajo del nombre y la línea en dólares sangrada
   debajo. Toca la tarjeta.
2. Al lado de la pastilla de la tarjeta salen «PEN» y «USD». Toca «USD», escribe 10 y guarda: en Registros el gasto sale en
   dólares en la línea USD.
3. Panel → Filtros: en «Cuentas» sale la tarjeta y no la línea. Elígela y aplica: salen los gastos en soles y en dólares.
4. Planificación → nuevo presupuesto con la tarjeta: el gastado incluye el gasto en dólares convertido.
5. Si usas el atajo de Apple Pay con la tarjeta, paga algo en `$`: el borrador de la Bandeja sale en la línea USD.
6. Mira el Panel: bajo la cifra ya no está «Entró … − salió …»; con VoiceOver, las pastillas dicen «Entró …» y «Salió …».
