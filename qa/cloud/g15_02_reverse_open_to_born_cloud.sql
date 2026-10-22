-- =====================================================================================================
-- g15_02 · «Volver a iCloud» se abre a quien nació en la nube
--
-- QUÉ GANA EL USUARIO. Creó su cuenta de Yala con Google, la usó meses, y un día decide que prefiere que
-- sus finanzas vivan solo en su iCloud privado. Hasta hoy no tenía salida: el backend rechazaba la
-- operación y la única forma de dejar la nube era borrar la cuenta y empezar de cero. A partir de aquí
-- recorre el mismo camino que un usuario migrado.
--
-- DECISIÓN (Jürgen, 2026-09-10): la reversa se ABRE a las cuentas born-cloud. Ver el ticket
-- `reverse-cutover-cerrado-para-cuentas-born-cloud` §Paso 0.
--
-- === EL CAMBIO: LA PUERTA LA ABRE EL TIPO DE CUENTA, NO EL HABER MIGRADO ===
--   Hoy `reverse_claim` arranca con `if v_migrated is null → not_migrated`, y `migrated_at` **solo lo
--   estampa el `cutover`**. Tras el fresh start del 2026-09-10 toda cuenta nueva nace en la nube, así que
--   ese guard cierra la fila E de la matriz de escenarios para la población entera — la fila que el ADR
--   del 2026-09-09 apoya como ÚNICA degradación `complete → groups_only` del sistema.
--
--   Pasa a rechazar solo a quien **no es `complete` y nunca revirtió**:
--
--       if v_kind is distinct from 'complete' and v_reverted is null then → not_complete
--
-- === LAS DOS MITADES DEL GUARD, Y POR QUÉ HACEN FALTA LAS DOS ===
--   **`kind <> 'complete'`** es la pregunta de producto: `kind` es la columna que el ADR §11 puso para
--   contestar «¿esta cuenta lleva finanzas personales?», que es exactamente lo que la reversa devuelve. Una
--   cuenta de solo grupos no tiene nada que llevar a iCloud.
--
--   **`and v_reverted is null`** es la mitad que una review adversarial rescató, y sin ella el cambio
--   ROMPÍA multi-device. Medido contra staging el 2026-09-10: `reverse_complete` degrada a `groups_only`,
--   así que un SEGUNDO dispositivo de esa misma cuenta —que sigue en modo nube, con `/sync/push`
--   respondiendo 409 porque el backend quedó congelado (§h.4)— recibía `not_complete` al pedir su propia
--   vuelta a iCloud. Y `.rejected` no tiene desatascador en el cliente: la fase se queda en
--   `reverseClaimLeader`, la barra clavada en 15 % y «Retomar» sin efecto, **para siempre**. Con el guard
--   viejo ese device convergía. ⇒ `reverted_at` no nulo significa «esta cuenta YA volvió a iCloud», y el
--   device que llega detrás tiene derecho a seguirla: no se le cierra la puerta.
--
--   Lo que sí queda cerrado —y era el objetivo de esa mitad— es la cuenta de solo grupos que **nunca**
--   revirtió: antes recibía `not_migrated`, o sea acertaba por el motivo equivocado.
--
-- === POR QUÉ ESTO NO ROMPE EL TAKEOVER DE UNA MIGRACIÓN ABANDONADA (golden 12) ===
--   Porque la promoción `groups_only → complete` de `claim_account` escribe `kind = 'complete'` en el
--   MISMO UPDATE que arma `migration_in_progress` (línea 80 de su cuerpo vivo), no al terminar. Una
--   migración abandonada por un líder crasheado entre `cutover` y `complete` —el modo de fallo real del
--   device run 2026-07-10— llega al takeover con `kind = 'complete'` y sigue pasando el guard.
--
-- === VERIFICADO ANTES DE ESCRIBIR ESTO ===
--   Sandbox transaccional contra STAGING (motor y esquema reales, `begin … rollback`, sin rastro:
--   md5 de vuelta al de partida y cero filas sintéticas), con **control negativo** —los mismos escenarios
--   contra la función VIVA— y positivo. El §3 de este fichero deja esa prueba EJECUTABLE, así que ya no
--   hay que creerse esta tabla:
--
--     escenario                                        | función VIVA          | función NUEVA
--     -------------------------------------------------|-----------------------|----------------------
--     born-cloud `complete` (migrated_at null)          | ✗ not_migrated        | ✓ ok, rip=true
--     migrada `complete` (control positivo)             | ✓ ok                  | ✓ ok
--     takeover: mip con lease VENCIDO (golden 12)       | ✓ ok, mip=false       | ✓ ok, mip=false
--     `groups_only` pura (nunca revirtió)               | ✗ not_migrated        | ✗ not_complete
--     `groups_only` YA revertida (2.º device)           | ✓ ok                  | ✓ ok  ← la mitad rescatada
--
-- === migration_progress SE TRANSFORMA, NO SE RE-PEGA (igual que g15_01) ===
--   Son 3 bloques dentro de una función de 10 KB. Se parte de la definición VIVA, se sustituye cada
--   bloque exacto y se verifica de dónde se sale y a dónde se llega: determinista o ruidosa.
--
--   `v_migrated` se retira ENTERA en vez de dejarla leída-y-sin-usar: una variable que nadie consulta es
--   el residuo que la próxima sesión reusa mal. No se pierde nada — `migrated_at` sigue en la tabla y
--   sigue siendo la red del §h.4; lo que deja de ser es la puerta.
--
-- === APLICACIÓN ===
--   NO trae `begin;`/`commit;`: `apply_migration` ya envuelve en transacción. Por psql, **`-1` NO es
--   opcional**: el §0 se comunica con el §1 y el §2 por una GUC local a la transacción, así que en
--   autocommit-por-sentencia el fichero no se comporta como está escrito.
--
--   **DOS estados de partida, y los dos tienen salida definida** (§0):
--
--     md5 de partida                     | estado              | qué hace
--     -----------------------------------|---------------------|-----------------------------------
--     6afd2433191c15f7fdb90984636a2f7c   | virgen (pre-g15_02) | las 3 sustituciones + §2 + §3
--     14fc5e2c54766dd7c5706966c7381f51   | ya aplicado         | no-op, pero el §3 corre IGUAL
--     cualquier otro                     | divergido           | ABORTA
--
--   Que el §3 corra también en la rama no-op es a propósito: convierte este fichero en una **sonda**
--   re-ejecutable del comportamiento del guard, no solo en un aplicador de una vez.
--
--   HISTORIAL DE APLICACIÓN, porque los md5 intermedios están en `supabase_migrations` y conviene poder
--   seguirlos: el 2026-09-10 esto entró en TRES pasos en ambos entornos —`g15_02` (guard sin la mitad de
--   `reverted_at`, md5 `41a4bfe0…`), `g15_02b` (la mitad rescatada por la review, `1945f634…`) y
--   `g15_02c` (higiene de una línea de comentario que `g15_02b` dejó cortada, `14fc5e2c…`)—. Este fichero
--   es el resultado, y desde un entorno virgen produce ese cuerpo final en un solo paso.
--   Los md5 fueron IDÉNTICOS en staging y producción en los tres pasos.
-- =====================================================================================================

