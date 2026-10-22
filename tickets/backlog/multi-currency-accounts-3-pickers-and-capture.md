---
id: multi-currency-accounts-3-pickers-and-capture
status: backlog
priority: medium
area: "accounts, currency, transactions, budgets, capture"
created: 2026-10-10
updated: 2026-10-10
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

- [ ] Suite de la función tarjeta + divisa → línea: coincide con línea, coincide con principal, no
      coincide con ninguna (va a la principal y no crea línea), cuenta sin líneas (sin cambios).
- [ ] Cada entrada del punto 3 tiene un test que, con la tarjeta y un importe en USD, guarda la
      transacción en la línea USD: formulario, chat, voz, imagen, Siri, Apple Pay y aprobación de
      borrador.
- [ ] `ApplePayDraftServiceTests` y `ChatDraftAccountCurrencyTests` siguen en verde: con cuentas sin
      líneas nada cambia.
- [ ] El selector enseña la tarjeta una vez con las líneas anidadas; XCUITest con el seed de tarjeta
      de dos líneas. Los UITests que eligen cuenta con `account_selector_row_` (BEGINSWITH) siguen
      eligiendo la cuenta que querían.
- [ ] Filtro: elegir la tarjeta en Registros enseña los movimientos de las dos líneas; test.
- [ ] Presupuesto con la tarjeta: un gasto en la línea USD cuenta, convertido; test.
- [ ] Barrido documentado en el PR: `rg` de `selectedAccountIDs`, `resolvedAccountIDs` e
      `isSystemAccount` en selectores, con cada sitio revisado y su veredicto.
- [ ] `/gate` en verde.

## Dependencias

- Depende de: [`multi-currency-accounts-1-model-and-sync`](multi-currency-accounts-1-model-and-sync.md).
- Es la que permite publicar la función: sin ella, la entrega 2 enseña una tarjeta que en los
  selectores sale partida.
