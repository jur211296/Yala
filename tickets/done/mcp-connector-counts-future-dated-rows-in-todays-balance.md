---
id: mcp-connector-counts-future-dated-rows-in-todays-balance
status: done
priority: medium
area: mcp, balances
created: 2026-10-19
updated: 2026-11-05
source: review adversarial del saldo de hoy con fechas futuras (lote decidido 2.2 · 01, 2026-10-18)
---

# El conector de Claude da otro «saldo de hoy» que la app cuando hay un movimiento con fecha futura

## Qué le pasa al usuario

Desde el 2026-10-18 la app deja fuera del saldo de hoy los movimientos fechados después de hoy (decisión A de Jürgen,
`LiveBalanceCalculator.TodayCutoff`). El conector (`mcp/src/logic/balances.ts`, `computeBalances`) sigue sumando
todas las filas. Con 1.000 hoy y −200 mañana, la app dice 1.000 y el conector 800, en el total y por cuenta.

## Dónde

- `mcp/src/logic/balances.ts:45-70`: sin corte de fecha. La consulta (`mcp/src/toolCore.ts`, `COLUMNS.txBalance`) no
  trae `date` ni `local_day`, y `listar_cuentas` no recibe zona horaria.
- `MCPAppParityGoldenTests` no lo ve: `app-parity.json` no tiene ningún movimiento posterior al `now` del escenario.

## Qué hace falta

Portar el corte por día (con `zoneOf` y `txDay` de `dates.ts`), ampliar las columnas, añadir un movimiento futuro al
golden y regenerarlo. **Desplegar el conector es producción**: lo hace Jürgen.

## Resuelto (encargo «Login Apple y Google en el conector + lote P7», 2026-11-04/05)

- `computeBalances` corta en el día de hoy de la zona del usuario: lo fechado después no entra ni en la cuenta ni en
  el total, y `listar_cuentas` lo avisa («Hay 1 movimiento con fecha posterior a hoy…»). Corta por el instante
  `date` y no por `local_day` (`mcp/src/logic/balances.ts`).
- **Golden de paridad:** `MCPAppParityGoldenTests` usa ahora el saldo por cuenta que enseña la app
  (`AccountBalanceCalculator`, con el corte) y `liveBalanceBreakdown(asOf: now)`; antes usaba
  `InitialBalanceService.currentBalance`, que ninguna pantalla usa. El escenario `sin-filas-de-tasas` lleva un
  gasto posterior a `now`. Regenerado desde la app en el simulador; `mcp/test/golden.test.ts` usa el `now` del
  escenario y pasa.
- Desplegado en staging. Producción, con el runbook del conector (Jürgen).
