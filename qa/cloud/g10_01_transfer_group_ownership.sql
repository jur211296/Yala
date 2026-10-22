-- g10_01_transfer_group_ownership (2026-07-20, D10 — batch "salir de todos mis grupos"):
-- transfer_group_ownership(p_group_id) transfiere el ownership de UN grupo backend al co-member elegible
-- más antiguo (admin primero, luego joined_at asc, tie-break member_key asc) y NADA MÁS. El caller (el
-- orquestador batch) luego llama leave_group — que ya pasa el guard yala_owner_cannot_leave porque
-- owner_user_id ya no es él.
--
-- === Diferencia vs groups_forget_user (g7_02) ===
--   Copia VERBATIM el patrón de heredero de groups_forget_user loop1 (g7_02:311-315), PERO:
--     - opera sobre UN solo grupo (where group_id = p_group_id), no itera todos los owned;
--     - NO anonimiza al caller (sin loop2), NO borra push_tokens;
--     - **JAMÁS tombstonea** cuando no hay heredero (invariante D10: nunca destruir datos de terceros) →
--       devuelve {transferred:false, reason:'no_eligible_owner'} y el cliente decide (lista "necesitan tu
--       decisión"). groups_forget_user SÍ tombstonea porque ahí la cuenta muere entera (GDPR).
--   Los placeholders user_id NULL (legacy migrado sin reclamar) NUNCA son herederos: no hay auth.user al
--   que ceder el ownership (split_groups.owner_user_id es uuid → auth.users). Ese es exactamente el motivo
--   por el que el batch NO migra grupos CloudKit-legacy (decisión owner A1, 2026-07-20).
--
-- === IDEMPOTENTE-SUAVE (retry-transient SEGURO ⇒ NO va a neverRetryTransient del cliente) ===
--   Grupo inexistente / deleted / owner_user_id IS DISTINCT FROM caller (ya transferido, o nunca fui owner,
--   o huérfano NULL por on-delete-set-null) → {already:true} SIN tocar nada. Escenario del retry: transfiero
--   (COMMIT), se pierde la respuesta (502), reintento → 2º call lee owner=heredero → is distinct from v_uid
--   → already:true. Una vez commiteado el 1er intento, ningún reintento re-transfiere a un heredero distinto.
--
-- === search_path = public (SIN extensions) ===
--   NO escribe columnas † (owner_user_id/role/hlc/field_hlcs no son bytea) → no llama pgcrypto → el gateway
--   NO inyecta p_key (transfer_group_ownership NO está en RPC_NEEDS_ENC_KEY).
--
-- Sanitización de errores: constantes yala_* (errcode P0001), JAMÁS interpolan inputs (molde de los RPCs de
-- grupos). server_seq lo pone SIEMPRE el trigger stamp_group_seq — el RPC NO lo setea. Grants: REVOKE
-- public/anon + GRANT authenticated (molde supabase-groups-staging.ddl:806-827).

create or replace function public.transfer_group_ownership(p_group_id text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := (select auth.uid());
  v_hlc   text;
  v_owner uuid;
  v_found boolean;
  v_cand  record;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  -- group_id shape (molde migrate_group): garbage permanente → yala_invalid_group_id (NO reintentable).
  if p_group_id is null or length(p_group_id) < 8 or length(p_group_id) > 120 then
    raise exception 'yala_invalid_group_id' using errcode = 'P0001';
  end if;

  -- ¿Soy owner de un grupo VIVO? No-existe / deleted / otro owner / owner NULL huérfano → already:true.
  select owner_user_id into v_owner from split_groups
    where group_id = p_group_id and deleted = false;
  v_found := found;
  if not v_found or v_owner is distinct from v_uid then
    return jsonb_build_object('transferred', false, 'already', true,
                              'new_owner_member_key', null, 'reason', null, 'group_id', p_group_id);
  end if;

  -- Heredero: VERBATIM de groups_forget_user loop1 (admin primero, más antiguo, tie-break member_key).
  -- Placeholders user_id NULL (legacy sin reclamar) EXCLUIDOS: no hay auth.user al que ceder.
  select * into v_cand from group_members
    where group_id = p_group_id and deleted = false and status = 'active'
      and user_id is not null and user_id <> v_uid
    order by (coalesce(role, '') = 'admin') desc, joined_at asc, member_key asc
    limit 1;

  if v_cand.member_key is null then
    -- Sin heredero elegible: JAMÁS tombstonear (invariante D10). El cliente lo manda a "necesitan tu decisión".
    return jsonb_build_object('transferred', false, 'already', false,
                              'new_owner_member_key', null, 'reason', 'no_eligible_owner', 'group_id', p_group_id);
  end if;

  v_hlc := server_hlc();

  if v_cand.role is distinct from 'admin' then
    update group_members set
      role       = 'admin',
      hlc        = v_hlc,
      updated_at = now(),
      field_hlcs = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{membership}', to_jsonb(v_hlc))
      where group_id = p_group_id and member_key = v_cand.member_key;
  end if;

  update split_groups set
    owner_user_id = v_cand.user_id,
    hlc           = v_hlc,
    updated_at    = now(),
    field_hlcs    = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{meta}', to_jsonb(v_hlc))
    where group_id = p_group_id;

  return jsonb_build_object('transferred', true, 'already', false,
                            'new_owner_member_key', v_cand.member_key,
                            'new_owner_user_id', v_cand.user_id,
                            'reason', null, 'group_id', p_group_id);
end $$;

-- Grants de EXECUTE: revocar de public/anon, otorgar solo a authenticated (molde
-- supabase-groups-staging.ddl:806-827). SECURITY DEFINER corre como owner de la función.
revoke all on function public.transfer_group_ownership(text) from public, anon;
grant execute on function public.transfer_group_ownership(text) to authenticated;
