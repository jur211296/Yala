#!/usr/bin/env bash
# Cross-user RLS gate (§2.3) for the Modo Nube staging schema (I5).
#
# For EACH of the 18 tenant tables (16 domain + user_preferences + attest_keys — CLOSED list,
# EXCLUDES the spike_* tables of S-B6 which are documented references without RLS), verifies:
#   1. JWT-A can INSERT its own row.
#   2. JWT-B: SELECT does NOT see A's row (RLS SELECT USING).
#   3. JWT-B: UPDATE does NOT touch A's row (0 rows; RLS UPDATE USING).
#   4. JWT-B: INSERT with user_id = A is REJECTED (RLS WITH CHECK).
#   5. JWT-A: DELETE is REJECTED (REVOKE DELETE FROM authenticated — tombstone = UPDATE deleted=true).
#
# Uses ONLY the anon key + two user JWTs (password grant). NEVER service_role.
# Does NOT run in CI (needs network + the two seeded test users). See README.md.
#
# Env overrides: SUPABASE_URL, SUPABASE_ANON_KEY, USER_A_EMAIL/PASS, USER_B_EMAIL/PASS.
set -uo pipefail

URL="${SUPABASE_URL:-https://fostjbbwstyuunmmefuk.supabase.co}"
ANON="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg}"
A_EMAIL="${USER_A_EMAIL:-i5-user-a@test.yala}"; A_PASS="${USER_A_PASS:-I5-Passw0rd-A!}"
B_EMAIL="${USER_B_EMAIL:-i5-user-b@test.yala}"; B_PASS="${USER_B_PASS:-I5-Passw0rd-B!}"

login() { # email pass -> access_token
  curl -s -X POST "$URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))"
}
sub_of() { python3 -c "import sys,base64,json; t='$1'.split('.')[1]; t+='='*(-len(t)%4); print(json.load(__import__('io').BytesIO(base64.urlsafe_b64decode(t))).get('sub',''))"; }

JWT_A="$(login "$A_EMAIL" "$A_PASS")"; JWT_B="$(login "$B_EMAIL" "$B_PASS")"
[ -n "$JWT_A" ] && [ -n "$JWT_B" ] || { echo "FATAL: could not obtain JWTs"; exit 2; }
SUB_A="$(sub_of "$JWT_A")"; SUB_B="$(sub_of "$JWT_B")"
echo "user A = $SUB_A"; echo "user B = $SUB_B"; echo

RUN="i5rls-$(date +%s)-$RANDOM"
HLC="2026-07-07T00:00:00.000Z-0001-0123456789abcdef"   # 46-char dummy; not load-bearing for RLS
rest() { # METHOD JWT PATH [body] -> prints "HTTP<code>\n<body>"
  local m="$1" jwt="$2" path="$3" body="${4:-}"
  if [ -n "$body" ]; then
    curl -s -w $'\nHTTP%{http_code}' -X "$m" "$URL/rest/v1/$path" \
      -H "apikey: $ANON" -H "Authorization: Bearer $jwt" \
      -H "Content-Type: application/json" -H "Prefer: return=representation" -d "$body"
  else
    curl -s -w $'\nHTTP%{http_code}' -X "$m" "$URL/rest/v1/$path" \
      -H "apikey: $ANON" -H "Authorization: Bearer $jwt" -H "Prefer: return=representation"
  fi
}
code() { printf '%s' "$1" | tail -1 | sed 's/HTTP//'; }
data() { printf '%s' "$1" | sed '$d'; }

# per-table config: PK column, unique PK value, insert body (user_id filled per-caller), update body
pkcol() { case "$1" in user_preferences) echo key;; attest_keys) echo key_id;; *) echo sync_id;; esac; }
pkval() { case "$1" in
  user_preferences) echo "prefkey-$RUN";;
  attest_keys)      echo "keyid-$RUN";;
  *)                python3 -c "import uuid;print(uuid.uuid4())";; esac; }
body() { # table user_id pkvalue
  case "$1" in
    user_preferences) printf '{"user_id":"%s","key":"%s","hlc":"%s"}' "$2" "$3" "$HLC";;
    attest_keys)      printf '{"user_id":"%s","key_id":"%s","attestation_type":"app_attest"}' "$2" "$3";;
    *)                printf '{"user_id":"%s","sync_id":"%s","hlc":"%s"}' "$2" "$3" "$HLC";;
  esac
}
updbody() { case "$1" in
  user_preferences) echo '{"value":"hacked-by-B"}';;
  attest_keys)      echo '{"last_seen_at":"2020-01-01T00:00:00Z"}';;
  *)                echo '{"hlc":"hacked-by-B"}';; esac; }

TABLES="tx_items accounts categories subcategories tags budgets scheduled_payments \
inbox_drafts favorite_payments merchant_memory exchange_rates notification_items \
cashflow_plans cashflow_lines cashflow_overrides group_bridge_prefs \
user_preferences attest_keys"

pass_tables=0; fail_tables=0
printf "%-22s %-8s %-8s %-8s %-9s %-8s\n" TABLE A_INS B_SEL B_UPD B_INS_A A_DEL
printf "%-22s %-8s %-8s %-8s %-9s %-8s\n" "----" "-----" "-----" "-----" "------" "-----"

for t in $TABLES; do
  col="$(pkcol "$t")"; pv="$(pkval "$t")"
  # 1. A inserts its own row
  r="$(rest POST "$JWT_A" "$t" "$(body "$t" "$SUB_A" "$pv")")"
  [ "$(code "$r")" = "201" ] && a_ins=PASS || a_ins="FAIL($(code "$r"))"
  # 2. B cannot SELECT A's row
  r="$(rest GET "$JWT_B" "$t?$col=eq.$pv")"
  { [ "$(code "$r")" = "200" ] && [ "$(data "$r")" = "[]" ]; } && b_sel=PASS || b_sel="FAIL($(code "$r"))"
  # 3. B UPDATE touches 0 rows (RLS hides A's row)
  r="$(rest PATCH "$JWT_B" "$t?$col=eq.$pv" "$(updbody "$t")")"
  { [ "$(data "$r")" = "[]" ]; } && b_upd=PASS || b_upd="FAIL($(code "$r"))"
  # 4. B INSERT with user_id = A is rejected by WITH CHECK (fresh VALID pk so type parses; RLS is the gate)
  wcpv="$(pkval "$t")"
  r="$(rest POST "$JWT_B" "$t" "$(body "$t" "$SUB_A" "$wcpv")")"
  case "$(code "$r")" in 401|403) b_insa=PASS;; *) b_insa="FAIL($(code "$r"))";; esac
  # 5. A DELETE rejected (REVOKE DELETE FROM authenticated)
  r="$(rest DELETE "$JWT_A" "$t?$col=eq.$pv")"
  case "$(code "$r")" in 401|403) a_del=PASS;; *) a_del="FAIL($(code "$r"))";; esac

  printf "%-22s %-8s %-8s %-8s %-9s %-8s\n" "$t" "$a_ins" "$b_sel" "$b_upd" "$b_insa" "$a_del"
  if [ "$a_ins$b_sel$b_upd$b_insa$a_del" = "PASSPASSPASSPASSPASS" ]; then
    pass_tables=$((pass_tables+1)); else fail_tables=$((fail_tables+1)); fi
done

echo
echo "RESULT: ${pass_tables}/18 tables fully isolated (fail: ${fail_tables})"
[ "$fail_tables" -eq 0 ] || exit 1
