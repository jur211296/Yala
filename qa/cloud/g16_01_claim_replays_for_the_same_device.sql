-- =====================================================================================================
-- g16_01 · si se pierde la respuesta del alta, el reintento del MISMO teléfono la termina
--
-- QUÉ GANA EL USUARIO. Usa Yala solo para grupos y activa Yala completo → «Tu cuenta en la nube». Justo
-- cuando sale «Activando tu cuenta…» se corta la red: el servidor ya promocionó la cuenta, pero la
-- respuesta no llega al teléfono. Hasta hoy «Reintentar» le decía «Tu cuenta ya tiene finanzas
-- personales» —sin tenerlas— y desde ahí no había forma de activar la nube. Ahora el reintento termina.
-- Lo mismo gana quien se da de alta en la nube desde la bienvenida («Soy nuevo → nube») y pierde la
-- respuesta de ese primer alta: el reintento siembra en vez de adoptar una cuenta vacía.
--
-- Ticket: `claim-promotion-lost-response-blocks-the-retry` (su Paso 0 tiene las decisiones).
--
-- === EL CAMBIO: UNA RAMA MÁS EN claim_account ===
--   Tras la promoción, la fila queda `kind='complete'`, `leader_device_id = <este teléfono>` y sin
--   migración en curso. Un claim personal (`p_migration=false`) de ESE MISMO teléfono sobre ESA fila
--   contestaba `existing_stable`. Ahora contesta `created` —el mismo alta, repetido— si y solo si:
--
--     not p_migration                         una migración con `created` conduciría una máquina sin lease
--     leader_device_id = p_device_id          el que la promocionó (o la creó) es quien reintenta
--     kind = 'complete'                       una cuenta que volvió a iCloud no se reabre por aquí
--     not reverse_in_progress                 una vuelta a iCloud en curso tiene el backend congelado
--     sin fila en sync_seq_counters           la cuenta NUNCA recibió una escritura personal
--
--   El contrato del cliente ya lo daba por hecho —«el re-claim del MISMO device colapsa a `created`»
--   (`BornCloudSignUpOutcome.transient`)—, pero el servidor solo lo cumplía con una migración en curso.
--   La rama va DETRÁS de las de migración en curso, así que ahí `migration_in_progress` es falso.
--
-- === POR QUÉ EL CONTADOR Y NO LAS 16 TABLAS ===
--   `sync_seq_counters` lo crea el trigger `stamp_server_seq`, que está en las 17 tablas del canal
--   personal: las 16 de dominio y `user_preferences` (medido en producción el 2026-09-24). Una fila ahí
--   significa «alguna vez se escribió algo personal en esta cuenta». Es mejor señal que 16 `exists`:
--   sobrevive a los borrados, cubre las preferencias, y una tabla futura la hereda porque `server_seq` es
--   el cursor del pull. El RPC es SECURITY INVOKER y la policy `seq_select` deja al dueño leer SU fila.
--   La sonda del §3 lo comprueba con el rol `authenticated`, porque si RLS la escondiera la rama fallaría
--   ABIERTA: una cuenta con datos leída como vacía.
--
-- === POR QUÉ EL DISPOSITIVO SOLO NO BASTA ===
--   El mismo teléfono pudo tener esa cuenta completa CON datos hace meses (alta en la nube, cerrar sesión,
--   volver solo por grupos). Sin el contador, «Activar Yala completo» sembraría un segundo corpus encima.
--   Y sin el dispositivo, un segundo teléfono sembraría encima del alta en curso del primero, que todavía
--   no ha escrito nada: la fusión que el ADR descartó.
--
-- === APLICACIÓN ===
--   NO trae `begin;`/`commit;`: `apply_migration` ya envuelve en transacción. Por psql, con `-1`.
--   La firma NO cambia, así que no hay `drop function` ni grants que re-otorgar, y el Worker no se toca.
--
--     cuerpo vivo                                   | qué hace
--     ----------------------------------------------|--------------------------------------------
--     md5 8668a13c3d452fd5f192a192dd415bbd (g15_01)  | la sustitución + §2 + §3
--     md5 e7f8bec957091abaa126d8100a3a53bd (final)  | no-op, pero el §2 y el §3 corren IGUAL
--     cualquier otro                                | ABORTA
--
--   El md5 de llegada lo imprime el §2 y queda anotado en `qa/cloud/README.md`. El «final» se fijó tras la
--   review del 2026-09-24: aceptar cualquier cuerpo que llevara la marca dejaba pasar como «ya aplicada» una
--   función que hubiera divergido en otro sitio.
-- =====================================================================================================

-- ── 0 · Guarda de partida ────────────────────────────────────────────────────────────────────────────
do $guard$
declare
  v_src    text;
  v_firmas int;
