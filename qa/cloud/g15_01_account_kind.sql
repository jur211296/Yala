-- =====================================================================================================
-- g15_01 · el backend sabe decir si una cuenta es «completa» o «solo grupos»
--
-- QUÉ GANA EL USUARIO. Entra con su cuenta de Google en un móvil recién instalado y Yala ya sabe si esa
-- cuenta lleva sus finanzas personales o solo sus grupos. Hasta hoy lo deducía de una preferencia LOCAL
-- (`storageMode`) que en un móvil nuevo no existe, así que cada puerta se lo inventaba a su manera: «Ya
-- tengo cuenta» adoptaba como completa a quien solo tenía grupos, y «Vengo por un grupo» trataba como
-- solo-grupos a quien tenía años de datos en la nube.
--
-- DECISIÓN (Jürgen, 2026-09-09). Columna `kind` EXPLÍCITA, aunque `personal_claimed_at` ya diera casi la
-- misma señal, con el riesgo de dos verdades sabido y aceptado: quien toque una ruta que cambie el tipo
-- de cuenta mantiene las dos coherentes, y los tests cubren esa coherencia.
--
-- === LO MEDIDO QUE CONVIERTE ESA REDUNDANCIA EN NECESIDAD (2026-09-10) ===
--   La decisión daba por hecho que `personal_claimed_at` clasifica bien. Es cierto para las cuentas de
--   HOY y falso en general, y la diferencia es justo el caso que este ticket tiene que soportar: la rama
--   `reverse_complete` de `migration_progress` (cuerpo vivo, medido) estampa `reverted_at` y **NO toca
--   `personal_claimed_at`** — igual que no toca `migrated_at`, y por el mismo motivo declarado (§h.4).
--   ⇒ una cuenta que vuelve a iCloud conserva `personal_claimed_at` no nulo y debe quedar `groups_only`.
--   Ese es el estado que la señal vieja no sabe expresar, y por eso el backfill de abajo mira las DOS
--   columnas. Sobre los corpus de hoy da el mismo resultado que la fórmula de la decisión (cero filas
--   con `reverted_at` en ambos entornos): no cambia ningún número medido, cambia el futuro.
--
-- === POR QUÉ HAY UN TRIGGER Y NO SOLO UNA COLUMNA ===
--   El ticket pide `kind` «escribible solo por RPC». Añadir la columna NO lo consigue: los grants de
--   `profiles` son a nivel TABLA (`authenticated=arwDxtm/postgres`, ninguna columna con ACL propia), así
--   que una columna nueva HEREDA INSERT/SELECT/UPDATE, y la policy `profiles_update` (`auth.uid() = id`)
--   deja al dueño escribirla. Sin nada más, cualquiera se auto-promueve con un PATCH a PostgREST.
--
--   Se cierra con un trigger + guard de transacción, NO regenerando los grants por columna: pasar el
--   UPDATE de `profiles` a por-columna dejaría sin grant a toda columna futura, y ese síntoma es un push
--   en noop SILENCIOSO — el incidente de `created_at` en G2 que g14_01 documenta. El guard
--   `set_config('yala.kind_write', ..., true)` es LOCAL a la transacción y PostgREST no expone GUCs
--   arbitrarias al cliente, así que no se puede abrir desde fuera.
--
--   Verificado en sandbox transaccional contra staging antes de escribir esto, con control negativo Y
--   positivo (los cinco casos):
--     · el dueño hace `update profiles set kind='complete'`  → RECHAZADO (yala_kind_readonly)
--     · el dueño hace `insert into profiles (id, kind) values (…, 'complete')` → RECHAZADO
--     · la misma escritura dentro de una RPC que abre el guard → pasa
--     · `insert into profiles (id) values (…)` de create_group/join_group → pasa, kind='groups_only'
--     · `update` de OTRA columna → pasa (no se rompe ninguna escritura existente)
--
-- === LO QUE ESTA MIGRACIÓN NO PONE, Y ES DELIBERADO ===
--   NO hay check cruzado `kind <> 'complete' or personal_claimed_at is not null`. Parecía gratis y
--   rompía un golden VIVO: `account.goldens.test.ts` (bloque g3_02) simula la fila ligera con
--   `patchProfile(jwtA, { personal_claimed_at: null, … })` y espera `< 300`; con ese check, ese PATCH
--   sobre una fila `complete` daría 400. Medido en sandbox: sin el check, el golden pasa. La coherencia
--   entre las dos columnas queda donde Jürgen la puso — en las rutas y en los tests.
--
-- === LA FIRMA DE claim_account CAMBIA, ASÍ QUE HAY DROP ===
--   `create or replace function` con una lista de parámetros distinta CREA UNA SOBRECARGA, no reemplaza.
--   Con `claim_account(text,text,boolean)` y `claim_account(text,text,boolean,text)` vivas a la vez, una
--   llamada de PostgREST con 3 argumentos nombrados casa con las DOS y devuelve PGRST203 («could not
--   choose the best candidate function») — o sea, el claim entero caído. Por eso se dropea la vieja y se
--   re-otorgan los grants explícitamente, dentro de la misma transacción.
--
-- === migration_progress SE TRANSFORMA, NO SE RE-PEGA ===
--   El cambio real son 4 líneas dentro de una función de 9,6 KB. Pegarla entera a mano para cambiar 4
--   líneas es como nació el drift que g13_05 tuvo que cerrar. Se parte de la definición VIVA, se
--   sustituye el bloque exacto y se verifica md5 de partida y de llegada: determinista o ruidosa.
--
-- === APLICACIÓN ===
--   Este fichero NO trae `begin;`/`commit;`: `apply_migration` ya envuelve en transacción (y anidarlos
--   cerraría la externa antes de tiempo — la desviación que documentó el runbook con g14_01). Por psql,
--   aplícalo con `-1`.
--
--   md5 de partida (IDÉNTICOS en staging y producción, verificado el 2026-09-10):
--     claim_account(text,text,boolean)   41cad9ea61307687981cd9e9f8e99640   (3971 chars)
--     migration_progress(text,text)      cfb6e415d0f731639709e8cbd0cfeaf9   (9638 chars)
-- =====================================================================================================

