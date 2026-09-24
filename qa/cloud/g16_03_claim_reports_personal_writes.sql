-- =====================================================================================================
-- g16_03 · el claim que da el turno dice si la cuenta ya tiene datos personales
--
-- QUÉ GANA EL USUARIO. Empieza a activar la nube en un teléfono y a mitad se queda sin conexión más de una hora.
-- Mientras tanto otro teléfono entra en la misma cuenta y `claim_account` le da el relevo (`created`). Hasta hoy ese
-- teléfono subía su corpus encima de lo que el primero alcanzó a subir, fuera o no el mismo. Ahora el servidor le dice
-- que la cuenta ya recibió datos personales, y el cliente comprueba —antes de subir nada— que su corpus comparte
-- identidades con lo que hay; si no, no sube y sale con un texto que lo dice.
--
-- Ticket: `migration-takeover-uploads-without-a-lineage-check` (Paso 0 en su encargo).
--
-- === EL CAMBIO ===
--   Toda respuesta `created` gana `has_personal_writes`: hay fila en `sync_seq_counters` para esta cuenta, la misma
--   señal que usa la rama g16_01 («alguna vez se escribió algo personal aquí»). Son CINCO `return`: el alta nueva, la
--   promoción de una cuenta de grupos, el relevo de un líder callado, el re-claim del mismo líder y la rama g16_01.
--   Se añade a los cinco a propósito, y no solo al relevo: si la respuesta del relevo se pierde, el reintento cae en la
--   rama del mismo líder, y un campo «esto es un relevo» ya no llegaría.
--   El alta normal —cuenta nueva o solo de grupos— nunca tiene contador: el cliente no paga nada nuevo ahí.
--   `existing_stable` y `claiming_in_progress` no cambian.
--
-- === POR QUÉ EL CONTADOR Y NO «HAY FILAS VIVAS» ===
--   Es una lectura por clave primaria, y el cliente hace la comprobación fina (enumera y cruza identidades) solo cuando
--   el contador existe. Un contador de una cuenta cuyas filas se borraron todas, o que solo recibió preferencias, le
--   cuesta al cliente una enumeración que no encuentra nada que mezclar, y sigue.
--
-- === APLICACIÓN ===
--   NO trae `begin;`/`commit;`: `apply_migration` ya envuelve en transacción. Por psql, con `-1`.
--   La firma NO cambia: sin `drop function`, sin grants, sin deploy del Worker (devuelve el JSON del RPC tal cual).
--
--     cuerpo vivo                                   | qué hace
--     ----------------------------------------------|--------------------------------------------
--     md5 ab0e59d094fe7d7324d3ea79b4861965 (g16_02)  | la sustitución + §2 + §3
--     md5 c96106b7f3b043e5a26f68ff971c2123 (final)  | no-op, pero el §2 y el §3 corren IGUAL
--     cualquier otro                                | ABORTA
-- =====================================================================================================

-- ── 0 · Guarda de partida ────────────────────────────────────────────────────────────────────────────
do $guard$
declare
  v_src    text;
  v_firmas int;
begin
  select count(*) into v_firmas from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';
  if v_firmas <> 1 then
    raise exception 'g16_03: hay % firmas de claim_account, tiene que haber 1. Abortada.', v_firmas;
  end if;

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';

  if md5(v_src) = 'ab0e59d094fe7d7324d3ea79b4861965' then
    perform set_config('yala.g16_03_estado', 'virgen', true);
  elsif md5(v_src) = 'c96106b7f3b043e5a26f68ff971c2123' then
    perform set_config('yala.g16_03_estado', 'final', true);
    raise notice 'g16_03: la pista ya está en el cuerpo vivo (md5 %). No-op; el §2 y el §3 corren igual.', md5(v_src);
  else
    raise exception 'g16_03: claim_account no es el cuerpo esperado (md5 %). Abortada.', md5(v_src);
  end if;
end $guard$;

