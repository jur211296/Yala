#!/usr/bin/env bash
# =====================================================================================================
# g17_01 · banco LOCAL de la migración, sin tocar staging ni producción
#
# Levanta un Postgres desechable y corre la MISMA batería contra dos cuerpos de `migration_progress`, cada uno en
# su base:
#
#   real     el cuerpo VIVO de staging y producción (`fixtures/migration_progress.g15_02.functiondef.sql`,
#            `pg_get_functiondef` exportado el 2026-10-09; md5(prosrc) 14fc5e2c…, el de la guarda). Aquí la
#            migración y el rollback corren SIN TOCAR: su md5 ya es el que esperan. Sus tres escrituras están
#            ALINEADAS (`reverted_at          = null`, 10 y 11 espacios): esa grafía hizo abortar la primera
#            versión de la guarda en staging, que buscaba el literal con un espacio.
#   replica  una réplica escrita a mano desde el contrato del README, con un solo espacio en cada escritura. Se
#            queda como variante de espaciado: la guarda tiene que servir con las dos grafías.
#
# Lo mínimo que el cuerpo real lee se crea aquí: `auth.users`, `public.profiles`, el rol `authenticated` y
# `auth.uid()` con la definición de Supabase (lee el `sub` de `request.jwt.claims`). Sin RLS ni el trigger
# `profiles_kind_guard`: el §3 lee la fila con el rol de PostgREST, pero aquí sin políticas.
#
# Por cada cuerpo:
#   1. el §3 FALLA con el cuerpo viejo, y nombra los caminos del ticket (dirección 1: puede fallar);
#   2. la migración entera pasa (dirección 2), con el §1-bis sobre tres cuentas;
#   3. re-aplicar es no-op y el §3 vuelve a correr;
#   4. el rollback devuelve exactamente el md5 de partida;
#   5. un cuerpo divergido aborta en la guarda sin tocar nada;
#   6. una cuarta escritura de reverted_at a null aborta (el número está fijado a 3);
#   7-8. una cuarta escritura con una grafía que la sustitución no tocaría (MAYÚSCULAS, `nullif`) aborta.
# Y en el real, además: el md5 que deja la migración es el fijado abajo (`MD5_FINAL_REAL`), el que Frank compara
# al aplicar en staging y en producción.
#
# Uso:  bash qa/cloud/g17_01-local-test.sh
# =====================================================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/g17_01_reverse_claim_keeps_reverted_at.sql"
RB="$HERE/g17_01_rollback.sql"
FIXTURE_REAL="$HERE/fixtures/migration_progress.g15_02.functiondef.sql"
PGBIN="${PGBIN:-/opt/homebrew/opt/postgresql@17/bin}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/g17_01.XXXXXX")"
PORT="${PORT:-55417}"
VIRGEN_PROD='14fc5e2c54766dd7c5706966c7381f51'
# md5(prosrc) del cuerpo real tras la migración. Medido en este banco el 2026-10-09; si cambia la sustitución,
# cambia este número y el del RUNBOOK.
MD5_FINAL_REAL='776dac35d585393fabeabedf8eafee82'
trap '"$PGBIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

"$PGBIN/initdb" -D "$WORK/data" -U postgres -A trust >/dev/null
# Por TCP y sin socket Unix: la ruta de un directorio temporal largo pasa de los 103 bytes que admite.
"$PGBIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -c listen_addresses=127.0.0.1 -c unix_socket_directories=''" -l "$WORK/log" -w start >/dev/null

DB=postgres
q() { "$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d "$DB" -v ON_ERROR_STOP=1 -q -X "$@"; }

q -c "create role authenticated nologin" >/dev/null

preparar_base() {
  "$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -q -X -c "create database $DB"
  q <<'SQL'
create schema auth;
create table auth.users (id uuid primary key, instance_id uuid, aud text, role text, email text,
                         created_at timestamptz, updated_at timestamptz);
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  provider text, kind text, personal_claimed_at timestamptz, migrated_at timestamptz,
  reverted_at timestamptz, reverse_frozen_at timestamptz,
  migration_in_progress boolean not null default false,
  reverse_in_progress boolean not null default false,
  leader_device_id text, migration_updated_at timestamptz);
-- La de Supabase: el `sub` del JWT que PostgREST deja en `request.jwt.claims`.
create function auth.uid() returns uuid language sql stable as $f$
  select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'))::uuid $f$;
grant usage on schema public, auth to authenticated;
grant select, update on public.profiles to authenticated;
SQL
}

