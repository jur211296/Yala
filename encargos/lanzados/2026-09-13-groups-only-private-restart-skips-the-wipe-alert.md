# Implementar ticket: groups-only-private-restart-skips-the-wipe-alert

## Contexto
Cola autónoma bypass (Jürgen 2026-09-13). Siguiente tras cerrar #152 (groups-killswitch-403 → qa).
Desde una sesión solo-grupos, «Primera vez → privado» se salta el aviso de datos existentes.

MODO AUTÓNOMO HASTA TERMINAR: review adversarial si toca sync/onboarding/wipe, gate, commit, board, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket `--solo-crear`; si es high que deba adelantarse, anótalo en el cierre. Ambigüedad NUEVA: lo más seguro (no borrar datos sin aviso). Device-QA → `tickets/qa/`.

Avisos a Frank (webhook Mini): (1) bloqueo acceso/decisión Jürgen; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle — una vez. No avisar por test/build a reintentar ni CI advisory.

No lances el siguiente: Frank encadena. No marketing/.

## Que se pide
1. Leer el ticket y medir el camino «sesión solo-grupos → Primera vez → privado».
2. Que el aviso de wipe/datos existentes salga cuando corresponde; no saltárselo.
3. Tests del camino; PR a `2.1`; board/`TICKETS.md`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Wipe de prod. El ticket hermano `groups-sync-treats-an-infra-403-as-an-account-verdict` (Frank decide si lo adelanta).

## Como se sabe que esta bien
Desde solo-grupos, «Primera vez → privado» muestra el aviso de datos; tests verdes; PR mergeado; `/cerrar-total`.
