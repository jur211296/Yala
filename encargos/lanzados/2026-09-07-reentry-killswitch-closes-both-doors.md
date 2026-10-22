# Kill-switch: mensaje honesto + motor en sesión en la re-entrada

## Contexto
Ticket: `tickets/backlog/reentry-killswitch-closes-both-doors.md`. Residual de `reentry-counts-as-fresh-install`.

**Decisión Jürgen (2026-09-06) — no repreguntar:**
1. Bajo el kill, las DOS puertas cerradas es lo deseado; corregir comentario + mensaje Welcome («nube en pausa», no «No encontramos tus datos»).
2. Motor arranca en sesión también en la re-entrada (como el alta); sin «reinicia Yala».
3. Docblock MigrationWorkExecutor: solo si tocas ese fichero.

Cola medium autónoma (Frank): tras /cerrar-total → features (settlement/summary/budget/fx-card) → CI timeout.

## Que se pide
AC del ticket; review adversarial antes del gate (arranque motor sync); copy 16 `.lproj`; board + `docs/TICKETS.md`. Device-QA documentado (kill se conmuta desde backend).

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No reabrir la puerta de Ajustes bajo el kill.
- No inventar otra semántica del kill.

## Como se sabe que esta bien
- AC (salvo device-QA en qa); review adversarial; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
