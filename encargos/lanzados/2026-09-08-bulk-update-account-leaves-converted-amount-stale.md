# bulkUpdateAccount deja el monto convertido de la divisa vieja

## Contexto
Cola mediums (Jürgen 2026-09-08, bypass autónomo). Tras barrido QA #109 (simulador) retomamos mediums: éste → `fx-approximate-mark-missing-on-secondary-surfaces` → `bridge-de-grupos-pierde-la-marca-de…`.

Ticket: `tickets/backlog/bulk-update-account-leaves-converted-amount-stale.md` (medium; currency/fx/cloud-sync). Sale de review adversarial de `fx-manual-writes-seal-approximate-as-final`.

Hoy no tiene llamador (UI usa `RecordsViewModel.bulkUpdateAccount` / `DraftService`), pero `TransactionService.bulkUpdateAccount` reasigna cuenta/`currencyCode` y guarda **sin** `recalculatePreferredCurrency`. Sus gemelos sí lo hacen. El canario `money` no cazaría el desfase porque `currency_code` no está en ese grupo.

Quien recibe ARRANCA EN CONTEXTO LIMPIO.

## Que se pide
1. Leer el ticket y el código citado (`TransactionService.bulkUpdateAccount`, gemelos `bulkUpdateAmount` y `RecordsViewModel.bulkUpdateAccount`, mapa de coherencia).
2. Arreglar: o llamar `recalculatePreferredCurrency` tras reasignar la divisa (como el gemelo), o borrar el método si de verdad no debe existir — elige el mínimo coherente y documenta por qué.
3. Test equivalente al de `bulkUpdateAmount`: mover transacciones a cuenta de OTRA divisa deja las cuatro columnas del grupo `money` coherentes.
4. Barrer el patrón: otras rutas que escriban `currencyCode` o `amount` de una transacción ya persistida sin recalcular derivadas.
5. Board + `docs/TICKETS.md` al día; hallazgos → ticket propio.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen (pregúntale en la sesión; Frank avisa).

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No uses `agent-device`.
- No ensanches el alcance a un refactor masivo de sync.

## Como se sabe que esta bien
- AC del ticket en verde (recalc o borrado justificado + test + barrido del patrón).
- Board e índice al día; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: test rojo a reclasificar, build a reintentar, ni ruido de CI advisory.
