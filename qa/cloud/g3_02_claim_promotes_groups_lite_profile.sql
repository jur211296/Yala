-- g3_02_claim_promotes_groups_lite_profile (2026-07-15, decisión owner en sesión):
-- El claim LIGERO de grupos (create_group/join_group → insert profiles(id) on conflict do nothing, G1)
-- crea filas de identidad SIN vida personal (provider NULL, migrated_at NULL, mip false). El
-- claim_account actual clasifica esa fila como 'existing_stable' → un usuario solo-grupos que luego
-- activa Yala completo y elige nube queda SIN CAMINO de migración (el cliente enruta a adopt/secundaria
-- en vez de sembrar/migrar). Decisión owner (Opción A): señal `personal_claimed_at` + PROMOCIÓN — para
-- lo PERSONAL, la cuenta nace cuando claim_account la reclama por primera vez → devuelve 'created'
-- (cero cambios de cliente ni de wire; la máquina §g y FullModeActivation funcionan tal cual).
-- Los RPCs de grupos NO se tocan (su insert ligero deja personal_claimed_at NULL por default).

-- 1. Columna + backfill ONE-SHOT (JAMÁS re-aplicar este archivo: un re-run marcaría como reclamada
--    una fila ligera creada después, bloqueando su promoción): todo lo preexistente se considera reclamado (las filas ligeras de grupos
--    creadas por los goldens G1-G3 sobre i5-user-a/b pertenecen a cuentas TAMBIÉN claimeadas por los
--    goldens de account — el coalesce con created_at cubre cualquier fila sin migrated_at).
alter table public.profiles add column if not exists personal_claimed_at timestamptz;
update public.profiles set personal_claimed_at = coalesce(migrated_at, created_at)
  where personal_claimed_at is null;

-- 2. claim_account: el INSERT estampa personal_claimed_at; la rama fila-existente gana la PROMOCIÓN
--    TOCTOU-safe (WHERE personal_claimed_at IS NULL — dos claims concurrentes: el perdedor re-clasifica).
create or replace function public.claim_account(p_device_id text, p_provider text, p_migration boolean default false)
returns jsonb
language plpgsql
set search_path = public
as $function$
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
begin
  if v_uid is null then
    raise exception 'claim_account: no auth.uid() (SECURITY INVOKER requires a user JWT)'
      using errcode = '28000';
  end if;

  -- Atomic reservation. p_migration=true arms the leader lease IN THE SAME INSERT (no kill window
  -- between the created row and a separate begin): migration_in_progress + heartbeat set atomically.
  -- Default false preserves the born-cloud contract and every existing 2-arg caller.
  insert into public.profiles (id, provider, leader_device_id, migration_in_progress, migration_updated_at, personal_claimed_at)
  values (
    v_uid, p_provider, p_device_id,
    p_migration,
    case when p_migration then now() else null end,
    now()
  )
  on conflict (id) do nothing
  returning id into v_created;

  if v_created is not null then
    return jsonb_build_object('state', 'created');
  end if;

  -- Row already existed: classify its state (RLS restricts the SELECT to the caller's own row).
  select migration_in_progress, leader_device_id, migrated_at, reverse_in_progress, provider, migration_updated_at, personal_claimed_at
    into v_mip, v_leader, v_migrated, v_reverse, v_provider, v_updated, v_pca
    from public.profiles where id = v_uid;

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
          migration_updated_at  = case when p_migration then now() else null end
      where id = v_uid and personal_claimed_at is null;
    if found then
      return jsonb_build_object('state', 'created');
    end if;
    -- Carrera: otro claim promocionó entre el SELECT y el UPDATE → re-leer y clasificar normal.
    select migration_in_progress, leader_device_id, migrated_at, reverse_in_progress, provider, migration_updated_at
      into v_mip, v_leader, v_migrated, v_reverse, v_provider, v_updated
      from public.profiles where id = v_uid;
  end if;

  if v_mip and v_leader is distinct from p_device_id then
    -- Lease expiry (§g.1): a leader silent for >60 min can be TAKEN OVER — but ONLY by another
    -- MIGRATION caller (p_migration=true). A born-cloud/returning-user caller must NEVER usurp a
    -- half-migrated account (SERIO 2 of the adversarial review): it gets claiming_in_progress and
    -- routes to wait/adopt, never seeds. A NULL heartbeat (legacy row) never expires.
    if p_migration and v_updated is not null and v_updated < now() - interval '60 minutes' then
      update public.profiles
        set leader_device_id = p_device_id, migration_updated_at = now()
        where id = v_uid;
      return jsonb_build_object('state', 'created');  -- takeover: this device now leads
    end if;
    return jsonb_build_object('state', 'claiming_in_progress');
  elsif v_mip and v_leader = p_device_id then
    return jsonb_build_object('state', 'created');  -- idempotent reclaim by the same leader
  else
    return jsonb_build_object(
      'state', 'existing_stable',
      'profile', jsonb_build_object(
        'migrated_at', v_migrated,
        'migration_in_progress', v_mip,
        'reverse_in_progress', v_reverse,
        'provider', v_provider
      )
    );
  end if;
end;
$function$;
