---
id: chat-context-balances-only-read-the-last-13-months
status: backlog
priority: high
area: yala-ia
created: 2026-10-19
updated: 2026-10-19
source: review adversarial del saldo de hoy con fechas futuras (lote decidido 2.2 · 01, 2026-10-18)
---

# Yala IA calcula los saldos solo con los movimientos de los últimos 13 meses

## Qué le pasa al usuario

`FullFinancialContextBuilder.build` lee los movimientos con `date >= now − 13 meses && date <= now` (líneas ~71-72 y
~1073) y con ese conjunto calcula el saldo total (~466) y el de cada cuenta (~490). Una cuenta cuyo saldo inicial es de
hace más de 13 meses le sale mal a la IA: el Panel dice una cifra y Yala IA otra.

Además corta por instante y no por día: un movimiento de hoy con hora posterior a ahora (foto o voz, 12:00) cuenta en el
Panel y no en la IA.

## Dónde

- `Yala/Services/Chat/FullFinancialContextBuilder.swift`. Los tests de paridad entran por `buildFromArrays`, que no
  tiene la ventana de 13 meses, así que no lo ven.

Leído, sin medir en el simulador. Ya existía antes del 2026-10-18.
