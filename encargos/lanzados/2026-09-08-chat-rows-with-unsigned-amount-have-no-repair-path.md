# Migrar a ciegas el corpus de gastos del chat guardados sin signo (ventana 2026-04-27 → fix)

## Contexto
Ticket: `tickets/backlog/chat-rows-with-unsigned-amount-have-no-repair-path.md` (high).
Hijo de `chat-draft-drops-the-expense-sign` (PR #102 mergeado): la ruta hacia delante ya firma; las filas viejas siguen rotas.

## Decisión de Jürgen (2026-09-08) — REGISTRADA, NO REPREGUNTAR
**Migrar a ciegas**, acotado por fecha **2026-04-27 → build/fecha del fix #102**.
- Forma: categoría de gasto (`isIncome == false`) + `amount > 0` dentro de esa ventana.
- Aceptado: los reembolsos legítimos en esa ventana también se voltean.
- Negar `amount` **y** `amountInPreferredCurrency` (no usar `recalculatePreferredCurrency`: propaga el signo).
- One-shot con flag en defaults, estilo `repairLegacyOneToOneRatesIfNeeded`.
- Antes de implementar: mirar `SyncContentAnchor.canonicalAmount` (el signo entra al ancla).
- Test: un reembolso legítimo **fuera** de la ventana (o la forma documentada) sobrevive; el corpus de la ventana sí se corrige.
- Registrar la decisión en el ticket / ESTADO / board + `docs/TICKETS.md`.

## Que se pide
Implementar el barrido según AC del ticket + decisión arriba. Merge a 2.1 y `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen (esta ya está tomada).

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No ampliar la migración fuera de la ventana acordada sin nueva decisión.

## Como se sabe que esta bien
- AC del ticket con la decisión aplicada; test de supervivencia de reembolso; PR mergeado; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
