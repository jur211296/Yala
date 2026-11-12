#!/usr/bin/env bash
# =====================================================================================================
# g22_01 · banco LOCAL de `set_member_role` y del reset de rol de `remove_member` / `leave_group`, sin tocar staging ni
# producción
#
# Levanta un Postgres desechable, carga el DDL REAL de Grupos (`supabase-groups-staging.ddl`, entero: tablas,
# `stamp_group_seq`, `server_hlc`, `is_group_admin`, `join_group`, `approve_member`, RLS y el `cap_future_hlc` de hlc01)
# con los stubs mínimos de Supabase (roles, `auth.uid()` leyendo `request.jwt.claims`, pgcrypto, `profiles`), aplica la
# migración y llama a los RPC como los llama PostgREST: `role authenticated` con el `sub` en los claims.
#
# Qué prueba, cada regla con su control positivo al lado:
#   0. la guarda: el DDL cargado trae los md5 de partida fijados; con un remove_member divergido la migración aborta
#      sin tocar nada (y el rollback también)
#   1. sin sesión / quien llama no es admin activo (miembro, pendiente, que salió, ajeno al grupo) → yala_not_authorized
#   2. rol fuera de {admin, member} (otro texto, mayúsculas, NULL) → yala_bad_input
#   3. objetivo inexistente, pendiente, que salió, borrado o de OTRO grupo → yala_member_not_found
#   4. quitarle el admin al creador (con `member_key` legacy: se compara por user_id) → yala_cannot_change_owner_role
#   5. hacer admin a un hueco sin reclamar → yala_member_not_eligible (quitárselo a un hueco admin sí se puede)
#   6. quitarse el admin el último admin activo CON CUENTA de un grupo sin creador → yala_last_admin (los que salieron,
#      los borrados y los huecos admin sin cuenta no cuentan; con otro admin activo con cuenta, sí se puede)
#   7. idempotencia: pedir el rol que ya tiene no escribe nada (hlc, server_seq, updated_at intactos) y da changed:false
#   8. la escritura: rol, hlc del servidor, field_hlcs.membership = hlc, el resto de field_hlcs intacto, server_seq sube,
#      la forma exacta de la respuesta y el errcode P0001 de los rechazos
#   9. grants: anon no la ejecuta, authenticated sí
#  10. concurrencia: dos admins que se quitan el admin el uno al otro a la vez → el segundo recibe yala_not_authorized
#      y el grupo conserva un admin
#  13. salir deja de ser admin: expulsar a un admin, irse siendo admin y rechazar una solicitud con rol admin dejan
#      `role = member`; re-entrar por el enlace (`join_group` real) y aprobarlo deja member. Controles: al creador ni se
#      le expulsa ni se va, y un miembro no expulsa
#  14. remove_member bajo candado: un admin al que le están quitando el admin no expulsa a nadie mientras tanto
#  11-12. re-aplicar la migración es no-op; el rollback devuelve los dos cuerpos al md5 del DDL y retira la función, y
#      un segundo rollback no falla
# Y después, los MUTANTES: la batería se repite contra copias de la migración con una regla quitada (4, 5, 6, el
# `user_id is not null` de la 6, los dos candados y los dos resets de rol) y cada copia TIENE que tumbar SU caso.
#
# Uso:  bash qa/cloud/g22_01-local-test.sh      → «g22_01 banco local: todo en verde», exit 0 solo si todo pasa.
# =====================================================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
MIG="$HERE/g22_01_set_member_role.sql"
RB="$HERE/g22_01_rollback.sql"
DDL="$ROOT/supabase-groups-staging.ddl"
PGBIN="${PGBIN:-/opt/homebrew/opt/postgresql@17/bin}"
[ -x "$PGBIN/initdb" ] || { echo "g22_01: no encuentro initdb en $PGBIN (exporta PGBIN)"; exit 2; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/g22_01.XXXXXX")"
PORT="${PORT:-55422}"
trap '"$PGBIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

"$PGBIN/initdb" -D "$WORK/data" -U postgres -A trust -E UTF8 --no-locale >/dev/null
# Por TCP y sin socket Unix: la ruta de un directorio temporal largo pasa de los 103 bytes que admite (molde g17_01).
"$PGBIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -c listen_addresses=127.0.0.1 -c unix_socket_directories=''" \
  -l "$WORK/log" -w start >/dev/null

DB=postgres
q() { "$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d "$DB" -v ON_ERROR_STOP=1 -q -X "$@"; }

# --- stubs de Supabase (molde hlc01-cap-test.sh; auth.uid() con la definición de Supabase, molde g17_01) ---------
q <<'SQL'
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create role authenticator noinherit login;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable as $f$
  select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'))::uuid $f$;
grant usage on schema auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
create schema extensions;
create extension pgcrypto schema extensions;
grant usage on schema extensions to authenticated;
grant usage on schema public to authenticated, anon;
-- `join_group` hace `insert into profiles (id)`; la tabla vive en el DDL personal.
create table public.profiles (id uuid primary key);
SQL

# --- DDL real de Grupos (trae `set local check_function_bodies = off`: va en UNA transacción) --------------------
q -1 -f "$DDL" >"$WORK/ddl.out" 2>&1 || { echo "g22_01: el DDL de Grupos no cargó:"; grep -v NOTICE "$WORK/ddl.out"; exit 1; }

# --- las personas y los grupos ------------------------------------------------------------------------------------
# O creador de G (member_key LEGACY, distinto de su uuid) · A admin · M miembro · P pendiente · L salió · D fila borrada
# H hueco sin reclamar (user_id null) · HA hueco admin · X ajeno a G y admin de G2 · S único admin activo de G3 (sin
# creador) con T miembro, U admin que salió y V admin borrado · S2 y A2 admins de G4 (sin creador), la carrera, y W
# miembro de G4 · K y Lv admins de G1 (a K lo expulsan y re-entra por el enlace `tok-g1`; Lv se va) · R único admin CON
# CUENTA de G5 (sin creador), al lado de un hueco admin.
q <<'SQL'
create function public.bench_seed() returns void language plpgsql as $f$
declare
  h0 text := '2026-01-01T00:00:00.000Z-0000-0000000000000000';
  fh jsonb := jsonb_build_object('profile', '2026-01-01T00:00:00.000Z-0000-0000000000000000', 'membership', h0);
begin
  truncate public.group_members, public.split_groups, public.group_seq_counters;
  delete from auth.users;
  insert into auth.users (id) select ('11111111-0000-0000-0000-0000000000' || lpad(i::text, 2, '0'))::uuid
    from generate_series(1, 18) i;
  truncate public.group_invites;
  insert into public.group_invites (token, group_id) values ('tok-g1', 'SplitGroup-G1');
  insert into public.split_groups (group_id, owner_user_id, hlc, field_hlcs) values
    ('SplitGroup-G1', '11111111-0000-0000-0000-000000000001', h0, fh),
    ('SplitGroup-G2', '11111111-0000-0000-0000-000000000006', h0, fh),
    ('SplitGroup-G3', null, h0, fh),
    ('SplitGroup-G4', null, h0, fh),
    ('SplitGroup-G5', null, h0, fh);
  insert into public.group_members (group_id, member_key, user_id, role, status, deleted, joined_at, hlc, field_hlcs) values
    ('SplitGroup-G1', 'legacy-o',                             '11111111-0000-0000-0000-000000000001', 'admin',  'active',          false, now(), h0, fh),
    ('SplitGroup-G1', '11111111-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000002', 'admin',  'active',          false, now(), h0, fh),
    ('SplitGroup-G1', '11111111-0000-0000-0000-000000000003', '11111111-0000-0000-0000-000000000003', 'member', 'active',          false, now(), h0, fh),
    ('SplitGroup-G1', '11111111-0000-0000-0000-000000000004', '11111111-0000-0000-0000-000000000004', 'admin',  'pendingApproval', false, now(), h0, fh),
    ('SplitGroup-G1', '11111111-0000-0000-0000-000000000005', '11111111-0000-0000-0000-000000000005', 'admin',  'left',            false, now(), h0, fh),
    ('SplitGroup-G1', '11111111-0000-0000-0000-000000000009', '11111111-0000-0000-0000-000000000009', 'member', 'active',          true,  now(), h0, fh),
    ('SplitGroup-G1', 'legacy-hueco',                         null,                                   'member', 'active',          false, now(), h0, fh),
    ('SplitGroup-G1', 'legacy-hueco-admin',                   null,                                   'admin',  'active',          false, now(), h0, fh),
    ('SplitGroup-G2', '11111111-0000-0000-0000-000000000006', '11111111-0000-0000-0000-000000000006', 'admin',  'active',          false, now(), h0, fh),
    ('SplitGroup-G3', '11111111-0000-0000-0000-000000000007', '11111111-0000-0000-0000-000000000007', 'admin',  'active',          false, now(), h0, fh),
    ('SplitGroup-G3', '11111111-0000-0000-0000-000000000010', '11111111-0000-0000-0000-000000000010', 'member', 'active',          false, now(), h0, fh),
    ('SplitGroup-G3', '11111111-0000-0000-0000-000000000011', '11111111-0000-0000-0000-000000000011', 'admin',  'left',            false, now(), h0, fh),
    ('SplitGroup-G3', '11111111-0000-0000-0000-000000000012', '11111111-0000-0000-0000-000000000012', 'admin',  'active',          true,  now(), h0, fh),
    ('SplitGroup-G4', '11111111-0000-0000-0000-000000000008', '11111111-0000-0000-0000-000000000008', 'admin',  'active',          false, now(), h0, fh),
    ('SplitGroup-G4', '11111111-0000-0000-0000-000000000013', '11111111-0000-0000-0000-000000000013', 'admin',  'active',          false, now(), h0, fh),
    ('SplitGroup-G4', '11111111-0000-0000-0000-000000000017', '11111111-0000-0000-0000-000000000017', 'member', 'active',          false, now(), h0, fh),
    ('SplitGroup-G1', '11111111-0000-0000-0000-000000000014', '11111111-0000-0000-0000-000000000014', 'admin',  'active',          false, now(), h0, fh),
    ('SplitGroup-G1', '11111111-0000-0000-0000-000000000015', '11111111-0000-0000-0000-000000000015', 'admin',  'active',          false, now(), h0, fh),
    ('SplitGroup-G5', '11111111-0000-0000-0000-000000000016', '11111111-0000-0000-0000-000000000016', 'admin',  'active',          false, now(), h0, fh),
    ('SplitGroup-G5', 'legacy-hueco-admin-g5',                null,                                   'admin',  'active',          false, now(), h0, fh);
end $f$;
SQL

O=11111111-0000-0000-0000-000000000001; A=11111111-0000-0000-0000-000000000002; M=11111111-0000-0000-0000-000000000003
P=11111111-0000-0000-0000-000000000004; L=11111111-0000-0000-0000-000000000005; X=11111111-0000-0000-0000-000000000006
S=11111111-0000-0000-0000-000000000007; S2=11111111-0000-0000-0000-000000000008; D=11111111-0000-0000-0000-000000000009
T=11111111-0000-0000-0000-000000000010; U=11111111-0000-0000-0000-000000000011; V=11111111-0000-0000-0000-000000000012
A2=11111111-0000-0000-0000-000000000013; K=11111111-0000-0000-0000-000000000014; Lv=11111111-0000-0000-0000-000000000015
R=11111111-0000-0000-0000-000000000016; W=11111111-0000-0000-0000-000000000017
G1=SplitGroup-G1; G2=SplitGroup-G2; G3=SplitGroup-G3; G4=SplitGroup-G4; G5=SplitGroup-G5

seed() { q -c "select public.bench_seed()" >/dev/null; }

# Ejecuta `$2` (una sentencia SQL) como PostgREST: `role authenticated`, el sub en los claims (vacío = sin sesión).
# Imprime su resultado, o `ERR:<sqlstate>:<mensaje>` si falla.
sql_as() {
  local sub="$1" stmt="$2" out
  out=$("$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d "$DB" -X -q -tA -v ON_ERROR_STOP=1 \
        -v sub="$sub" 2>&1 <<SQL
\\set VERBOSITY verbose
begin;
set local role authenticated;
-- \\gset: guarda el resultado en una variable y no imprime nada. (Un \`select … where false\` alrededor NO sirve: el
-- planificador no evalúa el set_config y la llamada sale sin sesión.)
select set_config('request.jwt.claims',
  case when :'sub' = '' then '' else json_build_object('sub', :'sub')::text end, true) as _claims \\gset
$stmt;
commit;
SQL
  ) || true
  if grep -q 'ERROR:' <<<"$out"; then
    sed -nE 's/.*ERROR: +([0-9A-Z]{5}): (.*)$/ERR:\1:\2/p' <<<"$out" | head -1
  else
    printf '%s\n' "$out" | tail -1
  fi
}
# Comillas simples de SQL para un literal.
lit() { if [[ "$1" == '<null>' ]]; then echo null; else printf "'%s'" "${1//\'/\'\'}"; fi; }
# set_member_role como lo llama la app. $4 = `<null>` manda un rol NULL.
call() { sql_as "$1" "select public.set_member_role($(lit "$2"), $(lit "$3"), $(lit "$4"))"; }

# Una fila de group_members como `rol|status|hlc|membership|profile|server_seq|updated_at`.
fila() { q -tA -c "select role||'|'||status||'|'||hlc||'|'||coalesce(field_hlcs->>'membership','-')||'|'||coalesce(field_hlcs->>'profile','-')||'|'||server_seq||'|'||updated_at from public.group_members where group_id='$1' and member_key='$2'"; }
rol() { q -tA -c "select role from public.group_members where group_id='$1' and member_key='$2'"; }
admins_activos() { q -tA -c "select count(*) from public.group_members where group_id='$1' and deleted=false and status='active' and role='admin'"; }

fallos=0
ok()  { echo "  ✓ $1"; }
mal() { echo "  ✗ $1"; fallos=$((fallos + 1)); }
espera() {  # $1 etiqueta · $2 esperado (prefijo) · $3 obtenido
  if [[ "$3" == "$2"* ]]; then ok "$1"; else mal "$1 — esperaba «$2…», salió «$3»"; fi
}
role_of() {  # el rol de una respuesta, o el ERR tal cual
  if [[ "$1" == ERR:* ]]; then echo "$1"; else jq -r '.role // "sin-rol"' <<<"$1" 2>/dev/null || echo "no-json:$1"; fi
}
json_es() {  # $1 etiqueta · $2 jsonb esperado · $3 obtenido: compara como JSON
  if [[ "$3" != ERR:* ]] && [[ "$(jq -S -c . <<<"$3" 2>/dev/null)" == "$(jq -S -c . <<<"$2")" ]]; then ok "$1"
  else mal "$1 — esperaba $2, salió «$3»"; fi
}

bateria() {
  fallos=0

  echo "1 · quien llama"
  seed
  espera "sin sesión → not_authorized"                      "ERR:P0001:yala_not_authorized" "$(call "" "$G1" "$M" admin)"
  espera "un miembro → not_authorized"                      "ERR:P0001:yala_not_authorized" "$(call "$M" "$G1" "$M" admin)"
  espera "un admin pendiente → not_authorized"              "ERR:P0001:yala_not_authorized" "$(call "$P" "$G1" "$M" admin)"
  espera "un admin que salió → not_authorized"              "ERR:P0001:yala_not_authorized" "$(call "$L" "$G1" "$M" admin)"
  espera "el admin de OTRO grupo → not_authorized"          "ERR:P0001:yala_not_authorized" "$(call "$X" "$G1" "$M" admin)"
  [[ "$(rol "$G1" "$M")" == member ]] && ok "ningún rechazo escribió" || mal "un rechazo cambió el rol"
  json_es "control: un admin activo SÍ"  "{\"group_id\":\"$G1\",\"member_key\":\"$M\",\"role\":\"admin\",\"changed\":true}" "$(call "$A" "$G1" "$M" admin)"
  seed
  espera "control: el creador (member_key legacy) SÍ"       admin              "$(role_of "$(call "$O" "$G1" "$M" admin)")"

  echo "2 · el rol pedido"
  seed
  espera "«owner» → bad_input"                              "ERR:P0001:yala_bad_input"      "$(call "$A" "$G1" "$M" owner)"
  espera "«Admin» (mayúscula) → bad_input"                  "ERR:P0001:yala_bad_input"      "$(call "$A" "$G1" "$M" Admin)"
  espera "NULL → bad_input"                                 "ERR:P0001:yala_bad_input"      "$(call "$A" "$G1" "$M" '<null>')"
  espera "vacío → bad_input"                                "ERR:P0001:yala_bad_input"      "$(call "$A" "$G1" "$M" '')"
  espera "control: «member» SÍ (no es bad_input)"           member             "$(role_of "$(call "$A" "$G1" "$M" member)")"

  echo "3 · el objetivo"
  seed
  espera "member_key inexistente → member_not_found"        "ERR:P0001:yala_member_not_found" "$(call "$A" "$G1" "nadie" admin)"
  espera "pendiente → member_not_found"                     "ERR:P0001:yala_member_not_found" "$(call "$A" "$G1" "$P" member)"
  espera "que salió → member_not_found"                     "ERR:P0001:yala_member_not_found" "$(call "$A" "$G1" "$L" member)"
  espera "fila borrada → member_not_found"                  "ERR:P0001:yala_member_not_found" "$(call "$A" "$G1" "$D" admin)"
  espera "miembro de OTRO grupo → member_not_found"         "ERR:P0001:yala_member_not_found" "$(call "$A" "$G1" "$X" admin)"
  [[ "$(rol "$G1" "$P")" == admin && "$(rol "$G2" "$X")" == admin ]] && ok "ningún rechazo escribió" || mal "un rechazo escribió"
  espera "control: el activo SÍ"                            admin              "$(role_of "$(call "$A" "$G1" "$M" admin)")"

  echo "4 · el creador"
  seed
  espera "quitarle el admin → cannot_change_owner_role"     "ERR:P0001:yala_cannot_change_owner_role" "$(call "$A" "$G1" "legacy-o" member)"
  espera "ni él a sí mismo → cannot_change_owner_role"      "ERR:P0001:yala_cannot_change_owner_role" "$(call "$O" "$G1" "legacy-o" member)"
  [[ "$(rol "$G1" legacy-o)" == admin ]] && ok "el creador sigue admin" || mal "el creador perdió el admin"
  json_es "control: pedirle admin (ya lo es) → changed:false" "{\"group_id\":\"$G1\",\"member_key\":\"legacy-o\",\"role\":\"admin\",\"changed\":false}" "$(call "$A" "$G1" "legacy-o" admin)"
  espera "control: a otro admin SÍ se le quita"             member             "$(role_of "$(call "$O" "$G1" "$A" member)")"

  echo "5 · el hueco sin reclamar"
  seed
  espera "hacerlo admin → member_not_eligible"              "ERR:P0001:yala_member_not_eligible" "$(call "$A" "$G1" "legacy-hueco" admin)"
  [[ "$(rol "$G1" legacy-hueco)" == member ]] && ok "el hueco sigue miembro" || mal "el hueco salió admin"
  espera "control: a un hueco ADMIN sí se le quita"         member             "$(role_of "$(call "$A" "$G1" "legacy-hueco-admin" member)")"
  espera "control: un miembro con cuenta sí sale admin"     admin              "$(role_of "$(call "$A" "$G1" "$M" admin)")"

  echo "6 · el último admin"
  seed
  espera "el único admin activo (sin creador) se lo quita → last_admin" "ERR:P0001:yala_last_admin" "$(call "$S" "$G3" "$S" member)"
  [[ "$(admins_activos "$G3")" == 1 ]] && ok "el grupo conserva su admin (los que salieron o borrados no cuentan)" || mal "G3 sin admin"
  espera "control: con otro admin activo, sí"               member             "$(role_of "$(call "$S2" "$G4" "$S2" member)")"
  [[ "$(admins_activos "$G4")" == 1 ]] && ok "G4 sigue con un admin" || mal "G4 sin el admin que quedaba"
  espera "control: G3 sigue dejando hacer admin a un miembro" admin            "$(role_of "$(call "$S" "$G3" "$T" admin)")"
  espera "…y entonces S ya puede quitárselo"                member             "$(role_of "$(call "$S" "$G3" "$S" member)")"
  seed
  espera "el único admin CON CUENTA (al lado de un hueco admin) se lo quita → last_admin" "ERR:P0001:yala_last_admin" "$(call "$R" "$G5" "$R" member)"
  [[ "$(rol "$G5" "$R")" == admin ]] && ok "R sigue admin: un hueco no cuenta como sucesor" || mal "G5 se quedó solo con el hueco admin"
  espera "control: R sí puede quitarle el admin al hueco"   member             "$(role_of "$(call "$R" "$G5" "legacy-hueco-admin-g5" member)")"

  echo "7 · idempotencia"
  seed
  call "$A" "$G1" "$M" admin >/dev/null
  local antes despues r2
  antes="$(fila "$G1" "$M")"
  r2="$(call "$A" "$G1" "$M" admin)"
  despues="$(fila "$G1" "$M")"
  json_es "el mismo rol otra vez → changed:false" "{\"group_id\":\"$G1\",\"member_key\":\"$M\",\"role\":\"admin\",\"changed\":false}" "$r2"
  [[ "$antes" == "$despues" ]] && ok "no escribió nada (hlc, server_seq, updated_at iguales)" || mal "la repetición escribió: $antes → $despues"
  json_es "un miembro que ya es miembro → changed:false" "{\"group_id\":\"$G1\",\"member_key\":\"legacy-hueco\",\"role\":\"member\",\"changed\":false}" "$(call "$A" "$G1" "legacy-hueco" member)"

  echo "8 · la escritura"
  seed
  local pre post seq0 seq1 hlc mem prof res
  pre="$(fila "$G1" "$M")"; seq0="$(cut -d'|' -f6 <<<"$pre")"
  res="$(call "$A" "$G1" "$M" admin)"
  post="$(fila "$G1" "$M")"
  IFS='|' read -r _r _st hlc mem prof seq1 _u <<<"$post"
  json_es "respuesta con la forma exacta" "{\"group_id\":\"$G1\",\"member_key\":\"$M\",\"role\":\"admin\",\"changed\":true}" "$res"
  [[ "$_r" == admin && "$_st" == active ]] && ok "rol escrito, estado intacto" || mal "rol/estado: $post"
  [[ "$hlc" =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9:.]{12}Z-0000-0000000000000000$ && "$hlc" != 2026-01-01T* ]] \
    && ok "hlc nuevo con el formato del servidor ($hlc)" || mal "hlc: $hlc"
  [[ "$mem" == "$hlc" ]] && ok "field_hlcs.membership = hlc" || mal "membership $mem ≠ hlc $hlc"
  [[ "$prof" == 2026-01-01T00:00:00.000Z-0000-0000000000000000 ]] && ok "field_hlcs.profile intacto" || mal "profile: $prof"
  (( seq1 > seq0 )) && ok "server_seq sube ($seq0 → $seq1, lo pone el trigger)" || mal "server_seq $seq0 → $seq1"
  [[ "$(fila "$G1" "$A")" == admin\|active\|2026-01-01T* ]] && ok "la fila de quien llama no se tocó" || mal "la fila del admin cambió"

  echo "9 · grants"
  local anon_out
  anon_out=$("$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d "$DB" -X -q -tA -v ON_ERROR_STOP=1 2>&1 <<SQL || true
\set VERBOSITY verbose
begin; set local role anon; select public.set_member_role('$G1', '$M', 'admin'); commit;
SQL
  )
  grep -q '42501' <<<"$anon_out" && ok "anon → permiso denegado (42501)" || mal "anon pudo llamarla: $anon_out"
  [[ "$(q -tA -c "select has_function_privilege('authenticated', 'public.set_member_role(text,text,text)', 'EXECUTE')")" == t ]] \
    && ok "authenticated puede ejecutarla" || mal "authenticated no puede"
  [[ "$(q -tA -c "select prosecdef::text || '|' || array_to_string(proconfig, ',') from pg_proc where proname='set_member_role'")" == "true|search_path=public" ]] \
    && ok "SECURITY DEFINER con search_path=public" || mal "ni definer ni search_path"

  echo "10 · dos admins que se lo quitan el uno al otro a la vez (G4, sin creador)"
  seed
  # Sesión 1: S2 le quita el admin a A2 y NO confirma en 3 s. Sesión 2, 1 s después: A2 le quita el admin a S2.
  ( "$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d "$DB" -X -q -tA -v ON_ERROR_STOP=1 >"$WORK/s1.out" 2>&1 <<SQL
begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '$S2')::text, true) as _claims \gset
select public.set_member_role('$G4', '$A2', 'member');
select pg_sleep(3);
commit;
SQL
  ) &
  local pid1=$!
  sleep 1
  local carrera
  carrera="$(call "$A2" "$G4" "$S2" member)"
  wait "$pid1" || true
  espera "el segundo espera y lo para la regla 1 → not_authorized" "ERR:P0001:yala_not_authorized" "$carrera"
  [[ "$(admins_activos "$G4")" == 1 ]] && ok "G4 conserva un admin" || mal "G4 se quedó con $(admins_activos "$G4") admins"

  echo "13 · salir del grupo deja de ser admin (remove_member / leave_group)"
  seed
  local rr
  rr="$(sql_as "$A" "select public.remove_member('$G1', '$K')")"
  [[ "$rr" == *'"removed"'* ]] && ok "expulsar a un admin → removed" || mal "expulsar a un admin: $rr"
  [[ "$(rol "$G1" "$K")" == member ]] && ok "…y su rol queda member" || mal "…y su rol queda member — el expulsado conserva role=$(rol "$G1" "$K")"
  rr="$(sql_as "$Lv" "select public.leave_group('$G1')")"
  [[ "$rr" == *'"left"'* && "$(rol "$G1" "$Lv")" == member ]] && ok "salir siendo admin → left y member" || mal "salir siendo admin → left y member — $rr, role=$(rol "$G1" "$Lv")"
  rr="$(sql_as "$K" "select public.join_group('tok-g1', 'K', 'k-bench')")"
  [[ "$rr" == *pendingApproval* && "$(rol "$G1" "$K")" == member ]] && ok "re-entrar por el enlace → pendiente y member (sin insignia)" || mal "re-entrar por el enlace → pendiente y member — $rr, role=$(rol "$G1" "$K")"
  rr="$(sql_as "$A" "select public.approve_member('$G1', '$K')")"
  [[ "$rr" == *active* && "$(rol "$G1" "$K")" == member ]] && ok "aprobarlo → active y member: nadie decidió hacerlo admin" || mal "aprobarlo → active y member — $rr, role=$(rol "$G1" "$K")"
  rr="$(sql_as "$A" "select public.remove_member('$G1', '$P')")"
  [[ "$rr" == *rejected* && "$(rol "$G1" "$P")" == member ]] && ok "rechazar una solicitud con rol admin → rejected y member" || mal "rechazar una solicitud con rol admin — $rr, role=$(rol "$G1" "$P")"
  espera "control: al creador no se le expulsa (sin cambios)" "ERR:P0001:yala_cannot_remove_owner" "$(sql_as "$A" "select public.remove_member('$G1', 'legacy-o')")"
  espera "control: el creador no se va (sin cambios)"       "ERR:P0001:yala_owner_cannot_leave" "$(sql_as "$O" "select public.leave_group('$G1')")"
  [[ "$(rol "$G1" legacy-o)" == admin ]] && ok "…y sigue admin" || mal "el creador perdió el admin"
  espera "control: un miembro no expulsa (sin cambios)"     "ERR:P0001:yala_not_authorized" "$(sql_as "$M" "select public.remove_member('$G1', '$A')")"
  rr="$(q -tA -c "select field_hlcs->>'membership' = hlc from public.group_members where group_id='$G1' and member_key='$Lv'")"
  [[ "$rr" == t ]] && ok "la salida sella field_hlcs.membership (el rol va en esa unidad)" || mal "membership no sellado: $rr"

  echo "14 · remove_member también mira el admin bajo candado (G4)"
  seed
  # Sesión 1: S2 le quita el admin a A2 y no confirma en 3 s. Sesión 2, 1 s después: A2 intenta expulsar a W.
  ( "$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d "$DB" -X -q -tA -v ON_ERROR_STOP=1 >"$WORK/s1b.out" 2>&1 <<SQL
begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '$S2')::text, true) as _claims \gset
select public.set_member_role('$G4', '$A2', 'member');
select pg_sleep(3);
commit;
SQL
  ) &
  local pid2=$!
  sleep 1
  local carrera2
  carrera2="$(sql_as "$A2" "select public.remove_member('$G4', '$W')")"
  wait "$pid2" || true
  espera "el que acaba de dejar de ser admin ya no expulsa → not_authorized" "ERR:P0001:yala_not_authorized" "$carrera2"
  [[ "$(q -tA -c "select status from public.group_members where group_id='$G4' and member_key='$W'")" == active ]] && ok "W sigue dentro" || mal "W fue expulsado por un no-admin"

  echo "11 · re-aplicar y marcha atrás"
  if q -1 -f "$1" >"$WORK/re.out" 2>&1 && grep -q 'g22_01 OK' "$WORK/re.out"; then ok "re-aplicar es no-op y vuelve a comprobar"
  else mal "re-aplicar falló"; sed 's/^/    /' "$WORK/re.out"; fi
  seed
  espera "sigue funcionando tras re-aplicar"                admin              "$(role_of "$(call "$A" "$G1" "$M" admin)")"
}

# md5(prosrc) de los dos cuerpos que g22_01 redefine: los del DDL (de partida) y los de la migración. Si cambia el
# cuerpo de la migración, cambia el DESPUES y hay que fijarlo también en los dos .sql.
RM_ANTES=e716f203c405437c95c82e47deae61b5;   LG_ANTES=a4bbcff1bca1ac1cec09f372d577d1cc
RM_DESPUES=efce7084cb5cb5c902948f156c09f148; LG_DESPUES=f4820b999e862b2f0ee6192855982318
md5s() { q -tA -c "select (select md5(prosrc) from pg_proc where oid = 'public.remove_member(text, text)'::regprocedure) || '|' || (select md5(prosrc) from pg_proc where oid = 'public.leave_group(text)'::regprocedure)"; }
# Cambia un literal del cuerpo vivo de remove_member (para fingir un cuerpo que no es el del molde, y deshacerlo).
retocar_remove_member() {
  q -v de="$1" -v a="$2" >/dev/null <<'SQL'
select set_config('g22.de', :'de', false) as _de, set_config('g22.a', :'a', false) as _a \gset
do $d$
declare v text;
begin
  select prosrc into v from pg_proc where oid = 'public.remove_member(text, text)'::regprocedure;
  execute format('create or replace function public.remove_member(p_group_id text, p_member_key text) returns jsonb language plpgsql security definer set search_path = public as %L',
                 replace(v, current_setting('g22.de'), current_setting('g22.a')));
end $d$;
SQL
}

aplicar() { q -1 -f "$1" >"$WORK/apply.out" 2>&1 || { echo "  ✗ la migración no aplicó:"; sed 's/^/    /' "$WORK/apply.out"; exit 1; }; }

echo "== 0 · la guarda de los dos cuerpos"
g0=0
[[ "$(md5s)" == "$RM_ANTES|$LG_ANTES" ]] && echo "  ✓ el DDL cargado trae los md5 de partida que la guarda espera" || { echo "  ✗ md5 de partida: $(md5s)"; g0=$((g0 + 1)); }
# Un cuerpo vivo distinto del molde (aquí, un literal cambiado) → la migración aborta sin tocar nada.
retocar_remove_member "yala_cannot_remove_owner" "yala_cannot_remove_owner_x"
DIVERGIDO="$(md5s)"
[[ "$DIVERGIDO" != "$RM_ANTES|$LG_ANTES" ]] || { echo "  ✗ el retoque no cambió el cuerpo"; g0=$((g0 + 1)); }
if q -1 -f "$MIG" >"$WORK/g0.out" 2>&1; then echo "  ✗ la migración se aplicó sobre un remove_member divergido"; g0=$((g0 + 1))
elif grep -q 'g22_01: remove_member no es' "$WORK/g0.out"; then echo "  ✓ cuerpo divergido → aborta en la guarda"
else echo "  ✗ abortó, pero no en la guarda:"; sed 's/^/    /' "$WORK/g0.out"; g0=$((g0 + 1)); fi
[[ "$(md5s)" == "$DIVERGIDO" && "$(q -tA -c "select count(*) from pg_proc where proname = 'set_member_role'")" == 0 ]] \
  && echo "  ✓ no tocó nada (ni remove_member ni set_member_role)" || { echo "  ✗ tocó algo"; g0=$((g0 + 1)); }
retocar_remove_member "yala_cannot_remove_owner_x" "yala_cannot_remove_owner"
[[ "$(md5s)" == "$RM_ANTES|$LG_ANTES" ]] && echo "  ✓ devuelto al cuerpo del DDL" || { echo "  ✗ no volvió: $(md5s)"; g0=$((g0 + 1)); }

echo "== g22_01 · la migración tal cual"
aplicar "$MIG"
grep -q 'g22_01 OK' "$WORK/apply.out" && echo "  ✓ aplicó con su comprobación de grants y de cuerpos" || { echo "  ✗ sin el aviso g22_01 OK"; exit 1; }
[[ "$(md5s)" == "$RM_DESPUES|$LG_DESPUES" ]] && echo "  ✓ remove_member y leave_group con el md5 fijado" || { echo "  ✗ md5 tras aplicar: $(md5s)"; g0=$((g0 + 1)); }
bateria "$MIG"
total_real=$((fallos + g0))

echo "12 · marcha atrás"
rb_fallos=0
if q -1 -f "$RB" >"$WORK/rb.out" 2>&1 && grep -q 'g22_01_rollback OK' "$WORK/rb.out"; then echo "  ✓ rollback aplicado"
else echo "  ✗ el rollback abortó"; sed 's/^/    /' "$WORK/rb.out"; rb_fallos=$((rb_fallos + 1)); fi
[[ "$(md5s)" == "$RM_ANTES|$LG_ANTES" ]] && echo "  ✓ los dos cuerpos vuelven al md5 del DDL" || { echo "  ✗ tras el rollback: $(md5s)"; rb_fallos=$((rb_fallos + 1)); }
seed
r="$(call "$A" "$G1" "$M" admin)"
if [[ "$r" == ERR:42883:* ]]; then echo "  ✓ tras el rollback la función no existe (42883)"; else echo "  ✗ tras el rollback: $r"; rb_fallos=$((rb_fallos + 1)); fi
sql_as "$A" "select public.remove_member('$G1', '$K')" >/dev/null
[[ "$(rol "$G1" "$K")" == admin ]] && echo "  ✓ y expulsar vuelve a dejar el rol como estaba (el comportamiento del DDL)" || { echo "  ✗ tras el rollback el expulsado quedó $(rol "$G1" "$K")"; rb_fallos=$((rb_fallos + 1)); }
if q -1 -f "$RB" >/dev/null 2>&1; then echo "  ✓ un segundo rollback no falla"; else echo "  ✗ el segundo rollback falló"; rb_fallos=$((rb_fallos + 1)); fi
retocar_remove_member "yala_cannot_remove_owner" "yala_cannot_remove_owner_x"
if q -1 -f "$RB" >"$WORK/rb2.out" 2>&1; then echo "  ✗ el rollback se aplicó sobre un remove_member divergido"; rb_fallos=$((rb_fallos + 1))
elif grep -q 'g22_01_rollback: remove_member no es' "$WORK/rb2.out"; then echo "  ✓ rollback sobre un cuerpo divergido → aborta en su guarda"
else echo "  ✗ el rollback abortó, pero no en la guarda"; sed 's/^/    /' "$WORK/rb2.out"; rb_fallos=$((rb_fallos + 1)); fi
retocar_remove_member "yala_cannot_remove_owner_x" "yala_cannot_remove_owner"

# --- mutantes: cada copia quita UNA regla; la batería tiene que caer -------------------------------------------
# Muerto no basta: tiene que caer el caso de SU regla. La primera versión de este banco llamaba al RPC sin sesión por
# un `set_config` que el planificador no evaluaba, y los cuatro mutantes «morían» por el mismo rojo de todo.
# Cada mutante se aplica sobre los cuerpos del DDL (restaurados con el rollback sin su guarda) y con la comprobación
# final de md5 apagada: un mutante de remove_member / leave_group cambia su md5 a propósito.
mutante() {  # $1 nombre · $2 texto a quitar (literal, una sola vez) · $3 sustituto · $4 el caso que tiene que caer
  local f="$WORK/mut-$1.sql"
  python3 "$WORK/mutar.py" "$MIG" "$f" "$2" "$3" || return 1
  python3 "$WORK/sin_guarda.py" "$RB" "$WORK/restaurar.sql" || return 1
  q -1 -f "$WORK/restaurar.sql" >/dev/null 2>&1 || { echo "  ✗ no pude restaurar los cuerpos antes del mutante «$1»"; return 1; }
  aplicar "$f"
  bateria "$f" >"$WORK/mut-$1.out" 2>&1 || true
  local caidos=$fallos
  if (( caidos > 0 )) && grep -qF "✗ $4" "$WORK/mut-$1.out"; then
    echo "  ✓ mutante «$1» muerto ($caidos caso(s) en rojo, entre ellos «$4»)"
    return 0
  fi
  echo "  ✗ mutante «$1» VIVO, o muerto por otro caso: no cayó «$4» ($caidos rojo(s))"; return 1
}

cat >"$WORK/mutar.py" <<'PY'
import sys
src, dst, old, new = sys.argv[1:5]
text = open(src, encoding="utf-8").read()
n = text.count(old)
if n != 1:
    sys.exit(f"mutante: el texto aparece {n} veces, se esperaba 1: {old!r}")
text = text.replace(old, new)
for fn in ("remove_member(text, text)", "leave_group(text)"):
    check = f"  if (select md5(prosrc) from pg_proc where oid = 'public.{fn}'::regprocedure) <> "
    if text.count(check) != 1:
        sys.exit(f"mutante: no encuentro la comprobación de md5 de {fn}")
    text = text.replace(check, "  if false and (select md5(prosrc) from pg_proc where oid = 'public." + fn + "'::regprocedure) <> ")
open(dst, "w", encoding="utf-8").write(text)
PY
cat >"$WORK/sin_guarda.py" <<'PY'
import sys
src, dst = sys.argv[1:3]
text = open(src, encoding="utf-8").read()
for var in ("v_rm", "v_lg"):
    old = f"  if {var} is null or {var} not in ("
    if text.count(old) != 1:
        sys.exit(f"sin_guarda: no encuentro {old!r}")
    text = text.replace(old, f"  if false and {var} not in (")
open(dst, "w", encoding="utf-8").write(text)
PY

echo "== mutantes"
mut_vivos=0
mutante "sin regla 4 (creador)" \
  "if p_role = 'member' and v_owner is not null and v_target.user_id = v_owner then" "if false then" \
  "quitarle el admin → cannot_change_owner_role" || mut_vivos=$((mut_vivos + 1))
mutante "sin regla 5 (hueco)" \
  "if p_role = 'admin' and v_target.user_id is null then" "if false then" \
  "hacerlo admin → member_not_eligible" || mut_vivos=$((mut_vivos + 1))
mutante "sin regla 6 (último admin)" \
  "if v_others = 0 then" "if false then" \
  "el único admin activo (sin creador) se lo quita → last_admin" || mut_vivos=$((mut_vivos + 1))
mutante "regla 6 contando huecos" \
  " and role = 'admin' and user_id is not null;" " and role = 'admin';" \
  "el único admin CON CUENTA (al lado de un hueco admin) se lo quita → last_admin" || mut_vivos=$((mut_vivos + 1))
mutante "sin el candado de set_member_role" \
  "  -- y quien acaba de dejar de ser admin ya no pasa.
  perform 1 from group_members
    where group_id = p_group_id and deleted = false
      and ((status = 'active' and role = 'admin') or member_key = p_member_key)
    order by member_key
    for update;" "  perform 1;" \
  "el segundo espera y lo para la regla 1 → not_authorized" || mut_vivos=$((mut_vivos + 1))
mutante "sin el candado de remove_member" \
  "  -- tenía el candado antes (molde de set_member_role).
  perform 1 from group_members
    where group_id = p_group_id and deleted = false
      and ((status = 'active' and role = 'admin') or member_key = p_member_key)
    order by member_key
    for update;" "  perform 1;" \
  "el que acaba de dejar de ser admin ya no expulsa → not_authorized" || mut_vivos=$((mut_vivos + 1))
mutante "remove_member sin el reset de rol" \
  "    role       = 'member',   -- g22_01: quien sale expulsado deja de ser admin
" "" \
  "…y su rol queda member" || mut_vivos=$((mut_vivos + 1))
mutante "leave_group sin el reset de rol" \
  "    role       = 'member',   -- g22_01: quien se va deja de ser admin
" "" \
  "salir siendo admin → left y member" || mut_vivos=$((mut_vivos + 1))

echo
todo=$((total_real + rb_fallos + mut_vivos))
if [[ $todo -eq 0 ]]; then echo "g22_01 banco local: todo en verde"
else echo "g22_01 banco local: $total_real fallo(s) en la batería, $rb_fallos en la marcha atrás, $mut_vivos mutante(s) vivo(s)"; exit 1; fi
