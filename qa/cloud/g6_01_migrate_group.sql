-- g6_01_migrate_group (2026-07-16, incremento G6-1 — migración de grupos VIVOS de CloudKit al backend):
-- `migrate_group(p_group_id, p_meta, p_members)` crea, en UNA transacción atómica, el `split_groups` con su
-- META HISTÓRICA (created_at del payload, NO now()) + los N `group_members` migrados TAL CUAL (member_key
-- legacy, status/role/joined_at históricos). Cierra el diseño §9 (D7: el OWNER migra el grupo entero y luego
-- RE-INVITA a los demás members; el rebind por `legacy_member_key` de `join_group` — DDL L442-461 — reclama
-- las filas placeholder `user_id NULL` cuando cada member se une con su token).
--
-- === Decisiones owner referenciadas (2026-07-16) ===
--   - R10 (namespaces CloudKit↔backend en grupos migrados): las FKs del historial de grupos apuntan a
--     `SplitMember.id.uuidString` (determinista por `(groupID, member_key)`), NO a `cloudKitUserRecordID`.
--     Este RPC PRESERVA el `member_key` legacy (recordName CloudKit-era) verbatim → el historial subido por
--     `/groups/push` (columnas `*_member_key`) sigue resolviendo byte-idéntico tras la migración. El
--     transporte de la ID se cierra server-side sin re-mapear: el member_key ES la ancla estable.
--   - Token-en-marcador: la reclamación de las filas placeholder (`user_id NULL`) solo ocurre vía
--     `join_group(token, legacy_member_key)` — exige un TOKEN de invitación del propio grupo (creado por el
--     owner tras migrar). Sin token no hay reclamo → los placeholders no son secuestrables sin invitación.
--
-- === Por qué un RPC NUEVO y no extender create_group ===
--   `create_group` fuerza el owner con `member_key = sub` (rompería las FKs del historial del PROPIO owner,
--   que apuntan al id derivado de su recordName LEGACY) y estampa `created_at/joined_at = now()` (perdería la
--   fecha histórica). `migrate_group` estampa el `member_key` legacy del owner y las fechas del payload.
--   Los RPCs existentes (`create_group`/`join_group`) quedan INTACTOS.
--
-- === Contrato de p_meta / p_members ===
--   p_meta:  name, currency_code, icon_name, color_hex, default_split_type, simplify_debts,
--            show_debts_in_single_currency, members_can_invite, created_at (histórico).
--   p_members: array de {member_key, display_name, role, status, joined_at, is_owner}. Validaciones:
--            array no vacío · EXACTAMENTE 1 con is_owner=true · member_key no vacío · member_key SIN
--            DUPLICADOS en el payload · role ∈ {admin,member} · status ∈ {active,pendingApproval,left,
--            removed} (los históricos migran tal cual) · btrim(display_name) no vacío.
--            El owner (is_owner=true) recibe `user_id = v_uid` (el caller); el resto `user_id NULL`
--            (placeholders reclamables por rebind legacy).
--   DOCUMENTACIÓN (no se valida server-side): el OWNER migrado DEBE traer su member_key LEGACY (recordName),
--   NO su sub — si migrara con sub, su propio historial (FKs a la id derivada del recordName) quedaría
--   HUÉRFANO. El cliente es SSOT de esta correspondencia.
--
-- === Validación de member_key duplicado (CRÍTICO del review-plan) ===
--   Un member_key duplicado en el payload dispararía el PK `(group_id, member_key)` → `unique_violation`
--   CRUDA → el gateway la colapsa a 502 `yala_unavailable` ("transitorio") → el uploader one-shot
--   REINTENTARÍA PARA SIEMPRE un payload que JAMÁS aplicará. ⇒ se valida ANTES (count vs count distinct) →
--   `yala_bad_input` (permanente, el uploader no reintenta). ADEMÁS un cinturón `exception when
--   unique_violation → yala_bad_input` (molde create_group) por si un dup esquivara la validación.
--
-- === IDEMPOTENTE-SUAVE (el uploader one-shot reintenta tras timeout) ===
--   Si `split_groups` ya existe con `owner_user_id = v_uid` → return `{already:true, group_id,
--   owner_user_id, server_seq}` SIN tocar nada (los 2 campos extra = sanity-check barato para el resume del
--   uploader). La atomicidad de plpgsql (una tx) garantiza "grupo existe ⇒ members existen" — sin estado
--   parcial. **La rama `already` IGNORA el `p_members` del reintento**: gana el 1er intento, sin
--   reconciliación de DRIFT (el uploader es determinista — reenvía el MISMO payload; un p_members distinto
--   sería un bug del cliente, no un caso a reconciliar). Si existe con OTRO owner → `yala_group_exists`
--   (distinto de `create_group` INTERACTIVO, que rechaza TODO duplicado).
--
-- === Riesgo ACEPTADO de squat de group_id (DoS insider-only) ===
--   Un member del grupo (que conoce el `group_id` = zoneID de 128 bits) podría llamar `migrate_group` con
--   ese group_id ANTES que el owner legítimo, estampándose como owner_user_id. Aceptado: (a) exige conocer
--   el zoneID de 128 bits, visible SOLO para members del grupo (sin exfiltración, sin takeover de cuentas);
--   (b) los placeholders `user_id NULL` solo se reclaman con un TOKEN del propio caller (join_group);
--   (c) no hay escalada de privilegios fuera de ese grupo. El blast-radius es 1 grupo entre insiders.
--
-- Sanitización de errores: constantes `yala_*` (errcode P0001), JAMÁS interpolan inputs (molde de los RPCs
-- de grupos). Grants: REVOKE public/anon + GRANT authenticated (molde supabase-groups-staging.ddl:806-827).
-- server_seq lo pone SIEMPRE el trigger `stamp_group_seq` — el RPC NO lo setea.