-- ── 0 · Guarda de partida ────────────────────────────────────────────────────────────────────────────
do $guard$
declare
  v_claim text;
  v_mig   text;
begin
  select md5(prosrc) into v_claim from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';
  select md5(prosrc) into v_mig   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'migration_progress';

  if v_claim is distinct from '41cad9ea61307687981cd9e9f8e99640' then
    raise exception 'g15_01: claim_account no es el cuerpo esperado (md5 %). Abortada.', coalesce(v_claim, '<ausente>');
  end if;
  if v_mig is distinct from 'cfb6e415d0f731639709e8cbd0cfeaf9' then
    raise exception 'g15_01: migration_progress no es el cuerpo esperado (md5 %). Abortada.', coalesce(v_mig, '<ausente>');
  end if;
end $guard$;

-- ── 1 · La columna ───────────────────────────────────────────────────────────────────────────────────
-- Se recuerda si la columna NACE aquí: de eso depende que el backfill de abajo corra o no (§2).
do $nace$
begin
  perform set_config(
    'yala.kind_backfill',
    case when exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'profiles' and column_name = 'kind'
    ) then 'no' else 'si' end,
    true);
end $nace$;

alter table public.profiles
  add column if not exists kind text not null default 'groups_only';

do $c$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_kind_check') then
    alter table public.profiles
      add constraint profiles_kind_check check (kind in ('complete', 'groups_only'));
  end if;
end $c$;

comment on column public.profiles.kind is
  'Tipo de cuenta: complete (lleva finanzas personales) | groups_only. Escribible SOLO por RPC — lo impone el trigger profiles_kind_guard. ADR 2026-09-09 «Sesiones — dos ejes» §11.';

