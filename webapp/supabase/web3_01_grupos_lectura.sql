-- web3_01_grupos_lectura (2026-11-14, lote 3 de Yala web — SOLO STAGING)
--
-- QUÉ HACE. Deja que el token de Yala web (rol `yala_mcp_reader` con el cliente OAuth de la web) LEA los grupos de los
-- que la persona es miembro, por los mismos RPC lectores que usa el iPhone (`groups_pull_rows_*`, SECURITY INVOKER). Es
-- ADITIVO: crea un helper y cinco políticas SELECT para ese rol, y da GRANTs de SELECT y EXECUTE. Ninguna escritura:
-- el rol sigue sin INSERT/UPDATE/DELETE y sin EXECUTE en ningún RPC que escriba (`apply_group_delta`, `create_group`…).
--
-- POR QUÉ SOLO EL CLIENTE DE LA WEB. El conector de Claude comparte el rol `yala_mcp_reader`. Las políticas exigen
-- además que el token sea del cliente de la web (`yala_is_web_reader()`), así que el conector no gana nada.
--
-- POR QUÉ NO BASTA CON ESTO PARA LEER. Ocho columnas de Grupos están cifradas (G7) y la llave solo la tiene el gateway,
-- que la pasa a los RPC lectores. La web lee a través del gateway (entrada interna `WebGroupsReader`), nunca directo.
--
-- PRODUCCIÓN: NO. Marcha atrás: web3_01_rollback.sql.

-- 1. ¿Es un token de Yala web? Mismo criterio que el hook (web0_01): el claim `client_id` o, si un token reemitido no lo
--    trae, el cliente OAuth de la SESIÓN. SECURITY DEFINER para leer `auth.sessions`; sin parámetros: solo mira el JWT
--    de quien llama.
create or replace function public.yala_is_web_reader()
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  web_client constant uuid := '03e0f13b-818f-4a93-8e69-701ea6343fda';
  claims jsonb := coalesce(auth.jwt(), '{}'::jsonb);
  cid text := nullif(claims->>'client_id', '');
  sid text := nullif(claims->>'session_id', '');
  session_cid uuid;
begin
  if cid = web_client::text then
    return true;
  end if;
  if sid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select s.oauth_client_id into session_cid from auth.sessions s where s.id = sid::uuid;
    return session_cid = web_client;
  end if;
  return false;
end;
$$;
revoke all on function public.yala_is_web_reader() from public, anon, authenticated;
grant execute on function public.yala_is_web_reader() to yala_mcp_reader;

-- 2. SELECT sobre las cinco tablas de Grupos. La RLS de abajo decide qué filas.
grant select on public.split_groups, public.group_members, public.split_expenses, public.split_shares,
  public.split_settlements to yala_mcp_reader;

-- 3. Las mismas condiciones que las políticas de `authenticated` (membresía o escritor del grupo), más la de la web.
--    `(select …)` hace que el helper se evalúe una vez por consulta y no por fila.
--    OJO: si una migración futura hace DROP + CREATE de un `groups_pull_rows_*` (como g14_01), pierde el EXECUTE de
--    este fichero y Grupos de la web responde 503 hasta volver a darlo.
drop policy if exists web_reader_select on public.split_groups;
create policy web_reader_select on public.split_groups for select to yala_mcp_reader
  using ((select public.yala_is_web_reader()) and public.is_group_member(group_id));
drop policy if exists web_reader_select on public.group_members;
create policy web_reader_select on public.group_members for select to yala_mcp_reader
  using ((select public.yala_is_web_reader()) and public.is_group_member(group_id));
drop policy if exists web_reader_select on public.split_expenses;
create policy web_reader_select on public.split_expenses for select to yala_mcp_reader
  using ((select public.yala_is_web_reader()) and public.is_group_writer(group_id));
drop policy if exists web_reader_select on public.split_shares;
create policy web_reader_select on public.split_shares for select to yala_mcp_reader
  using ((select public.yala_is_web_reader()) and public.is_group_writer(group_id));
drop policy if exists web_reader_select on public.split_settlements;
create policy web_reader_select on public.split_settlements for select to yala_mcp_reader
  using ((select public.yala_is_web_reader()) and public.is_group_writer(group_id));

-- 4. Los helpers de membresía y descifrado (SECURITY DEFINER, ya existentes) y los cinco RPC lectores.
grant execute on function public.is_group_member(text), public.is_group_writer(text),
  public.yala_try_decrypt(bytea, text) to yala_mcp_reader;
grant execute on function
  public.groups_pull_rows_split_groups(text, bigint, int, text),
  public.groups_pull_rows_group_members(text, bigint, int, text),
  public.groups_pull_rows_split_expenses(text, bigint, int, text),
  public.groups_pull_rows_split_shares(text, bigint, int, text),
  public.groups_pull_rows_split_settlements(text, bigint, int, text)
  to yala_mcp_reader;
