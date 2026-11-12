-- g27_01 · marcha atrás: quita el candado de saldos iniciales y deja `split_expenses` y `split_shares` como estaban
-- (solo sus políticas de siempre: cualquier miembro activo escribe).
--
-- No reescribe filas: lo que se escribió con el candado puesto es el estado real del grupo. Idempotente: sin los
-- triggers ni la función, no cambia nada. Comprobación después:
--   select tgrelid::regclass, tgname from pg_trigger where tgname = 'opening_balance_guard';            -- 0 filas
--   select count(*) from pg_proc where proname = 'opening_balance_guard' and pronamespace = 'public'::regnamespace; -- 0

drop trigger if exists opening_balance_guard on public.split_expenses;
drop trigger if exists opening_balance_guard on public.split_shares;
drop function if exists public.opening_balance_guard();
