#!/usr/bin/env bash
# Spike B de G0 (Grupos→backend): pgcrypto llave-por-request + hash canónico sobre plaintext.
#
# Verifica contra STAGING (tabla spike_enc + RPCs de g0_pgcrypto_spike.sql):
#   1. Round-trip cifrado byte-idéntico (write → read).
#   2. Llave mala → error LIMPIO (yala_bad_key) y el body NO contiene la llave.
#   3. Hash canónico coincide (stored == computed).
#   4. ESTABILIDAD tras re-cifrado: rekey cambia el ciphertext pero content_hash NO
#      (el veredicto de que el Merkle de G7 sobre plaintext es viable).
#   5. La llave vieja ya no abre.
#   6. RLS directa: user-B no ve la fila de A.
#   7. RLS vía RPC: user-B con la llave CORRECTA recibe yala_not_found (RLS filtra ANTES de descifrar).
#   8. Variante GUC (set_config local a la tx) descifra igual.
# Al final imprime la auditoría MANUAL de logs (fuga de la llave) — no automatizable desde aquí.
#
# Usa SOLO la anon key + JWTs de usuario (password grant). NUNCA service_role. No corre en CI.
# Env REQUERIDO: USER_A_PASS, USER_B_PASS (sin default en el arbol; ver qa/cloud/README.md).
# Env opcional:  SUPABASE_URL, SUPABASE_ANON_KEY, USER_A_EMAIL, USER_B_EMAIL.
set -uo pipefail

URL="${SUPABASE_URL:-https://fostjbbwstyuunmmefuk.supabase.co}"
ANON="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg}"
A_EMAIL="${USER_A_EMAIL:-i5-user-a@test.yala}"; A_PASS="${USER_A_PASS:?falta en el entorno — ver qa/cloud/README.md (credenciales de staging)}"
B_EMAIL="${USER_B_EMAIL:-i5-user-b@test.yala}"; B_PASS="${USER_B_PASS:?falta en el entorno — ver qa/cloud/README.md (credenciales de staging)}"

login() { # email pass -> access_token
  curl -s -X POST "$URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))"
}

JWT_A="$(login "$A_EMAIL" "$A_PASS")"; JWT_B="$(login "$B_EMAIL" "$B_PASS")"
[ -n "$JWT_A" ] && [ -n "$JWT_B" ] || { echo "FATAL: could not obtain JWTs"; exit 2; }

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
rpc() { rest POST "$1" "rpc/$2" "$3"; } # JWT fn json-args
code() { printf '%s' "$1" | tail -1 | sed 's/HTTP//'; }
data() { printf '%s' "$1" | sed '$d'; }
jstr() { printf '%s' "$1" | python3 -c "import sys,json; v=json.load(sys.stdin); print(v if isinstance(v,str) else '')" 2>/dev/null; }

# Llaves SENTINELA únicas y grep-ables en los logs de Postgres (auditoría manual del final).
TS="$(date +%s)"
KEY1="g0-spike-key-A-$TS"
KEY2="g0-spike-key-B-$TS"
KEY_BAD="g0-spike-key-WRONG-$TS"
PLAIN="hola grupos G0 · ñ € 12.34"

pass=0; fail=0
check() { # name condition(0=ok)
  if [ "$2" -eq 0 ]; then printf "%-46s PASS\n" "$1"; pass=$((pass+1));
  else printf "%-46s FAIL\n" "$1"; fail=$((fail+1)); fi
}

# 1. Round-trip
r="$(rpc "$JWT_A" spike_enc_write "{\"p_plaintext\":\"$PLAIN\",\"p_key\":\"$KEY1\"}")"
ID="$(jstr "$(data "$r")")"
[ "$(code "$r")" = "200" ] && [ -n "$ID" ]; check "1. write (A, KEY1)" $?
r="$(rpc "$JWT_A" spike_enc_read "{\"p_id\":\"$ID\",\"p_key\":\"$KEY1\"}")"
[ "$(jstr "$(data "$r")")" = "$PLAIN" ]; check "1. read round-trip byte-idéntico" $?

