---
id: 2026-11-15-saldo-panel
status: done
priority: high
area: panel
created: 2026-11-15
updated: 2026-11-16
source: encargo 2026-11-16-panel-saldo-y-tu-dinero (Jürgen, decisión del 15-nov en el chat de Frank)
---
# Panel: el saldo en grande, «Tu dinero hoy» en chico y un «?» que explica los dos

## Qué pidió Jürgen

«Debes hoy» y «Te queda» no se explicaban solos. Lo quiere «for dummies»: que la persona sepa el dinero que tiene sin
confundirse. Sin maqueta previa: directo a la app.

## Qué cambió para quien usa Yala

- **Arriba, en grande: «Tu saldo hoy».** Todas las cuentas, tarjetas incluidas, con su signo. Si las tarjetas pesan más,
  sale con el menos delante; ya no dice «Debes hoy».
- **Debajo, en chico: «Tu dinero hoy».** Lo mismo sin las tarjetas de crédito. Solo sale cuando alguna cuenta queda fuera
  (sin tarjetas, las dos cifras serían la misma).
- **«?» junto a «Tu saldo hoy»:** hoja con las dos cifras explicadas, un ejemplo (1.000 en ahorros, 300 gastados con
  tarjeta) y «Elegir qué cuentas suman», con un interruptor por cuenta.
- **Formulario de la cuenta:** interruptor «Sumar en «Tu dinero hoy»». Por defecto encendido en todo menos en la tarjeta
  de crédito.
- **Se fue del hero la línea del mes** («Te queda» con sus flechas): la cuenta Flujo de caja. El filtro de ingresos o
  gastos sigue en la barra de filtros del Panel.
- El rótulo queda más cerca de su cifra.

## Paso 0

En el encargo (`encargos/lanzados/2026-11-16-panel-saldo-y-tu-dinero.md`) y en el cuerpo del PR.

## Cómo se guarda

Una preferencia sincronizada (`panelMoneyAccountOverrides`), con solo las cuentas que la persona cambió respecto al valor
de su tipo. Sin campo nuevo en CloudKit ni en Supabase.

## Pruebas

- `YalaTests/SaldoPanel/PanelMoneyFigureTests` y `PanelMoneyScopeLogicTests`: saldo positivo, negativo con tarjeta,
  cuenta apagada, valores por tipo, varias monedas, líneas de tarjeta, preferencia y formulario.
- `YalaTests/VocabularioTienesTeQuedaTests` ajustado.
- XCUITest `PanelHeroSaldoUITests` (seed `tarjeta-dos-lineas`).
- Recorrido en el simulador con capturas: `~/Claude/entregas/2026-11-16-panel-saldo-y-tu-dinero/evidencia/`.

## Pendiente fuera del encargo

- Flujo de caja (`Yala/App/Views/Reports/CashFlow/CashFlowMonthDetailView.swift`): la cuenta de «Al 30 tendrías» sigue
  diciendo «Debes hoy» con el importe sin signo; cambiarlo pide código.
