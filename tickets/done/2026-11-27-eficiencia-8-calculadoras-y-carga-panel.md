---
id: 2026-11-27-eficiencia-8-calculadoras-y-carga-panel
status: done
priority: medium
area: "performance, widgets, panel, arranque"
created: 2026-11-27
updated: 2026-11-27
source: "decisión de Jürgen del 27-nov-2026, ~10:14 Lima (encolar Eficiencia 8 en 2.3 antes del barrido QA de la build 12); lo que dejó anotado Eficiencia 7 (docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-7-foto-widgets-y-arranque/)"
---

# Las calculadoras de saldo y la carga del Panel dejan de trabar el arranque

Con 16.004 movimientos en el iPhone 14 quedaban, tras Eficiencia 7, tres tramos de 146-197 ms sin ceder el hilo en
calculadoras compartidas (saldo vivo, lectura de tasas de la curva y saldos por cuenta) y una carga del Panel con un tramo
de 293 ms sin ceder.

## Qué se hizo

- Las tres calculadoras ganan un acumulador fila a fila (`SumaSaldoVivo`, `SumaSaldosPorCuenta`,
  `BalanceValuation.LecturaDeTasas`); la versión de una vez, con su firma de siempre, recorre con él. Un solo cuerpo de
  reglas para todos los llamadores.
- La foto de los widgets suma saldo vivo y saldos de las tarjetas sobre las filas ya leídas, por tramos, y la curva lee
  sus tasas por tandas.
- El Panel carga por tramos que ceden el hilo (`cargarPorTramos`): ajuste de grupos y huérfanos sobre las filas que miran,
  saldos y líneas de Grupos en una sola pasada. En el cálculo, el saldo vivo de la curva una sola vez y por tramos, y el
  saldo grande por tramos.
- Paridad contra copias congeladas del código previo, con cinco mutantes en rojo (`YalaTests/Eficiencia8CalculadorasYCargaPanel/`).

## Resultado (iPhone 14, 16 k)

Tramo más largo: saldo vivo 197 → ≤ 50 ms (salvo la nota de salud, 204 ms), tasas de la curva 146 → 29 ms, saldos por
cuenta 158 → ≤ 50 ms (salvo la nota de salud, 140 ms), carga del Panel 293 → 27-48 ms. Foto de los widgets: tramo máximo ~210 →
~127 ms. Cuelgues > 250 ms del arranque: 6 (2,6 s) → 4 (1,4 s). Panel listo: ~10,6 → ~10,0 s. Informe:
`docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-8-calculadoras-y-carga-panel/`.

## Fuera

- La nota de salud del Panel (`FinancialScoreCalculator.plan`, `FinancialScoreAlertsLogic.negativeAccounts`) sigue con
  las versiones de una vez del saldo vivo y los saldos por cuenta: fuera del encargo.
- La curva de saldo de la app (`TrendDataProcessor.fillBalanceBuckets`, hasta 178 ms) y la proyección de la foto
  (`ProyeccionFoto.resultado`, 153 ms): fuera del encargo.