-- ── 0 · Guarda de partida ────────────────────────────────────────────────────────────────────────────
-- Clasifica el cuerpo vivo en uno de los dos estados y deja el veredicto en una GUC transaccional.
-- El md5 se comprueba SIEMPRE, también en las ramas ya-aplicadas: un cuerpo que trae el guard nuevo pero
-- ha divergido en cualquier otro sitio no es «ya aplicada», es un cuerpo desconocido.
do $guard$
declare
  v_src text;
  v_md5 text;
begin
  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'migration_progress' and p.pronargs = 2;

  if v_src is null then
    raise exception 'g15_02: migration_progress(text,text) no existe. Abortada.';
  end if;
  v_md5 := md5(v_src);

  if v_md5 = '14fc5e2c54766dd7c5706966c7381f51' then
    perform set_config('yala.g15_02_estado', 'final', true);
    raise notice 'g15_02: el guard YA está en el cuerpo vivo. No-op (el §3 se ejecuta igual).';
  elsif v_md5 = '6afd2433191c15f7fdb90984636a2f7c' then
    perform set_config('yala.g15_02_estado', 'virgen', true);
  else
    raise exception 'g15_02: migration_progress no es ninguno de los 2 cuerpos esperados (md5 %). Abortada.', v_md5;
  end if;
end $guard$;

-- ── 1 · La transformación ────────────────────────────────────────────────────────────────────────────
do $mig$
declare
  v_src text;
  v_new text;
  v_estado text := coalesce(current_setting('yala.g15_02_estado', true), 'final');

  -- A · la declaración: `migrated_at` deja de gobernar, `kind` entra.
  v_decl_old text := $a_old$  v_migrated  timestamptz;
$a_old$;
  v_decl_new text := $a_new$  v_kind      text;
