# Un grupo archivado no acepta miembros nuevos (hacer verdad el copy)

## Contexto
Ticket: `tickets/backlog/groups-archived-group-rejects-join.md` (medium). Hoy `join_group` no mira `is_archived` y deja unirse; la app ya tiene copy `groups.reconnect.archived.*` (16 idiomas) que promete lo contrario.

**Decisión Jürgen (2026-09-06) — no repreguntar:** se hace verdad el comportamiento (archivado no acepta nuevos), no se reescribe el texto.

Cola medium autónoma (Frank): tras /cerrar-total de este, el siguiente es fx-presentation / hero / welcome-privacy / panel-cuentas / reentry-killswitch / features — Frank lanza el siguiente; tú cierra este del todo.

## Que se pide
Implementar el AC del ticket:
- `join_group` rechaza si archivado, error propio, staging + prod + test RPC.
- Cliente mapea a `groups.reconnect.archived.*` como estado, no error crudo.
- Miembros ya dentro no afectados; desarchivar reabre entrada.
- Device-QA documentado (enlace desde 2º teléfono) — si no hay device, deja el AC marcado y el ticket en qa.
- Board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No reescribir el copy para permitir entrada a archivados.
- No inventar otra semántica de «archivado».

## Como se sabe que esta bien
- AC cumplidos (salvo device-QA explícito en qa).
- PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando:
  (1) decisión de producto o acceso de Jürgen;
  (2) PR abierto / preview listo;
  (3) vas a /cerrar-total — resumen corto en lenguaje de usuario;
  (4) sin siguiente paso claro — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
