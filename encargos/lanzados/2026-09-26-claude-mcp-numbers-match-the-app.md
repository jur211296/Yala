# Que las cifras del conector Claude (mcp/) coincidan con las de la app, verificado con goldens de Swift

## Contexto
Ticket `tickets/backlog/claude-mcp-numbers-match-the-app.md` (léelo entero primero). Es la fase 1 del conector MCP de Claude para Yala. La fase 0 (PR #261) portó a TypeScript en `mcp/src/logic/` el saldo, el resumen de periodo, el gasto de presupuesto y el equivalente mensual de recurrentes, con tests sobre datos hechos a mano. El PR #263 (ya en 2.1) cerró el agujero del token: el Worker emite sus propios tokens OAuth. Hay tres diferencias conocidas con la app, declaradas en el campo `avisos` de la respuesta: gastos de grupo (falta `GroupBridgeStatsAdjustment`), tasa del día (usa la más reciente) y zona horaria / `firstWeekday`.
Todo contra staging (`yala-modo-nube-staging`). El PAT de gestión de Supabase de staging está en `~/Secrets/yala-supabase-mgmt/pat` (Keychain `yala-supabase-mgmt-pat`) si hace falta; no tocar producción.

## Qué se pide
1. Generar golden vectors desde los tests de Swift (sigue el patrón existente de `golden_vectors.json`) para saldo, resumen de periodo, presupuesto, recurrentes y el ajuste de grupos, y hacer que `npm test` en `mcp/` los consuma.
2. Portar `GroupBridgeStatsAdjustment` a `mcp/src/logic/` con sus goldens, para que un gasto de grupo cuente «tu parte» igual que en la app.
3. Leer la tasa del día desde `exchange_rates` (una fila por `date_key`) con el mismo fallback que la app.
4. Zona horaria y `firstWeekday`: decisión ya tomada, NO preguntes a Jürgen. En esta sesión el conector sigue aceptando la zona que pase Claude (default `America/Lima`) y un `firstWeekday` opcional, y el aviso de `avisos` queda solo para ese caso. Que la app suba su zona y `firstWeekday` a `user_preferences` va en un ticket NUEVO aparte (toca código Swift de la app; área cloud, prioridad medium), no se implementa aquí.
5. Quitar de `avisos` los textos de grupos y tasas una vez cubiertos.

## Qué NO hay que tocar
- Código Swift de la app (salvo añadir tests/generador de goldens en el target de tests si es imprescindible; nada de lógica de producción). Hay otra sesión de Cola A tocando la app en paralelo.
- Producción de Supabase. El flujo OAuth del Worker que dejó #263.
- `marketing/` y cualquier otro proyecto.

## Cómo se sabe que está bien
- Los goldens de Swift pasan en `npm test` de `mcp/`, y los tests de Swift que generan/verifican goldens siguen en verde.
- El campo `avisos` ya no menciona grupos ni tasas.
- Worker desplegado en staging y una llamada real de prueba devuelve cifras coherentes.
- Ticket nuevo creado para la subida de zona/`firstWeekday` desde la app.

## MODO AUTÓNOMO
Queda suspendida la regla del repo de pedir aprobación si se tocan más de 3 ficheros y el «¿Sigo?» tras el plan: implementa de punta a punta sin pedir permiso para continuar, abre PR contra 2.1, mergea cuando esté verde y cierra con `/cerrar-total`, dejando el ticket movido en `tickets/` y `docs/TICKETS.md` actualizado con conteos correctos. Bugs o decisiones nuevas de camino van a ticket propio antes de cerrar. Es horario diurno (06:00–21:00 Lima): puedes usar AskUserQuestion solo para decisiones reales de producto o de acceso; a partir de las 21:00, elige la opción recomendada o aparca en ticket.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Dónde viven los goldens y quién escribe cada mitad?** → `mcp/test/golden/app-parity.json`. Las ENTRADAS
son filas en forma de PostgREST, escritas a mano; los `expected` los escribe un test de Swift
(`YalaTests/MCP/MCPAppParityGoldenTests.swift`) con `TEST_RUNNER_YALA_WRITE_MCP_GOLDENS=1`, y sin esa variable el
mismo test los VERIFICA. `npm test` los consume. Por qué: el patrón de `golden_vectors.json` (JSON + `#filePath`),
y las entradas legibles para quien añada un caso desde TS. Descartado: escenarios en Swift que emiten las filas
(obliga a un serializador modelo→wire solo para el test).

**D2 · ¿Con qué código de la app se calculan los `expected`?** → El real, sin tocar producción: las filas entran
por `EntityApplyMap` (el mismo camino del pull), y se calcula con `InitialBalanceService`, `LiveBalanceCalculator`,
`FullFinancialContextBuilder.buildFromArrays` (periodos y totales de recurrentes), `BudgetsViewModel.calculateSpending`,
`GroupBridgeStatsAdjustment.build(from:context:)` y `CurrencyConverter.convertChecked(on:)`. Por qué: un golden
calculado con una réplica del test solo probaría la réplica.

**D3 · ¿Cómo se hace determinista algo que en la app depende de `Date.now` y `Calendar.current`?** → Escenarios
con `now` y movimientos a las 12:00 UTC (mismo día civil de UTC−11 a UTC+11) y tasas en el pasado. La semana y
`firstWeekday` quedan fuera de los goldens (siguen en tests de TS). Descartado: fijar la zona del proceso de tests
(`NSTimeZone.default` es global y los tests corren en paralelo).

**D4 · ¿Qué es «la tasa del día»?** → Port exacto de `CurrencyConverter.resolveRates`: clave = día UTC de `date`
(no `local_day`); la fila de ese día; si le falta alguna divisa, las 30 filas estrictamente anteriores; y si aún
falta, la tabla estática `CurrencyCode.fallbackRates` (portada y verificada contra el golden). La «tasa de hoy»
de saldos, presupuestos y recurrentes es la misma función con el día UTC de ahora, igual que la app. `aproximado`
= calidad no exacta. Descartado: seguir sin tabla estática («el mismo fallback que la app» la incluye).

**D5 · Filas de tasas duplicadas para un mismo `date_key`** (medido: 367 días duplicados en el usuario de 1133
filas, 732 pares con valores distintos, hasta un 12,6 %). → Se funden en una por día: por divisa gana la fila con
`timestamp` más reciente (nulo = más vieja), luego la que trae más divisas, luego `sync_id`. Por qué: la app coge
`results.first` sin orden, así que no hay cifra de la app que copiar; se elige una regla determinista y se abre
ticket para la app. Los goldens usan una fila por día.

**D6 · ¿Qué filas de tasas se leen?** → Las del rango de días UTC que se necesiten más las 30 anteriores al primero,
con `timestamp`. Por qué: cubre la ventana de 30 filas de la app sin leer las 1133 filas.

**D7 · Ajuste de grupos** → Port literal de `GroupBridgeStatsAdjustment.build` con su identificación por signo,
`is_system_account` y rol «Préstamo a grupos» por nombre en todos los idiomas (lista generada desde Swift y
verificada en el golden; `is_system`/`is_default_seed` pasan a leerse). Se construye con el conjunto más amplio:
los movimientos del rango más las patas hermanas por `split_expense_id`. Saldos nunca se ajustan (como la app).

**D8 · Avisos** → Fuera los de grupos y de tasa del día. Queda el de «aproximado», redactado como lo que es: la
app también marca esas cifras con ≈. Zona: aviso solo cuando Claude no pasó la zona y se usa la de por defecto.
`firstWeekday` se acepta como entrada opcional (`primer_dia_semana`) y, si no llega, se lee de las preferencias.

**D9 · Premisa corregida: `firstWeekday` ya viaja.** Medido: es una `PrefSyncKey` («ints por presencia»,
`PreferenceMergeLogic.swift:109`), así que se sincroniza en cuanto el usuario la cambia; sin ella la app usa lunes
(`userConfiguredCalendar`), igual que el conector. Staging no tiene la key porque nadie la ha tocado. → No hay aviso
de semana (sería falso) y el ticket nuevo se queda con la zona horaria.

**D10 · Tickets nuevos** → (a) `app-uploads-its-timezone-to-the-cloud` (cloud, medium); (b)
`duplicate-exchange-rate-rows-pick-an-arbitrary-rate` (la app convierte con una fila arbitraria cuando hay varias
del mismo día).