cargar_real() {
  # `pg_get_functiondef` no trae el `;` final.
  { cat "$FIXTURE_REAL"; echo ';'; } | q
  q -c "grant execute on function public.migration_progress(text, text) to authenticated"
}

# La réplica. Las tres escrituras `reverted_at = null` son el claim fresco y los dos takeovers del README.
cargar_replica() {
  q <<'SQL'
create or replace function public.migration_progress(p_device_id text, p_action text) returns jsonb
language plpgsql set search_path = public as $body$
declare
  v_uid       uuid;
  v_mip       boolean;
  v_leader    text;
  v_rip       boolean;
  v_kind      text;
  v_reverted  timestamptz;
  v_updated   timestamptz;
  v_expired   boolean;
begin
  v_uid := (nullif(current_setting('request.jwt.claims', true), '')::json->>'sub')::uuid;
  if v_uid is null then
    raise exception 'sin sub' using errcode = '28000';
  end if;
  select migration_in_progress, leader_device_id, reverse_in_progress, kind, reverted_at, migration_updated_at
    into v_mip, v_leader, v_rip, v_kind, v_reverted, v_updated
    from profiles where id = v_uid;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'no_profile');
  end if;
  v_expired := v_updated is not null and v_updated < now() - interval '60 minutes';

  if p_action = 'reverse_claim' then
    if v_kind is distinct from 'complete' and v_reverted is null then
      return jsonb_build_object('ok', false, 'reason', 'not_complete');
    end if;
    if v_mip then
      if not v_expired then
        return jsonb_build_object('ok', false, 'reason', 'migration_in_progress');
      end if;
      update profiles set migration_in_progress = false, reverse_in_progress = true, leader_device_id = p_device_id,
             migration_updated_at = now(), reverse_frozen_at = null, reverted_at = null
       where id = v_uid and migration_updated_at = v_updated;
      if not found then return jsonb_build_object('ok', false, 'reason', 'other_leader'); end if;
      return jsonb_build_object('ok', true);
    end if;
    if v_rip then
      if v_leader = p_device_id then
        update profiles set migration_updated_at = now()
         where id = v_uid and leader_device_id = p_device_id and reverse_in_progress = true;
        if not found then return jsonb_build_object('ok', false, 'reason', 'other_leader'); end if;
        return jsonb_build_object('ok', true);
      end if;
      if not v_expired then
        return jsonb_build_object('ok', false, 'reason', 'other_leader');
      end if;
      update profiles set leader_device_id = p_device_id, migration_updated_at = now(),
             reverse_frozen_at = null, reverted_at = null
       where id = v_uid and migration_updated_at = v_updated;
      if not found then return jsonb_build_object('ok', false, 'reason', 'other_leader'); end if;
      return jsonb_build_object('ok', true);
    end if;
    update profiles set reverse_in_progress = true, leader_device_id = p_device_id, migration_updated_at = now(),
           reverse_frozen_at = null, reverted_at = null
     where id = v_uid and reverse_in_progress = false and migration_in_progress = false;
    if not found then return jsonb_build_object('ok', false, 'reason', 'other_leader'); end if;
    return jsonb_build_object('ok', true);

  elsif p_action = 'reverse_freeze' then
    if not v_rip or v_leader is distinct from p_device_id then
      return jsonb_build_object('ok', false, 'reason', 'other_leader');
    end if;
    update profiles set reverse_frozen_at = coalesce(reverse_frozen_at, now()), migration_updated_at = now()
     where id = v_uid;
    return jsonb_build_object('ok', true);

  elsif p_action = 'reverse_complete' then
    if not v_rip then
      if v_reverted is not null then return jsonb_build_object('ok', true); end if;
      return jsonb_build_object('ok', false, 'reason', 'not_in_progress');
    end if;
    if v_leader is distinct from p_device_id then
      return jsonb_build_object('ok', false, 'reason', 'other_leader');
    end if;
    update profiles set reverse_in_progress = false, reverted_at = coalesce(reverted_at, now()), kind = 'groups_only',
           migration_updated_at = now()
     where id = v_uid;
    return jsonb_build_object('ok', true);

  elsif p_action = 'reverse_abort' then
    if not v_rip then return jsonb_build_object('ok', true); end if;
    if v_leader is distinct from p_device_id and not v_expired then
      return jsonb_build_object('ok', false, 'reason', 'other_leader');
    end if;
    update profiles set reverse_in_progress = false, reverse_frozen_at = null, migration_updated_at = now()
     where id = v_uid;
    return jsonb_build_object('ok', true);
  end if;

  return jsonb_build_object('ok', false, 'reason', 'bad_action');
