CREATE OR REPLACE FUNCTION public.migration_progress(p_device_id text, p_action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_uid       uuid := auth.uid();
  v_mip       boolean;
  v_leader    text;
  v_rip       boolean;
  v_kind      text;
  v_reverted  timestamptz;
  v_updated   timestamptz;
  v_expired   boolean;
begin
  if v_uid is null then
    raise exception 'migration_progress: no auth.uid() (SECURITY INVOKER requires a user JWT)'
      using errcode = '28000';
  end if;

  select migration_in_progress, leader_device_id, reverse_in_progress, kind, reverted_at, migration_updated_at
    into v_mip, v_leader, v_rip, v_kind, v_reverted, v_updated
    from public.profiles where id = v_uid;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'no_profile');
  end if;

  -- Lease expiry mirrors claim_account (§g.1): >60 min silent. A NULL heartbeat (legacy row)
  -- NEVER expires.
  v_expired := (v_updated is not null and v_updated < now() - interval '60 minutes');

  -- ============ REVERSE actions (I11-3, §h) ============
  -- Handled BEFORE the forward leader guard: reverse_claim must be able to take over an
  -- ABANDONED forward migration (leader crashed between cutover and complete — the real
  -- 2026-07-10 device failure mode) or an expired reverse lease; both are cases where
  -- leader_device_id != p_device_id.
  --
  -- CAS (asymmetry fix): every UPDATE in this branch is CONDITIONAL on the state read above,
  -- and re-checks FOUND. Two concurrent claimants both pass the read guards; only ONE update
  -- matches — the loser gets 'other_leader' instead of a transient dual-leader.
  if p_action = 'reverse_claim' then
    -- g15_02: la puerta la abre el TIPO DE CUENTA, no el haber migrado. Una cuenta nacida en la
    -- nube tiene lo personal en el backend igual que una migrada, y `kind` es quien contesta «¿lleva
    -- finanzas personales?» (ADR 2026-09-09 §11).
    --
    -- La segunda mitad NO es cosmética: `reverse_complete` degrada a `groups_only`, así que sin ella un
    -- SEGUNDO dispositivo de una cuenta que ya volvió a iCloud —el suyo sigue en modo nube, con el
    -- backend congelado y `/sync/push` en 409— no podía reclamar su propia vuelta, y el cliente no tiene
    -- desatascador para un rechazo: barra clavada en 15 % para siempre. `reverted_at` no nulo dice «esta
    -- cuenta YA volvió», y quien llega detrás tiene derecho a seguirla.
    if v_kind is distinct from 'complete' and v_reverted is null then
      return jsonb_build_object('ok', false, 'reason', 'not_complete');
    end if;
    if v_mip then
      -- Forward migration still holds the lease. VIGENTE -> reject; EXPIRED -> the reverse
      -- TAKES OVER (without this, a leader crashed between cutover and complete could never revert).
      if not v_expired then
        return jsonb_build_object('ok', false, 'reason', 'migration_in_progress');
      end if;
      update public.profiles
        set migration_in_progress = false,
            reverse_in_progress   = true,
            leader_device_id      = p_device_id,
            reverse_frozen_at     = null,
            reverted_at           = null,
            migration_updated_at  = now()
        where id = v_uid
          and migration_in_progress = true
          and migration_updated_at = v_updated;  -- CAS: only the EXACT abandoned lease we read
      if not found then
        return jsonb_build_object('ok', false, 'reason', 'other_leader');
      end if;
      return jsonb_build_object('ok', true);
    end if;
    if v_rip then
      if v_leader = p_device_id then
        -- Idempotent re-claim after a kill; NO lease-age check for the SAME leader.
        update public.profiles set migration_updated_at = now()
          where id = v_uid
            and leader_device_id = p_device_id
            and reverse_in_progress = true;  -- CAS: a concurrent usurp/abort kills the heartbeat
        if not found then
          return jsonb_build_object('ok', false, 'reason', 'other_leader');
        end if;
        return jsonb_build_object('ok', true);
      elsif v_expired then
        -- Usurp an abandoned reverse. New run: reset the freeze/reverted markers.
        update public.profiles
          set leader_device_id     = p_device_id,
              reverse_frozen_at    = null,
              reverted_at          = null,
              migration_updated_at = now()
          where id = v_uid
            and reverse_in_progress = true
            and migration_updated_at = v_updated;  -- CAS: only the EXACT abandoned lease we read
        if not found then
          return jsonb_build_object('ok', false, 'reason', 'other_leader');
        end if;
        return jsonb_build_object('ok', true);
      else
        return jsonb_build_object('ok', false, 'reason', 'other_leader');
      end if;
    end if;
    -- Fresh claim. Resets reverse_frozen_at/reverted_at from any PREVIOUS completed/aborted run
    -- (a 2nd reverse is the "migrated" variant, §h.6): this run has not frozen nor reverted yet.
    update public.profiles
      set reverse_in_progress  = true,
          leader_device_id     = p_device_id,
          reverse_frozen_at    = null,
          reverted_at          = null,
          migration_updated_at = now()
      where id = v_uid
        and reverse_in_progress = false
        and migration_in_progress = false;  -- CAS: a concurrent claimant already took the row
    if not found then
      return jsonb_build_object('ok', false, 'reason', 'other_leader');
    end if;
    return jsonb_build_object('ok', true);

  elsif p_action = 'reverse_freeze' then
    if not v_rip then
      return jsonb_build_object('ok', false, 'reason', 'not_in_progress');
    end if;
    -- Leader guard WITHOUT lease-age check: the lease exists ONLY so competitors can usurp;
    -- the SAME slow leader must always be able to continue.
    if v_leader is distinct from p_device_id then
      return jsonb_build_object('ok', false, 'reason', 'other_leader');
    end if;
    update public.profiles
      set reverse_frozen_at    = coalesce(reverse_frozen_at, now()),
          migration_updated_at = now()  -- heartbeat: every leader action refreshes the lease
      where id = v_uid;
    return jsonb_build_object('ok', true);

  elsif p_action = 'reverse_complete' then
    if not v_rip then
      -- Idempotent resume: rip already false + reverted_at set by a previous complete -> ok.
      if v_reverted is not null and v_leader is not distinct from p_device_id then
        return jsonb_build_object('ok', true);
      end if;
      return jsonb_build_object('ok', false, 'reason', 'not_in_progress');
    end if;
    if v_leader is distinct from p_device_id then
      return jsonb_build_object('ok', false, 'reason', 'other_leader');
    end if;
    -- migrated_at is NEVER touched: the frozen backend keeps marking "this account migrated once"
    -- (§h.4). reverted_at is the signal for the future re-cutover design (claim_account unchanged
    -- today — deferred, documented).
    -- g15_01: lo personal vuelve a iCloud, la cuenta queda de GRUPOS. Es la UNICA degradacion
    -- complete -> groups_only del sistema (ADR 2026-09-09 §11 + fila E de la matriz de escenarios).
    perform set_config('yala.kind_write', txid_current()::text, true);
    update public.profiles
      set reverse_in_progress  = false,
          reverted_at          = coalesce(reverted_at, now()),
          migration_updated_at = now(),
          kind                 = 'groups_only'
      where id = v_uid;
    perform set_config('yala.kind_write', '', true);
    return jsonb_build_object('ok', true);

  elsif p_action = 'reverse_abort' then
    if not v_rip then
      return jsonb_build_object('ok', true);  -- idempotent: nothing to abort
    end if;
    -- Leader OR expired lease: an emergency abort after a long crash must be able to pass.
    if v_leader is distinct from p_device_id and not v_expired then
      return jsonb_build_object('ok', false, 'reason', 'other_leader');
    end if;
    -- UN-freezes. reverted_at stays untouched (null in an aborted run: the reverse did not happen).
    update public.profiles
      set reverse_in_progress  = false,
          reverse_frozen_at    = null,
          migration_updated_at = now()
      where id = v_uid;
    return jsonb_build_object('ok', true);
  elsif p_action = 'heartbeat' then
    -- I14-pre: refresh ONLY the lease timestamp while a long step makes progress (snapshot upload,
    -- reverse drain), so the leader is not usurpable mid-work. Serves forward AND reverse via
    -- (mip OR rip). NO lease-age check for the leader (reverse_freeze idiom: the lease exists only
    -- so competitors can usurp; the same slow leader must always be able to beat). Touches nothing
    -- but migration_updated_at (never migrated_at / reverse_frozen_at / reverted_at).
    if not (v_mip or v_rip) then
      return jsonb_build_object('ok', false, 'reason', 'not_in_progress');
    end if;
    if v_leader is distinct from p_device_id then
      return jsonb_build_object('ok', false, 'reason', 'other_leader');
    end if;
    -- CAS: conditional UPDATE + FOUND re-check — a takeover committing between our read and this
    -- write must NOT get its fresh lease refreshed by the old leader's heartbeat.
    update public.profiles
      set migration_updated_at = now()
      where id = v_uid
        and leader_device_id = p_device_id
        and (migration_in_progress or reverse_in_progress);
    if not found then
      return jsonb_build_object('ok', false, 'reason', 'other_leader');
    end if;
    return jsonb_build_object('ok', true);
  end if;

  -- ============ FORWARD actions (unchanged from i10) ============
  -- Leader guard: only THIS device (the recorded leader) may advance. A usurped leader (lease taken
  -- over) sees a different leader_device_id here -> other_leader -> its runner cuts, converges to follower.
  if v_leader is distinct from p_device_id then
    return jsonb_build_object('ok', false, 'reason', 'other_leader');
  end if;

  if p_action = 'cutover' then
    if not v_mip then
      return jsonb_build_object('ok', false, 'reason', 'not_in_progress');
    end if;
    update public.profiles
      set migrated_at = coalesce(migrated_at, now()), migration_updated_at = now()
      where id = v_uid;
    return jsonb_build_object('ok', true);
  elsif p_action = 'complete' then
    -- Idempotent even after mip already flipped false (leader match suffices): a resumed 'complete'
    -- must not fail once the migration is marked done.
    update public.profiles
      set migration_in_progress = false, migration_updated_at = now()
      where id = v_uid;
    return jsonb_build_object('ok', true);
  else
    return jsonb_build_object('ok', false, 'reason', 'bad_action');
  end if;
end;
$function$
