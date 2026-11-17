-- =====================================================================================================
-- g31_01 · rollback: vuelve claim_account a la firma de cuatro argumentos y al cuerpo de g16_04
-- (md5(prosrc) 354237247d7c366596f1c2f43f78e802). El cuerpo sale de `fixtures/claim_account.g16_04.functiondef.sql`.
-- ANTES de aplicarlo, el Worker no puede estar mandando `p_recutover`: con la función de cuatro argumentos, PostgREST
-- no encontraría la firma y TODO claim daría 502. El Worker de g31_01 solo lo manda con `recutover: true` en el cuerpo,
-- así que basta con que ninguna app con el cambio esté pidiendo un re-cutover.
-- Lo que el re-cutover ya retiró NO vuelve: las filas siguen borradas y la subida de la ida ya las reescribió.
-- =====================================================================================================
do $rb$
begin
  if exists (select 1 from pg_proc where oid = to_regprocedure('public.claim_account(text,text,boolean,text,boolean)')) then
    drop function public.claim_account(text, text, boolean, text, boolean);
  end if;
end $rb$;
CREATE OR REPLACE FUNCTION public.claim_account(p_device_id text, p_provider text, p_migration boolean DEFAULT false, p_kind text DEFAULT 'complete'::text)
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
  select migration_in_progress, leader_device_id, migrated_at, reverse_in_progress, provider, migration_updated_at, personal_claimed_at, kind, personal_adopted_at
    into v_mip, v_leader, v_migrated, v_reverse, v_provider, v_updated, v_pca, v_kind, v_adopted
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

  -- NO hay promoción para la cuenta que volvió a iCloud: eso es el RE-CUTOVER, diferido por diseño.

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
grant execute on function public.claim_account(text, text, boolean, text) to anon, authenticated, service_role;

do $verify$
declare v_m text;
begin
  select md5(prosrc) into v_m from pg_proc where oid = 'public.claim_account(text,text,boolean,text)'::regprocedure;
  if v_m <> '354237247d7c366596f1c2f43f78e802' then
    raise exception 'g31_01 rollback: md5 % distinto del de g16_04', v_m;
  end if;
  raise notice 'g31_01 rollback OK · claim_account vuelve a g16_04 (md5 %)', v_m;
end $verify$;
