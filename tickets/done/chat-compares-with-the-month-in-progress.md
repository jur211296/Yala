---
id: chat-compares-with-the-month-in-progress
status: backlog
priority: medium
area: chat, ai, statistics
created: 2026-10-07
updated: 2026-10-07
source: banco de chat.answer (sesión 2 del gateway de IA, gateway/bench/results/2026-10-07/REPORT-chat-y-nota.md)
---

# Yala IA compara el mes en curso con el mes pasado entero

## Qué le pasa al usuario

Pregunta a mitad de mes «¿gasto más que el mes pasado?» y le responde que gasta menos, porque compara lo que lleva del
mes con el mes pasado completo.

## Lo medido (2026-10-07)

- El contexto de `FullFinancialContextBuilder` no trae «el mes pasado hasta el mismo día». Es la mayor fuente de
  respuestas equivocadas del banco (las cinco malas de la muestra a mano, «Yes… less»).
- La app ya resuelve esa comparación en Tendencias (MTD contra MTD).

## Hecho cuando

- El contexto lleva el mes pasado hasta el día equivalente y el prompt dice cuándo usarlo.
- Caso del banco a mitad de mes que hoy falla y pasa.
