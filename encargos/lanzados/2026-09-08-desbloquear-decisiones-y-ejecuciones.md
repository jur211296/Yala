# Sesión de desbloqueo: decisiones de producto + runbook de ejecuciones + hygiene del board

## Contexto
Jürgen (2026-09-08): cola autónoma en PAUSA. Quiere una sentada de desbloqueo antes de reactivar. Frank lanza esto en bypass / opus max (default del comando).

**Fuera de alcance de esta sesión (explícito):** Device-QA en teléfono (lo hace Jürgen luego, aparte). No implementar features de producto salvo lo que sea hygiene/docs/board + dejar decisiones escritas.

## Que se pide

### A · Decisiones de producto (NO decidas tú — prepara y pregunta)
Para cada una: 1) una página clara (problema en lenguaje de usuario, opciones, recomendación tuya con motivo, AC si elige X). 2) Avisa a Frank por webhook forma (1) decisión Jürgen con el resumen accionable. 3) Cuando Jürgen conteste vía Frank/`decirle`, escribe la decisión en el ticket y en docs si aplica. 4) NO implementes el código de producto en esta sesión salvo que Jürgen diga «implementa ya» en la misma respuesta.

Tickets:
1. `tickets/backlog/groups-owner-debt-no-heir-dead-end.md` — salidas (a)–(d) ya listadas; necesita elección.
2. `tickets/backlog/groups-settlement-reminder-discoverability.md` — feature hecho, casi nadie lo recibe (toggle + avisos Grupos + primer notificaciones).
3. `tickets/backlog/approximate-mark-ors-over-whole-period.md` — umbral del «≈» (cualquier tx / fracción / por divisa como FXPnL).
4. `tickets/backlog/cobertura-ui-diaria-cuelga-del-push.md` — launchd en Mini vs aceptar hueco (sin prisa; igual dejarla decidida).
5. `tickets/backlog/dmarc-sube-la-politica-tras-observar.md` — NO subir política ahora; confirmar fecha ≥15-sep y dejar el ticket con plan/fecha (observación sigue).

Puedes agrupar las preguntas en uno o dos avisos a Frank para no bombardear; lo importante es que Jürgen pueda contestar sin abrir la ventana.

### B · Ejecuciones de Jürgen (runbook, no las hagas tú)
Preparar/actualizar un runbook claro (docs o ticket) para staging DDL, en orden:
`qa/cloud/g13_04_join_group_reports_transition.sql` → `g13_05_join_group_rejects_archived.sql` → `g14_01_group_budget_limit.sql`
Incluir: dónde está el SQL, orden, qué verificar después, y que **hace falta su credencial DDL** (tú no la tienes). Worker Merkle / canon_version: solo anotar estado si sigue pendiente; no desplegar sin acceso.

### C · Hygiene del board (sí, hazlo)
- `groups-budget` sigue en `tickets/in-progress/` con status in-progress pese a PR #91 mergeado → mover a `qa/` (o `done` si el ticket ya no pide device) alineando frontmatter + `docs/TICKETS.md`.
- Revisar índice = disco (conteos).
- Encargos huérfanos en el árbol principal (`?? encargos/lanzados/…groups-budget`, `?? encargos/pendientes/`): si son basura post-merge, proponer limpieza en el aviso o limpiar solo lo que sea claramente del proceso de encargos y no trabajo de Jürgen.

### D · Salida de la sesión
Al terminar (decisiones escritas o esperando respuestas, runbook DDL listo, hygiene hecha): `/cerrar-total` con resumen en lenguaje de usuario. Si aún faltan respuestas de Jürgen, avisa una vez qué queda pendiente y cierra igual dejando el board honesto (tickets en backlog con decisión parcial anotada).

## MODO AUTÓNOMO HASTA TERMINAR
Gate/docs/board/`docs/TICKETS.md`/commit/merge/`/cerrar-total` sin preguntar por gate o commit. **Sí debes parar y avisar** ante decisión/acceso real de Jürgen (bloque A y B). Bugs nuevos → ticket propio.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No lanzar ni implementar `chat-draft-drops-the-expense-sign` ni reactivar la cola medium (eso lo hace Frank después).
- No Device-QA en dispositivos.
- No subir DMARC a quarantine/reject en esta sesión.

## Como se sabe que esta bien
- Las 4–5 decisiones tienen opción elegida escrita **o** pregunta clara ya avisada a Frank.
- Runbook DDL staging listo para que Jürgen ejecute.
- `groups-budget` ya no está mentiroso en in-progress; índice al día.
- `/cerrar-total` hecho.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen — **prioridad de esta sesión**;
  (2) PR abierto;
  (3) /cerrar-total con resumen de usuario;
  (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
