-- hlc01-cap-test-seed.sql — filas «legacy» para `hlc01-cap-test.sh`: escritas ANTES de la migración, como las que un
-- teléfono adelantado pudo dejar en el backend. La migración tiene que acotarlas (normalización) y mover su
-- server_seq; la de control, dentro del margen, no se toca.

insert into auth.users (id) values
  ('aaaaaaaa-0000-0000-0000-000000000001'),   -- A: el teléfono adelantado
  ('bbbbbbbb-0000-0000-0000-000000000002');   -- B: el otro miembro / el otro dispositivo

-- Personal (tags): una con hlc + field_hlcs del futuro, otra con deleted_hlc del futuro, otra dentro del margen.
insert into public.tags (user_id, sync_id, name, field_hlcs, hlc, deleted, deleted_hlc) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'legacy-futuro',
   '{"name": "2027-03-01T00:00:00.000Z-0007-00000000000000aa", "color_hex": "2026-01-01T00:00:00.000Z-0000-00000000000000aa"}',
   '2027-03-01T00:00:00.000Z-0007-00000000000000aa', false, null),
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000002', 'legacy-borrado-futuro',
   '{}', '2026-01-01T00:00:00.000Z-0000-00000000000000aa', true, '2030-01-01T00:00:00.000Z-0001-00000000000000aa'),
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000003', 'legacy-dentro-del-margen',
   '{"name": "2026-01-01T00:00:00.000Z-0000-00000000000000aa"}',
   '2026-01-01T00:00:00.000Z-0000-00000000000000aa', false, null);

-- Personal (user_preferences): el `zz` que la sonda de staging dejó — un HLC mal formado que hoy gana a todo.
insert into public.user_preferences (user_id, key, value, hlc) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'zz_hlc_probe', 'B', 'zz');

-- Grupos: el grupo, sus dos miembros activos (A admin) y un gasto legacy sellado un año por delante.
insert into public.split_groups (group_id, field_hlcs, hlc, owner_user_id) values
  ('grupo-hlc01', '{}', '2026-01-01T00:00:00.000Z-0000-0000000000000000', 'aaaaaaaa-0000-0000-0000-000000000001');
insert into public.group_members (group_id, member_key, user_id, role, status, field_hlcs, hlc) values
  ('grupo-hlc01', 'mk-a', 'aaaaaaaa-0000-0000-0000-000000000001', 'admin',  'active', '{}', '2026-01-01T00:00:00.000Z-0000-0000000000000000'),
  ('grupo-hlc01', 'mk-b', 'bbbbbbbb-0000-0000-0000-000000000002', 'member', 'active', '{}', '2026-01-01T00:00:00.000Z-0000-0000000000000000');
insert into public.split_expenses (group_id, sync_id, currency_code, field_hlcs, hlc) values
  ('grupo-hlc01', '22222222-0000-0000-0000-000000000001', 'PEN',
   '{"currency_code": "2027-10-01T00:00:00.000Z-0003-00000000000000aa"}',
   '2027-10-01T00:00:00.000Z-0003-00000000000000aa');

-- Testigo de server_seq antes de la migración.
create table public.hlc01_seq_before as
  select 'tags' as t, sync_id::text as id, server_seq from public.tags
  union all select 'user_preferences', key, server_seq from public.user_preferences
  union all select 'split_expenses', sync_id::text, server_seq from public.split_expenses;