create or replace function public.migrate_group(
  p_group_id text,
  p_meta jsonb,
  p_members jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid       uuid := (select auth.uid());
  v_hlc       text;
  v_existing  record;
  v_owners    integer;
  v_total     integer;
  v_distinct  integer;
  v_name      text;
  v_currency  text;
  v_member    jsonb;
  v_mkey      text;
  v_role      text;
  v_status    text;
  v_display   text;
  v_is_owner  boolean;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  -- group_id shape (molde create_group).
  if p_group_id is null or length(p_group_id) < 8 or length(p_group_id) > 120 then
    raise exception 'yala_invalid_group_id' using errcode = 'P0001';
  end if;

  -- IDEMPOTENTE-SUAVE: el grupo ya existe. Con ESTE owner → already:true (ignora p_members del reintento).
  -- Con OTRO owner → yala_group_exists. Un owner_user_id NULL (fila huérfana on-delete-set-null) NO matchea
  -- v_uid → cae a yala_group_exists (conservador: nadie re-migra un grupo huérfano).
  select owner_user_id, server_seq into v_existing
    from split_groups where group_id = p_group_id;
  if found then
    if v_existing.owner_user_id = v_uid then
      return jsonb_build_object('already', true, 'group_id', p_group_id,
                                'owner_user_id', v_existing.owner_user_id, 'server_seq', v_existing.server_seq);
    else
      raise exception 'yala_group_exists' using errcode = 'P0001';
    end if;
  end if;

  -- Validación de meta (name/currency; el resto es contenido opcional — el cliente es SSOT de divisas).
  v_name     := btrim(coalesce(p_meta->>'name', ''));
  v_currency := coalesce(p_meta->>'currency_code', '');
  if v_name = '' or length(v_name) > 120 or length(v_currency) <> 3 then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  -- p_members: array no vacío, EXACTAMENTE 1 owner, member_key SIN duplicados.
  if p_members is null or jsonb_typeof(p_members) <> 'array' or jsonb_array_length(p_members) = 0 then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;
  select count(*) filter (where coalesce((e->>'is_owner')::boolean, false)) into v_owners
    from jsonb_array_elements(p_members) e;
  if v_owners <> 1 then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;
  select count(*), count(distinct e->>'member_key') into v_total, v_distinct
    from jsonb_array_elements(p_members) e;
  if v_total <> v_distinct then
    -- member_key duplicado → yala_bad_input (evita el unique_violation crudo → 502 → retry-loop eterno).
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  v_hlc := server_hlc();

  -- Claim LIGERO del caller (molde create_group; profiles solo tiene `id` NOT NULL sin default).
  insert into profiles (id) values (v_uid) on conflict (id) do nothing;

  -- split_groups con META HISTÓRICA (created_at del payload) + owner_user_id = caller + field_hlcs por unidad.
  begin
    insert into split_groups (
      group_id, name, icon_name, color_hex, currency_code,
      simplify_debts, show_debts_in_single_currency, members_can_invite,
      default_split_type, is_archived, is_hidden_for_all, owner_user_id,
      created_at, field_hlcs, hlc, deleted, schema_version
    ) values (
      p_group_id, v_name, p_meta->>'icon_name', p_meta->>'color_hex', v_currency,
      coalesce((p_meta->>'simplify_debts')::boolean, false),
      coalesce((p_meta->>'show_debts_in_single_currency')::boolean, false),
      coalesce((p_meta->>'members_can_invite')::boolean, false),
      p_meta->>'default_split_type', false, false, v_uid,
      coalesce((p_meta->>'created_at')::timestamptz, now()),
      jsonb_build_object('meta', v_hlc), v_hlc, false, 1
    );
  exception when unique_violation then
    -- TOCTOU: dos migrate concurrentes con el mismo group_id esquivan el fast-path → PK → yala_group_exists.
    raise exception 'yala_group_exists' using errcode = 'P0001';
  end;

  -- N members. Owner → user_id = v_uid; resto → user_id NULL (placeholders reclamables por rebind legacy).
  for v_member in select value from jsonb_array_elements(p_members)
  loop
    v_mkey     := btrim(coalesce(v_member->>'member_key', ''));
    v_role     := coalesce(v_member->>'role', '');
    v_status   := coalesce(v_member->>'status', '');
    v_display  := btrim(coalesce(v_member->>'display_name', ''));
    v_is_owner := coalesce((v_member->>'is_owner')::boolean, false);
    if v_mkey = '' or v_display = '' or length(v_display) > 80
       or v_role not in ('admin', 'member')
       or v_status not in ('active', 'pendingApproval', 'left', 'removed') then
      raise exception 'yala_bad_input' using errcode = 'P0001';
    end if;
    insert into group_members (
      group_id, member_key, user_id, display_name, role, status,
      joined_at, field_hlcs, hlc, deleted, schema_version
    ) values (
      p_group_id, v_mkey,
      case when v_is_owner then v_uid else null end,
      v_display, v_role, v_status,
      coalesce((v_member->>'joined_at')::timestamptz, now()),
      jsonb_build_object('profile', v_hlc, 'membership', v_hlc), v_hlc, false, 1
    );
  end loop;

  return jsonb_build_object('already', false, 'group_id', p_group_id, 'owner_user_id', v_uid);

exception
  -- Cinturón (molde create_group): un member_key dup que esquivara la validación → yala_bad_input (permanente).
  when unique_violation then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  -- Fix P2 (review adversarial PRE-aplicación): un cast malformado del jsonb (created_at/joined_at no
  -- ISO → 22007/22008; boolean no-bool → 22P02) escaparía CRUDO → el gateway lo colapsa a 502
  -- yala_unavailable "transitorio" → el uploader reintentaría PARA SIEMPRE un payload que jamás
  -- aplicará. La misma invariante que el guard de dups: payload permanentemente-malo = error PERMANENTE.
  when invalid_datetime_format or datetime_field_overflow or invalid_text_representation then
    raise exception 'yala_bad_input' using errcode = 'P0001';
end $$;

-- Grants de EXECUTE: revocar de public/anon, otorgar solo a authenticated (molde
-- supabase-groups-staging.ddl:806-827). SECURITY DEFINER corre como owner de la función.
revoke all on function public.migrate_group(text, jsonb, jsonb) from public, anon;
grant execute on function public.migrate_group(text, jsonb, jsonb) to authenticated;
