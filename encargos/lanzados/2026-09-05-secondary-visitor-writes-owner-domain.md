# Cerrar secondary-visitor-writes-owner-domain

## Contexto
Cola nocturna autónoma. Esta noche ya mergearon a `2.1`: #63 rejoin-tap, #64 group-joiner, #65 invite-link. Nada más está corriendo; retomamos la cola.

`docs/ESTADO.md` (2026-09-05): este ticket + `secondary-guest-exit-lock-and-outbox` son bloqueantes del encendido de SECONDARY_SESSION (hoy 0 % en prod). Decisiones del 3-sep tomadas; **el código aprobado no está escrito**.

Ticket: `tickets/in-progress/secondary-visitor-writes-owner-domain.md`. Coordenadas caducadas: grepea. Hay tickets relacionados ya en QA (`prefs-domain-per-secondary-session`, `secondary-groups-off-wipes-owner`) — léelos para no duplicar ni contradecir.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando (1) te bloquees esperando a Jürgen, (2) dejes listo PR / artifact, o (3) falle build / CI. No avises al cerrar (`/cerrar`).

## Qué se pide
MODO AUTÓNOMO HASTA TERMINAR. No preguntes si correr el gate, si hacer commit, si actualizar docs/board, si mergear ni si cerrar. Flujo completo:

1. Lee el ticket + decisiones del 3-sep relevantes (DECISIONS / ticket body) y mide el código actual.
2. Implementa el arreglo mínimo aprobado: la visita secundaria no debe escribir en el dominio del dueño (las seis vías del ticket, o las que sigan vivas tras grepear).
3. No mezcles en este PR el ticket hermano `secondary-guest-exit-lock-and-outbox` salvo un cambio imprescindible compartido; si encuentras solape, documenta y deja ese ticket para la siguiente sesión.
4. Tests / gate: corre el gate, clasifica rojos (tuyos / preexistentes / entorno / UI advisory ya documentados en 2.1) y arréglalos o demuéstralos; no pares a preguntar.
5. Commit(s), board/`docs/ESTADO.md`, PR desde worktree.
6. CI verde (o criterio del repo) → merge a `2.1`.
7. `/cerrar` obligatorio al final.

Bugs nuevos → `tickets/backlog/` y sigue. Solo párate ante decisión/acceso real; documenta, webhook a Frank, mergea lo documentado, salta lo bloqueado.

## Qué NO hay que tocar
- `marketing/` (Lola).
- No flip de `SECONDARY_SESSION_ROLLOUT_PERCENT` / HOLD store/tag/A7/M5.
- Secrets, `.env*`.
- No inventes PASS ni cierres sin evidencia.
- No abras secciones nuevas de docs de estructura sin pedirlo el ticket.

## Como se sabe que está bien
- Las vías que escriben en el dominio del dueño desde secundaria están cerradas o residual documentado con ticket.
- Ticket en board coherente; PR mergeado (o bloqueo documentado).
- `/cerrar` ejecutado.
