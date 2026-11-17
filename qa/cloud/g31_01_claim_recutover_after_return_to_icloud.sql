-- =====================================================================================================
-- g31_01 · Volver a pasar a la nube con la misma cuenta después de volver a iCloud (el re-cutover)
--
-- QUÉ GANA EL USUARIO. Pasó sus datos de su cuenta de Yala a su iCloud («Volver a iCloud»). Hasta hoy, esa cuenta
-- quedaba congelada con la copia de antes y «Pasar a tu cuenta de Yala» con ella decía «todavía no está disponible»:
-- para volver a la nube tenía que usar otra cuenta. Ahora vuelve con la misma: es una activación nueva que REEMPLAZA la
-- copia congelada por lo que el teléfono tiene en su iCloud, que tras la vuelta es lo completo. Lo que borró mientras
-- estaba en iCloud no reaparece.
--
-- Card «2.3 · Poder volver a la nube con la misma cuenta» (V4 de la decisión 53 de la revisión 2.3). Decisión de
-- Jürgen del 2026-11-16: opción A (reemplazar), no fusionar. Encargo `2026-11-16-nube-bugs-media-2-3`.
--
-- === LO MEDIDO ANTES DE CAMBIAR NADA (staging y producción, 2026-11-16) ===
--   · `claim_account` md5(prosrc) 354237247d7c366596f1c2f43f78e802 (el final de g16_04) en LOS DOS entornos; firma
--     (text,text,boolean,text). `apply_delta` 2a5d8b9e…, `migration_progress` 776dac35…, iguales en los dos.
--   · Tras `reverse_complete` la cuenta queda `kind = 'groups_only'`, `reverted_at` puesto y `reverse_frozen_at`
--     puesto (`/sync/push` contesta 409 mientras dure). `migrated_at` no se toca. Las filas personales siguen vivas.
--   · El cliente ya enruta «Pasar a tu cuenta de Yala» desde `icloudActive` (`MigrationStateMachine`, arista
--     `.userActivated`); lo que lo paraba era el `existing_stable` de este RPC (`blockForClaimRefusal` →
--     `accountReturnedToICloud`).
--
-- === EL CAMBIO ===
--   Un parámetro nuevo, `p_recutover boolean default false`, y una rama antes del relevo. Con `p_recutover` y
--   `p_migration` sobre una cuenta `groups_only` con `reverted_at` y sin ida ni vuelta en curso:
--     1. la fila del perfil pasa a `complete`, sin `reverted_at`, sin congelar, sin `migrated_at` ni
--        `personal_adopted_at`, con este dispositivo de líder y la migración en curso (lease armado), en un UPDATE con
--        su propia comprobación (dos claims a la vez: solo uno entra);
--     2. cada fila viva de las 16 tablas personales queda BORRADA (`deleted = true`) con `deleted_hlc` = el `hlc` de la
--        fila con el nodo al máximo (`…-ffffffffffffffff`): gana a la fila que retira y pierde con cualquier cosa que el
--        teléfono suba después. El trigger le pone `server_seq` nuevo: un teléfono que siga en la nube lo baja.
--     3. contesta `created` (con `has_personal_writes`, como todo `created`), más `recutover: true` y `retired_rows`.
--   La subida de la ida reescribe después cada fila con la identidad que ya tenía: `apply_delta` la reinstala (su HLC
--   es mayor que el del borrado) con todas sus unidades.
--   Sin `p_recutover` NADA cambia: el cliente lo manda solo en el claim de «Migrar» (`ForwardClaimIntent.migrateOnly`),
--   no en la entrada de un teléfono nuevo por la bienvenida, que también llama con `p_migration`. Un Worker sin el
--   parámetro no lo manda nunca, así que el orden de despliegue es: este SQL → Worker → app.
--   `user_preferences` no entra: no tiene borrado por fila y la subida de la ida la pisa por LWW.
--
-- === APLICACIÓN ===
--   La firma CAMBIA: `drop function` de la de cuatro argumentos y `create` de la de cinco, en la MISMA transacción
--   (`g31_01-remote.sh apply` la envuelve). Los Worker de hoy llaman con argumentos con nombre y sin `p_recutover`:
--   resuelven a la de cinco por su default. Grants: los mismos que tenía (anon, authenticated, service_role).
--
--     cuerpo vivo (4 args)                          | qué hace
--     ----------------------------------------------|--------------------------------------------
--     md5 354237247d7c366596f1c2f43f78e802 (g16_04)  | drop + create + §2 + §3
--     ya está la de 5 args con el md5 final         | no-op, pero el §2 y el §3 corren IGUAL
--     cualquier otro                                | ABORTA
--   Rollback: `g31_01_rollback.sql` (vuelve al cuerpo de g16_04 desde `fixtures/claim_account.g16_04.functiondef.sql`).
-- =====================================================================================================