-- ── 1 · La transformación ────────────────────────────────────────────────────────────────────────────
-- Un solo patrón, que tiene que aparecer EXACTAMENTE cinco veces (los cinco `created`).
do $mig$
declare
  v_src text;
  v_new text;
  v_old constant text := $o$jsonb_build_object('state', 'created', 'kind', $o$;
  v_rep constant text := $n$jsonb_build_object('state', 'created', 'has_personal_writes', exists (select 1 from public.sync_seq_counters where user_id = v_uid), 'kind', $n$;
  v_n   int;
begin
  if coalesce(current_setting('yala.g16_03_estado', true), '') <> 'virgen' then
    return;
  end if;

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';

  v_n := (length(v_src) - length(replace(v_src, v_old, ''))) / length(v_old);
  if v_n <> 5 then
    raise exception 'g16_03: el patrón de `created` aparece % veces en claim_account, tienen que ser 5. Abortada.', v_n;
  end if;
  v_new := replace(v_src, v_old, v_rep);

  -- Misma firma y mismos defaults que g15_01/g16_01/g16_02: `create or replace` conserva los grants.
  execute format(
    'create or replace function public.claim_account(p_device_id text, p_provider text, p_migration boolean default false, p_kind text default %L) returns jsonb language plpgsql set search_path = public as %L',
    'complete', v_new);
end $mig$;

-- ── 2 · Verificación ESTRUCTURAL ─────────────────────────────────────────────────────────────────────
do $verify$
declare
  v_src text;
  v_n   int;
begin
  select count(*) into v_n from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';
  if v_n <> 1 then raise exception 'g16_03 verify: % firmas de claim_account', v_n; end if;

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';
  v_n := (length(v_src) - length(replace(v_src, $m$'has_personal_writes'$m$, ''))) / length($m$'has_personal_writes'$m$);
  if v_n <> 5 then raise exception 'g16_03 verify: la pista está % veces, tienen que ser 5', v_n; end if;
  v_n := (length(v_src) - length(replace(v_src, $m$'state', 'created', 'kind'$m$, ''))) / length($m$'state', 'created', 'kind'$m$);
  if v_n <> 0 then raise exception 'g16_03 verify: quedan % `created` sin la pista', v_n; end if;

  -- SECURITY INVOKER con search_path fijo: la pista lee el contador POR RLS (policy `seq_select`).
  select count(*) into v_n from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account'
      and not p.prosecdef and p.proconfig = array['search_path=public'];
  if v_n <> 1 then
    raise exception 'g16_03 verify: claim_account ya no es SECURITY INVOKER con search_path=public';
  end if;

  if md5(v_src) <> 'c96106b7f3b043e5a26f68ff971c2123' then
    raise exception 'g16_03 verify: md5 de llegada % distinto del medido en el banco', md5(v_src);
  end if;
  raise notice 'g16_03 · claim_account md5 de llegada: %', md5(v_src);
end $verify$;

-- ── 3 · Verificación de COMPORTAMIENTO ───────────────────────────────────────────────────────────────
-- Cada escenario en su savepoint, deshecho al acabar (sin filas, ni las de los triggers).
-- Columnas: etiqueta | partida | escritura | llamada | estado esperado | pista esperada (true/false/absent) | rol.
-- Partidas: none (sin fila), lite (fila de grupos), mip_stale (migración en curso de OTRO con el lease vencido),
-- mip_self (migración en curso de ESTE), complete_self (completa, líder este, sin migración).
-- Escrituras: '-', tx_items / accounts (una fila de dominio), prefs (solo una preferencia).
-- Llamadas: t = personal con migración, f = personal sin migración, g = `groups_only`. Siempre desde el dispositivo D.
do $conducta$
declare
  v_uid     uuid;
  v_ret     jsonb;
  v_state   text;
  v_hint    text;
  v_fallos  text := '';
  v_n       int := 0;
  e         text[];
  escen text[][] := array[
    array['alta nueva con migración → sin datos',                         'none',          '-',        't', 'created',              'false',  'postgres'],
    array['alta nueva born-cloud → sin datos',                            'none',          '-',        'f', 'created',              'false',  'postgres'],
    array['promoción de cuenta de grupos → sin datos',                    'lite',          '-',        't', 'created',              'false',  'postgres'],
    array['relevo de un líder callado que ya subió → con datos',          'mip_stale',     'tx_items', 't', 'created',              'true',   'postgres'],
    array['lo mismo con el rol de PostgREST (RLS del contador)',          'mip_stale',     'tx_items', 't', 'created',              'true',   'authenticated'],
    array['relevo de un líder callado que subió cuentas → con datos',     'mip_stale',     'accounts', 't', 'created',              'true',   'postgres'],
    array['relevo de un líder callado que no subió nada → sin datos',     'mip_stale',     '-',        't', 'created',              'false',  'postgres'],
    array['re-claim del mismo líder tras subir → con datos',              'mip_self',      'tx_items', 't', 'created',              'true',   'postgres'],
    array['re-claim del mismo líder sin subir → sin datos',               'mip_self',      '-',        't', 'created',              'false',  'postgres'],
    array['rama g16_01 (mismo teléfono, cuenta vacía) → sin datos',       'complete_self', '-',        'f', 'created',              'false',  'postgres'],
    array['solo preferencias → el contador cuenta',                       'mip_stale',     'prefs',    't', 'created',              'true',   'postgres'],
    array['existing_stable no lleva la pista',                            'complete_self', 'tx_items', 'f', 'existing_stable',      'absent', 'postgres'],
    array['claiming_in_progress no lleva la pista',                       'mip_fresh',     'tx_items', 't', 'claiming_in_progress', 'absent', 'postgres'],
    array['groups_only no lleva la pista',                                'complete_self', '-',        'g', 'existing_stable',      'absent', 'postgres']
  ];
begin
  foreach e slice 1 in array escen loop
    v_n := v_n + 1;
    v_state := null;
    v_hint := null;
    begin
      v_uid := gen_random_uuid();
      insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
        values (v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
                'g16-03-verify-' || replace(v_uid::text, '-', '') || '@invalid.local', now(), now());

      perform set_config('yala.kind_write', txid_current()::text, true);
      if e[2] = 'lite' then
        insert into public.profiles (id) values (v_uid);
      elsif e[2] = 'mip_stale' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, migration_in_progress,
                                     leader_device_id, migration_updated_at)
          values (v_uid, 'apple', 'complete', now(), true, 'g16-03-O', now() - interval '2 hours');
      elsif e[2] = 'mip_fresh' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, migration_in_progress,
                                     leader_device_id, migration_updated_at)
          values (v_uid, 'apple', 'complete', now(), true, 'g16-03-O', now());
      elsif e[2] = 'mip_self' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, migration_in_progress,
                                     leader_device_id, migration_updated_at)
          values (v_uid, 'apple', 'complete', now(), true, 'g16-03-D', now());
      elsif e[2] = 'complete_self' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, leader_device_id)
          values (v_uid, 'apple', 'complete', now(), 'g16-03-D');
      end if;
      perform set_config('yala.kind_write', '', true);

      perform set_config('request.jwt.claims',
                         json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

      if e[3] in ('accounts', 'tx_items') then
        execute format('insert into public.%I (user_id, sync_id, hlc, server_seq) values ($1, gen_random_uuid(), $2, 0)', e[3])
          using v_uid, '0000000000001:0000:g16';
      elsif e[3] = 'prefs' then
        v_ret := public.apply_pref('g16_03.probe', 'x', '0000000000001:0000:g16');
      end if;

      if e[7] = 'authenticated' then
        perform set_config('role', 'authenticated', true);
      end if;

      v_ret := public.claim_account('g16-03-D', 'apple', e[4] = 't',
                                    case e[4] when 'g' then 'groups_only' else 'complete' end);
      v_state := coalesce(v_ret->>'state', '<sin state>');
      v_hint := case when v_ret ? 'has_personal_writes' then v_ret->>'has_personal_writes' else 'absent' end;

      raise exception 'g16_03_deshacer';
    exception
      when others then
        if sqlerrm <> 'g16_03_deshacer' then
          v_fallos := v_fallos || format(E'\n  · %s: el andamio falló: %s', e[1], sqlerrm);
        elsif v_state is distinct from e[5] then
          v_fallos := v_fallos || format(E'\n  · %s: estado esperado %s, obtenido %s', e[1], e[5], v_state);
        elsif v_hint is distinct from e[6] then
          v_fallos := v_fallos || format(E'\n  · %s: pista esperada %s, obtenida %s', e[1], e[6], v_hint);
        end if;
    end;
  end loop;

  if v_fallos <> '' then
    raise exception 'g16_03 conducta: fallaron escenarios (de %):%', v_n, v_fallos;
  end if;
  raise notice 'g16_03 OK · %/% escenarios · el claim que da el turno dice si la cuenta ya tiene datos personales.', v_n, v_n;
end $conducta$;