end $body$;
grant execute on function public.migration_progress(text, text) to authenticated;
SQL
}

md5_vivo() {
  q -t -A -c "select md5(prosrc) from pg_proc where proname = 'migration_progress' and pronargs = 2"
}
filas() { q -t -A -c 'select count(*) from public.profiles'; }

fallos=0
ok()   { printf '  ✓ %s\n' "$1"; }
mal()  { printf '  ✗ %s\n' "$1"; fallos=$((fallos + 1)); }

bateria() {
  local cuerpo="$1"
  DB="g17_$cuerpo"
  local W="$WORK/$cuerpo"
  mkdir -p "$W"
  preparar_base
  "cargar_$cuerpo"

  local VIRGEN; VIRGEN="$(md5_vivo)"
  echo
  echo "══ cuerpo $cuerpo (md5 $VIRGEN) ══"
  if [[ "$cuerpo" == real ]]; then
    [[ "$VIRGEN" == "$VIRGEN_PROD" ]] && ok "el fixture da el md5 de producción" || mal "el fixture no da el md5 de producción"
  fi
  local n_esc
  n_esc=$(q -t -A -c "select count(*) from regexp_matches((select prosrc from pg_proc where proname = 'migration_progress'), 'reverted_at\s*=\s*null', 'gi')")
  [[ "$n_esc" == 3 ]] && ok "3 escrituras de reverted_at a null en el cuerpo de partida" || mal "el cuerpo de partida tiene $n_esc escrituras"
  # La guarda espera el md5 de PRODUCCIÓN; con la réplica se sustituye en una copia. Con el real, la copia es
  # idéntica al fichero.
  sed "s/$VIRGEN_PROD/$VIRGEN/g" "$MIG" > "$W/mig.sql"
  sed "s/$VIRGEN_PROD/$VIRGEN/g" "$RB"  > "$W/rb.sql"
  if [[ "$cuerpo" == real ]]; then
    cmp -s "$W/mig.sql" "$MIG" && cmp -s "$W/rb.sql" "$RB" && ok "migración y rollback corren sin tocar" || mal "la copia difiere del fichero"
  fi
  # Solo el §3, para correrlo contra el cuerpo viejo.
  awk '/^-- ── 3 · Verificación de COMPORTAMIENTO/{p=1} p' "$MIG" > "$W/conducta.sql"

  echo "1 · el §3 contra el cuerpo VIEJO tiene que fallar"
  if q -1 -f "$W/conducta.sql" >"$W/out1" 2>&1; then
    mal "el §3 pasó con el cuerpo viejo: no puede fallar, no prueba nada"
  else
    local n camino control
    n=$(grep -c '^  · ' "$W/out1" || true)
    for camino in '(a) revertida: claim fresco' '(b) claim con éxito' '(c) tres dispositivos' 'takeover de una vuelta ajena'; do
      if grep -qF "$camino" "$W/out1"; then ok "falla: $camino"; else mal "no falla: $camino"; fi
    done
    for control in 'golden 17' 'born-cloud complete' 'nunca revirtió' 'golden 12'; do
      if grep -qF "$control" "$W/out1"; then mal "un control falla con el cuerpo viejo: $control"; else ok "control verde: $control"; fi
    done
    echo "    ($n escenarios en rojo)"
  fi
  [[ "$(md5_vivo)" == "$VIRGEN" ]] && ok "el intento fallido no tocó la función" || mal "el intento fallido tocó la función"
  [[ "$(filas)" == "0" ]] && ok "cero filas sintéticas" || mal "quedaron filas"

  echo "2 · la migración entera (con tres cuentas reales para el §1-bis)"
  # atascada = volvió a iCloud y un claim le borró reverted_at, con su vuelta reservada (camino 2);
  # pura = solo grupos, nunca tuvo lo personal; completa = complete sin marcas. Solo la primera se repara.
  q <<'SQL'
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000a2'), ('00000000-0000-0000-0000-0000000000a3');
insert into public.profiles (id, kind, personal_claimed_at, reverted_at, reverse_in_progress, leader_device_id, migration_updated_at)
values ('00000000-0000-0000-0000-0000000000a1', 'groups_only', now() - interval '3 days', null, true, 'dev-B', now() - interval '2 hours'),
       ('00000000-0000-0000-0000-0000000000a2', 'groups_only', null, null, false, null, now()),
       ('00000000-0000-0000-0000-0000000000a3', 'complete', now(), null, false, null, now());
SQL
  reparada() { q -t -A -c "select reverted_at is not null from public.profiles where id = '00000000-0000-0000-0000-0000000000$1'"; }
  if q -1 -f "$W/mig.sql" >"$W/out2" 2>&1; then
    grep -o 'g17_01: [0-9]* cuenta[^"]*' "$W/out2" | head -1 | sed 's/^/    /'
    [[ "$(reparada a1)" == "t" ]] && ok "§1-bis: la cuenta atascada recupera reverted_at" || mal "§1-bis: la atascada sigue sin reverted_at"
    [[ "$(reparada a2)" == "f" ]] && ok "§1-bis: la de solo grupos pura no se toca" || mal "§1-bis: tocó la de solo grupos pura"
    [[ "$(reparada a3)" == "f" ]] && ok "§1-bis: la complete no se toca" || mal "§1-bis: tocó la complete"
    # Y el dispositivo que quedó con la vuelta reservada vuelve a entrar: re-claim idempotente.
    local r
    r=$(q -t -A -c "select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-0000-0000-0000000000a1\"}', false); select public.migration_progress('dev-B', 'reverse_claim')" | tail -1)
    [[ "$r" == '{"ok": true}' ]] && ok "§1-bis: el líder atascado vuelve a entrar ($r)" || mal "§1-bis: el líder atascado recibe $r"
    q -c "delete from auth.users where id::text like '00000000-0000-0000-0000-0000000000a%'"

    grep -o 'g17_01: 3 sustitución[^"]*' "$W/out2" | head -1 | sed 's/^/    /'
    grep -q 'g17_01: 3 sustitución' "$W/out2" && ok "tres sustituciones" || mal "no salen tres sustituciones"
    grep -o 'g17_01 OK[^"]*' "$W/out2" | head -1 | sed 's/^/    /'
    grep -q 'g17_01 OK · 11/11' "$W/out2" && ok "§3 en verde, 11/11" || mal "el §3 no dio 11/11"
  else
    mal "la migración abortó"; sed 's/^/    /' "$W/out2"
  fi
  local APLICADA; APLICADA="$(md5_vivo)"
  [[ "$APLICADA" != "$VIRGEN" ]] && ok "el cuerpo cambió (md5 $APLICADA)" || mal "el cuerpo no cambió"
  grep -q "md5 nuevo de migration_progress: $APLICADA" "$W/out2" && ok "la migración anuncia ese md5" || mal "la migración no anuncia el md5 que deja"
  local n_new
  n_new=$(q -t -A -c "select count(*) from regexp_matches((select prosrc from pg_proc where proname = 'migration_progress'), 'reverted_at(\s*)=(\s*)case when kind = ''complete'' then null else reverted_at end', 'g')")
  [[ "$n_new" == 3 ]] && ok "tres escrituras condicionales" || mal "hay $n_new escrituras condicionales"
  if [[ "$cuerpo" == real ]]; then
    [[ "$APLICADA" == "$MD5_FINAL_REAL" ]] && ok "md5 final = el fijado ($MD5_FINAL_REAL)" || mal "md5 final $APLICADA, fijado $MD5_FINAL_REAL"
    # El espaciado de cada escritura se conserva: la alineación del cuerpo vivo sigue en su sitio.
    local alin
    alin=$(q -t -A -c "select count(*) from regexp_matches((select prosrc from pg_proc where proname = 'migration_progress'), 'reverted_at {10,11}= case when', 'g')")
    [[ "$alin" == 3 ]] && ok "las tres conservan su alineación (10-11 espacios)" || mal "solo $alin conservan la alineación"
    echo "    md5(pg_get_functiondef) final: $(q -t -A -c "select md5(pg_get_functiondef(oid)) from pg_proc where proname = 'migration_progress'")"
  fi
  [[ "$(filas)" == "0" ]] && ok "cero filas sintéticas" || mal "quedaron filas"

  echo "3 · re-aplicar es no-op y el §3 corre igual"
  if q -1 -f "$W/mig.sql" >"$W/out3" 2>&1 && grep -q 'ya aplicada' "$W/out3" && grep -q 'g17_01 OK' "$W/out3"; then
    ok "no-op con el §3 en verde"
  else
    mal "la re-aplicación no fue no-op"; sed 's/^/    /' "$W/out3"
  fi
  [[ "$(md5_vivo)" == "$APLICADA" ]] && ok "md5 intacto" || mal "la re-aplicación cambió el cuerpo"

  echo "4 · rollback"
  if q -1 -f "$W/rb.sql" >"$W/out4" 2>&1; then ok "rollback aplicado"; else mal "el rollback abortó"; sed 's/^/    /' "$W/out4"; fi
  [[ "$(md5_vivo)" == "$VIRGEN" ]] && ok "vuelve al md5 de partida ($VIRGEN)" || mal "el rollback no devolvió el md5 de partida"
  if q -1 -f "$W/conducta.sql" >/dev/null 2>&1; then mal "tras el rollback el §3 pasa"; else ok "tras el rollback el §3 vuelve a fallar"; fi
  if q -1 -f "$W/rb.sql" >"$W/out4b" 2>&1 && grep -q 'No-op' "$W/out4b"; then ok "un segundo rollback es no-op"; else mal "el segundo rollback no fue no-op"; fi

  echo "5 · un cuerpo divergido aborta en la guarda"
  q <<'SQL'
do $d$
declare v text;
begin
  select prosrc into v from pg_proc where proname = 'migration_progress' and pronargs = 2;
  execute format('create or replace function public.migration_progress(p_device_id text, p_action text) returns jsonb language plpgsql set search_path = public as %L',
                 replace(v, '''not_complete''', '''not_complete_x'''));
end $d$;
SQL
  local DIVERGIDO; DIVERGIDO="$(md5_vivo)"
  if q -1 -f "$W/mig.sql" >"$W/out5" 2>&1; then
    mal "la migración se aplicó sobre un cuerpo divergido"
  else
    grep -q 'ni el cuerpo de g15_02 ni el de g17_01' "$W/out5" && ok "abortó en la guarda" || { mal "abortó, pero no en la guarda"; sed 's/^/    /' "$W/out5"; }
  fi
  [[ "$(md5_vivo)" == "$DIVERGIDO" ]] && ok "no tocó la función" || mal "tocó la función divergida"

  # 6-8: el cuerpo de partida con una cuarta escritura, en tres grafías. La guarda espera el md5 de cada una
  # (sed en una copia), así que llegan al recuento del §1: lo que se prueba es el recuento, no el md5.
  cuarta() {
    local etiqueta="$1" sentencia="$2" esperado="$3"
    "cargar_$cuerpo" >/dev/null
    q -v sent="$sentencia" >/dev/null <<'SQL'
select set_config('g17.sent', :'sent', false);
do $d$
declare v text;
begin
  select prosrc into v from pg_proc where proname = 'migration_progress' and pronargs = 2;
  v := replace(v, $q$'bad_action');$q$, $q$'bad_action'); $q$ || current_setting('g17.sent'));
  execute format('create or replace function public.migration_progress(p_device_id text, p_action text) returns jsonb language plpgsql set search_path = public as %L', v);
