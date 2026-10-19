---
id: mcp-connector-counts-future-dated-rows-in-todays-balance
status: backlog
priority: medium
area: mcp, balances
created: 2026-10-19
updated: 2026-10-19
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
