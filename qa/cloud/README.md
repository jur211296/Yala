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

## Related repo artifacts

- `capability_manifest.json` (repo root) — per-entity domain columns with explicit `safe` / `group_key`.
- `supabase-staging.ddl` (repo root) — snapshot-contract of the live schema.
- `YalaTests/CloudSync/CloudCapabilityManifestParityTests.swift` — parity: manifest ↔ frozen coherence groups ↔ snapshot (runs offline in CI).
