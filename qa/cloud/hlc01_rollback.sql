-- hlc01_rollback — retira el tope a un HLC futuro (`hlc01_cap_future_hlc.sql`).
-- Quita los 22 triggers y las cinco funciones. La normalización NO se deshace: solo acotó HLC por encima de
-- `now() + 60 s` y no tocó ningún valor. Idempotente.

begin;

do $$
declare
  c_tables constant text[] := array[
    'accounts','budgets','cashflow_lines','cashflow_overrides','cashflow_plans','categories','exchange_rates',
    'favorite_payments','group_bridge_prefs','inbox_drafts','merchant_memory','notification_items',
    'scheduled_payments','subcategories','tags','tx_items','user_preferences',
    'split_groups','group_members','split_expenses','split_shares','split_settlements'];
  v_t text;
begin
  foreach v_t in array c_tables loop
    if to_regclass(format('public.%I', v_t)) is not null then
      execute format('drop trigger if exists cap_future_hlc on public.%I', v_t);
    end if;
  end loop;
end
$$;

drop function if exists public.cap_future_hlc();
drop function if exists public.hlc_cap_patch(jsonb, text);
drop function if exists public.hlc_cap_value(text, text);
drop function if exists public.hlc_cap_instant();
drop function if exists public.hlc_cap_margin();

commit;
