---
esfuerzo: high
---
# Medir qué cuelga de «una cuenta, una divisa» y dejar 2-3 diseños con alcance para que una tarjeta lleve saldo en soles y en dólares, sin tocar código de producto

## Contexto
Card del tablero `tablero-una-cuenta-con-mas-de-una-divisa-la-tarj-mn0q` (lista para lanzar, prioridad media). Ticket: `tickets/backlog/multi-currency-accounts.md` (idea de Jürgen del 2026-09-09, sin spec). Jürgen lo volvió a pedir el 2026-10-08 a las 13:55 (Lima): quiere una sesión de **análisis** para saber el impacto antes de decidir. **Esta sesión no implementa nada**: el resultado es un documento y el ticket actualizado. La decisión final es de Jürgen, vía Frank.

La idea, en lenguaje de usuario: una tarjeta de crédito peruana bimoneda cobra en soles y en dólares **por separado**, cada línea con su propio saldo, pero es una sola tarjeta y la persona la piensa como una. Hoy la única salida es partirla en dos cuentas, y entonces no hay ninguna vista de «cuánto debo en esta tarjeta».

Lo que hay en 2.1 hoy (2026-10-08, `e755b0d64`). Son pistas, así que verifícalas en este árbol antes de escribir nada:
- `Yala/Models/Account.swift:17`: `var currencyCode: String = "USD"`. Una propiedad, un `String`. Sin sub-saldos ni relación a saldos por divisa. `Account` es un `@Model` de SwiftData con espejo de CloudKit (defaults obligatorios, relaciones opcionales, sin `.unique`), así que cualquier campo o entidad nueva tiene que respetar esas reglas y lo que exija el esquema de producción de CloudKit (que no deja borrar ni renombrar campos ya desplegados).
- `TransactionItem` ya lleva su propia divisa (`Yala/Models/TransactionItem.swift:18` `currencyCode`, `:47` `exchangeRate`). `Budget`, `ScheduledPayment`, `FavoritePayment` (opcional), `SplitExpense`, `SplitGroup` y `SplitSettlement` también tienen `currencyCode`. Hoy el sistema exige que la divisa de la transacción coincida con la de su cuenta. Eso es lo que hizo que cambiar la divisa de una cuenta dejara «desemparejados».
- Saldo: `AccountBalanceCalculator` (`Yala/Utils/AccountBalanceCalculator.swift`) y `LiveBalanceCalculator` (`Yala/App/Logic/Calculators/LiveBalanceCalculator.swift`).
- Precedente que conviene mirar: el bridge de Grupos ya crea **una cuenta sistema por divisa** (`Account.isSystemAccount`, «Grupos PEN», etc.). Es justo el patrón de la opción A de abajo, visto desde dentro.
- Falso amigo: `currencyToSuggestAsSecondary` (`AccountFormViewModel.swift`) es una preferencia global de visualización (`"secondaryCurrencies"`), no multi-divisa de cuenta.
- Cloud: `supabase-staging.ddl` tiene `currency_code` en 7 sitios (incluida la tabla de cuentas). `supabase-groups-staging.ddl` lo tiene en 20. El applier es `Yala/Services/CloudSync/EntityApplyMap.swift` (bloque `accounts`: `"currency_code": Apply.stringReq(\.currencyCode)`), y la emisión es `EntityEmissionMap.swift`.
- Medición orientativa de Frank (`git grep` sobre `origin/2.1`, sin afinar; **rehazla tú con `rg`**): 477 ficheros Swift mencionan `currencyCode` (3.028 apariciones; ~200 son tests). Solo 44 ficheros (103 líneas) lo leen como `account.currencyCode` literal: el resto va por variables con otro nombre, `$0`, closures o la divisa de la transacción. Por eso el conteo literal subestima y hay que seguir el dato, no el nombre. Reparto aproximado por ruta: Panel, estadísticas e informes ~59, Grupos y bridge ~56, widgets ~32, programados, favoritos y Bandeja ~26, IA (chat, voz, imagen, insights) ~19, presupuestos ~11, CloudSync ~10, importación y export ~8, divisas y tasas ~8, Siri e intents ~3, transferencias ~2.

