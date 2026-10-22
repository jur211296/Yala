-- =====================================================================================================
-- g17_01 · marcha atrás: el claim de la vuelta vuelve a borrar `reverted_at` (cuerpo de g15_02)
--
-- Deshace exactamente la sustitución de `g17_01_reverse_claim_keeps_reverted_at.sql` y comprueba que el cuerpo
-- vuelve al md5 de partida (14fc5e2c…). Si el cuerpo vivo no es el de g17_01, aborta sin tocar nada. Busca las
-- escrituras por patrón y devuelve a cada una su espaciado: el cuerpo vivo las alinea (`reverted_at          = …`).
-- Probado contra el cuerpo real en `qa/cloud/g17_01-local-test.sh`.
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
  -- Patrones, no literales: el cuerpo vivo alinea las escrituras (`reverted_at          = …`). La inversa
  -- devuelve a cada una su espaciado, capturado a los dos lados del `=`.
  v_pat_new text := '\mreverted_at(\s*)=(\s*)case when kind = ''complete'' then null else reverted_at end';
  v_inv     text := 'reverted_at\1=\2null';
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
  if (select count(*) from regexp_matches(v_src, 'reverted_at\s*=\s*null', 'gi')) <> 0
     or (select count(*) from regexp_matches(v_src, v_pat_new, 'g')) <> 3 then
    raise exception 'g17_01 rollback: el cuerpo vivo no es el de g17_01 (md5 %). Abortada.', md5(v_src);
  end if;

  v_new_src := regexp_replace(v_src, v_pat_new, v_inv, 'g');
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
