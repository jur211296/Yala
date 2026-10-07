-- hlc01-cap-test.sql — casos del tope a un HLC futuro. Lo corre `hlc01-cap-test.sh` (psql -At); cada caso imprime
-- una línea `PASS <nombre>` o `FAIL <nombre> — <detalle>`. Cada sentencia va en su propia transacción, así que
-- `now()` avanza entre ellas como entre dos peticiones reales.

-- ------------------------------------------------------------------------------------------------- utilidades
create function pg_temp.hlc(p_off interval, p_counter int, p_node text) returns text language sql as
$$ select to_char((now() at time zone 'utc') + p_off, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
          || '-' || lpad(to_hex(p_counter), 4, '0') || '-' || p_node $$;

-- Instante canónico (24 chars) de now() + p_off.
create function pg_temp.at(p_off interval) returns text language sql as
$$ select to_char((now() at time zone 'utc') + p_off, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') $$;

create function pg_temp.ok(p_name text, p_cond boolean, p_detail text default '') returns text language sql as
$$ select case when coalesce(p_cond, false) then 'PASS ' || p_name
               else 'FAIL ' || p_name || ' — ' || coalesce(p_detail, '(null)') end $$;

-- «Acotado a now()+60 s de su escritura»: prefijo entre now()+50 s y now()+60 s del momento de la comprobación.
create function pg_temp.capped(p_hlc text) returns boolean language sql as
$$ select left(p_hlc, 24) collate "C" <= pg_temp.at(interval '60 seconds') collate "C"
      and left(p_hlc, 24) collate "C" >= pg_temp.at(interval '50 seconds') collate "C" $$;

-- Ejecuta `p_sql` como el usuario `p_uid` con `role authenticated` (como PostgREST) y devuelve su jsonb.
create function pg_temp.as_user(p_uid uuid, p_sql text) returns jsonb language plpgsql as
$$
declare r jsonb;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid)::text, true);
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  return r;
end
$$;

-- Upsert de una unidad de split_expenses por `apply_group_delta` REAL.
create function pg_temp.gdelta(p_uid uuid, p_sync uuid, p_unit text, p_value text, p_hlc text) returns jsonb
language sql as
$$ select pg_temp.as_user(p_uid, format(
     'select public.apply_group_delta(%L, %L, %L::uuid, %L, %L::jsonb, %L::jsonb, %L, %L, 1)',
     'split_expenses', 'grupo-hlc01', p_sync, 'upsert',
     jsonb_build_object(p_unit, jsonb_build_object(p_unit, p_value)), jsonb_build_object(p_unit, p_hlc), 'k', p_hlc)) $$;

create function pg_temp.gtomb(p_uid uuid, p_sync uuid, p_hlc text) returns jsonb language sql as
$$ select pg_temp.as_user(p_uid, format(
     'select public.apply_group_delta(%L, %L, %L::uuid, %L, %L::jsonb, %L::jsonb, %L, %L, 1)',
     'split_expenses', 'grupo-hlc01', p_sync, 'tombstone', '{}', '{}', 'k', p_hlc)) $$;

\set A '''aaaaaaaa-0000-0000-0000-000000000001'''
\set B '''bbbbbbbb-0000-0000-0000-000000000002'''

-- ======================================================================================= instalación
select pg_temp.ok('instalacion: 22 triggers cap_future_hlc (tras aplicar la migración dos veces)',
  (select count(*) from pg_trigger where tgname = 'cap_future_hlc' and not tgisinternal) = 22,
  (select count(*)::text from pg_trigger where tgname = 'cap_future_hlc'));

select pg_temp.ok('instalacion: ningún cliente puede ejecutar las funciones del tope',
  not has_function_privilege('authenticated', 'public.hlc_cap_value(text,text)', 'execute')
  and not has_function_privilege('anon', 'public.hlc_cap_value(text,text)', 'execute')
  and not has_function_privilege('authenticated', 'public.hlc_cap_patch(jsonb,text)', 'execute'));

