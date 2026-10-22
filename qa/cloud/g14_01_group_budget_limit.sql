-- =====================================================================================================
-- g14_01 · presupuesto de grupo: UN límite por grupo
--
-- QUÉ GANA EL USUARIO. Un grupo de viaje o de piso compartido puede fijar un tope de gasto colectivo
-- —"Presupuesto del viaje: S/ 3000"— y ver cuánto lleva gastado el grupo entero contra ese tope. Hoy el
-- único límite que existe en Yala es el presupuesto PERSONAL, que suma las transacciones de la cuenta de
-- una sola persona y nunca los gastos compartidos del grupo.
--
-- DECISIÓN (Jürgen, 2026-09-06). UN límite por grupo, no varios: el límite vive en `split_groups` y se
-- expresa en la moneda del grupo (`currency_code`, ya existente). Sin tabla nueva, sin modelo nuevo, sin
-- columna de moneda propia. Varios presupuestos por grupo se podrán añadir después si alguien los pide.
--
-- LA PREMISA DEL TICKET ERA VIEJA, Y SE MIDIÓ ANTES DE OBEDECERLA. El ticket describe un checklist de
-- CloudKit (`CKConstants.RecordType`, `CKRecordTranslator`, `SplitSyncManager`, deploy al CloudKit
-- Dashboard). Ese transporte YA NO EXISTE: los tres símbolos dan cero ocurrencias en `Yala/` (medido en
-- este árbol el 2026-09-07; la Fase 3 del Modo Nube lo borró y `.claude/rules/swiftdata-cloudkit.md` lo
-- avisa en su cabecera). Grupos viaja hoy por el backend propio ⇒ el coste de esquema es DDL + grants +
-- los dos RPCs de este archivo, y ningún deploy de CloudKit.
--
-- === Por qué la columna es † (cifrada) y no numeric en claro ===
--   El modelo de amenaza de G7 (g7_01) cifra los MONTOS para que una fila filtrada de un dump lógico no
--   los revele. Un límite de presupuesto es un monto del grupo: dejarlo en claro sería una regresión de
--   ese modelo, y el precedente para el siguiente. Va como las otras 8 columnas †: `bytea`, cifrada con
--   `pgp_sym_encrypt(<texto>, p_key)` al escribir y `yala_try_decrypt` al leer.
--
-- === La trampa que esto destapa: 'amount' había dejado de ser la única columna † numérica ===
--   La normalización de escala del cifrado estaba atada al NOMBRE LITERAL de la columna
--   (`case when c = 'amount'`), con el comentario "'amount' es la ÚNICA columna † numérica" — cierto
--   hasta esta migración. Sin tocarlo, `budget_limit_amount` habría caído en la rama `else` y se habría
--   cifrado como texto CRUDO, sin normalizar la escala. Con el cliente iOS de hoy el resultado sería
--   byte-idéntico POR CASUALIDAD (emite `.money` ya canonizado a escala 4 — "3000.0000", medido en
--   `Canonc1Codec.swift:117-118`), pero un cliente que mandara "3000" escribiría un valor sin escala y
--   produciría un root de Merkle divergente PERMANENTE para ese grupo. ⇒ la condición pasa a lista en
--   las 3 ramas que la usan.
--
-- === Grants: SELECT se hereda, UPDATE no ===
--   El SELECT de `authenticated` es a nivel TABLA y cubre columnas futuras. El UPDATE es POR COLUMNA
--   (hallazgo #1 de G1) y NO se hereda: sin el grant de abajo, el push del delta daría 42501 →
--   `yala_not_authorized`, y el server rechazaría el delta ENTERO del grupo, no solo este campo. Es el
--   mismo incidente que `created_at` en G2.
--
-- === Permisos de producto: los impone el server, no la app ===
--   La policy `split_groups_update` exige `is_group_admin(group_id)` ⇒ fijar o quitar el límite es de
--   ADMIN, por construcción. La UI lo refleja para no ofrecer un control que fallaría.
--
-- === POR QUÉ ESTA MIGRACIÓN TRANSFORMA `apply_group_delta` EN VEZ DE REESCRIBIRLA ENTERA ===
--   El cambio real son 4 sustituciones dentro de una función de 12,6 KB. Pegar los 12,6 KB a mano para
--   cambiar 4 trozos es precisamente como nació el drift que g13_05 tuvo que cerrar (una versión del
--   repo que difería de lo aplicado en 18 caracteres de comentario). En su lugar la migración parte de la
--   definición VIVA y es AUTO-VERIFICADA: comprueba el md5 de partida y el de llegada, y aborta la
--   transacción entera si cualquiera de los dos no es el esperado. Determinista o ruidosa, nunca a medias.
--   El texto completo resultante vive, como siempre, en `supabase-groups-staging.ddl`.
--
-- === CÓMO SE APLICÓ EN PRODUCCIÓN, Y POR QUÉ ESTE FICHERO NO ES BYTE-IDÉNTICO A ESO ===
--   Producción se aplicó el 2026-09-07 con la columna PRIMERO y la función después, y salió bien (el
--   estado final está verificado: columna `bytea`, `md5(prosrc)` = ae78bce…, grant presente). El riesgo
--   del estado intermedio lo destapó la review adversarial DESPUÉS de aplicar, y por eso este fichero
--   —el que se aplicará en staging y el que queda como registro— lleva el orden corregido. El estado de
--   llegada es el MISMO por los dos caminos; lo que cambia es qué pasa si la migración se interrumpe a
--   la mitad. Verificado en sandbox transaccional partiendo del estado exacto de staging (función
--   pre-G14 + columna ausente): llega a ae78bce… y a la columna creada.
--
-- === EL ORDEN NO ES INDIFERENTE: LA FUNCIÓN VA ANTES QUE LA COLUMNA ===
--   Con la columna creada y `apply_group_delta` todavía en su versión vieja, `budget_limit_amount` NO
--   estaría en la lista de columnas † ⇒ caería en `v_plain_fields` ⇒ entraría por
--   `jsonb_populate_record(null::public.split_groups, …)` contra una columna `bytea`, y `byteain` en
--   formato escape ACEPTA texto arbitrario sin error: el importe quedaría EN CLARO dentro de la columna
--   cifrada. Después `yala_try_decrypt` fallaría, devolvería NULL, y el presupuesto desaparecería para
--   todo el grupo — con un canario de «divergencia de Merkle» que no nombra la fuga.
--   Al revés (función primero, columna después) el estado intermedio hace fallar el push con
--   `42703 column does not exist`: ruidoso y reversible. Se elige el fallo que se ve.
--   AVISO PARA EL FUTURO: `g7_02_encrypt_groups_cutover.sql` sigue en el repo y recrea esta función con
--   `array['name']`. Re-aplicarlo sobre un esquema post-G14 reabre exactamente esta puerta.
--
-- === TRANSACCIÓN EXPLÍCITA ===
--   `begin`/`commit` propios: si el guard de md5 aborta, o si el reader falla, no puede quedar la mitad
--   aplicada. Postgres tiene DDL transaccional, así que esto revierte de verdad. (El resto de
--   `qa/cloud/` no los lleva y depende de que el applier envuelva; aquí no se depende de eso.)
--
-- === IDEMPOTENCIA: NO la tiene, y es DELIBERADO ===
--   Una segunda pasada aborta con el md5 de llegada en el mensaje. Es lo correcto para una migración que
--   REESCRIBE una función viva: repetirla en silencio es lo que produce drift. Si hay que reintentarla
--   tras un fallo, la transacción ya dejó todo como estaba, así que se re-aplica entera.
--
-- VERIFICADO ANTES DE APLICAR (2026-09-07), en sandbox transaccional contra el esquema y el motor REALES
-- de producción (`begin … rollback`, con el probe previo que confirma que el rollback revierte):
--   1. admin fija 3000.0000 → `applied_units:["budget_limit_amount"]`; el pull lo devuelve "3000.0000"
--      (escala preservada) y en disco son 75 bytes cifrados, sin el texto plano visible.
--   2. admin lo quita (null explícito) → aplicado; el pull devuelve null ⇒ QUITAR el límite se propaga.
--   3. `name` quedó intacto tras los dos deltas ⇒ la unidad `budget_limit_amount` no arrastra el resto
--      de la meta (su HLC es propio; no entra en la unidad `meta`).
--   4. CONTROL NEGATIVO: un miembro NO-admin recibe `{"noop":true,"reason":"not_authorized_or_gone"}` y
--      el valor en disco queda INTACTO. Con su control positivo: el mismo no-admin sobre `icon_name`
--      (columna vieja) da el mismo rechazo ⇒ lo que protege es la RLS, no un accidente del campo nuevo.
--   5. Sin rastro tras el rollback: columna ausente, 0 filas sintéticas y los md5 de ambas funciones de
--      vuelta a los originales.
-- =====================================================================================================

begin;

-- ============================================================================================
-- 1. apply_group_delta — PRIMERO, antes de que exista la columna (ver «el orden» arriba) — `budget_limit_amount` entra en las columnas † de split_groups, y la
--    normalización de escala deja de estar atada al nombre literal 'amount' (3 ramas).
--    La firma NO cambia ⇒ `create or replace` conserva los grants de EXECUTE de G7.
-- ============================================================================================
do $mig$
declare
  v_def   text;
  v_md5   text;
  c_before constant text := 'd2e748320da4f2eca82b19a0048e84ab';  -- prosrc vivo pre-g14_01
  c_after  constant text := 'ae78bce687ab00da0ae463e6525cc09c';  -- resultado verificado en sandbox
begin
  -- Firma FIJADA con ::regprocedure: un `where proname = …` sin firma toma una fila ARBITRARIA si
  -- hubiera dos sobrecargas (y g7_02 tuvo que limpiar exactamente eso con un drop explícito).
  select md5(prosrc), pg_get_functiondef(oid) into strict v_md5, v_def
    from pg_proc
    where oid = 'public.apply_group_delta(text, text, uuid, text, jsonb, jsonb, text, text, integer)'::regprocedure;

  if v_md5 is distinct from c_before then
    raise exception 'g14_01 ABORTA: apply_group_delta no esta en la version esperada (md5 % != %). '
                    'Alguien la cambio despues de verificar esta migracion: re-verificar en sandbox.',
                    coalesce(v_md5,'<no existe>'), c_before;
  end if;

  v_def := replace(v_def, $x$when 'split_groups'      then array['name']$x$,
                          $x$when 'split_groups'      then array['name','budget_limit_amount']$x$);
  v_def := replace(v_def, $x$case when c = 'amount'$x$,
                          $x$case when c in ('amount','budget_limit_amount')$x$);
  execute v_def;

  select md5(prosrc) into strict v_md5
    from pg_proc
    where oid = 'public.apply_group_delta(text, text, uuid, text, jsonb, jsonb, text, text, integer)'::regprocedure;

  if v_md5 is distinct from c_after then
    raise exception 'g14_01 ABORTA: resultado inesperado (md5 % != %).', v_md5, c_after;
  end if;
end $mig$;

-- ============================================================================================
-- 2. La columna † y su grant — DESPUÉS de que la función ya sepa cifrarla.
--    SELECT se hereda del grant de TABLA; UPDATE es POR COLUMNA y no se hereda.
-- ============================================================================================
alter table public.split_groups add column if not exists budget_limit_amount bytea;
grant update (budget_limit_amount) on public.split_groups to authenticated;

-- ============================================================================================
-- 3. Reader del pull — la columna descifrada se añade AL FINAL del RETURNS TABLE.
--    DROP + CREATE (no `or replace`): cambiar el tipo de retorno de una funcion que devuelve
--    TABLE exige recrearla. El DROP se lleva los grants de EXECUTE ⇒ se re-otorgan aqui mismo,
--    y todo va dentro de la transaccion de la migracion: sin ventana en la que el reader falte.
-- ============================================================================================
drop function if exists public.groups_pull_rows_split_groups(text, bigint, int, text);
create function public.groups_pull_rows_split_groups(
  p_group_id text, p_after_seq bigint, p_limit int, p_key text
) returns table(
  group_id text, name text, icon_name text, color_hex text, currency_code text,
  simplify_debts boolean, show_debts_in_single_currency boolean, members_can_invite boolean,
  default_split_type text, is_archived boolean, is_hidden_for_all boolean, owner_user_id uuid,
  created_at timestamptz, field_hlcs jsonb, hlc text, deleted boolean, deleted_hlc text,
  server_seq bigint, schema_version integer, updated_at timestamptz,
  budget_limit_amount text
) language sql security invoker stable set search_path = public, extensions as $$
  select
    t.group_id, public.yala_try_decrypt(t.name, p_key), t.icon_name, t.color_hex, t.currency_code,
    t.simplify_debts, t.show_debts_in_single_currency, t.members_can_invite,
    t.default_split_type, t.is_archived, t.is_hidden_for_all, t.owner_user_id,
    t.created_at, t.field_hlcs, t.hlc, t.deleted, t.deleted_hlc,
    t.server_seq, t.schema_version, t.updated_at,
    public.yala_try_decrypt(t.budget_limit_amount, p_key)
  from public.split_groups t
  where t.group_id = p_group_id and t.server_seq > p_after_seq
  order by t.server_seq asc
  limit p_limit
$$;

revoke all on function public.groups_pull_rows_split_groups(text, bigint, int, text) from public, anon;
grant execute on function public.groups_pull_rows_split_groups(text, bigint, int, text) to authenticated;

commit;