begin
  select count(*) into v_firmas from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';
  if v_firmas <> 1 then
    raise exception 'g16_01: hay % firmas de claim_account, tiene que haber 1. Abortada.', v_firmas;
  end if;

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';

  if md5(v_src) = '8668a13c3d452fd5f192a192dd415bbd' then
    perform set_config('yala.g16_01_estado', 'virgen', true);
  elsif md5(v_src) = 'e7f8bec957091abaa126d8100a3a53bd' then
    perform set_config('yala.g16_01_estado', 'final', true);
    raise notice 'g16_01: la rama ya está en el cuerpo vivo (md5 %). No-op; el §2 y el §3 corren igual.', md5(v_src);
  else
    raise exception 'g16_01: claim_account no es el cuerpo esperado (md5 %). Abortada.', md5(v_src);
  end if;
end $guard$;

-- ── 1 · La transformación ────────────────────────────────────────────────────────────────────────────
-- Se parte del cuerpo VIVO y se sustituye un bloque exacto (el molde de g15_01/g15_02): pegar la función
-- entera a mano es como nació el drift que g13_05 tuvo que cerrar.
do $mig$
declare
  v_src text;
  v_new text;
  v_old_block constant text :=
$old$  elsif v_mip and v_leader = p_device_id then
    return jsonb_build_object('state', 'created', 'kind', v_kind);  -- idempotent reclaim by the same leader
  else$old$;
  v_new_block constant text :=
$new$  elsif v_mip and v_leader = p_device_id then
    return jsonb_build_object('state', 'created', 'kind', v_kind);  -- idempotent reclaim by the same leader
  elsif not p_migration
        and v_leader = p_device_id
        and v_kind = 'complete'
        and not v_reverse
        and not exists (select 1 from public.sync_seq_counters where user_id = v_uid) then
    -- g16_01: el MISMO teléfono reintenta un alta cuya respuesta se perdió. La promoción (o el INSERT)
    -- ya dejó la cuenta completa con este dispositivo de líder, y nadie ha escrito nada personal en ella:
    -- no hay nada que fusionar, así que es el mismo alta repetido. Sin esta rama el reintento leía su
    -- propia huella como «ya tienes finanzas personales» y bloqueaba para siempre.
    -- `sync_seq_counters` lo crea `stamp_server_seq` en las 17 tablas del canal personal (16 de dominio
    -- + user_preferences): ninguna fila = ninguna escritura personal, nunca. Ticket
    -- `claim-promotion-lost-response-blocks-the-retry`.
    return jsonb_build_object('state', 'created', 'kind', v_kind);
  else$new$;
begin
  if coalesce(current_setting('yala.g16_01_estado', true), '') <> 'virgen' then
    return;
  end if;

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';

  if position(v_old_block in v_src) = 0 then
    raise exception 'g16_01: no encuentro el bloque del reclaim idempotente en claim_account. Abortada.';
  end if;
  if (length(v_src) - length(replace(v_src, v_old_block, ''))) / length(v_old_block) <> 1 then
    raise exception 'g16_01: el bloque del reclaim idempotente aparece más de una vez. Abortada.';
  end if;

  v_new := replace(v_src, v_old_block, v_new_block);
  -- Misma firma y mismos defaults que g15_01: `create or replace` conserva los grants.
  execute format(
    'create or replace function public.claim_account(p_device_id text, p_provider text, p_migration boolean default false, p_kind text default %L) returns jsonb language plpgsql set search_path = public as %L',
    'complete', v_new);
end $mig$;

-- ── 2 · Verificación ESTRUCTURAL ─────────────────────────────────────────────────────────────────────
do $verify$
declare
  v_src    text;
  v_firmas int;
  v_marca  constant text := '-- g16_01: el MISMO teléfono reintenta';
