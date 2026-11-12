-- =====================================================================================================
-- g30_01 · Grupos: la edición de un teléfono que no conoce el autor deja el autor de un gasto en «no se sabe»
--          (2026-11-03, card vx6f)
--
-- QUÉ GANA EL USUARIO. Desde g29_01 el aviso «Ana actualizó 'Cena'» nombra a quien editó el gasto, y lo saca de
-- `split_expenses.last_edited_by_member_key`. Los teléfonos con la app 2.2 mandan esa columna en cada edición del
-- formulario; todo iOS hasta 2.1 no la conoce y no la manda. Como el servidor resuelve cada unidad por separado (LWW por
-- `field_hlcs`), cuando Ana editaba desde un 2.1 el importe cambiaba y el autor se quedaba en el de ANTES: los demás
-- recibían «Jürgen actualizó 'Cena'» por una edición de Ana. Desde aquí, esa edición deja el autor en NULL y el aviso
-- cae al pagador, que es lo que se hacía antes de g29_01. Mejor no nombrar a nadie que nombrar al equivocado.
--
-- MEDIDO ANTES (Management API, 2026-11-03). `apply_group_delta` tiene el mismo md5(prosrc) en staging y producción
-- (ae78bce687ab00da0ae463e6525cc09c) y es el ÚNICO escritor de `split_expenses.field_hlcs`. Unidades guardadas en staging:
-- gmoney (amount + currency_code), expense_description, note, date, created_at, paid_by_member_key, split_type, is_settled,
-- is_opening_balance, subcategory_name y last_edited_by_member_key (producción, la misma lista sin esta última: aún
-- ninguna fila la tiene). Triggers BEFORE UPDATE previos en los dos entornos: cap_future_hlc, opening_balance_guard y
-- split_expenses_stamp. Un cliente estampa TODAS las unidades de un delta con el mismo HLC (`DeltaEmitter.emit`, un
-- `hlc` por delta), y el Worker no mira la versión en el push: un delta de 2.1 es uno sin la unidad del autor.
--
-- LA REGLA (`expense_author_from_v2_clients`, BEFORE UPDATE en `split_expenses`). El autor pasa a NULL cuando este UPDATE
-- AVANZA el HLC de alguna unidad del formulario (gmoney, expense_description, note, date, paid_by_member_key, split_type,
-- subcategory_name: las que en la 2.2 arrastran el autor, `GroupEntityEmissionMap.splitExpense.columnKeyPaths`) y ese
-- HLC nuevo es POSTERIOR al HLC guardado de la unidad `last_edited_by_member_key`. Dicho de otro modo: entró un cambio
-- del formulario más nuevo que la última vez que alguien dijo quién editó, y no dijo quién lo hizo.
--   · Una edición 2.2 trae la unidad del autor con el MISMO HLC que las del formulario: no es posterior, el autor queda.
--   · Una edición 2.1 trae el formulario sin el autor: su HLC supera al del autor guardado y lo anula.
--   · Se compara `field_hlcs`, no valores de columna, y «avanzar» es `>` estricto en orden de bytes (collate "C", el de
--     hlc01): una reescritura del servidor que no toque `field_hlcs` (`groups_forget_user`) o que lo BAJE (la
--     normalización de hlc01) no anula a nadie.
--
-- POR QUÉ «POSTERIOR AL AUTOR» Y NO «SIN AVANZAR EL AUTOR». Con la segunda, dos ediciones 2.2 concurrentes que llegan
-- desordenadas borraban un autor bueno: C edita la descripción en t7 (autor C, t7) y luego llega la edición de B del
-- importe en t5 (autor B, t5). El importe avanza y la unidad del autor no, porque la de C es más nueva; el último editor
-- es C y el autor ya lo dice. Lo mismo con una edición 2.1 que llega tarde (t5) tras una 2.2 posterior (t7). La regla de
-- arriba da el mismo resultado que la otra en todo caso donde la otra acierta.
--
-- QUÉ NO JUZGA.
--   · INSERT: un alta 2.1 nace sin autor y una 2.2 con el suyo. El trigger es solo de UPDATE.
--   · Un borrado (NEW.deleted): `apply_group_delta` no toca `field_hlcs` al borrar, y el reenvío de un tombstone
--     tampoco. La resurrección (OLD borrado, NEW vivo) SÍ se juzga: es una edición.
--   · is_settled, is_opening_balance y created_at: no son el formulario de edición, y la 2.2 no les cuelga el autor.
--   · Filas cuyo autor ya quedó desfasado ANTES de esta migración (una edición 2.1 entre g29_01 y g30_01): un cambio
--     posterior que no es del formulario no las corrige. Las corrige la siguiente edición del formulario.
--
-- QUÉ NO TOCA. Ninguna política, tabla, columna, RPC ni fila existente. `apply_group_delta` no cambia: el trigger
-- reescribe NEW antes de guardar, después de que el RPC decida qué unidades ganan. Se dispara después de
-- `cap_future_hlc` (orden alfabético de Postgres), así que compara los HLC ya acotados; las unidades de un delta se
-- acotan igual, así que el orden no cambia el resultado.
--
-- ORDEN DE DESPLIEGUE. Ninguno: ni el Worker ni la app cambian. Con NULL, la app 2.2 ya cae al pagador (g29_01: «con la
-- key presente manda el servidor también con NULL»).
--
-- IDEMPOTENTE: `create or replace` + `drop trigger if exists`. Marcha atrás: `g30_01_rollback.sql`.
-- BANCO LOCAL: `bash qa/cloud/g30_01-local-test.sh` (Postgres 17 desechable con el DDL real; casos, control y mutantes).
-- SONDA: `qa/cloud/g30_01-staging-probe.sh` (por el Worker de staging). Remoto: `qa/cloud/g30_01-remote.sh`.
-- =====================================================================================================

