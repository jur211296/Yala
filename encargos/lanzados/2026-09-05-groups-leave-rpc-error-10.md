# Salir del grupo: error crudo «GroupsRPCError 10» y mensaje usable

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, merge a 2.1 y /cerrar-total sin preguntar. Solo parar ante decisión/acceso real de Jürgen.

## Contexto
Ticket: `tickets/backlog/groups-leave-rpc-error-10.md` (high). Device QA TF 2.1 build 12: en teléfono B salir del grupo falló con alert «No se ha podido completar la operación. (Error de Yala.GroupsRPCError 10.)» — número crudo, sin copy, sin acción. En A sí salió.

Medido en el ticket (re-medir; coords pueden estar caducadas): el alert usa `error.localizedDescription`; `GroupsRPCError` no conforma `LocalizedError`; el caso #10 en orden de declaración es **`channelDisabled`** (403 `yala_groups_disabled`, kill-switch del canal) — no confundir con `ownerCannotLeave` (eso sería otra frase).

Cola nocturna Jürgen 2026-09-05: bypass; Unirme (#74) ya mergeado. No tocar pending-member ni kill-switch de producto salvo lo mínimo para mensajes de error honestos.

Rama nace desde origin/2.1 (Casa #10). Secrets.xcconfig en worktree-enlaces.

## Que se pide
1. Re-medir el enum y el camino `leaveGroup()` / alert en HEAD actual.
2. Dar a `GroupsRPCError` (y el alert de salir) copy humano: qué pasó, si sirve reintentar, sin números de discriminante. Especial cuidado con `channelDisabled` vs `ownerCannotLeave` vs transients.
3. Si al medir el fallo de device es solo copy + mapping: arreglar eso. Si hay un bug de leave real reproducible en código (más allá del kill-switch), fíjalo con alcance mínimo y anótalo.
4. No flippear SECONDARY_SESSION / kill-switch de prod. Si el 10 es canal apagado, el usuario debe entenderlo — no «arreglar» apagando el kill.
5. Tests; ticket → qa/board; PR a 2.1; merge cuando gate verde (UI advisory: contrastar base 2.1); /cerrar-total.

## Que NO hay que tocar
- marketing/
- groups-pending-member-can-open-group
- reentry-killswitch-closes-both-doors (decisión producto)
- groups-tab-missing-panel-perf (siguiente, no mezclar)
- No inventar causa del device más allá de lo medido

## Como se sabe que esta bien
- Salir del grupo ya no muestra «GroupsRPCError N»; mensaje claro.
- Gate verde; PR mergeado; /cerrar-total con resumen en lenguaje de usuario.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) decisión de producto/acceso; (2) PR o preview listo; (3) terminaste y /cerrar-total — resumen de qué se hizo; (4) idle mid-ticket una vez. NO avises por test rojo a reclasificar, build a reintentar, ni ruido de setup cp/cd. URL/key solo en la Mini.