begin
  select count(*) into v_firmas from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';
  if v_firmas <> 1 then raise exception 'g16_01 verify: % firmas de claim_account', v_firmas; end if;

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';
  if (length(v_src) - length(replace(v_src, v_marca, ''))) / length(v_marca) <> 1 then
    raise exception 'g16_01 verify: la rama nueva no está exactamente una vez';
  end if;
  if position('from public.sync_seq_counters where user_id = v_uid' in v_src) = 0 then
    raise exception 'g16_01 verify: falta la comprobación del contador';
  end if;

  -- `create or replace` reescribe los atributos de la función. La rama lee el contador POR RLS, así que
  -- tiene que seguir siendo SECURITY INVOKER: como DEFINER vería filas ajenas y el `search_path` fijo es
  -- lo que impide que otro esquema le cambie la tabla.
  select count(*) into v_firmas from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account'
      and not p.prosecdef and p.proconfig = array['search_path=public'];
  if v_firmas <> 1 then
    raise exception 'g16_01 verify: claim_account ya no es SECURITY INVOKER con search_path=public';
  end if;

  -- La señal vale lo que valga su cobertura: toda tabla del canal personal (las que llevan `user_id` y
  -- `server_seq` y NO `group_id`: `group_members` lleva las dos primeras y su propio contador, el de
  -- Grupos — lo cazó el control negativo de esta comprobación) tiene que estampar el contador. Una tabla
  -- nueva sin el trigger haría fallar la rama ABIERTA —una cuenta con datos solo ahí se leería vacía—. Hoy
  -- son 17; menos de 17 es que el filtro se rompió, no que haya menos tablas.
  select count(*) into v_firmas from information_schema.columns c
    where c.table_schema = 'public' and c.column_name = 'server_seq'
      and exists (select 1 from information_schema.columns u
                   where u.table_schema = 'public' and u.table_name = c.table_name and u.column_name = 'user_id')
      and not exists (select 1 from information_schema.columns g
                   where g.table_schema = 'public' and g.table_name = c.table_name and g.column_name = 'group_id');
  if v_firmas < 17 then
    raise exception 'g16_01 verify: solo % tablas con user_id+server_seq (se esperaban 17 o más)', v_firmas;
  end if;
  select string_agg(c.table_name, ', ') into v_src from information_schema.columns c
    where c.table_schema = 'public' and c.column_name = 'server_seq'
      and exists (select 1 from information_schema.columns u
                   where u.table_schema = 'public' and u.table_name = c.table_name and u.column_name = 'user_id')
      and not exists (select 1 from information_schema.columns g
                   where g.table_schema = 'public' and g.table_name = c.table_name and g.column_name = 'group_id')
      and not exists (select 1 from pg_trigger t
                       where t.tgrelid = format('public.%I', c.table_name)::regclass and not t.tgisinternal
                         and t.tgfoid = 'public.stamp_server_seq'::regproc);
  if v_src is not null then
    raise exception 'g16_01 verify: tablas del canal personal sin stamp_server_seq: %', v_src;
  end if;
  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';
  raise notice 'g16_01 · claim_account md5 de llegada: %', md5(v_src);
end $verify$;

-- ── 3 · Verificación de COMPORTAMIENTO ───────────────────────────────────────────────────────────────
-- El §2 mira TEXTO. Esto recorre los escenarios del ticket contra el motor real con usuarios sintéticos.
-- Cada escenario vive en su propio bloque con `exception`, o sea en su propio SAVEPOINT: al terminar lanza
-- `g16_01_deshacer` y vuelve al savepoint, así que no queda NINGUNA fila —tampoco las que crean los
-- triggers, como `sync_seq_counters`— y el rol y las GUC vuelven a su valor. Los resultados viven en
-- variables de PL/pgSQL, que no son transaccionales y sobreviven al rollback del savepoint.
--
-- Columnas: etiqueta | partida | escritura entre las dos llamadas | 1.ª llamada | 2.ª llamada | esperado
-- de la 2.ª | rol de la 2.ª. Las llamadas son `dispositivo:migración` (D = el que reintenta, O = otro).
-- Partidas: lite = la fila ligera de grupos · none = sin fila · reverted/reversing/mip = a mano.
do $conducta$
declare
  v_uid     uuid;
  v_ret     jsonb;
  v_last    text;
  v_fallos  text := '';
  v_n       int := 0;
  v_dev     text;
  e         text[];
  escen text[][] := array[
    array['respuesta perdida tras la promoción → termina (criterio 1)',     'lite',      '-',        'D:f', 'D:f', 'created',         'postgres'],
    array['lo mismo con el rol de PostgREST',                              'lite',      '-',        'D:f', 'D:f', 'created',         'authenticated'],
    array['alta born-cloud con la respuesta perdida → siembra (gemelo)',   'none',      '-',        'D:f', 'D:f', 'created',         'postgres'],
    array['otro teléfono ya tiene lo personal → bloquea (criterio 2)',     'lite',      'accounts', 'O:f', 'D:f', 'existing_stable', 'postgres'],
    array['otro teléfono, cuenta aún vacía (su alta en curso) → bloquea',  'lite',      '-',        'O:f', 'D:f', 'existing_stable', 'postgres'],
    array['mismo teléfono, ya subió transacciones → bloquea',              'lite',      'tx_items', 'D:f', 'D:f', 'existing_stable', 'postgres'],
    array['lo mismo con el rol de PostgREST (RLS del contador)',           'lite',      'tx_items', 'D:f', 'D:f', 'existing_stable', 'authenticated'],
    array['mismo teléfono, solo subió preferencias → bloquea',             'lite',      'prefs',    'D:f', 'D:f', 'existing_stable', 'postgres'],
    array['una migración sobre la cuenta recién promovida → no replica',   'lite',      '-',        'D:f', 'D:t', 'existing_stable', 'postgres'],
    array['cuenta que volvió a iCloud, vacía, mismo teléfono → bloquea',   'reverted',  '-',        '-',   'D:f', 'existing_stable', 'postgres'],
    array['vuelta a iCloud en curso, vacía, mismo teléfono → bloquea',     'reversing', '-',        '-',   'D:f', 'existing_stable', 'postgres'],
    array['migración en curso del mismo teléfono (control, rama vieja)',   'mip',       '-',        '-',   'D:t', 'created',         'postgres'],
    array['cuenta completa y vacía SIN líder apuntado → bloquea',          'noleader',  '-',        '-',   'D:f', 'existing_stable', 'postgres']
  ];