-- ======================================================================================= normalización (legacy)
select pg_temp.ok('legacy: hlc y field_hlcs del futuro acotados, contador y nodo conservados',
  pg_temp.capped(hlc) and right(hlc, 22) = '-0007-00000000000000aa'
  and pg_temp.capped(field_hlcs ->> 'name') and right(field_hlcs ->> 'name', 22) = '-0007-00000000000000aa',
  hlc || ' / ' || field_hlcs::text)
from public.tags where sync_id = '11111111-0000-0000-0000-000000000001';

select pg_temp.ok('legacy: la unidad que no pasaba del tope queda intacta',
  field_hlcs ->> 'color_hex' = '2026-01-01T00:00:00.000Z-0000-00000000000000aa', field_hlcs::text)
from public.tags where sync_id = '11111111-0000-0000-0000-000000000001';

select pg_temp.ok('legacy: deleted_hlc del futuro acotado', pg_temp.capped(deleted_hlc) and deleted, deleted_hlc)
from public.tags where sync_id = '11111111-0000-0000-0000-000000000002';

select pg_temp.ok('legacy: el HLC mal formado que ganaba a todo (zz) queda acotado con nodo de servidor',
  pg_temp.capped(hlc) and right(hlc, 22) = '-0000-0000000000000000' and value = 'B', hlc)
from public.user_preferences where key = 'zz_hlc_probe';

select pg_temp.ok('legacy: gasto de grupo sellado un año por delante, acotado',
  pg_temp.capped(hlc) and pg_temp.capped(field_hlcs ->> 'currency_code'), hlc)
from public.split_expenses where sync_id = '22222222-0000-0000-0000-000000000001';

select pg_temp.ok('legacy: las filas acotadas cambian de server_seq (los teléfonos las vuelven a bajar)',
  (select count(*) from public.tags t join public.hlc01_seq_before b on b.t = 'tags' and b.id = t.sync_id::text
     where t.sync_id in ('11111111-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000002')
       and t.server_seq > b.server_seq) = 2
  and (select count(*) from public.split_expenses e join public.hlc01_seq_before b
         on b.t = 'split_expenses' and b.id = e.sync_id::text where e.server_seq > b.server_seq) = 1);

select pg_temp.ok('legacy: la fila dentro del margen no se re-escribe (su server_seq no se mueve)',
  t.server_seq = b.server_seq, t.server_seq || ' vs ' || b.server_seq)
from public.tags t join public.hlc01_seq_before b on b.t = 'tags' and b.id = t.sync_id::text
where t.sync_id = '11111111-0000-0000-0000-000000000003';

-- ======================================================================================= trigger en tablas personales
insert into public.tags (user_id, sync_id, name, field_hlcs, hlc)
values (:A, '33333333-0000-0000-0000-000000000001', 'nuevo',
        jsonb_build_object('name', pg_temp.hlc('1 month', 5, '00000000000000aa'), 'icon_name', pg_temp.hlc('-1 hour', 0, '00000000000000bb'), 'raro', 42),
        pg_temp.hlc('1 month', 5, '00000000000000aa'));
select pg_temp.ok('personal insert: HLC un mes por delante, acotado a now()+60 s',
  pg_temp.capped(hlc) and right(hlc, 22) = '-0005-00000000000000aa' and pg_temp.capped(field_hlcs ->> 'name'), hlc)
from public.tags where sync_id = '33333333-0000-0000-0000-000000000001';
select pg_temp.ok('personal insert: la unidad del pasado queda intacta',
  left(field_hlcs ->> 'icon_name', 24) < pg_temp.at('0 seconds') and right(field_hlcs ->> 'icon_name', 22) = '-0000-00000000000000bb',
  field_hlcs::text)
from public.tags where sync_id = '33333333-0000-0000-0000-000000000001';
-- Un valor que no es texto (42) ordenaba, leído con `->>`, por encima de todo: se sustituye por el tope.
select pg_temp.ok('personal insert: un valor no-texto en field_hlcs se sustituye por el tope con nodo de servidor',
  pg_temp.capped(field_hlcs ->> 'raro') and right(field_hlcs ->> 'raro', 22) = '-0000-0000000000000000', field_hlcs::text)
