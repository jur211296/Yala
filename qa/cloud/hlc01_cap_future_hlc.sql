-- hlc01_cap_future_hlc — tope en el servidor a un HLC del futuro (canal personal + Grupos), 2026-10-07.
--
-- Tickets: `personal-clock-ahead-wins-every-conflict-until-real-time-catches-up` y
-- `groups-clock-ahead-wins-every-conflict-until-real-time-catches-up`. Decisión de Jürgen (2026-10-04): tope en el
-- servidor. Los detalles (recortar y no rechazar, 60 s, trigger y no RPC) están en el Paso 0 del encargo
-- `encargos/lanzados/2026-10-07-clock-ahead-wins-every-conflict-server-cap.md`.
--
-- QUÉ HACE
--   Todo HLC que se guarda en una tabla sincronizada queda acotado a «ahora + 60 s» (`clock_timestamp()`). Un teléfono
--   con la hora adelantada sigue subiendo sus cambios —nada se rechaza ni va a dead-letter—, pero su HLC guardado ya no
--   le hace ganar a lo que otros escriban después de que su cambio LLEGUE: frente a los demás cuenta el orden de
--   llegada, con un minuto de ventana. Un cambio suyo que espera sin red gana, al llegar, a lo que otros escribieron
--   antes: el servidor no puede saber la hora real de una edición de un reloj que miente.
--
--   - `hlc_cap_value(hlc, tope)`: un c1 válido por encima del tope se guarda `<tope>-<contador>-<nodo>`; uno por debajo,
--     tal cual. Cualquier valor que NO sea c1 (mal formado, con caracteres de control) se guarda
--     `<tope>-0000-0000000000000000` SIN mirar su orden: así no depende de la collation de la base, que los RPC usan
--     para comparar y que puede ignorar caracteres de control. `''` y `null` se quedan como están (la rama de tombstone de
--     `apply_group_delta` escribe `''` a propósito).
--   - `hlc_cap_patch(fila, tope)`: lo que hay que cambiar de una fila, en jsonb (`{}` si nada). Acota `hlc`,
--     `deleted_hlc` y cada valor de `field_hlcs` —un valor que no sea texto también cuenta como mal formado—, y si toca
--     `field_hlcs` sube `hlc` al máximo de las unidades: acotar unidad a unidad puede invertir su orden (el contador
--     manda dentro del mismo milisegundo acotado), y el `hlc` de fila es lo que integran los clientes y lo que arbitra
--     un tombstone. Una sola función para el trigger y para la normalización.
--   - `cap_future_hlc()`: trigger `BEFORE INSERT OR UPDATE` en las 22 tablas. Va en el trigger y no en los RPC porque
--     (a) alcanza a todo escritor —`apply_delta`, `apply_pref`, `apply_group_delta` y el `PATCH` directo, que tiene
--     grant de UPDATE sobre las columnas de HLC en Grupos— y (b) el cuerpo de `apply_delta`/`apply_pref` no vive en el
--     repo.
--   - Normalización: re-escribe (`set hlc = hlc`) las filas que el trigger cambiaría, y el trigger las acota. Mueve su
--     `server_seq`: los teléfonos las re-bajan una vez, y en Grupos un gasto re-bajado sale como «gasto modificado».
--     Solo toca HLC, nunca un valor.
--
-- POR QUÉ DECIDIR CON EL ENTRANTE Y GUARDAR ACOTADO
--   Los RPC comparan el HLC entrante SIN acotar con el guardado. Todo lo guardado cumple `≤ hora de su escritura + 60 s`,
--   así que un entrante por encima del tope gana igual que ganaría acotado (salvo un empate en el mismo milisegundo). Lo
--   que eso añade es el ORDEN PROPIO: el segundo cambio de un teléfono adelantado lleva un HLC sin acotar mayor que el
--   primero y le gana, aunque el primero ya esté guardado acotado. Eso exige que lleguen en orden, y por eso los clientes
--   suben ordenado por HLC (`SyncPushClient.push`, `GroupsSyncClient.pushPending`). Un primer cambio que falla SOLO en su
--   lote y se reintenta después del segundo le ganaría: residual con ticket
--   (`clock-ahead-retried-older-change-beats-the-newer-one`).
--
-- `clock_timestamp()` y no `now()`: `now()` es el inicio de la transacción, y una larga (esta misma normalización, un
-- re-cifrado) acotaría como «futuros» HLC honrados escritos mientras tanto.
--
-- IDEMPOTENTE: `create or replace` + `drop trigger if exists`. Transacción única con `lock_timeout` de 5 s: si una tabla
-- no se deja bloquear, no se aplica nada y se reintenta. MARCHA ATRÁS: `qa/cloud/hlc01_rollback.sql`.
-- VERIFICACIÓN: local `bash qa/cloud/hlc01-cap-test.sh`; staging, tras aplicar, `bash qa/cloud/hlc01-cap-staging-probe.sh`.
-- Con `apply_migration` del MCP, quita antes el `begin;` y el `commit;`: ese applier ya envuelve en transacción.

