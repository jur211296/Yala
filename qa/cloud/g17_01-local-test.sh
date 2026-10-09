#!/usr/bin/env bash
# =====================================================================================================
# g17_01 · banco LOCAL de la migración, sin tocar staging ni producción
#
# Levanta un Postgres desechable, crea lo mínimo que la migración lee (auth.users, public.profiles, el rol
# authenticated) y una RÉPLICA de `migration_progress` escrita desde el contrato del README (§«Reversa
# server-side»): mismo guard de g15_02, mismos CAS y el mismo `reverted_at = null` en el claim fresco y en los
# dos takeovers. NO es el cuerpo vivo —ese no está en el repo— y por eso esto no sustituye al §3 de la
# migración, que corre contra el cuerpo real al aplicarla. Lo que sí prueba:
#
#   1. el §3 FALLA con el cuerpo viejo, y nombra los caminos del ticket (dirección 1: puede fallar);
#   2. la migración entera pasa (dirección 2);
#   3. el rollback devuelve exactamente el md5 de partida;
#   4. re-aplicar es no-op y el §3 vuelve a correr;
#   5. un cuerpo divergido aborta en la guarda sin tocar nada.
#
# La guarda de la migración espera el md5 del cuerpo de PRODUCCIÓN; aquí se sustituye en una copia por el md5
# de la réplica. Uso:  bash qa/cloud/g17_01-local-test.sh
# =====================================================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/g17_01_reverse_claim_keeps_reverted_at.sql"
RB="$HERE/g17_01_rollback.sql"
PGBIN="${PGBIN:-/opt/homebrew/opt/postgresql@17/bin}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/g17_01.XXXXXX")"
PORT="${PORT:-55417}"
trap '"$PGBIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

