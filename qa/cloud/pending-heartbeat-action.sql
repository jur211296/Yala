-- =============================================================================================
-- I14-pre — Acción `heartbeat` del RPC `migration_progress` (heartbeat del lease de 60 min)
-- =============================================================================================
--
-- ARTEFACTO, NO DEPLOY. Esta sesión NO tenía el MCP de Supabase conectado (ni psql/CLI/SUPABASE_DB_URL),
-- y la functiondef DESPLEGADA de `migration_progress` NO vive en el repo (la regla del proyecto es
-- LEER la función viva y EXTENDER, jamás reescribir a ciegas). Por eso el branch se entrega como
-- injerto con instrucciones — lo aplica el OWNER cuando reconecte el MCP, JUNTO al redeploy del Worker.
--
-- Migración sugerida: `i14_heartbeat_action`.
-- Proyecto: STAGING `fostjbbwstyuunmmefuk`. PRODUCTION JAMÁS (Modo Nube sigue DARK / flags OFF).
--
-- ---------------------------------------------------------------------------------------------
-- PASOS DEL OWNER (en orden):
--
-- 1. LEER la functiondef viva (verificar primero la firma real — puede ser (text,text) u otra):
--
--      select pg_get_functiondef('public.migration_progress(text,text)'::regprocedure);
--
--    Si la firma difiere (p.ej. nombres de parámetros `p_device_id`/`p_action` distintos, o un
--    tipo de retorno que no sea `jsonb`), AJUSTAR el branch de abajo a lo que devuelva la lectura.
--
-- 2. GRAFTEAR el branch `heartbeat` (ver abajo) DENTRO del `if/elsif` de dispatch de acciones,
--    ANTES del `else` final que rechaza acciones desconocidas (el que hoy hace que golden 18
--    `reverse_nuke` caiga a `bad_action`). El branch es AUTOCONTENIDO: no depende de variables
--    internas de la función (consulta `public.profiles` filtrando por `auth.uid()` directamente),
--    así que se puede pegar tal cual sea cual sea el estilo del resto de la función.
--
-- 3. `create or replace function public.migration_progress(...)` con el CUERPO COMPLETO leído en (1)
--    + el branch injertado. Los branches existentes (cutover/complete/reverse_*) quedan VERBATIM
--    (los goldens 6-18 verdes lo prueban). NUNCA reescribir a ciegas.
--
-- 4. Redeploy del Worker (`cd gateway && npx wrangler deploy`) — el set de actions del edge ya
--    incluye `heartbeat` (account.ts); antes del deploy el edge devuelve 400 a `heartbeat`, lo que
--    PROTEGE al RPC desplegado de una acción que aún no entiende. RPC-primero, Worker-después: si se
--    desplegara el Worker antes que el RPC, `heartbeat` llegaría al RPC viejo → `bad_action`.
--
-- 5. `cd gateway && npm test` → goldens 23-26 de `account.goldens.test.ts` deben pasar (network ON).
--
-- ---------------------------------------------------------------------------------------------
-- SEMÁNTICA (sirve a la ida Y a la reversa con UNA sola acción; el RPC decide por el flag activo):
--   * Sin fila `profiles` para `auth.uid()`                         → { ok:false, reason:'not_in_progress' }
--   * (migration_in_progress OR reverse_in_progress) y líder == caller
--         → UPDATE migration_updated_at = now()                      → { ok:true }
--     SIN edad de lease (idiom `reverse_freeze`: el lease existe SOLO para que competidores usurpen;
--     el MISMO líder lento siempre puede latir).
--   * (mip OR rip) y líder DISTINTO                                  → { ok:false, reason:'other_leader' }
--     (el cliente NO corta el paso por esto — best-effort; el guard real lo aplican cutover/freeze/complete).
--   * Ni mip ni rip (heartbeat tardío tras complete)                → { ok:false, reason:'not_in_progress' }
--   NO toca migrated_at / reverse_frozen_at / reverted_at / claim_account. SOLO el timestamp del lease.
-- =============================================================================================

-- --------- BRANCH A GRAFTEAR (dentro del dispatch de `p_action`, antes del `else` final) ---------

    elsif p_action = 'heartbeat' then
      -- Sin fila para el usuario autenticado → nada que latir.
      if not exists (select 1 from public.profiles where id = auth.uid()) then
        return jsonb_build_object('ok', false, 'reason', 'not_in_progress');
      end if;

      -- Líder actual de un run ACTIVO (ida o reversa) → refresca el lease. SIN edad de lease
      -- (el mismo líder lento siempre puede latir; el lease solo existe para que competidores usurpen).
      -- UPDATE CONDICIONAL en UNA sentencia (idiom CAS de i11_reverse_claim_cas): un exists+UPDATE
      -- separado tendría el TOCTOU de refrescar el lease del usurpador si un takeover comitea en medio.
      update public.profiles set migration_updated_at = now()
      where id = auth.uid()
        and (migration_in_progress or reverse_in_progress)
        and leader_device_id is not distinct from p_device_id;
      if found then
        return jsonb_build_object('ok', true);
      end if;

      -- Run activo pero líder DISTINTO → other_leader (advisory; el cliente no corta por esto).
      if exists (
        select 1 from public.profiles
        where id = auth.uid()
          and (migration_in_progress or reverse_in_progress)
          and leader_device_id is distinct from p_device_id
      ) then
        return jsonb_build_object('ok', false, 'reason', 'other_leader');
      end if;

      -- Ni mip ni rip (heartbeat tardío tras complete) → benigno idempotente.
      return jsonb_build_object('ok', false, 'reason', 'not_in_progress');
