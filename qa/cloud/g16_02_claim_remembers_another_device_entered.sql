-- =====================================================================================================
-- g16_02 · el reintento de un alta ya no siembra al lado de un teléfono que entró en la cuenta
--
-- QUÉ GANA EL USUARIO. Activa la nube en el iPhone A y se corta la red justo al final. Mientras tanto entra
-- con la misma cuenta en el iPhone B («Ya tengo cuenta»): la cuenta está vacía y B arranca de cero. Vuelve a A
-- y toca «Reintentar». Hasta hoy A también sembraba y la nube acababa con dos juegos de cuentas y categorías.
-- Ahora el reintento de A ve que B ya entró y no siembra: A entra en la cuenta de B, como cualquier segundo
-- teléfono.
--
-- Ticket: `claim-replay-can-seed-beside-a-phone-that-adopted-silently` (el Paso 0 del encargo tiene las
-- decisiones). Residual de la review de g16_01.
--
-- === LA VENTANA, MEDIDA ===
--   Todo adopt pasa por `POST /account/claim` antes de terminar (`MigrationWorkExecutor.performClaim`, con
--   `migration: true` y el `device_id` de B; es el 22 % de la barra). Sobre la cuenta que A promocionó
--   —`complete`, líder A, sin migración— ese claim caía en la rama final y contestaba `existing_stable` SIN
--   ESCRIBIR NADA. La primera huella de B en el servidor era su primera subida, y la rama g16_01 solo miraba
--   `sync_seq_counters`: entre las dos, el reintento de A leía una cuenta vacía y repetía `created`.
--
-- === EL CAMBIO ===
--   1. Columna `profiles.personal_adopted_at`: «otro dispositivo pidió lo personal de esta cuenta y se le dijo
--      que ya existía». Nula en todas las filas de hoy.
--   2. La rama final de `claim_account` (la que contesta `existing_stable` a un claim personal) la estampa si
--      el claim lleva `migration` y quien llama NO es el líder apuntado. Solo el primer sello
--      (`where personal_adopted_at is null`): el adopt re-reclama en cada re-kick y no hay por qué reescribir la
--      fila cada vez. No mira `kind`: una cuenta revertida también puede quedar sellada, y no importa, porque la
--      rama g16_01 ya exige `complete`.
--      Por qué `migration`: es el claim con el que ENTRA un segundo teléfono. Toda entrada real acaba en el
--      adopt (`performClaim`, `migration: true`): «Ya tengo cuenta», la tarjeta de Almacenamiento, Grupos, y
--      también «Soy nuevo → nube», cuyo claim sin migración devuelve `existing_stable` y sigue al adopt en el
--      mismo flujo. Un claim sin migración que recibe `existing_stable` y NO sigue —«Activar Yala completo»
--      desde otro teléfono solo-grupos, que se queda en «Tu cuenta ya tiene finanzas personales»— no entra, y
--      sellarlo bloqueaba a los dos teléfonos sobre una cuenta vacía (lo cazó la review).
--      No estampa: un claim `groups_only` (sale antes, no entra en lo personal), el propio líder (su adopt o su
--      reintento son suyos) ni un `claiming_in_progress` (el seguidor de una migración, que ya escribe).
--   3. La rama g16_01 exige además `personal_adopted_at is null`.
--   Sin candado a propósito: si el reintento de A lee la fila antes de que el sello de B se confirme, A recibe
--   `created` y B `existing_stable` — exactamente lo mismo que si A hubiera llegado primero. Un `for update` solo
--   movería ese empate de milisegundos, y la sonda no puede probarlo (lo cazó la review).
--
-- === LO QUE QUEDA FUERA, ESCRITO ===
--   · A reintenta ANTES de que B entre: A siembra y B entra después en una cuenta que ya es de A. Es la carrera de
--     siempre entre dos teléfonos sobre una cuenta recién creada, anterior a g16_01.
--   · «Soy nuevo → nube» en B hace primero un claim SIN migración (no sella) y segundos después el del adopt: un
--     reintento de A entre los dos todavía recibe `created`. Es el mismo caso que el anterior.
--   · «Migrar a la nube» también manda `migration: true`. Si B lo toca sobre esta cuenta y se le rechaza, no
--     entra pero sella. Es raro: la comprobación de identidad de «Migrar» ya para ANTES del claim cuando
--     `/account/exists` dice `complete`, así que solo pasa si A promociona justo entre esa pregunta y el claim de B.
--     El servidor no puede distinguirlo porque el cliente no manda la intención. Coste: A bloquea y entra por el
--     adopt en una cuenta vacía.
--
-- === POR QUÉ NO SE BORRA ===
--   Un B que entró y luego canceló deja la cuenta sellada: el reintento de A bloquea y A entra por el adopt en
--   esa misma cuenta vacía. Bloquear de más cuesta un adopt; sembrar de más, un corpus duplicado. Es el criterio
--   que g16_01 ya aplica a «otro teléfono con el alta en curso». La fila muere entera con el borrado de cuenta
--   (g5_01/g12_01), y con ella el sello.
--
-- === APLICACIÓN ===
--   NO trae `begin;`/`commit;`: `apply_migration` ya envuelve en transacción. Por psql, con `-1`.
--   La firma NO cambia: sin `drop function`, sin grants que re-otorgar, sin deploy del Worker. La columna nueva
--   hereda los grants de tabla de `profiles` y la policy `profiles_update` (own-row) cubre el UPDATE del RPC,
--   que es SECURITY INVOKER. El §1 termina con `notify pgrst, 'reload schema'`, como g15_01: sin él PostgREST
--   puede no ver la columna nueva hasta recargar su caché.
--
--     cuerpo vivo                                   | qué hace
--     ----------------------------------------------|--------------------------------------------
--     md5 e7f8bec957091abaa126d8100a3a53bd (g16_01)  | la columna + la sustitución + §3 + §4
--     md5 ab0e59d094fe7d7324d3ea79b4861965 (final)  | no-op, pero el §3 y el §4 corren IGUAL
--     cualquier otro                                | ABORTA
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
    raise exception 'g16_02: hay % firmas de claim_account, tiene que haber 1. Abortada.', v_firmas;
  end if;

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';

  if md5(v_src) = 'e7f8bec957091abaa126d8100a3a53bd' then
    perform set_config('yala.g16_02_estado', 'virgen', true);
  elsif md5(v_src) = 'ab0e59d094fe7d7324d3ea79b4861965' then
    perform set_config('yala.g16_02_estado', 'final', true);
    raise notice 'g16_02: el sello ya está en el cuerpo vivo (md5 %). No-op; el §3 y el §4 corren igual.', md5(v_src);
  else
    raise exception 'g16_02: claim_account no es el cuerpo esperado (md5 %). Abortada.', md5(v_src);
  end if;