$a_new$;

  -- B · la lectura de estado (una sola query, la de la cabecera del RPC).
  v_sel_old text := $b_old$  select migration_in_progress, leader_device_id, reverse_in_progress, migrated_at, reverted_at, migration_updated_at
    into v_mip, v_leader, v_rip, v_migrated, v_reverted, v_updated$b_old$;
  v_sel_new text := $b_new$  select migration_in_progress, leader_device_id, reverse_in_progress, kind, reverted_at, migration_updated_at
    into v_mip, v_leader, v_rip, v_kind, v_reverted, v_updated$b_new$;

  -- C · el guard. Desde el cuerpo VIRGEN.
  v_grd_old text := $c_old$    -- Only a migrated account can reverse (born-cloud v1 excluded).
    if v_migrated is null then
      return jsonb_build_object('ok', false, 'reason', 'not_migrated');
    end if;$c_old$;

  v_grd_new text := $c_new$    -- g15_02: la puerta la abre el TIPO DE CUENTA, no el haber migrado. Una cuenta nacida en la
    -- nube tiene lo personal en el backend igual que una migrada, y `kind` es quien contesta «¿lleva
    -- finanzas personales?» (ADR 2026-09-09 §11).
    --
    -- La segunda mitad NO es cosmética: `reverse_complete` degrada a `groups_only`, así que sin ella un
    -- SEGUNDO dispositivo de una cuenta que ya volvió a iCloud —el suyo sigue en modo nube, con el
    -- backend congelado y `/sync/push` en 409— no podía reclamar su propia vuelta, y el cliente no tiene
    -- desatascador para un rechazo: barra clavada en 15 % para siempre. `reverted_at` no nulo dice «esta
    -- cuenta YA volvió», y quien llega detrás tiene derecho a seguirla.
    if v_kind is distinct from 'complete' and v_reverted is null then
      return jsonb_build_object('ok', false, 'reason', 'not_complete');
    end if;$c_new$;

  v_nombres text[] := array['declaración de v_migrated', 'select de estado', 'guard de reverse_claim'];
  v_viejos  text[];
  i int;
begin
  if v_estado = 'final' then
    return;
  end if;

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'migration_progress' and p.pronargs = 2;

  -- Cuerpo virgen: las tres sustituciones. Cada bloque tiene que aparecer EXACTAMENTE una vez — si
  -- aparece cero, el cuerpo no es el que creemos; si aparece dos, `replace` tocaría de más y en silencio.
  v_viejos := array[v_decl_old, v_sel_old, v_grd_old];
  for i in 1 .. array_length(v_viejos, 1) loop
    if position(v_viejos[i] in v_src) = 0 then
      raise exception 'g15_02: no encuentro el bloque «%» en migration_progress. Abortada.', v_nombres[i];
    end if;
    if (length(v_src) - length(replace(v_src, v_viejos[i], ''))) / length(v_viejos[i]) <> 1 then
      raise exception 'g15_02: el bloque «%» aparece más de una vez. Abortada.', v_nombres[i];
    end if;
  end loop;
  v_new := replace(replace(replace(v_src, v_decl_old, v_decl_new), v_sel_old, v_sel_new), v_grd_old, v_grd_new);

  -- Por si alguna rama futura hubiera empezado a usar `v_migrated`: quedaría sin declarar, y eso no es un
  -- error al CREAR la función (plpgsql compila el cuerpo en la primera llamada, no aquí) sino en la cara
  -- del primer usuario. El §2 lo remata ejecutándola.
  if position('v_migrated' in v_new) <> 0 then
    raise exception 'g15_02: v_migrated sigue usándose en el cuerpo nuevo. Abortada.';
  end if;

  execute format(
    'create or replace function public.migration_progress(p_device_id text, p_action text) returns jsonb language plpgsql set search_path = public as %L',
    v_new);
end $mig$;

-- ── 2 · Verificación ESTRUCTURAL ─────────────────────────────────────────────────────────────────────
do $verify$
declare
  v_src text;
  v_ret jsonb;
begin
  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'migration_progress' and p.pronargs = 2;

  if position($v$if v_kind is distinct from 'complete' and v_reverted is null then$v$ in v_src) = 0 then
    raise exception 'g15_02 verify: el guard completo no está en el cuerpo';
  end if;
  if position($v$'reason', 'not_complete'$v$ in v_src) = 0 then
    raise exception 'g15_02 verify: el reason not_complete no entró';
  end if;
  if position($v$'reason', 'not_migrated'$v$ in v_src) <> 0 then
    raise exception 'g15_02 verify: el guard viejo sigue vivo';
  end if;
  if position('v_migrated' in v_src) <> 0 then
    raise exception 'g15_02 verify: v_migrated sigue en el cuerpo';
  end if;

  -- La función SIGUE COMPILANDO. plpgsql valida el cuerpo entero —variables incluidas— en la primera
  -- llamada, así que sin ejecutarla una vez un nombre roto viajaría vivo hasta el primer usuario. Se
  -- llama con un `sub` sintético que NO tiene fila: sale por `no_profile` sin escribir nada, después de
  -- recorrer el prólogo, que es donde vive el select transformado. (Sin `sub` la función lanza 28000 por
  -- diseño, así que esa vía no distinguiría «no compila» de «no hay JWT».)
  perform set_config('request.jwt.claims',
                     json_build_object('sub', gen_random_uuid()::text)::text, true);
  v_ret := public.migration_progress('g15_02-verify', 'reverse_claim');
  if v_ret->>'reason' is distinct from 'no_profile' then
    raise exception 'g15_02 verify: la llamada de humo devolvió % (se esperaba no_profile)', v_ret;
  end if;
  perform set_config('request.jwt.claims', '', true);
