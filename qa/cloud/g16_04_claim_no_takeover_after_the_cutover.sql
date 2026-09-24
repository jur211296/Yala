-- =====================================================================================================
-- g16_04 · después del cutover no hay relevo: quien llega entra en la cuenta
--
-- QUÉ GANA EL USUARIO. Activa la nube en el teléfono A, que llega hasta el final —sus datos ya están verificados en la
-- cuenta— y se queda esperando a que reabra Yala. Si tarda más de una hora, un segundo teléfono B que activa la nube
-- recibía el relevo y volvía a subir su corpus entero encima de una cuenta que ya estaba completa. Ahora B entra en la
-- cuenta como cualquier segundo teléfono (el adopt): baja lo que hay y sube solo lo que A no tenía. Y si A no vuelve
-- nunca —teléfono perdido—, B no se queda esperándolo.
--
-- Ticket: `claim-grants-a-takeover-after-the-leader-passed-the-cutover` (Paso 0 en su encargo). La decisión «B adopta, no
-- espera ni releva» es de Jürgen (2026-09-24).
--
-- === LO MEDIDO ANTES DE CAMBIAR NADA (producción, 2026-09-24) ===
--   · `claim_account` (md5 c96106b7…, g16_03) da `created` a un claim con `migration`, líder ajeno y lease > 60 min, sin
--     mirar `migrated_at`. El banco de abajo, contra la función VIVA, lo reproduce.
--   · Entre los RPC, `migrated_at` solo lo estampa `migration_progress('cutover')`, con guarda de líder y `coalesce`: ninguno
--     lo borra. (El dueño puede PATCHear su propia fila por RLS —los goldens lo hacen—; nadie en la app lo hace.)
--   · Con la migración en curso, el único que cambia de líder además de este relevo es `reverse_claim`, y lo hace
--     cerrándola (`migration_in_progress = false`). ⇒ con `migrated_at` puesto y la migración en curso, el líder apuntado
--     es el que pasó el cutover.
--
-- === EL CAMBIO ===
--   En la rama «migración en curso de OTRO dispositivo», antes del relevo: si `migrated_at` está puesto y el lease venció,
--   `existing_stable` con su `profile`, igual que la rama final. Sin cambiar de líder: si A vuelve, sigue liderando y
--   cierra con su `complete` (y el cliente de #238 lo encuentra `held`).
--   · Con y SIN `migration`. Sin ella, hoy recibía `claiming_in_progress`: «Soy nuevo → nube» se quedaba esperando a un
--     líder que quizá no vuelve. El Worker y el cliente tratan `existing_stable` igual en los dos casos (adopt).
--   · Con `migration` estampa `personal_adopted_at`, la regla de g16_02: es el claim con el que ENTRA el segundo teléfono.
--   · Lease vigente con `migrated_at`: sin cambio, `claiming_in_progress` (A está vivo y cierra enseguida).
--   · Latido nulo (fila legada): nunca vence, como en el relevo — `null < x` es null y el `if` no entra.
--   · Antes del cutover (`migrated_at` nulo): sin cambio, el relevo legítimo sigue.
--   · `reverse_claim` sobre una ida abandonada vive en `migration_progress`: no se toca.
--
-- === APLICACIÓN ===
--   NO trae `begin;`/`commit;`: `apply_migration` ya envuelve en transacción. Por psql, con `-1`.
--   La firma NO cambia: sin `drop function`, sin grants, sin deploy del Worker (devuelve el JSON del RPC tal cual).
--
--     cuerpo vivo                                   | qué hace
--     ----------------------------------------------|--------------------------------------------
--     md5 c96106b7f3b043e5a26f68ff971c2123 (g16_03)  | la sustitución + §2 + §3
--     md5 354237247d7c366596f1c2f43f78e802 (final)  | no-op, pero el §2 y el §3 corren IGUAL
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
    raise exception 'g16_04: hay % firmas de claim_account, tiene que haber 1. Abortada.', v_firmas;
  end if;

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';

  if md5(v_src) = 'c96106b7f3b043e5a26f68ff971c2123' then
    perform set_config('yala.g16_04_estado', 'virgen', true);
  elsif md5(v_src) = '354237247d7c366596f1c2f43f78e802' then
    perform set_config('yala.g16_04_estado', 'final', true);
    raise notice 'g16_04: la rama ya está en el cuerpo vivo (md5 %). No-op; el §2 y el §3 corren igual.', md5(v_src);
  else
    raise exception 'g16_04: claim_account no es el cuerpo esperado (md5 %). Abortada.', md5(v_src);
  end if;
end $guard$;

-- ── 1 · La transformación ────────────────────────────────────────────────────────────────────────────
-- Se inserta la rama delante del relevo. El ancla tiene que aparecer EXACTAMENTE una vez.
do $mig$
declare
  v_src text;
  v_new text;
  v_old constant text := $o$    if p_migration and v_updated is not null and v_updated < now() - interval '60 minutes' then
$o$;
  v_rep constant text := $n$    -- g16_04: después del cutover no hay relevo. `migrated_at` solo lo estampa el `cutover` del líder, y con la
    -- migración en curso solo `reverse_claim` cambia de líder (y la cierra): el líder apuntado es el que pasó el cutover
    -- y su corpus ya está verificado en la cuenta. Con su lease vencido, quien llama ENTRA en ella (`existing_stable` →
    -- adopt), en vez de subir su corpus encima (con `migration`) o esperar a un líder que quizá no vuelve (sin ella). El
    -- líder no cambia: si vuelve, cierra con su `complete`. Un latido nulo no vence (la comparación da null). Con
    -- `migration` deja el sello de g16_02: es el claim con el que entra el segundo teléfono. Ticket
    -- `claim-grants-a-takeover-after-the-leader-passed-the-cutover`.
    if v_migrated is not null and v_updated < now() - interval '60 minutes' then
      if p_migration then
        update public.profiles set personal_adopted_at = now()
          where id = v_uid and personal_adopted_at is null;
      end if;
      return jsonb_build_object(
        'state', 'existing_stable',
        'kind', v_kind,
        'profile', jsonb_build_object(
          'migrated_at', v_migrated,
          'migration_in_progress', v_mip,
          'reverse_in_progress', v_reverse,
          'provider', v_provider
        )
      );
    end if;
    if p_migration and v_updated is not null and v_updated < now() - interval '60 minutes' then
$n$;
  v_n   int;
begin
  if coalesce(current_setting('yala.g16_04_estado', true), '') <> 'virgen' then
    return;
  end if;

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';

  v_n := (length(v_src) - length(replace(v_src, v_old, ''))) / length(v_old);
  if v_n <> 1 then
    raise exception 'g16_04: el ancla del relevo aparece % veces en claim_account, tiene que ser 1. Abortada.', v_n;
  end if;
  v_new := replace(v_src, v_old, v_rep);

  -- Misma firma y mismos defaults que g15_01/g16_01/g16_02/g16_03: `create or replace` conserva los grants.
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
  if v_n <> 1 then raise exception 'g16_04 verify: % firmas de claim_account', v_n; end if;

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';
  v_n := (length(v_src) - length(replace(v_src, $m$-- g16_04:$m$, ''))) / length($m$-- g16_04:$m$);
  if v_n <> 1 then raise exception 'g16_04 verify: la rama está % veces, tiene que ser 1', v_n; end if;
  -- La pista de g16_03 sigue en sus cinco `created`.
  v_n := (length(v_src) - length(replace(v_src, $m$'has_personal_writes'$m$, ''))) / length($m$'has_personal_writes'$m$);
  if v_n <> 5 then raise exception 'g16_04 verify: la pista de g16_03 está % veces, tienen que ser 5', v_n; end if;

  -- SECURITY INVOKER con search_path fijo: el sello y la pista pasan por RLS.
  select count(*) into v_n from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account'
      and not p.prosecdef and p.proconfig = array['search_path=public'];
  if v_n <> 1 then
    raise exception 'g16_04 verify: claim_account ya no es SECURITY INVOKER con search_path=public';
  end if;

  if md5(v_src) <> '354237247d7c366596f1c2f43f78e802' then
    raise exception 'g16_04 verify: md5 de llegada % distinto del medido en el banco', md5(v_src);
  end if;
  raise notice 'g16_04 · claim_account md5 de llegada: %', md5(v_src);
end $verify$;

-- ── 3 · Verificación de COMPORTAMIENTO ───────────────────────────────────────────────────────────────
-- El banco de g16_03 (sus 14 escenarios, sin cambio) ampliado con los del cutover. Cada escenario en su savepoint,
-- deshecho al acabar (sin filas, ni las de los triggers).
-- Columnas: etiqueta | partida | escritura | llamada | estado esperado | pista esperada (true/false/absent) | rol |
--           líder después (D/O/-) | sello `personal_adopted_at` después (set/null/kept = el que ya tenía/-).
-- Siempre, además: un `existing_stable` lleva `kind` y un `profile` objeto (y, sobre una migración en curso, con
-- `migration_in_progress` true y `migrated_at` de la fila); y todo lo que no es `created` deja la migración y el lease
-- como estaban.
-- Partidas: none (sin fila), lite (fila de grupos), mip_stale / mip_fresh (migración en curso de OTRO, O, con el lease
-- vencido / vigente), mip_self (migración en curso de ESTE, D), complete_self (completa, líder D, sin migración).
-- Con sufijo `_cut`, la misma partida con `migrated_at` puesto (el líder pasó el cutover); `mip_nullhb_cut`, con el
-- latido nulo de una fila legada; `mip_59_cut` / `mip_61_cut`, con el lease a 59 y a 61 min (el umbral);
-- `mip_stale_cut_sealed`, con el sello ya puesto (el reintento de quien ya entró y perdió la respuesta).
-- Escrituras: '-', tx_items / accounts (una fila de dominio), prefs (solo una preferencia).
-- Llamadas: t = personal con migración, f = personal sin migración, g = `groups_only`. Siempre desde el dispositivo D.
-- Marcas por escenario: `.` bien · L estado · P pista · F `profile`/`kind` · D líder · S sello · M migración o lease
-- tocados sin `created` · A andamio.
-- Con `yala.g16_04_informe = on` no aborta: deja las marcas en `yala.g16_04_marcas` (así se corren vivo y mutantes).
do $conducta$
declare
  v_uid     uuid;
  v_ret     jsonb;
  v_state   text;
  v_hint    text;
  v_leader  text;
  v_sealed  timestamptz;
  v_mip0    boolean;
  v_upd0    timestamptz;
  v_mip1    boolean;
  v_upd1    timestamptz;
  v_mig1    timestamptz;
  v_mark    text;
  v_marcas  text := '';
  v_fallos  text := '';
  v_n       int := 0;
  e         text[];
  escen text[][] := array[
    -- g16_03, tal cual
    array['alta nueva con migración → sin datos',                         'none',           '-',        't', 'created',              'false',  'postgres',      '-', '-'],
    array['alta nueva born-cloud → sin datos',                            'none',           '-',        'f', 'created',              'false',  'postgres',      '-', '-'],
    array['promoción de cuenta de grupos → sin datos',                    'lite',           '-',        't', 'created',              'false',  'postgres',      '-', '-'],
    array['relevo de un líder callado que ya subió → con datos',          'mip_stale',      'tx_items', 't', 'created',              'true',   'postgres',      'D', 'null'],
    array['lo mismo con el rol de PostgREST (RLS del contador)',          'mip_stale',      'tx_items', 't', 'created',              'true',   'authenticated', 'D', 'null'],
    array['relevo de un líder callado que subió cuentas → con datos',     'mip_stale',      'accounts', 't', 'created',              'true',   'postgres',      'D', 'null'],
    array['relevo de un líder callado que no subió nada → sin datos',     'mip_stale',      '-',        't', 'created',              'false',  'postgres',      'D', 'null'],
    array['re-claim del mismo líder tras subir → con datos',              'mip_self',       'tx_items', 't', 'created',              'true',   'postgres',      'D', 'null'],
    array['re-claim del mismo líder sin subir → sin datos',               'mip_self',       '-',        't', 'created',              'false',  'postgres',      'D', 'null'],
    array['rama g16_01 (mismo teléfono, cuenta vacía) → sin datos',       'complete_self',  '-',        'f', 'created',              'false',  'postgres',      'D', 'null'],
    array['solo preferencias → el contador cuenta',                       'mip_stale',      'prefs',    't', 'created',              'true',   'postgres',      'D', 'null'],
    array['existing_stable no lleva la pista',                            'complete_self',  'tx_items', 'f', 'existing_stable',      'absent', 'postgres',      'D', 'null'],
    array['claiming_in_progress no lleva la pista',                       'mip_fresh',      'tx_items', 't', 'claiming_in_progress', 'absent', 'postgres',      'O', 'null'],
    array['groups_only no lleva la pista',                                'complete_self',  '-',        'g', 'existing_stable',      'absent', 'postgres',      'D', 'null'],
    -- g16_04: después del cutover
    array['tras el cutover, relevo con migración → entra y sella',        'mip_stale_cut',  'tx_items', 't', 'existing_stable',      'absent', 'postgres',      'O', 'set'],
    array['lo mismo con el rol de PostgREST (RLS del sello)',             'mip_stale_cut',  'tx_items', 't', 'existing_stable',      'absent', 'authenticated', 'O', 'set'],
    array['tras el cutover sin nada subido → entra igual',                'mip_stale_cut',  '-',        't', 'existing_stable',      'absent', 'postgres',      'O', 'set'],
    array['tras el cutover sin migración («Soy nuevo») → entra sin sello', 'mip_stale_cut', 'tx_items', 'f', 'existing_stable',      'absent', 'postgres',      'O', 'null'],
    array['tras el cutover, groups_only → como siempre, sin sello',       'mip_stale_cut',  '-',        'g', 'existing_stable',      'absent', 'postgres',      'O', 'null'],
    array['tras el cutover con el lease vigente → espera',                'mip_fresh_cut',  'tx_items', 't', 'claiming_in_progress', 'absent', 'postgres',      'O', 'null'],
    array['tras el cutover, vigente y sin migración → espera',            'mip_fresh_cut',  '-',        'f', 'claiming_in_progress', 'absent', 'postgres',      'O', 'null'],
    array['tras el cutover con latido nulo → no vence, espera',           'mip_nullhb_cut', 'tx_items', 't', 'claiming_in_progress', 'absent', 'postgres',      'O', 'null'],
    array['el mismo líder tras el cutover, lease vencido → sigue',        'mip_self_cut',   'tx_items', 't', 'created',              'true',   'postgres',      'D', 'null'],
    array['antes del cutover, sin migración → espera (SERIO 2)',          'mip_stale',      'tx_items', 'f', 'claiming_in_progress', 'absent', 'postgres',      'O', 'null'],
    array['tras el cutover, lease a 59 min → aún espera',                 'mip_59_cut',     'tx_items', 't', 'claiming_in_progress', 'absent', 'postgres',      'O', 'null'],
    array['tras el cutover, lease a 61 min → entra',                      'mip_61_cut',     'tx_items', 't', 'existing_stable',      'absent', 'postgres',      'O', 'set'],
    array['reintento de quien ya entró → entra y el sello no se mueve',   'mip_stale_cut_sealed', 'tx_items', 't', 'existing_stable', 'absent', 'postgres',     'O', 'kept']
  ];
begin
  foreach e slice 1 in array escen loop
    v_n := v_n + 1;
    v_state := null;
    v_hint := null;
    v_leader := null;
    v_sealed := null;
    v_ret := null;
    v_mip0 := null; v_upd0 := null; v_mip1 := null; v_upd1 := null; v_mig1 := null;
    begin
      v_uid := gen_random_uuid();
      insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
        values (v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
                'g16-04-verify-' || replace(v_uid::text, '-', '') || '@invalid.local', now(), now());

      perform set_config('yala.kind_write', txid_current()::text, true);
      if e[2] = 'lite' then
        insert into public.profiles (id) values (v_uid);
      elsif e[2] in ('mip_stale', 'mip_stale_cut') then
        insert into public.profiles (id, provider, kind, personal_claimed_at, migration_in_progress,
                                     leader_device_id, migration_updated_at, migrated_at)
          values (v_uid, 'apple', 'complete', now(), true, 'g16-04-O', now() - interval '2 hours',
                  case when e[2] = 'mip_stale_cut' then now() - interval '3 hours' end);
      elsif e[2] in ('mip_59_cut', 'mip_61_cut', 'mip_stale_cut_sealed') then
        insert into public.profiles (id, provider, kind, personal_claimed_at, migration_in_progress,
                                     leader_device_id, migration_updated_at, migrated_at, personal_adopted_at)
          values (v_uid, 'apple', 'complete', now(), true, 'g16-04-O',
                  now() - case e[2] when 'mip_59_cut' then interval '59 minutes'
                                    when 'mip_61_cut' then interval '61 minutes' else interval '2 hours' end,
                  now() - interval '3 hours',
                  case when e[2] = 'mip_stale_cut_sealed' then timestamptz '2000-01-01 00:00:00+00' end);
      elsif e[2] in ('mip_fresh', 'mip_fresh_cut') then
        insert into public.profiles (id, provider, kind, personal_claimed_at, migration_in_progress,
                                     leader_device_id, migration_updated_at, migrated_at)
          values (v_uid, 'apple', 'complete', now(), true, 'g16-04-O', now(),
                  case when e[2] = 'mip_fresh_cut' then now() - interval '5 minutes' end);
      elsif e[2] = 'mip_nullhb_cut' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, migration_in_progress,
                                     leader_device_id, migration_updated_at, migrated_at)
          values (v_uid, 'apple', 'complete', now(), true, 'g16-04-O', null, now() - interval '3 hours');
      elsif e[2] in ('mip_self', 'mip_self_cut') then
        insert into public.profiles (id, provider, kind, personal_claimed_at, migration_in_progress,
                                     leader_device_id, migration_updated_at, migrated_at)
          values (v_uid, 'apple', 'complete', now(), true, 'g16-04-D',
                  case when e[2] = 'mip_self_cut' then now() - interval '2 hours' else now() end,
                  case when e[2] = 'mip_self_cut' then now() - interval '3 hours' end);
      elsif e[2] = 'complete_self' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, leader_device_id)
          values (v_uid, 'apple', 'complete', now(), 'g16-04-D');
      end if;
      perform set_config('yala.kind_write', '', true);

      perform set_config('request.jwt.claims',
                         json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

      if e[3] in ('accounts', 'tx_items') then
        execute format('insert into public.%I (user_id, sync_id, hlc, server_seq) values ($1, gen_random_uuid(), $2, 0)', e[3])
          using v_uid, '0000000000001:0000:g16';
      elsif e[3] = 'prefs' then
        v_ret := public.apply_pref('g16_04.probe', 'x', '0000000000001:0000:g16');
      end if;

      select migration_in_progress, migration_updated_at into v_mip0, v_upd0 from public.profiles where id = v_uid;

      if e[7] = 'authenticated' then
        perform set_config('role', 'authenticated', true);
      end if;

      v_ret := public.claim_account('g16-04-D', 'apple', e[4] = 't',
                                    case e[4] when 'g' then 'groups_only' else 'complete' end);
      v_state := coalesce(v_ret->>'state', '<sin state>');
      v_hint := case when v_ret ? 'has_personal_writes' then v_ret->>'has_personal_writes' else 'absent' end;
      select leader_device_id, personal_adopted_at, migration_in_progress, migration_updated_at, migrated_at
        into v_leader, v_sealed, v_mip1, v_upd1, v_mig1 from public.profiles where id = v_uid;

      raise exception 'g16_04_deshacer';
    exception
      when others then
        if sqlerrm <> 'g16_04_deshacer' then
          v_mark := 'A';
          v_fallos := v_fallos || format(E'\n  · %s: el andamio falló: %s', e[1], sqlerrm);
        elsif v_state is distinct from e[5] then
          v_mark := 'L';
          v_fallos := v_fallos || format(E'\n  · %s: estado esperado %s, obtenido %s', e[1], e[5], v_state);
        elsif v_hint is distinct from e[6] then
          v_mark := 'P';
          v_fallos := v_fallos || format(E'\n  · %s: pista esperada %s, obtenida %s', e[1], e[6], v_hint);
        elsif v_state = 'existing_stable'
              and (jsonb_typeof(v_ret->'profile') is distinct from 'object' or v_ret->>'kind' is null
                   or (v_mip1 and ((v_ret->'profile'->>'migration_in_progress') is distinct from 'true'
                                   or (v_ret->'profile'->>'migrated_at') is distinct from to_jsonb(v_mig1)#>>'{}'))) then
          v_mark := 'F';
          v_fallos := v_fallos || format(E'\n  · %s: existing_stable con profile/kind equivocado: %s', e[1], v_ret);
        elsif e[8] <> '-' and v_leader is distinct from ('g16-04-' || e[8]) then
          v_mark := 'D';
          v_fallos := v_fallos || format(E'\n  · %s: líder esperado %s, obtenido %s', e[1], e[8], v_leader);
        elsif e[9] = 'kept' and v_sealed is distinct from timestamptz '2000-01-01 00:00:00+00' then
          v_mark := 'S';
          v_fallos := v_fallos || format(E'\n  · %s: el sello que ya había cambió a %s', e[1], v_sealed);
        elsif e[9] in ('set', 'null') and (v_sealed is not null) <> (e[9] = 'set') then
          v_mark := 'S';
          v_fallos := v_fallos || format(E'\n  · %s: sello esperado %s, obtenido %s', e[1], e[9], v_sealed);
        elsif e[5] <> 'created' and e[2] <> 'none'
              and (v_mip1 is distinct from v_mip0 or v_upd1 is distinct from v_upd0) then
          v_mark := 'M';
          v_fallos := v_fallos || format(E'\n  · %s: sin created, la migración o el lease cambiaron', e[1]);
        else
          v_mark := '.';
        end if;
        v_marcas := v_marcas || v_mark || case when v_n % 10 = 0 then ' ' else '' end;
    end;
  end loop;

  perform set_config('yala.g16_04_marcas', v_marcas, true);
  if coalesce(current_setting('yala.g16_04_informe', true), '') = 'on' then
    raise notice 'g16_04 informe · %', v_marcas;
    return;
  end if;
  if v_fallos <> '' then
    raise exception 'g16_04 conducta: fallaron escenarios (de %):%', v_n, v_fallos;
  end if;
  raise notice 'g16_04 OK · %/% escenarios · después del cutover no hay relevo: quien llega entra en la cuenta.', v_n, v_n;
end $conducta$;
