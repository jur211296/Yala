# Una cuenta con más de una divisa: análisis de impacto (2026-10-08)

Ticket: [`multi-currency-accounts`](../tickets/backlog/multi-currency-accounts.md). Medido sobre el
árbol `e755b0d64` (`2.1` tras el PR #400). **No se ha tocado código ni se ha compilado nada.**

En este documento:

- **[medido]**: leído en el código o contado con el comando que se publica al lado.
- **[inferido]**: deducción que nadie ha ejecutado. Para confirmarla hace falta un test o el simulador.

## Resumen

1. Hoy una cuenta tiene una sola divisa, y la app depende de eso en **34 ficheros y 106 líneas** que
   leen la divisa de una cuenta, más **33 sitios** que la copian en lo que guardan.
2. **No hay un validador central.** La regla se cumple porque casi todas las entradas copian la divisa
   de la cuenta en la transacción: el formulario, los borradores, el chat, Siri, Apple Pay, la voz y
   la imagen. Los borradores de la Bandeja ni siquiera tienen campo de divisa.
3. **La app ya está partida en dos.** La mitad suma importes en crudo y les pone la divisa de la
   cuenta: tarjeta del Panel, ficha de cuenta, Ajustes, ajuste de saldo, la tabla de informes por
   cuenta y el contexto del chat de IA. La otra mitad agrupa por la divisa de cada transacción y
   convierte: saldo total, presupuestos, estadísticas y conversión.
4. Se estudiaron tres diseños. **A** une varias cuentas de una divisa en una sola tarjeta. **B** guarda
   saldos por divisa dentro de la cuenta. **C** deja que la cuenta acepte varias divisas.
5. **B se descarta con datos.** Guardar saldos crea una segunda fuente de verdad que dos teléfonos se
   pisan.
6. **C rompe la primera mitad entera.** Toca unos 50-60 ficheros, deshace la política de divisas que
   Jürgen decidió el 9-sep y el 7-oct, y un teléfono sin actualizar daría saldos mal sin avisar.
7. **Recomendación: A en su variante A1.** La tarjeta es la cuenta principal, y cada divisa extra es
   una «línea» enlazada a ella con un solo campo nuevo. Cada línea sigue siendo una cuenta de una
   divisa, así que todo lo que ya funciona sigue funcionando.
8. A1 encaja con quien hoy ya tiene la tarjeta partida en dos cuentas: **se vinculan sin tocar ni un
   movimiento**. Un teléfono viejo ve dos cuentas sueltas, con los números bien.
9. Coste estimado de A1: unos 25-35 ficheros de producción, más la vista nueva de la tarjeta, en
   cuatro entregas.
10. **Decide Jürgen:** la opción, la variante y cuatro preguntas cerradas más (sección 5).

---

## 1. Lo que hay hoy

### 1.1 El modelo [medido]

- `Yala/Models/Account.swift:17`: `var currencyCode: String = "USD"`. Una propiedad, sin sub-saldos.
- `Account` sincroniza por dos canales:
  - el espejo de iCloud: record type `CD_Account`, en `Cloudkit Schemas/yala-production.ckdb:18-41`;
  - el Modo Nube: tabla `accounts`, en `supabase-staging.ddl:15-38`.
- Las transacciones ya llevan su propia divisa: `TransactionItem.currencyCode` y `exchangeRate`.
  En la nube, `tx_items.currency_code` (`supabase-staging.ddl:394`).
- No hay migraciones versionadas de SwiftData. `rg -n 'VersionedSchema|SchemaMigrationPlan|MigrationStage' Yala YalaTests YalaWidgets YalaShare`
  solo da dos comentarios de un spike, y `rg -c 'migrationPlan' Yala` da 0. El esquema solo admite
  cambios aditivos: un campo con valor por defecto o una entidad nueva. Lo demás se ajusta con
  migraciones one-shot en el arranque (`AppBootstrapper`).

### 1.2 La app ya está partida en dos [medido]

Lo dice el propio código en `Yala/App/Logic/AccountCurrencyChangeLogic.swift:13-18`, y está medido
fichero a fichero en la sección 2:

| Suma en crudo y pone la divisa de la cuenta | Agrupa por la divisa de la transacción y convierte |
|---|---|
| `AccountBalanceCalculator` (`Yala/Utils/AccountBalanceCalculator.swift:81-83`: `Decimal(item.amount)`) | `LiveBalanceCalculator` (`:126-132`: `nativeBalances[tx.currencyCode]`) |
| Tarjeta del Panel, ficha de cuenta, lista de Ajustes | Saldo total del Panel, KPI de saldo, puntuación financiera |
| Saldo inicial y ajuste de saldo (`InitialBalanceService`) | Presupuestos (`BudgetsViewModel.swift:637-655`) |
| Tabla de informes agrupada por cuenta (`PivotTableCalculator.swift:51-59`) | Estadísticas, tendencias, distribución, flujo de caja |
| Contexto que se le pasa al chat de IA (`FullFinancialContextBuilder.swift:350-357`) | Ganancia o pérdida cambiaria (`FXPnLLogic.swift:148-158`) |
| DTO de saldos por cuenta del widget (sin lector: ver 2.5) | Filtro de divisas (`FilterService.swift:279`) |

Con una sola divisa por cuenta, las dos columnas dan lo mismo. Con dos divisas en una cuenta, la
izquierda da números falsos: S/ −500 y US$ +20 salen como «−480» en una divisa que no existe.

### 1.3 Nadie impide guardar una transacción en otra divisa [medido]

No hay validador. La regla se cumple porque las entradas copian `account.currencyCode`:

- `NewTransactionViewModel.swift:166-171`: `effectiveCurrencyCode` devuelve la divisa de la cuenta
  en cuanto hay cuenta. Una transacción nueva no tiene selector de divisa.
- `InboxDraft` **no tiene campo de divisa**. `InboxDraft.swift:341` la deriva de su cuenta. Siri,
  Apple Pay, la voz, la imagen y los programados la detectan, la usan para elegir cuenta y la
  descartan (`VisionDraftFactory.swift:73-75`, `SiriDraftService.swift:152-154`,
  `ScheduledPaymentDraftService.swift:253-271`).
- Al aprobar un borrador se guarda con la divisa de la cuenta: `DraftService.swift:351-367`,
  `:406-426`, `:541-560` y `:1052-1064`, e `InboxDraftEditSheet.swift:944-962`.
- Los únicos puntos de control reales son tres:
  - el veredicto del cambio de divisa (`AccountCurrencyChangeLogic.swift:100-141`);
  - la importación CSV, que rechaza filas de otra divisa (`TransactionCSVImportService.swift:452`,
    `:691`, `:1315`);
  - los guards del bridge de Grupos (`GroupTransactionBridge.swift:424`, `:457`, `:576`).

Comando de las escrituras que copian la divisa de la cuenta. Da **33 líneas en 11 ficheros**:

```
rg --type swift -n '(currencyCode:\s*|\.currencyCode\s*=\s*|from:\s*)(\w*[aA]ccount\??|source|dest)\.currencyCode' Yala
```

---

## 2. Inventario de impacto por área

**Conteo global** de lecturas de la divisa de una cuenta, sin `Yala/Seed`. Da **106 líneas en 34
ficheros**:

```
rg --type swift -n -e 'account\??\.currencyCode' -e 'acc\??\.currencyCode' -e 'accountCurrency' \
  -e 'selectedAccount\??\.currencyCode' -e '\$0\.account\??\.currencyCode' -e 'tx\.account\??\.currencyCode' \
  -e 'transaction\.account\??\.currencyCode' Yala YalaWidgets YalaShare | rg -v '^Yala/Seed'
```

Este conteo literal **subestima**: muchas lecturas van por `$0`, por closures o por alias. Por eso
cada área sigue el dato además del nombre.

Como referencia, `currencyCode` aparece en **477 ficheros Swift y 3.028 veces** en todo el repo
(`rg -l --type swift currencyCode | wc -l` y
`rg -c --type swift currencyCode | awk -F: '{s+=$2} END{print s}'`). Casi todo es la divisa de la
transacción, del presupuesto o de Grupos, no la de la cuenta.

`[CRÍTICO]` marca un sitio que daría un número mal o guardaría un dato malo si una cuenta tuviera
transacciones en dos divisas, es decir, con la opción C.

Los comandos de conteo por área usan el patrón `P`, que capta la divisa de una cuenta por nombre, por
alias y en closures:

```
P='(\w*[aA]ccount\??|\b(source|dest)\??|\$0|\}\??)\.currencyCode|map\(\\\.currencyCode\)'
```

### 2.1 Saldos

- `[CRÍTICO]` `AccountBalanceCalculator` (`:27-29`, `:63-71`, `:81-83`) suma `amount` sin mirar la
  divisa. Lo consumen:
  - `PanelViewModel.swift:2964-2971` (`accountBalances`, una cifra por cuenta);
  - `AccountCardView.swift:55`, `:128-134`, y `:184-191`, que además convierte esa suma mezclada a
    la preferida;
  - `AccountsSettingsListViewModel.swift:144-158`;
  - `WidgetDataCache.swift:431-447`.
- `[CRÍTICO]` Ficha de cuenta. `AccountDetailCalculator.swift:74-75`, `:118-125` y `:146-160` suman
  `amount` nativo. `AccountDetailSheet.swift:124`, `:180`, `:209` y `:311-312` lo rotulan con la
  divisa de la cuenta.
- `[CRÍTICO]` Gasto del período por cuenta: `PanelViewModel.swift:2974-2990`.
- `[CRÍTICO, guarda un dato malo]` Saldo inicial y ajuste:
  - `InitialBalanceService.swift:46-54` suma en crudo;
  - `:115-122` crea el saldo inicial en la divisa de la cuenta;
  - `:101-107` borra todos los saldos iniciales de la cuenta;
  - `AccountFormViewModel.swift:196-251` calcula el ajuste con la suma mezclada y lo guarda como
    transacción (`InitialBalanceService.swift:141`, `:156`).
- Correcto hoy: `LiveBalanceCalculator.swift:126-132` y `BalanceHelper.swift:34-77`.
- No depende de la divisa: `adjustmentMode` solo elige el modo de ajuste.
- Conteo: **20 llamadas en 11 ficheros** a las funciones de saldo.

```
rg --type swift -n -e 'AccountBalanceCalculator\.(currentBalance|batchCalculateBalances)' \
  -e 'InitialBalanceService\.(currentBalance|setInitialBalance|createAdjustment)' \
  -e 'LiveBalanceCalculator\.(liveBalance|liveBalanceBreakdown|liveBalanceOverride)\(' Yala YalaWidgets \
  | rg -v '^Yala/(Utils/AccountBalanceCalculator|App/Logic/Calculators/LiveBalanceCalculator|Services/InitialBalanceService)\.swift'
```

### 2.2 Conversión a la divisa preferida y tasas

Todo usa la divisa de la **transacción**:

- `TransactionItem.recalculatePreferredCurrency` (`TransactionItem.swift:126-134`);
- el barrido al cambiar la preferida (`CurrencyChangeService.swift:65`);
- el reparador de tasas (`TransactionUpdateService.swift:150-155`);
- `CurrencyConverter`, que no tiene ninguna referencia a `Account`.

**Excepción** [medido]: `ExchangeRateService.swift:708` decide qué tasas históricas precargar con
`Set(accounts.map { $0.currencyCode })`. [inferido] Con C, una divisa que solo aparezca en
transacciones caería a escalones peores y saldría con «≈».

Conteo: 2 líneas en 1 fichero.

```
rg --type swift -n -e 'FetchDescriptor<Account>' -e 'account\??\.currencyCode' -e 'accounts\.map \{ \$0\.currencyCode' \
  Yala/Services/ExchangeRateService.swift Yala/Services/CurrencyConverter.swift Yala/Services/CurrencyChangeService.swift \
  Yala/Services/TransactionUpdateService.swift Yala/App/Logic/ExchangeRate*.swift Yala/App/Logic/FX*.swift Yala/Models/TransactionItem.swift
```

### 2.3 Panel, informes, estadísticas, tendencias, distribución, flujo de caja, KPI y puntuación

- **No dependen de la divisa de la cuenta** [medido]. Todos van por `LiveBalanceCalculator`, por
  `amountInPreferredCurrency` o convierten desde `tx.currencyCode`:
  - saldo total (`PanelViewModel.swift:1096-1116`), KPI de saldo (`BalanceKPICalculator.swift:93`),
    puntuación financiera (`FinancialScoreCalculator.swift:382`);
  - Estadísticas, Tendencias, hero, Sankey, categorías principales, Insights, `CashFlowCalculator`,
    `BalanceTrendCalculator`, la tendencia por cuenta (`StatisticsViewModel.swift:764-825`) y el
    filtro de divisas.
  - La hoja «¿Cuánto tienes hoy?» ya desglosa por divisa.
- `[CRÍTICO]` Tabla de informes agrupada por cuenta:
  - `PivotTableCalculator.swift:51-59` suma en nativo;
  - `:72-73` rotula la cuenta con la divisa de su primera transacción.
- `[CRÍTICO]` El contexto del chat de IA: `FullFinancialContextBuilder.swift:350-357`.
- Flujo de caja por cuenta (`TrendsTabView.swift:1625-1640`, `:1730-1742`):
  - convierte bien a la divisa de la cuenta;
  - con dos divisas, la segunda se funde en la primera.
- Conteo: 13 líneas en 6 ficheros.

```
rg --type swift -n -e 'account\??\.currencyCode' -e 'dimension == \.cuenta' -e 'currentTxns\.first\?\.currencyCode' \
  -e 'InitialBalanceService\.currentBalance' -e 'accountPeriodExpenses\[' Yala/App/Views/Panel Yala/App/Views/Statistics \
  Yala/App/Views/Reports Yala/App/ViewModels/PanelViewModel.swift Yala/App/ViewModels/StatisticsViewModel.swift \
  Yala/App/ViewModels/FinancialReportViewModel.swift Yala/App/ViewModels/CashFlowPlanViewModel.swift Yala/App/Logic/Calculators \
  Yala/Services/TrendDataProcessor.swift Yala/Services/ReportNotificationService.swift Yala/Services/Chat/FullFinancialContextBuilder.swift
```

### 2.4 Presupuestos

- El gasto se calcula por transacción: `BudgetsViewModel.swift:637-655` compara `tx.currencyCode`
  con `budget.currencyCode` y convierte. **No hay ningún sitio crítico.**
- El filtro por cuenta compara `tx.account.shortcutID` con `Budget.accountIDs`
  (`BudgetsViewModel.swift:571-573`). [inferido] Con A, un presupuesto que apunte a la tarjeta tiene
  que incluir también sus líneas.
- `BudgetEditorView.swift:759` toma la divisa de la cuenta como valor por defecto.
- Conteo: `budget.currencyCode` sale en 28 líneas de 13 ficheros; el filtro por cuenta, en 9 líneas
  de 8 ficheros.

```
rg --type swift -n -e 'budget\.currencyCode' -e 'budgetCurrencyCode' Yala YalaWidgets
rg --type swift -n 'resolvedAccountIDs' Yala
```

### 2.5 Widgets

- `[CRÍTICO en el dato, invisible hoy]` `WidgetDataCache.swift:431-447` arma `WidgetAccountBalance`
  con un solo `balance` y un solo `currencyCode`. El DTO está duplicado: `WidgetDataCache.swift:112-118`
  y `YalaWidgets/Services/WidgetDataService.swift:90-96`.
  - [medido] Su único lector, `getAccountBalances()` (`WidgetDataService.swift:416-418`), no tiene
    llamadores: ningún widget pinta saldos por cuenta.
- Saldo total y del período: correctos, por transacción (`:355-359`, `:782-795`).
- Un campo nuevo en el DTO tiene que ser **opcional en las dos copias**. Si no, se apagan todos los
  widgets (regla de `.claude/rules/swiftdata-cloudkit.md`).
- Conteo: 11 líneas en 2 ficheros.

```
rg --type swift -n -e 'WidgetAccountBalance' -e 'accountBalances' -e 'getAccountBalances' -e 'account\.currencyCode' \
  -e 'AccountBalanceCalculator' Yala/Services/WidgetDataCache.swift YalaWidgets
```

### 2.6 Pagos programados, suscripciones, favoritos y borradores (lo que tocó el PR #400)

- Al crear, copian la divisa de la cuenta. Los tres son `[CRÍTICO]` con C:
  - programado: `ScheduledPaymentEditorView.swift:1481-1483`;
  - favorito: `FavoriteEditorViewModel.swift:73`, `:85`;
  - guardar como favorito o como recurrente: `NewTransactionView.swift:986`, `:1004`.
- Al materializar:
  - el borrador del programado no lleva la divisa del pago (`ScheduledPaymentDraftService.swift:253-271`);
  - la precarga de un favorito ignora `favorite.currencyCode` (`NewTransactionView.swift:1783-1787`).
- El PR #400 (`AccountCurrencyMigrationService.swift:257-341`) los selecciona **por cuenta** y los
  convierte. Lo dice su línea `:304-305`: «el borrador no guarda divisa: la toma de la cuenta al
  aprobarse».
- Conteo: 24 referencias en 7 ficheros.

```
rg --type swift -n "$P" Yala/Models/ScheduledPayment.swift Yala/Models/FavoritePayment.swift Yala/Models/InboxDraft.swift \
  Yala/App/Services/ScheduledPaymentDraftService.swift Yala/App/Services/ScheduledPaymentPaidStatusHelper.swift \
  Yala/App/ViewModels/ScheduledPaymentEditorViewModel.swift Yala/App/ViewModels/ScheduledPaymentsViewModel.swift \
  Yala/App/Views/Planning/ScheduledPaymentEditorView.swift Yala/App/Views/Planning/Components/TransactionAssociationSheet.swift \
  Yala/App/ViewModels/FavoriteEditorViewModel.swift Yala/App/ViewModels/SaveAsFavoriteViewModel.swift Yala/App/Views/Favorites \
  Yala/App/Views/Transactions/SaveAsFavoriteSheet.swift Yala/Services/DraftService.swift Yala/App/Views/Inbox \
  Yala/App/ViewModels/InboxDraftEditViewModel.swift
```

### 2.7 Transferencias

- Una transferencia FX son **dos transacciones**, una en cada cuenta, ligadas por `transferPairID`.
  Cada pata toma la divisa de su cuenta (`NewTransactionViewModel.swift:715-808`).
- `[CRÍTICO con C]` `needsExchangeRate` compara las divisas de las dos cuentas
  (`NewTransactionViewModel.swift:150-159`). Una transferencia dentro de la misma cuenta bimoneda
  nunca pediría tasa.
- `TransferPairReconcileService.swift:92-125` empareja por divisa de la transacción, no de la cuenta.
- `TransferMigrationService` **no depende de la divisa**: solo mueve transferencias positivas de
  «Otros» a «Ingresos» (líneas 1-60).
- Una pata de transferencia bloquea el cambio de divisa de la cuenta
  (`AccountCurrencyChangeLogic.swift:100-104`).
- Conteo: 4 referencias en 1 fichero. Las lecturas que guardan datos viven en
  `NewTransactionViewModel` y se cuentan en 2.15.

```
rg --type swift -n "$P" Yala/Services/TransferMigrationService.swift Yala/Services/TransferPairReconcileService.swift \
  Yala/Services/TransferPartnerLookup.swift Yala/App/Views/Transactions/Components/TransferAmountInputView.swift
```

### 2.8 Importación (CSV, PDF) y parsers de IA (voz, chat, imagen)

- **CSV/XLSX:**
  - guarda con la divisa **del fichero** (`TransactionCSVImportService.swift:190`, `:1110`, `:1505`,
    `:1666`);
  - `[CRÍTICO con C]` pero rechaza toda fila que no coincida con la cuenta (`:452`, `:691`, `:1315`,
    `:1619-1623`);
  - la importación multidivisa asigna cada divisa a una cuenta por `account.currencyCode`
    (`ImportCurrencyMappingSheet.swift:97-99`).
- **PDF:** no hay importador de estados de cuenta. Un PDF entra por la ruta de imagen, que lee la
  primera página (`ImageSelectionView.swift:691-700`).
- **Imagen, voz, Siri y Apple Pay:** usan la divisa del parser para buscar cuenta y la descartan.
  - `DraftBuilder.findAccount(byCurrency:)` (`DraftBuilder.swift:28-35`) solo devuelve cuenta si
    hay **exactamente una** con esa divisa.
  - La voz tiene su propia copia (`VoiceRecordingView.swift:962-978`).
- **Chat:**
  - `[CRÍTICO con C]` `ChatTransactionDraft.swift:124-125` define
    `effectiveCurrencyCode = account?.currencyCode ?? dictada`;
  - `ChatAssistantViewModel.swift:794-797` sobrescribe la divisa al elegir cuenta.
- **Share extension:** 0 referencias a divisa o cuenta.
- Conteo: 20 referencias en 10 ficheros.

```
rg --type swift -n "$P" Yala/Utils/TransactionCSVImportService.swift Yala/App/Views/Import Yala/App/ViewModels/ImportIntroViewModel.swift \
  Yala/App/Services/DraftBuilder.swift Yala/App/Services/ImageVision Yala/App/Views/Image/ImageSelectionView.swift Yala/App/Views/Voice \
  Yala/Services/TranscriptionParserService.swift Yala/App/Models/ChatTransactionDraft.swift Yala/App/ViewModels/ChatAssistantViewModel.swift \
  Yala/Services/ChatAssistantService.swift YalaShare
```

### 2.9 Export CSV

- Escribe `tx.currencyCode` y el nombre de la cuenta (`TransactionsExportService.swift:443-449`,
  `:580-583`). No depende de la divisa de la cuenta.
- El filtro de divisas del asistente de exportación sale de las cuentas elegidas
  (`ExportFiltersStepViewModel.swift:134-140`). [inferido] Con C, la segunda divisa de una cuenta no
  aparecería como opción.
- Conteo: 2 referencias en 2 ficheros.

```
rg --type swift -n "$P" Yala/Utils/TransactionsExportService.swift Yala/Utils/TransactionsExportModels.swift \
  Yala/App/ViewModels/ExportFiltersStepViewModel.swift Yala/App/Views/ExportWizard
```

### 2.10 Bridge de Grupos: el precedente de A

- [medido] El bridge **ya crea una cuenta por divisa**:
  `GroupBridgeSystemEntities.ensureSystemAccount(currencyCode:)` (`:113-194`).
  - La busca por la identidad lógica `isSystemAccount && currencyCode`.
  - La crea bajo demanda y la desarchiva si estaba archivada.
  - Si hay duplicados entre dispositivos, se queda una y archiva las demás.
  - La deduplicación se repite en el sync (`SystemEntityMergePolicy.swift:9-10`,
    `CloudSyncReconciler.swift:220-226`).
  - Se archiva sola cuando se vacía (`:208-245`).
- Las pantallas ya saben esconderlas: pickers, Ajustes en sección propia, Panel en gris y fuera del
  límite Free.
  - Conteo de `isSystemAccount`: **90 líneas en 45 ficheros** de `Yala/`.
  - Comando: `rg --type swift -n 'isSystemAccount' Yala`.
- **Riesgo para A** [medido]: el bridge distingue la pata virtual por `account?.isSystemAccount` en
  al menos seis sitios (`GroupTransactionBridge.swift:294-295`,
  `GroupBridgeStatsAdjustment.swift:174-175`, `DraftService.swift:312`…). **Las líneas de una
  tarjeta no pueden reutilizar `isSystemAccount`**: el bridge las tomaría por patas virtuales.
- `[CRÍTICO con C]` Guards `realTx.currencyCode == expense.currencyCode` y
  `providedAccount.currencyCode == expense.currencyCode` (`GroupTransactionBridge.swift:424`, `:457`,
  `:576`). También el `currencyFilter` del selector de cuentas: **10 líneas en 7 ficheros**, con
  `rg --type swift -n 'currencyFilter' Yala`.
- Conteo de las lecturas de divisa de cuenta en Grupos: 11 referencias en 8 ficheros.
  Comando: `rg --type swift -n "$P" Yala/Services/Groups Yala/App/ViewModels/Groups Yala/App/Views/Groups`.

### 2.11 Sync con Supabase (Modo Nube)

[medido, sin tocar Supabase]

- **Esquema.** `currency_code` sale **7 veces** en `supabase-staging.ddl`: `accounts:19`,
  `budgets:44`, `favorite_payments:183`, `inbox_drafts.cached_currency_code:236`,
  `scheduled_payments:310` y `tx_items:394` y `:401`. En `supabase-groups-staging.ddl` sale **20
  veces**, todas de Grupos. Es `TEXT` sin CHECK.
- **Emisión y apply de `accounts`.** Emisión en `EntityEmissionMap.swift:529-561`; apply en
  `EntityApplyMap.swift:507-536`, con `currency_code` en `:524`. **Account no tiene ningún grupo de
  coherencia**: todas sus columnas son `"safe": true` en `capability_manifest.json:62-127`.
- **Clientes viejos.** No hay versionado de columnas ni de entidades. El cliente siempre declara
  `v1` (`SyncPullClient.swift:122`), la lista de columnas protegidas está vacía
  (`gateway/src/sync/schemaGate.ts:23`) y `MIN_SUPPORTED_BUILD = "0"` (`gateway/wrangler.toml:57`,
  `:173`).
  - **Columna nueva:** el cliente viejo la ignora
    (`guard let applier = entry.appliers[column] else { continue }`, `SyncApplyEngine.swift:471`).
  - **Tabla nueva:** el cliente viejo deja cada fila en cuarentena y apaga el Merkle de esa tabla
    (`SyncApplyEngine.swift:300`, `:336`).
- **Orden de despliegue.** Si el Worker aún no conoce una columna, rechaza la fila entera
  (`unknown_column`, `gateway/src/sync/manifest.ts:122-125`), y el cliente la aparta sin subirla
  (`SyncPushClient.swift:478-499`). Por tanto van primero el DDL, el manifest y el Worker, y después
  la app.
- **Cómo se migra la nube.** SQL suelto por ticket en `qa/cloud/`; el molde de columna nueva es
  `g14_01_group_budget_limit.sql`. Se aplica en staging, se sondea y luego en producción
  (`docs/RUNBOOK-staging-ddl.md:359`). `apply_delta` escribe con `jsonb_populate_record`: una columna
  nueva no lo toca, una tabla nueva sí amplía su lista blanca.
- **Registrar una entidad nueva** cuesta en torno a diez puntos:
  - en `EntityEmissionMap`: `table(forClass:)` y `catalog`;
  - en `EntityApplyMap`: `wiredTables`, `isWired`, `nonFiniteMoneyColumns`, `deleteLiveRows` y la
    comprobación de fila viva;
  - `CloudSyncEngine.personalEntityNames`;
  - el manifest y el DDL;
  - tres tests de paridad con «16 entidades» escrito a mano
    (`CloudCapabilityManifestParityTests.swift:231`, `EntityEmissionParityTests.swift:146`,
    `CloudSyncSchemaParityTests.swift:543`).
- **Conteo** de `currency_code|currencyCode` en `Yala/Services/CloudSync`: 53 líneas en 10 ficheros.
  Comando: `rg -n 'currency_code|currencyCode' Yala/Services/CloudSync`.

### 2.12 SwiftData y el espejo de iCloud

[medido]

- `CD_Account` tiene 13 campos (`yala-production.ckdb:18-31`) y **ninguno se puede reutilizar**.
- Un campo o un record type nuevos exigen **desplegar el esquema a Production** en los dos
  contenedores personales, `yala` y `yala_dev`. Si no, producción rechaza en silencio cada guardado de
  ese tipo. Ya pasó: incidente `isOpeningBalance`, cuatro días de sync muerto; y `CD_GroupBridgePreference`,
  commit `c76b5c2a8`.
- **Ningún test vigila el `.ckdb` personal**: `rg -c 'ckdb' YalaTests` da 0. Ver la deuda
  `personal-cloudkit-schema-snapshot-misses-optional-fields` en la sección 7.
- Moldes de migración one-shot en `AppBootstrapper.swift`:
  - `migrateToLiveBalanceIfNeeded` (`:2667-2710`): centinela, espera a que el store esté quieto y
    reintenta si falla;
  - `migrateShortcutIDsAndRebuildCSVMirrors` (`:2195-2365`), con `MigrationGateLogic`.

### 2.13 Siri, App Intents, Shortcuts y Apple Pay

- **No hay `AppEntity` de cuenta** [medido]. Solo existen `BudgetAppEntity` y
  `ScheduledPaymentAppEntity`.
- `[CRÍTICO con C]` Apple Pay resuelve un símbolo ambiguo (`$`, `kr`) con la divisa de la **última
  cuenta usada** (`ApplePayDraftService.swift:83-89`). Con una tarjeta bimoneda en soles, un pago en
  `$` quedaría en soles.
- Siri usa la divisa sugerida solo para elegir cuenta (`SiriDraftService.swift:152-154`).
- Centro de Control: 0 referencias.
- Conteo: 1 referencia en 1 fichero. El resto pasa por `DraftBuilder.findAccount`, contado en 2.8.

```
rg --type swift -n "$P" Yala/App/Intents Yala/Shared/ControlCenterIntents.swift Yala/App/Services/ApplePayDraftService.swift Yala/App/Services/SiriDraftService.swift
```

### 2.14 Formulario y detalle de cuenta, pickers, filtros, archivado y tarjeta de crédito

- **Formulario de cuenta:** una sola divisa, `selectedCurrency` (`AccountFormViewModel.swift:54`),
  que se escribe al crear (`:607`) y al editar (`:916`).
- **Selector de cuentas:** cada fila enseña una divisa (`AccountSelectorSheet.swift:144`). Filtra por
  divisa solo en el caso A de Grupos (`:63`).
- **Filtro de cuentas:** es un conjunto de identificadores, `selectedAccountIDs`: **60 líneas en 17
  ficheros**, con `rg --type swift -n 'selectedAccountIDs' Yala`.
- **Límite Free:** `isBillableUserAccount` (`Account.swift:96`). Con A, cada línea sería una
  `Account` y contaría si no se excluye **dentro de ese predicado**.
- **Tarjeta de crédito:**
  - El día de pago y el recordatorio están en `Account.swift:39-41`.
  - La notificación (`ScheduledPaymentNotificationService.swift:500-541`) solo lleva el nombre de la
    cuenta, **sin importe**, y se deduplica por `shortcutID` y día.
  - «Por pagar» es solo una etiqueta: `PanelAccountCardLogic.swift:41-49` la pone cuando el saldo de
    una tarjeta es negativo.
  - **No existe** límite de crédito, utilización ni ciclo de facturación.
- Conteo: `creditCardPaymentReminder|creditCardPaymentDay` sale en 21 líneas de 6 ficheros, con
  `rg --type swift -n 'creditCardPaymentReminder|creditCardPaymentDay' Yala`.

### 2.15 Formulario de transacción y veredicto de cambio de divisa

- `[CRÍTICO con C]` Al elegir cuenta, el formulario fija la divisa a la de la cuenta
  (`NewTransactionView.swift:422-425`).
- El veredicto del cambio de divisa (`AccountCurrencyChangeLogic.swift:45-141`) devuelve `.free`,
  `.needsConversion` o `.blocked`.
  - Basta una transferencia, un gasto de grupo o una liquidación para bloquear el cambio.
  - Si se acepta, reexpresa cada importe con la tasa de **su** fecha
    (`AccountCurrencyMigrationService.swift:153-192`).
  - Su docblock llama a «una cuenta en USD con parte del histórico en PEN» «exactamente el estado que
    este ticket existe para impedir»: **C convertiría ese estado en el normal**.
- Conteo: 26 referencias en 6 ficheros.

```
rg --type swift -n "$P" Yala/App/ViewModels/NewTransactionViewModel.swift Yala/App/Views/Transactions/NewTransactionView.swift \
  Yala/App/Views/Transactions/AccountSelectorSheet.swift Yala/App/Logic/AccountCurrencyChangeLogic.swift \
  Yala/App/ViewModels/Accounts/AccountFormViewModel.swift Yala/App/ViewModels/RecordsViewModel.swift Yala/Services/TransactionService.swift
```

### 2.16 Tests y UITests que fijan el supuesto

[medido]

- `currencyCode` aparece en **200 ficheros de `YalaTests` y 1.414 líneas**; en `YalaUITests`, en 0.
  - Comando: `rg -n currencyCode YalaTests YalaUITests`.
- Construyen `Account(... currencyCode:)` **135 veces en 63 ficheros**. Compilan con A si el campo
  nuevo tiene valor por defecto.
  - Comando: `rg -U --count-matches '\bAccount\(\s*[^)]*?currencyCode:' YalaTests YalaUITests`.
- **Suites que fijan «una divisa por cuenta»:**
  - `MismatchedTransactionSaveTests`, `ChatDraftAccountCurrencyTests` y `ApplePayDraftServiceTests`
    (`:223 twoAccountsSameCurrency_noAutoMatch`);
  - `GroupExpenseViewModelM6Tests` y `RecordsViewModelBulkAccountCurrencyTests`;
  - `TransactionCSVImportServiceTests:111` e `InitialBalanceServiceTests`;
  - las cuatro del cambio de divisa (`AccountCurrencyChangeLogicTests`,
    `AccountCurrencyMigrationServiceTests`, `AccountCurrencyPlanConversionTests` y
    `AccountFormCurrencyGateTests`), que suman **54 casos**;
  - `AccountBalanceCalculatorTests` y `PanelAccountsRedesignTests`;
  - las del bridge con cuentas de sistema por divisa;
  - las de paridad del sync;
  - las de los DTO del widget.
- Estimación por diseño [inferido]:
  - **A:** 195-200 de 200 ficheros siguen verdes. Se ponen rojas de 3 a 5 pruebas de paridad del sync,
    y lo que hay que tocar son los artefactos, no los tests.
  - **B:** 20-28 ficheros y 150-200 casos.
  - **C:** 15-25 ficheros y 100-150 casos, sobre todo los 54 del cambio de divisa y unos 8 ficheros
    de «manda la cuenta». Además, muchos tests siguen verdes sin cubrir el caso nuevo.
- **UITests:** todo perfil de seed con datos personales siembra una cuenta en PEN y otra en USD
  (`Yala/Seed/DevSeedAccounts.swift:21-36`). Los que eligen cuenta con `account_selector_row_`
  (BEGINSWITH) podrían coger la tarjeta en vez de la línea.
- **`qa/coverage-index.json`:** ningún área cubre `Account.swift`, `AccountBalanceCalculator` ni las
  transferencias. Habría que reverificar:
  - de cuentas: `accounts-crud`, `panel-dashboard-logic` y `transactions-core-crud`;
  - de divisas: `fx-conversion-persistence` y `currency-filter-statistics`;
  - el widget: `widgets-widgetkit`;
  - de Grupos: `groups-bridge-personal`;
  - del sync: `cloud-backend-schema`, `cloud-sync-capture` y `cloud-sync-pull-apply`.

---

## 3. Las opciones

### A. Una tarjeta agrupa varias cuentas de una divisa cada una

**Cómo se ve para la persona.**

- En el Panel hay una sola tarjeta «Visa BCP» con dos líneas: «S/ −1.250» y «US$ −80».
- Debajo sale el total en su divisa preferida: «≈ S/ −1.548».
- Al registrar un gasto elige «Visa BCP», y la divisa del importe decide la línea.
- En Ajustes la tarjeta sale una vez, con sus líneas anidadas.

**Modelo.** Cada línea es una `Account` normal de una sola divisa. Lo único nuevo es que las líneas
saben a qué tarjeta pertenecen. Hay dos variantes:

- **A1. Enlace a la cuenta principal.** La tarjeta es su línea principal, por ejemplo la de soles.
  - Cada línea extra lleva un campo nuevo, provisionalmente `parentAccountID: UUID?`, con el
    `shortcutID` de la principal.
  - La principal guarda el nombre, el día de pago y el recordatorio.
  - No hay entidad nueva.
- **A2. Entidad «tarjeta» nueva.** Un modelo nuevo (por ejemplo `AccountGroup`) con nombre, tipo, día
  de pago y recordatorio, y todas las líneas apuntan a él.
  - Es más simétrico.
  - Pero es una tabla nueva en la nube y un record type nuevo en iCloud: unos diez puntos de
    registro, cuarentena en clientes viejos y tres tests de paridad con el 16 escrito a mano
    (sección 2.11).

**Pros**

- **Conserva el invariante «una cuenta, una divisa»** que fijaron el PR #118, el PR #400 y la
  decisión 2A del 7-oct. Los `[CRÍTICO]` de la sección 2 no se tocan, porque cada línea sigue
  teniendo una divisa.
- **Reusa un patrón probado:** el bridge de Grupos ya tiene una cuenta por divisa, deduplicada en
  local y en el sync.
- **Quien ya tiene la tarjeta partida en dos cuentas la une sin migrar datos:** vincular es escribir
  un campo. Ningún movimiento cambia, que es justo lo que pide 2A («el historial no se toca»).
- **Degrada bien en un teléfono viejo:** ve dos cuentas sueltas con los números correctos.
- **Es la práctica habitual en contabilidad** [inferido, criterio general, no medido en el repo]: una
  cuenta de libro lleva una sola divisa, y un producto multidivisa es un contenedor de saldos de una
  divisa cada uno.

**Contras**

- La sensación de «una sola tarjeta» depende de la interfaz. Si las líneas se filtran como cuentas
  sueltas en selectores, filtros o presupuestos, la persona ve dos cuentas.
- Hay que excluir las líneas del límite Free dentro de `isBillableUserAccount`.
- Seleccionar la tarjeta en un filtro o un presupuesto tiene que incluir sus líneas.
- El recordatorio solo puede estar en la principal, o llegaría duplicado.
- Hace falta un marcador propio: no se puede reutilizar `isSystemAccount` (sección 2.10).
- **Riesgo propio de A1:** el enlace usa `shortcutID`, y ese UUID se puede regenerar cuando CloudKit
  lo entrega colapsado (`CategoryDeduplicationService.repairCollapsedIdentityUUIDs`). La regla del
  CSV mirror obliga a reconstruir todo lo que lo referencia. **El campo nuevo tiene que entrar en esa
  reconstrucción**, o la línea queda huérfana.
  - En Modo Nube el campo viaja como referencia, igual que `account_ref`, y le aplica la regla de
    las referencias colgadas.

**Alcance estimado** [inferido a partir del inventario; los números son ficheros de producción]

| Área | A1 | A2 |
|---|---|---|
| Modelo, sync y esquema: `Account` o modelo nuevo, emisión, apply, manifest, DDL, SQL en `qa/cloud/`, deploy de `.ckdb` | 6-8 | 12-15 |
| Lógica pura de líneas: sin dos líneas en la misma divisa, línea huérfana, archivar en cascada, límite Free | 2-3 | 2-3 |
| Panel, ficha de la tarjeta y Ajustes (vista nueva) | 6-8 | 6-8 |
| Selectores, filtros y presupuestos (incluir las líneas) | 5-7 | 5-7 |
| Captura: chat, voz, imagen, Siri y Apple Pay eligen la línea por divisa | 3-5 | 3-5 |
| Informes por cuenta, flujo de caja por cuenta y export | 3-4 | 3-4 |
| **Total** | **~25-35** | **~31-42** |

**Migración**

- **Local:** un campo opcional nuevo. Es aditivo, no necesita plan de migración ni one-shot.
- **iCloud:** un campo en `CD_Account` (A1) o un record type nuevo (A2), desplegados a Production en
  los dos contenedores **antes** de publicar la versión.
- **Nube:** una columna `safe` en `accounts` (A1) o una tabla nueva con sus políticas, triggers y la
  lista blanca de `apply_delta` (A2). Orden: DDL, manifest, Worker y después la app.
- **Clientes viejos:**
  - en A1 ignoran la columna;
  - en A2 dejan las filas en cuarentena;
  - en ninguno de los dos casos dan números mal.

**Riesgo:** bajo en dinero, porque ningún cálculo cambia de premisa; medio en interfaz.

### B. Saldos por divisa guardados dentro de la cuenta

**Cómo se ve.** Igual que A para la persona: una cuenta, dos saldos.

**Modelo.** Una entidad nueva, por ejemplo `AccountCurrencyBalance` (cuenta, divisa, importe), que
cuelga de `Account`.

**Se descarta, por tres datos:**

1. **Crea una segunda fuente de verdad.** Hoy el saldo **se deriva** de las transacciones: desde
   `migrateToLiveBalanceIfNeeded`, hasta el saldo inicial es una transacción. Un saldo guardado hay
   que mantenerlo en cada alta, edición, borrado, importación y apply del sync.
   - [inferido] En Modo Nube, dos teléfonos que registran un gasto a la vez escriben cada uno su
     saldo, y la regla «gana la última escritura» pierde uno de los dos incrementos.
2. **Si el saldo no se guarda y solo se declaran las divisas, B es C con una tabla más.** Hereda todos
   los `[CRÍTICO]` de C y añade una entidad nueva: cuarentena en clientes viejos, unos diez puntos de
   registro y tres tests de paridad.
3. **Es el que más tests rompe:** 20-28 ficheros y 150-200 casos (sección 2.16).

**Alcance si se hiciera:** el de C más unos 12-15 ficheros de sync y esquema.

### C. La cuenta acepta transacciones en varias divisas

**Cómo se ve.**

- Una sola cuenta «Visa BCP».
- Al registrar un gasto aparece un selector de divisa.
- La tarjeta del Panel enseña el saldo por divisa.

**Modelo.** Sin cambio obligatorio en la transacción, porque ya lleva su divisa. En la práctica hace
falta guardar qué divisas admite la cuenta, para el selector, la importación y la desambiguación de
Apple Pay: un campo nuevo en `Account`. Además, `InboxDraft` necesita su propia divisa, que es un
campo nuevo en `CD_InboxDraft` y en la columna `inbox_drafts`.

**Pros**

- Para la persona es lo más directo: una cuenta es una cuenta.
- Obliga a arreglar la mitad de la app que suma en crudo. Eso cerraría de raíz la clase de bugs de
  `changing-an-account-currency-orphans-its-whole-history`.
- La mitad que ya agrupa por divisa no se toca: saldo total, presupuestos y estadísticas.

**Contras**

- **Toca todos los `[CRÍTICO]` de la sección 2:**
  - saldos, ficha, Ajustes, saldo inicial y ajuste;
  - tabla de informes y contexto de IA;
  - formulario de transacción (selector de divisa nuevo);
  - cinco aprobaciones de borradores, programados y favoritos;
  - chat, voz, imagen, Siri y Apple Pay;
  - importación CSV, transferencias dentro de la misma cuenta y bridge de Grupos.
- **Deshace la política de Jürgen.** El veredicto de cambio de divisa, la migración del PR #400 y el
  rechazo de la importación existen para impedir justo el estado que C vuelve normal. Habría que
  rediseñarlos: «cambiar la divisa» pasa a ser «añadir o quitar una divisa».
- **Un teléfono sin actualizar da números falsos sin avisar.** No hay cambio de esquema que le impida
  recibir transacciones en dólares dentro de una cuenta en soles, y su `AccountBalanceCalculator` las
  sumaría en crudo.
  - Para evitarlo hace falta subir `MIN_SUPPORTED_BUILD` y obligar a actualizar.
  - **En iCloud no existe ningún mecanismo equivalente.**
- Hoy la regla se cumple por convención, no por validación (sección 1.3). Con C, cada camino que se
  olvide de pasar la divisa vuelve a estampar la de la cuenta sin avisar.

**Alcance estimado:** unos 50-60 ficheros de producción, más los campos nuevos en `Account` e
`InboxDraft` en los dos canales, más rediseñar el cambio de divisa (4 suites y 54 casos).

**Riesgo:** alto en dinero. Es la mitad crítica de la app, y su red de tests hoy no puede ponerse roja
por el caso nuevo.

### 3.1 Los cinco casos, opción por opción

| Caso | A (A1) | B | C |
|---|---|---|---|
| **Cambiar la divisa de una cuenta** (PR #118 y #400) | Vale tal cual en cada línea. Regla nueva: no puede haber dos líneas de la tarjeta con la misma divisa. «Cambiar la divisa de la tarjeta» no existe: se añade o se retira una línea. | El veredicto pasa a decidirse por saldo; el saldo guardado hay que recalcularlo. | El veredicto actual deja de tener sentido. Hay que rediseñarlo como «añadir o quitar divisa». La migración del #400 convierte todas las filas a una sola divisa y **reexpresaría también las de dólares** [inferido]. |
| **Pagar la línea en dólares con soles** | Transferencia FX normal entre dos cuentas, con dos patas y la tasa implícita en los importes. **Funciona hoy, sin cambios.** | Transferencia dentro de la misma cuenta: las dos patas en la misma `Account`; hay que rehacer `needsExchangeRate` y el guardado. | Igual que B: transferencia dentro de la misma cuenta, más el emparejado, los bloqueos de edición en lote y la ficha de cuenta. |
| **Día de pago y recordatorio** | Viven en la principal. Las líneas los tienen apagados, o la notificación llegaría duplicada. El texto no lleva importe, así que la divisa no le afecta. | Sin cambios: una cuenta, un recordatorio. | Sin cambios. «Por pagar» tiene que mirar cada divisa. |
| **Saldo total «en mi divisa»** | Ya es correcto: `LiveBalanceCalculator` agrupa por divisa. El total de la tarjeta es nuevo: sus líneas convertidas con la tasa de hoy y la marca «≈» por divisa. | El total sale de saldos guardados, que pueden discrepar de las transacciones. | Ya es correcto. El total de la tarjeta, igual que en A. |
| **Modo Nube, dos teléfonos en versiones distintas** | El viejo ignora la columna y ve dos cuentas sueltas, **con los números bien**. Basta desplegar primero la nube y el esquema de iCloud; no hace falta forzar la actualización. | El viejo deja los saldos en cuarentena y apaga el Merkle de esa tabla; en iCloud los ignora. | El viejo recibe transacciones de otra divisa en una cuenta de una divisa y **suma mal sin avisar**. Hace falta subir `MIN_SUPPORTED_BUILD`, y para iCloud no hay forma. |

En los tres casos, el total «en mi divisa» arrastra el ticket
`preferred-currency-has-three-different-defaults`: cuatro sitios responden tres cosas distintas
cuando falta la divisa preferida. No lo empeora ni lo arregla ninguna opción.

---

## 4. Recomendación: A1

**Por qué.** Jürgen pide lo más robusto y de mejor práctica aunque tarde más. Aquí eso no es C, que
toca más, sino A1:

1. **Robustez:** cambia la premisa del dinero en cero sitios. Los `[CRÍTICO]` siguen recibiendo una
   cuenta de una divisa.
2. **Sync:** un solo campo `safe`. Un cliente viejo no rompe ni miente, y no hay que forzar
   actualizaciones en un canal, iCloud, que no sabe forzarlas.
3. **Coherencia con lo ya decidido:** respeta la política del 9-sep y la decisión 2A del 7-oct sin
   reabrirlas.
4. **Precedente:** el bridge de Grupos ya vive con una cuenta por divisa desde hace meses.
5. **Camino de entrada:** quien ya partió su tarjeta en dos cuentas la une con un toque y sin
   migración.

A1 gana a A2 porque una columna es mucho menos superficie que una tabla nueva: unos diez puntos de
registro menos, sin cuarentena en clientes viejos y sin tocar tres tests de paridad.

**Lo que haría fallar a A1**

- **Una interfaz a medias.** Si las líneas salen como cuentas sueltas en algún selector, filtro o
  presupuesto, la persona ve dos cuentas y la función parece rota. Mitigación: la entrega 3 recorre
  los 17 ficheros de `selectedAccountIDs`, los 8 de `resolvedAccountIDs` y los selectores que hoy
  excluyen `isSystemAccount`.
- **El UUID de identidad regenerado** (sección 3 A, riesgo propio). Si el campo nuevo no entra en la
  reconstrucción, la línea queda huérfana. Mitigación: la lógica pura trata una línea cuyo padre no
  existe como cuenta suelta (falla cerrado y visible), más un test con el UUID colapsado.
- **Desplegar el esquema de iCloud tarde.** Si la versión sale antes del deploy a Production, el
  guardado de cuentas muere en silencio. Mitigación: deploy en la entrega 1, antes de cualquier UI,
  y comprobar en la consola de iCloud que el campo existe en Production.
- **Dos líneas en la misma divisa** creadas en dos teléfonos a la vez. Mitigación: la misma
  deduplicación del bridge (`SystemEntityMergePolicy`), por `(tarjeta, divisa)`.

## 5. Preguntas cerradas para Jürgen

1. **¿Qué opción?**
   - **A, recomendada**;
   - B;
   - C.
2. **Si A, ¿qué variante?**
   - **A1, enlace a la cuenta principal y sin entidad nueva: recomendada**;
   - A2, entidad «tarjeta» nueva.
3. **¿Solo tarjetas de crédito o cualquier tipo de cuenta?**
   - **Cualquier tipo, ofrecido primero en tarjetas de crédito: recomendada.** Cuesta lo mismo y
     cubre cuentas bimoneda de ahorro.
   - Solo tarjetas de crédito.
4. **¿Se pueden vincular dos cuentas que ya tienen movimientos?**
   - **Sí, recomendada:** vincular no toca el historial, en línea con 2A.
   - No, solo líneas nuevas.
5. **¿Las líneas extra cuentan para el límite Free de cuentas?**
   - **No, la tarjeta cuenta una vez: recomendada**;
   - Sí, cada línea cuenta.
6. **¿Cómo se elige la línea al registrar un gasto?**
   - **Se elige la tarjeta y la divisa del importe decide la línea; el selector enseña las líneas
     anidadas: recomendada**;
   - se elige siempre la línea concreta («Visa · USD»).

Ninguna exige subir la versión mínima, `MIN_SUPPORTED_BUILD`: con A1 un teléfono viejo sigue dando
números correctos.

## 6. Entregas propuestas para A1

Son propuestas: se abren como tickets cuando Jürgen decida.

1. **`multi-currency-accounts-1-model-and-sync`: modelo, sync y esquema, sin UI.**
   - `parentAccountID` en `Account`.
   - Emisión, apply, manifest, DDL en `qa/cloud/` con staging, sonda y producción.
   - Deploy de `CD_Account` a Production en `yala` y `yala_dev`.
   - Lógica pura de líneas: misma divisa, huérfana, sin ciclos ni más de un nivel.
   - Exclusión del límite Free.
   - Entrada en la reconstrucción de UUID colapsados.
   - Review adversarial, porque es sync.
2. **`multi-currency-accounts-2-card-view`: la tarjeta en pantalla.**
   - Carrusel y ficha agregados, con saldo por línea y total convertido con «≈».
   - Ajustes con líneas anidadas.
   - Formulario: «Añadir línea en otra divisa» y «Vincular cuenta existente».
   - Recordatorio solo en la principal.
   - Capturas de antes y después.
3. **`multi-currency-accounts-3-pickers-and-capture`: que en ningún sitio se vean dos cuentas.**
   - Selector anidado.
   - Filtros y presupuestos que incluyen las líneas.
   - Formulario, chat, voz, imagen, Siri y Apple Pay eligen la línea por divisa dentro de la
     tarjeta.
4. **`multi-currency-accounts-4-reports-and-export`: informes.**
   - Tabla de informes y flujo de caja por tarjeta o por línea.
   - Columna de tarjeta en el export.

La 1 va sola y antes que nada, porque el esquema de iCloud y de la nube tiene que estar desplegado
antes de que ningún cliente escriba el campo.

---

## 7. Deudas encontradas por el camino

Existen hoy, elija Jürgen lo que elija. Tienen ticket propio y no se han arreglado:

- [`personal-cloudkit-schema-snapshot-misses-optional-fields`](../tickets/backlog/personal-cloudkit-schema-snapshot-misses-optional-fields.md)
  (high):
  - los snapshots `.ckdb` del contenedor personal no tienen campos opcionales que los modelos sí
    escriben, por ejemplo `Account.accountNumber` y `FavoritePayment.amount`;
  - faltan en los cuatro entornos;
  - o el snapshot no es fiel, o producción rechaza esos guardados;
  - hay que mirarlo en la consola de iCloud.
- [`bulk-move-to-another-currency-account-relabels-the-amount`](../tickets/backlog/bulk-move-to-another-currency-account-relabels-the-amount.md)
  (medium): mover movimientos en lote a una cuenta de otra divisa reetiqueta el importe sin
  convertirlo, de modo que 50 USD pasan a ser 50 PEN.

Relacionados que el diseño elegido toca, enlazados sin reabrirlos:

- `changing-an-account-currency-orphans-its-whole-history` y
  `account-currency-change-leaves-scheduled-and-favorites-stale`: A los conserva, C los rediseña.
- `saving-a-mismatched-transaction-relabels-it-without-converting` y
  `cloudsync-account-currency-orphans-receiver-history`: la decisión 2A.
- `preferred-currency-has-three-different-defaults`: afecta al total «en mi divisa» con cualquier
  opción.
- `account-collections`:
  - se solapa con A en la fila de Ajustes y en el filtro por conjunto;
  - pero una colección es un conjunto de muchos a muchos para filtrar, sin saldo ni divisa, y sus
    cuentas siguen contando para el límite Free;
  - A1 no la sustituye, ni ella sustituye a A1.
- `cashflow-scheduled-line-ignores-payment-currency`: lo mismo con cualquier opción.
- `bridge-virtual-only-currency-mismatch-is-silent`: con C, el guard sin `else` se dispararía más.
- `converted-amount-sweep-blind-to-input-changes`: con C, crecen los inputs que hay que vigilar.