from public.tags where sync_id = '33333333-0000-0000-0000-000000000001';

-- El hlc de fila nunca por debajo de una unidad: dos unidades del futuro con contadores invertidos al acotarlas
-- (`name` 0x0007 en el ms m, `color_hex` 0x0000 en el ms m+1, `hlc` = la mayor sin acotar = color_hex).
insert into public.tags (user_id, sync_id, name, field_hlcs, hlc)
values (:A, '33333333-0000-0000-0000-000000000003', 'invariante',
        jsonb_build_object('name', pg_temp.hlc('1 month', 7, '00000000000000aa'),
                           'color_hex', pg_temp.hlc('1 month 1 millisecond', 0, '00000000000000aa')),
        pg_temp.hlc('1 month 1 millisecond', 0, '00000000000000aa'));
select pg_temp.ok('personal insert: con unidades acotadas, el hlc de fila sigue siendo el máximo de las unidades',
  hlc collate "C" >= (field_hlcs ->> 'name') collate "C" and hlc collate "C" >= (field_hlcs ->> 'color_hex') collate "C"
  and pg_temp.capped(hlc), hlc || ' / ' || field_hlcs::text)
from public.tags where sync_id = '33333333-0000-0000-0000-000000000003';

-- Un mal formado con un carácter de control delante: en "C" ordena por DEBAJO (0x01 < '2'), pero una collation que
-- ignore los controles lo leería como año 9999. Se sustituye sin mirar su orden.
insert into public.tags (user_id, sync_id, name, field_hlcs, hlc)
values (:A, '33333333-0000-0000-0000-000000000004', 'control', '{}',
        E'\x01' || '9999-12-31T00:00:00.000Z-0000-0000000000000000');
select pg_temp.ok('personal insert: un HLC con un carácter de control se sustituye por el tope',
  pg_temp.capped(hlc) and right(hlc, 22) = '-0000-0000000000000000', hlc)
from public.tags where sync_id = '33333333-0000-0000-0000-000000000004';

-- `''` es legítimo (la rama de tombstone de apply_group_delta lo escribe sin row_hlc): no se toca.
insert into public.tags (user_id, sync_id, name, field_hlcs, hlc, deleted, deleted_hlc)
values (:A, '33333333-0000-0000-0000-000000000005', 'vacio', '{}', '', true, null);
select pg_temp.ok('personal insert: un hlc vacío se queda vacío', hlc = '', hlc)
from public.tags where sync_id = '33333333-0000-0000-0000-000000000005';

insert into public.tags (user_id, sync_id, name, field_hlcs, hlc)
values (:A, '33333333-0000-0000-0000-000000000002', 'margen',
        jsonb_build_object('name', pg_temp.hlc('30 seconds', 2, '00000000000000aa')), pg_temp.hlc('30 seconds', 2, '00000000000000aa'));
select pg_temp.ok('personal insert: +30 s (dentro del margen) se guarda tal cual',
  left(hlc, 24) < pg_temp.at('31 seconds') and left(hlc, 24) > pg_temp.at('25 seconds')
  and hlc = field_hlcs ->> 'name', hlc)
from public.tags where sync_id = '33333333-0000-0000-0000-000000000002';

update public.tags set deleted = true, deleted_hlc = pg_temp.hlc('1 year', 0, '00000000000000aa')
 where sync_id = '33333333-0000-0000-0000-000000000002';
select pg_temp.ok('personal update: tombstone un año por delante, deleted_hlc acotado', pg_temp.capped(deleted_hlc), deleted_hlc)
from public.tags where sync_id = '33333333-0000-0000-0000-000000000002';

insert into public.user_preferences (user_id, key, value, hlc)
values (:A, 'pref_fut', 'x', pg_temp.hlc('10 minutes', 0, '00000000000000aa'));
select pg_temp.ok('prefs: HLC +10 min acotado', pg_temp.capped(hlc), hlc) from public.user_preferences where key = 'pref_fut';

