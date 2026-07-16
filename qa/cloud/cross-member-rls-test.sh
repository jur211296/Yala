#!/usr/bin/env bash
# Cross-MEMBER RLS + RPC gate for the Grupos→backend staging schema (G1).
#
# Membership-based access (NOT the personal per-user (auth.uid()=user_id) model): exercises the 9 RPCs
# (create_group / create_group_invite / join_group / approve_member / remove_member / leave_group /
#  revoke_invite / update_member_display_name / groups_forget_user) end-to-end AND the direct PostgREST channel
# against the 5 group tables (split_groups, group_members, split_expenses, split_shares, split_settlements) +
# group_invites + push_tokens, asserting:
#   * a non-member reads NOTHING and writes NOTHING;
#   * a pendingApproval member reads the group/roster but NOT financial content (fix 2), and cannot write;
#   * an active member reads content + writes; remove/leave revokes it;
#   * group_members is FROZEN for direct UPDATE — a member cannot PATCH role/status/display_name/field_hlcs on
#     its own row (hallazgo #1 total freeze); the only rename path is the update_member_display_name RPC;
#   * a legacy rebind lands as pendingApproval (fix 1) — the admin must approve before the rebound member writes;
#   * a non-admin member cannot PATCH split_groups (hallazgo #2);
#   * DELETE is revoked on every group table;
#   * invite lifecycle: revoked / exhausted (max_uses) / expired / ttl-out-of-range;
#   * owner cannot leave / cannot be removed;
#   * groups_forget_user transfers ownership (or tombstones) + anonymizes memberships.
#
# Uses ONLY the anon key + user JWTs (password grant). NEVER service_role. Does NOT run in CI (network +
# seeded test users). See README.md. Re-runnable with NO manual cleanup (unique group_id per run; users reused;
# each run's forget self-cleans A-owned groups from prior runs).
#
# ⚠️ G7 (pgcrypto): las columnas † (split_groups.name, group_members.display_name, split_expenses.amount/
# expense_description/note, split_settlements.amount/note, split_shares.amount) están CIFRADAS at-rest (bytea).
# Consecuencias en este gate:
#   * REQUIERE `GROUPS_ENC_KEY` en el entorno (como URL/ANON; SIN default — jamás hardcodeada).
#   * Las SIEMBRAS POSITIVAS de contenido (un expense escrito por un writer activo) pasan por el RPC
#     apply_group_delta con p_key (arma p_fields anidado por unidad, como el Worker); un INSERT directo de
#     amount plaintext moriría por coerción de tipo (bytea), no por RLS.
#   * Las siembras NEGATIVAS (write directo rechazado por RLS) usan una fila con SOLO columnas NO-† (currency_code,
#     date) → el 4xx prueba RLS, no la coerción de tipo (con una † plaintext el 4xx sería por tipo — no probaría RLS).
#   * Los PATCH directos de split_groups.name → re-apuntados a icon_name (NO-†): mantienen la prueba de RLS 0-rows.
#   * Las lecturas de display_name (†) se hacen vía el RPC lector groups_pull_rows_group_members (descifra).
#   * create_group/join_group/update_member_display_name/groups_forget_user reciben p_key.
#
# Users: A/B from the I5 mold; optional C (i5-user-c@test.yala) is best-effort (login → signup → skip).
#
# Modes / flags:
#   (no args)          run the full gate. Exit 1 on any FAIL.
#   --prepare-legacy   create a group + two invites for the legacy-rebind case, write /tmp/cross-member-rls-legacy.env,
#                      print the two MCP execute_sql statements the operator must run, then exit 0 (no matrix).
#   --skip-legacy      run the gate but SKIP the rebind/expired-token legacy block WITHOUT failing (env absent is OK).
#
# Env overrides: SUPABASE_URL, SUPABASE_ANON_KEY, USER_A_EMAIL/PASS, USER_B_EMAIL/PASS, USER_C_EMAIL/PASS.
set -uo pipefail

