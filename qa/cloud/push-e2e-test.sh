#!/usr/bin/env bash
# Sender e2e (I8e) — SyncPushClient wire contract against the LIVE staging Worker.
#
# Exercises POST /sync/push with the SAME JSON envelope SyncPushClient builds (RawJSON-crudo fields,
# hlc-de-fila, client_mutation_id), then verifies the effect with execute_sql (run separately via MCP).
# Uses ONLY the anon key + user-A JWT (password grant). NEVER service_role. Does NOT run in CI.
#
# Scenarios:
#   (a) upsert a real tx_items delta      → 200 applied  (verify row exists via execute_sql)
#   (b) idempotency: re-push same delta   → 200 noop
#   (c) coherence_group_partial forge     → 200 rejected (reason coherence_group_partial:money)
#
# FRESH sync_id per run (UUID). DELETE is REVOKED on staging → rows ACCUMULATE. Clean up by user_id via
# the Supabase SQL editor / MCP (service context) — this script never uses service_role.
#
# Env overrides: SUPABASE_URL, SUPABASE_ANON_KEY, WORKER_URL, USER_A_EMAIL/PASS.
set -uo pipefail

URL="${SUPABASE_URL:-https://fostjbbwstyuunmmefuk.supabase.co}"
ANON="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg}"
WORKER="${WORKER_URL:-https://yala-gateway-staging.misty-surf-6866.workers.dev}"
A_EMAIL="${USER_A_EMAIL:-i5-user-a@test.yala}"; A_PASS="${USER_A_PASS:-I5-Passw0rd-A!}"

login() {
  curl -s -X POST "$URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))"
}
sub_of() { python3 -c "import sys,base64,json; t='$1'.split('.')[1]; t+='='*(-len(t)%4); print(json.load(__import__('io').BytesIO(base64.urlsafe_b64decode(t))).get('sub',''))"; }

JWT_A="$(login "$A_EMAIL" "$A_PASS")"
[ -n "$JWT_A" ] || { echo "FATAL: could not obtain JWT"; exit 2; }
SUB_A="$(sub_of "$JWT_A")"
echo "user A sub = $SUB_A"

SID="$(python3 -c 'import uuid;print(uuid.uuid4())')"
CMID="$(python3 -c 'import uuid;print(uuid.uuid4())')"
CMID2="$(python3 -c 'import uuid;print(uuid.uuid4())')"
HLC="2026-07-08T00:00:00.000Z-0001-0123456789abcdef"
echo "sync_id = $SID"
echo

push() { # json-body -> prints body
  curl -s -X POST "$WORKER/sync/push" \
    -H "Authorization: Bearer $JWT_A" -H "Content-Type: application/json" -d "$1"
}

# (a) upsert a real tx_items delta — safe (field-level) columns only, RawJSON-crudo fields verbatim.
DELTA_A=$(cat <<JSON
{"deltas":[{"entity_type":"tx_items","sync_id":"$SID","op":"upsert","fields":{"date":"2026-07-08T00:00:00.000Z","local_day":"2026-07-08","currency_code":"USD","note":"i8e-e2e"},"field_hlcs":{"date":"$HLC","local_day":"$HLC","currency_code":"$HLC","note":"$HLC"},"hlc":"$HLC","client_mutation_id":"$CMID","schema_version":1}]}
JSON
)
echo "(a) upsert real delta:"
push "$DELTA_A"; echo; echo

# (b) idempotency — re-push the SAME delta (same sync_id + hlc) → noop.
echo "(b) idempotency (re-push same delta):"
push "$DELTA_A"; echo; echo

# (c) coherence_group_partial forge — touch `amount` (group money) WITHOUT the rest of the group → rejected.
DELTA_C=$(cat <<JSON
{"deltas":[{"entity_type":"tx_items","sync_id":"$SID","op":"upsert","fields":{"amount":"9.9900"},"field_hlcs":{"money":"$HLC"},"hlc":"$HLC","client_mutation_id":"$CMID2","schema_version":1}]}
JSON
)
echo "(c) coherence_group_partial forge (amount only):"
push "$DELTA_C"; echo; echo

echo "Verify row via execute_sql (service/MCP):"
echo "  select sync_id, note, currency_code, hlc from public.tx_items where sync_id = '$SID';"
