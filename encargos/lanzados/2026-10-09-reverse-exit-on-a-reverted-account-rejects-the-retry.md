**Nota de lanzamiento (2026-10-09 16:0x, frank):** w7w8 ya está desplegada en staging y producción (Worker staging 47b02439-ab1f-4ef6-9604-3b15f4b53675, producción c2b95bd0-43f9-4ff9-9d53-2331b1b3ea1b) y su PR #422 está en auto-merge a 2.1. Antes de tu deploy y de abrir tu PR, rebasa sobre `origin/2.1` con el #422 ya dentro (si aún no mergeó, rebasa sobre `origin/encargo/2026-10-09-settings-migrate-blocks-a-second-device-before-its-marker` y vuelve a rebasar sobre 2.1 al final). Ojo: la sesión de w7w8 encontró que el token de gestión de Supabase da `Invalid access token`; usa el camino del RUNBOOK y, si no tienes cómo aplicar el DDL en staging o producción, para y anótalo en el cierre con el comando exacto. /cerrar-total autónomo al terminar.

# En el segundo dispositivo de una cuenta que ya volvió a iCloud, salir de la espera impide volver a intentar «Volver a iCloud»

**Prioridad:** high
**Ticket:** tickets/backlog/reverse-exit-on-a-reverted-account-rejects-the-retry.md

**Orden:** va DESPUÉS de `w7w8` (`settings-migrate-blocks-a-second-device-before-its-marker`), que también toca el backend de la cuenta. Arranca sobre `origin/2.1` y, antes del deploy y de abrir el PR, rebasa sobre lo que haya entrado de `w7w8` (código y migraciones); si su deploy aún no se hizo en staging/producción, no despliegues encima: espera a que esté hecho o anótalo en el cierre.

## Objetivo

La persona tiene dos o más dispositivos en una cuenta de la nube que ya volvió a iCloud en uno de ellos. En otro de esos
dispositivos puede pulsar «Volver a iCloud», salir de la espera (o perder la respuesta del servidor) y volver a intentarlo,
y el reintento avanza. Hoy recibe «tu cuenta no lo permitía» y su única salida es escribir a soporte.

## Ficheros implicados

- Backend (DDL nuevo en `qa/cloud/`, staging y producción): la función `migration_progress`. Su última versión en el repo es
  `qa/cloud/g15_02_reverse_open_to_born_cloud.sql`. Hay que impedir que el claim fresco de la reversa resetee `reverted_at`
  cuando `kind <> 'complete'`, o que `reverse_abort` restaure el valor previo. La alternativa cierra solo los caminos 2 y 3:
  evaluar reserva, líder y lease antes del guard de `kind`/`reverted_at`.
- `gateway/test/account.goldens.test.ts` (golden 17): el contrato del rechazo `not_complete`.
- Cliente, solo si cambia el contrato: `Yala/Services/CloudSync/MigrationWorkExecutor.swift:1533` (rechazo del claim de la
  reversa), `Yala/Services/CloudSync/CloudSyncEngine.swift:1093`, `Yala/Services/Metrics/MetricsService.swift:683`
  (canario `cloudReverseClaimRejected`).

## Criterio de hecho

- Medido antes de tocar nada: `pg_get_functiondef` de la función viva en staging (en producción ya se midió el 16-sep).
- Una verificación SQL de conducta, al estilo de la de `g15_02` y probada en las dos direcciones, con estos casos:
  (a) cuenta revertida → claim fresco → `reverse_abort` → reintento ⇒ no `not_complete`;
  (b) claim con éxito y respuesta perdida → reintento del mismo líder ⇒ re-claim idempotente;
  (c) tres dispositivos, con B subiendo ⇒ C recibe `other_leader`, no `not_complete`.
- El canario `cloudReverseClaimRejected` con detalle `not_complete` cae a cero en la flota tras desplegar.
- Device-QA con dos iPhone y la misma cuenta: volver a iCloud en el primero; en el segundo, empezar, cancelar y reintentar ⇒ avanza.

## Deploy de backend: AUTORIZADO por Jürgen (2026-10-09 14:01)

Jürgen autorizó el deploy de backend de esta card. Se hace con la mejor práctica, en este orden, y sin saltarse pasos:

1. **Compatibilidad hacia atrás, obligatoria.** La app que ya está instalada (TestFlight y builds anteriores) tiene que seguir funcionando igual con el backend nuevo: solo cambios aditivos (campos nuevos opcionales, funciones que conservan la firma y los códigos de respuesta que la app vieja ya entiende). Fíjalo con un test o golden que use la respuesta tal como la lee la app vieja.
2. **Staging primero.** Migración SQL en el proyecto de Supabase de staging (`fostjbbwstyuunmmefuk`) con el camino del repo (`docs/RUNBOOK-staging-ddl.md`: `apply_migration` del conector de Supabase, o `psql -1 -f qa/cloud/<fichero>.sql "$SUPABASE_DB_URL"`), con su guarda de cuerpo previo (`md5(pg_get_functiondef(...))`) y su rollback escrito al lado. Si cambia el Worker: `cd gateway && npm run deploy:staging`.
3. **Verificación en staging.** La verificación SQL de conducta y los goldens del gateway contra staging, en verde; anota versión del Worker y `md5` de las funciones antes y después.
4. **Producción después.** La misma migración en producción (`kefvaiymtgytemwbltlz`) con la misma guarda, y si aplica `cd gateway && npm run migrate:production` / `npm run deploy:production`. Luego una **prueba de humo** en producción (la llamada mínima que demuestra el cambio y otra que demuestra que el camino viejo sigue igual), sin tocar datos de usuarios reales.
5. Deja el antes → después (md5, versión del Worker, resultado de la prueba de humo) en el ticket y en el `RUNBOOK` que corresponda, y en el PR.