URL="${SUPABASE_URL:-https://fostjbbwstyuunmmefuk.supabase.co}"
ANON="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg}"
# G7: llave de cifrado de las columnas † de grupos. SIN default (JAMÁS hardcodeada). Requerida en TODOS los modos.
ENC_KEY="${GROUPS_ENC_KEY:-}"
[ -n "$ENC_KEY" ] || { echo "FATAL: set GROUPS_ENC_KEY (staging groups enc key) — see README/g7_01 header"; exit 2; }
A_EMAIL="${USER_A_EMAIL:-i5-user-a@test.yala}"; A_PASS="${USER_A_PASS:-I5-Passw0rd-A!}"
B_EMAIL="${USER_B_EMAIL:-i5-user-b@test.yala}"; B_PASS="${USER_B_PASS:-I5-Passw0rd-B!}"
C_EMAIL="${USER_C_EMAIL:-i5-user-c@test.yala}"; C_PASS="${USER_C_PASS:-I5-Passw0rd-C!}"
LEGACY_ENV="/tmp/cross-member-rls-legacy.env"
HLC="2026-07-14T00:00:00.000Z-0001-0123456789abcdef"   # 46-char dummy; not load-bearing for RLS/RPC

MODE="run"
case "${1:-}" in
  --prepare-legacy) MODE="prepare";;
  --skip-legacy)    MODE="skiplegacy";;
  "" ) ;;
  *) echo "unknown flag: $1"; echo "usage: $0 [--prepare-legacy|--skip-legacy]"; exit 2;;
esac

# ---------- HTTP helpers (mold: cross-user-rls-test.sh) ----------
login() { # email pass -> access_token ("" on failure)
  curl -s -X POST "$URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null
}
signup() { # email pass -> access_token ("" if disabled/failed)
  curl -s -X POST "$URL/auth/v1/signup" \
    -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null
}
sub_of() { python3 -c "import sys,base64,json,io; t='$1'.split('.')[1]; t+='='*(-len(t)%4); print(json.load(io.BytesIO(base64.urlsafe_b64decode(t))).get('sub',''))"; }

