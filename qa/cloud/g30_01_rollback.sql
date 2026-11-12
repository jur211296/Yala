-- g30_01 · marcha atrás: quita el trigger que anula el autor de un gasto cuando lo edita un teléfono que no lo conoce.
--
-- Vuelve el comportamiento de g29_01 a secas: la edición de un teléfono 2.1 conserva el autor ANTERIOR. No reescribe
-- filas: los autores que el trigger dejó en NULL se quedan así (no se sabe quién editó, y el aviso cae al pagador) hasta
-- la siguiente edición desde la 2.2. Idempotente: sin el trigger ni la función, no cambia nada. Comprobación después:
--   select count(*) from pg_trigger where tgname = 'expense_author_from_v2_clients';                                  -- 0
--   select count(*) from pg_proc where proname = 'expense_author_from_v2_clients' and pronamespace = 'public'::regnamespace; -- 0

drop trigger if exists expense_author_from_v2_clients on public.split_expenses;
drop function if exists public.expense_author_from_v2_clients();
