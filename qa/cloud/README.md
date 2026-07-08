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

## Related repo artifacts

- `capability_manifest.json` (repo root) — per-entity domain columns with explicit `safe` / `group_key`.
- `supabase-staging.ddl` (repo root) — snapshot-contract of the live schema.
- `YalaTests/CloudSync/CloudCapabilityManifestParityTests.swift` — parity: manifest ↔ frozen coherence groups ↔ snapshot (runs offline in CI).
