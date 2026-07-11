# qa/cloud — Modo Nube backend contract checks (I5)

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

Defaults target staging with the anon key and the two seeded users (`i5-user-a@test.yala` /
`i5-user-b@test.yala`). Override via env: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`USER_A_EMAIL`/`USER_A_PASS`, `USER_B_EMAIL`/`USER_B_PASS`.

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
- **Goldens 19-21** (`account.goldens.test.ts`, sub B — VIVEN ahí y no en sync.goldens porque vitest
  corre los archivos en paralelo y congelar a sub A rompería los pushes concurrentes de sync.goldens):
  409 + type + leak delta[0]/bloqueo delta[1]; pull/merkle 200 congelada; des-congelada → noop/applied.
- **Residual (documentado, fuera de scope):** `/prefs/push` NO se gatea — un device rezagado puede
  pushear prefs a un backend congelado (mismo perfil de riesgo: converge sin corromper; las prefs de la
  época nube quedan en un backend muerto).

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

## Related repo artifacts

- `capability_manifest.json` (repo root) — per-entity domain columns with explicit `safe` / `group_key`.
- `supabase-staging.ddl` (repo root) — snapshot-contract of the live schema.
- `YalaTests/CloudSync/CloudCapabilityManifestParityTests.swift` — parity: manifest ↔ frozen coherence groups ↔ snapshot (runs offline in CI).