-- ── 2 · Backfill ─────────────────────────────────────────────────────────────────────────────────────
-- `reverted_at` es la mitad que la decisión no nombraba: una cuenta que volvió a iCloud conserva
-- personal_claimed_at y ya NO es completa.
--
-- UN CASO QUE ESTA FÓRMULA CLASIFICA COMO `complete` A PROPÓSITO: la migración de ida ABANDONADA
-- (`personal_claimed_at` se estampa al EMPEZAR, `migrated_at` solo en el cutover), o sea `mip=true` con
-- lease expirado y poco o nada en la nube. Se deja `complete` porque la alternativa es peor —marcarla
-- `groups_only` le quitaría a esa persona el acceso a lo suyo— y porque ese estado transitorio ya tiene
-- su propio canal: el claim devuelve `claiming_in_progress` y el cliente rutea a esperar/adoptar, sin
-- mirar `kind`. Población medida el 2026-09-10: CERO filas así en staging (5 perfiles) y en producción
-- (2 perfiles). Si algún día la hay, esto es lo que decidió tratarla como completa.
--
-- Abre el guard aunque en la PRIMERA aplicación el trigger todavía no exista: en una re-aplicación sí
-- existe, y sin esta línea la migración se abortaría a sí misma con `yala_kind_readonly`.
do $backfill$
begin
  -- SOLO en la aplicación que crea la columna. Es una migración de datos de una vez, no un
  -- reconciliador — y la diferencia costó un dato real: en staging, el usuario B de los goldens quedó
  -- `kind='groups_only'` con `reverted_at` NULO, porque `reverse_complete` lo degradó y un
  -- `reverse_claim` posterior reseteó `reverted_at` (§h.6) sin tocar `kind`. La fórmula de abajo lee
  -- ese estado como `complete`, así que una RE-aplicación le habría devuelto lo personal a la nube
  -- deshaciendo una degradación legítima, en silencio y sobre datos de producción.
  -- ⇒ `kind` es la verdad; esta fórmula solo sirve para inicializarla.
  if coalesce(current_setting('yala.kind_backfill', true), 'si') <> 'si' then
    raise notice 'g15_01: la columna kind ya existía — backfill OMITIDO (kind ya es la verdad)';
    return;
  end if;

  perform set_config('yala.kind_write', txid_current()::text, true);
  -- `reverse_in_progress` excluido: durante una reversa `reverse_claim` deja `reverted_at` en null
  -- (README §h.6, para que el run nuevo no herede los marcadores del anterior), así que la fórmula
  -- diría 'complete' a mitad de una degradación en curso. Una reversa viva no es momento de
  -- reclasificar: la clasifica su propio `reverse_complete`.
  update public.profiles
     set kind = case
                  when personal_claimed_at is not null and reverted_at is null then 'complete'
                  else 'groups_only'
                end
   where not reverse_in_progress
     and kind is distinct from case
                                 when personal_claimed_at is not null and reverted_at is null then 'complete'
                                 else 'groups_only'
                               end;
  perform set_config('yala.kind_write', '', true);
end $backfill$;

-- ── 3 · El guard ─────────────────────────────────────────────────────────────────────────────────────
-- El guard NO es el string 'on' sino el ID DE ESTA TRANSACCIÓN, y el motivo es un footgun concreto:
-- `set_config(..., is_local => false)` deja el GUC pegado al backend del pool de PostgREST, y la
-- siguiente petición —de CUALQUIER usuario— heredaría el guard abierto. Ningún test lo cazaría, porque
-- el comportamiento observable dentro de una petición es idéntico. Con `txid_current()`, un GUC filtrado
-- a otra transacción queda inerte por construcción: el token ya no coincide.
create or replace function public.tg_profiles_kind_guard()
returns trigger
language plpgsql
set search_path = public
as $fn$
declare
  v_abierto boolean := coalesce(current_setting('yala.kind_write', true), '') = txid_current()::text;
begin
  -- NO hay exención por rol, y se intentó una: `if session_user = 'postgres' then return new`, para que
  -- una reparación futura por `apply_migration` no se bloqueara. Medida con control negativo en
  -- transacción fresca, esa exención ABRÍA EL GUARD ENTERO en el único banco de pruebas que existe:
  -- `set local role authenticated` cambia `current_user` pero NO `session_user`, así que desde una
  -- conexión de administrador —que es como se aplican y se prueban las migraciones— los cuatro casos
  -- pasaban, incluido el que debía fallar. Un guard que no se puede probar no es un guard. Quien tenga
  -- que reparar `kind` a mano abre el guard como lo hace el backfill de arriba (una línea de
  -- `set_config`), o desactiva el trigger explícitamente.

  -- INSERT: la fila ligera de create_group/join_group nace con el DEFAULT y pasa sin guard. Cualquier
  -- otro valor (o sea: nacer 'complete') exige venir de una RPC.
  if tg_op = 'INSERT' then
    if new.kind <> 'groups_only' and not v_abierto then
      raise exception 'yala_kind_readonly' using errcode = 'P0001';
    end if;
    return new;
  end if;

  -- UPDATE: `kind` solo cambia dentro de una RPC. Las demás columnas siguen escribiéndose igual que hoy.
  if new.kind is distinct from old.kind and not v_abierto then
    raise exception 'yala_kind_readonly' using errcode = 'P0001';
  end if;
  return new;