end $guard$;

-- ── 1 · La columna ───────────────────────────────────────────────────────────────────────────────────
alter table public.profiles add column if not exists personal_adopted_at timestamptz;
comment on column public.profiles.personal_adopted_at is
  'g16_02: primera vez que un dispositivo que no es el líder entró en lo personal de esta cuenta (claim personal '
  'con migration —el adopt— respondido con existing_stable). Lo estampa claim_account; la rama g16_01 no repite '
  '`created` si no es nula.';
notify pgrst, 'reload schema';

-- ── 2 · La transformación ────────────────────────────────────────────────────────────────────────────
-- Se parte del cuerpo VIVO y se sustituyen cuatro bloques exactos, cada uno una sola vez (el molde de g16_01).
do $mig$
declare
  v_src text;
  v_new text;
  v_pares text[][] := array[
    -- a) la variable del sello
    array[
$o$  v_kind      text;
$o$,
$n$  v_kind      text;
  v_adopted   timestamptz;
$n$],
    -- b) la lectura que clasifica también lee el sello
    array[
$o$  select migration_in_progress, leader_device_id, migrated_at, reverse_in_progress, provider, migration_updated_at, personal_claimed_at, kind
    into v_mip, v_leader, v_migrated, v_reverse, v_provider, v_updated, v_pca, v_kind
    from public.profiles where id = v_uid;$o$,
$n$  select migration_in_progress, leader_device_id, migrated_at, reverse_in_progress, provider, migration_updated_at, personal_claimed_at, kind, personal_adopted_at
    into v_mip, v_leader, v_migrated, v_reverse, v_provider, v_updated, v_pca, v_kind, v_adopted
    from public.profiles where id = v_uid;$n$],
    -- c) la rama g16_01 mira el sello
    array[
$o$        and not exists (select 1 from public.sync_seq_counters where user_id = v_uid) then$o$,
$n$        and not exists (select 1 from public.sync_seq_counters where user_id = v_uid)
        and v_adopted is null then$n$],
    -- d) la rama final lo estampa
    array[
$o$  else
    return jsonb_build_object(
      'state', 'existing_stable',$o$,
$n$  else
    -- g16_02: el claim de ENTRADA (con `migration`: el adopt) de un dispositivo que no es el líder recibe
    -- `existing_stable`: ese teléfono va a entrar en esta cuenta. Se deja constancia en el servidor, porque su
    -- primera subida puede no llegar nunca, y sin ella la rama g16_01 dejaba al líder volver a sembrar al lado.
    -- Sin `migration` no: ese claim puede quedarse fuera («Activar Yala completo» bloqueado). Solo el primer
    -- sello. Ticket `claim-replay-can-seed-beside-a-phone-that-adopted-silently`.
    if p_migration and v_leader is distinct from p_device_id then
      update public.profiles set personal_adopted_at = now()
        where id = v_uid and personal_adopted_at is null;
    end if;
    return jsonb_build_object(
      'state', 'existing_stable',$n$]
  ];
  par text[];
begin
  if coalesce(current_setting('yala.g16_02_estado', true), '') <> 'virgen' then
    return;
  end if;

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';
  v_new := v_src;

  foreach par slice 1 in array v_pares loop
    if (length(v_new) - length(replace(v_new, par[1], ''))) / length(par[1]) <> 1 then
      raise exception 'g16_02: el bloque «%…» no aparece exactamente una vez en claim_account. Abortada.',
        left(ltrim(par[1]), 40);
    end if;
    v_new := replace(v_new, par[1], par[2]);
  end loop;

  -- Misma firma y mismos defaults que g15_01/g16_01: `create or replace` conserva los grants.
  execute format(
    'create or replace function public.claim_account(p_device_id text, p_provider text, p_migration boolean default false, p_kind text default %L) returns jsonb language plpgsql set search_path = public as %L',
    'complete', v_new);
end $mig$;

-- ── 3 · Verificación ESTRUCTURAL ─────────────────────────────────────────────────────────────────────
do $verify$
declare
  v_src    text;
  v_n      int;
  v_marca  text;
begin
  select count(*) into v_n from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';
  if v_n <> 1 then raise exception 'g16_02 verify: % firmas de claim_account', v_n; end if;

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';
  foreach v_marca in array array[
    'v_adopted   timestamptz;',
    'kind, personal_adopted_at',
    E'where user_id = v_uid)\n        and v_adopted is null then',
    'if p_migration and v_leader is distinct from p_device_id then',
    'where id = v_uid and personal_adopted_at is null;',
    '-- g16_01: el MISMO teléfono reintenta'
  ] loop
    if (length(v_src) - length(replace(v_src, v_marca, ''))) / length(v_marca) <> 1 then
      raise exception 'g16_02 verify: «%» no está exactamente una vez', v_marca;
    end if;
  end loop;

  -- `create or replace` reescribe los atributos: tiene que seguir siendo SECURITY INVOKER con search_path fijo
  -- (la rama g16_01 lee el contador POR RLS, y el sello se escribe con la policy own-row).
  select count(*) into v_n from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account'
      and not p.prosecdef and p.proconfig = array['search_path=public'];
  if v_n <> 1 then
    raise exception 'g16_02 verify: claim_account ya no es SECURITY INVOKER con search_path=public';
  end if;

  select count(*) into v_n from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'personal_adopted_at'
      and data_type = 'timestamp with time zone';
  if v_n <> 1 then raise exception 'g16_02 verify: falta profiles.personal_adopted_at (timestamptz)'; end if;

  -- El cuerpo que sale tiene que ser el que se midió en el banco (la sonda de abajo, contra ESE cuerpo, más un
  -- mutante por término). Otro md5 es que la transformación no hizo lo que se probó.
  if md5(v_src) <> 'ab0e59d094fe7d7324d3ea79b4861965' then
    raise exception 'g16_02 verify: md5 de llegada % distinto del medido en el banco', md5(v_src);
  end if;
  raise notice 'g16_02 · claim_account md5 de llegada: %', md5(v_src);
end $verify$;

-- ── 4 · Verificación de COMPORTAMIENTO ───────────────────────────────────────────────────────────────
-- El molde del §3 de g16_01, con una llamada INTERMEDIA (el otro teléfono) y el sello como segunda salida.
-- Cada escenario vive en su propio savepoint y lo deshace al acabar: no deja filas —tampoco las de los
-- triggers— y el rol y las GUC vuelven a su valor.
--
-- Columnas: etiqueta | partida | escritura | 1.ª llamada | intermedia | 2.ª llamada | esperado de la 2.ª |
--           rol desde la intermedia | sello al final (set / null).
-- Llamadas `dispositivo:tipo`: D = el que reintenta, O = otro; f = personal sin migración, t = personal con
-- migración (el adopt), g = `groups_only`; la intermedia admite varias con `+`, en orden. Los 13 primeros son los
-- de g16_01, que tienen que seguir dando lo mismo.
do $conducta$
declare
  v_uid     uuid;
  v_ret     jsonb;
  v_last    text;
  v_sello   text;
  v_fallos  text := '';
  v_n       int := 0;
  e         text[];
  v_call    text;
  escen text[][] := array[
    array['respuesta perdida tras la promoción → termina',                 'lite',      '-',        'D:f', '-',   'D:f', 'created',            'postgres',      'null'],
    array['lo mismo con el rol de PostgREST',                             'lite',      '-',        'D:f', '-',   'D:f', 'created',            'authenticated', 'null'],
    array['alta born-cloud con la respuesta perdida → siembra',           'none',      '-',        'D:f', '-',   'D:f', 'created',            'postgres',      'null'],
    array['otro teléfono ya tiene lo personal → bloquea',                 'lite',      'accounts', 'O:f', '-',   'D:f', 'existing_stable',    'postgres',      'null'],
    array['otro teléfono, cuenta aún vacía (su alta en curso) → bloquea', 'lite',      '-',        'O:f', '-',   'D:f', 'existing_stable',    'postgres',      'null'],
    array['mismo teléfono, ya subió transacciones → bloquea',             'lite',      'tx_items', 'D:f', '-',   'D:f', 'existing_stable',    'postgres',      'null'],
    array['lo mismo con el rol de PostgREST (RLS del contador)',          'lite',      'tx_items', 'D:f', '-',   'D:f', 'existing_stable',    'authenticated', 'null'],
    array['mismo teléfono, solo subió preferencias → bloquea',            'lite',      'prefs',    'D:f', '-',   'D:f', 'existing_stable',    'postgres',      'null'],
    array['una migración sobre la cuenta recién promovida → no replica',  'lite',      '-',        'D:f', '-',   'D:t', 'existing_stable',    'postgres',      'null'],
    array['cuenta que volvió a iCloud, vacía, mismo teléfono → bloquea',  'reverted',  '-',        '-',   '-',   'D:f', 'existing_stable',    'postgres',      'null'],
    array['vuelta a iCloud en curso, vacía, mismo teléfono → bloquea',    'reversing', '-',        '-',   '-',   'D:f', 'existing_stable',    'postgres',      'null'],
    array['migración en curso del mismo teléfono (rama vieja)',           'mip',       '-',        '-',   '-',   'D:t', 'created',            'postgres',      'null'],
    array['cuenta completa y vacía SIN líder apuntado → bloquea',         'noleader',  '-',        '-',   '-',   'D:f', 'existing_stable',    'postgres',      'null'],
    -- g16_02
    array['otro teléfono entra por el adopt → el reintento bloquea (criterio 1)',        'lite', '-', 'D:f', 'O:t', 'D:f', 'existing_stable', 'postgres',      'set'],
    array['lo mismo con el rol de PostgREST (el sello pasa por RLS)',                   'lite', '-', 'D:f', 'O:t', 'D:f', 'existing_stable', 'authenticated', 'set'],
    array['otro teléfono choca desde «Activar Yala completo» → no entra, no sella: el reintento termina', 'lite', '-', 'D:f', 'O:f', 'D:f', 'created', 'postgres', 'null'],
    array['otro teléfono: «Soy nuevo → nube» y su adopt → el reintento bloquea',         'lite', '-', 'D:f', 'O:f+O:t', 'D:f', 'existing_stable', 'postgres', 'set'],
    array['alta born-cloud perdida + otro teléfono entra → el reintento bloquea',       'none', '-', 'D:f', 'O:t', 'D:f', 'existing_stable', 'postgres',      'set'],
    array['otro teléfono solo se une por Grupos → el reintento termina (criterio 2)',   'lite', '-', 'D:f', 'O:g', 'D:f', 'created',         'postgres',      'null'],
    array['el mismo teléfono pasa por el adopt → su reintento termina',                 'lite', '-', 'D:f', 'D:t', 'D:f', 'created',         'postgres',      'null'],
    array['otro teléfono sigue una migración en curso → no sella',                      'mip',  '-', '-',   'O:t', 'D:t', 'created',         'postgres',      'null']
  ];
begin
  foreach e slice 1 in array escen loop
    v_n := v_n + 1;
    v_last := null;
    v_sello := null;
    begin
      v_uid := gen_random_uuid();
      insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
        values (v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
                'g16-02-verify-' || replace(v_uid::text, '-', '') || '@invalid.local', now(), now());

      perform set_config('yala.kind_write', txid_current()::text, true);
      if e[2] = 'lite' then
        insert into public.profiles (id) values (v_uid);
      elsif e[2] = 'reverted' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, reverted_at, leader_device_id)
          values (v_uid, 'apple', 'groups_only', now(), now(), 'g16-02-D');
      elsif e[2] = 'reversing' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, reverse_in_progress,
                                     leader_device_id, migration_updated_at)
          values (v_uid, 'apple', 'complete', now(), true, 'g16-02-D', now());
      elsif e[2] = 'noleader' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, leader_device_id)
          values (v_uid, 'apple', 'complete', now(), null);
      elsif e[2] = 'mip' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, migration_in_progress,
                                     leader_device_id, migration_updated_at)
          values (v_uid, 'apple', 'complete', now(), true, 'g16-02-D', now());
      end if;
      perform set_config('yala.kind_write', '', true);

      if e[2] = 'none' and exists (select 1 from public.profiles where id = v_uid) then
        raise exception 'la partida none ya trae fila en profiles';
      end if;

      perform set_config('request.jwt.claims',
                         json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

      -- 1.ª llamada: la que deja la huella (la promoción o el alta).
      if e[4] <> '-' then
        v_ret := public.claim_account(
          case split_part(e[4], ':', 1) when 'D' then 'g16-02-D' else 'g16-02-O' end, 'apple',
          split_part(e[4], ':', 2) = 't', 'complete');
        if v_ret->>'state' is distinct from 'created' then
          raise exception 'la 1.ª llamada devolvió %', v_ret;
        end if;
      end if;

      if e[3] in ('accounts', 'tx_items') then
        execute format('insert into public.%I (user_id, sync_id, hlc, server_seq) values ($1, gen_random_uuid(), $2, 0)', e[3])
          using v_uid, '0000000000001:0000:g16';
      elsif e[3] = 'prefs' then
        v_ret := public.apply_pref('g16_02.probe', 'x', '0000000000001:0000:g16');
      end if;

      if e[8] = 'authenticated' then
        perform set_config('role', 'authenticated', true);
      end if;

      -- Intermedia: el otro teléfono (o el mismo) entra. Su desenlace no se exige: lo que se mide es qué deja.
      if e[5] <> '-' then
        foreach v_call in array string_to_array(e[5], '+') loop
          v_ret := public.claim_account(
            case split_part(v_call, ':', 1) when 'D' then 'g16-02-D' else 'g16-02-O' end, 'apple',
            split_part(v_call, ':', 2) = 't',
            case split_part(v_call, ':', 2) when 'g' then 'groups_only' else 'complete' end);
        end loop;
      end if;

      -- 2.ª llamada: el reintento.
      v_ret := public.claim_account(
        case split_part(e[6], ':', 1) when 'D' then 'g16-02-D' else 'g16-02-O' end, 'apple',
        split_part(e[6], ':', 2) = 't', 'complete');
      v_last := coalesce(v_ret->>'state', '<sin state>');

      -- Con el rol que tocara: `authenticated` ve su fila por la policy own-row.
      select case when personal_adopted_at is null then 'null' else 'set' end into v_sello
        from public.profiles where id = v_uid;

      raise exception 'g16_02_deshacer';
    exception
      when others then
        if sqlerrm <> 'g16_02_deshacer' then
          v_fallos := v_fallos || format(E'\n  · %s: el andamio falló: %s', e[1], sqlerrm);
        elsif v_last is distinct from e[7] then
          v_fallos := v_fallos || format(E'\n  · %s: esperado %s, obtenido %s', e[1], e[7], v_last);
        elsif v_sello is distinct from e[9] then
          v_fallos := v_fallos || format(E'\n  · %s: sello esperado %s, obtenido %s', e[1], e[9], v_sello);
        end if;
    end;
  end loop;

  if v_fallos <> '' then
    raise exception 'g16_02 conducta: fallaron escenarios (de %):%', v_n, v_fallos;
  end if;
  raise notice 'g16_02 OK · %/% escenarios · quien entra deja huella y el reintento del líder ya no siembra a su lado.', v_n, v_n;
end $conducta$;