-- ── 0 · Guarda de partida ────────────────────────────────────────────────────────────────────────────
do $guard$
declare
  v_firmas int;
  v_src    text;
  v_args   text;
begin
  select count(*) into v_firmas from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'claim_account';
  if v_firmas <> 1 then
    raise exception 'g31_01: hay % firmas de claim_account, tiene que haber 1. Abortada.', v_firmas;
  end if;
  select prosrc, pg_get_function_identity_arguments(p.oid) into v_src, v_args
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'claim_account';
  if v_args = 'p_device_id text, p_provider text, p_migration boolean, p_kind text'
     and md5(v_src) = '354237247d7c366596f1c2f43f78e802' then
    perform set_config('yala.g31_01_estado', 'virgen', true);
  elsif v_args = 'p_device_id text, p_provider text, p_migration boolean, p_kind text, p_recutover boolean' then
    perform set_config('yala.g31_01_estado', 'final', true);
    raise notice 'g31_01: la firma de cinco argumentos ya está (md5 %). No-op; el §2 y el §3 corren igual.', md5(v_src);
  else
    raise exception 'g31_01: claim_account no es el cuerpo esperado (args %, md5 %). Abortada.', v_args, md5(v_src);
  end if;
end $guard$;

-- ── 1 · La función nueva ─────────────────────────────────────────────────────────────────────────────
-- Se crea siempre con un nombre de trabajo y se cambia por la viva solo si la guarda dijo «virgen»: así el fichero
-- entero se puede re-aplicar sin tocar una función que ya está.
CREATE OR REPLACE FUNCTION public.g31_01_claim_account_nueva(p_device_id text, p_provider text, p_migration boolean DEFAULT false, p_kind text DEFAULT 'complete'::text, p_recutover boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_uid       uuid := auth.uid();
  v_created   uuid;
  v_mip       boolean;
  v_leader    text;
  v_migrated  timestamptz;
  v_reverse   boolean;
  v_provider  text;
  v_updated   timestamptz;
  v_pca       timestamptz;
  v_kind      text;
  v_adopted   timestamptz;
  v_personal  boolean := (p_kind = 'complete');
  v_reverted  timestamptz;
  v_table     text;
  v_n         bigint;
  v_retired   bigint := 0;
  -- g31_01: las 16 tablas personales que `apply_delta` acepta (su `c_tables`). `user_preferences` no va: no tiene borrado
  -- de fila y lo que suba el teléfono la pisa por LWW.
  c_personal  constant text[] := array[
    'accounts','budgets','cashflow_lines','cashflow_overrides','cashflow_plans',
    'categories','exchange_rates','favorite_payments','group_bridge_prefs','inbox_drafts',
    'merchant_memory','notification_items','scheduled_payments','subcategories','tags','tx_items'];
  c_hlc_c1    constant text := '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{3}Z-[0-9a-f]{4}-[0-9a-f]{16}$';
begin
  if v_uid is null then
    raise exception 'claim_account: no auth.uid() (SECURITY INVOKER requires a user JWT)'
      using errcode = '28000';
  end if;

  if p_kind is null or p_kind not in ('complete', 'groups_only') then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  -- El guard de `kind` queda abierto durante TODA la función: es una transacción de PostgREST y
  -- ninguna otra escritura de esta función toca `kind`.
  perform set_config('yala.kind_write', txid_current()::text, true);

  -- Atomic reservation. p_migration=true arms the leader lease IN THE SAME INSERT (no kill window
  -- between the created row and a separate begin): migration_in_progress + heartbeat set atomically.
  -- Default false preserves the born-cloud contract and every existing 2-arg caller.
  -- `personal_claimed_at` SOLO se estampa en un alta personal: un alta de grupos crea la misma fila
  -- ligera que create_group/join_group.
  insert into public.profiles (id, provider, leader_device_id, migration_in_progress, migration_updated_at, personal_claimed_at, kind)
  values (
    v_uid, p_provider, p_device_id,
    p_migration,
    case when p_migration then now() else null end,
    case when v_personal then now() else null end,
    p_kind
  )
  on conflict (id) do nothing
  returning id into v_created;

  if v_created is not null then
    return jsonb_build_object('state', 'created', 'has_personal_writes', exists (select 1 from public.sync_seq_counters where user_id = v_uid), 'kind', p_kind);
  end if;

  -- Row already existed: classify its state (RLS restricts the SELECT to the caller's own row).
  select migration_in_progress, leader_device_id, migrated_at, reverse_in_progress, provider, migration_updated_at, personal_claimed_at, kind, personal_adopted_at, reverted_at
    into v_mip, v_leader, v_migrated, v_reverse, v_provider, v_updated, v_pca, v_kind, v_adopted, v_reverted
    from public.profiles where id = v_uid;

  -- Un claim de grupos sobre una cuenta que YA existe no toca nada de lo personal: solo clasifica.
  -- Nunca degrada (la única degradación es el reverse cutover).
  if not v_personal then
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

  -- PROMOCIÓN de fila ligera de grupos (personal_claimed_at NULL): para lo personal esta cuenta nace
  -- AHORA — estampar exactamente lo que el INSERT habría estampado y devolver 'created'. Guard
  -- `not v_mip` conservador: una fila con mip=true y pca NULL es teóricamente imposible post-backfill
  -- (solo este RPC arma mip y desde hoy siempre estampa pca) — si apareciera, cae a la lógica de
  -- lease/takeover de abajo en vez de promocionar a ciegas.
  if v_pca is null and not v_mip then
    update public.profiles
      set personal_claimed_at   = now(),
          provider              = p_provider,
          leader_device_id      = p_device_id,
          migration_in_progress = p_migration,
          migration_updated_at  = case when p_migration then now() else null end,
          kind                  = 'complete'
      where id = v_uid and personal_claimed_at is null;
    if found then
      return jsonb_build_object('state', 'created', 'has_personal_writes', exists (select 1 from public.sync_seq_counters where user_id = v_uid), 'kind', 'complete');
    end if;
    -- Carrera: otro claim promocionó entre el SELECT y el UPDATE -> re-leer y clasificar normal.
    select migration_in_progress, leader_device_id, migrated_at, reverse_in_progress, provider, migration_updated_at, kind
      into v_mip, v_leader, v_migrated, v_reverse, v_provider, v_updated, v_kind
      from public.profiles where id = v_uid;
  end if;

  -- g31_01: VOLVER A PASAR a la nube con la cuenta que volvió a iCloud (el re-cutover). Decisión de Jürgen del
  -- 2026-11-16, opción A: es una activación nueva que REEMPLAZA la copia congelada por lo que trae el teléfono, que tras
  -- la vuelta tiene en su iCloud lo completo. Solo lo pide el claim de «Pasar a tu cuenta de Yala» (`p_recutover`, que el
  -- cliente manda solo con la intención de migrar): la entrada de un teléfono nuevo por la bienvenida también llama con
  -- `p_migration` y no puede vaciar la copia.
  --  · Primero la fila del perfil, con su propia comprobación (CAS): dos claims a la vez no retiran dos veces.
  --  · Lo que había se retira con un BORRADO por fila (`deleted`), no con DELETE: un teléfono que siga en la nube sin
  --    haber hecho la vuelta lo baja y lo quita. El HLC del borrado es el de la fila con el nodo al máximo: gana a la
  --    fila que retira y pierde con todo lo que el teléfono suba después, aunque su reloj vaya atrás.
  --  · `migrated_at` y `personal_adopted_at` vuelven a null: son de la copia que se retira, y `migrated_at` puesto
  --    cerraba el relevo antes del cutover nuevo (rama g16_04).
  if p_recutover and p_migration and v_kind = 'groups_only' and v_reverted is not null
     and not coalesce(v_mip, false) and not coalesce(v_reverse, false) then
    update public.profiles
      set kind                  = 'complete',
          reverted_at           = null,
          reverse_frozen_at     = null,
          migrated_at           = null,
          personal_adopted_at   = null,
          personal_claimed_at   = coalesce(personal_claimed_at, now()),
          provider              = p_provider,
          leader_device_id      = p_device_id,
          migration_in_progress = true,
          migration_updated_at  = now()
      where id = v_uid and kind = 'groups_only' and reverted_at is not null
        and not migration_in_progress and not reverse_in_progress;
    if found then
      foreach v_table in array c_personal loop
        execute format(
          'update public.%I set deleted = true,
             deleted_hlc = case when hlc ~ $2 then left(hlc, 30) || ''ffffffffffffffff''
                                else to_char(clock_timestamp() at time zone ''utc'', ''YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'')
                                     || ''-0000-0000000000000000'' end,
             updated_at = now()
           where user_id = $1 and not deleted', v_table)
          using v_uid, c_hlc_c1;
        get diagnostics v_n = row_count;
        v_retired := v_retired + v_n;
      end loop;
      return jsonb_build_object('state', 'created',
        'has_personal_writes', exists (select 1 from public.sync_seq_counters where user_id = v_uid),
        'kind', 'complete', 'recutover', true, 'retired_rows', v_retired);
    end if;
    -- Carrera: otro claim cambió la fila entre la lectura y el UPDATE -> re-leer y clasificar normal.
    select migration_in_progress, leader_device_id, migrated_at, reverse_in_progress, provider, migration_updated_at, kind
      into v_mip, v_leader, v_migrated, v_reverse, v_provider, v_updated, v_kind
      from public.profiles where id = v_uid;
  end if;

  -- Sin `p_recutover`, NO hay promoción para la cuenta que volvió a iCloud (g31_01, arriba).

  if v_mip and v_leader is distinct from p_device_id then
    -- Lease expiry (§g.1): a leader silent for >60 min can be TAKEN OVER — but ONLY by another
    -- MIGRATION caller (p_migration=true). A born-cloud/returning-user caller must NEVER usurp a
    -- half-migrated account (SERIO 2 of the adversarial review): it gets claiming_in_progress and
    -- routes to wait/adopt, never seeds. A NULL heartbeat (legacy row) never expires.
    -- g16_04: después del cutover no hay relevo. `migrated_at` solo lo estampa el `cutover` del líder, y con la
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
      update public.profiles
        set leader_device_id = p_device_id, migration_updated_at = now()
        where id = v_uid;
      return jsonb_build_object('state', 'created', 'has_personal_writes', exists (select 1 from public.sync_seq_counters where user_id = v_uid), 'kind', v_kind);  -- takeover: this device now leads
    end if;
    return jsonb_build_object('state', 'claiming_in_progress', 'kind', v_kind);
  elsif v_mip and v_leader = p_device_id then
    return jsonb_build_object('state', 'created', 'has_personal_writes', exists (select 1 from public.sync_seq_counters where user_id = v_uid), 'kind', v_kind);  -- idempotent reclaim by the same leader
  elsif not p_migration
        and v_leader = p_device_id
        and v_kind = 'complete'
        and not v_reverse
        and not exists (select 1 from public.sync_seq_counters where user_id = v_uid)
        and v_adopted is null then
    -- g16_01: el MISMO teléfono reintenta un alta cuya respuesta se perdió. La promoción (o el INSERT)
    -- ya dejó la cuenta completa con este dispositivo de líder, y nadie ha escrito nada personal en ella:
    -- no hay nada que fusionar, así que es el mismo alta repetido. Sin esta rama el reintento leía su
    -- propia huella como «ya tienes finanzas personales» y bloqueaba para siempre.
    -- `sync_seq_counters` lo crea `stamp_server_seq` en las 17 tablas del canal personal (16 de dominio
    -- + user_preferences): ninguna fila = ninguna escritura personal, nunca. Ticket
    -- `claim-promotion-lost-response-blocks-the-retry`.
    return jsonb_build_object('state', 'created', 'has_personal_writes', exists (select 1 from public.sync_seq_counters where user_id = v_uid), 'kind', v_kind);
  else
    -- g16_02: el claim de ENTRADA (con `migration`: el adopt) de un dispositivo que no es el líder recibe
    -- `existing_stable`: ese teléfono va a entrar en esta cuenta. Se deja constancia en el servidor, porque su
    -- primera subida puede no llegar nunca, y sin ella la rama g16_01 dejaba al líder volver a sembrar al lado.
    -- Sin `migration` no: ese claim puede quedarse fuera («Activar Yala completo» bloqueado). Solo el primer
    -- sello. Ticket `claim-replay-can-seed-beside-a-phone-that-adopted-silently`.
    if p_migration and v_leader is distinct from p_device_id then
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
end $function$;

do $swap$
declare
  v_src text;
begin
  if current_setting('yala.g31_01_estado', true) = 'virgen' then
    drop function public.claim_account(text, text, boolean, text);
    alter function public.g31_01_claim_account_nueva(text, text, boolean, text, boolean) rename to claim_account;
    grant execute on function public.claim_account(text, text, boolean, text, boolean) to anon, authenticated, service_role;
  else
    -- Ya estaba: el cuerpo de trabajo tiene que ser byte a byte el vivo, o el fichero y la base divergieron.
    select prosrc into v_src from pg_proc where oid = 'public.claim_account(text,text,boolean,text,boolean)'::regprocedure;
    if v_src is distinct from (select prosrc from pg_proc
                                where oid = 'public.g31_01_claim_account_nueva(text,text,boolean,text,boolean)'::regprocedure) then
      raise exception 'g31_01: la función viva de cinco argumentos no es la de este fichero (md5 %). Abortada.', md5(v_src);
    end if;
    drop function public.g31_01_claim_account_nueva(text, text, boolean, text, boolean);
  end if;
end $swap$;

-- ── 2 · Verificación estructural ─────────────────────────────────────────────────────────────────────
do $verify$
declare
  v_row record;
begin
  select p.prosecdef, p.proconfig, md5(p.prosrc) as m,
         has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
         has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec
    into v_row from pg_proc p where p.oid = 'public.claim_account(text,text,boolean,text,boolean)'::regprocedure;
  if v_row.prosecdef then raise exception 'g31_01 verify: claim_account tiene que ser SECURITY INVOKER'; end if;
  if v_row.proconfig is distinct from array['search_path=public'] then
    raise exception 'g31_01 verify: search_path inesperado %', v_row.proconfig;
  end if;
  if not v_row.auth_exec then raise exception 'g31_01 verify: authenticated sin EXECUTE'; end if;
  if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname in ('claim_account', 'g31_01_claim_account_nueva')) <> 1 then
    raise exception 'g31_01 verify: tiene que quedar UNA claim_account y ninguna de trabajo';
  end if;
  -- La lista de tablas de la rama es la de `apply_delta`: si una tabla personal nueva entra allí y no aquí, su copia
  -- congelada sobreviviría al re-cutover.
  if (select prosrc from pg_proc where oid = 'public.apply_delta(text,uuid,text,jsonb,jsonb,text,integer)'::regprocedure)
       not like '%''accounts'',''budgets'',''cashflow_lines'',''cashflow_overrides'',''cashflow_plans'',%''merchant_memory'',''notification_items'',''scheduled_payments'',''subcategories'',''tags'',''tx_items''];%' then
    raise exception 'g31_01 verify: la lista de tablas de apply_delta cambió; revisa c_personal de claim_account';
  end if;
  raise notice 'g31_01 · claim_account (5 args) md5 de llegada: %', v_row.m;
end $verify$;

-- ── 3 · Verificación de COMPORTAMIENTO ───────────────────────────────────────────────────────────────
-- Cada escenario en su savepoint, deshecho al acabar (sin filas, ni las de los triggers). Siempre desde el dispositivo
-- D. Partidas: reverted (volvió a iCloud: groups_only + reverted_at + congelada, con dos filas vivas y una ya borrada),
-- reverted_rip (lo mismo con otra vuelta en curso), complete (cuenta completa normal, líder D), lite (fila de grupos).
-- Llamadas: R = migración + recutover · M = migración sin recutover · P = personal sin migración con recutover ·
-- G = groups_only con recutover.
-- Columnas: etiqueta | partida | llamada | estado esperado | ¿retira? | rol
-- Marcas: `.` bien · L estado · K perfil · T filas · H HLC del borrado · U la subida no reinstala · A andamio.
-- Con `yala.g31_01_informe = on` no aborta: deja las marcas en el aviso (así se corren el vivo y los mutantes).
do $conducta$
declare
  v_uid    uuid;
  v_ret    jsonb;
  v_state  text;
  v_prof   record;
  v_live   int;
  v_dead   int;
  v_badhlc int;
  v_up     jsonb;
  v_reinst boolean;
  v_mark   text;
  v_marcas text := '';
  v_fallos text := '';
  v_n      int := 0;
  v_tx1    uuid;
  e        text[];
  escen text[][] := array[
    array['volver a pasar con la misma cuenta → entra y retira la copia',     'reverted',     'R', 'created',              'si', 'postgres'],
    array['lo mismo con el rol de PostgREST (RLS de las 16 tablas)',          'reverted',     'R', 'created',              'si', 'authenticated'],
    array['sin recutover (la bienvenida de un teléfono nuevo) → como antes',  'reverted',     'M', 'existing_stable',      'no', 'postgres'],
    array['recutover sin migración → como antes',                             'reverted',     'P', 'existing_stable',      'no', 'postgres'],
    array['recutover pidiendo groups_only → como antes',                      'reverted',     'G', 'existing_stable',      'no', 'postgres'],
    array['recutover con otra vuelta en curso → como antes',                  'reverted_rip', 'R', 'existing_stable',      'no', 'postgres'],
    array['recutover sobre una cuenta completa → como antes',                 'complete',     'R', 'existing_stable',      'no', 'postgres'],
    array['recutover sobre una cuenta de grupos → promoción de siempre',      'lite',         'R', 'created',              'no', 'postgres']
  ];
begin
  foreach e slice 1 in array escen loop
    v_n := v_n + 1;
    v_state := null; v_ret := null; v_live := null; v_dead := null; v_badhlc := null; v_up := null; v_reinst := null;
    v_prof := null;
    begin
      v_uid := gen_random_uuid();
      insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
        values (v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
                'g31-01-verify-' || replace(v_uid::text, '-', '') || '@invalid.local', now(), now());
      perform set_config('yala.kind_write', txid_current()::text, true);
      if e[2] = 'lite' then
        insert into public.profiles (id) values (v_uid);
      elsif e[2] = 'complete' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, leader_device_id, migrated_at)
          values (v_uid, 'google', 'complete', now() - interval '30 days', 'g31-01-D', now() - interval '29 days');
      else
        insert into public.profiles (id, provider, kind, personal_claimed_at, leader_device_id, migrated_at,
                                     reverse_frozen_at, reverted_at, reverse_in_progress, personal_adopted_at,
                                     migration_updated_at)
          values (v_uid, 'google', 'groups_only', now() - interval '30 days', 'g31-01-D', now() - interval '29 days',
                  now() - interval '2 days', now() - interval '1 day', e[2] = 'reverted_rip', now() - interval '28 days',
                  now() - interval '1 day');
      end if;
      perform set_config('yala.kind_write', '', true);
      perform set_config('request.jwt.claims', json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

      if e[2] <> 'lite' then
        v_tx1 := gen_random_uuid();
        insert into public.tx_items (user_id, sync_id, hlc, field_hlcs, server_seq, deleted, amount, note)
          values (v_uid, v_tx1, '2026-10-01T10:00:00.000Z-0003-00000000000000aa',
                  '{"amount":"2026-10-01T10:00:00.000Z-0003-00000000000000aa","note":"2026-10-01T10:00:00.000Z-0003-00000000000000aa"}',
                  0, false, 12.5, 'g31');
        insert into public.accounts (user_id, sync_id, hlc, field_hlcs, server_seq, deleted, name)
          values (v_uid, gen_random_uuid(), '2026-09-01T10:00:00.000Z-0000-00000000000000bb', '{}', 0, false, 'g31');
        insert into public.tags (user_id, sync_id, hlc, field_hlcs, server_seq, deleted, deleted_hlc, name)
          values (v_uid, gen_random_uuid(), '2026-08-01T10:00:00.000Z-0000-00000000000000cc', '{}', 0, true,
                  '2026-08-02T10:00:00.000Z-0000-00000000000000cc', 'g31');
      end if;

      if e[6] = 'authenticated' then perform set_config('role', 'authenticated', true); end if;
      v_ret := public.claim_account('g31-01-D', 'google', e[3] in ('R', 'M'),
                                    case e[3] when 'G' then 'groups_only' else 'complete' end,
                                    e[3] in ('R', 'P', 'G'));
      v_state := coalesce(v_ret->>'state', '<sin state>');
      select kind, reverted_at, reverse_frozen_at, migrated_at, personal_adopted_at, leader_device_id,
             migration_in_progress into v_prof from public.profiles where id = v_uid;
      select count(*) filter (where not deleted), count(*) filter (where deleted),
             count(*) filter (where deleted and sync_id = v_tx1
                                and deleted_hlc is distinct from '2026-10-01T10:00:00.000Z-0003-ffffffffffffffff')
        into v_live, v_dead, v_badhlc
        from (select sync_id, deleted, deleted_hlc from public.tx_items where user_id = v_uid
              union all select sync_id, deleted, deleted_hlc from public.accounts where user_id = v_uid
              union all select sync_id, deleted, deleted_hlc from public.tags where user_id = v_uid) t;
      -- La subida de la ida: la misma identidad con un HLC de ahora reinstala la fila con todas sus unidades.
      if e[5] = 'si' then
        v_up := public.apply_delta('tx_items', v_tx1, 'upsert', '{"amount":{"amount":20},"note":{"note":"vuelta"}}',
                  '{"amount":"2026-11-16T22:00:00.000Z-0000-00000000000000dd","note":"2026-11-16T22:00:00.000Z-0000-00000000000000dd"}',
                  null, 1);
        select not deleted and amount = 20 and note = 'vuelta' into v_reinst from public.tx_items where user_id = v_uid and sync_id = v_tx1;
      end if;
      raise exception 'g31_01_deshacer';
    exception
      when others then
        if sqlerrm <> 'g31_01_deshacer' then
          v_mark := 'A';
          v_fallos := v_fallos || format(E'\n  · %s: el andamio falló: %s', e[1], sqlerrm);
        elsif v_state is distinct from e[4] then
          v_mark := 'L';
          v_fallos := v_fallos || format(E'\n  · %s: estado esperado %s, obtenido %s (%s)', e[1], e[4], v_state, v_ret);
        elsif e[5] = 'si' and (v_prof.kind <> 'complete' or v_prof.reverted_at is not null
                               or v_prof.reverse_frozen_at is not null or v_prof.migrated_at is not null
                               or v_prof.personal_adopted_at is not null or v_prof.leader_device_id <> 'g31-01-D'
                               or not v_prof.migration_in_progress or (v_ret->>'recutover') is distinct from 'true') then
          v_mark := 'K';
          v_fallos := v_fallos || format(E'\n  · %s: perfil tras el re-cutover: %s · %s', e[1], row_to_json(v_prof), v_ret);
        elsif e[5] = 'no' and e[2] in ('reverted', 'reverted_rip')
              and (v_prof.kind <> 'groups_only' or v_prof.reverted_at is null or v_prof.reverse_frozen_at is null) then
          v_mark := 'K';
          v_fallos := v_fallos || format(E'\n  · %s: sin re-cutover el perfil cambió: %s', e[1], row_to_json(v_prof));
        elsif e[2] <> 'lite' and ((e[5] = 'si' and (v_live <> 0 or v_dead <> 3)) or (e[5] = 'no' and (v_live <> 2 or v_dead <> 1))) then
          v_mark := 'T';
          v_fallos := v_fallos || format(E'\n  · %s: filas vivas %s, borradas %s', e[1], v_live, v_dead);
        elsif e[5] = 'si' and v_badhlc <> 0 then
          v_mark := 'H';
          v_fallos := v_fallos || format(E'\n  · %s: el HLC del borrado no es el de la fila con el nodo al máximo', e[1]);
        elsif e[5] = 'si' and v_reinst is distinct from true then
          v_mark := 'U';
          v_fallos := v_fallos || format(E'\n  · %s: la subida no reinstaló la fila: %s', e[1], v_up);
        else
          v_mark := '.';
        end if;
        v_marcas := v_marcas || v_mark;
    end;
  end loop;
  if coalesce(current_setting('yala.g31_01_informe', true), '') = 'on' then
    raise notice 'g31_01 informe · %', v_marcas;
    return;
  end if;
  if v_fallos <> '' then
    raise exception 'g31_01 conducta: fallaron escenarios (de %):%', v_n, v_fallos;
  end if;
  raise notice 'g31_01 OK · %/% escenarios · volver a pasar a la nube reemplaza la copia congelada.', v_n, v_n;
end $conducta$;