insert into public.user_preferences (user_id, key, value, hlc) values (:A, 'pref_bajo', 'x', '0');
select pg_temp.ok('prefs: un mal formado que ordena por DEBAJO también se sustituye (sin mirar su orden)',
  pg_temp.capped(hlc) and right(hlc, 22) = '-0000-0000000000000000', hlc)
from public.user_preferences where key = 'pref_bajo';

-- ======================================================================================= Grupos, por apply_group_delta REAL
-- G1: A (un mes adelantado) edita X. Entra, y se guarda acotado.
select pg_temp.ok('grupos: el cambio del teléfono adelantado ENTRA (no se rechaza)',
  (pg_temp.gdelta(:A, '44444444-0000-0000-0000-000000000001', 'currency_code', 'USD',
                  pg_temp.hlc('1 month', 1, '00000000000000aa')) ->> 'noop')::boolean = false);
select pg_temp.ok('grupos: ... y se guarda acotado, con contador y nodo',
  pg_temp.capped(hlc) and right(hlc, 22) = '-0001-00000000000000aa' and pg_temp.capped(field_hlcs ->> 'currency_code')
  and currency_code = 'USD', hlc)
from public.split_expenses where sync_id = '44444444-0000-0000-0000-000000000001';

-- G2: B edita X DESPUÉS de la ventana (HLC now()+90 s ≡ «pasó más de un minuto»). Gana: es el bug del ticket, cerrado.
select pg_temp.ok('grupos: lo que B escribe pasado el minuto GANA al teléfono adelantado',
  (pg_temp.gdelta(:B, '44444444-0000-0000-0000-000000000001', 'currency_code', 'EUR',
                  pg_temp.hlc('90 seconds', 0, '00000000000000bb')) ->> 'noop')::boolean = false);
select pg_temp.ok('grupos: ... y queda el valor de B', currency_code = 'EUR', currency_code)
from public.split_expenses where sync_id = '44444444-0000-0000-0000-000000000001';

-- G3: dentro del minuto el adelantado sí gana (la ventana acotada, a propósito).
select pg_temp.gdelta(:A, '44444444-0000-0000-0000-000000000002', 'currency_code', 'USD',
                      pg_temp.hlc('1 month', 1, '00000000000000aa')) is not null as _ \gset
select pg_temp.ok('grupos: dentro del minuto (now()+30 s) B pierde: la ventana acotada',
  (pg_temp.gdelta(:B, '44444444-0000-0000-0000-000000000002', 'currency_code', 'EUR',
                  pg_temp.hlc('30 seconds', 0, '00000000000000bb')) ->> 'reason') = 'all_units_stale');

-- G4: orden propio. A edita Y dos veces con el reloj un mes por delante (contador +1, como `sendLocal` con el reloj
-- adelantado): gana el segundo, porque el RPC decide con su HLC sin acotar frente al primero ya guardado acotado.
select pg_temp.gdelta(:A, '44444444-0000-0000-0000-000000000003', 'currency_code', 'USD',
                      pg_temp.hlc('1 month', 1, '00000000000000aa')) is not null as _ \gset
select (pg_temp.gdelta(:A, '44444444-0000-0000-0000-000000000003', 'currency_code', 'GBP',
                       pg_temp.hlc('1 month', 2, '00000000000000aa')) ->> 'noop') as g4_noop \gset
-- La comprobación va en OTRA sentencia: en la misma, la subconsulta lee con la instantánea de antes del RPC.
select pg_temp.ok('grupos: el segundo cambio del adelantado gana al primero aunque el primero ya esté acotado',
  :'g4_noop' = 'false' and currency_code = 'GBP', :'g4_noop' || ' / ' || currency_code)
from public.split_expenses where sync_id = '44444444-0000-0000-0000-000000000003';

