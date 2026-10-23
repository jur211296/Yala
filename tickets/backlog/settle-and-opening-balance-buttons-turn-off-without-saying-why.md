---
id: settle-and-opening-balance-buttons-turn-off-without-saying-why
status: backlog
priority: low
area: groups
created: 2026-10-21
updated: 2026-10-21
source: lote decidido 2.2 · 11 (L13-9, visto al buscar el mismo patrón)
---

# «Apuntar pago» y el «Guardar» del saldo inicial se apagan sin decir qué falta

L13-9 (decisión B de Jürgen) dejó «Guardar» siempre activo en el formulario de gasto de grupo: al tocarlo con algo
pendiente marca el campo y una línea dice qué falta. Dos formularios hermanos siguen con el patrón viejo:

- `SettlementFormView`: «Apuntar pago» apagado con el importe a 0.
- `GroupOpeningBalanceFormView`: «Guardar» apagado sin quién debe, a quién, o con los dos iguales o sin importe.

No se tocaron en el lote porque la decisión nombra el formulario de gasto. Si Jürgen quiere el mismo trato, es la misma
pieza (`GroupExpenseMissingFieldLogic` como molde).
