# Arreglar group-joiner-flag-consumers-still-narrow

## Contexto
Cola nocturna autónoma (Jürgen duerme). Acaba de mergear el PR #63 (`rejoin-tap-renotifies-admins`) a `2.1` y cerrar esa sesión. `docs/ESTADO.md` pone este ticket como high: al recién llegado ya se le reconoce, pero su gasto no llega a su cuenta personal hasta un arranque posterior y aterriza en la cuenta «Grupos». Trece consumidores del flag siguen estrechos.

Ticket: `tickets/backlog/group-joiner-flag-consumers-still-narrow.md`. Coordenadas pueden estar caducadas: grepea, no abras la línea citada.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando (1) te bloquees esperando a Jürgen, (2) dejes listo PR / artifact, o (3) falle build / CI. No avises al cerrar (`/cerrar`).

## Qué se pide
MODO AUTÓNOMO HASTA TERMINAR. No preguntes si correr el gate, si hacer commit, si actualizar docs/board, si mergear ni si cerrar. Ejecuta el flujo completo de punta a punta:

1. Lee el ticket y mide el código actual (greppea; coords pueden estar viejas).
2. Implementa el arreglo mínimo: los consumidores del flag del joiner que siguen estrechos, para que el gasto del recién llegado llegue a su cuenta personal sin necesitar un arranque posterior ni caer en «Grupos».
3. Tests / gate locales: corre el gate, clasifica rojos (tuyos / preexistentes / entorno) y arréglalos o demuéstralos; no pares a preguntar.
4. Commit(s) claros, actualiza ticket (status/board), `docs/ESTADO.md` / índice si toca, abre PR desde el worktree.
5. Cuando CI esté verde (o el criterio del repo lo permita), mergea a `2.1`.
6. Ejecuta `/cerrar` al final — obligatorio: limpia disco, sincroniza documentación y board.

Si encuentras bugs nuevos de camino: crea tickets en `tickets/backlog/` y sigue. Solo párate si hay una decisión de producto/acceso real que Jürgen deba tomar; entonces documenta, webhook a Frank, y deja el ticket en estado coherente. Si el acceso bloquea un pedazo, documenta en ticket+ESTADO, mergea eso, salta el cambio bloqueado y cierra.

## Qué NO hay que tocar
- `marketing/` (Lola).
- No mezclar con otros tickets (invite-link, secondary-*, rejoin ya cerrado).
- Secrets, `.env*`, credenciales.
- No inventes PASS ni cierres tickets sin evidencia.
- HOLD de release (store/tag/A7/M5): no flip.
- No abras secciones nuevas en docs de estructura (p. ej. aprendizajes-tecnicos) salvo que el ticket lo pida.

## Como se sabe que está bien
- El gasto del joiner llega a su cuenta personal sin relanzar la app (medido con test o demostración en código).
- Consumidores del flag alineados o documentado el residual con ticket.
- Ticket en board coherente; PR mergeado (o bloqueo documentado y mergeado).
- `/cerrar` ejecutado.