-- G5: monótono al cruzar el umbral: W1 a +59 s (se guarda tal cual), W2 a +2 min (se acota): W2 > W1.
select pg_temp.gdelta(:A, '44444444-0000-0000-0000-000000000004', 'currency_code', 'USD',
                      pg_temp.hlc('59 seconds', 0, '00000000000000aa')) is not null as _ \gset
select hlc as w1 from public.split_expenses where sync_id = '44444444-0000-0000-0000-000000000004' \gset
select (pg_temp.gdelta(:A, '44444444-0000-0000-0000-000000000004', 'currency_code', 'GBP',
                       pg_temp.hlc('2 minutes', 0, '00000000000000aa')) ->> 'noop') as g5_noop \gset
select pg_temp.ok('grupos: cruzar el umbral no deja el segundo cambio por debajo del primero',
  :'g5_noop' = 'false' and hlc collate "C" > :'w1' collate "C" and currency_code = 'GBP',
  :'w1' || ' → ' || hlc)
from public.split_expenses where sync_id = '44444444-0000-0000-0000-000000000004';

-- G6: un borrado del adelantado ya no bloquea para siempre: B lo resucita pasado el minuto.
select pg_temp.gtomb(:A, '44444444-0000-0000-0000-000000000005', pg_temp.hlc('1 year', 0, '00000000000000aa')) is not null as _ \gset
select pg_temp.ok('grupos: tombstone un año por delante, guardado acotado', pg_temp.capped(deleted_hlc) and deleted, deleted_hlc)
from public.split_expenses where sync_id = '44444444-0000-0000-0000-000000000005';
select pg_temp.ok('grupos: ... y B lo resucita pasado el minuto',
  (pg_temp.gdelta(:B, '44444444-0000-0000-0000-000000000005', 'currency_code', 'EUR',
                  pg_temp.hlc('90 seconds', 0, '00000000000000bb')) ->> 'resurrected')::boolean);

-- G7: la meta del grupo (split_groups, admin) también se acota.
select pg_temp.as_user(:A, format(
  'select public.apply_group_delta(%L, %L, null, %L, %L::jsonb, %L::jsonb, %L, %L, 1)',
  'split_groups', 'grupo-hlc01', 'upsert', '{"icon_name": {"icon_name": "star"}}',
  jsonb_build_object('icon_name', pg_temp.hlc('1 month', 0, '00000000000000aa')), 'k',
  pg_temp.hlc('1 month', 0, '00000000000000aa'))) is not null as _ \gset
select pg_temp.ok('grupos: la meta del grupo con HLC del futuro, acotada', pg_temp.capped(hlc) and icon_name = 'star', hlc)
from public.split_groups where group_id = 'grupo-hlc01';

-- ======================================================================================= control negativo: SIN la migración
\i :rollback_file
select pg_temp.ok('control: el rollback retira los 22 triggers',
  (select count(*) from pg_trigger where tgname = 'cap_future_hlc') = 0);
select pg_temp.gdelta(:A, '44444444-0000-0000-0000-000000000006', 'currency_code', 'USD',
                      pg_temp.hlc('1 month', 1, '00000000000000aa')) is not null as _ \gset
select pg_temp.ok('control: sin el tope, el HLC de un mes por delante se guarda entero (el bug existe)',
  left(hlc, 24) > pg_temp.at('20 days'), hlc)
from public.split_expenses where sync_id = '44444444-0000-0000-0000-000000000006';
select pg_temp.ok('control: sin el tope, B pierde aunque escriba pasado el minuto (el bug del ticket)',
  (pg_temp.gdelta(:B, '44444444-0000-0000-0000-000000000006', 'currency_code', 'EUR',
                  pg_temp.hlc('90 seconds', 0, '00000000000000bb')) ->> 'reason') = 'all_units_stale');

-- Re-aplicar deja el estado del principio: la normalización acota también la fila del control.
\i :migration_file
select pg_temp.ok('re-aplicar tras el rollback: la fila del control queda acotada',
  pg_temp.capped(hlc), hlc)
from public.split_expenses where sync_id = '44444444-0000-0000-0000-000000000006';
