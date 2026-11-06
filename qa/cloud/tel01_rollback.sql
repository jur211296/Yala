-- tel01_rollback — deshace tel01_stats_counts.sql. El panel deja de recibir los conteos de la base y lo dice.
revoke execute on function public.yala_stats_counts() from yala_stats;
drop function if exists public.yala_stats_counts();
revoke usage on schema public from yala_stats;
revoke yala_stats from authenticator;
drop role if exists yala_stats;