end $verify$;

-- ── 3 · Verificación de COMPORTAMIENTO ───────────────────────────────────────────────────────────────
-- El §2 mira TEXTO, y un texto puede estar dentro de un comentario o detrás de un `return` previo: pasa
-- en verde sin que el guard se ejecute nunca. Esto ejercita las cinco poblaciones de la tabla del header
-- contra el motor real, con filas sintéticas que se borran ANTES de terminar el bloque.
--
-- **Probado en LAS DOS DIRECCIONES contra staging el 2026-09-10**, porque un verificador que no puede
-- fallar es peor que ninguno: con los cinco esperados correctos pasa y deja cero filas sintéticas; con
-- un esperado falseado a propósito **aborta** con el escenario y los dos valores en el mensaje, y el
-- `exception when others` limpia igual antes de re-lanzar (comprobado: cero filas tras el fallo).
--
-- Se limpia con DELETE explícito y no con una sub-transacción: `apply_migration` ya envuelve el fichero
-- entero, y un `rollback` aquí se llevaría la migración por delante. El `exception` re-lanza tras limpiar,
-- así que un fallo aborta la transacción externa (y con ella el cambio) sin dejar filas.
do $conducta$
declare
  v_ids uuid[] := '{}';
  v_id uuid;
  v_ret jsonb;
  v_fallos text := '';
  e text[];
  --      kind          migrated_at   reverted_at  mip  lease   esperado        etiqueta
  escen text[][] := array[
    array['complete',   'null',       'null',      'f', 'now', 'ok',           'born-cloud complete'],
    array['complete',   '2026-01-01', 'null',      'f', 'now', 'ok',           'migrada complete (control positivo)'],
    array['complete',   '2026-01-01', 'null',      't', 'old', 'ok',           'takeover mip lease vencido (golden 12)'],
    array['groups_only','null',       'null',      'f', 'now', 'not_complete', 'groups_only pura (nunca revirtio)'],
    array['groups_only','2026-01-01', 'set',       'f', 'now', 'ok',           '2.o device de cuenta YA revertida']
  ];
  v_obtenido text;
begin
  foreach e slice 1 in array escen loop
    v_id := gen_random_uuid();
    v_ids := v_ids || v_id;
    insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
      values (v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
              'g15-02-verify-' || replace(v_id::text, '-', '') || '@invalid.local', now(), now());
    perform set_config('yala.kind_write', txid_current()::text, true);
    insert into public.profiles (id, provider, kind, personal_claimed_at, migrated_at, reverted_at,
                                 migration_in_progress, reverse_in_progress, leader_device_id,
                                 migration_updated_at)
      values (v_id, 'apple', e[1],
              case when e[1] = 'complete' then now() else null end,
              case when e[2] = 'null' then null else e[2]::timestamptz end,
              case when e[3] = 'null' then null else now() end,
              e[4]::boolean, false, 'g15-02-otro-device',
              case when e[5] = 'old' then now() - interval '90 minutes' else now() end);
    perform set_config('yala.kind_write', '', true);

    perform set_config('request.jwt.claims', json_build_object('sub', v_id::text)::text, true);
    v_ret := public.migration_progress('g15-02-caller', 'reverse_claim');
    v_obtenido := case when v_ret->>'ok' = 'true' then 'ok' else coalesce(v_ret->>'reason', '<sin reason>') end;
    if v_obtenido is distinct from e[6] then
      v_fallos := v_fallos || format(E'\n  · %s: esperado %s, obtenido %s', e[7], e[6], v_ret);
    end if;
  end loop;

  perform set_config('request.jwt.claims', '', true);
  delete from public.profiles where id = any(v_ids);
  delete from auth.users where id = any(v_ids);

  if v_fallos <> '' then
    raise exception 'g15_02 conducta: % escenario(s) fallaron:%', array_length(escen, 1), v_fallos;
  end if;
  raise notice 'g15_02 OK · 5/5 escenarios · born-cloud dentro, solo-grupos fuera, 2.o device de una revertida dentro.';
exception
  when others then
    -- Limpiar aunque el fallo venga del propio ejercicio, y RE-LANZAR: el cambio no debe entrar sin la
    -- prueba en verde. La transacción externa de `apply_migration` revierte todo.
    delete from public.profiles where id = any(v_ids);
    delete from auth.users where id = any(v_ids);
    raise;
end $conducta$;
