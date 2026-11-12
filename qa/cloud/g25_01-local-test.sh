#!/usr/bin/env bash
# =====================================================================================================
# g25_01 · banco LOCAL de `groups_forget_user` que nunca deja un grupo vivo sin admin con cuenta, sin tocar staging ni
# producción
#
# Levanta un Postgres desechable, carga el DDL REAL de Grupos (`supabase-groups-staging.ddl`, entero) con los stubs
# mínimos de Supabase (roles, `auth.uid()` leyendo `request.jwt.claims`, pgcrypto, `profiles`), aplica la migración y
# llama a los RPC como los llama PostgREST: `role authenticated` con el `sub` en los claims (molde g22_01).
#
# Qué prueba, cada regla con su control al lado:
#   0. la guarda: el DDL cargado trae el md5 de partida fijado; con un cuerpo divergido la migración aborta sin tocar
#      nada (y el rollback también)
#   1. `create_group` deja al creador admin/active con su user_id: el invariante nace bien
#   2. el dueño que se borra con heredero: propiedad transferida, heredero admin, el grupo sin heredero se tombstonea
#      (comportamiento previo intacto) y el paso nuevo no promueve a nadie más
#   3. grupo SIN creador donde quien se borra era el único admin con cuenta → el miembro activo más antiguo con cuenta
#      queda admin (hlc, membership y server_seq sellados), en cada grupo así; el invariante se cumple
#   4. control: si queda OTRO admin activo con cuenta, nadie más sale admin (admins_promoted = 0, filas intactas)
#   5. sin heredero (era el único con cuenta) → nadie promovido, no falla, el grupo sigue vivo
#   6. un pendiente, un expulsado, un hueco sin user_id o una fila borrada nunca es heredero (ni siendo admin y más
#      antiguo), y si solo quedan ellos no se promueve a nadie
#   7. control: quien no es admin ACTIVO (un admin pendiente) no dispara el paso
#   8. sin sesión → yala_not_authorized, sin escribir
#   9. la respuesta conserva sus tres claves y añade `admins_promoted`
#  10. grants: anon no la ejecuta, authenticated sí; SECURITY DEFINER con el mismo search_path
#  11. re-aplicar la migración es no-op y sigue funcionando
#  12. el rollback devuelve el md5 de partida (y con él, el hueco), es re-ejecutable y tiene su guarda
# Y después, los MUTANTES: la batería se repite contra copias de la migración con una pieza quitada (el paso nuevo
# entero, el `status = 'active'` y el `deleted = false` del heredero, la mirada a «queda otro admin» y la de «quien
# llama es admin activo») y cada copia TIENE que tumbar SU caso.
#
# Uso:  bash qa/cloud/g25_01-local-test.sh      → «g25_01 banco local: todo en verde», exit 0 solo si todo pasa.
# =====================================================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
MIG="$HERE/g25_01_forget_user_keeps_an_admin.sql"
RB="$HERE/g25_01_rollback.sql"
DDL="$ROOT/supabase-groups-staging.ddl"
PGBIN="${PGBIN:-/opt/homebrew/opt/postgresql@17/bin}"
[ -x "$PGBIN/initdb" ] || { echo "g25_01: no encuentro initdb en $PGBIN (exporta PGBIN)"; exit 2; }
command -v jq >/dev/null || { echo "g25_01: hace falta jq"; exit 2; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/g25_01.XXXXXX")"
PORT="${PORT:-55425}"
trap '"$PGBIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

"$PGBIN/initdb" -D "$WORK/data" -U postgres -A trust -E UTF8 --no-locale >/dev/null
# Por TCP y sin socket Unix: la ruta de un directorio temporal largo pasa de los 103 bytes que admite (molde g17_01).
"$PGBIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -c listen_addresses=127.0.0.1 -c unix_socket_directories=''" \
  -l "$WORK/log" -w start >/dev/null

DB=postgres
q() { "$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d "$DB" -v ON_ERROR_STOP=1 -q -X "$@"; }

# --- stubs de Supabase (molde g22_01) ------------------------------------------------------------------------------
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
-- `create_group` hace `insert into profiles (id)`; la tabla vive en el DDL personal.
create table public.profiles (id uuid primary key);
SQL

# --- DDL real de Grupos (trae `set local check_function_bodies = off`: va en UNA transacción) --------------------
q -1 -f "$DDL" >"$WORK/ddl.out" 2>&1 || { echo "g25_01: el DDL de Grupos no cargó:"; grep -v NOTICE "$WORK/ddl.out"; exit 1; }

# --- las personas y los grupos ------------------------------------------------------------------------------------
# G1: dueño O, con B (miembro más antiguo, el heredero) y C · G2: dueño O, solo (se tombstonea).
# G3 (sin creador): S único admin con cuenta; más antiguos que T pero NO herederos: P admin pendiente, Rm admin
#   expulsado, Dl admin con la fila borrada, un hueco admin y un hueco miembro (user_id null); T miembro activo (el
#   heredero) y T2, más nuevo. G8 (sin creador): S admin y U miembro.
# G4 (sin creador): E admin, F otro admin con cuenta, Gm miembro · G5 (sin creador): N admin y un hueco (sin heredero).
# G6 (sin creador): I admin; solo quedan P2 pendiente, R2 expulsado, un hueco y D2 con la fila borrada.
# G7 (sin creador): Q admin PENDIENTE, Z miembro activo y un hueco admin (un grupo que ya llega roto).
q <<'SQL'
create function public.bench_seed() returns void language plpgsql as $f$
declare
  h0 text := '2026-01-01T00:00:00.000Z-0000-0000000000000000';
  fh jsonb := jsonb_build_object('profile', '2026-01-01T00:00:00.000Z-0000-0000000000000000', 'membership', h0);
  t0 timestamptz := '2026-01-01 00:00:00+00';
begin
  truncate public.group_members, public.split_groups, public.group_seq_counters, public.push_tokens;
  delete from auth.users;
  insert into auth.users (id) select ('22222222-0000-0000-0000-0000000000' || lpad(i::text, 2, '0'))::uuid
    from generate_series(1, 21) i;
  insert into public.split_groups (group_id, owner_user_id, hlc, field_hlcs) values
    ('SplitGroup-G1', '22222222-0000-0000-0000-000000000001', h0, fh),
    ('SplitGroup-G2', '22222222-0000-0000-0000-000000000001', h0, fh),
    ('SplitGroup-G3', null, h0, fh),
    ('SplitGroup-G4', null, h0, fh),
    ('SplitGroup-G5', null, h0, fh),
    ('SplitGroup-G6', null, h0, fh),
    ('SplitGroup-G7', null, h0, fh),
    ('SplitGroup-G8', null, h0, fh);
  insert into public.group_members (group_id, member_key, user_id, role, status, deleted, joined_at, hlc, field_hlcs) values
    ('SplitGroup-G1', '22222222-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001', 'admin',  'active',          false, t0,                       h0, fh),
    ('SplitGroup-G1', '22222222-0000-0000-0000-000000000002', '22222222-0000-0000-0000-000000000002', 'member', 'active',          false, t0 + interval '1 hour',   h0, fh),
    ('SplitGroup-G1', '22222222-0000-0000-0000-000000000003', '22222222-0000-0000-0000-000000000003', 'member', 'active',          false, t0 + interval '2 hour',   h0, fh),
    ('SplitGroup-G2', '22222222-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001', 'admin',  'active',          false, t0,                       h0, fh),
    ('SplitGroup-G3', '22222222-0000-0000-0000-000000000004', '22222222-0000-0000-0000-000000000004', 'admin',  'active',          false, t0,                       h0, fh),
    ('SplitGroup-G3', '22222222-0000-0000-0000-000000000005', '22222222-0000-0000-0000-000000000005', 'admin',  'pendingApproval', false, t0,                       h0, fh),
    ('SplitGroup-G3', '22222222-0000-0000-0000-000000000006', '22222222-0000-0000-0000-000000000006', 'admin',  'removed',         false, t0,                       h0, fh),
    ('SplitGroup-G3', '22222222-0000-0000-0000-000000000007', '22222222-0000-0000-0000-000000000007', 'admin',  'active',          true,  t0,                       h0, fh),
    ('SplitGroup-G3', 'legacy-hueco-admin-g3',                null,                                   'admin',  'active',          false, t0,                       h0, fh),
    ('SplitGroup-G3', 'legacy-hueco-g3',                      null,                                   'member', 'active',          false, t0,                       h0, fh),
    ('SplitGroup-G3', '22222222-0000-0000-0000-000000000008', '22222222-0000-0000-0000-000000000008', 'member', 'active',          false, t0 + interval '3 hour',   h0, fh),
    ('SplitGroup-G3', '22222222-0000-0000-0000-000000000009', '22222222-0000-0000-0000-000000000009', 'member', 'active',          false, t0 + interval '4 hour',   h0, fh),
    ('SplitGroup-G8', '22222222-0000-0000-0000-000000000004', '22222222-0000-0000-0000-000000000004', 'admin',  'active',          false, t0,                       h0, fh),
    ('SplitGroup-G8', '22222222-0000-0000-0000-000000000020', '22222222-0000-0000-0000-000000000020', 'member', 'active',          false, t0 + interval '1 hour',   h0, fh),
    ('SplitGroup-G4', '22222222-0000-0000-0000-000000000010', '22222222-0000-0000-0000-000000000010', 'admin',  'active',          false, t0 + interval '2 hour',   h0, fh),
    ('SplitGroup-G4', '22222222-0000-0000-0000-000000000011', '22222222-0000-0000-0000-000000000011', 'admin',  'active',          false, t0 + interval '3 hour',   h0, fh),
    ('SplitGroup-G4', '22222222-0000-0000-0000-000000000012', '22222222-0000-0000-0000-000000000012', 'member', 'active',          false, t0,                       h0, fh),
    ('SplitGroup-G5', '22222222-0000-0000-0000-000000000013', '22222222-0000-0000-0000-000000000013', 'admin',  'active',          false, t0 + interval '1 hour',   h0, fh),
    ('SplitGroup-G5', 'legacy-hueco-g5',                      null,                                   'member', 'active',          false, t0,                       h0, fh),
    ('SplitGroup-G6', '22222222-0000-0000-0000-000000000014', '22222222-0000-0000-0000-000000000014', 'admin',  'active',          false, t0 + interval '1 hour',   h0, fh),
    ('SplitGroup-G6', '22222222-0000-0000-0000-000000000015', '22222222-0000-0000-0000-000000000015', 'member', 'pendingApproval', false, t0,                       h0, fh),
    ('SplitGroup-G6', '22222222-0000-0000-0000-000000000016', '22222222-0000-0000-0000-000000000016', 'member', 'removed',         false, t0,                       h0, fh),
    ('SplitGroup-G6', 'legacy-hueco-g6',                      null,                                   'member', 'active',          false, t0,                       h0, fh),
    ('SplitGroup-G6', '22222222-0000-0000-0000-000000000017', '22222222-0000-0000-0000-000000000017', 'member', 'active',          true,  t0,                       h0, fh),
    ('SplitGroup-G7', '22222222-0000-0000-0000-000000000018', '22222222-0000-0000-0000-000000000018', 'admin',  'pendingApproval', false, t0,                       h0, fh),
    ('SplitGroup-G7', '22222222-0000-0000-0000-000000000019', '22222222-0000-0000-0000-000000000019', 'member', 'active',          false, t0 + interval '1 hour',   h0, fh),
    ('SplitGroup-G7', 'legacy-hueco-admin-g7',                null,                                   'admin',  'active',          false, t0,                       h0, fh);
end $f$;

-- El invariante, por grupo: o no queda nadie activo con cuenta, o hay ≥1 admin activo con cuenta.
create function public.bench_invariante(p_group text) returns boolean language sql as $f$
  select not exists (select 1 from public.group_members
                      where group_id = p_group and deleted = false and status = 'active' and user_id is not null)
      or exists (select 1 from public.group_members
                  where group_id = p_group and deleted = false and status = 'active' and role = 'admin'
                    and user_id is not null) $f$;
SQL

O=22222222-0000-0000-0000-000000000001; B=22222222-0000-0000-0000-000000000002; C=22222222-0000-0000-0000-000000000003
S=22222222-0000-0000-0000-000000000004; P=22222222-0000-0000-0000-000000000005; Rm=22222222-0000-0000-0000-000000000006
Dl=22222222-0000-0000-0000-000000000007; T=22222222-0000-0000-0000-000000000008; T2=22222222-0000-0000-0000-000000000009
E=22222222-0000-0000-0000-000000000010; F=22222222-0000-0000-0000-000000000011; Gm=22222222-0000-0000-0000-000000000012
N=22222222-0000-0000-0000-000000000013; I=22222222-0000-0000-0000-000000000014; P2=22222222-0000-0000-0000-000000000015
R2=22222222-0000-0000-0000-000000000016; D2=22222222-0000-0000-0000-000000000017; Q=22222222-0000-0000-0000-000000000018
Z=22222222-0000-0000-0000-000000000019; U=22222222-0000-0000-0000-000000000020; K=22222222-0000-0000-0000-000000000021
G1=SplitGroup-G1; G2=SplitGroup-G2; G3=SplitGroup-G3; G4=SplitGroup-G4; G5=SplitGroup-G5; G6=SplitGroup-G6
G7=SplitGroup-G7; G8=SplitGroup-G8
H0=2026-01-01T00:00:00.000Z-0000-0000000000000000

seed() { q -c "select public.bench_seed()" >/dev/null; }

# Ejecuta `$2` (una sentencia SQL) como PostgREST: `role authenticated`, el sub en los claims (vacío = sin sesión).
# Imprime su resultado, o `ERR:<sqlstate>:<mensaje>` si falla (molde g22_01).
sql_as() {
  local sub="$1" stmt="$2" out
  out=$("$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d "$DB" -X -q -tA -v ON_ERROR_STOP=1 \
        -v sub="$sub" 2>&1 <<SQL
\\set VERBOSITY verbose
begin;
set local role authenticated;
-- \\gset: guarda el resultado en una variable y no imprime nada (un \`select … where false\` NO sirve: molde g22_01).
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
# groups_forget_user como lo llama el gateway (con p_key inyectada).
forget() { sql_as "$1" "select public.groups_forget_user('k-bench')"; }

# Una fila de group_members como `rol|status|hlc|membership|profile|server_seq|user_id|deleted`.
fila() { q -tA -c "select coalesce(role,'-')||'|'||status||'|'||hlc||'|'||coalesce(field_hlcs->>'membership','-')||'|'||coalesce(field_hlcs->>'profile','-')||'|'||server_seq||'|'||coalesce(user_id::text,'-')||'|'||deleted from public.group_members where group_id='$1' and member_key='$2'"; }
rol() { q -tA -c "select role from public.group_members where group_id='$1' and member_key='$2'"; }
inv() { q -tA -c "select public.bench_invariante('$1')"; }
dueno() { q -tA -c "select coalesce(owner_user_id::text, '-') || '|' || deleted from public.split_groups where group_id='$1'"; }
md5fu() { q -tA -c "select md5(prosrc) from pg_proc where oid = 'public.groups_forget_user(text)'::regprocedure"; }

fallos=0
ok()  { echo "  ✓ $1"; }
mal() { echo "  ✗ $1"; fallos=$((fallos + 1)); }
espera() {  # $1 etiqueta · $2 esperado (prefijo) · $3 obtenido
  if [[ "$3" == "$2"* ]]; then ok "$1"; else mal "$1 — esperaba «$2…», salió «$3»"; fi
}
igual() {  # $1 etiqueta · $2 esperado (exacto) · $3 obtenido
  if [[ "$3" == "$2" ]]; then ok "$1"; else mal "$1 — esperaba «$2», salió «$3»"; fi
}
json_es() {  # $1 etiqueta · $2 jsonb esperado · $3 obtenido: compara como JSON
  if [[ "$3" != ERR:* ]] && [[ "$(jq -S -c . <<<"$3" 2>/dev/null)" == "$(jq -S -c . <<<"$2")" ]]; then ok "$1"
  else mal "$1 — esperaba $2, salió «$3»"; fi
}
resp() {  # la respuesta esperada de groups_forget_user con g25_01: transferred tombstoned anonymized promoted
  printf '{"groups_transferred":%s,"groups_tombstoned":%s,"memberships_anonymized":%s,"admins_promoted":%s}' "$1" "$2" "$3" "$4"
}

bateria() {
  fallos=0
  local res pre post

  echo "1 · create_group: el invariante nace bien"
  seed
  res="$(sql_as "$K" "select public.create_group('SplitGroup-K1', 'Casa', 'PEN', 'house', '#000000', 'K', 'equal', 'k-bench')")"
  espera "create_group responde"                              '{"group_id": "SplitGroup-K1"' "$res"
  igual  "el creador es admin/active con su user_id"          "admin|active|$K|false" \
         "$(q -tA -c "select role||'|'||status||'|'||user_id||'|'||deleted from public.group_members where group_id='SplitGroup-K1' and member_key='$K'")"
  igual  "…y es el dueño del grupo"                           "$K|false" "$(dueno SplitGroup-K1)"
  igual  "el invariante se cumple al nacer"                   t "$(inv SplitGroup-K1)"

  echo "2 · el dueño que se borra con heredero (comportamiento previo)"
  seed
  res="$(forget "$O")"
  json_es "respuesta: 1 transferido, 1 tombstoneado, 2 anonimizadas, 0 promovidos" "$(resp 1 1 2 0)" "$res"
  igual  "G1 pasa a B (el miembro activo más antiguo)"        "$B|false" "$(dueno "$G1")"
  igual  "B sale admin"                                       admin "$(rol "$G1" "$B")"
  igual  "C sigue miembro (solo un heredero)"                 member "$(rol "$G1" "$C")"
  igual  "G2, sin heredero, se tombstonea"                    "$O|true" "$(dueno "$G2")"
  espera "la fila de O en G1 queda anonimizada"               "admin|removed|" "$(fila "$G1" "$O")"
  [[ "$(fila "$G1" "$O")" == *"|-|false" ]] && ok "…sin user_id" || mal "…sin user_id — $(fila "$G1" "$O")"
  igual  "el invariante se cumple en G1"                      t "$(inv "$G1")"

  echo "3 · grupo SIN creador: quien se borra era el único admin con cuenta"
  seed
  pre="$(fila "$G3" "$T")"
  res="$(forget "$S")"
  json_es "respuesta: 0 transferidos, 0 tombstoneados, 2 anonimizadas, 2 promovidos" "$(resp 0 0 2 2)" "$res"
  igual  "sin creador: T (miembro activo más antiguo con cuenta) queda admin" admin "$(rol "$G3" "$T")"
  igual  "T2, más nuevo, sigue miembro"                       member "$(rol "$G3" "$T2")"
  igual  "el invariante se cumple en G3 tras el borrado"      t "$(inv "$G3")"
  igual  "en G8, U queda admin"                               admin "$(rol "$G8" "$U")"
  igual  "el invariante se cumple en G8"                      t "$(inv "$G8")"
  igual  "G3 sigue sin creador (el paso no toca owner_user_id)" "-|false" "$(dueno "$G3")"
  espera "S queda anonimizada en G3"                          "admin|removed|" "$(fila "$G3" "$S")"
  post="$(fila "$G3" "$T")"
  local _r _st hlc mem prof seq0 seq1
  seq0="$(cut -d'|' -f6 <<<"$pre")"
  IFS='|' read -r _r _st hlc mem prof seq1 _ _ <<<"$post"
  [[ "$hlc" =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9:.]{12}Z-0000-0000000000000000$ && "$hlc" != "$H0" ]] \
    && ok "T: hlc nuevo con el formato del servidor" || mal "T: hlc $hlc"
  [[ "$mem" == "$hlc" ]] && ok "T: field_hlcs.membership = hlc" || mal "T: membership $mem ≠ hlc $hlc"
  [[ "$prof" == "$H0" ]] && ok "T: field_hlcs.profile intacto" || mal "T: profile $prof"
  (( seq1 > seq0 )) && ok "T: server_seq sube ($seq0 → $seq1)" || mal "T: server_seq $seq0 → $seq1"
  [[ "$hlc" == "$(cut -d'|' -f3 <<<"$(fila "$G3" "$S")")" ]] && ok "T y la anonimización comparten el hlc de la llamada" || mal "hlc distinto del de la anonimización"

  echo "6 · quien nunca es heredero (pendiente, expulsado, hueco, fila borrada)"
  igual  "P (pendiente, admin, más antiguo) no es heredero: intacto"  "admin|pendingApproval|$H0|$H0|$H0" "$(cut -d'|' -f1-5 <<<"$(fila "$G3" "$P")")"
  igual  "Rm (expulsado, admin, más antiguo) no es heredero: intacto" "admin|removed|$H0|$H0|$H0" "$(cut -d'|' -f1-5 <<<"$(fila "$G3" "$Rm")")"
  igual  "Dl (fila borrada, admin, más antigua) no es heredera: intacta" "admin|active|$H0|$H0|$H0" "$(cut -d'|' -f1-5 <<<"$(fila "$G3" "$Dl")")"
  igual  "el hueco miembro (sin user_id) no es heredero: intacto"     "member|active|$H0" "$(cut -d'|' -f1-3 <<<"$(fila "$G3" legacy-hueco-g3)")"
  seed
  res="$(forget "$I")"
  json_es "si solo quedan inelegibles: 0 promovidos, sin fallar" "$(resp 0 0 1 0)" "$res"
  igual  "P2 (pendiente) sigue igual"                         "member|pendingApproval|$H0" "$(cut -d'|' -f1-3 <<<"$(fila "$G6" "$P2")")"
  igual  "R2 (expulsado) sigue igual"                         "member|removed|$H0" "$(cut -d'|' -f1-3 <<<"$(fila "$G6" "$R2")")"
  igual  "el hueco sigue igual"                               "member|active|$H0" "$(cut -d'|' -f1-3 <<<"$(fila "$G6" legacy-hueco-g6)")"
  igual  "D2 (fila borrada) sigue igual"                      "member|active|$H0" "$(cut -d'|' -f1-3 <<<"$(fila "$G6" "$D2")")"

  echo "4 · control: queda OTRO admin activo con cuenta"
  seed
  pre="$(fila "$G4" "$Gm")|$(fila "$G4" "$F")"
  res="$(forget "$E")"
  json_es "control: con otro admin con cuenta, admins_promoted = 0" "$(resp 0 0 1 0)" "$res"
  igual  "F sigue admin y Gm miembro, sin escribir"           "$pre" "$(fila "$G4" "$Gm")|$(fila "$G4" "$F")"
  igual  "el invariante se cumple en G4"                      t "$(inv "$G4")"

  echo "5 · sin heredero: era el único con cuenta"
  seed
  res="$(forget "$N")"
  json_es "nadie promovido y no falla"                        "$(resp 0 0 1 0)" "$res"
  igual  "G5 sigue vivo (no lo poseía: no se tombstonea)"     "-|false" "$(dueno "$G5")"
  igual  "el hueco sigue miembro"                             member "$(rol "$G5" legacy-hueco-g5)"

  echo "7 · control: quien no es admin ACTIVO no dispara el paso"
  seed
  res="$(forget "$Q")"
  json_es "un admin pendiente que se borra: 0 promovidos"     "$(resp 0 0 1 0)" "$res"
  igual  "Z sigue miembro"                                    "member|active|$H0" "$(cut -d'|' -f1-3 <<<"$(fila "$G7" "$Z")")"

  echo "8 · sin sesión"
  seed
  espera "sin sesión → not_authorized"                        "ERR:P0001:yala_not_authorized" "$(forget "")"
  igual  "no escribió"                                        "member|$S|-|false" "$(rol "$G3" "$T")|$(q -tA -c "select user_id from public.group_members where group_id='$G3' and member_key='$S'")|$(dueno "$G3")"

  echo "9 · la forma de la respuesta"
  seed
  res="$(forget "$S")"
  igual  "conserva las tres claves de antes y añade admins_promoted" \
         '["admins_promoted","groups_tombstoned","groups_transferred","memberships_anonymized"]' \
         "$(jq -c 'keys' <<<"$res" 2>/dev/null || echo "no-json:$res")"

  echo "10 · grants"
  local anon_out
  anon_out=$("$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d "$DB" -X -q -tA -v ON_ERROR_STOP=1 2>&1 <<SQL || true
\set VERBOSITY verbose
begin; set local role anon; select public.groups_forget_user('k-bench'); commit;
SQL
  )
  grep -q '42501' <<<"$anon_out" && ok "anon → permiso denegado (42501)" || mal "anon pudo llamarla: $anon_out"
  igual "authenticated puede ejecutarla" t \
    "$(q -tA -c "select has_function_privilege('authenticated', 'public.groups_forget_user(text)', 'EXECUTE')")"
  igual "SECURITY DEFINER con search_path=public, extensions" "true|search_path=public, extensions" \
    "$(q -tA -c "select prosecdef::text || '|' || array_to_string(proconfig, ',') from pg_proc where oid = 'public.groups_forget_user(text)'::regprocedure")"

  echo "11 · re-aplicar"
  local m0
  m0="$(md5fu)"
  if q -1 -f "$1" >"$WORK/re.out" 2>&1 && grep -q 'g25_01 OK' "$WORK/re.out"; then ok "re-aplicar es no-op y vuelve a comprobar"
  else mal "re-aplicar falló"; sed 's/^/    /' "$WORK/re.out"; fi
  igual "el cuerpo no cambió al re-aplicar" "$m0" "$(md5fu)"
  seed
  forget "$S" >/dev/null
  igual "sigue funcionando tras re-aplicar" admin "$(rol "$G3" "$T")"
}

# md5(prosrc) de groups_forget_user: el del DDL (de partida) y el de la migración. Si cambia el cuerpo de la
# migración, cambia el DESPUES y hay que fijarlo también en los dos .sql.
ANTES=4cd0a3cbc080002c476523a2d5f47766
DESPUES=fb2263667e3565f84cbad009c7df1d17
# Cambia un literal del cuerpo vivo (para fingir un cuerpo que no es el del molde, y deshacerlo).
retocar() {
  q -v de="$1" -v a="$2" >/dev/null <<'SQL'
select set_config('g25.de', :'de', false) as _de, set_config('g25.a', :'a', false) as _a \gset
do $d$
declare v text;
begin
  select prosrc into v from pg_proc where oid = 'public.groups_forget_user(text)'::regprocedure;
  execute format('create or replace function public.groups_forget_user(p_key text) returns jsonb language plpgsql security definer set search_path = public, extensions as %L',
                 replace(v, current_setting('g25.de'), current_setting('g25.a')));
end $d$;
SQL
}

aplicar() { q -1 -f "$1" >"$WORK/apply.out" 2>&1 || { echo "  ✗ la migración no aplicó:"; sed 's/^/    /' "$WORK/apply.out"; exit 1; }; }

echo "== 0 · la guarda del cuerpo"
g0=0
[[ "$(md5fu)" == "$ANTES" ]] && echo "  ✓ el DDL cargado trae el md5 de partida que la guarda espera ($ANTES)" || { echo "  ✗ md5 de partida: $(md5fu)"; g0=$((g0 + 1)); }
retocar "'__deleted_user__'" "'__deleted_user_x__'"
DIVERGIDO="$(md5fu)"
[[ "$DIVERGIDO" != "$ANTES" ]] || { echo "  ✗ el retoque no cambió el cuerpo"; g0=$((g0 + 1)); }
if q -1 -f "$MIG" >"$WORK/g0.out" 2>&1; then echo "  ✗ la migración se aplicó sobre un cuerpo divergido"; g0=$((g0 + 1))
elif grep -q 'g25_01: groups_forget_user no es' "$WORK/g0.out"; then echo "  ✓ cuerpo divergido → aborta en la guarda"
else echo "  ✗ abortó, pero no en la guarda:"; sed 's/^/    /' "$WORK/g0.out"; g0=$((g0 + 1)); fi
[[ "$(md5fu)" == "$DIVERGIDO" ]] && echo "  ✓ no tocó nada" || { echo "  ✗ tocó algo"; g0=$((g0 + 1)); }
retocar "'__deleted_user_x__'" "'__deleted_user__'"
[[ "$(md5fu)" == "$ANTES" ]] && echo "  ✓ devuelto al cuerpo del DDL" || { echo "  ✗ no volvió: $(md5fu)"; g0=$((g0 + 1)); }

echo "== g25_01 · la migración tal cual"
aplicar "$MIG"
grep -q 'g25_01 OK' "$WORK/apply.out" && echo "  ✓ aplicó con su comprobación de cuerpo y grants" || { echo "  ✗ sin el aviso g25_01 OK"; exit 1; }
[[ "$(md5fu)" == "$DESPUES" ]] && echo "  ✓ groups_forget_user con el md5 fijado ($DESPUES)" || { echo "  ✗ md5 tras aplicar: $(md5fu)"; g0=$((g0 + 1)); }
bateria "$MIG"
total_real=$((fallos + g0))

echo "12 · marcha atrás"
rb_fallos=0
if q -1 -f "$RB" >"$WORK/rb.out" 2>&1 && grep -q 'g25_01_rollback OK' "$WORK/rb.out"; then echo "  ✓ rollback aplicado"
else echo "  ✗ el rollback abortó"; sed 's/^/    /' "$WORK/rb.out"; rb_fallos=$((rb_fallos + 1)); fi
[[ "$(md5fu)" == "$ANTES" ]] && echo "  ✓ el cuerpo vuelve al md5 de partida ($ANTES)" || { echo "  ✗ tras el rollback: $(md5fu)"; rb_fallos=$((rb_fallos + 1)); }
seed
r="$(forget "$S")"
[[ "$(rol "$G3" "$T")" == member ]] && echo "  ✓ y con él vuelve el hueco: T sigue member (el comportamiento del DDL)" || { echo "  ✗ tras el rollback T quedó $(rol "$G3" "$T")"; rb_fallos=$((rb_fallos + 1)); }
[[ "$(jq -c 'keys' <<<"$r" 2>/dev/null)" == '["groups_tombstoned","groups_transferred","memberships_anonymized"]' ]] \
  && echo "  ✓ la respuesta vuelve a sus tres claves" || { echo "  ✗ respuesta tras el rollback: $r"; rb_fallos=$((rb_fallos + 1)); }
if q -1 -f "$RB" >/dev/null 2>&1; then echo "  ✓ un segundo rollback no falla"; else echo "  ✗ el segundo rollback falló"; rb_fallos=$((rb_fallos + 1)); fi
retocar "'__deleted_user__'" "'__deleted_user_x__'"
if q -1 -f "$RB" >"$WORK/rb2.out" 2>&1; then echo "  ✗ el rollback se aplicó sobre un cuerpo divergido"; rb_fallos=$((rb_fallos + 1))
elif grep -q 'g25_01_rollback: groups_forget_user no es' "$WORK/rb2.out"; then echo "  ✓ rollback sobre un cuerpo divergido → aborta en su guarda"
else echo "  ✗ el rollback abortó, pero no en la guarda"; sed 's/^/    /' "$WORK/rb2.out"; rb_fallos=$((rb_fallos + 1)); fi
retocar "'__deleted_user_x__'" "'__deleted_user__'"

# --- mutantes: cada copia quita UNA pieza; la batería tiene que caer, y por SU caso ------------------------------
# Cada mutante se aplica sobre el cuerpo del DDL (restaurado con el rollback sin su guarda) y con la comprobación final
# de md5 apagada: un mutante cambia el md5 a propósito. Su «re-aplicar» cae en la guarda (cuerpo ajeno): es un rojo
# más, no el que se busca.
mutante() {  # $1 nombre · $2 texto a quitar (literal, una sola vez; «@paso-nuevo» = el bloque entero) · $3 sustituto · $4 el caso que tiene que caer
  local f="$WORK/mut-${1// /_}.sql"
  python3 "$WORK/mutar.py" "$MIG" "$f" "$2" "$3" || return 1
  python3 "$WORK/sin_guarda.py" "$RB" "$WORK/restaurar.sql" || return 1
  q -1 -f "$WORK/restaurar.sql" >/dev/null 2>&1 || { echo "  ✗ no pude restaurar el cuerpo antes del mutante «$1»"; return 1; }
  aplicar "$f"
  bateria "$f" >"$WORK/mut.out" 2>&1 || true
  local caidos=$fallos
  if (( caidos > 0 )) && grep -qF "✗ $4" "$WORK/mut.out"; then
    echo "  ✓ mutante «$1» muerto ($caidos caso(s) en rojo, entre ellos «$4»)"
    return 0
  fi
  echo "  ✗ mutante «$1» VIVO, o muerto por otro caso: no cayó «$4» ($caidos rojo(s))"; return 1
}

cat >"$WORK/mutar.py" <<'PY'
import sys
src, dst, old, new = sys.argv[1:5]
text = open(src, encoding="utf-8").read()
if old == "@paso-nuevo":
    a = text.index("  -- g25_01 ▶ paso nuevo")
    fin = "  -- g25_01 ◀ fin del paso nuevo\n"
    b = text.index(fin) + len(fin)
    if text.count("  -- g25_01 ▶ paso nuevo") != 1 or text.count(fin) != 1:
        sys.exit("mutante: los marcadores del paso nuevo no aparecen una sola vez")
    text = text[:a] + new + text[b:]
else:
    n = text.count(old)
    if n != 1:
        sys.exit(f"mutante: el texto aparece {n} veces, se esperaba 1: {old!r}")
    text = text.replace(old, new)
check = "  if (select md5(prosrc) from pg_proc where oid = 'public.groups_forget_user(text)'::regprocedure) <> "
if text.count(check) != 1:
    sys.exit("mutante: no encuentro la comprobación de md5")
text = text.replace(check, "  if false and (select md5(prosrc) from pg_proc where oid = 'public.groups_forget_user(text)'::regprocedure) <> ")
open(dst, "w", encoding="utf-8").write(text)
PY
cat >"$WORK/sin_guarda.py" <<'PY'
import sys
src, dst = sys.argv[1:3]
text = open(src, encoding="utf-8").read()
old = "  if v_fu is null or v_fu not in ("
if text.count(old) != 1:
    sys.exit(f"sin_guarda: no encuentro {old!r}")
text = text.replace(old, "  if false and v_fu not in (")
open(dst, "w", encoding="utf-8").write(text)
PY

echo "== mutantes"
mut_vivos=0
mutante "sin el paso nuevo" "@paso-nuevo" "" \
  "sin creador: T (miembro activo más antiguo con cuenta) queda admin" || mut_vivos=$((mut_vivos + 1))
mutante "heredero sin status = active" \
  "m.group_id = v_grp.group_id and m.deleted = false and m.status = 'active'" "m.group_id = v_grp.group_id and m.deleted = false" \
  "P (pendiente, admin, más antiguo) no es heredero: intacto" || mut_vivos=$((mut_vivos + 1))
mutante "heredero sin deleted = false" \
  "m.group_id = v_grp.group_id and m.deleted = false and m.status = 'active'" "m.group_id = v_grp.group_id and m.status = 'active'" \
  "Dl (fila borrada, admin, más antigua) no es heredera: intacta" || mut_vivos=$((mut_vivos + 1))
mutante "sin mirar si queda otro admin" \
  "        and not exists (select 1 from group_members o
                         where o.group_id = g.group_id and o.deleted = false and o.status = 'active'
                           and o.role = 'admin' and o.user_id is not null and o.user_id <> v_uid)
" "" \
  "control: con otro admin con cuenta, admins_promoted = 0" || mut_vivos=$((mut_vivos + 1))
mutante "quien llama sin status = active" \
  "me.status = 'active' and me.role = 'admin'" "me.role = 'admin'" \
  "un admin pendiente que se borra: 0 promovidos" || mut_vivos=$((mut_vivos + 1))

echo
todo=$((total_real + rb_fallos + mut_vivos))
if [[ $todo -eq 0 ]]; then echo "g25_01 banco local: todo en verde"
else echo "g25_01 banco local: $total_real fallo(s) en la batería, $rb_fallos en la marcha atrás, $mut_vivos mutante(s) vivo(s)"; exit 1; fi