end $d$;
SQL
    local CUATRO; CUATRO="$(md5_vivo)"
    [[ "$CUATRO" != "$VIRGEN" ]] || mal "$etiqueta: no se añadió la cuarta"
    sed "s/$VIRGEN_PROD/$CUATRO/g" "$MIG" > "$W/mig4.sql"
    if q -1 -f "$W/mig4.sql" >"$W/out6" 2>&1; then
      mal "$etiqueta: aplicó con cuatro escrituras"
    else
      grep -qF "$esperado" "$W/out6" && ok "$etiqueta: abortó («${esperado}»)" || { mal "$etiqueta: abortó por otra cosa"; sed 's/^/    /' "$W/out6"; }
    fi
    [[ "$(md5_vivo)" == "$CUATRO" ]] && ok "$etiqueta: no tocó la función" || mal "$etiqueta: tocó la función"
  }
  echo "6 · una cuarta escritura de reverted_at a null aborta (el número está fijado a 3)"
  cuarta "cuarta minúscula" 'update profiles set reverted_at = null where false;' 'se esperaban 3'
  echo "7 · una cuarta en MAYÚSCULAS (la sustitución no la tocaría) aborta"
  cuarta "cuarta en mayúsculas" 'update profiles set REVERTED_AT = NULL where false;' 'con la grafía esperada'
  echo "8 · una cuarta con nullif (tampoco la tocaría) aborta"
  cuarta "cuarta con nullif" 'update profiles set reverted_at = nullif(reverted_at, reverted_at) where false;' 'con la grafía esperada'
  "cargar_$cuerpo" >/dev/null
  [[ "$(md5_vivo)" == "$VIRGEN" ]] && ok "recargado, el cuerpo vuelve al de partida" || mal "el cuerpo no volvió al de partida"
}

bateria real
bateria replica

echo
if [[ $fallos -eq 0 ]]; then echo "g17_01 banco local: todo en verde"; else echo "g17_01 banco local: $fallos fallo(s)"; exit 1; fi
