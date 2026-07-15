-- g0_pgcrypto_spike_cleanup — retiro del Spike B de G0. Aplicar SOLO al cerrar el spike
-- (veredicto escrito en MODO-NUBE-GRUPOS-BACKEND-V1-DISENO §3/§8/R2). Solo staging.
-- La extensión pgcrypto NO se dropea (G7 la usará; y digest() puede tener otros consumidores).

drop function if exists public.spike_enc_read_local(uuid, text);
drop function if exists public.spike_enc_hash(uuid, text);
drop function if exists public.spike_enc_rekey(uuid, text, text);
drop function if exists public.spike_enc_read(uuid, text);
drop function if exists public.spike_enc_write(text, text);
drop function if exists public.spike_canonical_hash(text);
drop table if exists public.spike_enc;
