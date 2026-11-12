-- g27_01 · batería de políticas de saldos iniciales — la MISMA en el banco local, en staging y en producción.
--
-- Todo va en UN bloque DO que termina SIEMPRE con `raise exception 'G27_RESULTS:<json>'`: la transacción entera se
-- deshace por construcción (usuarios, grupos, gastos, contadores de secuencia), y los resultados viajan en el mensaje
-- del error. No hay camino que haga commit. Por eso se puede correr contra producción.
--
-- Cada caso llama a `apply_group_delta` como lo llama el gateway (rol `authenticated`, el `sub` en los claims), o hace
-- el PATCH directo que haría PostgREST. Sin columnas cifradas (ni `gmoney` ni `amount`): la llave de grupos no hace
-- falta y no viaja; el candado no mira importes.
--
-- Resultado por caso: `applied`, `noop:<motivo>` o `err:<mensaje>`. Lo que se espera es un PREFIJO del obtenido.
-- Uso: banco local (`g27_01-local-test.sh`) o `bash qa/cloud/g27_01-remote.sh <staging|production> [--expect-before]`.

do $battery$
declare
  -- Personas (sintéticas; nacen y mueren en esta transacción).
  u_owner  uuid := '27270000-0000-4000-8000-000000000001';  -- dueño de G1, admin
  u_admin  uuid := '27270000-0000-4000-8000-000000000002';  -- admin que NO es dueño
  u_member uuid := '27270000-0000-4000-8000-000000000003';  -- miembro normal
  u_ex     uuid := '27270000-0000-4000-8000-000000000004';  -- ex-miembro (era admin, `removed`)
  u_pend   uuid := '27270000-0000-4000-8000-000000000005';  -- admin pendiente de aprobar
  u_out    uuid := '27270000-0000-4000-8000-000000000006';  -- de fuera del grupo
  u_owner3 uuid := '27270000-0000-4000-8000-000000000007';  -- dueño de G3 con rol `member` (grupo migrado)
  u_c      uuid := '27270000-0000-4000-8000-000000000008';  -- miembro C (acreedor del saldo bloqueado)
  u_d      uuid := '27270000-0000-4000-8000-000000000009';  -- miembro D (deudor, con pago confirmado)
  u_z      uuid := '27270000-0000-4000-8000-000000000010';  -- miembro Z (recibe el pago de D)
  g1 text := 'SplitGroup-g27-open';
  g2 text := 'SplitGroup-g27-closed';
  g3 text := 'SplitGroup-g27-migrated';
  h0 text := '2026-01-01T00:00:00.000Z-0000-0000000000000000';
  fh jsonb := '{"profile":"2026-01-01T00:00:00.000Z-0000-0000000000000000","membership":"2026-01-01T00:00:00.000Z-0000-0000000000000000"}';
  -- Gastos y repartos.
  e_normal uuid := '27270000-0000-4000-8000-0000000000e0';
  e1  uuid := '27270000-0000-4000-8000-0000000000e1';  -- saldo A→owner, editable
  s1  uuid := '27270000-0000-4000-8000-0000000000a1';
  e2  uuid := '27270000-0000-4000-8000-0000000000e2';  -- saldo C←D, bloqueado por el pago D→Z
  s2  uuid := '27270000-0000-4000-8000-0000000000a2';
  e3  uuid := '27270000-0000-4000-8000-0000000000e3';  -- saldo nuevo con D de acreedor (se crea aunque D esté saldado)
  s3  uuid := '27270000-0000-4000-8000-0000000000a3';
  e4  uuid := '27270000-0000-4000-8000-0000000000e4';  -- saldo de Z con pago NO confirmado y uno confirmado BORRADO
  s4  uuid := '27270000-0000-4000-8000-0000000000a4';
  e5  uuid := '27270000-0000-4000-8000-0000000000e5';  -- saldo en G3
  e6  uuid := '27270000-0000-4000-8000-0000000000e6';  -- saldo en G2 (cerrado)
  e7  uuid := '27270000-0000-4000-8000-0000000000e7';  -- saldo admin←owner que se mueve hacia Z (saldado)
  s7  uuid := '27270000-0000-4000-8000-0000000000a7';
  e8  uuid := '27270000-0000-4000-8000-0000000000e8';  -- saldo de Z (bloqueado por su acreedor) con un reparto de owner
  s8  uuid := '27270000-0000-4000-8000-0000000000a8';
  e_ghost uuid := '27270000-0000-4000-8000-0000000000ff';  -- gasto que aún no llegó
  res jsonb := '[]'::jsonb;
  got text;
  orig_role text := current_setting('role');
