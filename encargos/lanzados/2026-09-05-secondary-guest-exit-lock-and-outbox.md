# Cerrar secondary-guest-exit-lock-and-outbox

## Contexto
Cola diaria autónoma (mismo marco que la noche). Acaba de cerrar `secondary-visitor-writes-owner-domain` (PR #66 mergeado a 2.1). Siguiente por prioridad del ESTADO: este ticket; después `reentry-counts-as-fresh-install`.

`docs/ESTADO.md` (2026-09-05): este ticket es el otro bloqueante del encendido de SECONDARY_SESSION (hoy 0 % en prod). Decisión del owner 2026-09-03 tomada (pieza 3: banner propio al salir con cambios pendientes — esperar o salir igual). Pieza 1 (empujar los dos outboxes en secundaria) ya tuvo implementación parcial el 12-ago — **re-medir** antes de asumir qué falta. Pieza 2 (clasificar bloqueo en vez de siempre «revisa tu conexión») sigue pendiente de código.

Ticket: `tickets/in-progress/secondary-guest-exit-lock-and-outbox.md`. Coordenadas caducadas: grepea. Hermano recién a QA: `secondary-visitor-writes-owner-domain` (y relacionados en QA). Comparte superficie con `SwiftDataConfiguration.swift` / sign-out; no pises el trabajo ya mergeado del hermano.

Secrets.xcconfig / secrets gitignored viven en el árbol principal (`~/Yala`), no en el worktree — enlázalos antes del primer build.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Qué se pide
MODO AUTÓNOMO HASTA TERMINAR. No preguntes si correr el gate, si hacer commit, si actualizar docs/board, si mergear ni si cerrar. Flujo completo:

1. Lee el ticket + decisión del 3-sep (banner propio) y mide el código actual (qué quedó de la pieza 1 del 12-ago; qué falta de 2 y 3).
2. Implementa el arreglo mínimo aprobado: en salida de visita secundaria, empujar outbox de grupos (si aún no), clasificar el bloqueo (no siempre `.permanent` / «revisa tu conexión»), y el aviso propio de cambios pendientes con esperar o salir igual.
3. No mezcles en este PR `reentry-counts-as-fresh-install` ni reabras el hermano visitor salvo un cambio imprescindible compartido; si hay solape, documenta y deja el otro ticket.
4. Tests / gate: corre el gate, clasifica rojos (tuyos / preexistentes / entorno / UI advisory ya documentados en 2.1 — no bloquees merge por el patrón flaky advisory) y arréglalos o demuéstralos; no pares a preguntar.
5. Commit(s), board (ticket a qa/ cuando toque). No reescribas `docs/ESTADO.md` desde el worktree (ADR-008); el parte va en el PR.
6. CI (criterio del repo; UI tests advisory) → merge a `2.1`.
7. `/cerrar` obligatorio al final.

Bugs nuevos → `tickets/backlog/` y sigue. Solo párate ante decisión/acceso real; documenta, webhook a Frank, mergea lo documentado, salta lo bloqueado.

## Qué NO hay que tocar
- `marketing/` (Lola).
- No flip de `SECONDARY_SESSION_ROLLOUT_PERCENT` / HOLD store/tag/A7/M5.
- Secrets, `.env*` (solo enlazar Secrets.xcconfig desde el árbol principal).
- No inventes PASS ni cierres sin evidencia.
- No abras secciones nuevas de docs de estructura sin pedirlo el ticket.
- clinicas-dentales-bi.

## Como se sabe que está bien
- Al salir de una sesión de visita, los gastos de grupo pendientes se empujan (o el aviso propio deja elegir esperar / salir) — no se pierden en silencio por el wipe.
- Un bloqueo transitorio ya no se presenta siempre como «revisa tu conexión» permanente sin «un momento más».
- Gate verde o rojos clasificados con evidencia; PR mergeado a 2.1; ticket reflejado; `/cerrar` con resumen de usuario.