# 2. Llave mala → yala_bad_key limpio, sin la llave en el body
r="$(rpc "$JWT_A" spike_enc_read "{\"p_id\":\"$ID\",\"p_key\":\"$KEY_BAD\"}")"
[ "$(code "$r")" = "400" ] && printf '%s' "$(data "$r")" | grep -q "yala_bad_key"; check "2. llave mala → 400 yala_bad_key" $?
! printf '%s' "$(data "$r")" | grep -q "$KEY_BAD"; check "2. la llave NO aparece en el error" $?

# 3. Hash canónico
r="$(rpc "$JWT_A" spike_enc_hash "{\"p_id\":\"$ID\",\"p_key\":\"$KEY1\"}")"
printf '%s' "$(data "$r")" | grep -q '"matches" *: *true\|"matches":true'; check "3. hash stored == computed" $?
H1="$(printf '%s' "$(data "$r")" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['stored_hash'])")"

# 4. Estabilidad del hash tras re-cifrado (rekey KEY1→KEY2)
r="$(rpc "$JWT_A" spike_enc_rekey "{\"p_id\":\"$ID\",\"p_old_key\":\"$KEY1\",\"p_new_key\":\"$KEY2\"}")"
[ "$(code "$r")" = "200" ] || [ "$(code "$r")" = "204" ]; check "4. rekey OK" $?
r="$(rest GET "$JWT_A" "spike_enc?id=eq.$ID&select=content_hash")"
printf '%s' "$(data "$r")" | grep -q "$H1"; check "4. content_hash ESTABLE tras rekey" $?
r="$(rpc "$JWT_A" spike_enc_hash "{\"p_id\":\"$ID\",\"p_key\":\"$KEY2\"}")"
printf '%s' "$(data "$r")" | grep -q '"matches" *: *true\|"matches":true'; check "4. hash matches con KEY2" $?

# 5. La llave vieja ya no abre
r="$(rpc "$JWT_A" spike_enc_read "{\"p_id\":\"$ID\",\"p_key\":\"$KEY1\"}")"
printf '%s' "$(data "$r")" | grep -q "yala_bad_key"; check "5. KEY1 vieja → yala_bad_key" $?

# 6. RLS directa: B no ve la fila de A
r="$(rest GET "$JWT_B" "spike_enc?id=eq.$ID")"
[ "$(code "$r")" = "200" ] && [ "$(data "$r")" = "[]" ]; check "6. RLS directa: B ve []" $?

# 7. RLS vía RPC: B con la llave CORRECTA → yala_not_found (filtra ANTES de descifrar)
r="$(rpc "$JWT_B" spike_enc_read "{\"p_id\":\"$ID\",\"p_key\":\"$KEY2\"}")"
printf '%s' "$(data "$r")" | grep -q "yala_not_found"; check "7. RLS vía RPC: B → yala_not_found" $?

# 8. Variante GUC
r="$(rpc "$JWT_A" spike_enc_read_local "{\"p_id\":\"$ID\",\"p_key\":\"$KEY2\"}")"
[ "$(jstr "$(data "$r")")" = "$PLAIN" ]; check "8. variante GUC (set_config local)" $?

echo
echo "RESULT: ${pass} PASS / ${fail} FAIL"
echo
cat <<EOF
MANUAL — auditoría de fuga de la llave en logs (no automatizable desde aquí):
  1. Dashboard Supabase (fostjbbwstyuunmmefuk) → Logs → Postgres → buscar: g0-spike-key
     (las llaves sentinela de esta corrida terminan en -$TS; el caso 2/5 generó ERRORES
      con la llave como bind param — es el punto caliente).
  2. SQL editor:
       show log_statement; show log_min_duration_statement;
       show log_parameter_max_length; show log_parameter_max_length_on_error;
     (log_statement='all' o log_parameter_max_length_on_error != 0 pueden volcar la llave.)
  3. SQL editor: select query from pg_stat_statements where query ilike '%spike_enc%';
     → debe salir NORMALIZADO con \$1,\$2. Si aparece una llave literal: FAIL.
  4. Logs → API Edge: confirmar que no se loggean request bodies.
  Anotar el veredicto (argumento vs SET LOCAL, y qué settings fugan) en
  MODO-NUBE-GRUPOS-BACKEND-V1-DISENO §3/§8/R2.
EOF
[ "$fail" -eq 0 ] || exit 1
