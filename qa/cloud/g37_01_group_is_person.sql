-- =====================================================================================================
-- g37_01 · Grupos: una persona es un grupo de dos que no se ve como grupo (`split_groups.is_person`)
--
-- QUÉ GANA EL USUARIO. Compartido (lote 1 de «Compartido: Grupos y Personas», 2.3) separa la pestaña en dos chips,
-- Grupos y Personas. Para apuntar gastos con una persona sin crear un grupo, la persona es por dentro un grupo de dos con
-- una marca: la app lo saca de la lista de Grupos y lo enseña como «Sin grupo» en la tarjeta de esa persona. La marca
-- tiene que viajar para que el otro teléfono de la misma cuenta, y la otra persona, vean lo mismo.
--
-- DECISIÓN. Jürgen aprobó el cambio de esquema el 2026-11-26 (propiedad local en el almacén de Grupos, columna
-- `split_groups.is_person` en el manifiesto de Grupos v4 y esta migración en STAGING; producción no se toca en este lote).
--
-- QUÉ ES. Una columna `boolean NOT NULL DEFAULT false`, en claro (no es un monto ni un texto del usuario: el modelo de
-- amenaza de G7 cifra montos y textos libres). NOT NULL con default y no NULLABLE, a propósito: toda fila que ya existe
-- nace en `false`, que es lo que el teléfono tiene en su modelo (`SplitGroup.isPerson = false`). Con NULLABLE, el Merkle
-- del servidor diría `null` y el del teléfono `false` en cada grupo de antes, y divergirían todos (la trampa de la v5 del
-- canal personal, `.claude/rules/swiftdata-cloudkit.md`).
--
-- === QUÉ TOCA Y QUÉ NO ===
--   · `apply_group_delta` NO cambia: las columnas en claro entran por `jsonb_populate_record` (v_plain_fields) y esta no
--     va en la lista † (como g29_01).
--   · El UPDATE de `authenticated` en split_groups es POR COLUMNA (hallazgo #1 de G1) y NO se hereda: sin el grant, el
--     push de la meta daría 42501 y se rechazaría el delta ENTERO. La policy `split_groups_update` sigue exigiendo
--     `is_group_admin`: marcar es de quien crea la persona.
--   · El reader del pull devuelve columnas explícitas: la nueva va AL FINAL (el gateway lee por nombre). Cambiar el
--     RETURNS TABLE exige DROP + CREATE, y el DROP se lleva el EXECUTE: se re-otorga aquí, en la misma transacción.
--   · `create_group` no cambia: la marca llega con el primer push de la meta. Crear la persona ya marcada es del lote 3.
--
-- === EL ORDEN DE DESPLIEGUE ===
--   1. Esta migración (staging; producción, cuando Jürgen lo decida).
--   2. El Worker con `group_capability_manifest.json` v4 (`is_person` con `since: 4`).
--   3. La app. Declara la versión que el Worker ANUNCIA (`GroupsSyncCapability`): contra un Worker v3 no emite ni hashea
--      la columna, y la 2.2 (v3) tampoco la ve: le llega la persona como un grupo más, sin perder datos.
--   Un Worker v3 con esta migración aplicada ignora la columna extra del reader (lee por nombre): orden 1 → 2 sin hueco.
--
-- === IDEMPOTENTE === `add column if not exists`; el reader se recrea entero. Con el reader en una versión que no es la
-- medida (md5 de prosrc, staging, 2026-11-26: dff883b4…) y sin la columna, aborta entera (§1). Con la columna ya creada
-- con otro tipo, también (§4).
--
-- Marcha atrás: `g37_01_rollback.sql`.
-- =====================================================================================================

begin;

set local lock_timeout = '5s';

-- §1 · el reader tiene que estar en la versión medida. Una segunda pasada lo encuentra recreado y la columna ya creada:
-- se acepta (idempotente).
do $$
declare
  v_md5 text;
begin
  select md5(prosrc) into v_md5 from pg_proc
   where oid = 'public.groups_pull_rows_split_groups(text, bigint, int, text)'::regprocedure;
  if v_md5 is distinct from 'dff883b4f733956f3a29d631440a7757'
     and not exists (select 1 from information_schema.columns where table_schema = 'public'
                      and table_name = 'split_groups' and column_name = 'is_person') then
    raise exception 'g37_01 ABORTA: groups_pull_rows_split_groups no está en la versión medida (md5 %)', v_md5;
  end if;
end;
$$;

-- §2 · la columna y su grant de UPDATE (por columna, no se hereda)
alter table public.split_groups add column if not exists is_person boolean not null default false;
grant update (is_person) on public.split_groups to authenticated;

comment on column public.split_groups.is_person is
  'Grupos: el grupo es una persona (grupo de dos que no se lista como grupo; SplitGroup.isPerson). g37_01, 2026-11-26.';

-- §3 · reader del pull con la columna nueva AL FINAL
drop function if exists public.groups_pull_rows_split_groups(text, bigint, int, text);
create function public.groups_pull_rows_split_groups(
  p_group_id text, p_after_seq bigint, p_limit int, p_key text
) returns table(
  group_id text, name text, icon_name text, color_hex text, currency_code text,
  simplify_debts boolean, show_debts_in_single_currency boolean, members_can_invite boolean,
  default_split_type text, is_archived boolean, is_hidden_for_all boolean, owner_user_id uuid,
  created_at timestamptz, field_hlcs jsonb, hlc text, deleted boolean, deleted_hlc text,
  server_seq bigint, schema_version integer, updated_at timestamptz,
  budget_limit_amount text,
  is_person boolean
) language sql security invoker stable set search_path = public, extensions as $$
  select
    t.group_id, public.yala_try_decrypt(t.name, p_key), t.icon_name, t.color_hex, t.currency_code,
    t.simplify_debts, t.show_debts_in_single_currency, t.members_can_invite,
    t.default_split_type, t.is_archived, t.is_hidden_for_all, t.owner_user_id,
    t.created_at, t.field_hlcs, t.hlc, t.deleted, t.deleted_hlc,
    t.server_seq, t.schema_version, t.updated_at,
    public.yala_try_decrypt(t.budget_limit_amount, p_key),
    t.is_person
  from public.split_groups t
  where t.group_id = p_group_id and t.server_seq > p_after_seq
  order by t.server_seq asc
  limit p_limit
$$;

revoke all on function public.groups_pull_rows_split_groups(text, bigint, int, text) from public, anon;
grant execute on function public.groups_pull_rows_split_groups(text, bigint, int, text) to authenticated;

-- §4 · comprobaciones: aborta la transacción entera si algo no es lo esperado
do $$
begin
  if (select data_type || '/' || is_nullable || '/' || coalesce(column_default, '')
        from information_schema.columns
       where table_schema = 'public' and table_name = 'split_groups' and column_name = 'is_person')
     is distinct from 'boolean/NO/false' then
    raise exception 'g37_01: split_groups.is_person no es boolean NOT NULL DEFAULT false';
  end if;
  if exists (select 1 from public.split_groups where is_person) then
    raise exception 'g37_01: hay grupos marcados como persona justo después de crear la columna';
  end if;
  if not has_column_privilege('authenticated', 'public.split_groups', 'is_person', 'SELECT')
     or not has_column_privilege('authenticated', 'public.split_groups', 'is_person', 'UPDATE') then
    raise exception 'g37_01: authenticated sin SELECT/UPDATE en split_groups.is_person';
  end if;
  if pg_get_function_result('public.groups_pull_rows_split_groups(text, bigint, int, text)'::regprocedure)
       not like '%budget_limit_amount text, is_person boolean)' then
    raise exception 'g37_01: el reader de split_groups no devuelve is_person al final';
  end if;
  if not has_function_privilege('authenticated', 'public.groups_pull_rows_split_groups(text, bigint, int, text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.groups_pull_rows_split_groups(text, bigint, int, text)', 'EXECUTE') then
    raise exception 'g37_01: EXECUTE del reader mal otorgado';
  end if;
  raise notice 'g37_01 OK';
end;
$$;

commit;