begin
  -- ====================================================================================== siembra (como dueño de BD)
  insert into auth.users (id) values (u_owner), (u_admin), (u_member), (u_ex), (u_pend), (u_out), (u_owner3),
                                     (u_c), (u_d), (u_z);
  insert into public.split_groups (group_id, owner_user_id, deleted, hlc, field_hlcs) values
    (g1, u_owner, false, h0, fh), (g2, u_admin, true, h0, fh), (g3, u_owner3, false, h0, fh);
  insert into public.group_members (group_id, member_key, user_id, role, status, deleted, hlc, field_hlcs) values
    (g1, u_owner::text,  u_owner,  'admin',  'active',          false, h0, fh),
    (g1, u_admin::text,  u_admin,  'admin',  'active',          false, h0, fh),
    (g1, u_member::text, u_member, 'member', 'active',          false, h0, fh),
    (g1, u_ex::text,     u_ex,     'admin',  'removed',         false, h0, fh),
    (g1, u_pend::text,   u_pend,   'admin',  'pendingApproval', false, h0, fh),
    (g1, u_c::text,      u_c,      'member', 'active',          false, h0, fh),
    (g1, u_d::text,      u_d,      'member', 'active',          false, h0, fh),
    (g1, u_z::text,      u_z,      'member', 'active',          false, h0, fh),
    (g2, u_admin::text,  u_admin,  'admin',  'active',          false, h0, fh),
    (g3, u_owner3::text, u_owner3, 'member', 'active',          false, h0, fh),
    (g3, u_member::text, u_member, 'member', 'active',          false, h0, fh);
  -- Saldo E2 (C acreedor, D deudor), el saldo E4 (Z acreedor, C deudor) y los pagos: D→Z confirmado y vivo (bloquea
  -- todo lo que toque a D o a Z… salvo E4, ver abajo), C→owner sin confirmar, y C→owner confirmado pero BORRADO.
  insert into public.split_expenses (group_id, sync_id, paid_by_member_key, is_opening_balance, split_type, deleted, hlc, field_hlcs) values
    (g1, e2, u_c::text, true, 'exact', false, h0, '{}'),
    (g1, e4, u_c::text, true, 'exact', false, h0, '{}'),
    (g1, e7, u_admin::text, true, 'exact', false, h0, '{}'),
    (g1, e8, u_z::text, true, 'exact', false, h0, '{}');
  insert into public.split_shares (group_id, sync_id, expense_id, member_key, deleted, hlc, field_hlcs) values
    (g1, s2, e2, u_d::text, false, h0, '{}'),
    (g1, s4, e4, u_owner::text, false, h0, '{}'),
    (g1, s7, e7, u_owner::text, false, h0, '{}'),
    (g1, s8, e8, u_owner::text, false, h0, '{}');
  insert into public.split_settlements (group_id, sync_id, from_member_key, to_member_key, is_confirmed, deleted, hlc, field_hlcs) values
    (g1, gen_random_uuid(), u_d::text, u_z::text,     true,  false, h0, '{}'),
    (g1, gen_random_uuid(), u_c::text, u_admin::text, false, false, h0, '{}'),
    (g1, gen_random_uuid(), u_c::text, u_owner::text, true,  true,  h0, '{}');

  -- ====================================================================================== los casos
  -- Cada caso: (etiqueta, quién, SQL, esperado). El SQL corre con `role authenticated` y el `sub` de quién.
  declare
    c record;
  begin
    for c in
      select * from (values
        -- ---- dueño / admin / miembro: crear
        (1,  'miembro normal crea un saldo inicial → rechazado',                    u_member,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"opening":{"is_opening_balance":true,"paid_by_member_key":%s}}'::jsonb, '{"opening":"2026-02-01T00:00:01.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, e1, to_json(u_member::text)),
             'err:yala_opening_balance_not_admin'),
        (2,  'CONTROL miembro normal crea un gasto normal → aplicado',               u_member,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"base":{"is_opening_balance":false,"paid_by_member_key":%s}}'::jsonb, '{"base":"2026-02-01T00:00:02.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, e_normal, to_json(u_member::text)),
             'applied'),
        (3,  'admin (no dueño) crea un saldo inicial → aceptado',                    u_admin,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"opening":{"is_opening_balance":true,"paid_by_member_key":%s,"split_type":"exact"}}'::jsonb, '{"opening":"2026-02-01T00:00:03.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, e1, to_json(u_admin::text)),
             'applied'),
        (4,  'admin crea su primer reparto → aceptado',                              u_admin,
             format($q$select public.apply_group_delta('split_shares', %L, %L, 'upsert', '{"gshare":{"expense_id":%s,"member_key":%s}}'::jsonb, '{"gshare":"2026-02-01T00:00:04.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, s1, to_json(e1::text), to_json(u_owner::text)),
             'applied'),
        (5,  'dueño edita el saldo → aceptado',                                      u_owner,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"opening":{"is_opening_balance":true,"paid_by_member_key":%s,"split_type":"exact"}}'::jsonb, '{"opening":"2026-02-01T00:00:05.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, e1, to_json(u_admin::text)),
             'applied'),
        -- ---- miembro normal: editar / borrar / convertir
        (6,  'miembro normal edita el saldo → rechazado',                            u_member,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"opening":{"is_opening_balance":true,"paid_by_member_key":%s}}'::jsonb, '{"opening":"2026-02-01T00:00:06.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, e1, to_json(u_member::text)),
             'err:yala_opening_balance_not_admin'),
        (7,  'miembro normal borra el saldo → rechazado',                            u_member,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'tombstone', '{}'::jsonb, '{}'::jsonb, 'k', '2026-02-01T00:00:07.000Z-0000-00000000000000aa')$q$, g1, e1),
             'err:yala_opening_balance_not_admin'),
        (8,  'miembro normal borra el reparto del saldo → rechazado',                u_member,
             format($q$select public.apply_group_delta('split_shares', %L, %L, 'tombstone', '{}'::jsonb, '{}'::jsonb, 'k', '2026-02-01T00:00:08.000Z-0000-00000000000000aa')$q$, g1, s1),
             'err:yala_opening_balance_not_admin'),
        (9,  'miembro normal añade un reparto al saldo → rechazado',                 u_member,
             format($q$select public.apply_group_delta('split_shares', %L, gen_random_uuid(), 'upsert', '{"gshare":{"expense_id":%s,"member_key":%s}}'::jsonb, '{"gshare":"2026-02-01T00:00:09.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, to_json(e1::text), to_json(u_member::text)),
             'err:yala_opening_balance_not_admin'),
        (10, 'miembro normal convierte un gasto normal en saldo → rechazado',        u_member,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"opening":{"is_opening_balance":true}}'::jsonb, '{"opening":"2026-02-01T00:00:10.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, e_normal),
             'err:yala_opening_balance_not_admin'),
        (11, 'miembro normal convierte el saldo en gasto normal → rechazado',        u_member,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"opening":{"is_opening_balance":false}}'::jsonb, '{"opening":"2026-02-01T00:00:11.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, e1),
             'err:yala_opening_balance_not_admin'),
        (12, 'miembro normal mueve un reparto del saldo a su gasto → rechazado',     u_member,
             format($q$select public.apply_group_delta('split_shares', %L, %L, 'upsert', '{"gshare":{"expense_id":%s,"member_key":%s}}'::jsonb, '{"gshare":"2026-02-01T00:00:12.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, s1, to_json(e_normal::text), to_json(u_member::text)),
             'err:yala_opening_balance_not_admin'),
        (13, 'miembro normal, PATCH directo sobre el saldo → rechazado',             u_member,
             format($q$update public.split_expenses set paid_by_member_key = %L where group_id = %L and sync_id = %L returning 'patched'$q$, u_member::text, g1, e1),
             'err:yala_opening_balance_not_admin'),
        -- ---- fuera del grupo
        (14, 'ex-miembro (era admin) edita el saldo → rechazado',                    u_ex,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"opening":{"is_opening_balance":true,"paid_by_member_key":%s}}'::jsonb, '{"opening":"2026-02-01T00:00:14.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, e1, to_json(u_ex::text)),
             'err:yala_not_authorized'),
        (15, 'admin pendiente de aprobar crea un saldo → rechazado',                 u_pend,
             format($q$select public.apply_group_delta('split_expenses', %L, gen_random_uuid(), 'upsert', '{"opening":{"is_opening_balance":true}}'::jsonb, '{"opening":"2026-02-01T00:00:15.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1),
             'err:yala_not_authorized'),
        (16, 'alguien de fuera crea un saldo → rechazado sin saber nada del grupo',  u_out,
             format($q$select public.apply_group_delta('split_expenses', %L, gen_random_uuid(), 'upsert', '{"opening":{"is_opening_balance":true}}'::jsonb, '{"opening":"2026-02-01T00:00:16.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1),
             'err:yala_not_authorized'),
        -- ---- grupo cerrado / dueño de grupo migrado
        (17, 'grupo congelado (cerrado en el servidor): el admin crea un saldo → rechazado', u_admin,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"opening":{"is_opening_balance":true}}'::jsonb, '{"opening":"2026-02-01T00:00:17.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g2, e6),
             'err:yala_opening_balance_group_closed'),
        (18, 'dueño con rol «member» (grupo migrado) crea un saldo → aceptado',      u_owner3,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"opening":{"is_opening_balance":true,"paid_by_member_key":%s}}'::jsonb, '{"opening":"2026-02-01T00:00:18.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g3, e5, to_json(u_owner3::text)),
             'applied'),
        (19, 'en ese grupo, un miembro normal lo edita → rechazado',                 u_member,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"opening":{"is_opening_balance":true,"paid_by_member_key":%s}}'::jsonb, '{"opening":"2026-02-01T00:00:19.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g3, e5, to_json(u_member::text)),
             'err:yala_opening_balance_not_admin'),
        -- ---- pago confirmado
        (20, 'pago confirmado: el admin edita el saldo de D → rechazado',            u_admin,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"opening":{"is_opening_balance":true,"paid_by_member_key":%s}}'::jsonb, '{"opening":"2026-02-01T00:00:20.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, e2, to_json(u_c::text)),
             'err:yala_opening_balance_locked'),
        (21, 'pago confirmado: el dueño lo borra → rechazado',                       u_owner,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'tombstone', '{}'::jsonb, '{}'::jsonb, 'k', '2026-02-01T00:00:21.000Z-0000-00000000000000aa')$q$, g1, e2),
             'err:yala_opening_balance_locked'),
        (22, 'pago confirmado: el admin borra su reparto → rechazado',               u_admin,
             format($q$select public.apply_group_delta('split_shares', %L, %L, 'tombstone', '{}'::jsonb, '{}'::jsonb, 'k', '2026-02-01T00:00:22.000Z-0000-00000000000000aa')$q$, g1, s2),
             'err:yala_opening_balance_locked'),
        (23, 'pago confirmado: el admin le añade un reparto → rechazado',            u_admin,
             format($q$select public.apply_group_delta('split_shares', %L, gen_random_uuid(), 'upsert', '{"gshare":{"expense_id":%s,"member_key":%s}}'::jsonb, '{"gshare":"2026-02-01T00:00:23.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, to_json(e2::text), to_json(u_c::text)),
             'err:yala_opening_balance_locked'),
        (24, 'carrera: mover un saldo libre HACIA alguien saldado entra entero (se juzga la arista que ya tiene)', u_admin,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"opening":{"is_opening_balance":true,"paid_by_member_key":%s}}'::jsonb, '{"opening":"2026-02-01T00:00:24.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, e7, to_json(u_z::text)),
             'applied'),
        (25, 'pago confirmado: CREAR un saldo nuevo con D de acreedor sigue permitido', u_admin,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"opening":{"is_opening_balance":true,"paid_by_member_key":%s}}'::jsonb, '{"opening":"2026-02-01T00:00:25.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, e3, to_json(u_d::text)),
             'applied'),
        (26, 'pago confirmado: su PRIMER reparto también (su acreedor D está saldado; crear no es editar)', u_admin,
             format($q$select public.apply_group_delta('split_shares', %L, %L, 'upsert', '{"gshare":{"expense_id":%s,"member_key":%s}}'::jsonb, '{"gshare":"2026-02-01T00:00:26.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, s3, to_json(e3::text), to_json(u_c::text)),
             'applied'),
        (27, 'CONTROL pago sin confirmar o confirmado y BORRADO no bloquea: editar E4', u_admin,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'upsert', '{"opening":{"is_opening_balance":true,"paid_by_member_key":%s}}'::jsonb, '{"opening":"2026-02-01T00:00:27.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, e4, to_json(u_c::text)),
             'applied'),
        -- ---- lo que no se juzga
        (28, 'reparto de un gasto que aún no llegó: no se juzga',                    u_member,
             format($q$select public.apply_group_delta('split_shares', %L, gen_random_uuid(), 'upsert', '{"gshare":{"expense_id":%s,"member_key":%s}}'::jsonb, '{"gshare":"2026-02-01T00:00:28.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, to_json(e_ghost::text), to_json(u_member::text)),
             'applied'),
        (29, 'admin borra el saldo y su reparto sin pagos → aceptado (reparto)',     u_admin,
             format($q$select public.apply_group_delta('split_shares', %L, %L, 'tombstone', '{}'::jsonb, '{}'::jsonb, 'k', '2026-02-01T00:00:29.000Z-0000-00000000000000aa')$q$, g1, s1),
             'applied'),
        (30, 'admin borra el saldo y su reparto sin pagos → aceptado (gasto)',       u_admin,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'tombstone', '{}'::jsonb, '{}'::jsonb, 'k', '2026-02-01T00:00:30.000Z-0000-00000000000000aa')$q$, g1, e1),
             'applied'),
        (33, 'pago confirmado: el admin MUEVE el reparto de un saldo bloqueado (E8, acreedor Z) a uno libre (E4) → rechazado', u_admin,
             format($q$select public.apply_group_delta('split_shares', %L, %L, 'upsert', '{"gshare":{"expense_id":%s,"member_key":%s}}'::jsonb, '{"gshare":"2026-02-01T00:00:33.000Z-0000-00000000000000aa"}'::jsonb, 'k')$q$, g1, s8, to_json(e4::text), to_json(u_owner::text)),
             'err:yala_opening_balance_locked'),
        (34, 'reenvío del borrado de un saldo ya borrado (respuesta perdida), por quien ya no es admin → no se juzga', u_member,
             format($q$select public.apply_group_delta('split_expenses', %L, %L, 'tombstone', '{}'::jsonb, '{}'::jsonb, 'k', '2026-02-01T00:00:34.000Z-0000-00000000000000aa')$q$, g1, e1),
             'applied')
      ) as t(n, label, who, stmt, expected)
      order by n
    loop
      perform set_config('request.jwt.claims', json_build_object('sub', c.who, 'role', 'authenticated')::text, true);
      perform set_config('role', 'authenticated', true);
      begin
        execute c.stmt into got;
        if got is null then
          got := 'norow';  -- un PATCH que la RLS filtró: no tocó ninguna fila
        elsif got like '{%' then
          got := case when (got::jsonb ->> 'noop')::boolean then 'noop:' || coalesce(got::jsonb ->> 'reason', '?')
                      else 'applied' end;
        elsif got = 'patched' then
          got := 'applied';
        end if;
      exception when others then
        got := 'err:' || sqlerrm;
      end;
      perform set_config('role', orig_role, true);
      perform set_config('request.jwt.claims', '', true);
      res := res || jsonb_build_object('n', c.n, 'label', c.label, 'expected', c.expected, 'got', got,
                                       'ok', got like c.expected || '%');
    end loop;
  end;

  -- 31. Sin sesión (migraciones, `g7_recrypt_corpus`): el candado no juzga.
  begin
    update public.split_expenses set paid_by_member_key = u_z::text where group_id = g1 and sync_id = e2;
    got := 'applied';
  exception when others then
    got := 'err:' || sqlerrm;
  end;
  res := res || jsonb_build_object('n', 31, 'label', 'sin sesión (dueño de BD) edita un saldo bloqueado → pasa',
                                   'expected', 'applied', 'got', got, 'ok', got = 'applied');

  -- 32. Lo aplicado quedó escrito, y lo rechazado no: E1 borrado por el admin, E2 intacto salvo el paso 31.
  got := (select string_agg(sync_id::text || '=' || deleted::text || '/' || coalesce(paid_by_member_key, '-'), ',' order by sync_id)
            from public.split_expenses where group_id = g1 and sync_id in (e1, e2));
  res := res || jsonb_build_object('n', 32, 'label', 'estado final: E1 borrado, E2 vivo',
                                   'expected', e1::text || '=true/' || u_admin::text || ',' || e2::text || '=false/' || u_z::text,
                                   'got', got,
                                   'ok', got = e1::text || '=true/' || u_admin::text || ',' || e2::text || '=false/' || u_z::text);

  raise exception 'G27_RESULTS:%', res::text;
end
$battery$;
