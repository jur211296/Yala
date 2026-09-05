# Arreglar rejoin-tap-renotifies-admins (fan-out de join_group)

## Contexto
Cola nocturna autónoma (Jürgen duerme, 2026-09-04). Acaba de aterrizar en `2.1` el fix de equal-split (`a44ac80` + docs). `docs/ESTADO.md` pone este ticket primero entre los abiertos: vivo en producción, ruido al admin cada vez que alguien pendiente vuelve a tocar su enlace.

Ticket: `tickets/backlog/rejoin-tap-renotifies-admins.md`. El guardián en `gateway/src/groups/rpc.ts` deja pasar `pendingApproval` sin distinguir transición real vs re-tap no-op; el RPC «ya-member» no reporta `changed`. Arreglo esperado: migración SQL (+campo `changed` o equivalente) + gate en el Worker + verificar en staging antes de producción.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando (1) te bloquees esperando a Jürgen, (2) dejes listo PR / artifact, o (3) falle build / CI. No avises al cerrar (`/cerrar`).

## Qué se pide
MODO AUTÓNOMO HASTA TERMINAR. No preguntes si correr el gate, si hacer commit, si actualizar docs/board, si mergear ni si cerrar. Ejecuta el flujo completo de punta a punta:

1. Lee el ticket y mide el código actual (coordenadas del ticket pueden estar caducadas: grepea).
2. Implementa el arreglo mínimo (RPC dice transición real; fan-out se gatea con eso; no mezclar con tickets de cliente).
3. Verifica en staging lo que el ticket pide; si falta acceso a staging/prod, documenta en el ticket + `docs/ESTADO.md`, mergea esa documentación, salta el cambio bloqueado y cierra.
4. Tests / gate locales: corre el gate, clasifica rojos (tuyos / preexistentes / entorno) y arréglalos o demuéstralos; no pares a preguntar.
5. Commit(s) claros, actualiza ticket (status/board), `docs/ESTADO.md` / índice si toca, abre PR desde el worktree.
6. Cuando CI esté verde (o el criterio del repo lo permita), mergea a `2.1`.
7. Ejecuta `/cerrar` al final — obligatorio: limpia disco, sincroniza documentación y board.

Si encuentras bugs nuevos de camino: crea tickets en `tickets/backlog/` y sigue. Solo párate si hay una decisión de producto/acceso real que Jürgen deba tomar; entonces documenta, webhook a Frank, y deja el ticket en estado coherente.

## Qué NO hay que tocar
- `marketing/` (Lola).
- App iOS salvo lo imprescindible para consumir un campo nuevo del RPC (preferible cero cliente si el gate basta en Worker).
- No mezclar con `rejected-member-cold-tap-does-nothing` ni otros tickets.
- Secrets, `.env*`, credenciales.
- No inventes PASS ni cierres tickets sin evidencia.
- HOLD de release (store/tag/A7/M5): no flip.

## Como se sabe que está bien
- El re-tap de un miembro ya `pendingApproval` no vuelve a fan-outear push al admin (medido en staging o demostrado en código+test).
- Migración + Worker desplegados o, si el acceso bloquea, documentado en ticket+ESTADO y mergeado sin el cambio bloqueado.
- Ticket movido de board con status coherente; PR mergeado (o documentado el bloqueo).
- `/cerrar` ejecutado.