begin
  foreach e slice 1 in array escen loop
    v_n := v_n + 1;
    v_last := null;
    begin
      v_uid := gen_random_uuid();
      insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
        values (v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
                'g16-01-verify-' || replace(v_uid::text, '-', '') || '@invalid.local', now(), now());

      perform set_config('yala.kind_write', txid_current()::text, true);
      if e[2] = 'lite' then
        insert into public.profiles (id) values (v_uid);
      elsif e[2] = 'reverted' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, reverted_at, leader_device_id)
          values (v_uid, 'apple', 'groups_only', now(), now(), 'g16-01-D');
      elsif e[2] = 'reversing' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, reverse_in_progress,
                                     leader_device_id, migration_updated_at)
          values (v_uid, 'apple', 'complete', now(), true, 'g16-01-D', now());
      elsif e[2] = 'noleader' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, leader_device_id)
          values (v_uid, 'apple', 'complete', now(), null);
      elsif e[2] = 'mip' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, migration_in_progress,
                                     leader_device_id, migration_updated_at)
          values (v_uid, 'apple', 'complete', now(), true, 'g16-01-D', now());
      end if;
      perform set_config('yala.kind_write', '', true);

      -- «Sin fila» tiene que serlo de verdad: si algún trigger de auth.users la creara, el gemelo probaría
      -- una promoción y seguiría en verde.
      if e[2] = 'none' and exists (select 1 from public.profiles where id = v_uid) then
        raise exception 'la partida none ya trae fila en profiles';
      end if;

      perform set_config('request.jwt.claims',
                         json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

      -- 1.ª llamada: la que deja la huella (la promoción o el alta).
      if e[4] <> '-' then
        v_dev := case split_part(e[4], ':', 1) when 'D' then 'g16-01-D' else 'g16-01-O' end;
        v_ret := public.claim_account(v_dev, 'apple', split_part(e[4], ':', 2) = 't', 'complete');
        if v_ret->>'state' is distinct from 'created' then
          raise exception 'la 1.ª llamada devolvió %', v_ret;
        end if;
      end if;

      -- La escritura personal entre las dos, por el camino real: el trigger estampa el contador.
      if e[3] in ('accounts', 'tx_items') then
        execute format('insert into public.%I (user_id, sync_id, hlc, server_seq) values ($1, gen_random_uuid(), $2, 0)', e[3])
          using v_uid, '0000000000001:0000:g16';
      elsif e[3] = 'prefs' then
        v_ret := public.apply_pref('g16_01.probe', 'x', '0000000000001:0000:g16');
      end if;

      -- 2.ª llamada: el reintento. Con el rol de PostgREST cuando la fila lo pide, para que decida RLS.
      if e[7] = 'authenticated' then
        perform set_config('role', 'authenticated', true);
      end if;
      v_dev := case split_part(e[5], ':', 1) when 'D' then 'g16-01-D' else 'g16-01-O' end;
      v_ret := public.claim_account(v_dev, 'apple', split_part(e[5], ':', 2) = 't', 'complete');
      v_last := coalesce(v_ret->>'state', '<sin state>');

      raise exception 'g16_01_deshacer';
    exception
      when others then
        if sqlerrm <> 'g16_01_deshacer' then
          v_fallos := v_fallos || format(E'\n  · %s: el andamio falló: %s', e[1], sqlerrm);
        elsif v_last is distinct from e[6] then
          v_fallos := v_fallos || format(E'\n  · %s: esperado %s, obtenido %s', e[1], e[6], v_last);
        end if;
    end;
  end loop;

  if v_fallos <> '' then
    raise exception 'g16_01 conducta: fallaron escenarios (de %):%', v_n, v_fallos;
  end if;
  raise notice 'g16_01 OK · %/% escenarios · el reintento del mismo teléfono termina; lo ajeno y lo escrito siguen bloqueando.', v_n, v_n;
end $conducta$;
