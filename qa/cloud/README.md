# qa/cloud — Modo Nube backend contract checks (I5)

<!-- INDICE:inicio — generado por scripts/indexar_doc.py, no editar a mano -->

## Índice (28 entradas)

> **No hace falta leer este fichero entero** — son 113 KB. Localiza la entrada
> aquí y salta a ella.

- `—` [Running the RLS gate](#running-the-rls-gate)
- `—` [Goldens de I7a (Worker `/account/*` contra staging)](#goldens-de-i7a-worker-account-contra-staging)
- `—` [IdentityRemap (§b.4, DIFERIDOS #29) — traducción client-side, op first-class diferido a v2](#identityremap-b4-diferidos-29--traduccin-client-side-op-first-class-diferido-a-v2)
- `—` [Reversa server-side (I11-3, §h) — columnas `reverse_*` + acciones del RPC](#reversa-server-side-i11-3-h--columnas-reverse--acciones-del-rpc)
- `—` [Heartbeat del lease (I14-pre) — acción `heartbeat` del RPC `migration_progress`](#heartbeat-del-lease-i14-pre--accin-heartbeat-del-rpc-migrationprogress)
- `—` [delete_personal_account (G5-D1) — borrado GDPR del corpus personal + verificación WIRE one-shot](#deletepersonalaccount-g5-d1--borrado-gdpr-del-corpus-personal--verificacin-wire-one-shot)
- `—` [g12_01 — delete_personal_account TAMBIÉN borra `auth.users` (gate §12, Bloque B2)](#g1201--deletepersonalaccount-tambin-borra-authusers-gate-12-bloque-b2)
- `—` [g12_02 — lockdown EXECUTE de `stamp_group_seq` (higiene advisor, molde i5_11) — APLICADA EN AMBOS EN](#g1202--lockdown-execute-de-stampgroupseq-higiene-advisor-molde-i511--aplicada-en-ambos-envs)
- `—` [G8-1 — APNs server-side: registro de tokens + fan-out de silent push](#g8-1--apns-server-side-registro-de-tokens--fan-out-de-silent-push)
- `—` [G8-3 — credencial de máquina `yala_push` (supersede el modelo de amenaza de G8-1)](#g8-3--credencial-de-mquina-yalapush-supersede-el-modelo-de-amenaza-de-g8-1)
- `—` [B1 (gate §12) — SIWA revoke 5.1.1(v): canje + revocación del refresh token de Apple](#b1-gate-12--siwa-revoke-511v-canje--revocacin-del-refresh-token-de-apple)
- `—` [Google revoke (sesión 3 Google Sign-In) — `disconnect()` del grant OAuth al borrar la cuenta](#google-revoke-sesin-3-google-sign-in--disconnect-del-grant-oauth-al-borrar-la-cuenta)
- `—` [Related repo artifacts](#related-repo-artifacts)
- `—` [Remote-config `GET /config` (DIFERIDOS #34 — kill-switch sin release, §j.1/§j.2)](#remote-config-get-config-diferidos-34--kill-switch-sin-release-j1j2)
- `—` [Vaciar (wipe masivo por filas) — caracterización del drain en `.cloud`](#vaciar-wipe-masivo-por-filas--caracterizacin-del-drain-en-cloud)
- `—` [Goldens de I6 (Worker `/sync/*` contra staging)](#goldens-de-i6-worker-sync-contra-staging)
- `—` [migrate_group (G6-1) — migración de grupos VIVOS de CloudKit al backend (§9 D7)](#migrategroup-g6-1--migracin-de-grupos-vivos-de-cloudkit-al-backend-9-d7)
- `—` [Sender e2e de I8e (`SyncPushClient` `/sync/push` contra staging)](#sender-e2e-de-i8e-syncpushclient-syncpush-contra-staging)
- `—` [I14 — UI real de migración + consent + claimAction + relaunch asistido + encendido de flags](#i14--ui-real-de-migracin--consent--claimaction--relaunch-asistido--encendido-de-flags)
- `—` [transfer_group_ownership (G10 / D10) — batch "salir de todos mis grupos" — APLICADA EN AMBOS ENVS ✅](#transfergroupownership-g10--d10--batch-salir-de-todos-mis-grupos--aplicada-en-ambos-envs)
- `—` [G7 — cifrado pgcrypto de columnas † de grupos (data-at-rest)](#g7--cifrado-pgcrypto-de-columnas--de-grupos-data-at-rest)
- `2026-07-28` [Addendum 2026-07-28 — `migrate_group` queda INERTE (Fase 1 de simplificación de Grupos)](#addendum-2026-07-28--migrategroup-queda-inerte-fase-1-de-simplificacin-de-grupos)
- `2026-07-17` [Telemetría propia `POST /metrics` (2026-07-17 — sustituye TelemetryDeck)](#telemetra-propia-post-metrics-2026-07-17--sustituye-telemetrydeck)
- `2026-07-16` [Google Sign-In (sesión 1 — brief `docs/modo-nube/briefs/BRIEF-GOOGLE-SIGNIN-V1.md`, 2026-07-16)](#google-sign-in-sesin-1--brief-docsmodo-nubebriefsbrief-google-signin-v1md-2026-07-16)
- `2026-07-11` [Entidades de SISTEMA — política v1 de merge determinista (residual NOTA-2 de I12-B, 2026-07-11)](#entidades-de-sistema--poltica-v1-de-merge-determinista-residual-nota-2-de-i12-b-2026-07-11)
- `2026-07-11` [Huérfano cross-device del cutover (DIFERIDOS #30) — adopt-reconcile v1 (DARK, 2026-07-11)](#hurfano-cross-device-del-cutover-diferidos-30--adopt-reconcile-v1-dark-2026-07-11)
- `2026-07-11` [Hallazgos de la corrida device de la reversa (2026-07-11): cierres pre-flags](#hallazgos-de-la-corrida-device-de-la-reversa-2026-07-11-cierres-pre-flags)
- `2026-07-11` [Proyecto Supabase de PRODUCCIÓN (DIFERIDOS #23 — creado 2026-07-11)](#proyecto-supabase-de-produccin-diferidos-23--creado-2026-07-11)

<!-- INDICE:fin -->

Scripts that validate the Supabase **staging** schema (`fostjbbwstyuunmmefuk`). They need network +
the two seeded test users, so they do **NOT** run in CI — run them by hand after any `i5_*` migration.

| File | What it does |
|------|--------------|
| `cross-user-rls-test.sh` | The cross-user RLS gate (§2.3). For each of the **18** tenant tables (16 domain + `user_preferences` + `attest_keys`; the `spike_*` tables are excluded — documented references without RLS), verifies with two user JWTs (never `service_role`): A can insert its own row; B cannot SELECT/UPDATE it; B cannot INSERT with `user_id = A` (WITH CHECK); DELETE is rejected even for A (REVOKE — tombstone = `UPDATE deleted=true`). Prints per-table PASS/FAIL and an overall `N/18`. |
| `dump-schema.sh` | Documents how to regenerate/verify `supabase-staging.ddl` (repo root) from the live schema (needs `SUPABASE_DB_URL` + `pg_dump`/psql). The committed `.ddl` is the offline mold. |

## Running the RLS gate

```bash
bash qa/cloud/cross-user-rls-test.sh      # expects 18/18
```

### Credenciales (obligatorio antes de correr nada)

**Las contraseñas de los usuarios de test NO están en el repo** y no tienen valor por defecto:
este repo es público y estuvieron en claro hasta el 2026-09-01 (ticket
`staging-test-credentials-in-public-repo`). Hay que exportarlas antes de correr la batería, los
goldens del gateway o los E2E de Swift:

```bash
export USER_A_PASS='…'      # i5-user-a@test.yala
export USER_B_PASS='…'      # i5-user-b@test.yala
export USER_C_PASS='…'      # opcional; solo cross-member-rls-test.sh (sin ella, ese sub-caso cae a B)
```

Sin ellas, cada frente falla de forma explícita en vez de dar `invalid_credentials`: los `.sh`
mueren nombrando la variable que falta, los goldens del gateway lanzan en su `beforeAll`, y los
E2E de Swift aparecen **skipped** (su gate exige la contraseña además de `YALA_CLOUD_E2E=1`).

Para los tests de Swift, `xcodebuild` entrega las variables al runner con el prefijo
`TEST_RUNNER_`, que el runner retira:

```bash
TEST_RUNNER_YALA_CLOUD_E2E=1 TEST_RUNNER_USER_A_PASS="$USER_A_PASS" \
TEST_RUNNER_USER_B_PASS="$USER_B_PASS" xcodebuild test -scheme Yala …
```

Las contraseñas vivas no están en el árbol ni en este documento — pídeselas a Jürgen. Los
**emails** sí conservan valor por defecto (cuentas sintéticas de staging, no son secreto) y se
pueden sobrescribir con `USER_A_EMAIL` / `USER_B_EMAIL` / `USER_C_EMAIL`.

El resto de valores por defecto apuntan a staging con la anon key (pública por diseño; nunca
`service_role`) y se pueden sobrescribir con `SUPABASE_URL` y `SUPABASE_ANON_KEY`.

The test leaves A's inserted rows behind (authenticated cannot DELETE by design). To clean them,
delete rows for the two test `user_id`s via the Supabase SQL editor / MCP (service context) — the
script itself never uses `service_role`.

## Goldens de I6 (Worker `/sync/*` contra staging)

`gateway/test/sync.goldens.test.ts` (vitest) ejerce el Worker end-to-end contra ESTE staging con los 2
JWTs de usuario (password grant, mismos `i5-user-a/b@test.yala`). Cubren: `user_id` siempre del JWT,
PATCH FATAL-2, gate `schema_version` por-columna, invariante de emisión (grupo parcial → 422),
delete-vs-upsert (ambos sentidos), convergencia orden-independiente (re-golden S-B6 G3), idempotencia de
batch, y prefs push/pull. Corren con `cd gateway && npm test` (network ON; NO en CI).

**Sin cleanup:** cada run usa `sync_id`s FRESCOS (UUID) — como `DELETE` está revocado (`REVOKE DELETE`),
las filas de prueba se ACUMULAN bajo los `user_id` de test. Para limpiarlas, borrar por `user_id` de los
2 usuarios de test vía el SQL editor / MCP (contexto service) — igual que con el RLS gate. Los goldens
nunca usan `service_role`.

## Goldens de I7a (Worker `/account/*` contra staging)

`gateway/test/account.goldens.test.ts` (vitest) ejerce `POST /account/claim` + `GET /account/exists`
end-to-end contra ESTE staging con los 2 JWTs de usuario (password grant). Cubren: dos claims
concurrentes del mismo sub → exactamente uno `created` y el otro `existing_stable` (serialización del
`ON CONFLICT`), `claiming_in_progress` con líder distinto, reclaim idempotente del mismo líder →
`created`, `exists` false→true, y el `sub` SIEMPRE del JWT (un `id`/`sub`/`user_id` ajeno en el body se
ignora). Corren con `cd gateway && npm test` (network ON; NO en CI).

**Estado previo REQUERIDO:** el test 1 exige que `profiles[subA]` NO preexista (para ver `created`);
`profiles` tiene 1 fila por sub (PK = `id`) y `DELETE` está revocado, así que la fila se ACUMULA entre
runs. Antes de correr, limpia los `profiles` de los 2 usuarios de test en contexto **service** (SQL
editor / MCP — el test nunca usa `service_role`):

```sql
DELETE FROM public.profiles WHERE id IN (
  SELECT id FROM auth.users WHERE email IN ('i5-user-a@test.yala','i5-user-b@test.yala')
);
```

Los tests que necesitan estado `migration_in_progress` lo fijan por un PATCH directo a PostgREST con el
JWT del propio dueño (RLS UPDATE lo permite) y lo revierten al terminar.

## IdentityRemap (§b.4, DIFERIDOS #29) — traducción client-side, op first-class diferido a v2

El remap de un UUID de identidad cableado como sync_id se traduce CLIENT-SIDE a `tombstone(old, reason
.remap)` + `upsert FULL(new)` + upserts FULL de las filas referenciantes (commit `54ccf391`) — CERO
cambios de wire/gateway/RPC: la PK `(user_id, sync_id)` hace las dos filas disjuntas, el batch es
conmutativo y HLC-idempotente. **Un op `remap` first-class server-side queda como candidato v2
multi-device** (compraría atomicidad cross-device del par y auditoría explícita; en v1 single-device no
aporta). Si se implementa: el RPC tendría que re-keyear la fila preservando server_seq/HLC y el applier
cliente ganar el case — revisar entonces la interacción con el sweep de la reversa (el tombstone(old)
de la traducción actual NO resuelve testigo en la reversa → skip correcto, §b.5).

## Reversa server-side (I11-3, §h) — columnas `reverse_*` + acciones del RPC

Migración `i11_reverse_progress_actions` (staging). `profiles` ganó 3 columnas ADITIVAS
(`reverse_in_progress boolean not null default false` — ya existía desde i10 —, `reverse_frozen_at
timestamptz`, `reverted_at timestamptz`) y el RPC `migration_progress(p_device_id, p_action)` se
EXTENDIÓ (los branches `cutover`/`complete` de la ida quedaron intactos) con 4 acciones, expuestas por
`POST /account/migration` (passthrough — toda la lógica vive en el RPC). El lease REUSA
`leader_device_id` + `migration_updated_at` (migración y reversa son mutuamente excluyentes; expiry
>60min, heartbeat NULL jamás expira — mismo idiom que `claim_account`):

- **`reverse_claim`** — guards: `migrated_at` set (born-cloud v1 → `not_migrated`); `mip=true` con lease
  VIGENTE → `migration_in_progress`, con lease EXPIRADO → **takeover de la migración ABANDONADA**
  (mip=false, rip=true, líder=caller — el modo de fallo real del device run 2026-07-10); re-claim del
  MISMO líder → ok idempotente SIN edad de lease; reversa ajena con lease expirado → takeover. El claim
  FRESCO (y todo takeover) resetea `reverse_frozen_at`/`reverted_at` del run anterior.
- **`reverse_freeze`** — guard reverse-líder SIN edad de lease (el lease existe SOLO para que
  competidores usurpen) → `reverse_frozen_at=coalesce(...,now())` idempotente + heartbeat.
- **`reverse_complete`** — guard reverse-líder → `rip=false` + `reverted_at=now()`. **`migrated_at` NO
  se toca** (§h.4: el backend queda congelado como red; `reverted_at` es la señal para el diseño futuro
  de re-cutover — `claim_account` NO cambia hoy, diferido documentado). Idempotente tras el flip.
- **`reverse_abort`** — DES-congela (`rip=false`, `reverse_frozen_at=null`; `reverted_at` queda null).
  Acepta líder **o lease expirado** (abort de emergencia post-crash largo). Idempotente con rip ya false.

Cada acción del líder refresca `migration_updated_at` (heartbeat). Goldens 11-18 de
`account.goldens.test.ts` cubren las 4 acciones (incl. el takeover 1-bis y la acción inválida → 400).

**ASIMETRÍA CERRADA (2026-07-11, migración `i11_reverse_claim_cas`) — `reverse_claim` ya es CAS:**
el review adversarial de I11-3 documentó que `reverse_claim` era read-then-UPDATE (TOCTOU): dos
devices del MISMO usuario reclamando a la vez podían recibir ambos `ok:true` (dual-líder transitorio
que convergía por los guards de freeze/complete). Fix desplegado en staging: los 4 UPDATE de la rama
`reverse_claim` son CONDICIONALES sobre el estado leído (claim fresco: `AND reverse_in_progress=false
AND migration_in_progress=false`; takeovers de ida/reversa abandonada: `AND migration_updated_at =
<leído>`; re-claim mismo líder: `AND leader_device_id = p_device_id AND reverse_in_progress=true`) +
re-check de `FOUND` → `other_leader` si perdió la carrera (bajo READ COMMITTED el UPDATE perdedor
re-evalúa su WHERE sobre la fila comiteada por el ganador — EvalPlanQual — y no matchea). Los demás
branches del RPC quedaron VERBATIM (goldens 6-18 verdes lo prueban). **Golden 19 (test `22.` del
archivo): la carrera REAL** — dos `reverse_claim` concurrentes vía `Promise.all` (patrón del golden 1
de `claim_account`) → exactamente uno `ok:true`, el perdedor `other_leader`; el assert es determinista
post-fix en ambos interleavings. Nota: un golden FOUND-false SECUENCIAL no es representable — el read
y el UPDATE condicional viven dentro de la MISMA llamada al RPC; `patchProfile` solo pre-setea ANTES.

**CERRADO (2026-07-11) — enforcement del freeze en `/sync/push`:** el gateway RECHAZA con **409
`yala_account_reverting`** (request-level) los pushes de una cuenta con `reverse_frozen_at` set (el
backend dejó de ser fuente de verdad §h.1, y SIGUE congelado tras `reverse_complete` — red §h.4).
Diseño (handler `handleSyncPush`, `gateway/src/sync/routes.ts`):

- **Request-level, NO per-delta:** un `rejected` por-delta dead-letterearía en el cliente filas
  legítimas que deben sobrevivir en el outbox para la reversa/adopción de ese device (y el guard en
  `apply_delta` sería inevitablemente per-delta + migración SQL).
- **Costo CERO de pared** (el motivo original del diferido era "una query extra por request"): el check
  (1 GET a la fila propia de `profiles`, RLS/PK, por request) corre **EN PARALELO con el primer
  `apply_delta`** y se gatea antes del 2º delta y antes de responder. Medido contra el Worker staging
  desplegado (12-20 pushes noop de 1 delta): baseline p50 0.51s → secuencial 0.67s (+160ms, descartado)
  → paralelo **p50 0.512s** (sin delta medible).
- **Leak ACOTADO documentado:** el delta[0] puede aterrizar en el backend congelado (y el batch entero
  en el caso 1-delta, donde el gate queda al final). Benigno por diseño: apply HLC-idempotente, el
  backend congelado jamás vuelve a ser fuente de verdad (la reversa deja de pullear ANTES del freeze), y
  el 409 hace stop en el cliente SIN purgar. El freeze tiene TOCTOU inherente de todos modos (un push en
  vuelo cuando cae el freeze también aterriza).
- **La reversa NO se auto-bloquea:** todos sus pushes (`reverseDrainOnce`, fase `reverseDrainAll`)
  ocurren ANTES de `reverse_freeze` (el freeze solo se estampa tras `reverseVerify` OK); `reverseUpload`
  es CloudKit. Pull y Merkle NO se gatean (el re-drain y el sweep de zombies DEPENDEN de ellos post-freeze).
- **Cliente:** `SyncPushClient` mapea el 409-reverting → `.accountUnavailable` (misma semántica de stop:
  `SyncCadencePolicy` → `stopUntilRelaunch`, sin loop de reintentos, nada se purga) con breadcrumb
  (`pushAccountReverting`) y telemetría (`cloudAccountReverting`) PROPIOS para distinguirlo del 403 en
  diagnóstico. Un 409 sin ese `type` conserva el trato previo (`transient`). Sin case nuevo en
  `PushOutcome`: la cadencia es idéntica y un case nuevo tocaría todos los switches exhaustivos sin
  cambiar comportamiento; I14 detectará la reversa por estado de cuenta, no por el push outcome.
- **Fail-closed:** check upstream caído → 502 (cliente → transient/backoff; el batch aplicado se
  re-pushea noop-idempotente).
- **Goldens 19-21 + 19-bis** (`account.goldens.test.ts`, sub B — VIVEN ahí y no en sync.goldens porque
  vitest corre los archivos en paralelo y congelar a sub A rompería los pushes concurrentes de
  sync.goldens): 409 + type + leak item[0]/bloqueo item[1] en AMBAS rutas; pull/merkle/prefs-pull 200
  congelada; des-congelada → noop/applied.
- **`/prefs/push` TAMBIÉN gateado (2026-07-11, mismo patrón — cierra el residual):** check compartido
  (`beginFreezeCheck`) en la sombra del primer `apply_pref`, gate antes de la 2ª key y antes de
  responder; 409 mismo type. Latencia medida: p50 0.525s post-gate vs 0.524s baseline (costo cero).
  Cliente: `PrefsSyncClient` mapea 409-reverting → `.accountUnavailable` vía
  `GatewayErrorEnvelope.isAccountReverting` (helper compartido con `SyncPushClient`); el runtime NO
  purga el outbox de prefs en ese outcome (solo purga en `completed`) → nada se pierde, y el stop del
  ciclo lo impone el push de dominio del mismo ciclo. La reversa no drena prefs post-freeze (el sync de
  prefs solo corre en el runtime `.cloud`, gateado durante migración/reversa) → no se auto-bloquea.

**Estado POSTERIOR que dejan los goldens de `/sync/*` (gotcha cazado 2026-07-10):** `sync.goldens.test.ts`
re-crea en cada corrida filas PARCIALES de `budgets` (hand-crafted, `name` NULL — el golden de uuid[] `'{}'`
de DIFERIDOS #25) para el user A. Esas filas divergen PERMANENTE en el Merkle del e2e Swift
(`snapshotUpload_backfillThenVerify_datasetTablesConverge` espera `diverged == ["tx_items"]` ESTRICTO —
el cliente materializa `name` con default ≠ NULL server-side). Tras correr `npm test`, RE-TOMBSTONEARLAS
(mismo remedio que I12-A aplicó a las legacy) antes de correr el e2e Swift:

```sql
UPDATE public.budgets SET deleted=true, deleted_hlc = hlc
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'i5-user-a@test.yala')
  AND deleted=false AND name IS NULL;
```

Alternativa SIN contexto service (verificada 2026-07-11): con el JWT del propio user A, `GET
/rest/v1/budgets?deleted=eq.false&name=is.null&select=sync_id` y por cada fila un `POST
/rest/v1/rpc/apply_delta` con `p_op:"tombstone"` y un `p_row_hlc` fresco (> los HLC T0 de los goldens)
— `apply_delta` tiene GRANT a `authenticated` y el tombstone es el mismo efecto.

## Heartbeat del lease (I14-pre) — acción `heartbeat` del RPC `migration_progress`

Residual pendiente #3. Un PASO monolítico largo (upload del snapshot: minutos con 1.1k filas, más en
corpus 10k+; drain de la reversa sobre una época nube grande) sólo refrescaba `migration_updated_at` en
claim/cutover/complete y en las acciones `reverse_*` → dejaba al líder **usurpable a mitad de trabajo**
(converge seguro por los guards de freeze/complete, pero sucio). Fix: el runner llama
`sendLeaseHeartbeatIfDue()` por PROGRESO (por página del snapshot, al cerrar `reverseDrainAll`, y en cada
re-poll de `reverseUpload`); el executor lo capa a **1 request/60s** (throttle in-memory) y es
**BEST-EFFORT ABSOLUTO** (nunca lanza, nunca altera el outcome del paso — un `other_leader` aquí NO corta,
el guard real vive en cutover/freeze/complete).

Semántica de la acción (sirve a la ida Y a la reversa con UNA sola acción; `migration_in_progress OR
reverse_in_progress`, guard líder SIN edad de lease): líder de un run activo → `UPDATE
migration_updated_at=now()` → `ok:true`; líder distinto → `ok:false, reason:'other_leader'`; sin run
activo → `ok:false, reason:'not_in_progress'` (la fila AUSENTE la corta el guard pre-dispatch del propio
RPC con `no_profile`, inalcanzable para este branch). NO toca `migrated_at`/`reverse_frozen_at`/`reverted_at`/
`claim_account`.

**ESTADO: ✅ DESPLEGADO (2026-07-11, MCP reconectado).** Migración `i14_heartbeat_action` aplicada en
staging (`fostjbbwstyuunmmefuk`) como injerto server-side sobre la functiondef VIVA (un `DO` lee
`pg_get_functiondef`, inserta el `elsif` ante el marcador del bloque FORWARD y ejecuta el
`create or replace` — extensión verbatim, cero retipeo; idempotente si se re-aplica). El UPDATE del
branch es CONDICIONAL + `FOUND` (idiom CAS de `i11_reverse_claim_cas`: un takeover que comitea entre el
read y el write NO recibe el refresco del líder viejo). Worker redesplegado desde HEAD limpio (versión
`55d27bb0`) y verificado por curl contra el DESPLEGADO (acción inválida → 400; `heartbeat` sin run →
`not_in_progress` e2e). Gates post-deploy: goldens **130/130** (los 23-26 verdes, previos intactos) ·
budgets parciales re-tombstoneados (gotcha aplicado) · e2e Swift staging **11/11** (4 suites, Merkle
estricto). El artefacto `pending-heartbeat-action.sql` se retiró al aplicarse — el branch vivo se
inspecciona con `pg_get_functiondef` y la migración queda en el historial de Supabase con su nombre.

## delete_personal_account (G5-D1) — borrado GDPR del corpus personal + verificación WIRE one-shot

Función NUEVA `qa/cloud/g5_01_delete_personal_account.sql` (`security definer`, `set search_path = public`,
guard `auth.uid()` NULL → `yala_not_authorized`, grants REVOKE public/anon + GRANT authenticated). **HARD
DELETE** de todas las filas `user_id = auth.uid()` en las 16 tablas de dominio + `user_preferences` +
`sync_seq_counters` + `attest_keys` + `report_claims` + la fila `profiles` (PK `id`); devuelve counts por
tabla en jsonb. NO toca grupos (`groups_forget_user` lo hace aparte). ~~Ni `auth.users` (residual owner)~~
**SUPERSEDED por g12_01 (2026-07-16, §g12_01 abajo): el RPC ahora TAMBIÉN borra `auth.users` del caller** —
HARD DELETE **RATIFICADO por el owner (2026-07-16)**. Ruta `POST /account/delete` (`requireUserAndAttest` —
asimetría deliberada con el resto de `/account/*`, que usa `requireUser` sin attest).

**Aplicación (loop principal, MCP, contexto service):** aplicar el `.sql` verbatim como migración
`g5_01_delete_personal_account`. Registrar el md5 real tras aplicar:

```sql
select md5(pg_get_functiondef('public.delete_personal_account()'::regprocedure));
-- md5 esperado: f1ab01670a85d3d72860b5aeae6cfe2b  (aplicada 2026-07-16, migración g5_01_delete_personal_account)
```

**Regla anti-drift:** re-aplicar a prod (`kefvaiymtgytemwbltlz`) en el mismo cambio o anotar drift pendiente.

### Verificación WIRE one-shot (por qué NO hay golden network-ON, ver account.goldens.test.ts)

Destructivo + irreversible → jamás sobre los users compartidos A/B de la suite (borrar `sync_seq_counters`
resetea seq→1 sin re-seed; `profiles[A]` lo exige el golden 11; `profiles[B]` lo mutan los goldens 6-26).
Verificación one-shot con el JWT de **sub B** (aislado del push paralelo de sync.goldens, que es solo-A),
CORRIDA MANUAL DESPUÉS de `npm test` (no antes — dejaría a B sin fila para los goldens de reversa):

1. **Sembrar filas frescas** de B vía PostgREST con su JWT (o vía RPCs). El JWT de B:
   `POST {SUPABASE_URL}/auth/v1/token?grant_type=password` con `i5-user-b@test.yala` y la
   contraseña de `USER_B_PASS` (ver «Credenciales» arriba; mismo helper `login()` del test). Con ese `access_token` como Bearer + `apikey: ANON`:

   ```
   POST /rest/v1/tx_items       body: {"sync_id":"<uuid1>","user_id":"<subB>","note":"g5-wire","hlc":"<hlc>", ...cols NOT NULL...}
   POST /rest/v1/accounts       body: {"sync_id":"<uuid2>","user_id":"<subB>", ...}
   POST /rest/v1/user_preferences body: {"user_id":"<subB>","key":"g5-wire","value":"x","hlc":"<hlc>"}
   -- Alternativa robusta: un push real vía POST /sync/push (arma sync_seq_counters por el trigger) —
   -- basta con que haya ≥1 fila en varias tablas para probar el borrado.
   ```
   Confirmar `GET /account/exists` (Bearer B) → `{"exists": true}` (B ya tiene fila profiles de los goldens).

2. **Ejecutar el borrado** con el JWT de B (attest opcional en staging, `ENFORCE=observe`):
   ```
   POST {WORKER}/account/delete   headers: { Authorization: Bearer <jwtB> }
   → 200 { accounts, budgets, ..., tx_items, user_preferences, sync_seq_counters, attest_keys,
           report_claims, profiles }  (counts > 0 en las tablas sembradas + profiles:1)
   ```
   (O directo al RPC en contexto service para aislar del edge: `POST /rest/v1/rpc/delete_personal_account`
   Bearer B, body `{}`.)

3. **Verificar vacío** (Bearer B, RLS filtra a las filas de B):
   ```
   GET /rest/v1/tx_items?user_id=eq.<subB>&select=sync_id        → []
   GET /rest/v1/accounts?user_id=eq.<subB>&select=sync_id        → []
   GET /rest/v1/user_preferences?user_id=eq.<subB>&select=key    → []
   GET /rest/v1/sync_seq_counters?user_id=eq.<subB>&select=seq   → []
   GET {WORKER}/account/exists   Bearer B                        → { "exists": false }   (profiles borrada)
   ```

4. **Re-claim a estado estable** (para no dejar a B sin fila — la suite lo re-crea igual en su próxima
   corrida, pero se restaura explícitamente):
   ```
   POST {WORKER}/account/claim   Bearer B   body: {"device_id":"device-B-01","provider":"google"}
   → { "state": "created" }        (la fila renace limpia)
   ```
   Nota: los counters de B renacen en seq=1 tras el re-claim — igual que un usuario nuevo; los goldens de B
   fijan su estado por PATCH y no dependen del valor de seq, así que es inocuo.

**CORRIDA 2026-07-16 (G5-D1, loop principal vía MCP+curl): VERDE** — seed 201 → delete 200 con counts
reales (`tx_items:53, user_preferences:41, sync_seq_counters:1, profiles:1`) → verificación post-delete
`[]` en prefs/counters (Bearer B) → re-claim `{"state":"created"}`. Suite gateway re-corrida tras el WIRE
para confirmar B estable.

⚠️ **El runbook WIRE de arriba (pasos 1-4) queda SUPERSEDED por g12_01** — con el borrado de `auth.users`,
el paso 4 (re-claim con el mismo JWT) VIOLARÍA `profiles_id_fkey` (409 → 502) y el password grant del user
borrado MUERE permanentemente. El método vigente está en §g12_01 (sub DESECHABLE + restore por signup).

## g12_01 — delete_personal_account TAMBIÉN borra `auth.users` (gate §12, Bloque B2)

Migración `qa/cloud/g12_01_delete_account_auth_users.sql` (2026-07-16; HARD DELETE + dirección RATIFICADOS
por el owner; review adversarial PRE-aplicación: APLICAR CON AJUSTES, todos aplicados). `create or replace`
VERBATIM sobre g5_01 + `delete from auth.users where id = v_uid` AL FINAL + key `auth_users` en el jsonb.
Por qué esta vía (y no Admin API [service_role todo-o-nada en el Worker: DESCARTADA] ni rol de máquina
[borraría cualquier uuid: DESCARTADO]): el borrado queda atado al `auth.uid()` del caller POR CONSTRUCCIÓN,
cero credencial nueva, invariante intacto. Detalle completo (PoC, cascadas, supuesto load-bearing) en el
header del `.sql`.

**Supuesto LOAD-BEARING (assert al promover a CUALQUIER entorno):** `auth.users` tiene RLS habilitado con
CERO policies → el DELETE funciona SOLO porque `postgres` (owner de la función) tiene `rolbypassrls=true`:

```sql
select rolbypassrls from pg_roles where rolname='postgres';  -- debe ser true (verificado staging 2026-07-16)
```

Efectos verificados en vivo: `profiles` cascadea desde auth.users (el delete explícito queda como belt);
GoTrue cascadea identities/sessions/refresh_tokens/mfa/oauth/webauthn; sesión NO refrescable post-RPC (el
access token en vuelo vale hasta exp — suficiente para el paso 4a SIWA revoke, stateless); un re-`claim`
del JWT en vuelo ya NO puede renacer la cuenta (violaría la FK — cierre de la resurrección que g5 permitía).
Residual-owner documentado: `auth.audit_log_entries`/`auth.flow_state` (sin FK) sobreviven — mismo residual
que el Admin API.

**Aplicación (loop principal, MCP, contexto service):** aplicar el `.sql` verbatim como migración
`g12_01_delete_account_auth_users`. Registrar el md5 real tras aplicar:

```sql
select md5(pg_get_functiondef('public.delete_personal_account()'::regprocedure));
-- md5 esperado: 6bafd85a2f9349e98af30ca48c53bdd9  (aplicada 2026-07-16, migración g12_01_delete_account_auth_users;
-- ACL verificado {postgres,authenticated,service_role}; rolbypassrls(postgres)=true verificado)
```

**Verificación WIRE one-shot (método VIGENTE — sub DESECHABLE, A/B intactos):**
1. Sembrar un tercer usuario efímero C. ⚠️ GoTrue RECHAZA el signup de dominios no-reales
   (`email_address_invalid` para `@test.yala` — así se descubrió que A/B fueron sembrados, no
   registrados): crear C vía MCP (contexto service) con INSERT a `auth.users` (molde: copiar
   instance_id/aud/role/raw_app_meta_data de la fila de A; `encrypted_password = crypt('<pass>',
   gen_salt('bf'))`; email_confirmed_at now(); tokens '' ) + su fila `auth.identities` (provider
   'email', provider_id = id, identity_data con sub/email/email_verified). Password grant → JWT C.
2. Sembrar 1-2 filas con el JWT de C (PostgREST directo o `POST /sync/push`) + `POST /account/claim`.
3. `POST /rest/v1/rpc/delete_personal_account` (Bearer C) → 200 con counts y **assert `auth_users: 1`**
   (el ÚNICO observable de que el delete matcheó — un 0 aquí = el gap sigue abierto).
4. Verificar: password grant de C → FALLA (usuario muerto); `GET /account/exists` con el JWT C en vuelo →
   `{"exists": false}`; las filas de C → `[]`.
5. Sin restore: C era desechable. A/B jamás se tocan con este método.

**CORRIDA 2026-07-16 (g12_01, loop principal vía MCP+curl): VERDE** — C sembrado por SQL → login OK →
seed pref 201 + claim `created` → delete 200 con `auth_users: 1, profiles: 1, user_preferences: 1,
sync_seq_counters: 1` → re-login 400 (usuario MUERTO) · prefs `[]` · `exists:false` con el JWT en vuelo
(la verificación stateless post-delete confirmada — el paso 4a de B1 [SIWA revoke] funciona tras el RPC).

**Regla anti-drift:** re-aplicar a prod (`kefvaiymtgytemwbltlz`) en el mismo cambio o anotar drift
pendiente — CON el assert de `rolbypassrls` contra prod ANTES de aplicar.

## g12_02 — lockdown EXECUTE de `stamp_group_seq` (higiene advisor, molde i5_11) — APLICADA EN AMBOS ENVS ✅

Migración `qa/cloud/g12_02_lock_down_stamp_group_seq.sql` (2026-07-16; cierra el WARN de higiene del
security advisor anotado en el cierre del gate §12 Bloque A). `stamp_group_seq()` (trigger function
SECURITY DEFINER de los seq de grupos, g1_01/g1_01b) conserva el EXECUTE default a PUBLIC/anon/
authenticated — a diferencia de `stamp_server_seq`, que i5_11_lock_down_function_execute dejó
solo-service_role. Inofensivo en la práctica (Postgres rechaza invocar trigger functions fuera de
contexto de trigger), se cierra por paridad. Grants-only: la functiondef NO cambia (el md5 de paridad
33/33 staging↔prod queda intacto). Los 5 triggers de grupos siguen disparando: EXECUTE se chequea al
CREATE TRIGGER, no al fire — precedente empírico: los 17 triggers de `stamp_server_seq` estampan desde
i5_11 en ambos envs con el ACL cerrado. Detalle completo en el header del `.sql`.

**Aplicación (loop principal, MCP — el conector autoriza UNA org a la vez, re-conmutar para cubrir
staging `fostjbbwstyuunmmefuk` Y prod `kefvaiymtgytemwbltlz`):**

1. Pre-flight en el entorno: `select proname, proacl from pg_proc p join pg_namespace n on
   n.oid = p.pronamespace where n.nspname='public' and proname in
   ('stamp_group_seq','stamp_server_seq');` — esperado: `stamp_group_seq` CON EXECUTE para
   PUBLIC/anon/authenticated (el WARN; en prod era el default MATERIALIZADO explícito
   `{=X/postgres,postgres=X,anon=X,authenticated=X,service_role=X}`, no `NULL` — ambas formas son el
   mismo caso y el revoke las cubre igual) y `stamp_server_seq` =
   `{postgres=X/postgres,service_role=X/postgres}` (el molde). Si el pre-flight NO cuadra con esto,
   PARAR y reconciliar contra esta sección antes de aplicar.
2. Aplicar como migración `g12_02_lock_down_stamp_group_seq` con EXACTAMENTE los 2 statements del
   `.sql` (sin el header de comentarios — así se aplicó en prod; el texto idéntico es lo que hace
   matchear `md5(statements[1])` entre envs).
3. Post-check (misma query): `stamp_group_seq` = `{postgres=X/postgres,service_role=X/postgres}`,
   idéntica a `stamp_server_seq`. Advisors: el WARN desaparece.
4. Smoke funcional: cualquier write de grupos (golden o push real) sigue estampando `server_seq`.

```text
md5 del archivo .sql completo (referencia del repo): 70c7baea436f89958766eebac4e7cd8a
md5(statements[1]) del texto aplicado (los 2 statements): 5a8797bc95a9fe7bf4370011e270466b

-- prod    (kefvaiymtgytemwbltlz): ✅ APLICADA 2026-07-16, versión 20260716223038;
--   post-check proacl {postgres=X/postgres,service_role=X/postgres} (== stamp_server_seq);
--   functiondef md5 de stamp_group_seq intacto (2039dd2982e31a02661c62cce28b1169, grants-only);
--   advisors: el WARN de stamp_group_seq DESAPARECIDO (quedan solo los by-design).
-- staging (fostjbbwstyuunmmefuk): ✅ APLICADA 2026-07-16, versión 20260716223824;
--   md5(statements[1]) = 5a8797bc95a9fe7bf4370011e270466b (== prod, paridad byte-exacta);
--   pre-flight idéntico al de prod (mismo default materializado explícito);
--   post-check proacl {postgres=X/postgres,service_role=X/postgres} (== stamp_server_seq);
--   functiondef md5 2039dd2982e31a02661c62cce28b1169 (== prod);
--   advisors: el WARN de stamp_group_seq DESAPARECIDO (quedan los by-design + el WARN
--   preexistente auth_leaked_password_protection, ajeno a grupos).
```

**Regla anti-drift:** SATISFECHA — aplicada en ambos envs el 2026-07-16 (misma sesión, conector
re-conmutado prod→staging; orden atípico prod-primero porque el conector arrancó autorizado en la
org de prod). El WARN de higiene anotado en el cierre del gate §12 Bloque A queda CERRADO.

## migrate_group (G6-1) — migración de grupos VIVOS de CloudKit al backend (§9 D7)

Función NUEVA `qa/cloud/g6_01_migrate_group.sql` (`security definer`, `set search_path = public`, guard
`auth.uid()` NULL → `yala_not_authorized`, grants REVOKE public/anon + GRANT authenticated). Crea EN UNA
TRANSACCIÓN ATÓMICA `split_groups` con META HISTÓRICA (`created_at` del payload, NO `now()`) + los N
`group_members` migrados TAL CUAL (member_key legacy, status/role/joined_at históricos): el owner
(`is_owner=true`) con `user_id = auth.uid()`, el resto placeholders `user_id NULL` reclamables por el rebind
legacy de `join_group`. NO extiende `create_group` (que forzaría owner `member_key=sub` → rompería las FKs
del historial del owner, y `created_at=now()`). IDEMPOTENTE-SUAVE (el uploader one-shot reintenta): mismo
owner → `{already:true, group_id, owner_user_id, server_seq}` sin tocar nada (ignora `p_members` del
reintento; sin reconciliación de drift); otro owner → `yala_group_exists`. member_key duplicado en el payload
→ `yala_bad_input` ANTES del PK (evita el `unique_violation` crudo → 502 → retry-loop eterno) + cinturón
`exception when unique_violation`. Riesgo ACEPTADO documentado en el `.sql`: squat de group_id (DoS
insider-only). Los RPCs existentes (`create_group`/`join_group`) quedan INTACTOS (el rebind ya vive en
`join_group`, DDL L442-461).

**Aplicación (loop principal, MCP, contexto service):** aplicar el `.sql` verbatim como migración
`g6_01_migrate_group`. Registrar el md5 real tras aplicar:

```sql
select md5(pg_get_functiondef('public.migrate_group(text, jsonb, jsonb)'::regprocedure));
-- md5 esperado: e7863927e5cb58398ae1e36b84f268f9  (aplicada 2026-07-16: g6_01_migrate_group + g6_01b verbatim-comments; fix P2 de casts incluido)  (aplicada 2026-07-16, migración g6_01_migrate_group)
```

**Regla anti-drift:** re-aplicar a prod (`kefvaiymtgytemwbltlz`) en el mismo cambio o anotar drift pendiente.

**Goldens (`gateway/test/groups.goldens.test.ts`, describe G6):** 3 goldens (prefijo `g6-migrate-`) — (1)
migrate atómico + filas exactas + re-intento `already:true` + otro caller `yala_group_exists`; (2) E2E R10
server-side (push del historial con FKs legacy `*_member_key` = uuidStrings CloudKit-era → pull de B tras
join+approve las ve byte-idénticas); (3) rebind vía gateway (`join_group(legacy_member_key)` → `rebound:true`;
re-join de la fila ya reclamada → `rebound:false`, no re-bindea). **Marcados `describe.skip` hasta la
aplicación** (dejan la suite VERDE hoy). TRAS aplicar la migración: cambiar `describe.skip(` → `describe(` en
ese bloque y re-correr `npm test` (3/3 verdes). Usan solo los users A/B compartidos; sin cleanup (gid único
por corrida, DELETE revocado — las filas se acumulan, se limpian por `group_id` en contexto service si hace falta).

## transfer_group_ownership (G10 / D10) — batch "salir de todos mis grupos" — APLICADA EN AMBOS ENVS ✅

Función NUEVA `qa/cloud/g10_01_transfer_group_ownership.sql` (`security definer`, `set search_path = public`
— NO toca pgcrypto → NO va a `RPC_NEEDS_ENC_KEY`; guard `auth.uid()` NULL → `yala_not_authorized`; grants
REVOKE public/anon + GRANT authenticated). Transfiere el ownership de UN grupo backend al co-member elegible
más antiguo — **heredero VERBATIM de `groups_forget_user` loop1** (`(role='admin') desc, joined_at asc,
member_key asc`, `user_id not null`, `status='active'`, `<> caller`) — y NADA MÁS. Diferencias vs
`groups_forget_user`: opera sobre UN grupo (sin loop), NO anonimiza al caller (sin loop2), NO borra
push_tokens, y **JAMÁS tombstonea** cuando no hay heredero (invariante D10: nunca destruir datos de terceros)
→ `{transferred:false, reason:'no_eligible_owner'}`, el cliente lo manda a "necesitan tu decisión". El
caller (orquestador batch) llama `leave_group` justo después (ya pasa el guard `yala_owner_cannot_leave`
porque `owner_user_id` ya no es él). IDEMPOTENTE-SUAVE: grupo inexistente/deleted/owner distinto (ya
transferido o nunca fui owner o huérfano NULL) → `{already:true}` sin tocar nada → **retry-transient SEGURO**
(2º call tras 502 → ya no soy owner → already:true; NO está en `neverRetryTransient` del cliente).

**Aplicación (loop principal, MCP, contexto service):** aplicada en AMBOS envs. md5 real:

```sql
select md5(pg_get_functiondef('public.transfer_group_ownership(text)'::regprocedure));
-- md5 esperado: dd3a049c793f6fe2479552ac0c7fba3f
-- staging (fostjbbwstyuunmmefuk): ✅ APLICADA 2026-07-20, versión 20260720193200;
--   md5 dd3a049c793f6fe2479552ac0c7fba3f.
-- prod    (kefvaiymtgytemwbltlz): ✅ APLICADA 2026-07-21, versión 20260721212213;
--   md5 dd3a049c793f6fe2479552ac0c7fba3f (== staging, paridad byte-exacta).
```

**OJO — el `.sql` del repo NO es byte-idéntico a lo aplicado (y por diseño):** staging recibió el 2026-07-20
una variante con los COMENTARIOS CONDENSADOS (2741 car. vs 5616 B del archivo), y a prod se promovió ese
mismo texto byte-exacto extraído del historial de staging (método del gate §12: «SQL extraído BYTE-EXACTO
del historial»), justo para que el md5 de `pg_get_functiondef` — que SÍ incluye los comentarios del cuerpo —
cuadre en los dos envs. El CÓDIGO es idéntico al del archivo: normalizando ambos (quitar `--`, colapsar
whitespace) dan `5ac870418e96cfdd80ba024ad35c8c18`. Si algún día se quiere que archivo == DB, el molde es
`g6_01b_migrate_group_verbatim_comments` (re-crear con los comentarios del archivo en AMBOS envs a la vez),
y entonces el md5 contractual de arriba cambia y hay que actualizarlo en sus 4 registros (este README,
CLAUDE.md, `qa/coverage-index.json` areas `groups-backend-g2-sync-channel`, y el doc del vault).

**Post-check de la promoción (endurecido — `md5(pg_get_functiondef)` NO basta):** la functiondef NO emite
`proowner` ni `proacl`. Como la función es SECURITY DEFINER y las policies de `split_groups`/`group_members`
están declaradas SOLO para el rol `authenticated`, un definer que no sea dueño de las tablas (ni
`rolbypassrls`) NO encajaría en ninguna policy → default deny → el `select owner_user_id into v_owner` no
devuelve fila → la RPC respondería **`{already:true}` EN SILENCIO**, con el md5 cuadrando perfectamente.
Verificado en prod el 2026-07-21, las 6 en OK: md5 == staging · `proowner=postgres` · `prosecdef=true` +
`proconfig={search_path=public}` · EXECUTE `anon`=false · EXECUTE `authenticated`=true · `proacl` =
`{postgres,authenticated,service_role}` sin PUBLIC (== staging). Precheck previo (39/39 OK): las 18 columnas
con tipo Y nullability, `server_hlc()`/`auth.uid()`/`stamp_group_seq()`, las 3 tablas, los 2 triggers stamp,
los 2 FKs a `auth.users`, `leave_group`+`groups_forget_user`, los 3 roles, **`owner=postgres` y FORCE RLS
apagado** en las 3 tablas, `rolbypassrls(postgres)=true`, event trigger `pgrst_ddl_watch` activo, y
`transfer_group_ownership` AUSENTE (aplicación puramente aditiva). Advisors post-aplicación: sin hallazgos
de clase nueva (el WARN `authenticated_security_definer_function_executable` es el by-design que comparte
con sus 15 hermanas). Funciones en `public`: 33 → **34**.

**Regla anti-drift (SQL):** SATISFECHA — aplicada en ambos envs (staging 2026-07-20, prod 2026-07-21; el
conector MCP se re-conmutó staging→prod para la promoción, precedente de g12_02). **Tejida en
`supabase-groups-staging.ddl` §7** (2026-07-21) con el texto APLICADO, no el del `.sql` — el molde offline
debe reflejar el schema VIVO; el `create…end $$;` de la §7 es byte-idéntico al aplicado. La cabecera del
`.ddl` deja anotado el lag conocido de `g12_02` (grants-only, no teje cuerpo de función). **Regla anti-drift (GATEWAY):
SATISFECHA — Worker de prod redesplegado el 2026-07-21**, Version ID `078bc707-768e-49b3-8a29-8eeb3c1a4d98`.
Sin él, la RPC existiría en la DB pero el gateway la habría rechazado con 404 `yala_bad_request: unknown rpc`
ANTES de llegar a PostgREST (`gateway/src/groups/rpc.ts` filtra por `PARAM_ALLOWLIST` — la entrada llegó en
`a9ed3785`, 2026-07-20, posterior al deploy vivo). Agravante que lo hacía obligatorio antes del encendido y
no después: ese 404 el cliente lo mapea a `.transient` (`GroupsMembershipClient`) ⇒ **reintento perpetuo sin
TTL**. **Gate usado (molde para el próximo redeploy):** el diff pendiente se deriva del ÚLTIMO DEPLOY REAL
(`wrangler deployments list --env production` → 2026-07-17T17:19Z), NUNCA de la fecha que digan los docs —
aquí resultó ser **4 líneas aditivas en un solo archivo**, no «todo lo acumulado desde el 2026-07-16» como
se había anotado por error (`/config` respondiendo 200 en prod ya delataba un deploy del 17-jul). Suite
OFFLINE del gateway como gate (13 ficheros, 140/140) — los 4 goldens network-ON se EXCLUYEN a propósito:
validan staging, no el artefacto que se despliega, y ensucian el corpus. Smoke post-deploy: `/config` 200
con `0×3` · 401 sin JWT en `/groups/pull|merkle` (GET), `/groups/push`, `/sync/push`,
`/groups/rpc/transfer_group_ownership` (POST) y `/account/exists` (**GET** — con POST da 404 y NO es
regresión). Nota: el 401 de la ruta RPC no prueba la allowlist (el handler autentica antes de mirarla); lo
que la garantiza es que el bundle se construyó desde el árbol con la entrada.

**Goldens (describe G10 — ACTIVOS desde el 2026-07-20, commit `a9ed3785`; primera corrida VERDE registrada
3/3 el 2026-07-21, `GROUPS_ENC_KEY=<staging.key> npx vitest run test/groups.goldens.test.ts -t "G10"`, 4.8s
— acotar con `-t "G10"` y NO correr `npm test` entero evita el efecto colateral conocido de re-crear filas
parciales de budgets que luego divergen en el e2e Swift):** 3 goldens — (1) owner con
co-member elegible → transfiere al heredero (promovido a admin), owner intacto (el leave lo hace el
cliente), retry → `already`; (2) owner sin heredero (co-member `user_id NULL`) → `no_eligible_owner` SIN
tombstone, tercero intacto; (3) caller no-owner → `already`, sin auto-promoción. **Limitación conocida:**
solo 2 users A/B → el tie-break admin-first+más-antiguo entre 2 herederos REALES no es E2E-testeable
(mitigado: ORDER BY byte-idéntico a `groups_forget_user`). **Corren contra STAGING con URL hard-codeada y
MUTAN datos** ⇒ `npm test` JAMÁS toca prod, y por tanto **no sirven como verificación de la promoción a
prod** (esa la cubren el precheck/post-check de arriba). La aplicación a prod no exige ninguna acción sobre
ellos.

**Residuales conocidos de la RPC (no bloquean, anotados al promover):** (a) sin `for update` entre el select
del heredero y el `update split_groups` — una salida concurrente del heredero en esa ventana de ms dejaría
el grupo con un `owner_user_id` que ya no es miembro activo, y como el guard exige ser owner, no se auto-cura
server-side; es NO destructivo y es EXACTAMENTE el patrón que ya corre en prod dentro de `groups_forget_user`
loop1, así que la promoción no introduce clase de riesgo nueva (cerrarlo obligaría a tocar ambas por simetría
y cambiaría el md5 contractual); (b) el cuerpo plpgsql no se resuelve al CREATE (`check_function_bodies` solo
valida sintaxis) — cubierto por el precheck de dependencias.

## G7 — cifrado pgcrypto de columnas † de grupos (data-at-rest)

Dos migraciones NUEVAS + un paso intermedio (la llave JAMÁS en schema_migrations — §6 del brief):
`qa/cloud/g7_01_encrypt_groups_columns.sql` (FASE A: columnas `<col>_enc bytea`, `g7_recrypt_corpus(p_key)`
SERVICE-ONLY, `yala_try_decrypt(p_c, p_key)`) y `qa/cloud/g7_02_encrypt_groups_cutover.sql` (FASE B: DROP
plaintext + RENAME `_enc`, column-UPDATE grants regenerados, 6 RPCs escritores re-creados con `p_key`, 5 RPCs
lectores `groups_pull_rows_<tabla>` que descifran, `yala_logging_settings()`). 8 columnas † cifradas:
split_groups.name · group_members.display_name · split_expenses.amount/expense_description/note ·
split_settlements.amount/note · split_shares.amount (las 2 últimas por modelo de amenaza — a RATIFICAR por el owner).
Amounts como `pgp_sym_encrypt(amount::text, p_key)` → el reader los sirve STRING decimal exacto escala-4 (C1).

**Aplicación (loop principal, MCP, contexto service):**
1. `g7_01_encrypt_groups_columns` verbatim (DDL, sin llave).
2. PASO INTERMEDIO (execute_sql directo, NO migración — para que la llave no toque schema_migrations/DDL log):
   `select public.g7_recrypt_corpus('<LLAVE_STAGING>');` (idempotente).
3. Re-ejecutar `select public.g7_recrypt_corpus('<LLAVE_STAGING>');` (cinturón m12) INMEDIATAMENTE antes de la
   fase B — cubre writes en la ventana entre fases.
4. `g7_02_encrypt_groups_cutover` verbatim (cutover DDL, sin llave).
La llave se guarda en `~/Secrets/yala-groups-enc/staging.key` + `gateway/.dev.vars` (JAMÁS commiteada; prod lleva
una llave DISTINTA que genera el owner). Regenerar el contrato `supabase-groups-staging.ddl` con `dump-schema.sh`
TRAS aplicar.

**Registrar los md5 reales tras aplicar (método g3_02):**

```sql
select md5(pg_get_functiondef('public.apply_group_delta(text, text, uuid, text, jsonb, jsonb, text, text, integer)'::regprocedure));
select md5(pg_get_functiondef('public.create_group(text, text, text, text, text, text, text, text, boolean, boolean, boolean)'::regprocedure));
select md5(pg_get_functiondef('public.join_group(text, text, text, text)'::regprocedure));
select md5(pg_get_functiondef('public.groups_forget_user(text)'::regprocedure));
select md5(pg_get_functiondef('public.update_member_display_name(text, text, text)'::regprocedure));
select md5(pg_get_functiondef('public.migrate_group(text, jsonb, jsonb, text)'::regprocedure));
select md5(pg_get_functiondef('public.yala_try_decrypt(bytea, text)'::regprocedure));
select md5(pg_get_functiondef('public.yala_logging_settings()'::regprocedure));
select md5(pg_get_functiondef('public.groups_pull_rows_split_groups(text, bigint, int, text)'::regprocedure));
select md5(pg_get_functiondef('public.groups_pull_rows_group_members(text, bigint, int, text)'::regprocedure));
select md5(pg_get_functiondef('public.groups_pull_rows_split_expenses(text, bigint, int, text)'::regprocedure));
select md5(pg_get_functiondef('public.groups_pull_rows_split_shares(text, bigint, int, text)'::regprocedure));
select md5(pg_get_functiondef('public.groups_pull_rows_split_settlements(text, bigint, int, text)'::regprocedure));
-- g7_recrypt_corpus se ejecuta y luego se puede dropear; su md5 no es contrato de runtime.
-- md5s esperados (aplicadas 2026-07-16, migraciones g7_01_encrypt_groups_columns + g7_02_encrypt_groups_cutover;
-- recrypt corrido ×2 [corpus: 336 names, 592 display_names, 239+59+3 amounts, 186+45+0 notes/descr; belt m12 en 0];
-- roundtrip verificado 239/239 pre-cutover):
--   apply_group_delta                    8de5f51dcef93d6f83f78d075816fddc
--   create_group                         3f2deb9df1eebdd2007fbb3cd79430b6
--   join_group                           059fae41dd79944a1326e3f5a56aab52
--   groups_forget_user                   22c36f83da343a53d2e53cd8f02005e8
--   update_member_display_name           90e39a22c4668ba257ddd6c074b7909d
--   migrate_group                        4a365198b45c5a1da52f055f417cb5d2
--   yala_try_decrypt                     4d366c7219d0b22ae25493140e559eea
--   yala_logging_settings                0cfd11692b7cb9ea08d591a16758032a
--   groups_pull_rows_split_groups        88179f041d193c4158a0c532febe3f44
--   groups_pull_rows_group_members       485dff02cffd237caaf96266918c1fd6
--   groups_pull_rows_split_expenses      b38c3e3c68f7fc49e7c30f0586fef21d
--   groups_pull_rows_split_shares        33edd4f26580ac66e62736403d35de15
--   groups_pull_rows_split_settlements   6d1f3456fc0d3a402ce87c9819b1f4a1
--   (g7_recrypt_corpus vive con md5 8a44c733e1fdcedc2491d69b8ec21886 — retenida, SERVICE-only, inofensiva)
```

**Regla anti-drift:** re-aplicar a prod (`kefvaiymtgytemwbltlz`) en el mismo cambio o anotar drift pendiente.

**Goldens (`gateway/test/groups.goldens.test.ts`):** describe G7 con `g7-logging-settings` (asserta
`{log_statement:"ddl", log_min_duration_statement:"-1", log_parameter_max_length_on_error:"0"}`) y `g7-roundtrip`
(push amount/note → pull plaintext byte-igual con amount STRING "30.0000" → columna física bytea ≠ plaintext →
merkle estable). Los goldens G2/G3/G6 que assertan † se adaptaron a leer vía los RPCs lectores con `p_key`
(`readGroupRowDecrypted`/`readMember`). **REQUIEREN `GROUPS_ENC_KEY` en el entorno** (`export GROUPS_ENC_KEY=<staging
key>` antes de `npm test`; fail-fast en beforeAll). `cross-member-rls-test.sh` también exige `GROUPS_ENC_KEY` y arma
las siembras positivas vía `apply_group_delta` (las negativas con columnas NO-†). Todos corren SOLO tras aplicar las
migraciones (contra el schema viejo pegarían ciphertext/errores).

## G8-1 — APNs server-side: registro de tokens + fan-out de silent push

> ⚠️ **SUPERSEDED por g8_02 (G8-3, decisión owner 2026-07-16) — ver §G8-3 abajo.** El MODELO DE AMENAZA de
> abajo ("cualquier co-member puede enumerar los device_tokens de sus co-members bajo demanda") YA NO APLICA:
> g8_02 movió los 2 RPCs a un rol de máquina `yala_push` (REVOKE de `authenticated`) → un cliente authenticated
> recibe 403+42501. La ENUMERACIÓN muere; el griefing del prune muere; el residual multi-device del autor se
> cierra (exclusión por DEVICE emisor). El registro/unregister (`/push/register`, `/push/unregister`) y la
> mecánica del fan-out siguen VIGENTES; solo cambió CÓMO el fan-out autentica los 2 RPCs (JWT de máquina, no del
> autor) y su FIRMA. Lo de esta sección se conserva como historia; la postura vigente es §G8-3.

Un `.sql` NUEVO (`qa/cloud/g8_01_push_fanout.sql`, 2 RPCs) + gateway TS (registro + fan-out). `push_tokens` YA
EXISTE en el DDL contrato (:247-260, PK `(user_id, device_token)`, RLS per-user, limpiada por
`groups_forget_user`) — el `.sql` NO la recrea.

**Los 2 RPCs** (`security definer`, `set search_path = public`, guard `auth.uid()` NULL → `yala_not_authorized`,
grants REVOKE public/anon + GRANT authenticated):
- `get_group_push_tokens(p_group_id)` → `table(user_id, device_token, platform)`. Valida `is_group_member` del
  CALLER; devuelve los device tokens de los co-members `status='active'` del grupo, EXCLUYENDO al caller
  (`gm.user_id <> auth.uid()`). **`pendingApproval` EXCLUIDO** (no es writer → un push de contenido le
  dispararía un pull que su RLS no materializa = ruido/batería; la meta la cubre la cadencia).
- `prune_push_token(p_user_id, p_device_token)` → borra el PAR EXACTO (best-effort del fan-out ante
  `BadDeviceToken`/`Unregistered`). SECURITY DEFINER bypassa la RLS delete → **guard de radio**: solo el dueño
  del token, o un co-member de un grupo activo compartido con `p_user_id`.

**⚠️ MODELO DE AMENAZA (decisión de sesión — RATIFICAR por owner):** PostgREST expone toda función
EXECUTE-a-authenticated en `/rest/v1/rpc/` ⇒ **cualquier co-member puede enumerar los device_tokens de sus
co-members bajo demanda** (acotado a grupos compartidos). Estructural con el invariante "el Worker jamás usa
service_role". Impacto ACOTADO: un token APNs es inerte sin la Auth Key del developer (secret server-side); el
único abuso práctico es el prune de un token co-member (griefing menor, auto-sanado por el re-registro de boot).
Divulgación aceptada y documentada en el header del `.sql`. **RESIDUAL v1:** `gm.user_id <> auth.uid()` excluye
TODOS los devices del autor → su segundo device espera a la cadencia (en CloudKit el push era per-device).

**Gateway TS:**
- `POST /push/register` (`src/push/register.ts`) — auth `requireUserAndAttest` (REUSADA de `groups/routes.ts`,
  exportada — sin 3ª copia). Body `{device_token, platform}` (hex-64 + `ios-sandbox|ios-prod`). Upsert a
  PostgREST con `Prefer: resolution=merge-duplicates` (PK compuesta basta, sin `on_conflict` param);
  `user_id = auth.sub` lo pone el WORKER (jamás del body; RLS with-check lo re-valida); `updated_at` EXPLÍCITO
  (el default `now()` no re-dispara en la rama conflict-update). 200 `{registered:true}`.
- `POST /push/unregister` — body `{device_token}` → `DELETE push_tokens?user_id=eq.<sub>&device_token=eq.<tok>`.
  200 `{unregistered:true}`.
- **Fan-out** (`src/groups/routes.ts::fanOutGroupPush`): `handleGroupsPush` recolecta el `Set<group_id>` de los
  deltas APPLIED (zip por índice — `SyncDeltaResult` no porta group_id) y dispara
  `c.executionCtx.waitUntil(fanOutGroupPush(...))` SIN esperar. El fan-out: short-circuit sin
  `APNS_KEY_ID/APNS_AUTH_KEY`; `get_group_push_tokens` por grupo con el JWT del AUTOR; dedup por device_token
  cross-grupo; cap 50; `sendPush` silent (`content-available:1`, `yala:{kind:"groups-sync"}`, background/prio 5);
  `BadDeviceToken`/`Unregistered` → `prune_push_token`; otros fallos → `console.log("[canary]
  groupApnsSendFailed …")` (token SOLO prefijo ≤8 chars). Best-effort TOTAL: un fallo JAMÁS afecta la respuesta.

**⚠️ AJUSTE #1 (crítico) del brief:** `c.executionCtx` LANZA en Hono si `app.fetch` se llama sin 3er arg. El
helper `push()` de `groups.goldens.test.ts` ahora pasa `{ waitUntil(){}, passThroughOnException(){} }` (ctx
no-op) — sin él los ~10 goldens de escritura reventarían a 500 al tocar el fan-out. El golden nuevo usa su
propio ctx COLECTOR de promesas.

**Aplicación (loop principal, MCP, contexto service):** aplicar el `.sql` verbatim como migración
`g8_01_push_fanout`. Registrar los md5 reales tras aplicar:

```sql
select md5(pg_get_functiondef('public.get_group_push_tokens(text)'::regprocedure));
select md5(pg_get_functiondef('public.prune_push_token(uuid, text)'::regprocedure));
-- md5 esperados (aplicada 2026-07-16, migración g8_01_push_fanout; con el notify pgrst añadido post-review):
--   get_group_push_tokens  067d9db70c85a26494d0e2ca15da770f
--   prune_push_token       eeba6e5658a15dcd7fc801e91dce670e
```

**Regla anti-drift:** re-aplicar a prod (`kefvaiymtgytemwbltlz`) en el mismo cambio o anotar drift pendiente.

**Tests:**
- `gateway/test/push.fanout.unit.test.ts` — units OFFLINE (fetch stubbeado, CI-safe): fan-out short-circuit sin
  APNs, happy path (host/headers/payload), dedup cross-grupo, cap 50, `BadDeviceToken`→prune, upstream error
  sin crash, `/push/register` 401 sin JWT.
- `gateway/test/push.fanout.test.ts` — semi-WIRE (network ON, users A/B):
  - Bloque `/push/register`+`/push/unregister` **NO-skip** (los endpoints solo tocan `push_tokens`, que ya
    existe → verde HOY sin g8_01): 401 sin JWT, 400 no-hex, 400 platform inválida, upsert idempotente
    (2 registros mismo par → 1 fila), aislamiento per-user.
  - Bloque fan-out `describe.skip` HASTA aplicar g8_01 (usa los 2 RPCs nuevos). Interceptor SELECTIVO de fetch
    (`*.push.apple.com` → mock; el resto → staging real; teardown restaura el fetch original en afterEach).
    Env extendido con PEM ES256 (molde `makeKeys`) + `APPLE_TEAM_ID/BUNDLE_IDS/APNS_KEY_ID`. **TRAS aplicar
    g8_01: cambiar `describe.skip(` → `describe(` y re-correr `npm test`** (2/2 verdes).

**Pendiente-owner:** cargar `APNS_KEY_ID` + secret `APNS_AUTH_KEY` en el bloque `[env.production]` de
`wrangler.toml` — sin ellos el fan-out es no-op silencioso en prod (log 1 vez). El canario TelemetryDeck
`groupApnsSendFailed` del §12 es server-side aquí (log del Worker en `wrangler tail`); el lado cliente va en G8-2.

## G8-3 — credencial de máquina `yala_push` (supersede el modelo de amenaza de G8-1)

Un `.sql` NUEVO (`qa/cloud/g8_02_push_machine_role.sql`) + gateway TS + un cambio Swift mínimo. **Decisión owner
(2026-07-16):** RECHAZA el modelo "co-members enumeran device_tokens" de G8-1 y pide la arquitectura robusta.

**SQL (g8_02):**
- Rol `yala_push` (nologin) — scope MÍNIMO: `usage on schema public` + EXECUTE sobre 2 funciones. CERO grants de
  tabla, sin BYPASSRLS. `grant yala_push to authenticator` (para el `SET ROLE` que dispara el claim `role` del JWT).
- `get_group_push_tokens` RE-FIRMADA → `(p_group_id text, p_exclude_user_id uuid, p_exclude_device_token text
  default null)` (DROP de la vieja `(text)` primero). **SIN guard de auth/rol en el cuerpo** (SECURITY DEFINER →
  `current_user`=OWNER, no el caller; un guard por current_user rompería la función para el Worker — los GRANTS son
  el ÚNICO control, AJUSTE #1). Exclusión del emisor: token NON-NULL → excluye SOLO ese `(user, token)` par (los
  otros devices del autor SÍ entran, cierra el residual multi-device); NULL → fallback G8-1 (excluye todos los del autor).
- `prune_push_token(uuid, text)` — firma sin cambio (`create or replace`, sin DROP); cuerpo grants-only (sin radio ni auth.uid()).
- **Grants (AJUSTE #4):** `revoke all … from public, anon, authenticated` (nombra `public` explícito — authenticated es
  miembro de PUBLIC; corre DESPUÉS del CREATE) + `grant execute … to yala_push`. `notify pgrst, 'reload schema'`.

**Cambio de postura vs G8-1:** la ENUMERACIÓN por co-members MUERE (los RPCs ya no son callable con el JWT del usuario
→ 403+42501); el griefing del prune muere; el fan-out deja de depender del JWT del autor (residual JWT-expiry cerrado).
El invariante multi-sitio se REFINA: "el Worker jamás posee credencial que pueda leer DATOS DE USUARIO; sí una
credencial de máquina acotada a infraestructura de push (2 funciones)". `yala_push` no lee datos de usuario.

**⚠️ Durabilidad (AJUSTE #5):** `PUSH_ROLE_JWT` es HS256 firmado con el LEGACY secret del proyecto (los users usan
ES256/JWKS). Si el owner completa la rotación y REVOCA el legacy secret, el fan-out muere EN SILENCIO (401 best-effort;
la cadencia de pull cubre — sin pérdida de datos). Canario: el `console.log "[groups-fanout] … upstream 401"` recurrente
= re-acuñar con el signing key vigente (`mint-push-role-jwt.mjs`).

**Gateway TS:**
- `env.ts`: `PUSH_ROLE_JWT?: string`. `fanOutGroupPush(env, {userJWT, sub}, groupIds, excludeDeviceToken?)`: short-circuit
  si falta el secret (junto al de APNs, 1 log); los 2 `callRpc` usan `env.PUSH_ROLE_JWT` (no el JWT del autor);
  `get_group_push_tokens` recibe `p_exclude_user_id: auth.sub` + `p_exclude_device_token`.
- `handleGroupsPush` lee `X-Yala-Device-Token` (opcional; hex-64 o se ignora con log; prefijo ≤8 en logs) → fan-out.
- `mint-push-role-jwt.mjs` (NUEVO): lee el legacy secret de un path por argv, firma `{role:'yala_push', iss:'yala-gateway'}`
  exp 10 años, imprime SOLO el JWT a stdout (pipe a `wrangler secret put PUSH_ROLE_JWT`).

**Cliente Swift (mínimo):** `GroupsSyncClient.pushChunk` añade el header `X-Yala-Device-Token` vía provider inyectado
`deviceTokenProvider: () -> String?` — default `{ nil }` (los tests reciben el default; NO se acoplan al singleton,
AJUSTE #7); la COMPOSICIÓN de producción (`.shared`) inyecta `{ PushTokenRegistrar.shared.storedToken }`. Header solo
si non-nil (flag OFF / default = header AUSENTE, byte-idéntico al pre-G8-3).

**Aplicación (loop principal):** aplicar `g8_02_push_machine_role.sql` verbatim; acuñar el JWT + `wrangler secret put
PUSH_ROLE_JWT`; desplegar el Worker (kill-safe: el Worker viejo con g8_02 aplicada → fan-out 403 best-effort, cadencia
cubre). Registrar los md5 reales tras aplicar:

```sql
select md5(pg_get_functiondef('public.get_group_push_tokens(text, uuid, text)'::regprocedure));
select md5(pg_get_functiondef('public.prune_push_token(uuid, text)'::regprocedure));
-- md5 esperados (aplicada 2026-07-16, migración g8_02_push_machine_role):
--   get_group_push_tokens(text,uuid,text)  942a8531f6f3c642d5a0a767e3250a1d
--   prune_push_token(uuid,text)            6ee533ae818ff77d902ad8cfd011e621
-- Verificar además el rol: select rolname, rolbypassrls, rolcanlogin from pg_roles where rolname='yala_push';
--   (verificado 2026-07-16: yala_push, rolbypassrls=false, rolcanlogin=false)
-- Y el ACL final de ambas funciones (assert del review adversarial — caza drift de grants):
--   select proname, proacl::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace
--     where n.nspname='public' and proname in ('get_group_push_tokens','prune_push_token');
--   (verificado 2026-07-16, ambas: {postgres=X/postgres,service_role=X/postgres,yala_push=X/postgres} —
--    authenticated/anon/PUBLIC FUERA; service_role conserva su default-grant, consistente con todo el
--    codebase e inofensivo: ya tiene BYPASSRLS y jamás la usa el Worker)
```

**Regla anti-drift:** re-aplicar a prod (`kefvaiymtgytemwbltlz`) en el mismo cambio o anotar drift pendiente.

**Tests:**
- `gateway/test/push.fanout.unit.test.ts` — OFFLINE (CI-safe): + short-circuit sin `PUSH_ROLE_JWT`; `get_group_push_tokens`
  recibe `p_exclude_user_id`/`p_exclude_device_token` (con y sin device emisor). `AUTH` gana `sub`; `makeFanoutEnv` lleva
  `PUSH_ROLE_JWT` por default.
- `gateway/test/push.fanout.test.ts` — WIRE, bloque fan-out `describe.skip` HASTA g8_02 aplicada + `PUSH_ROLE_JWT` en env
  (**ACTIVACIÓN POR EL LOOP: `describe.skip(`→`describe(` + `export PUSH_ROLE_JWT=<jwt>`**). Golden de la decisión owner:
  un authenticated que llame los RPCs DIRECTO con la firma NUEVA COMPLETA recibe **403 + code 42501**. Caso multi-device:
  header device1 → APNs recibe device2 (otro device de A) + B; sin header → solo B (fallback G8-1).
- `YalaTests/CloudSync/GroupsSyncClientTests.swift` — header presente con provider, ausente con default `{ nil }`.

## B1 (gate §12) — SIWA revoke 5.1.1(v): canje + revocación del refresh token de Apple

**Requisito:** App Store Guideline 5.1.1(v) — al ofrecer "eliminar cuenta" con Sign in with Apple, la app DEBE
revocar los tokens vía la REST API de Apple. Diseño (brief congelado `docs/modo-nube/briefs/BRIEF-B1-SIWA-REVOKE.md`,
5 ajustes del /review-plan incorporados): **canje EN el sign-in vía Worker; custodia del refresh token de Apple en
el Keychain del CLIENTE; revoke vía Worker al borrar**. El Worker es STATELESS (jamás persiste tokens de nadie) y
la .p8 de SIWA jamás sale del server → el invariante multi-sitio se conserva (el Worker no gana credencial que lea
datos de usuario; el refresh token de Apple ni siquiera pasa por reposo server-side).

**Endpoints** (`gateway/src/sync/siwa.ts`):
- `POST /account/siwa/exchange` — auth `requireUser` (SIN attest — el sign-in PRECEDE al `/attest/bind`, la
  asimetría documentada de `/account/*`). Body `{authorization_code}` con shape-check `[A-Za-z0-9._-]{10,2048}`
  (400 `yala_bad_input`). Canjea contra `appleid.apple.com/auth/token` (form-urlencoded, **SIN `redirect_uri`** —
  solo aplica al flujo web; con un code de ASAuthorizationController produce `invalid_grant`) y devuelve SOLO
  `{refresh_token}` (id_token/access_token de Apple NO se reenvían — minimización). Error Apple → 502 SIN volcar
  el body de Apple a logs/respuesta (puede portar tokens); el code solo como prefijo ≤8.
- `POST /account/siwa/revoke` — auth `requireUserAndAttest` (molde `/account/delete`: mismo flujo destructivo;
  en staging `observe` el attest es opcional). Body `{refresh_token}` → `auth/revoke` con
  `token_type_hint=refresh_token`. 200 → `{revoked:true}`; fallo → 502 (cliente best-effort).
- `client_secret`: JWT ES256 firmado por-request (exp 5 min, sin cache) con la .p8 — claims iss=Team,
  sub=client_id (primer elemento de `APPLE_BUNDLE_IDS` — single-valued por env hoy), aud=appleid.apple.com.
- **D3 (rate-limit) VERIFICADO:** ambos endpoints pasan por el paraguas existente — `requireUser`/
  `requireUserAndAttest` invocan `gateRequest(env, claims, "sync")` con el binding `RATE_LIMITER`, ANTES de
  cualquier fetch a Apple. Sin residual.

**Secrets/vars:** `SIWA_KEY_ID = "PQ53RQ5D3G"` en `wrangler.toml` (ambos bloques; inerte en prod hasta su primer
deploy) + secret `SIWA_AUTH_KEY` (PEM de `~/Secrets/yala-siwa/AuthKey_PQ53RQ5D3G.p8`, `wrangler secret put
SIWA_AUTH_KEY < AuthKey_PQ53RQ5D3G.p8`). **Staging se aplica en B1; el `--env production` se ENCADENA al runbook
del Bloque A** (el Worker de prod no existe hasta su primer deploy). Sin el secret → 503
`yala_siwa_not_configured` en los 2 endpoints y NADA más cambia.

**Cliente Swift:**
- Capture: el delegate de `CloudAuthService` extrae `credential.authorizationCode` (de un solo uso, ~5 min — por
  eso el canje corre EN el sign-in, no al borrar) y tras el `signInWithIdToken` EXITOSO invoca
  `siwaExchangeHook?(code, appleUserID)` — closure INYECTADA default `nil` (AJUSTE #2: sin dependencia
  CloudAuthService→CloudAccountClient; tests byte-idénticos). Composición única en AppBootstrapper (14.55):
  `SIWAExchangeSeam.installProductionHook()` — Task best-effort, timeout 4s (molde `PushTokenSignOutSeam`); el
  sign-in JAMÁS falla ni se retrasa por esto.
- Custodia: el PAR `cloudauth.appleRefreshToken` + `cloudauth.appleRefreshToken.user` (= appleUserID de ESE
  sign-in, AJUSTE #1) en `CloudAuthKeychainStorage` (service `com.yala.cloudauth`, AfterFirstUnlock). Writer
  con CLEAR del par previo ANTES de escribir + user-primero/token-después (SERIO #1 del review adversarial:
  sin el clear, una sobrescritura matada entre writes dejaba `(token del DUEÑO, user de la SECUNDARIA)` — par
  CRUZADO que el match no detecta); reader exige AMBAS keys (par a medias = ausencia). Sobrevive el sign-out normal
  (credencial de APPLE, no de la sesión Supabase) — verificado 2026-07-16: ni la matriz de sign-out ×4 (M1) ni
  la purga de frontera de secundaria barren estas keys, y el match por appleUserID hace el residuo inofensivo.
- Revoke: `SIWATokenRevocation.revokeIfNeeded()` (paso 4a del borrado, orden congelado intacto) — par ausente →
  skip (`siwaRevokeSkippedNoToken`); **par de OTRO appleUserID → skip SIN POST y SIN limpiar**
  (`siwaRevokeSkippedStaleToken`, AJUSTE #1 — cierra el hazard cross-cuenta M1: borrar la secundaria jamás
  revoca la autorización del dueño); match → POST con el JWT vivo (verificación stateless del Worker), timeout
  4s; 200 → limpia el par (`siwaRevoked`); fallo → canario `siwaRevokeFailed`, NUNCA lanza (contrato best-effort
  — el borrado no se bloquea). Canarios TelemetryDeck: `siwaExchangeFailed` (no-code|no-jwt|exchange|keychain) y
  `siwaRevokeFailed` (no-jwt|revoke) — ambos en CERO es parte del gate §12.

**Residuales (con argumento, del brief):**
- **Población-cero:** los flags están DARK — no existe usuario de producción con sesión SIWA previa al capture.
  El único residual (sesión creada antes de B1 → sin token custodiado al borrar → `siwaRevokeSkippedNoToken`)
  aplica solo a devices de dogfooding/staging del owner, que puede re-sign-in. NO se implementa fallback de
  re-auth interactiva en el flujo de borrado (fricción UX sin población real).
- **D1/D2 descartados** (decisión del /review-plan del brief): D1 — persistir el `authorization_code` para
  canjearlo al borrar es inviable (expira en ~5 min, un solo uso); D2 — canjear-y-revocar al vuelo en el borrado
  exigiría re-auth interactiva de Apple en medio de un flujo destructivo. El canje-en-sign-in es el único diseño
  que deja SIEMPRE un token revocable.
- Kill de la app en los ~4s del canje → sin token custodiado (misma clase que población-cero; re-sign-in cura).

**Tests:**
- `gateway/test/siwa.unit.test.ts` — OFFLINE (CI-safe, molde account.delete.test.ts): exchange happy (form
  EXACTO sin `redirect_uri`; client_secret decodificado kid/iss/sub/aud/exp), revoke happy
  (`token_type_hint=refresh_token`), 503 sin secret, 401 sin JWT, 400 shape, error Apple → 502 sin leak. NO hay
  golden WIRE contra Apple real (un code real solo existe en un device tras sign-in interactivo — paridad APNs).
- `YalaTests/CloudSync/SIWATokenRevocationTests.swift` — revocación con deps inyectadas (par válido / nil /
  STALE / fallo), composición del canje, capture post-credencial (hook nil = no-op), roundtrip Keychain del PAR
  (service único por test). `YalaTests/AccountDeletionServiceTests` conserva el ancla de orden
  `forget→teardown→delete→siwa→close` INTACTA.

## Google revoke (sesión 3 Google Sign-In) — `disconnect()` del grant OAuth al borrar la cuenta

**Requisito:** Guideline 5.1.1(v) formalmente solo exige el revoke de SIWA ("Sign in with Apple");
Google entra por la frase "credentials or tokens off of the device" + simetría ante App Review (una
cuenta Google borrada que deja el grant OAuth vivo es la misma clase de residuo que B1 cierra para
Apple). Diseño espejo de B1 con una diferencia estructural: **no hay canje ni Worker** — el SDK
GoogleSignIn custodia sus propios tokens y `GIDSignIn.disconnect()` revoca el grant COMPLETO (y firma
out) en un solo paso. El par custodiado (`GoogleUserPairStore`, sesión 1) solo aporta el MATCH, no el
token; ningún token de Google pasa por el gateway ni por reposo server-side.

**Cliente Swift** (`Yala/Services/CloudSync/GoogleTokenRevocation.swift`, paso 4b del borrado —
inmediatamente tras el 4a de SIWA, ANTES del 4c cierre local; orden congelado de
`AccountDeletionService` intacto):

- **MATCH DOBLE** (§0 del plan — endurece el molde B1, que matchea solo por appleUserID):
  1. `pair.sub == CloudAuthService.currentUserID` — el par es de ESTA cuenta Supabase (la que se
     borra). Cierra el hazard cross-cuenta M1: un par residual del DUEÑO bajo la secundaria jamás
     revoca al dueño (mismo AJUSTE #1 de B1, con el sub como llave en vez del appleUserID).
  2. `sdkUserID == pair.googleUserID` — la sesión del SDK es DEL MISMO humano que el par. Cierra el
     hazard que el sub NO cubre: tras el sign-out de A, el `signIn` del SDK de B puede TRIUNFAR con
     el exchange de Supabase FALLIDO (el catch re-lanza sin deshacer la sesión SDK) ⇒ sesión SDK =
     B, par = A; si A borra su cuenta después, un match solo-por-sub revocaría el grant de B.
  Cualquier mismatch ⇒ no-op SIN disconnect y SIN limpiar el par.
- **Sesión SDK restaurable:** `disconnect()` opera sobre `currentUser`; si es nil y
  `hasPreviousSignIn()`, `restorePreviousSignIn()` la restaura (refresca tokens si expiraron — VA A
  RED, por eso corre DENTRO del tope). Carrera vs timeout 4s (molde exacto
  `SIWATokenRevocation.revokeIfNeeded`). Si el disconnect falla tras un restore exitoso, la sesión
  SDK restaurada de la cuenta ya borrada la barre el paso 4c (cierre local →
  `CloudAuthService.signOut()` → `GIDSignIn.signOut()` local) — ajuste A3.
- **Skip ≠ fallo (ajuste A2):** los 4 skips (`no-pair` / `stale-pair` / `no-sdk-session` /
  `stale-sdk-session`) son estados legítimos — breadcrumb `googleRevokeSkipped(reason:)` SIN canario
  y SIN limpiar el par. Solo `.failed` (disconnect rechazado o timeout, colapsados en reason
  `disconnect` — paridad con el `revoke` de SIWA) dispara breadcrumb + canario TelemetryDeck
  `googleRevokeFailed`. Éxito ⇒ `clearPair()` + `googleDisconnected()`. Contrato best-effort: JAMÁS
  lanza ni bloquea el borrado.
- **Ciclo de vida del par:** sobrevive el sign-out normal Y la frontera M1 — re-verificado con grep
  2026-07-16 (sesión 3): ni los paths de `CloudSessionSignOut` ni
  `SecondarySessionBoundaryPurge.purge()` referencian `GoogleUserPairStore`/`googleUserID`/
  `com.yala.cloudauth` (su única vía a auth es `CloudAuthService.signOut()`, que hace `GIDSignIn.
  signOut()` LOCAL y NO borra el par — comentario H6 en el propio `signOut()`). El match doble hace
  el residuo inofensivo; re-sign-in lo sobreescribe (clear-before-write); el borrado exitoso lo
  limpia (clearPair en `.disconnected`).

**Residuales (con argumento):**
- **Post-reinstalación sin sesión SDK** ⇒ skip `no-sdk-session`: el grant queda vivo en
  myaccount.google.com pero el token es inerte (el refresh token murió con el Keychain-scope del
  SDK). Fallback REST (`POST oauth2.googleapis.com/revoke`) DESCARTADO: exige el refresh token, que
  vive en la misma sesión SDK — si no hay sesión restaurable tampoco hay token accesible.
- **Sin red entrante:** no existe equivalente Google del `credentialRevokedNotification` de Apple —
  revocar el grant en myaccount.google.com NO mata la sesión Supabase (estándar de industria: la
  sesión ya emitida vive hasta expirar/sign-out).

**Tests:** `YalaTests/CloudSync/GoogleTokenRevocationTests.swift` (deps inyectadas, molde
`SIWATokenRevocationTests`: match doble happy, par nil, sub stale, sub nil, SDK sin sesión, SDK de
OTRO humano [jamás disconnect], disconnect falla sin limpiar) + `AccountDeletionServiceTests` con el
ancla de orden `forget→teardown→delete→siwa→google→close` + `MigrationWorkExecutorTests` (I4: el
BODY del claim y el faro reflejan el provider VIGENTE al momento de uso, no el de la construcción —
lección d49d2e47). Roundtrip Keychain del par en `CloudAuthServiceTests.GoogleUserPairStoreTests`.
Verificación device (owner): paso 7 de la Fase G del guion SIGNOUT-WELCOME — eliminar cuenta con
sesión Google → el grant de Yala DESAPARECE de myaccount.google.com.

## Sender e2e de I8e (`SyncPushClient` `/sync/push` contra staging)

`push-e2e-test.sh` ejerce `POST /sync/push` con EL MISMO envelope JSON que arma `SyncPushClient`
(`fields`/`field_hlcs` RawJSON-crudo verbatim, `hlc` de fila, `client_mutation_id`) contra el Worker
staging desplegado, con el JWT de user-A (password grant). Escenarios:

- **(a)** upsert de un `tx_items` real (columnas safe field-level) → `200 applied` (inserted).
- **(b)** idempotencia: re-push del MISMO delta (mismo `sync_id`+`hlc`) → `200 noop` (`all_units_stale`).
- **(c)** forja de grupo de coherencia parcial: toca `amount` (grupo `money`) sin el resto del grupo →
  `200 rejected` con `reason=coherence_group_partial:money` (http 422).

```bash
bash qa/cloud/push-e2e-test.sh
# luego, en contexto service (SQL editor / MCP), verifica que la fila (a) aterrizó:
#   select sync_id, note, currency_code, hlc, field_hlcs from public.tx_items where sync_id = '<SID>';
```

**Sin cleanup:** `sync_id` FRESCO (UUID) por corrida — `DELETE` está revocado, las filas se ACUMULAN bajo
el `user_id` de test. Limpia por `user_id` de los 2 usuarios de test en contexto service, igual que los
goldens. El script nunca usa `service_role`. NO corre en CI (red + usuarios sembrados).

## Entidades de SISTEMA — política v1 de merge determinista (residual NOTA-2 de I12-B, 2026-07-11)

Las entidades de sistema (`Account.isSystemAccount` — cuentas `Grupos [moneda]` del bridge — y la
subcategoría `balanceAdjustment`) sincronizan con `sync_id = shortcutID` ALEATORIO por device → en
multi-device cada device acuña la suya (nombres LOCALIZADOS distintos) → duplicados server-side y saldo
virtual partido. **Política v1 (client-side, lado sync):** `CloudSyncReconciler.reconcileSystemEntities`
(post-pull + reversa) colapsa al ganador determinista-global — criterio `(name, shortcutID)` ascendente,
el MISMO del dedup local del bridge, computado sobre filas convergidas (NO usa estado local como el
conteo de TXs → sin el hazard de I11-4) — re-apunta referenciadores y tombstonea perdedoras con autor
default (el tombstone viaja). Argumento de convergencia completo en `SystemEntityMergePolicy.swift`.

**Candidato de RED server-side DIFERIDO (D2):** un índice parcial
`UNIQUE (user_id, currency_code) WHERE is_system_account AND NOT deleted` en `accounts` (staging vía
MCP, contexto service) NO sustituye la política (el server no puede re-apuntar las refs del perdedor)
pero acotaría el blast-radius a 1 fila viva. Evaluar en el gate de encendido de flags.

**e2e `systemAccountMerge_twoDevices_convergeToDeterministicWinner_thenCleanup`:** cierra con cleanup a
0 vivas del run (corre SIEMPRE, incluso con el escenario fallido). Residual: si el PUSH del propio
cleanup falla (red caída), quedan filas `accounts`/`tx_items` vivas del run bajo user A → el snapshot
e2e (`diverged == ["tx_items"]` estricto) se rompe hasta limpiarlas. Remedio manual (contexto service,
mismo idiom que los budgets parciales): tombstonear por nombre/nota con el sufijo del run:

```sql
UPDATE public.accounts SET deleted=true, deleted_hlc = hlc
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'i5-user-a@test.yala')
  AND deleted=false AND is_system_account AND name LIKE '%<run>%';
UPDATE public.tx_items SET deleted=true, deleted_hlc = hlc
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'i5-user-a@test.yala')
  AND deleted=false AND note LIKE '%<run>%';
```

## Huérfano cross-device del cutover (DIFERIDOS #30) — adopt-reconcile v1 (DARK, 2026-07-11)

Residual explícito de w8: durante la ventana de cutover, un 2º device del mismo Apple ID aún `.icloud`
puede escribir una fila a la base CloudKit compartida que el líder nunca importó antes del mirror-off —
el barrido del líder solo responde por SUS writes (History local). Sin mecanismo, la fila queda huérfana
para el modo nube Y todo adopt con store poblado + writes de ventana termina en **divergencia Merkle
local-ahead PERPETUA** (clase FX — la pieza es requisito de convergencia, no solo rescate).

**Mecanismo v1 elegido: adopt-reconcile del device que escribió** (`MigrationWorkExecutor.
runAdoptOrphanReconcile()` + `AdoptOrphanDiff` pure-logic; §g.4 "Cierre del hueco multi-device" ya lo
especificaba). Diseño (CERO cambios wire/gateway):
- Enumera las identidades del backend (upserts Y tombstones) vía `/sync/pull` read-only (idiom del sweep
  I11-2 — sin apply, sin cursor, sin testigos), con **completitud verificada positivamente** contra los
  counts por tabla de `/sync/merkle` (SERIO del review adversarial: una enumeración PARCIAL con 200 OK —
  página vacía prematura — produciría falsas huérfanas con HLC fresco que PISARÍAN contenido más nuevo;
  riesgo INVERTIDO respecto a `sweepZombies`, donde un set parcial es benigno). Merkle DESPUÉS de la
  enumeración (sesgo a abortar); enumerado > merkle pasa (deletes concurrentes = conservador).
- Guard anti mass-upload ANTES de toda mutación: backend enumerado vacío + huérfanas locales →
  `abortedEmptyBackend` sin backfill ni upload (un adopt `existing_stable` implica backend poblado; el
  merge local-poblado-vs-nube-vacía es decisión de producto de I14).
- Identidad a filas nil vía `SyncIdentityService.backfillIdentities` (testigos + regla 00439727) → diff
  → upload fila-COMPLETA (`enqueueSnapshotRows` + idiom push del leader-reconcile). Idempotente (2ª
  pasada no-op). Canarios: `cloudAdoptOrphanReconciled` + breadcrumbs (incomplete/abort).
- Descartados: barrido del líder en la reversa (el remount del mirror ya importa la fila nativamente —
  no aporta al modo nube) y lectura directa del CloudKit congelado por el líder (traducción
  CD_record→dominio; candidato v2 del sub-caso "jamás adopta").

**Residuales v1 (gate de flags):** (a) device que JAMÁS adopta — auto-bloqueado por
`secondaryDeviceCloudLogin`, sin pérdida física, adopción tardía lo rescata; (b) borrados de ventana no
propagados (resurrección benigna; el diff inverso arriesgaría tombstones de filas reales bajo
import-lag); (c) import-lag → duplicado content-idéntico curable (dedup I11-4/`SystemEntityMergePolicy`).

**PENDIENTE I14 (contrato completo en el doc-comment del método):** cablear el call-site — (i) tras
quiescencia del import CloudKit y ANTES del runtime, (ii) fast-forward del History baseline antes de
habilitar el drain, (iii) pull + `runPostPullReconcilers` post-upload (cura duplicados de sistema).

**e2e `adoptOrphanReconcile_twoDevices_uploadsOnlyTheOrphanRow`:** mismo patrón de cleanup RP-1 a 0
vivas del run que el e2e de system entities (remedio SQL manual de arriba aplica igual).

## Hallazgos de la corrida device de la reversa (2026-07-11): cierres pre-flags

Tres hallazgos de la corrida device VERDE de la reversa (I11). Los tres son gate de encendido de flags.

### HALLAZGO 2 (CRÍTICO) — fila FX invisible al drain: CERRADO con fix + tests

**Root cause:** la fila `ExchangeRate` del boot post-cutover obtuvo `syncID` + tx de History, pero
`SyncCursor.historyTokenData` **sobrevive la transición de mount** `.icloud` (mirror ON) → `.cloud`
(mirror OFF) sobre el mismo archivo. El predicado del drain `$0.token > staleToken` — con un token
acuñado en el mount viejo — **excluye silenciosamente** las txs del mount nuevo (no-comparabilidad
cross-mount de `DefaultHistoryToken`, la MISMA clase que `fastForwardHistoryBaseline` documenta ~50%).
Una exclusión por predicado NO lanza → cero breadcrumb → `pending=0` perpetuo. El Merkle SÍ ve la fila
(hashea vivas por syncID) → **divergencia local-ahead inconvergible** (autoridad backend→local) →
`reverseVerify mismatch ×3 → reverseFailedRollback`.

**Fix (client-side, CERO cambios wire/gateway):** `SyncCursor += lastDrainedTxAt: Date?` (timestamp de la
última tx drenada — ancla COMPARABLE cross-mount; los timestamps de History sí lo son) + guard
`recoverIfHistoryTokenIncomparable` en `performDrain` con **revalidación continua** por sesión: mientras
no validado y con `lastDrainedTxAt != nil`, un fetch por timestamp (`> lastDrainedTxAt - 60s`) detecta
txs NUEVAS (`timestamp > lastDrainedTxAt`, externas, personales) ausentes del token-fetch → re-procesa la
UNIÓN y **re-ancla SIEMPRE a la última tx del mount actual**. Breadcrumbs `historyTokenIncomparable(missed:)`
/ `historyTokenRecovered` (fuera de `#if DEBUG`, counts only — en producción cloud `> 0` = canario de la
clase). `SyncCursor` vive en el store sync-meta `.none` → **el campo NO exige deploy CloudKit** (0b del
plan: el mirror `.icloud` solo espeja el store personal `.private`).

- **AJUSTE de implementación (premisa del plan corregida):** "faltantes = todo el timestamp-fetch ausente
  del token-fetch" produciría un FALSO POSITIVO en steady-state — la última tx ya drenada
  (`timestamp == lastDrainedTxAt`) cae en la ventana de slack pero el token válido la excluye
  correctamente → aparecería "faltante" y dispararía recovery en cada primer drain de sesión. El
  discriminante real de un token ROTO es una tx NUEVA (`timestamp > lastDrainedTxAt`); la frontera ya
  drenada NO cuenta. El slack `-60s` solo ensancha el FETCH (completitud de la unión).
- **Residual (nil-skip):** un cursor pre-schema (`lastDrainedTxAt == nil`) con token YA roto no se
  auto-cura (nunca consume → nunca puebla el campo). Benigno hoy: 0 devices `.cloud` en producción (flags
  DARK); el device del owner se re-migra para I14 y tiene la palanca de purga FX; el flujo NUEVO puebla
  el campo antes del remount (`drainOnce` de `startParallelHistoryCapture`).
- **Residual (filas YA divergidas):** una tx vieja ya no capturable no se auto-cura — palanca: botón
  "Purgar ExchangeRate locales (caché)" del panel (`397519b8`; la caché FX es re-derivable).
- **S1 del review adversarial (re-migración misma instalación):** `fastForwardHistoryBaseline` ahora
  estampa `lastDrainedTxAt` JUNTO al token (mismo save). Sin eso, un re-cutover sobre una instalación que
  ya fue `.cloud` (ancla vieja) haría que el guard viera como "faltantes" TODAS las txs que el baseline
  salta a propósito (el snapshot full-row las cubre) → recovery masiva del corpus + canario
  `historyTokenIncomparable` FALSO en el propio camino de I14. Token y ancla avanzan SIEMPRE juntos.
- **Tests:** `CloudSyncEngineTests` T0-T8 (stores on-disk, `.serialized`, contenido REAL del outbox;
  T8 = regresión del S1).

**Caso hermano — token IN-DECODIFICABLE (DIFERIDOS #33, cerrado 2026-07-17):** el guard de arriba
dispara ante NO-comparabilidad detectable por timestamp (token que decodifica pero excluye); el otro
modo de fallo es el token que NO decodifica (o cuyo fetch por token LANZA — migración destructiva de
schema). Antes ese caso hacía re-escaneo COMPLETO (`historyTokenExpired`): con purga de History
activa habría re-emitido el corpus entero con HLC fresco (el reloj PERSISTIDO ya avanzó → el dedup
`(syncID,hlc,op)` no absorbe; en multi-device además PISA por LWW writes ajenos más nuevos aún no
pulleados). Fix: `HistoryTokenFallbackLogic` (tabla pura) + `fetchHistoryResolvingToken`/
`executeBrokenTokenBranch` en el motor — re-escaneo ACOTADO a la ventana `> lastDrainedTxAt − 60s`
(la MISMA ancla del guard) + re-anclaje a la última tx de la ventana. Semánticas: **(a)** sin ancla
(cursor pre-schema) → full-rescan CONSERVADO (sin ancla no se puede acotar sin arriesgar pérdida);
**(b)** el fetch acotado TAMBIÉN lanza → DEGRADA al full-rescan medido (abortar = stall = la clase
inconvergible local-ahead de arriba); ventana VACÍA (History purgada bajo el ancla) → drain ocioso
barato hasta que un write nuevo entre y sane. Breadcrumbs con rama:
`historyTokenBrokenBoundedRescan(window:)` / `historyTokenBrokenFullRescan(reason: no-anchor |
bounded-fetch-failed, txs:)` (los counts MIDEN la re-emisión — canario si el hazard ocurre igual) /
`historyTokenBrokenReanchored`. Residuales: rewind de reloj > slack con token roto simultáneo (el
fallback es load-bearing → los writes del gap se pierden de la captura hasta que el wall-clock
re-pase el cutoff — misma improbabilidad que M1, citada en el doc-comment); la frontera del slack se
re-emite con HLC fresco (LWW converge, mismo residual T3). El guard del Hallazgo 2 se SALTA con
token roto (su fetch sería idéntico al de la rama acotada). **SERIO 1 del review adversarial (fix
`translationAborted`):** los reanchor (el nuevo Y el gemelo del guard, que tenía el MISMO defecto
latente) apuntan a la última tx de la ventana/unión CRUDA, calculada ANTES de traducir — si
`clock.send` lanza a mitad (drift >5min, alcanzable con reloj persistido adelantado por
snapshot/remap), re-anclar saltaría las txs externas entre el break y el final SIN emitirlas
(invisibles para siempre: timestamp ≤ ancla nueva) = pérdida silenciosa. Con abort, AMBOS reanchor
se suprimen y el paso 7 cae al avance normal (última tx CONSUMIDA = punto de retry del invariante
de drift). Tests: `CloudSyncEngineTests` T9-T14 (T14 = el abort) + `HistoryTokenFallbackLogicTests`
(tabla). El token corrupto real solo aparece en migraciones destructivas de schema — no fabricable
en device on-demand: cobertura por tests + breadcrumbs como canario en Console.

### HALLAZGO 3 — zombies ni-sweep-ni-mirror-history: CERRADO como cubierto por canario

El sweep NUNCA propaga vía `ckRecordName`: borra la fila viva local bajo `outboxSaveAuthor` y el MIRROR
exporta el delete. `zombiesSwept=0` con tombstones pre-mount = **caso normal benigno** — la red PRIMARIA
de propagación de borrados de la época nube es el **replay de la History del MIRROR al remontar**
(I11-2/S2), no el sweep.

**Matriz (tombstone pre/post-mount × History del mirror viva/purgada/token-inválido × testigo vivo/borrado):**

| tombstone | History del mirror | red que lo propaga |
|-----------|--------------------|--------------------|
| pre-mount  | viva            | replay del mirror al remontar ✓ |
| pre-mount  | token-inválido / re-import | el sweep (load-bearing en este edge) ✓ |
| pre-mount  | **PURGADA** + token vivo | **NINGUNA** (celda sin red; con o sin testigo) |
| post-mount | cualquiera      | apply normal (borra fila + testigo) ✓ |

**Veredicto: CERRADO como cubierto.** La única celda sin red — tombstone pre-mount + History del mirror
PURGADA + token vivo — es HOY **INALCANZABLE**: la única purga (`purgeHistoryOnce`) está tras doble flag
DARK; no hay purga por tiempo/espacio. `CKIdentityCapture.scanOrphanMetadata` **delata** esa celda
(metadata sin fila viva, indiferente al testigo); la reparación sigue diferida (**D4**, canario v1).
Distinto de DIFERIDOS #30: aquél es un UPSERT que no subió; éste es un DELETE que no se propagó — no se
solapan.

### HALLAZGO 4 — `rebindsVerified=2`: BENIGNO (docs + panel read-only)

`verifyRebinds()` es read-only: cuenta testigos `SyncIdentity` con `lastReboundAt != nil` cuya fila viva
aún porta el syncID. Solo 2 rutas estampan `lastReboundAt`: rebind-por-ancla del backfill
(`SyncIdentityService`) y re-key del IdentityRemap #29; la auto-cura `identityCollisionHealed` **NO** lo
estampa. Reconstrucción: los 2 pares de `InboxDraft` byte-idénticos (bug pre-`00439727`) recibieron
rebind-por-ancla erróneo en la era pre-guard → 1 testigo con `lastReboundAt` por par → count=2.

**Checklist de confirmación del owner (1 tap: panel → "Testigos rebindeados (read-only)"):**
- [ ] `entityType` de los 2 testigos = `inboxDraft`.
- [ ] `lastReboundAt` anterior al cutover.
- [ ] `identityCollisionHealed count=2` presente y repair/remap = 0 en la corrida.

Panel (D1 del review): `CloudSyncMigrationPanelModel.listRebinds()` — lista `entityType + lastReboundAt`
(corto, sin PII) de los testigos con `lastReboundAt != nil` (molde `scanOrphanMetadata`, `#Predicate`
concreto, NO muta). Convierte la checklist en 1 tap.

## Google Sign-In (sesión 1 — brief `docs/modo-nube/briefs/BRIEF-GOOGLE-SIGNIN-V1.md`, 2026-07-16)

Decisión owner (revierte el diferimiento "Google = fase web/Android" del 2026-07-11): v1 lanza con
Apple Y Google. Config vigente:

- **Supabase Auth STAGING (`fostjbbwstyuunmmefuk`): provider Google ON** (owner vía dashboard
  2026-07-16, verificado `GET /auth/v1/settings` → `google: true`). "Client IDs" = los 2 iOS client
  IDs separados por coma (validan el `aud` del id_token), secret VACÍO (clients iOS no tienen),
  **Skip Nonce Check OFF — restricción DURA**: el SDK ≥9.0.0 acepta nonce custom (patrón idéntico a
  SIWA: raw a Supabase, SHA-256 hex al SDK); activar el skip degradaría TODOS los clientes futuros
  del provider (es un toggle global) y haría re-jugable ~1h un id_token capturado.
- **Client IDs de GCP** (proyecto `yala-502622`, app en estado Prueba — test user
  jur211296@gmail.com): copia de referencia en **`~/Secrets/yala-google/client-ids.md`** (prod
  `com.jurgenschmidt.yala` + dev `com.jurgenschmidt.yala.dev`; los mismos valores viajan como build
  settings `GID_CLIENT_ID`/`GID_URL_SCHEME` del pbxproj — NO son secretos, van en el Info.plist del
  binario). PENDIENTE encadenado al encendido: "Publicar app" en GCP (en Prueba solo los test users
  pueden firmar).
- **PROD (`kefvaiymtgytemwbltlz`): Google NO configurado aún** — se configura en el encendido
  (Bloque C), misma config exacta (el mismo par de client IDs sirve: el `aud` es del client de
  Google, no del proyecto Supabase).
- **Gateway/Worker: cero cambios** (verifica JWTs por JWKS sin mirar provider; los goldens de
  account ya ejercitan `provider: "google"`).
- Cliente: `CloudAuthService.signInWithGoogle()` (SDK GoogleSignIn-iOS 9.2.0 SPM, solo target Yala)
  + par `(googleUserID, sub)` en `GoogleUserPairStore` (molde `SIWARefreshTokenStore`; consumidor =
  el revoke de sesión 3, **HECHO** — `GoogleTokenRevocation`, ver §"Google revoke" arriba) +
  `cloudauth.provider` como fuente del `provider` del claim — desde la sesión 3 el executor de
  migración lo lee VIVO en cada uso (closure, residual I4 cerrado): un runner nacido antes del
  sign-in ya no congela `"apple"` para una sesión Google (ni en el claim ni en el faro R9).

### Guard R9 SUB-FIRST (sesión 2 — UI + chooser, 2026-07-16)

**H4 manda: GoTrue LINKEA identidades con el mismo email verificado al MISMO `sub`** (verificado en
el WIRE de la sesión 1: el sign-in Google del owner aterrizó en su user Apple — identities
apple+google, `profiles.provider` conserva `'apple'`). Consecuencia de diseño: **la señal de
"firmaste con el método equivocado" es el SUB, JAMÁS el provider a secas** — comparar providers
daría falso mismatch en todo linking legítimo.

`ProviderMismatchLogic.decide` (pura, `Yala/App/Logic/ProviderMismatchLogic.swift`, tabla en
`ProviderMismatchLogicTests`) corre SOLO dentro de la rama `.accountMissing` de
`WelcomeCloudSignInView.runSignInFlow`, con el faro `CloudBeacon` como referencia. Reglas en orden:
(1) `exists==true` ⇒ proceed SIEMPRE — protege la entrada secundaria M1 (el faro es del DUEÑO) y el
linking H4; (2) sin faro ⇒ proceed (`.notFound` normal); (3) hash del faro == hash del sub de la
sesión ⇒ proceed (cuenta borrada server-side, `.notFound` honesto); (4) mismo provider ⇒ proceed
(la hipótesis "método equivocado" está muerta — el provider jamás dispara solo); (5) resto ⇒
`.mismatch(knownProvider:)` → canario `cloudSignInProviderMismatch` (primer call-site real) +
`signOut()` + **NO claim** + fase `.providerMismatch` ("vuelve atrás y entra con ese método").
Con estas reglas `.mismatch` solo es alcanzable con `exists==false` ⇒ el flujo Apple existente
(adopt/secundaria/blocked/notFound) queda byte-idéntico.

**Red post-claim (también sub-first):** `CloudAccountClient.claim` decodifica `profile.provider`
ADITIVO y, si difiere del provider de la sesión, emite SOLO el breadcrumb
`claimProfileProviderDiffers` — post-claim el sub es EL MISMO por construcción (claim JWT-scoped)
⇒ por H4 es identity-linking legítimo: JAMÁS alerta ni canario (el falso mismatch que el brief H4
corrige). R9 real solo reproducible con Hide My Email (emails distintos ⇒ subs distintos).

## Proyecto Supabase de PRODUCCIÓN (DIFERIDOS #23 — creado 2026-07-11)

Proyecto **`kefvaiymtgytemwbltlz`** (`yala-modo-nube-production`), organización dedicada
**`yala-production`** (plan Pro — separada de la org free donde vive staging, aislando billing y
blast-radius), **us-east-1** (= staging), Postgres 17.6.1.141 (= staging). El MCP de Supabase
autoriza UNA org a la vez → para operar staging y prod hay que re-conmutar el conector.

**Schema replicado de staging vía 3 migraciones bootstrap** (historial de migraciones de prod):

- `prod_bootstrap_01_schema` — las 21 tablas: el `supabase-staging.ddl` del repo (contrato offline)
  + **`profiles`** extraída del vivo (NO está en el .ddl: `id` PK=sub, `provider`,
  `leader_device_id`, `migration_in_progress`, `migrated_at`, `migration_updated_at`,
  `reverse_in_progress`, `reverse_frozen_at`, `reverted_at`, `created_at`).
- `prod_bootstrap_02_rls_grants` — cola uniforme extraída verbatim del vivo: 17 triggers
  `stamp_server_seq`, 19 índices, RLS ON en las 21, **78 policies** con nombres exactos de staging
  (asimetrías intencionales: `profiles` sin policy DELETE, `report_claims` solo select/insert,
  `sync_seq_counters` solo select) + REVOKEs (DELETE global; `report_claims` también UPDATE;
  `sync_seq_counters` INSERT/UPDATE/DELETE).
- `prod_bootstrap_03_functions` — las 6 funciones con la functiondef VIVA de staging
  (`pg_get_functiondef`, 2026-07-11) aplicada VERBATIM: `apply_delta`, `apply_pref`,
  `claim_account` (3-arg con `p_migration`), `claim_report`, `migration_progress` (versión completa:
  cutover/complete + 4 `reverse_*` con CAS `i11_reverse_claim_cas` + `heartbeat` de
  `i14_heartbeat_action`), `stamp_server_seq` + ACLs del lockdown i5_11 (`stamp_server_seq` solo
  service_role; `apply_delta`/`apply_pref`/`claim_report` solo authenticated;
  `claim_account`/`migration_progress` default PUBLIC — inerte sin JWT, igual que staging).
  **NO replicado (a propósito):** tablas `spike_*`, `spike_apply_delta`, usuarios de test, datos.

**Verificación (2026-07-11):** conteos estructurales = staging sin spikes (21 tablas / 21 RLS / 78
policies / 17 triggers / 19 índices / 6 funciones) · columnas de las 16 tablas de dominio conformes
al contrato del .ddl (query compacta de `dump-schema.sh`) · security advisors de Supabase: 0
hallazgos · **gate RLS `cross-user-rls-test.sh` contra prod: 18/18** (usuarios efímeros
`rls-a/b@test.yala`, borrados post-gate — el CASCADE de `auth.users` limpia sus filas) · Auth
v2.192.0 (gotcha issuer SIWA ≥2.177.0 cubierto).

**Auth de prod (decisiones owner 2026-07-11):** provider **Apple** ON (Client IDs
`com.jurgenschmidt.yala,com.jurgenschmidt.yala.dev`, secret vacío — flujo nativo); provider
**Email OFF** (solo se re-habilita temporalmente para correr el gate RLS, que usa password grant —
gotcha: con Email OFF el login devuelve `email_provider_disabled`); Google NO configurado aún en
prod — la decisión "fase web/Android" fue REVERTIDA (2026-07-16, brief Google Sign-In): se
configura en el encendido con la misma config de staging (ver §"Google Sign-In" arriba);
**inactivity-timeout 720 h (30 días)** + **time-box 0 (never)** — la mitigación
server-side de DIFERIDOS #23 (racional en el vault, `MODO-NUBE-DIFERIDOS.md` §23).

**Gateway:** `gateway/wrangler.toml` `[env.production.vars]` apunta a este proyecto (URL + anon
key reales). ~~El Worker de producción NO está desplegado~~ **DESPLEGADO 2026-07-16 (gate §12
Bloque A, pedido explícito del owner)** — primer deploy en la historia del Worker
`yala-gateway-production` (la app de PRODUCCIÓN ya apuntaba a él vía `ProxyConfig` #else). Secrets
cargados (7): `OPENAI_API_KEY` + `EXCHANGE_RATE_API_KEY` (los de `Secrets.xcconfig` — la de OpenAI YA ES LA
ROTADA, confirmado por el owner 2026-07-16: la extraíble del archive del build 18 fue revocada;
el comentario del xcconfig quedó desactualizado) · `JWT_SIGNING_SECRET` PROPIO de prod (generado 2026-07-16, copia en
`~/Secrets/yala-gateway/prod-jwt-signing-secret`) · `GROUPS_ENC_KEY` de prod
(`~/Secrets/yala-groups-enc/prod.key`, DISTINTA de staging) · `PUSH_ROLE_JWT` de prod (acuñado con
`mint-push-role-jwt.mjs` + legacy secret de prod; verificado 200 [] contra PostgREST prod, y el
golden invertido anon → 42501) · `APNS_AUTH_KEY` (7H6BUZWKKS reusada, decisión owner) ·
`SIWA_AUTH_KEY` (PQ53RQ5D3G, B1). `APNS_KEY_ID = "7H6BUZWKKS"` como var. `DEV_SHARED_SECRET` NO
existe en prod (a propósito). `APP_STORE_API_KEY` NO cargado (pendiente-owner si el webhook de prod
lo necesita). Smoke post-deploy: GET /groups/pull|/groups/merkle y POST /groups/push|/sync/push|
/account/siwa/exchange sin JWT → 401; /account/exists sin JWT → 401.

**PROMOCIÓN DEL STACK DE GRUPOS + g12 (2026-07-16, gate §12 Bloque A) — DRIFT CERRADO:** las 13
migraciones aplicadas EN ORDEN con el diff DERIVADO de list_migrations (jamás asumido) y el SQL
extraído BYTE-EXACTO del historial de staging (md5 por archivo == md5(statements[1]) 17/17):
g1_01b_reapply_groups_infra_after_drop (≡ g1_01 + RLS fix — la terna del incidente g1_01/enable_rls/
drop_spike se NETEA a ella, probado por construcción; los spikes g0_* se saltaron [la extensión
pgcrypto ya estaba: `extensions` v1.3 = staging]) · g1_02 · g2_01 · g3_01 · g3_02 · g5_01 · g6_01 ·
g6_01b · g7_01 → **sandwich recrypt ×2 con la llave PROPIA de prod (corpus vacío → 8 columnas en 0)**
→ g7_02 · g8_01 · g8_02 · **g12_01** (con el assert previo `rolbypassrls(postgres)=true` ✓).
Verificación post-aplicación: **md5(pg_get_functiondef) idéntico staging↔prod en las 33 funciones**
(incl. delete_personal_account post-g12 `6bafd85a…`) · rol `yala_push` (nologin, sin BYPASSRLS,
grantado a authenticator) · proacl de los 2 RPCs de push = `{postgres, service_role, yala_push}` ·
`yala_logging_settings()` = ddl/-1/0 (§16e — prod ya venía correcto) · estructural: 29 tablas
(21+8) TODAS con RLS, 96 policies (78+18), 22 triggers (17+5), 55 índices (40+15) — cuadre exacto ·
security advisors: hallazgos = los by-design (RPCs SECURITY DEFINER expuestos a authenticated SON la
API; deny-all de group_seq_counters) + 1 WARN de higiene en `stamp_group_seq` (EXECUTE default
PUBLIC — inofensivo: Postgres rechaza invocar trigger functions directamente; CERRADO por g12_02:
aplicada en AMBOS envs 2026-07-16, ver §g12_02 arriba — proacl verificado en vivo contra staging).

**ADDENDUM 2026-07-21 (el conteo de arriba es la foto del 2026-07-16, no la de hoy):** desde entonces
entró UNA migración de grupos más, `g10_01_transfer_group_ownership` (aplicada a staging el 2026-07-20,
promovida a prod el 2026-07-21 — versión prod `20260721212213`). ⇒ hoy la paridad es **34/34 funciones**,
no 33/33. Ver §transfer_group_ownership arriba para su post-check (que además ENDURECE el método: el
`md5(pg_get_functiondef)` de este bloque no cubre `proowner`/`proacl`, y en un SECURITY DEFINER cuyo dueño
no fuese el de las tablas la RPC fallaría en silencio con el md5 cuadrando). El **gateway** de prod quedó
redesplegado el mismo día (Version ID `078bc707…`) ⇒ DB y Worker de prod al día, sin drift pendiente.

**Paridad de funciones VERIFICADA byte-exacta (2026-07-11):** `md5(pg_get_functiondef)` idéntico
staging↔prod en las 6 — apply_delta `7f8cb94d32f3976b6a9b0ade8f165b73`, apply_pref
`9ca95ec43db6aae72ab958bab68498d0`, claim_account `6f9d2bc967ed2402c39b20d4d42e7e99`, claim_report
`d4180fd245bc755e652f82d8159e3a70`, migration_progress `1768ad02de1cb25bf3fbfe458d22771e`,
stamp_server_seq `62ec7acb7d9eb68ff9b01415984b54ab`. Query de re-verificación (ambos proyectos):
`SELECT proname, md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON
n.oid=p.pronamespace WHERE n.nspname='public' AND proname NOT LIKE 'spike%' ORDER BY 1;`
**Regla anti-drift:** toda migración futura de staging (`i*`) debe re-aplicarse a prod en el mismo
cambio o anotarse aquí como drift pendiente (el MCP autoriza una org a la vez — re-conmutar).

## Related repo artifacts

- `capability_manifest.json` (repo root) — per-entity domain columns with explicit `safe` / `group_key`.
- `supabase-staging.ddl` (repo root) — snapshot-contract of the live schema.
- `YalaTests/CloudSync/CloudCapabilityManifestParityTests.swift` — parity: manifest ↔ frozen coherence groups ↔ snapshot (runs offline in CI).

## I14 — UI real de migración + consent + claimAction + relaunch asistido + encendido de flags

Último incremento de la Fase 4 del Modo Nube. Cierra el gate de flags: `syncRuntimeEnabled = true` con
las redes que hacen su encendido demostrablemente inerte para los usuarios actuales.

**Gate del runtime del dominio (P0, `CloudSyncRuntime.start()` + `handleBecameActive`).** El runtime del
dominio solo corre con `canRunDomain()` == true: `storageMode == .cloud` **Y** la fase de migración
ESTABLE (`MigrationRuntimeGate.isDomainStablePhase` = `done`/`notStarted`). Seguridad de encender el flag:
(a) prod placeholder → `CloudBackendConfig.isConfigured == false` → `NoopCloudSessionProvider` → `start()`
cae en `idleSignedOut`; (b) TODOS los devices de producción son `.icloud` → el guard de `storageMode`
corta antes de tocar red/store; (c) staging/DEV: solo `.cloud`+fase estable+sesión+claim proceed-like.
En fase transicional quien conduce es el `MigrationRunner`; el coordinator de boot (P4) re-arranca el
runtime al quedar estable (`startShared` es idempotente — no-op si ya corre).

**Guard de IDENTIDAD (P6).** En `.cloud`, un `currentUserID` SIN registro de claim → runtime `.idle` +
canario `cloudSyncBlockedByUnclaimedIdentity`. El registro lo estampa `CloudClaimActionStore` (UserDefaults,
keyed por userID) en `MigrationWorkExecutor.performClaim` (migración) y en `runAdoptFlow` (adopt).
`LiveCloudSessionProvider.claimAction` lo LEE para el userID actual → el gate `shouldStartSync` deja de
recibir el `nil`-inseguro. `signOut` NO borra los registros (keyed por userID → re-sign-in del MISMO usuario
no se bloquea; un Apple ID DISTINTO en un device migrado no pushea el corpus del dueño).

**Adopt (#30, P6).** `execute(.adoptBackendAccount)` ya NO es `notWired`: llama `runAdoptFlow()`, ORDEN
EXACTO — quiescencia del import → `runAdoptOrphanReconcile` (`.transient` → THROW retomable) →
`fastForwardHistoryBaseline` (sin él el primer drain re-emitiría el corpus importado) → verificación del
marcador local (belt, no bloquea) → persistir el PAR `.cloud`+`mirrorOffArmed` + estampar el claim-store
(`routeReturningUser`) → re-persistir las 2 keys de consent al outbox de prefs (el drenaje iKV es
LÍDER-only y jamás las llevaría). El relaunch asistido lo deriva la UI del par persistido (mirror armado +
mount `.icloud` → `needsRelaunch(.toCloud)`); NUNCA `exit()`. La entrada del adopt en la UI SIEMPRE fluye
por `startMigration` (consent → SIWA → claim `existing_stable` → la máquina rutea a `notStarted` + adopt);
el marcador (`secondaryDeviceCloudLogin` vía `markerReconciliation`) solo cambia el COPY de la card, sin
doble confirmación destructiva extra.

**Consent (§2.8/§k.6, P5).** `CloudConsentView` (los 7 puntos: qué sale incl. texto de recibos NO imagen,
chat IA ~13 meses, equipo puede leer, servidores en EE.UU., "mientras conserves ese login" + export, reversa
sin perder nada). Al aceptar registra `cloudConsentAcceptedAt` + `cloudConsentTextVersion`
(`CloudConsentText.version = 1`) — keys nuevas en `PrefSyncKey` (34→36, familia `intPresence`) → en `.icloud`
van a iKV y el drenaje del cutover las lleva al backend; en `.cloud` (adopt) directo al outbox de prefs.
Métrica `cloudConsentAccepted(path: migration|adopt)`.

**Visibilidad (P3).** La fila "Almacenamiento" de Ajustes → Datos aparece SOLO si
`CloudBackendConfig.isConfigured` (prod placeholder sin cambios visibles). La fila "iCloud" se oculta en
`.cloud` (`iCloudSyncSettingsView` mentiría — la vista bifurcada por modo es I12). `checkForICloudMismatch`
ya era `storageMode`-aware (w6) — en `.cloud` tener cuenta iCloud NO es mismatch.

**DIFERIDOS #33 (veredicto I14).** `historyPurgeEnabled` se queda `true` (S2 device-verde; sin purga la
History crece sin cota). El hazard #33 (token in-decodificable + purga activa → full-rescan re-emite el
corpus con HLC fresco) es de COSTO, no de corrección (LWW-idempotente server-side), y v1 = dogfooding
single-device del owner. **Gatillo movido al escalón de beta cerrada:** acotar el full-rescan antes de beta.

**DIFERIDO #34 — `cloudModeEnabled` remote-config: ✅ CERRADO (2026-07-17)** — ver la sección
"Remote-config `GET /config`" al final de este archivo.

**Tests (P8).** `YalaTests/CloudSync/CloudMigrationI14Tests.swift` (gate P0 · boot decision P4 · UIState
derive P2 · claim-store round-trip + gate de arranque P6) + `MigrationWorkExecutorTests` (runAdoptFlow orden
persiste `.cloud`+armed+claim-store; performClaim estampa `proceedMigration` — contenido real, lección
`d49d2e47`) + `PreferenceMergeLogicTests.taxonomy_36Keys`. l10n: 55 keys `storage.*` en los 16 locales
(`LocalizationParityTests` verde).

## Remote-config `GET /config` (DIFERIDOS #34 — kill-switch sin release, §j.1/§j.2)

**Endpoint** (2026-07-17): `GET /config` en el Worker, PÚBLICO (sin auth/attest, sin bindings D1/KV —
un kill-switch no puede caerse por dependencias). Shape v1:

```json
{"v":1,"flags":{"cloudModeRolloutPercent":0,"cloudOnboardingChoiceRolloutPercent":0,"groupsBackendRolloutPercent":0}}
```

Percents 0-100 por flag (decisión owner: escalón gradual §j.2 desde el día 1; 0=OFF, 100=ON).
**Dónde viven los valores:** `gateway/wrangler.toml` `[vars]` (staging=100 los 3; QA no pierde
superficie) y `[env.production.vars]`. **Producción, desde el 2026-07-30 (`0b1283fe`, desplegado):
`cloudModeRolloutPercent` = 100, los otros dos en 0.** El de Modo Nube NO es un valor de prueba: es
lo que exige la decisión de migración opt-in silencioso de 2.1. Patrón ENFORCE: **flip = editar la
var + `npm run deploy:production`** (el script de npm, no `wrangler` a pelo: su `predeploy` sincroniza
el manifest), versionado en git, sin release del cliente. ⚠️ El valor commiteado **no está en
producción hasta que corre el deploy** — git puede decir 100 mientras el Worker sirve 0. Parse
server-side fail-closed (ausente/inválido → 0, clamp [0,100]). `Cache-Control: public, max-age=300`
gobierna el URLCache del CLIENTE (CF no cachea edge sin Cache API; costo trivial a ≤1 req/6h/device).
Verificación: `curl https://yala-gateway-{staging,production}.misty-surf-6866.workers.dev/config`.
Tests: `gateway/test/config.test.ts` (unit, sin red).

**Cliente iOS:** `CloudRemoteConfig.swift` (snapshot en `UserDefaults.standard` bajo
`cloudSync.remoteConfig.*` — sobrevive sign-out por el carve-out `cloudSync.*`; extensiones no lo
leen) + `RemoteFlagDecisionLogic` (pure: bucket FNV-1a estable por instalación [seed UUID persistido
una vez — el golden de vectores fijos protege las cohortes], `bucket < percent`, percent nil →
`absentDefault` [DEV=ON para QA/uitest sin fetch; prod=OFF fail-closed], refresh min-interval 6 h con
futuro=stale). Fetch fire-and-forget en boot (14.56, gateado `isConfigured && !uiTestActive`) + los
`.task` de WelcomeFlowContainer y StorageSettingsView (re-verificación en la puerta). Last-cached-wins
SIN TTL de expiración: todo flujo gateado exige red al ejecutarse. Bajo unit/UI tests los getters
IGNORAN `.standard` (determinismo); `-uitest-reset` limpia snapshot + toggle DEBUG.

**Semántica de kill (ratificada por el owner 2026-07-17): OFF corta solo la ENTRADA.**

| Flag en 0 | Corta | NO corta |
|---|---|---|
| `cloudModeRolloutPercent` | fila Almacenamiento (no-migrados), cards sign-in nube del Welcome (Apple/Google/born-cloud), entrada secundaria M1 | runtime/outbox/pull de un `.cloud` existente; su fila (engaged: `.cloud` persistido ∨ `uiState != .idle`) con resume y REVERSA; secundaria YA activa |
| `cloudOnboardingChoiceRolloutPercent` | card born-cloud del Welcome (exige AMBOS flags) | — |
| `groupsBackendRolloutPercent` | composición `compilado && remoto` de `CloudSyncFlags.groupsBackendEnabled` (hoy compilado=false ⇒ inerte) | — |

Residual ratificado: un usuario nube que REINSTALA bajo el kill no ve la card de sign-in → no re-entra
hasta re-encendido (propósito del kill; datos server-side intactos). ⚠️ **Nota para la sesión de
ENCENDIDO de Grupos** (compilado → true): un kill remoto transitorio congela el canal (outbox
retenido, sin pérdida) y desvía creaciones a CloudKit, pero también cambia el shape de los paths de
teardown que leen el getter (sign-out push-all, borrado GDPR) — decidir entonces si esos paths leen el
compilado directo. Ídem: los tests que quieran la composición REAL deben llamar
`_testResetGroupsBackendEnabledOverride()` primero (el idiom `= true; defer { = false }` deja override).

**QA:** panel DEBUG (CloudSyncDebugView → card "Remote cfg"): snapshot + bucket + efectivos + toggle
"Simular remote OFF" (key `cloudSync.debug.remoteFlagsForceOff`, solo DEV) + botón "Fetch /config
ahora" (force, salta min-interval y URLCache).

## Telemetría propia `POST /metrics` (2026-07-17 — sustituye TelemetryDeck)

**Endpoint** público (sin auth/attest, molde `/config`) → **Workers Analytics Engine** (binding
`METRICS`; dataset `yala_metrics_staging` en staging, `yala_metrics` en prod — **retención AE: 90
días**; series más largas requieren export periódico, diferido D3). Wire v1:

```json
{"v":1,"install":"<sha256(bucketSeed) truncado 16 hex>","app":"2.0.5","events":[
  {"e":"ping"},
  {"e":"register","n":"local","d":"groupsOnly"},
  {"e":"canary","n":"cloudSyncMerkleDivergence","d":"tx_items","x":3}]}
```

Eventos: `ping` (activos/día — el CLIENTE garantiza ≤1/día con guard local `metrics.lastPingDay`,
día UTC), `register` (`n`=`local`|`cloud`; `d`=modo: full/groupsOnly/groupInvite/migration/bornCloud)
y `canary` (los wrappers typed de `MetricsService` — el gate "canarios en cero" del Bloque C se lee
AQUÍ). Validación estricta server-side (whitelist de eventos, `n` regex `[A-Za-z0-9_.-]{1,64}`,
`d`≤128, batch cap 25, body cap 8KB, install hex 16-64) → 400 `yala_bad_input`; binding ausente →
200 `accepted:0` (el cliente NO debe reintentar por config server-side). Mapeo AE por evento:
`blobs [e, n, d, appVersion, install]` · `doubles [x]` · `indexes [install]`.

**Privacidad:** `install` = SHA-256 truncado del `bucketSeed` local (UUID por instalación, carve-out
`cloudSync.*`) — no reversible, no enlazable a cuenta; JAMÁS viaja userID/email/dato financiero.

**Queries de referencia** (dashboard CF → Analytics Engine → SQL). ⚠️ AE **muestrea**: los counts
correctos son `sum(_sample_interval)`, JAMÁS `count()` a secas. Validadas contra el dataset real en
el deploy — ajustar si el SQL de AE difiere:

```sql
-- DAU (el guard client-side once-per-day hace que esto ≈ usuarios activos/día):
SELECT toStartOfInterval(timestamp, INTERVAL '1' DAY) AS day, sum(_sample_interval) AS dau
FROM yala_metrics WHERE blob1 = 'ping' GROUP BY day ORDER BY day DESC;

-- Registros/día por tipo (blob2 = local|cloud, blob3 = modo):
SELECT toStartOfInterval(timestamp, INTERVAL '1' DAY) AS day, blob2 AS kind, sum(_sample_interval) AS n
FROM yala_metrics WHERE blob1 = 'register' GROUP BY day, kind ORDER BY day DESC;

-- Canarios (GATE DE ENCENDIDO: cero filas = verde). blob4 = versión de app que lo emitió:
SELECT blob2 AS canary, blob3 AS detail, blob4 AS app, sum(_sample_interval) AS n
FROM yala_metrics WHERE blob1 = 'canary' GROUP BY canary, detail, app ORDER BY n DESC;

-- Tamaño REAL de la flota. `install` es por INSTALACIÓN, así que en dogfooding sobreestima
-- muchísimo (reinstalar cuenta como device nuevo): calibra con `register`, no con installs.
SELECT blob1 AS event, count(DISTINCT blob5) AS devices, sum(_sample_interval) AS n,
       min(timestamp) AS primero, max(timestamp) AS ultimo
FROM yala_metrics GROUP BY event ORDER BY n DESC;

-- Barredor de huérfanas puenteadas (A2 de la Fase 3). El detail de `Deferred` desglosa por
-- veredicto: solo `cloudKitChannelIdle` y `cloudKitZoneFetchFailed` son del brazo CloudKit.
SELECT blob2 AS canary, blob3 AS detail, count(DISTINCT blob5) AS devices,
       sum(_sample_interval) AS n, max(timestamp) AS ultimo
FROM yala_metrics
WHERE blob1 = 'canary'
  AND (blob2 = 'bridgedTxOrphanSweepDeferred' OR blob2 = 'bridgedTxOrphansRepaired')
GROUP BY canary, detail ORDER BY n DESC;
```

**Sin navegador:** el dashboard exige loguearse con **`admin@yala-app.pe`** — la cuenta personal
`Jur211296@gmail.com` da «Unauthorized to access requested resource», que engaña porque parece un permiso
que falta y es OTRA cuenta (`npx wrangler whoami` lo resuelve en un comando). Para consultar por API hay un
token de solo-lectura (scope único *Account Analytics Read*, caduca 2027-08-05) en
`~/Secrets/yala-cloudflare/analytics-read.token`:

```bash
T=$(cat ~/Secrets/yala-cloudflare/analytics-read.token)
curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/86c270a7776be98639700bd5959b303b/analytics_engine/sql" \
  -H "Authorization: Bearer $T" --data-binary "<SQL> FORMAT JSON"
```

⚠️ **El punto ciego del barredor, medido el 2026-08-04: «el gate lo frenó» y «no había candidatas» son
INDISTINGUIBLES aquí, los dos son silencio.** `OrphanedBridgedTxSweeper.sweep` está detrás de dos gates
asíncronos (`awaitPersonalStoreReady` y `awaitGroupsChannelEvidence`, `AppBootstrapper.swift:428-438`) y si
el segundo se rinde a los 60 s el barredor **no llega a correr** ⇒ no emite nada: su único rastro es un
`SaveBreadcrumb`, que va a Console.app y **no** a Analytics Engine. Y el canario positivo
(`bridgedTxOrphansRepaired`) sale detrás de un `guard !outcome.isEmpty` ⇒ un barrido que corre y encuentra
todo limpio también calla. ⇒ **el silencio NUNCA cierra una pregunta sobre este subsistema; solo la señal
positiva decide.** Y el sesgo es adverso: para emitir, un device necesita al menos una zona FRESCA además de
las paradas, así que el perfil más afectado —solo grupos CloudKit legacy con el canal quieto— es justo el que
no reporta.

Residuales documentados: evento retenido en el spool offline del cliente se estampa el día del ENVÍO
(distorsión solo offline multi-día); sin rate-limit por IP (D2 — validación estricta + AE barato);
alerting = consulta manual del dashboard (D5, paridad con lo que había). Tests:
`gateway/test/metrics.test.ts` (unit, sin red). Cliente iOS: `Yala/Services/Metrics/`.

## Vaciar (wipe masivo por filas) — caracterización del drain en `.cloud`

**Contexto (Vaciar v2, §3.3.1 punto 6 / D2).** "Vaciar mis datos" (`DataWipeService.wipeAllUserData`) borra
el corpus personal por FILAS con el store montado. Los dos modos difieren en cómo se propaga ese borrado, y
son MECANISMOS DISTINTOS — no confundirlos:

- **`.icloud` (VIVO hoy):** el mirror de `NSPersistentCloudKitContainer` está montado → el replay de la
  History EXPORTA los deletes a iCloud (invariante (a), usado A FAVOR: el copy declara "también se borra de
  iCloud"). No pasa por el outbox/drain del Modo Nube.
- **`.cloud` ([FLAG]):** el mirror está OFF; el motor del Modo Nube captura los deletes de la History y los
  drena al **outbox como TOMBSTONES** hacia el backend. **Este es el path que caracteriza el test** — el
  substrato del residual multi-device (`multiDeviceResidual`, D9).

**Resultado de la caracterización** (`YalaTests/CloudSync/WipeMassRowsCloudDrainTests.swift`, container
ON-DISK 3 stores): el drain emite **exactamente 1 tombstone por fila personal sync-eligible** que existía al
vaciar, cada uno con su `syncID` preservado. El volumen del outbox es, por tanto, **~1:1 con el tamaño del
corpus** (un vaciado de N filas sync-eligibles ≈ N tombstones). No hay amplificación oculta: los clears de
relaciones del wipe (`setTags`, `budget.setFilters`) emiten `upsert`, no tombstone; el conteo estricto se
hace sobre `opRaw == tombstone`.

**Load-bearing (no simplificar):** el test hace `seed → save → DRAIN → wipe → drain`. El `drainOnce`
INTERMEDIO es obligatorio: sin él, los deletes salen SIN `syncID` asignado → *identity gap*, NO tombstone
(ver `CloudSyncEngineTests` `drain_deleteWithoutSyncID_recordsIdentityGap_noRow`). En producción el device
`.cloud` drena periódicamente, así que el syncID ya está asignado cuando se borra.

**Caveats del test:** protege `UserDefaults.standard` con snapshot/restore del `persistentDomain` en `defer`
(molde `DataWipePreservesGroupsTests`) porque `wipeAllUserData` resetea prefs + singletons
(`AppRouter`/`ProTourManager`/`SetupChecklistManager`); ese snapshot cubre SOLO `.standard` (no App
Group/TipKit/singletons) — tolerable en `.serialized`. Corre con `broadcastSignal: false` (no toca el iCloud KV).

**Veredicto (gate de QA, NO bloqueante):** el volumen 1:1 es proporcional al corpus y pasa por el drain
normal (coalescing/retry del motor) — **sin patología detectada** en la caracterización. Si en device real
con un corpus grande (10k+ filas) el drain de tombstones resultara costoso (latencia/lease), es un **proyecto
aparte** (dimensionar el drain masivo), no un fix de este chip — cruza con §5.2.2 del estudio
`MODO-NUBE-GESTION-DATOS-UX.md` y con el residual D9. No caracterizado aún: interacción con el gate de
quiescencia bajo un import concurrente.

## Addendum 2026-07-28 — `migrate_group` queda INERTE (Fase 1 de simplificación de Grupos)

`POST /groups/rpc/migrate_group` pasa a devolver **404 por diseño** — retirado de `PARAM_ALLOWLIST` en
`gateway/src/groups/rpc.ts`, el gateway corta antes de tocar PostgREST — **efectivo al desplegar** el Worker
(pendiente del owner: `deploy:staging` → `deploy:production`). La función `public.migrate_group` **sigue
existiendo a propósito** en ambos envs: NO se dropea, y el §4 del DDL, los «33/33» y los md5 de arriba siguen
siendo verdad. Sus goldens G6 se retiraron con la Fase 1; el fixture de G10 nº2 se re-sembró sin ella.
