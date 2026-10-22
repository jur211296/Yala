---
id: claude-mcp-numbers-match-the-app
status: done
priority: medium
area: cloud
created: 2026-09-26
updated: 2026-09-26
source: encargo 2026-09-26-plugin-claude-mcp-fase0-spike (residual, fase 1)
---

# Que las cifras que da Claude sean las mismas que enseña la app

## Qué cambia para el usuario

Si preguntas a Claude cuánto gastaste en septiembre, el número tiene que ser el mismo que ves en Estadísticas.
Hoy casi siempre lo es, pero hay tres casos en los que el conector da otra cifra, y lo avisa en la respuesta.

## Estado

La fase 0 (`mcp/src/logic/`) portó a TypeScript el saldo, el resumen de un periodo, el gasto de un presupuesto y
el equivalente mensual de los recurrentes, con tests sobre datos a mano. Tres diferencias conocidas, las tres
declaradas en el campo `avisos` de la respuesta:

1. **Gastos de grupo.** No se porta `GroupBridgeStatsAdjustment`: un gasto de grupo que pagaste tú cuenta entero,
   no «tu parte».
2. **Tasa del día.** Donde la app reconvierte con la tasa del día del movimiento, el conector usa la más reciente.
3. **Zona horaria y primer día de la semana.** El servidor no conoce la zona del teléfono (Claude la pasa o se usa
   `America/Lima`), y `firstWeekday` no viaja en `user_preferences` (medido: no hay esa key en staging).

## Qué hay que hacer

- Generar golden vectors desde los tests de Swift (patrón de `golden_vectors.json`) y hacer que los tests de `mcp/`
  los consuman: es la única forma de saber que las dos implementaciones dicen lo mismo.
- Portar `GroupBridgeStatsAdjustment` con sus goldens.
- Leer la tasa del día de `exchange_rates` (una fila por `date_key`).
- Decidir con Jürgen si la app sube su zona horaria y `firstWeekday` a `user_preferences`. Toca la app.

## Cómo se sabe que está bien

Los goldens de Swift pasan en `npm test` de `mcp/`, y el campo `avisos` ya no menciona grupos ni tasas.

## Cierre (2026-09-26)

- **Goldens desde la app:** `mcp/test/golden/app-parity.json` (filas de PostgREST escritas a mano) y
  `YalaTests/MCP/MCPAppParityGoldenTests.swift`, que mete esas filas por `EntityApplyMap` y calcula con el código de
  producción; escribe los `expected` con `TEST_RUNNER_YALA_WRITE_MCP_GOLDENS=1` y los verifica sin ella.
  `mcp/test/golden.test.ts` los consume en `npm test`. Cubren saldo por cuenta y total (con su «≈»), mes en curso,
  mes pasado y año (ingresos, gastos, neto, gasto medio, tasa de ahorro y las tres marcas «≈»), gasto de siete
  presupuestos, totales de recurrentes, el ajuste de grupos por movimiento y conversiones sueltas en sus tres calidades.
- **Grupos:** `mcp/src/logic/groups.ts`, port literal de `GroupBridgeStatsAdjustment`, cableado en resumen y
  presupuestos, con las patas hermanas leídas aunque caigan fuera del rango.
- **Tasa del día:** `mcp/src/logic/fx.ts`, port de `CurrencyConverter.resolveRates` (fila del día UTC, 30 filas
  anteriores, tabla estática).
- **`avisos`:** ya no habla de grupos ni de tasas. Queda la zona horaria cuando Claude no la pasa.
- **Premisa corregida:** `firstWeekday` ya viaja (es una `PrefSyncKey`); el ticket nuevo es solo de la zona.
- Tickets nuevos: `app-uploads-its-timezone-to-the-cloud`, `duplicate-exchange-rate-rows-pick-an-arbitrary-rate`,
  `exchange-rate-date-keys-follow-the-phone-calendar`. Diferencias declaradas: §9 de `docs/exploracion/plugin-claude-mcp.md`.
