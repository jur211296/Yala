-- g38_01 · banco: casos contra la migración, dentro de UNA transacción que el `raise` final deshace entera.
-- Lo arma `g38_01-remote.sh test`: cuerpo de la migración (sin begin/commit) + este fichero. No deja nada en la base.
do $bench$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  gid text := 'SplitGroup-' || gen_random_uuid()::text;
  gid2 text := 'SplitGroup-' || gen_random_uuid()::text;
  pkey text := gen_random_uuid()::text;
  tok text; tok2 text;
  r jsonb;
  out jsonb := '[]'::jsonb;
  n int; st text; uid uuid; isp boolean;
  procedure_dummy int;
begin
  insert into auth.users (id, aud, role, email) values
    (a, 'authenticated', 'authenticated', 'g38a-' || a || '@bench.invalid'),
    (b, 'authenticated', 'authenticated', 'g38b-' || b || '@bench.invalid'),
    (c, 'authenticated', 'authenticated', 'g38c-' || c || '@bench.invalid');

  -- A crea la persona «Marta»
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  r := public.create_person_group(gid, 'Marta', 'PEN', 'person.fill', '#14B8A6', 'Jürgen', pkey, 'k');
  perform set_config('role', 'postgres', true);
  select count(*) into n from group_members where group_id = gid and deleted = false;
  select is_person into isp from split_groups where group_id = gid;
  select status, user_id into st, uid from group_members where group_id = gid and member_key = pkey;
  out := out || jsonb_build_object('caso', 'crear_persona_dos_miembros', 'ok', n = 2 and isp and st = 'active' and uid is null,
                                   'detalle', jsonb_build_object('n', n, 'is_person', isp, 'status', st));

  -- crear otra con la misma zona: yala_group_exists
  begin
    perform set_config('role', 'authenticated', true);
    perform public.create_person_group(gid, 'Otra', 'PEN', 'person.fill', '#14B8A6', 'Jürgen', gen_random_uuid()::text, 'k');
    out := out || jsonb_build_object('caso', 'zona_repetida', 'ok', false);
  exception when others then
    out := out || jsonb_build_object('caso', 'zona_repetida', 'ok', sqlerrm = 'yala_group_exists', 'detalle', sqlerrm);
  end;
  perform set_config('role', 'postgres', true);

  -- clave del sitio reservado igual a la del dueño: yala_bad_input
  begin
    perform set_config('role', 'authenticated', true);
    perform public.create_person_group('SplitGroup-' || gen_random_uuid(), 'X', 'PEN', 'person.fill', '#14B8A6', 'J', a::text, 'k');
    out := out || jsonb_build_object('caso', 'clave_del_dueno', 'ok', false);
  exception when others then
    out := out || jsonb_build_object('caso', 'clave_del_dueno', 'ok', sqlerrm = 'yala_bad_input', 'detalle', sqlerrm);
  end;
  perform set_config('role', 'postgres', true);

  -- A invita; B abre el enlace: ocupa el sitio y entra activo
  perform set_config('role', 'authenticated', true);
  tok := public.create_group_invite(gid, 2592000, null);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  r := public.join_group(tok, 'Marta Pérez', 'k', null);
  perform set_config('role', 'postgres', true);
  select status, user_id into st, uid from group_members where group_id = gid and member_key = pkey;
  select count(*) into n from group_members where group_id = gid and deleted = false;
  out := out || jsonb_build_object('caso', 'entra_sin_aprobacion', 'ok',
    r->>'status' = 'active' and (r->>'changed')::boolean and (r->>'is_person')::boolean and r->>'member_key' = pkey
    and st = 'active' and uid = b and n = 2, 'detalle', r);

  -- B vuelve a abrirlo: no cambia nada
  perform set_config('role', 'authenticated', true);
  r := public.join_group(tok, 'Marta Pérez', 'k', null);
  perform set_config('role', 'postgres', true);
  out := out || jsonb_build_object('caso', 'retap_no_op', 'ok', r->>'status' = 'active' and not (r->>'changed')::boolean, 'detalle', r);

  -- C (un tercero) con el mismo enlace: no entra
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.join_group(tok, 'Intruso', 'k', null);
    out := out || jsonb_build_object('caso', 'tercero_no_entra', 'ok', false);
  exception when others then
    out := out || jsonb_build_object('caso', 'tercero_no_entra', 'ok', sqlerrm = 'yala_invalid_invite', 'detalle', sqlerrm);
  end;
  perform set_config('role', 'postgres', true);
  select count(*) into n from group_members where group_id = gid;
  out := out || jsonb_build_object('caso', 'persona_sigue_de_dos', 'ok', n = 2, 'detalle', n);

  -- NO REGRESIÓN: un grupo normal sigue pidiendo aprobación
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  perform public.create_group(gid2, 'Viaje', 'PEN', 'airplane', '#8B5CF6', 'Jürgen', 'equal', 'k', false, false, false);
  tok2 := public.create_group_invite(gid2, 2592000, null);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  r := public.join_group(tok2, 'Marta', 'k', null);
  perform set_config('role', 'postgres', true);
  out := out || jsonb_build_object('caso', 'grupo_normal_pide_aprobacion', 'ok',
    r->>'status' = 'pendingApproval' and (r->>'changed')::boolean and r->'is_person' is null, 'detalle', r);

  raise exception 'G38BENCH %', out::text;
end;
$bench$;
