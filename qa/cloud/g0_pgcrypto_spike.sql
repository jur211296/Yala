-- g0_pgcrypto_spike — Spike B de G0 (Grupos→backend): pgcrypto llave-por-request + hash sobre plaintext.
-- DESECHABLE. Solo staging (fostjbbwstyuunmmefuk), NUNCA prod. Drift INTENCIONAL vs supabase-staging.ddl
-- (no se regenera el contrato por esto). Cleanup al cerrar el spike: g0_pgcrypto_spike_cleanup.sql.
--
-- Aplicar vía MCP de Supabase (nombre de migración: g0_pgcrypto_spike) o pegando en el SQL editor.
-- Verificación: bash qa/cloud/pgcrypto-spike-test.sh

create extension if not exists pgcrypto;

create table public.spike_enc (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null default auth.uid(),
  ciphertext   bytea not null,
  content_hash text  not null, -- sha256 hex del PLAINTEXT canónico (UTF8) — estable ante re-cifrado
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.spike_enc enable row level security;
create policy spike_enc_select_own on public.spike_enc
  for select to authenticated using (owner_id = (select auth.uid()));
create policy spike_enc_insert_own on public.spike_enc
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy spike_enc_update_own on public.spike_enc
  for update to authenticated using (owner_id = (select auth.uid()));
-- Sin policy de DELETE (mismo principio que las tablas de sync: sin borrado físico).

-- Hash canónico: función ÚNICA = una sola definición de canonicalización.
create or replace function public.spike_canonical_hash(p_plaintext text)
returns text language sql immutable set search_path = public
as $$ select encode(digest(convert_to(p_plaintext, 'UTF8'), 'sha256'), 'hex') $$;

-- RPC 1: write (llave como ARGUMENTO — variante base).
create or replace function public.spike_enc_write(p_plaintext text, p_key text)
returns uuid language plpgsql security invoker set search_path = public as $$
declare v_id uuid;
begin
  insert into spike_enc (ciphertext, content_hash)
  values (pgp_sym_encrypt(p_plaintext, p_key), spike_canonical_hash(p_plaintext))
  returning id into v_id;
  return v_id;
end $$;

-- RPC 2: read con error SANITIZADO (jamás interpolar p_key ni sqlerrm crudo).
create or replace function public.spike_enc_read(p_id uuid, p_key text)
returns text language plpgsql security invoker set search_path = public as $$
declare v_plain text;
begin
  select pgp_sym_decrypt(ciphertext, p_key) into v_plain
    from spike_enc where id = p_id; -- RLS filtra cross-user AQUÍ (antes de descifrar)
  if v_plain is null then
    raise exception 'yala_not_found';
  end if;
  return v_plain;
exception when others then
  if sqlerrm like '%yala_not_found%' then raise exception 'yala_not_found'; end if;
  raise exception 'yala_bad_key';
end $$;

-- RPC 3: rekey — re-cifra con llave nueva SIN tocar content_hash (la prueba de estabilidad).
create or replace function public.spike_enc_rekey(p_id uuid, p_old_key text, p_new_key text)
returns void language plpgsql security invoker set search_path = public as $$
begin
  update spike_enc
     set ciphertext = pgp_sym_encrypt(pgp_sym_decrypt(ciphertext, p_old_key), p_new_key),
         updated_at = now()
   where id = p_id;
  if not found then raise exception 'yala_not_found'; end if;
exception when others then
  if sqlerrm like '%yala_not_found%' then raise exception 'yala_not_found'; end if;
  raise exception 'yala_bad_key';
end $$;

-- RPC 4: verificación de hash (stored vs recomputado sobre el plaintext descifrado).
create or replace function public.spike_enc_hash(p_id uuid, p_key text)
returns table (stored_hash text, computed_hash text, matches boolean)
language sql security invoker set search_path = public as $$
  select content_hash,
         spike_canonical_hash(pgp_sym_decrypt(ciphertext, p_key)),
         content_hash = spike_canonical_hash(pgp_sym_decrypt(ciphertext, p_key))
    from spike_enc where id = p_id
$$;

-- RPC 5: variante GUC (SET LOCAL). NOTA de diseño: cada POST /rpc de PostgREST es su propia
-- transacción — set_config(is_local=true) NO sobrevive a un segundo RPC. La llave entra igual
-- como argumento; la variante solo mide si el GUC aporta algo (hipótesis: solo ergonomía
-- interna para triggers/funciones anidadas, cero aislamiento extra de logs).
create or replace function public.spike_enc_read_local(p_id uuid, p_key text)
returns text language plpgsql security invoker set search_path = public as $$
declare v_plain text;
begin
  perform set_config('yala.enc_key', p_key, true);
  select pgp_sym_decrypt(ciphertext, current_setting('yala.enc_key')) into v_plain
    from spike_enc where id = p_id;
  if v_plain is null then raise exception 'yala_not_found'; end if;
  return v_plain;
exception when others then
  if sqlerrm like '%yala_not_found%' then raise exception 'yala_not_found'; end if;
  raise exception 'yala_bad_key';
end $$;

-- GRANTs mínimos: nada para anon; authenticated solo lo necesario.
revoke all on table public.spike_enc from anon, authenticated;
grant select, insert, update on public.spike_enc to authenticated;
revoke all on function public.spike_canonical_hash(text) from public, anon;
revoke all on function public.spike_enc_write(text, text) from public, anon;
revoke all on function public.spike_enc_read(uuid, text) from public, anon;
revoke all on function public.spike_enc_rekey(uuid, text, text) from public, anon;
revoke all on function public.spike_enc_hash(uuid, text) from public, anon;
revoke all on function public.spike_enc_read_local(uuid, text) from public, anon;
grant execute on function public.spike_canonical_hash(text) to authenticated;
grant execute on function public.spike_enc_write(text, text) to authenticated;
grant execute on function public.spike_enc_read(uuid, text) to authenticated;
grant execute on function public.spike_enc_rekey(uuid, text, text) to authenticated;
grant execute on function public.spike_enc_hash(uuid, text) to authenticated;
grant execute on function public.spike_enc_read_local(uuid, text) to authenticated;