**Si el deploy pide un secreto, una credencial o un login que la sesión no tiene** (Cloudflare, Supabase, Llavero), **para ahí**: no lo busques por otro camino, no pidas que lo peguen. Deja todo listo hasta ese paso y anótalo en «Necesita de ti» del cierre, con el comando exacto que falta correr. Si la sesión crea una clave nueva en el Llavero, dilo en el cierre para pasarla a 1Password.

En esta card el backend es la función SQL `migration_progress` (nuevo fichero en `qa/cloud/`, partiendo de `g15_02_reverse_open_to_born_cloud.sql`). Mide primero `pg_get_functiondef` en staging y en producción. La app vieja no cambia de contrato: los mismos códigos (`not_complete`, `other_leader`, re-claim idempotente) con la conducta corregida.

## Ejecución
- `/cerrar-total` autónomo al terminar (PR a 2.1 con auto-merge, card bien puesta: in qa → jurgen si queda device-QA, done → frank si no; quitar worktree/tmux/DerivedData/cachés de XcodeBuildMCP de este worktree; ningún sim encendido).
- Pipeline serial de la Mini: limpiar sims muertos/DerivedData de sesiones cerradas/cachés de XcodeBuildMCP de worktrees que ya no existen sin preguntar; `xcodebuild -jobs 2` sin sim booteado; boot de 1 solo sim (si hay otro simulador o `xcodebuild` ajeno, no lo toques y espera); tests; apagar y borrar ese sim.
- Rebase al final, sin esperar a nadie: justo antes de abrir su PR, `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí cualquier conflicto (el ruleset de `2.1` tiene strict=false). Si el rebase trajo cambios que tocan lo suyo, vuelve a compilar y a correr los tests afectados.

## Cierre: tickets nuevos al tablero
Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre. Va SIN --fecha (la fecha de las cards es opcional desde el ADR-068; no pongas fecha de relleno).

## Paso 0 (frank, 2026-10-09)

Decisiones resueltas antes de escribir, con su porqué en una frase. Ninguna es de producto: el encargo ya las toma.

1. **Arreglo: el claim de la vuelta conserva `reverted_at` cuando la cuenta no es `complete`.** Es la única de las tres
   opciones del ticket que cierra los tres caminos. Que `reverse_abort` restaure el valor previo exige guardarlo en una
   columna nueva; mover el guard detrás de reserva/líder/lease deja vivo el camino 1 (salir de la espera).
2. **Se transforma el cuerpo vivo, no se re-pega** (disciplina de `g15_01`/`g15_02`): el cuerpo entero no está en el repo.
   Cada `reverted_at = null` pasa a `reverted_at = case when kind = 'complete' then null else reverted_at end`. Donde la
   cuenta es `complete` (golden 17, takeover de una ida abandonada, que siempre es `complete`) el resultado es idéntico al de
   hoy; solo cambia en una cuenta `groups_only`, que es la que ya volvió a iCloud.
3. **Guarda de partida exacta sin conocer el md5 final**: virgen = `14fc5e2c…` (medido en producción el 16-sep); aplicado =
   «deshacer la sustitución devuelve exactamente `14fc5e2c…`». Cualquier otro cuerpo aborta.
4. **Contrato de la app instalada: sin cambios.** Mismos códigos (`not_complete`, `other_leader`, `migration_in_progress`,
   re-claim idempotente), misma firma, mismos campos. El cliente no se toca. Los comentarios de Swift que describen el
   reset (`MigrationStateMachine.swift`, el residual del claim) siguen siendo ciertos hasta el deploy: se corrigen tras él.
5. **Acceso medido al empezar:** el token de gestión de `~/Secrets/yala-supabase-mgmt/pat` da 401 en staging y en
   producción; el conector de Supabase de esta sesión pide OAuth (no autenticado); no hay URI de base en `~/Secrets`.
   ⇒ según el encargo, se para en el deploy: todo listo y el comando exacto en «Necesita de ti». No se busca otra vía.
6. **Verificación sin base remota**: banco local en Postgres 17 con una réplica de `migration_progress` escrita desde el
   contrato del README (§Reversa) y la guarda adaptada a su md5. Corre la conducta en las dos direcciones (rojo con el cuerpo
   viejo, verde con el nuevo), el rollback (vuelve al md5 virgen) y la re-aplicación (no-op). La prueba real es el §3 del
   fichero, que corre dentro de la propia migración en staging y en producción y aborta si falla.
7. **Ticket a `blocked`** con el motivo (el deploy espera una credencial) y el guion de device-QA dentro; la card a Jürgen.