create or replace function public.expense_author_from_v2_clients() returns trigger
language plpgsql security invoker set search_path = public, pg_temp as $$
declare
  -- Las unidades del formulario de edición (gmoney = amount + currency_code).
  c_form_units constant text[] := array['gmoney', 'expense_description', 'note', 'date', 'paid_by_member_key',
                                        'split_type', 'subcategory_name'];
  v_old_fh jsonb := coalesce(old.field_hlcs, '{}'::jsonb);
  v_new_fh jsonb := coalesce(new.field_hlcs, '{}'::jsonb);
  v_author text;  -- HLC guardado de la unidad del autor ('' si no la tiene: fila anterior a g29_01)
begin
  -- 0. Un borrado no se juzga.
  if new.deleted then
    return new;
  end if;

  -- 1. Nada que anular, o nada que haya avanzado.
  if new.last_edited_by_member_key is null or v_new_fh = v_old_fh then
    return new;
  end if;

  -- 2. Un cambio del formulario que avanza y es posterior al autor guardado → el autor ya no es de esta edición.
  v_author := coalesce(v_new_fh ->> 'last_edited_by_member_key', '');
  if exists (select 1 from unnest(c_form_units) u
              where coalesce(v_new_fh ->> u, '') collate "C" > coalesce(v_old_fh ->> u, '') collate "C"
                and coalesce(v_new_fh ->> u, '') collate "C" > v_author collate "C") then
    new.last_edited_by_member_key := null;
  end if;

  return new;
end;
$$;

revoke all on function public.expense_author_from_v2_clients() from public, anon, authenticated;

drop trigger if exists expense_author_from_v2_clients on public.split_expenses;
create trigger expense_author_from_v2_clients before update on public.split_expenses
  for each row execute function public.expense_author_from_v2_clients();

-- Comprobaciones: aborta la transacción entera si algo no es lo esperado.
do $$
begin
  if (select count(*) from pg_trigger where tgname = 'expense_author_from_v2_clients'
        and tgrelid = 'public.split_expenses'::regclass and not tgisinternal) <> 1 then
    raise exception 'g30_01: el trigger expense_author_from_v2_clients no quedó puesto (o hay más de uno)';
  end if;
  if has_function_privilege('authenticated', 'public.expense_author_from_v2_clients()', 'EXECUTE') then
    raise exception 'g30_01: authenticated puede ejecutar la función del trigger';
  end if;
  raise notice 'g30_01 OK';
end;
$$;