"$PGBIN/initdb" -D "$WORK/data" -U postgres -A trust >/dev/null
# Por TCP y sin socket Unix: la ruta de un directorio temporal largo pasa de los 103 bytes que admite.
"$PGBIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -c listen_addresses=127.0.0.1 -c unix_socket_directories=''" -l "$WORK/log" -w start >/dev/null
PSQL=("$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -q -X)

"${PSQL[@]}" <<'SQL'
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
create role authenticated nologin;
grant usage on schema public to authenticated;
grant select, update on public.profiles to authenticated;
SQL

# La réplica. Las tres escrituras `reverted_at = null` son el claim fresco y los dos takeovers del README.
"${PSQL[@]}" <<'SQL'
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

md5_vivo() {
  "${PSQL[@]}" -t -A -c "select md5(prosrc) from pg_proc where proname = 'migration_progress' and pronargs = 2"
}
VIRGEN_REPLICA="$(md5_vivo)"
VIRGEN_PROD='14fc5e2c54766dd7c5706966c7381f51'
sed "s/$VIRGEN_PROD/$VIRGEN_REPLICA/g" "$MIG" > "$WORK/mig.sql"
sed "s/$VIRGEN_PROD/$VIRGEN_REPLICA/g" "$RB"  > "$WORK/rb.sql"
# Solo el §3, para correrlo contra el cuerpo viejo.
awk '/^-- ── 3 · Verificación de COMPORTAMIENTO/{p=1} p' "$MIG" > "$WORK/conducta.sql"

fallos=0
ok()   { printf '  ✓ %s\n' "$1"; }
mal()  { printf '  ✗ %s\n' "$1"; fallos=$((fallos + 1)); }

echo "1 · el §3 contra el cuerpo VIEJO tiene que fallar"
if "${PSQL[@]}" -1 -f "$WORK/conducta.sql" >"$WORK/out1" 2>&1; then
  mal "el §3 pasó con el cuerpo viejo: no puede fallar, no prueba nada"
else
  n=$(grep -c '^  · ' "$WORK/out1" || true)
  for camino in '(a) revertida: claim fresco' '(b) claim con éxito' '(c) tres dispositivos' 'takeover de una vuelta ajena'; do
    if grep -qF "$camino" "$WORK/out1"; then ok "falla: $camino"; else mal "no falla: $camino"; fi
  done
  for control in 'golden 17' 'born-cloud complete' 'nunca revirtió' 'golden 12'; do
    if grep -qF "$control" "$WORK/out1"; then mal "un control falla con el cuerpo viejo: $control"; else ok "control verde: $control"; fi
  done
  echo "    ($n escenarios en rojo)"
fi
[[ "$(md5_vivo)" == "$VIRGEN_REPLICA" ]] && ok "el intento fallido no tocó la función" || mal "el intento fallido tocó la función"
[[ "$("${PSQL[@]}" -t -A -c 'select count(*) from public.profiles')" == "0" ]] && ok "cero filas sintéticas" || mal "quedaron filas"

echo "2 · la migración entera (con tres cuentas reales para el §1-bis)"
# atascada = volvió a iCloud y un claim le borró reverted_at, con su vuelta reservada (camino 2);
# pura = solo grupos, nunca tuvo lo personal; completa = complete sin marcas. Solo la primera se repara.
"${PSQL[@]}" <<'SQL'
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000a2'), ('00000000-0000-0000-0000-0000000000a3');
insert into public.profiles (id, kind, personal_claimed_at, reverted_at, reverse_in_progress, leader_device_id, migration_updated_at)
values ('00000000-0000-0000-0000-0000000000a1', 'groups_only', now() - interval '3 days', null, true, 'dev-B', now() - interval '2 hours'),
       ('00000000-0000-0000-0000-0000000000a2', 'groups_only', null, null, false, null, now()),
       ('00000000-0000-0000-0000-0000000000a3', 'complete', now(), null, false, null, now());
SQL
reparada() { "${PSQL[@]}" -t -A -c "select reverted_at is not null from public.profiles where id = '00000000-0000-0000-0000-0000000000$1'"; }
if "${PSQL[@]}" -1 -f "$WORK/mig.sql" >"$WORK/out2" 2>&1; then
  grep -o 'g17_01: [0-9]* cuenta[^"]*' "$WORK/out2" | head -1 | sed 's/^/    /'
  [[ "$(reparada a1)" == "t" ]] && ok "§1-bis: la cuenta atascada recupera reverted_at" || mal "§1-bis: la atascada sigue sin reverted_at"
  [[ "$(reparada a2)" == "f" ]] && ok "§1-bis: la de solo grupos pura no se toca" || mal "§1-bis: tocó la de solo grupos pura"
  [[ "$(reparada a3)" == "f" ]] && ok "§1-bis: la complete no se toca" || mal "§1-bis: tocó la complete"
  # Y el dispositivo que quedó con la vuelta reservada vuelve a entrar: re-claim idempotente.
  r=$("${PSQL[@]}" -t -A -c "select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-0000-0000-0000000000a1\"}', false); select public.migration_progress('dev-B', 'reverse_claim')" | tail -1)
  [[ "$r" == '{"ok": true}' ]] && ok "§1-bis: el líder atascado vuelve a entrar ($r)" || mal "§1-bis: el líder atascado recibe $r"
  "${PSQL[@]}" -c "delete from auth.users where id::text like '00000000-0000-0000-0000-0000000000a%'"

  grep -o 'g17_01 OK[^"]*' "$WORK/out2" | head -1 | sed 's/^/    /'
  grep -o 'g17_01: [0-9]* sustitución[^"]*' "$WORK/out2" | head -1 | sed 's/^/    /'
  ok "aplicada"
else
  mal "la migración abortó"; sed 's/^/    /' "$WORK/out2"
fi
APLICADA="$(md5_vivo)"
[[ "$APLICADA" != "$VIRGEN_REPLICA" ]] && ok "el cuerpo cambió (md5 $APLICADA)" || mal "el cuerpo no cambió"
[[ "$("${PSQL[@]}" -t -A -c 'select count(*) from public.profiles')" == "0" ]] && ok "cero filas sintéticas" || mal "quedaron filas"

echo "3 · re-aplicar es no-op y el §3 corre igual"
if "${PSQL[@]}" -1 -f "$WORK/mig.sql" >"$WORK/out3" 2>&1 && grep -q 'ya aplicada' "$WORK/out3" && grep -q 'g17_01 OK' "$WORK/out3"; then
  ok "no-op con el §3 en verde"
else
  mal "la re-aplicación no fue no-op"; sed 's/^/    /' "$WORK/out3"
fi
[[ "$(md5_vivo)" == "$APLICADA" ]] && ok "md5 intacto" || mal "la re-aplicación cambió el cuerpo"

echo "4 · rollback"
if "${PSQL[@]}" -1 -f "$WORK/rb.sql" >"$WORK/out4" 2>&1; then ok "rollback aplicado"; else mal "el rollback abortó"; sed 's/^/    /' "$WORK/out4"; fi
[[ "$(md5_vivo)" == "$VIRGEN_REPLICA" ]] && ok "vuelve al md5 de partida" || mal "el rollback no devolvió el md5 de partida"
if "${PSQL[@]}" -1 -f "$WORK/conducta.sql" >/dev/null 2>&1; then mal "tras el rollback el §3 pasa"; else ok "tras el rollback el §3 vuelve a fallar"; fi

echo "5 · un cuerpo divergido aborta en la guarda"
"${PSQL[@]}" -c "select 1" >/dev/null
"${PSQL[@]}" <<'SQL'
do $d$
declare v text;
begin
  select prosrc into v from pg_proc where proname = 'migration_progress' and pronargs = 2;
  execute format('create or replace function public.migration_progress(p_device_id text, p_action text) returns jsonb language plpgsql set search_path = public as %L',
                 replace(v, '''not_complete''', '''not_complete_x'''));
end $d$;
SQL
DIVERGIDO="$(md5_vivo)"
if "${PSQL[@]}" -1 -f "$WORK/mig.sql" >"$WORK/out5" 2>&1; then
  mal "la migración se aplicó sobre un cuerpo divergido"
else
  grep -q 'ni el cuerpo de g15_02 ni el de g17_01' "$WORK/out5" && ok "abortó en la guarda" || { mal "abortó, pero no en la guarda"; sed 's/^/    /' "$WORK/out5"; }
fi
[[ "$(md5_vivo)" == "$DIVERGIDO" ]] && ok "no tocó la función" || mal "tocó la función divergida"

echo "6 · una cuarta escritura de reverted_at a null aborta (el número está fijado a 3)"
"${PSQL[@]}" <<'SQL'
do $d$
declare v text;
begin
  select prosrc into v from pg_proc where proname = 'migration_progress' and pronargs = 2;
  v := replace(v, $q$'not_complete_x'$q$, $q$'not_complete'$q$);
  v := replace(v, $q$'bad_action');$q$, $q$'bad_action'); update profiles set reverted_at = null where false;$q$);
  execute format('create or replace function public.migration_progress(p_device_id text, p_action text) returns jsonb language plpgsql set search_path = public as %L', v);
end $d$;
SQL
CUATRO="$(md5_vivo)"
sed "s/$VIRGEN_PROD/$CUATRO/g" "$MIG" > "$WORK/mig4.sql"
if "${PSQL[@]}" -1 -f "$WORK/mig4.sql" >"$WORK/out6" 2>&1; then
  mal "aplicó con cuatro escrituras"
else
  grep -q 'se esperaban 3' "$WORK/out6" && ok "abortó: se esperaban 3" || { mal "abortó por otra cosa"; sed 's/^/    /' "$WORK/out6"; }
fi
[[ "$(md5_vivo)" == "$CUATRO" ]] && ok "no tocó la función" || mal "tocó la función"

echo
if [[ $fallos -eq 0 ]]; then echo "g17_01 banco local: todo en verde"; else echo "g17_01 banco local: $fallos fallo(s)"; exit 1; fi
