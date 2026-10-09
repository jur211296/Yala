-- =====================================================================================================
-- g17_01 · marcha atrás: el claim de la vuelta vuelve a borrar `reverted_at` (cuerpo de g15_02)
--
-- Deshace exactamente la sustitución de `g17_01_reverse_claim_keeps_reverted_at.sql` y comprueba que el cuerpo
-- vuelve al md5 de partida (14fc5e2c…). Si el cuerpo vivo no es el de g17_01, aborta sin tocar nada.
--
-- Qué vuelve con ella: los tres caminos al `not_complete` del ticket
-- `reverse-exit-on-a-reverted-account-rejects-the-retry`. Las cuentas que ya conservaron `reverted_at` gracias
-- a g17_01 lo siguen teniendo (la marcha atrás no reescribe filas): solo el próximo claim lo borrará.
--
--   psql -1 -v ON_ERROR_STOP=1 -f qa/cloud/g17_01_rollback.sql "$SUPABASE_DB_URL"
-- =====================================================================================================
do $rollback$
declare
  v_src  text;
  v_new_src text;
  v_old  text := 'reverted_at = null';
  v_new  text := 'reverted_at = case when kind = ''complete'' then null else reverted_at end';
  v_virgen text := '14fc5e2c54766dd7c5706966c7381f51';
begin
  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'migration_progress' and p.pronargs = 2;

  if v_src is null then
    raise exception 'g17_01 rollback: migration_progress(text,text) no existe. Abortada.';
  end if;
  if md5(v_src) = v_virgen then
    raise notice 'g17_01 rollback: el cuerpo ya es el de g15_02. No-op.';
    return;
  end if;
  if position(v_old in v_src) <> 0 or position(v_new in v_src) = 0 then
    raise exception 'g17_01 rollback: el cuerpo vivo no es el de g17_01 (md5 %). Abortada.', md5(v_src);
  end if;

  v_new_src := replace(v_src, v_new, v_old);
  if md5(v_new_src) <> v_virgen then
    raise exception 'g17_01 rollback: deshacer la sustitución daría md5 %, no el de g15_02. Abortada.', md5(v_new_src);
  end if;

  execute format(
    'create or replace function public.migration_progress(p_device_id text, p_action text) returns jsonb language plpgsql set search_path = public as %L',
    v_new_src);

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'migration_progress' and p.pronargs = 2;
  if md5(v_src) <> v_virgen then
    raise exception 'g17_01 rollback: tras recrear la función el md5 es %, no el de g15_02.', md5(v_src);
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                  where n.nspname = 'public' and p.proname = 'migration_progress' and p.pronargs = 2
                    and not p.prosecdef and p.proconfig = array['search_path=public']) then
    raise exception 'g17_01 rollback: migration_progress perdió sus atributos (security invoker + search_path=public)';
  end if;
  raise notice 'g17_01 rollback OK · migration_progress vuelve al cuerpo de g15_02 (md5 %).', v_virgen;
end $rollback$;