rest() { # METHOD JWT PATH [body] -> prints "<body>\nHTTP<code>"
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
rpc() { rest POST "$1" "rpc/$2" "$3"; }               # jwt fn jsonbody
code() { printf '%s' "$1" | tail -1 | sed 's/HTTP//'; }
data() { printf '%s' "$1" | sed '$d'; }

# ---------- JSON extraction ----------
jfield() { python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: d=None
v=(d.get('$1') if isinstance(d,dict) else None); print('' if v is None else v)"; }
scalar() { python3 -c "import sys,json
try: v=json.load(sys.stdin)
except Exception: v=None
print(v if not isinstance(v,(dict,list)) and v is not None else '')"; }
arr0() { python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: d=None
v=(d[0].get('$1') if isinstance(d,list) and d and isinstance(d[0],dict) else None); print('' if v is None else v)"; }
arrlen() { python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: d=None
print(len(d) if isinstance(d,list) else -1)"; }
uuid() { python3 -c "import uuid;print(uuid.uuid4())"; }

# ---------- body builders ----------
# create_group lleva p_key (G7: cifra name+display_name server-side; name/display_name viajan plaintext al RPC).
cg_body() { printf '{"p_group_id":"%s","p_name":"RLS Test Group","p_currency_code":"USD","p_icon_name":"cart","p_color_hex":"#112233","p_display_name":"%s","p_default_split_type":"equal","p_key":"%s"}' "$1" "$2" "$ENC_KEY"; }
# Siembra NEGATIVA (write directo que RLS debe rechazar): SOLO columnas NO-† (currency_code/date) → el 4xx prueba
# RLS, no la coerción de tipo (amount es bytea post-G7). NO incluir amount/expense_description/note.
exp_body_safe() { printf '{"group_id":"%s","sync_id":"%s","currency_code":"USD","date":"2026-07-14T00:00:00.000Z","hlc":"%s","field_hlcs":{}}' "$1" "$(uuid)" "$HLC"; }
# Siembra POSITIVA (writer activo): vía apply_group_delta con p_key (arma p_fields anidado por unidad como el
# Worker) — el RPC cifra amount server-side. Sin esto, un INSERT directo de amount plaintext moriría por tipo.
agd_expense() { printf '{"p_entity":"split_expenses","p_group_id":"%s","p_sync_id":"%s","p_op":"upsert","p_fields":{"gmoney":{"amount":1.5,"currency_code":"USD"}},"p_field_hlcs":{"gmoney":"%s"},"p_row_hlc":"%s","p_schema_version":1,"p_key":"%s"}' "$1" "$(uuid)" "$HLC" "$HLC" "$ENC_KEY"; }

# ---------- assertions ----------
pass=0; fail=0
ok() { pass=$((pass+1)); printf "  PASS  %s\n" "$1"; }
no() { fail=$((fail+1)); printf "  FAIL  %s\n" "$1"; }
expect_eq()   { if [ "$2" = "$3" ]; then ok "$1"; else no "$1 — expected [$2] got [$3]"; fi; }        # label exp act
expect_err()  { local m; m="$(data "$3" | jfield message)"; if [ "$m" = "$2" ]; then ok "$1"; else no "$1 — expected err [$2] got code=$(code "$3") msg=[$m]"; fi; }  # label expmsg result
expect_empty(){ local d; d="$(data "$2")"; if [ "$d" = "[]" ]; then ok "$1"; else no "$1 — expected [] got code=$(code "$2") [$d]"; fi; }  # label result
expect_rows() { local n; n="$(data "$2" | arrlen)"; if [ "$n" -gt 0 ] 2>/dev/null; then ok "$1"; else no "$1 — expected rows got code=$(code "$2") [$(data "$2")]"; fi; }  # label result
expect_4xx()  { case "$(code "$2")" in 4*) ok "$1";; *) no "$1 — expected 4xx got $(code "$2") [$(data "$2")]";; esac; }  # label result
expect_201()  { if [ "$(code "$2")" = "201" ]; then ok "$1"; else no "$1 — expected 201 got $(code "$2") [$(data "$2")]"; fi; }  # label result
# escalation blocked = 4xx (column denied) OR 0 rows touched:
expect_blocked() { local c d; c="$(code "$2")"; d="$(data "$2")"; case "$c" in 4*) ok "$1";; *) if [ "$d" = "[]" ]; then ok "$1"; else no "$1 — NOT blocked: code=$c [$d]"; fi;; esac; }
# G7: siembra positiva vía apply_group_delta → 200 con noop!=true (op upsert aplicado).
expect_applied() { local c n; c="$(code "$2")"; n="$(data "$2" | jfield noop)"; if [ "$c" = "200" ] && [ "$n" != "True" ]; then ok "$1"; else no "$1 — expected applied got code=$c [$(data "$2")]"; fi; }  # label result

# G7 helpers ---------------------------------------------------------------
# join_group con p_key inyectado (writer de display_name). Args: jwt token display [legacy_key].
jg() {
  local body
  if [ -n "${4:-}" ]; then
    body="{\"p_token\":\"$2\",\"p_display_name\":\"$3\",\"p_legacy_member_key\":\"$4\",\"p_key\":\"$ENC_KEY\"}"
  else
    body="{\"p_token\":\"$2\",\"p_display_name\":\"$3\",\"p_key\":\"$ENC_KEY\"}"
  fi
  rpc "$1" join_group "$body"
}
# Lee un campo (descifrado) de una fila group_members vía el RPC lector. Args: jwt gid member_key field.
member_field() {
  local body
  body="$(rpc "$1" groups_pull_rows_group_members "{\"p_group_id\":\"$2\",\"p_after_seq\":0,\"p_limit\":1000,\"p_key\":\"$ENC_KEY\"}")"
  data "$body" | python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: d=None
row=next((r for r in d if isinstance(r,dict) and r.get('member_key')=='$3'), None) if isinstance(d,list) else None
print('' if not row or row.get('$4') is None else row.get('$4'))"
}

# ============================================================================
JWT_A="$(login "$A_EMAIL" "$A_PASS")"; JWT_B="$(login "$B_EMAIL" "$B_PASS")"
[ -n "$JWT_A" ] && [ -n "$JWT_B" ] || { echo "FATAL: could not obtain JWTs for A/B"; exit 2; }
SUB_A="$(sub_of "$JWT_A")"; SUB_B="$(sub_of "$JWT_B")"
echo "user A = $SUB_A"; echo "user B = $SUB_B"

# ---------- --prepare-legacy: seed the rebind fixtures, then exit ----------
if [ "$MODE" = "prepare" ]; then
  TS="$(date +%s)-$RANDOM"
  LG="rls-g1-legacy-$TS"                 # length >> 8
  LK="legacy-$TS"
  r="$(rpc "$JWT_A" create_group "$(cg_body "$LG" "Owner A")")"
  [ "$(data "$r" | jfield group_id)" = "$LG" ] || { echo "FATAL: prepare create_group failed: $(data "$r")"; exit 2; }
  r="$(rpc "$JWT_A" create_group_invite "{\"p_group_id\":\"$LG\"}")";          LT="$(data "$r" | scalar)"
  r="$(rpc "$JWT_A" create_group_invite "{\"p_group_id\":\"$LG\"}")";          LTX="$(data "$r" | scalar)"
  [ -n "$LT" ] && [ -n "$LTX" ] || { echo "FATAL: prepare create_group_invite failed"; exit 2; }
  cat > "$LEGACY_ENV" <<EOF
LEGACY_GROUP_ID=$LG
LEGACY_TOKEN=$LT
LEGACY_TOKEN_EXPIRED=$LTX
LEGACY_KEY=$LK
EOF
  echo
  echo "Wrote $LEGACY_ENV:"; cat "$LEGACY_ENV"
  echo
  echo "=== RUN THESE TWO STATEMENTS VIA MCP execute_sql (server-side; RLS blocks the script from doing it) ==="
  # G7: display_name es † (bytea). Se inserta NULL (la llave JAMÁS aterriza en este statement impreso); el rebind
  # de join_group luego lo setea cifrado a 'Pia'. El placeholder solo necesita user_id NULL para ser reclamable.
  echo "insert into group_members (group_id, member_key, user_id, display_name, role, status, joined_at, hlc, field_hlcs, deleted)"
  echo " values ('$LG', '$LK', null, null, 'member', 'active', now(), server_hlc(), '{}'::jsonb, false);"
  echo "update group_invites set expires_at = now() - interval '1 hour' where token = '$LTX';"
  echo
  echo "Then re-run this script with NO flags to cover the rebind + expired-token cases."
  exit 0
fi

# Optional user C (best-effort).
JWT_C="$(login "$C_EMAIL" "$C_PASS")"
if [ -z "$JWT_C" ]; then JWT_C="$(signup "$C_EMAIL" "$C_PASS")"; fi
if [ -n "$JWT_C" ]; then SUB_C="$(sub_of "$JWT_C")"; echo "user C = $SUB_C"; else echo "user C = (unavailable — exhaustion sub-case falls back to B)"; fi
echo

G="rls-g1-$(date +%s)-$RANDOM"          # unique per run, length >> 8
echo "### group_id = $G"

# ---------- Step 1: A creates group + invite ----------
echo "== Step 1: A create_group + invite =="
r="$(rpc "$JWT_A" create_group "$(cg_body "$G" "Owner A")")"
expect_eq "1.a A create_group returns group_id" "$G" "$(data "$r" | jfield group_id)"
expect_eq "1.b A create_group owner member_key = A sub" "$SUB_A" "$(data "$r" | jfield member_key)"
r="$(rpc "$JWT_A" create_group_invite "{\"p_group_id\":\"$G\"}")"; TOKEN="$(data "$r" | scalar)"
[ -n "$TOKEN" ] && ok "1.c A create_group_invite returns token" || no "1.c invite token empty [$(data "$r")]"
# Seed one expense as A (active writer) so the pending-member content-read block below is a REAL negative test.
# G7: vía apply_group_delta (cifra amount server-side).
r="$(rpc "$JWT_A" apply_group_delta "$(agd_expense "$G")")"; expect_applied "1.d A (owner) seeds a split_expense (apply_group_delta)" "$r"

# ---------- Step 2: PRE-JOIN — B is a non-member ----------
echo "== Step 2: pre-join — B (non-member) reads nothing / writes nothing =="
for t in split_groups group_members split_expenses split_shares split_settlements; do
  r="$(rest GET "$JWT_B" "$t?group_id=eq.$G")"; expect_empty "2.read B sees no $t" "$r"
done
# G7: write directo con SOLO columnas NO-† → el 4xx prueba RLS (no la coerción de tipo bytea). PATCH re-apuntado a
# icon_name (NO-†) para mantener la prueba RLS 0-rows (name es † → un PATCH plaintext moriría por tipo).
r="$(rest POST "$JWT_B" split_expenses "$(exp_body_safe "$G")")"; expect_4xx "2.write B insert split_expenses rejected" "$r"
r="$(rest PATCH "$JWT_B" "split_groups?group_id=eq.$G" '{"icon_name":"hacked-by-B"}')"; expect_empty "2.write B patch split_groups 0 rows" "$r"

# ---------- Step 3: B joins → pendingApproval; reads but cannot write; cannot self-approve ----------
echo "== Step 3: B join → pendingApproval (reads, no write, no self-approve) =="
r="$(jg "$JWT_B" "$TOKEN" "Member B")"
expect_eq "3.a B join status pendingApproval" "pendingApproval" "$(data "$r" | jfield status)"
expect_eq "3.b B join member_key = B sub"     "$SUB_B"          "$(data "$r" | jfield member_key)"
r="$(rest GET "$JWT_B" "split_groups?group_id=eq.$G")";  expect_rows  "3.c B (pending) now sees split_groups" "$r"
r="$(rest GET "$JWT_B" "group_members?group_id=eq.$G")"; expect_rows  "3.d B (pending) now sees group_members" "$r"
r="$(rest POST "$JWT_B" split_expenses "$(exp_body_safe "$G")")"; expect_4xx "3.e B (pending) still cannot write" "$r"
# fix 2: a pendingApproval member reads the group/roster (3.c/3.d) but NOT the financial content — the SELECT
# policies of the 3 content tables are gated to is_group_writer (active), not is_group_member (incl. pending).
r="$(rest GET "$JWT_B" "split_expenses?group_id=eq.$G")";   expect_empty "3.g B (pending) cannot read split_expenses (writer-only SELECT)" "$r"
r="$(rest GET "$JWT_B" "split_shares?group_id=eq.$G")";      expect_empty "3.h B (pending) cannot read split_shares (writer-only SELECT)" "$r"
r="$(rest GET "$JWT_B" "split_settlements?group_id=eq.$G")"; expect_empty "3.i B (pending) cannot read split_settlements (writer-only SELECT)" "$r"
# 3.f is redundant-but-informative: pending self-approve is already blocked by RLS + the total UPDATE revoke;
# the CANONICAL column-escalation test is 5.a (active member PATCH role→admin → blocked).
r="$(rest PATCH "$JWT_B" "group_members?group_id=eq.$G&member_key=eq.$SUB_B" '{"status":"active"}')"
expect_blocked "3.f B self-approve PATCH {status:active} BLOCKED (redundant-but-informative)" "$r"

# ---------- Step 4: A approves B → B becomes an active writer ----------
echo "== Step 4: A approve_member(B) → B writes =="
r="$(rpc "$JWT_A" approve_member "{\"p_group_id\":\"$G\",\"p_member_key\":\"$SUB_B\"}")"
expect_eq "4.a A approve → active" "active" "$(data "$r" | jfield status)"
r="$(rpc "$JWT_B" apply_group_delta "$(agd_expense "$G")")"; expect_applied "4.b B (active) writes split_expenses (apply_group_delta)" "$r"
# fix 2 flips on approval: B (now an active writer) can read the group's split_expenses.
r="$(rest GET "$JWT_B" "split_expenses?group_id=eq.$G")"; expect_rows "4.c B (active) can now read split_expenses (writer)" "$r"

# ---------- Step 5: escalation blocked; non-admin cannot patch group; legit rename allowed ----------
echo "== Step 5: escalation (hallazgo #1/#2) =="
# 5.a is the canonical column-escalation test: an ACTIVE member cannot PATCH role→admin (total UPDATE revoke).
r="$(rest PATCH "$JWT_B" "group_members?group_id=eq.$G&member_key=eq.$SUB_B" '{"role":"admin"}')"
expect_blocked "5.a B role→admin PATCH BLOCKED" "$r"
r="$(rest PATCH "$JWT_B" "split_groups?group_id=eq.$G" '{"icon_name":"hacked-by-B"}')"
expect_empty "5.b B (non-admin) patch split_groups 0 rows (hallazgo #2)" "$r"
# fix 3: group_members lost ALL direct UPDATE — even a legit display_name PATCH is now BLOCKED (not 0 rows).
r="$(rest PATCH "$JWT_B" "group_members?group_id=eq.$G&member_key=eq.$SUB_B" "{\"display_name\":\"B Renamed\",\"hlc\":\"$HLC\",\"field_hlcs\":{}}")"
expect_blocked "5.c B direct display_name PATCH now BLOCKED (group_members UPDATE revoked)" "$r"
# rename now flows ONLY through the RPC (SECURITY DEFINER bypasses the table grant). G7: + p_key (cifra el nuevo
# display_name); el RPC devuelve el display_name plaintext (no lo lee cifrado).
r="$(rpc "$JWT_B" update_member_display_name "{\"p_group_id\":\"$G\",\"p_display_name\":\"B Renamed\",\"p_key\":\"$ENC_KEY\"}")"
expect_eq "5.c2 B rename via update_member_display_name RPC → ok" "B Renamed" "$(data "$r" | jfield display_name)"
# G7: display_name es † → leer descifrado vía el RPC lector (un select=* directo vería bytea).
expect_eq "5.c3 display_name actually changed" "B Renamed" "$(member_field "$JWT_B" "$G" "$SUB_B" display_name)"
r="$(rpc "$JWT_B" approve_member "{\"p_group_id\":\"$G\",\"p_member_key\":\"nope-$RANDOM\"}")"
expect_err "5.d B approve of a third party → not_authorized" "yala_not_authorized" "$r"
# fix 3: even a metadata-only PATCH (field_hlcs) is blocked — group_members is frozen for direct UPDATE.
r="$(rest PATCH "$JWT_B" "group_members?group_id=eq.$G&member_key=eq.$SUB_B" '{"field_hlcs":{"membership":"9999-01-01T00:00:00.000Z-0000-000000000000"}}')"
expect_blocked "5.e B direct field_hlcs PATCH BLOCKED (group_members UPDATE revoked)" "$r"

# ---------- Step 6: A removes B → B loses access ----------
echo "== Step 6: A remove_member(B) → B loses access =="
r="$(rpc "$JWT_A" remove_member "{\"p_group_id\":\"$G\",\"p_member_key\":\"$SUB_B\"}")"
expect_eq "6.a A remove active → removed" "removed" "$(data "$r" | jfield status)"
r="$(rest GET "$JWT_B" "split_groups?group_id=eq.$G")"; expect_empty "6.b B (removed) sees no split_groups" "$r"
r="$(rest POST "$JWT_B" split_expenses "$(exp_body_safe "$G")")"; expect_4xx "6.c B (removed) cannot write" "$r"

# ---------- Step 7: B re-joins (revive) → approve → write → leave → no write ----------
echo "== Step 7: re-join (revive) → approve → leave =="
r="$(jg "$JWT_B" "$TOKEN" "Member B")"
expect_eq "7.a B re-join revives → pendingApproval" "pendingApproval" "$(data "$r" | jfield status)"
expect_eq "7.b revive keeps member_key = B sub"     "$SUB_B"          "$(data "$r" | jfield member_key)"
r="$(rpc "$JWT_A" approve_member "{\"p_group_id\":\"$G\",\"p_member_key\":\"$SUB_B\"}")"
expect_eq "7.c A re-approve → active" "active" "$(data "$r" | jfield status)"
r="$(rpc "$JWT_B" apply_group_delta "$(agd_expense "$G")")"; expect_applied "7.d B (active) writes again (apply_group_delta)" "$r"
r="$(rpc "$JWT_B" leave_group "{\"p_group_id\":\"$G\"}")"
expect_eq "7.e B leave → left" "left" "$(data "$r" | jfield status)"
r="$(rest POST "$JWT_B" split_expenses "$(exp_body_safe "$G")")"; expect_4xx "7.f B (left) cannot write" "$r"

# ---------- Step 8: invite lifecycle ----------
echo "== Step 8: invite lifecycle (revoked / exhausted / ttl-range) =="
# (a) revoked
r="$(rpc "$JWT_A" create_group_invite "{\"p_group_id\":\"$G\"}")"; TOK2="$(data "$r" | scalar)"
r="$(rpc "$JWT_A" revoke_invite "{\"p_token\":\"$TOK2\"}")"; expect_eq "8.a revoke_invite ok" "True" "$(data "$r" | jfield revoked)"
r="$(jg "$JWT_B" "$TOK2" "Member B")"
expect_err "8.b B join revoked token → invalid_invite" "yala_invalid_invite" "$r"
# (b) exhausted (max_uses=1) — fresh group so B is a clean new member
GX="rls-g1x-$(date +%s)-$RANDOM"
r="$(rpc "$JWT_A" create_group "$(cg_body "$GX" "Owner A")")"
r="$(rpc "$JWT_A" create_group_invite "{\"p_group_id\":\"$GX\",\"p_max_uses\":1}")"; TOK3="$(data "$r" | scalar)"
r="$(jg "$JWT_B" "$TOK3" "Member B")"
expect_eq "8.c first join consumes the single use" "pendingApproval" "$(data "$r" | jfield status)"
if [ -n "$JWT_C" ]; then
  r="$(jg "$JWT_C" "$TOK3" "Member C")"
  expect_err "8.d exhausted token (2nd user C) → invalid_invite" "yala_invalid_invite" "$r"
else
  # fallback: same token, any user (uses>=max_uses short-circuits BEFORE the idempotent branch)
  r="$(jg "$JWT_B" "$TOK3" "Member B")"
  expect_err "8.d exhausted token (2nd attempt, C unavailable) → invalid_invite" "yala_invalid_invite" "$r"
fi
# (c) ttl out of range
r="$(rpc "$JWT_A" create_group_invite "{\"p_group_id\":\"$G\",\"p_ttl_seconds\":10}")"
expect_err "8.e create_group_invite ttl=10 → bad_input" "yala_bad_input" "$r"

# ---------- Step 9: owner cannot leave / cannot be removed; non-admin cannot remove owner ----------
echo "== Step 9: owner protections =="
r="$(rpc "$JWT_A" leave_group "{\"p_group_id\":\"$G\"}")"
expect_err "9.a A (owner) leave → owner_cannot_leave" "yala_owner_cannot_leave" "$r"
r="$(rpc "$JWT_A" remove_member "{\"p_group_id\":\"$G\",\"p_member_key\":\"$SUB_A\"}")"
expect_err "9.b A remove self (owner) → cannot_remove_owner" "yala_cannot_remove_owner" "$r"
# B re-joins G and is approved, then (as non-admin member) tries to remove the owner A
r="$(rpc "$JWT_A" create_group_invite "{\"p_group_id\":\"$G\"}")"; TOK4="$(data "$r" | scalar)"
r="$(jg "$JWT_B" "$TOK4" "Member B")"
r="$(rpc "$JWT_A" approve_member "{\"p_group_id\":\"$G\",\"p_member_key\":\"$SUB_B\"}")"
r="$(rpc "$JWT_B" remove_member "{\"p_group_id\":\"$G\",\"p_member_key\":\"$SUB_A\"}")"
expect_err "9.c B (member) remove owner A → not_authorized" "yala_not_authorized" "$r"

# ---------- Step 10: DELETE revoked everywhere ----------
echo "== Step 10: DELETE revoked on every group table =="
for t in split_groups group_members split_expenses split_shares split_settlements; do
  r="$(rest DELETE "$JWT_A" "$t?group_id=eq.$G")"; expect_4xx "10.A DELETE $t rejected" "$r"
done
r="$(rest DELETE "$JWT_A" "group_invites?token=eq.$TOK4")"; expect_4xx "10.A DELETE group_invites rejected" "$r"
r="$(rest DELETE "$JWT_A" "push_tokens?user_id=eq.$SUB_B")"; expect_empty "10.A DELETE B's push_tokens → 0 rows (RLS)" "$r"

# ---------- Legacy rebind block (before forget, which would tombstone the legacy group) ----------
echo "== Legacy rebind + expired-token =="
if [ -f "$LEGACY_ENV" ]; then
  # shellcheck disable=SC1090
  . "$LEGACY_ENV"
  r="$(jg "$JWT_B" "$LEGACY_TOKEN" "Pia" "$LEGACY_KEY")"
  expect_eq "L.a B rebind rebound=true"                "True"            "$(data "$r" | jfield rebound)"
  expect_eq "L.b B rebind keeps LEGACY_KEY"            "$LEGACY_KEY"     "$(data "$r" | jfield member_key)"
  # fix 1: rebind lands as pendingApproval (NOT active) — the legacy member_key is enumerable, so activating
  # directly would bypass approval + impersonate the migrated member's history. Admin must approve first.
  expect_eq "L.c B rebind status pendingApproval"      "pendingApproval" "$(data "$r" | jfield status)"
  r="$(rest POST "$JWT_B" split_expenses "$(exp_body_safe "$LEGACY_GROUP_ID")")"
  expect_4xx "L.d rebound B (pending) cannot write yet" "$r"
  r="$(rpc "$JWT_A" approve_member "{\"p_group_id\":\"$LEGACY_GROUP_ID\",\"p_member_key\":\"$LEGACY_KEY\"}")"
  expect_eq "L.e A approves the rebound legacy member → active" "active" "$(data "$r" | jfield status)"
  r="$(rpc "$JWT_B" apply_group_delta "$(agd_expense "$LEGACY_GROUP_ID")")"
  expect_applied "L.f rebound+approved B (active) writes in legacy group (apply_group_delta)" "$r"
  # G7: user_id (NO-†) y display_name (†, cifrado) → leídos descifrados vía el RPC lector.
  expect_eq "L.g A sees rebound member user_id = B"    "$SUB_B"          "$(member_field "$JWT_A" "$LEGACY_GROUP_ID" "$LEGACY_KEY" user_id)"
  expect_eq "L.h A sees rebound member display_name"   "Pia"            "$(member_field "$JWT_A" "$LEGACY_GROUP_ID" "$LEGACY_KEY" display_name)"
  r="$(jg "$JWT_B" "$LEGACY_TOKEN_EXPIRED" "Pia")"
  expect_err "L.i B join expired token → invalid_invite" "yala_invalid_invite" "$r"
  # env is single-use: the forget below tombstones/transfers LEGACY_GROUP_ID (A owns it). Re-prepare for the next run.
  rm -f "$LEGACY_ENV"
  echo "  (consumed $LEGACY_ENV — re-run --prepare-legacy + MCP seed for the next full gate)"
elif [ "$MODE" = "skiplegacy" ]; then
  echo "  --skip-legacy: rebind/expired-token block SKIPPED (env absent, not counted as failure)."
else
  echo
  echo "  ###############################################################################"
  echo "  #  REBIND NO CUBIERTO — no existe $LEGACY_ENV.                                #"
  echo "  #  Corre:  $0 --prepare-legacy                                                #"
  echo "  #  luego ejecuta las 2 sentencias MCP que imprime, y re-corre este script.    #"
  echo "  #  (o pasa --skip-legacy para excluir conscientemente el rebind del gate).    #"
  echo "  ###############################################################################"
  no "Legacy rebind block NOT covered (run --prepare-legacy + MCP seed, or pass --skip-legacy)"
fi

# ---------- Step 11: groups_forget_user (LAST — global over all A-owned groups) ----------
echo "== Step 11: groups_forget_user (transfer + tombstone + anonymize) =="
# 11a: fresh group with A owner + B active → transfer to B
GF1="rls-g1f1-$(date +%s)-$RANDOM"
r="$(rpc "$JWT_A" create_group "$(cg_body "$GF1" "Owner A")")"
r="$(rpc "$JWT_A" create_group_invite "{\"p_group_id\":\"$GF1\"}")"; TOKF="$(data "$r" | scalar)"
r="$(jg "$JWT_B" "$TOKF" "Member B")"
r="$(rpc "$JWT_A" approve_member "{\"p_group_id\":\"$GF1\",\"p_member_key\":\"$SUB_B\"}")"
# 11b: fresh group with A only → tombstone
GF2="rls-g1f2-$(date +%s)-$RANDOM"
r="$(rpc "$JWT_A" create_group "$(cg_body "$GF2" "Owner A")")"

# G7: groups_forget_user cifra el sentinel display_name '__deleted_user__' → + p_key.
r="$(rpc "$JWT_A" groups_forget_user "{\"p_key\":\"$ENC_KEY\"}")"
tr="$(data "$r" | jfield groups_transferred)"; tb="$(data "$r" | jfield groups_tombstoned)"; an="$(data "$r" | jfield memberships_anonymized)"
python3 -c "import sys; sys.exit(0 if int('${tr:-0}')>=1 else 1)" 2>/dev/null && ok "11.a groups_transferred>=1 ($tr)" || no "11.a groups_transferred<1 ($tr)"
python3 -c "import sys; sys.exit(0 if int('${tb:-0}')>=1 else 1)" 2>/dev/null && ok "11.b groups_tombstoned>=1 ($tb)" || no "11.b groups_tombstoned<1 ($tb)"
python3 -c "import sys; sys.exit(0 if int('${an:-0}')>=1 else 1)" 2>/dev/null && ok "11.c memberships_anonymized>=1 ($an)" || no "11.c memberships_anonymized<1 ($an)"
# GF1 transferred to B: B sees owner_user_id=B, and A's row anonymized
r="$(rest GET "$JWT_B" "split_groups?group_id=eq.$GF1&select=owner_user_id")"
expect_eq "11.d GF1 ownership transferred to B" "$SUB_B" "$(data "$r" | arr0 owner_user_id)"
# user_id (NULL) y status (removed) son NO-† → GET directo; display_name (†, sentinel cifrado) → RPC lector.
r="$(rest GET "$JWT_B" "group_members?group_id=eq.$GF1&member_key=eq.$SUB_A&select=user_id,status")"
expect_eq "11.e GF1 A row anonymized: user_id null"     ""                 "$(data "$r" | arr0 user_id)"
expect_eq "11.f GF1 A row anonymized: sentinel name"    "__deleted_user__" "$(member_field "$JWT_B" "$GF1" "$SUB_A" display_name)"
expect_eq "11.g GF1 A row anonymized: status removed"   "removed"          "$(data "$r" | arr0 status)"
# GF2 tombstoned (and A anonymized) → A no longer sees it
r="$(rest GET "$JWT_A" "split_groups?group_id=eq.$GF2")"
expect_empty "11.h GF2 tombstoned → A sees nothing" "$r"

# ============================================================================
echo
echo "RESULT: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ] || exit 1
