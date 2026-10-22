# Aplicar g16_01 en staging para que Yala Dev deje de mostrar el bug del reintento

## Paso 0

Decisiones tomadas y lo que asumí, sin nadie delante:

- **Por dónde entrar:** con el conector MCP, midiéndolo primero. Entró a la primera, así que no hizo falta
  backoff ni aparcar el ticket.
- **Qué aplicar:** el fichero entero, sin recortar la cabecera. El md5 de llegada lo confirma: los comentarios
  no entran en el cuerpo de la función.
- **Cómo preparar los goldens (asumido):** borrar las filas de `profiles` de A, B y C con el `delete`
  documentado. El 1 y el 28 lo exigen. Medí antes que ninguna FK apunta a `profiles`, así que el contador
  que usa g3_02 no se toca.
- **El rojo del golden 20:** no lo arreglo. Es el timeout que ya lleva
  `account-goldens-freeze-read-test-times-out`, fuera de este encargo.
- **La nota caducada del README** («el usuario C no existe»): la corrijo, porque es la receta que acabo de
  seguir y contradice lo que medí.

## Contexto
Cola A autónoma (noche Lima ~04:00). Acaba de mergear a `2.1` el PR #232 (`claim-promotion-lost-response-blocks-the-retry`): si se pierde la respuesta al activar la nube, «Reintentar» termina la activación. La rama SQL `qa/cloud/g16_01_claim_replays_for_the_same_device.sql` ya está **aplicada en producción** (md5 de llegada `e7f8bec957091abaa126d8100a3a53bd`). Staging (`fostjbbwstyuunmmefuk`) quedó pendiente porque el conector MCP hizo timeout toda la sesión — con `Yala Dev` el bug viejo sigue visible y un device-QA lo tomaría por regresión.

Ticket: `tickets/backlog/g16-01-is-not-applied-on-staging.md` (medium, modo-nube/backend). Quién arranca lo hace en contexto limpio — lee el ticket y el SQL citado.

NO entran en este encargo los residuales de la review del #232 (`claim-replay-can-seed-beside-a-phone-that-adopted-silently` medium, y los tres low). Eso es cola posterior.

## Que se pide
1. Medir acceso al conector staging al empezar (mapa de acceso cambia: `list_projects` + `select current_user` / md5 de `claim_account`). No heredar el timeout del cierre anterior como hecho.
2. Comprobar el md5 de partida de `claim_account` en staging: tiene que ser `8668a13c3d452fd5f192a192dd415bbd` (el que exige el §0 del SQL).
3. Aplicar el fichero tal cual con `apply_migration` (`qa/cloud/g16_01_claim_replays_for_the_same_device.sql`). Su §0 exige ese md5 y su §3 aborta si la conducta falla — es seguro reintentarlo. Si el MCP vuelve a cortar: reintenta con backoff; si sigue muerto tras varios intentos medidos, deja el ticket en backlog/blocked con lo medido (REST vs MCP), avisa por webhook una vez, y `/cerrar-total` sin inventar un bypass.
4. Verificar: `claim_account` de staging tiene la rama g16_01 (el §2 del SQL lo imprime) y goldens del claim contra staging (`gateway/test/account.goldens.test.ts`, receta en `qa/cloud/README.md`) — criterios del ticket: goldens 1, g3_02 y 28 en verde contra staging. El 28 pide el usuario C sin fila en `profiles` (el `delete` está en su comentario).
5. Mueve el ticket a `done` (o déjalo documentado si staging sigue inaccesible), actualiza `docs/TICKETS.md` / ESTADO, merge si hubo cambio de docs en worktree, `/cerrar-total`.

## Que NO hay que tocar
- marketing/, Web/
- Producción (ya tiene g16_01)
- El Worker / firma del RPC / cliente iOS
- Los residuales medium/low del #232 (claim-replay-*, lost-cloud-signup-*, welcome-cloud-replay-*)
- Device-QA de tickets en `qa/`
- No inventar un applier alternativo ni pegar SQL a mano fuera de `apply_migration` salvo que el runbook medido del día lo exija y lo anotes

## Como se sabe que esta bien
- Staging `claim_account` tiene la rama g16_01 (md5/§2 del SQL).
- Goldens 1, g3_02 y 28 verdes contra staging (o skip documentado con causa ajena ya ticketada, no silencio).
- Ticket y `docs/TICKETS.md` al día; `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate (si tocas código/docs del repo), commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen (secretos/device). Board: create/move directo.

Override Jürgen 2026-09-22: la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA — implementa hasta el cierre sin pedir continuar.

Noche (04:00 Lima): elige la opción recomendada / más robusta sin AskUserQuestion; si es demasiado importante para asumirla, aparca en ticket propio.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: test rojo que vas a reclasificar, build a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.