end $fn$;

drop trigger if exists profiles_kind_guard on public.profiles;
create trigger profiles_kind_guard
  before insert or update on public.profiles
  for each row execute function public.tg_profiles_kind_guard();

-- ── 4 · claim_account gana `p_kind` ──────────────────────────────────────────────────────────────────
-- `p_kind` default 'complete': preserva a TODOS los llamadores de hoy (born-cloud y migración crean
-- cuentas completas). El alta de grupos manda 'groups_only' y entonces la cuenta NO estampa
-- personal_claimed_at: para lo personal esa cuenta todavía no ha nacido.
drop function if exists public.claim_account(text, text, boolean);

create function public.claim_account(
  p_device_id text,
  p_provider  text,
  p_migration boolean default false,
  p_kind      text default 'complete'
)
returns jsonb
language plpgsql
set search_path = public
as $claim$
declare
  v_uid       uuid := auth.uid();
  v_created   uuid;
  v_mip       boolean;
  v_leader    text;
  v_migrated  timestamptz;
  v_reverse   boolean;
  v_provider  text;
  v_updated   timestamptz;
  v_pca       timestamptz;
  v_kind      text;
  v_personal  boolean := (p_kind = 'complete');
begin
  if v_uid is null then
    raise exception 'claim_account: no auth.uid() (SECURITY INVOKER requires a user JWT)'
      using errcode = '28000';
  end if;

  if p_kind is null or p_kind not in ('complete', 'groups_only') then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  -- El guard de `kind` queda abierto durante TODA la función: es una transacción de PostgREST y
  -- ninguna otra escritura de esta función toca `kind`.
  perform set_config('yala.kind_write', txid_current()::text, true);

  -- Atomic reservation. p_migration=true arms the leader lease IN THE SAME INSERT (no kill window
  -- between the created row and a separate begin): migration_in_progress + heartbeat set atomically.
  -- Default false preserves the born-cloud contract and every existing 2-arg caller.
  -- `personal_claimed_at` SOLO se estampa en un alta personal: un alta de grupos crea la misma fila
  -- ligera que create_group/join_group.
  insert into public.profiles (id, provider, leader_device_id, migration_in_progress, migration_updated_at, personal_claimed_at, kind)
  values (
    v_uid, p_provider, p_device_id,
    p_migration,
    case when p_migration then now() else null end,
    case when v_personal then now() else null end,
    p_kind
  )
  on conflict (id) do nothing
  returning id into v_created;

  if v_created is not null then
    return jsonb_build_object('state', 'created', 'kind', p_kind);
  end if;

  -- Row already existed: classify its state (RLS restricts the SELECT to the caller's own row).
  select migration_in_progress, leader_device_id, migrated_at, reverse_in_progress, provider, migration_updated_at, personal_claimed_at, kind
    into v_mip, v_leader, v_migrated, v_reverse, v_provider, v_updated, v_pca, v_kind
    from public.profiles where id = v_uid;

  -- Un claim de grupos sobre una cuenta que YA existe no toca nada de lo personal: solo clasifica.
  -- Nunca degrada (§ADR: la única degradación es el reverse cutover).
  if not v_personal then
    return jsonb_build_object(
      'state', 'existing_stable',
      'kind', v_kind,
      'profile', jsonb_build_object(
        'migrated_at', v_migrated,
        'migration_in_progress', v_mip,
        'reverse_in_progress', v_reverse,
        'provider', v_provider
      )
    );
  end if;

  -- PROMOCIÓN de fila ligera de grupos (personal_claimed_at NULL): para lo personal esta cuenta nace
  -- AHORA — estampar exactamente lo que el INSERT habría estampado y devolver 'created'. Guard
  -- `not v_mip` conservador: una fila con mip=true y pca NULL es teóricamente imposible post-backfill
  -- (solo este RPC arma mip y desde hoy siempre estampa pca) — si apareciera, cae a la lógica de
  -- lease/takeover de abajo en vez de promocionar a ciegas.
  if v_pca is null and not v_mip then
    update public.profiles
      set personal_claimed_at   = now(),
          provider              = p_provider,
          leader_device_id      = p_device_id,
          migration_in_progress = p_migration,
          migration_updated_at  = case when p_migration then now() else null end,
          kind                  = 'complete'
      where id = v_uid and personal_claimed_at is null;
    if found then
      return jsonb_build_object('state', 'created', 'kind', 'complete');
    end if;
    -- Carrera: otro claim promocionó entre el SELECT y el UPDATE → re-leer y clasificar normal.
    select migration_in_progress, leader_device_id, migrated_at, reverse_in_progress, provider, migration_updated_at, kind
      into v_mip, v_leader, v_migrated, v_reverse, v_provider, v_updated, v_kind
      from public.profiles where id = v_uid;
  end if;

  -- NO hay promoción para la cuenta que volvió a iCloud (`reverse_complete` la deja groups_only con
  -- `personal_claimed_at` intacto). Se intentó y se quitó: promoverla ahí contradiría al backfill de
  -- esta misma migración —que clasifica por (pca, reverted_at)— y una re-aplicación la degradaría sola.
  -- Volver a la nube después de una reversa es el RE-CUTOVER, que el diseño vigente declara diferido
  -- (`migration_progress`, §h.4: «reverted_at is the signal for the future re-cutover design»). Cuando
  -- ese diseño exista, `kind` se mueve con él. Las dos promociones que este ticket sí necesita
  -- —«Activar Yala completo → nube» y «migrar a la nube» con cuenta asociada— tienen
  -- `personal_claimed_at` NULL y las cubre la rama de arriba.

  if v_mip and v_leader is distinct from p_device_id then
    -- Lease expiry (§g.1): a leader silent for >60 min can be TAKEN OVER — but ONLY by another
    -- MIGRATION caller (p_migration=true). A born-cloud/returning-user caller must NEVER usurp a
    -- half-migrated account (SERIO 2 of the adversarial review): it gets claiming_in_progress and
    -- routes to wait/adopt, never seeds. A NULL heartbeat (legacy row) never expires.
    if p_migration and v_updated is not null and v_updated < now() - interval '60 minutes' then
      update public.profiles
        set leader_device_id = p_device_id, migration_updated_at = now()
        where id = v_uid;
      return jsonb_build_object('state', 'created', 'kind', v_kind);  -- takeover: this device now leads
    end if;
    return jsonb_build_object('state', 'claiming_in_progress', 'kind', v_kind);
  elsif v_mip and v_leader = p_device_id then
    return jsonb_build_object('state', 'created', 'kind', v_kind);  -- idempotent reclaim by the same leader
  else
    return jsonb_build_object(
      'state', 'existing_stable',
      'kind', v_kind,
      'profile', jsonb_build_object(
        'migrated_at', v_migrated,
        'migration_in_progress', v_mip,
        'reverse_in_progress', v_reverse,
        'provider', v_provider
      )
    );
  end if;
end $claim$;

grant execute on function public.claim_account(text, text, boolean, text) to public;
grant execute on function public.claim_account(text, text, boolean, text) to anon;
grant execute on function public.claim_account(text, text, boolean, text) to authenticated;
grant execute on function public.claim_account(text, text, boolean, text) to service_role;
grant execute on function public.claim_account(text, text, boolean, text) to postgres;

-- ── 5 · La única degradación: reverse_complete ───────────────────────────────────────────────────────
do $mig$
declare
  v_src text;
  v_new text;
  v_old_block constant text :=
'    update public.profiles
      set reverse_in_progress  = false,
          reverted_at          = coalesce(reverted_at, now()),
          migration_updated_at = now()
      where id = v_uid;';
  v_new_block constant text :=
'    -- g15_01: lo personal vuelve a iCloud ⇒ la cuenta queda de GRUPOS. Es la ÚNICA degradación
    -- complete → groups_only del sistema (ADR 2026-09-09 §11 + fila E de la matriz de escenarios).
    perform set_config(''yala.kind_write'', txid_current()::text, true);
    update public.profiles
      set reverse_in_progress  = false,
          reverted_at          = coalesce(reverted_at, now()),
          migration_updated_at = now(),
          kind                 = ''groups_only''
      where id = v_uid;
    perform set_config(''yala.kind_write'', '''', true);';
begin
  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'migration_progress';

  if position(v_old_block in v_src) = 0 then
    raise exception 'g15_01: no encuentro el bloque de reverse_complete en migration_progress. Abortada.';
  end if;
  if (length(v_src) - length(replace(v_src, v_old_block, ''))) / length(v_old_block) <> 1 then
    raise exception 'g15_01: el bloque de reverse_complete aparece más de una vez. Abortada.';
  end if;

  v_new := replace(v_src, v_old_block, v_new_block);
  execute format(
    'create or replace function public.migration_progress(p_device_id text, p_action text) returns jsonb language plpgsql set search_path = public as %L',
    v_new);
end $mig$;

-- ── 6 · Verificación ─────────────────────────────────────────────────────────────────────────────────
do $verify$
declare
  v_col        int;
  v_trg        int;
  v_firmas     int;
  v_mig_kind   int;
  v_incoherent int;
  v_kinds      text;
begin
  select count(*) into v_col from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'kind';
  if v_col <> 1 then raise exception 'g15_01 verify: la columna kind no está'; end if;

  select count(*) into v_trg from pg_trigger where tgname = 'profiles_kind_guard' and not tgisinternal;
  if v_trg <> 1 then raise exception 'g15_01 verify: el trigger no está (o está duplicado): %', v_trg; end if;

  -- Una sola firma viva de claim_account, o PostgREST devuelve PGRST203 y el claim entero cae.
  select count(*) into v_firmas from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_account';
  if v_firmas <> 1 then raise exception 'g15_01 verify: hay % firmas de claim_account, tiene que haber 1', v_firmas; end if;

  -- La degradación entró de verdad en el cuerpo nuevo.
  select count(*) into v_mig_kind from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'migration_progress'
      and p.prosrc like '%kind                 = ''groups_only''%';
  if v_mig_kind <> 1 then raise exception 'g15_01 verify: reverse_complete no degrada'; end if;

  -- Backfill: ninguna fila contradice a las dos columnas de las que sale.
  -- La coherencia con la fórmula se comprueba SOLO cuando el backfill acaba de correr. No es un
  -- invariante permanente y tratarlo como tal abortaría la migración sobre una base sana: una cuenta
  -- degradada por `reverse_complete` a la que luego un `reverse_claim` le reseteó `reverted_at`
  -- discrepa de la fórmula y está PERFECTAMENTE clasificada (medido en staging el 2026-09-10).
  if coalesce(current_setting('yala.kind_backfill', true), 'si') = 'si' then
    select count(*) into v_incoherent from public.profiles
      where not reverse_in_progress
        and kind <> case when personal_claimed_at is not null and reverted_at is null then 'complete' else 'groups_only' end;
    if v_incoherent <> 0 then raise exception 'g15_01 verify: % filas mal clasificadas', v_incoherent; end if;
  end if;

  select string_agg(kind || '=' || n, ', ' order by kind) into v_kinds
    from (select kind, count(*) as n from public.profiles group by kind) x;
  raise notice 'g15_01 OK · reparto de kind: %', coalesce(v_kinds, '(cero filas)');
end $verify$;

-- ── 7 · Que PostgREST vea la columna ─────────────────────────────────────────────────────────────────
-- PostgREST cachea el esquema. Sin esta señal, `select=id,kind` sigue dando 400 («column does not
-- exist») hasta que el pool se recicle solo, y esa ventana se ve desde la app como 502 en
-- `/account/exists`. Es la mitad barata de la regla de despliegue: la BASE de un entorno va SIEMPRE
-- antes que su Worker, y el Worker no sale hasta que esto ha corrido.
notify pgrst, 'reload schema';