begin;

set local lock_timeout = '5s';

-- ------------------------------------------------------------------------------------------- el margen, en un sitio
create or replace function public.hlc_cap_margin() returns interval
language sql immutable set search_path = public as
$$ select interval '60 seconds' $$;

-- El tope de AHORA: instante canónico de 24 chars (`YYYY-MM-DDTHH:MI:SS.MSZ`) de `clock_timestamp() + margen`.
create or replace function public.hlc_cap_instant() returns text
language sql volatile set search_path = public as
$$ select to_char((clock_timestamp() at time zone 'utc') + public.hlc_cap_margin(), 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') $$;

-- --------------------------------------------------------------------------------------------- el valor acotado
-- Un c1 válido cuyo prefijo es igual al tope ordena por encima en "C" (46 chars > 24) y la rama de abajo devuelve
-- exactamente el mismo string.
create or replace function public.hlc_cap_value(p_hlc text, p_cap text) returns text
language sql immutable set search_path = public as
$$
  select case
    when p_hlc is null or p_hlc = '' then p_hlc
    when p_hlc !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z-[0-9a-f]{4}-[0-9a-f]{16}$'
      then p_cap || '-0000-0000000000000000'
    when p_hlc collate "C" <= p_cap collate "C" then p_hlc
    else p_cap || substr(p_hlc, 25)
  end
$$;

-- ------------------------------------------------------------------------------------------ el parche de una fila
create or replace function public.hlc_cap_patch(p_row jsonb, p_cap text) returns jsonb
language plpgsql immutable set search_path = public as
$$
declare
  v_patch   jsonb := '{}'::jsonb;
  v_hlc     text;
  v_capped  text;
  v_fh      jsonb := p_row -> 'field_hlcs';
  v_new_fh  jsonb;
  v_max     text;
begin
  if p_row ? 'hlc' then
    v_hlc := p_row ->> 'hlc';
    v_capped := public.hlc_cap_value(v_hlc, p_cap);
    if v_capped is distinct from v_hlc then
      v_patch := v_patch || jsonb_build_object('hlc', v_capped);
    end if;
  end if;

  if p_row ? 'deleted_hlc' then
    v_capped := public.hlc_cap_value(p_row ->> 'deleted_hlc', p_cap);
    if v_capped is distinct from (p_row ->> 'deleted_hlc') then
      v_patch := v_patch || jsonb_build_object('deleted_hlc', v_capped);
    end if;
  end if;

  if v_fh is not null and jsonb_typeof(v_fh) = 'object' then
    select coalesce(jsonb_object_agg(e.key,
             case jsonb_typeof(e.value)
               when 'null'   then e.value
               when 'string' then to_jsonb(public.hlc_cap_value(e.value #>> '{}', p_cap))
               else to_jsonb(p_cap || '-0000-0000000000000000')
             end), '{}'::jsonb)
      into v_new_fh
      from jsonb_each(v_fh) e;
    if v_new_fh <> v_fh then
      v_patch := v_patch || jsonb_build_object('field_hlcs', v_new_fh);
      -- El `hlc` de fila nunca por debajo de una unidad: acotadas al mismo milisegundo, manda el contador.
      if p_row ? 'hlc' then
        select max(x collate "C") into v_max
          from (select coalesce(v_patch ->> 'hlc', v_hlc) as x
                union all
                select e.value #>> '{}' from jsonb_each(v_new_fh) e where jsonb_typeof(e.value) = 'string') u
         where x is not null;
        if v_max is distinct from v_hlc then
          v_patch := v_patch || jsonb_build_object('hlc', v_max);
        end if;
      end if;
    end if;
  end if;

  return v_patch;
end
$$;

-- ------------------------------------------------------------------------------------------------- el trigger
-- SECURITY DEFINER: solo calcula (no lee ni escribe tablas), y así las funciones de arriba pueden quedar sin EXECUTE para
-- los clientes. Genérico por jsonb: cada tabla tiene un subconjunto distinto de (hlc, deleted_hlc, field_hlcs), y
-- `jsonb_populate_record(new, patch)` solo toca las claves del parche (las columnas bytea cifradas no se re-castean).
create or replace function public.cap_future_hlc() returns trigger
language plpgsql security definer set search_path = public as
$$
declare
  v_patch jsonb := public.hlc_cap_patch(to_jsonb(new), public.hlc_cap_instant());
begin
  if v_patch <> '{}'::jsonb then
    new := jsonb_populate_record(new, v_patch);
  end if;
  return new;
end
$$;

-- Higiene (molde g12_02): ninguna se llama desde un cliente.
revoke all on function public.hlc_cap_margin(), public.hlc_cap_instant(), public.hlc_cap_value(text, text),
  public.hlc_cap_patch(jsonb, text), public.cap_future_hlc()
  from public, anon, authenticated;

-- ------------------------------------------------------------------------------- triggers en las 22 tablas + normalización
do $$
declare
  c_tables constant text[] := array[
    -- canal personal: 16 de dominio + user_preferences (supabase-staging.ddl)
    'accounts','budgets','cashflow_lines','cashflow_overrides','cashflow_plans','categories','exchange_rates',
    'favorite_payments','group_bridge_prefs','inbox_drafts','merchant_memory','notification_items',
    'scheduled_payments','subcategories','tags','tx_items','user_preferences',
    -- Grupos (supabase-groups-staging.ddl)
    'split_groups','group_members','split_expenses','split_shares','split_settlements'];
  v_t       text;
  v_n       bigint;
  v_total   bigint := 0;
  v_extra   text;
begin
  -- Cada tabla de la lista TIENE que existir con su columna `hlc`: si el esquema no es el medido, no se aplica nada.
  foreach v_t in array c_tables loop
    if not exists (select 1 from information_schema.columns
                   where table_schema = 'public' and table_name = v_t and column_name = 'hlc') then
      raise exception 'hlc01: la tabla public.% no existe o no tiene columna hlc — esquema distinto del medido', v_t;
    end if;
  end loop;

  -- Una tabla con `hlc` fuera de la lista no se toca, pero se dice (en staging hay tablas spike_*).
  select string_agg(table_name, ', ' order by table_name) into v_extra
    from information_schema.columns
   where table_schema = 'public' and column_name = 'hlc' and not (table_name = any (c_tables));
  if v_extra is not null then
    raise notice 'hlc01: tablas con columna hlc que NO reciben el tope: %', v_extra;
  end if;

  foreach v_t in array c_tables loop
    execute format('drop trigger if exists cap_future_hlc on public.%I', v_t);
    execute format('create trigger cap_future_hlc before insert or update on public.%I
                    for each row execute function public.cap_future_hlc()', v_t);

    -- Las filas que el trigger cambiaría, con el tope de este instante (no el del inicio de la transacción).
    execute format('update public.%I as t set hlc = t.hlc where public.hlc_cap_patch(to_jsonb(t), $1) <> ''{}''::jsonb', v_t)
      using public.hlc_cap_instant();
    get diagnostics v_n = row_count;
    if v_n > 0 then
      raise notice 'hlc01: % filas de % con HLC por encima del tope o mal formado, acotadas', v_n, v_t;
    end if;
    v_total := v_total + v_n;
  end loop;

  raise notice 'hlc01: tope aplicado a % tablas; % filas normalizadas', array_length(c_tables, 1), v_total;
end
$$;

commit;