Tickets y trabajo relacionado (léelos; no los reabras):
- `tickets/qa/changing-an-account-currency-orphans-its-whole-history.md` (high, PR #118): el mismo supuesto visto por su lado roto.
- `tickets/qa/account-currency-change-leaves-scheduled-and-favorites-stale.md`, mergeado hoy en el **PR #400** (`4ec6f0c5e`): cambiar la divisa convierte también programados, favoritos y borradores. Mira `Yala/App/Logic/AccountCurrencyChangeLogic.swift` y `Yala/Services/AccountCurrencyMigrationService.swift`: son el mapa más reciente de todo lo que se ata a la divisa de una cuenta.
- `tickets/qa/saving-a-mismatched-transaction-relabels-it-without-converting.md` y `tickets/backlog/cloudsync-account-currency-orphans-receiver-history.md`: la decisión 2A de Jürgen del 2026-10-07 (avisar, convertir programados y favoritos a la tasa de hoy, no tocar el historial).
- `tickets/backlog/preferred-currency-has-three-different-defaults.md`: la divisa preferida tiene tres defaults distintos. Afecta a cualquier suma «total en mi divisa».
- `tickets/backlog/account-collections.md`: agrupar cuentas en colecciones con nombre. Puede solaparse con la opción A.
- `tickets/backlog/cashflow-scheduled-line-ignores-payment-currency.md`, `bridge-virtual-only-currency-mismatch-is-silent.md` y `converted-amount-sweep-blind-to-input-changes.md`: deudas de divisa que el diseño elegido puede arreglar o empeorar.

Para orientarte: `CLAUDE.md`, `docs/TICKETS.md` (schema de tickets), `docs/DECISIONS.md` (busca divisas, CloudKit y Modo Nube) y `.claude/rules/` que toquen modelo de datos, CloudKit o sync. No leas el repo entero: sigue el dato desde `Account.currencyCode`.

## Que se pide
1. **Inventario de impacto, medido.** Todo lo que depende de `Account.currencyCode` y del supuesto «una divisa por cuenta», con rutas y líneas, y un conteo por área (ficheros y referencias, con el comando `rg` exacto que usaste para que se pueda repetir). Las áreas, como mínimo:
   - Saldos: `AccountBalanceCalculator`, `LiveBalanceCalculator`, saldo inicial (`InitialBalanceService`) y ajustes de saldo.
   - Conversión a la divisa preferida y tasas (`ExchangeRateService`, `convertedAmount` y sus barridos).
   - Panel, informes, estadísticas, tendencias, distribución, flujo de caja, KPI y puntuación financiera.
   - Presupuestos.
   - Widgets (`WidgetDataCache`, el target del widget).
   - Pagos programados, suscripciones, favoritos y borradores de la Bandeja (lo que tocó el PR #400).
   - Transferencias entre cuentas, incluidas las de distinta divisa (`TransferMigrationService`).
   - Importación de estados de cuenta PDF y CSV, y los parsers de IA (voz, chat, imagen): ¿qué divisa estampan y de dónde la sacan?
   - Export CSV.
   - Bridge de Grupos (cuentas sistema por divisa, patas FX).
   - Sync con Supabase: esquema cloud (`supabase-staging.ddl`), emisión y apply (`EntityEmissionMap`, `EntityApplyMap`), grupos de campos y migración de la nube.
   - Migración SwiftData (esquemas versionados si los hay) y espejo de iCloud/CloudKit: qué cambio de esquema se puede hacer sin romper a quien está en una versión anterior.
   - Siri, App Intents, Shortcuts y Apple Pay.
   - Formulario y detalle de cuenta, pickers de cuenta, filtros y archivado.
   - Tests y UITests que fijan el supuesto (cuántos habría que tocar).
2. **De 2 a 3 opciones de diseño**, cada una con pros y contras, cómo se ve para la persona, y alcance estimado: ficheros por área, migración de datos local (SwiftData y CloudKit) y de la nube (DDL de Supabase, compatibilidad con clientes viejos en Modo Nube), riesgo y orden de entrega posible. Como punto de partida, mejóralas o descártalas con datos:
   - **A. Cuenta padre que agrupa sub-cuentas de una divisa cada una.** La tarjeta es un grupo visual; cada línea es una `Account` normal. Reusa todo lo que ya sabe de una divisa. Mira el precedente de las cuentas sistema de Grupos y el solape con `account-collections`.
   - **B. Sub-saldos por divisa dentro de una cuenta.** Modelo nuevo (por ejemplo `AccountCurrencyBalance`) colgando de `Account`. La cuenta deja de tener una sola divisa.
   - **C. La transacción manda.** La cuenta acepta transacciones en varias divisas y su saldo se suma por divisa (la transacción ya tiene `currencyCode`). Hay que revisar todo lo que hoy asume que coinciden, incluido el veredicto de cambio de divisa del PR #400.
   Para cada opción di explícitamente qué pasa con: el cambio de divisa de una cuenta (PR #118 y #400), las transferencias entre las dos divisas de la misma tarjeta (pagar la línea en dólares con soles), el día de pago y el recordatorio de tarjeta de crédito, el saldo total «en mi divisa», y un usuario en Modo Nube con dos teléfonos en versiones distintas.
3. **Recomendación razonada.** Jürgen prefiere la opción más robusta y de mejor práctica aunque tome más tiempo. Dila con el porqué, con lo que la haría fallar y con qué habría que decidir antes de empezar (preguntas cerradas para Jürgen, cada una con la opción recomendada). Si conviene partirla en entregas (por ejemplo, primero modelo y migración, después UI), propón los tickets de cada entrega.
4. **Dónde queda.** Escribe el análisis como sección `## Análisis de impacto (2026-10-08)` dentro de `tickets/backlog/multi-currency-accounts.md`. Si no cabe con claridad, ponlo en un doc en `docs/` (por ejemplo `docs/multi-currency-accounts-impact-2026-10.md`) enlazado desde el ticket, con un resumen de diez líneas en el ticket. Actualiza `updated:` del ticket y `docs/TICKETS.md` si el repo lo pide. Si salen deudas nuevas que no dependen de la decisión (bugs de divisa que encuentres por el camino), ábreles ticket propio en `tickets/backlog/` y enlázalos. No los arregles.
5. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, solo docs y tickets, limpieza). Al cerrar, mueve la card `tablero-una-cuenta-con-mas-de-una-divisa-la-tarj-mn0q` a «awaiting decision» asignada a jurgen, con la pregunta («¿qué opción, A/B/C?», con la recomendada) y el enlace al PR. Usa `tablero mover <id> --a "awaiting decision" --agente frank`, `tablero asignar <id> --a jurgen --agente frank` y `tablero editar <id> --pregunta "..." --enlace "PR #N|<url>" --agente frank`.

## Que NO hay que tocar
- Nada de código de producto: ni modelos, ni migraciones, ni DDL de Supabase, ni gateway. Solo `tickets/` y `docs/`.
- Nada de producción ni de staging: no ejecutes SQL ni migraciones contra Supabase, ni siquiera de lectura. Lo que necesites del esquema sale de los `.ddl` del repo.
- No hace falta build ni simulador: no compiles (`xcodebuild` no) ni arranques ningún simulador. Si por algún motivo lo necesitaras, sigue el pipeline serial de la Mini (limpiar, build con `-jobs 2` sin simulador, un solo simulador, tests, apagar y borrar ese simulador) y borra al cerrar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar.
- No reabras ni muevas los tickets relacionados de divisa (los de qa esperan device-QA de Jürgen). Solo enlázalos.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de `marketing/` ni `Web/`.

Regla día/noche (hora de Lima): entre las 06:00 y las 21:00, si aparece una duda de producto que bloquea el análisis, pregúntala con AskUserQuestion. Entre las 21:00 y las 06:00, no uses AskUserQuestion: deja la duda escrita en el documento como pregunta cerrada para Jürgen (A/B/C con recomendación) y sigue. En ningún horario se decide aquí la opción final: eso es de Jürgen.

Gate: la sesión arranca ya sobre `origin/2.1`. La sesión viva `inbox-dismiss-x-does-not-delete-the-draft-for-good` puede tener su PR en CI: no la esperes, porque esta solo toca docs y tickets. Solo si al final hay conflicto en `docs/TICKETS.md` o en el ticket con lo que haya entrado en `2.1`, rebasa una sola vez y resuélvelo conservando las entradas de los dos lados.

Mini limpia al cerrar: sin simuladores encendidos, sin worktree ni cachés de esta sesión tras el merge, sin borrar nada de otra sesión viva.

## Como se sabe que esta bien
- Inventario por área con rutas, conteos y los comandos `rg` que los reproducen. Ninguna área de la lista queda sin mirar; si una no depende de la divisa de la cuenta, está escrito el porqué.
- De 2 a 3 opciones con pros, contras, alcance (ficheros, migración local y cloud, riesgo) y la respuesta a los cinco casos del punto 2 en cada una.
- Recomendación razonada con preguntas cerradas para Jürgen, y tickets de entrega propuestos si aplica.
- Ticket `multi-currency-accounts` actualizado (y doc en `docs/` enlazado si hizo falta), con los relacionados enlazados.
- PR a 2.1 solo de docs y tickets, en auto-merge. Sin build ni simulador. Card en «awaiting decision» asignada a jurgen con la pregunta y el enlace al PR.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿El análisis va dentro del ticket o en un doc aparte?** → Doc aparte
(`docs/multi-currency-accounts-impact-2026-10.md`) con resumen de diez líneas en el ticket.
Por qué: el inventario por quince áreas con rutas y comandos no cabe con claridad en un ticket.
Alternativa descartada: todo en el ticket, que lo volvería ilegible desde el móvil.

**D2 · ¿Cambia el `status` del ticket?** → No: sigue en `backlog`, con `updated: 2026-10-08`.
Por qué: la opción la decide Jürgen; moverlo a `in-progress` anticiparía una decisión que no hay.

**D3 · ¿Se pregunta a Jürgen durante la sesión (es de día en Lima)?** → No.
Por qué: ninguna duda bloquea el análisis; las decisiones de producto van como preguntas cerradas en
el doc y en la card. Alternativa descartada: AskUserQuestion, que pararía la sesión por algo que el
encargo ya reserva a Jürgen.

**D4 · ¿PR o commit directo?** → PR a `2.1` en auto-merge.
Por qué: lo pide el encargo, aunque un diff solo de `docs/` y `tickets/` podría ir directo.

**D5 · ¿Qué hallazgos llevan ticket propio?** → Solo los bugs de divisa que existen hoy con
independencia de la opción elegida, tras buscar duplicados por síntoma. Las deudas que solo existen
si se elige una opción quedan dentro del análisis, no como tickets.

**D6 · Conteos: ¿se reutiliza la medición orientativa del encargo?** → No; se rehace con `rg` en este
árbol (`e755b0d64`) y se publica el comando exacto de cada cifra.
