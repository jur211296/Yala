-- =====================================================================================================
-- g17_01 · El claim de la vuelta a iCloud ya no borra la prueba de que la cuenta volvió
--
-- QUÉ GANA EL USUARIO. Tiene Yala en dos iPhone con la misma cuenta en la nube y en el primero ya volvió a
-- iCloud. En el segundo pulsa «Volver a iCloud», sale de la espera (o pierde la respuesta del servidor) y lo
-- intenta otra vez: el reintento avanza. Hasta hoy recibía «tu cuenta no lo permitía» y su única salida era
-- escribir a soporte. Ticket `reverse-exit-on-a-reverted-account-rejects-the-retry`.
--
-- === EL BUG, MEDIDO EN EL CUERPO VIVO DE PRODUCCIÓN (md5 14fc5e2c…, 2026-09-16) ===
--   `reverse_complete` degrada la cuenta a `kind = 'groups_only'` y estampa `reverted_at`. El guard de
--   `reverse_claim` (g15_02) deja pasar a quien es `complete` **o** tiene `reverted_at`: así el SEGUNDO
--   dispositivo puede seguir la vuelta del primero. Pero el claim FRESCO (y todo takeover) pone
--   `reverted_at = null`, y `reverse_abort` no lo devuelve. Tres caminos al mismo `not_complete`:
--
--     1. B reclama, sale de la espera → `reverse_abort` → reintenta: `groups_only` sin `reverted_at`.
--     2. B reclama con éxito y pierde la respuesta → reintenta: el guard corta ANTES de la rama del re-claim
--        idempotente del mismo líder.
--     3. B sube durante horas; C pulsa «Volver a iCloud»: el guard corta antes de mirar líder y lease, así que
--        C oye `not_complete` («tu cuenta no lo permitía») en vez de `other_leader`.
--
-- === EL CAMBIO ===
--   Cada `reverted_at = null` del cuerpo pasa a
--
--       reverted_at = case when kind = 'complete' then null else reverted_at end
--
--   La expresión vive en el SET de un UPDATE, así que `kind` y `reverted_at` son los de la fila ANTES de
--   escribir. Con la cuenta `complete` da `null`, exactamente lo de hoy: el golden 17 (claim fresco que limpia
--   los marcadores de un run anterior) y el takeover de una ida abandonada, que siempre es `complete` porque
--   `claim_account` escribe `kind = 'complete'` en el mismo UPDATE que arma la ida (g15_02, cabecera). Solo
--   cambia en una cuenta `groups_only`, y la única `groups_only` que llega a esos UPDATE es la que entró por la
--   mitad `reverted_at` del guard: la que YA volvió a iCloud. Ahí `reverted_at` se conserva, y con él la puerta.
--
--   Por qué así y no las otras dos opciones del ticket: que `reverse_abort` restaure el valor previo exige
--   guardarlo en una columna nueva y no cubre el camino 2 sin abort; mover el guard detrás de reserva, líder y
--   lease cierra los caminos 2 y 3 pero deja el 1.
--
--   `reverse_abort` sigue igual: des-congela (`reverse_in_progress = false`, `reverse_frozen_at = null`) y no
--   toca `reverted_at`. `reverse_complete` escribe `coalesce(reverted_at, now())` (g15_01 §5), así que en una
--   cuenta ya revertida conserva la hora de la PRIMERA vuelta en vez de poner la del 2.º dispositivo: nadie lee
--   el valor, solo si es nulo. Dentro de la función lo leen el guard y `reverse_complete`, que con
--   `reverted_at` puesto y sin vuelta en curso contesta `ok` idempotente (como ya hacía en toda cuenta revertida
--   antes del claim de otro dispositivo). Fuera, nadie: ni el Worker
--   (`gateway/src/sync/account.ts` solo lo nombra en comentarios), ni `claim_account` (g16_02 lista su select),
--   ni el 409 de `/sync/push` (mira solo `reverse_frozen_at`).
--
-- === LA APP INSTALADA NO CAMBIA DE CONTRATO ===
--   Misma firma, mismos campos en la respuesta y los mismos códigos (`not_complete`, `other_leader`,
--   `migration_in_progress`, `ok`). Lo que cambia es CUÁL recibe en estos tres caminos, y las tres respuestas
--   nuevas ya las lee hoy: `ok` avanza, `other_leader` vuelve al origen sin efectos (`reverseOtherLeader`).
--
-- === Y LAS CUENTAS QUE EL BUG YA ATASCÓ SE REPARAN (§1-bis) ===
--   Cambiar la función no cura a quien ya cayó: su fila sigue `groups_only` sin `reverted_at` y el guard le
--   contesta `not_complete` en todos sus dispositivos, también si quedó con una vuelta suya reservada (camino 2:
--   el cliente no manda `reverse_abort` tras un rechazo). El §1-bis le devuelve `reverted_at` a esas filas y
--   a ninguna más. El predicado es exacto:
--
--       kind = 'groups_only' and personal_claimed_at is not null and reverted_at is null
--
--   `personal_claimed_at` solo lo estampa un alta personal o la promoción, que escriben `kind = 'complete'` en
--   el mismo UPDATE; la única degradación `complete → groups_only` es `reverse_complete`, que deja
--   `reverted_at` puesto (g15_01 §5); y lo único que lo vuelve a null es el claim que esta migración arregla.
--   Una cuenta de solo grupos que nunca tuvo lo personal tiene `personal_claimed_at` nulo y no se toca. No
--   toca `kind`, así que el trigger `profiles_kind_guard` no interviene. Idempotente: tras la migración ningún
--   camino vuelve a producir esas filas, y una segunda pasada no encuentra ninguna.
--
-- === migration_progress SE TRANSFORMA, NO SE RE-PEGA (igual que g15_01 y g15_02) ===
--   Se parte de la definición VIVA, se sustituye cada escritura y se verifica de dónde se sale y a dónde se
--   llega. Una copia del cuerpo de partida vive en `qa/cloud/fixtures/` para el banco, no para aplicarla.
--
--   **Las escrituras se buscan por PATRÓN, no por literal.** En el cuerpo vivo están alineadas con sus vecinas
--   (`reverted_at          = null`, dos con 10 espacios y una con 11), y la primera versión de este fichero,
--   que buscaba `'reverted_at = null'` con un espacio, abortó en staging el 2026-10-09 sin tocar nada. El
--   patrón `\mreverted_at(\s*)=(\s*)null\M` captura el espacio de cada lado del `=` y la sustitución lo
--   devuelve tal cual, así que la alineación se conserva y la inversa es exacta. Sigue exigiendo exactamente 3,
--   y un segundo recuento más amplio (`reverted_at\s*=\s*null`, sin distinguir mayúsculas ni exigir palabra
--   entera) tiene que coincidir: una grafía que la sustitución no tocaría (`REVERTED_AT = NULL`, `nullif(…)`)
--   aborta.
--
--   **Estados de partida** (§0), los dos con salida definida:
--
--     cuerpo vivo                                            | estado    | qué hace
--     -------------------------------------------------------|-----------|---------------------------------
--     md5 14fc5e2c54766dd7c5706966c7381f51 (g15_02 final)     | virgen    | la sustitución + §2 + §3
--     sin escrituras a null, tres condicionales, y deshacer  | aplicado  | no-op, pero el §3 corre IGUAL
--       la sustitución vuelve EXACTAMENTE al md5 virgen      |           |
--     cualquier otro                                         | divergido | ABORTA
--
--   El estado «aplicado» se reconoce por la inversa exacta, no por un md5 propio. Sobre el cuerpo real exportado
--   de staging (el mismo md5 que producción) el banco mide md5(prosrc) **776dac35d585393fabeabedf8eafee82** tras
--   la migración, y el §1 lo anuncia al aplicarla: tiene que salir ése en staging y en producción.
--
-- === APLICACIÓN ===
--   NO trae `begin;`/`commit;`: `apply_migration` ya envuelve en transacción. Por psql, **`-1` NO es
--   opcional**: sin él el §1 se confirma antes de que corra el §3, y un §3 en rojo dejaría el cambio puesto
--   (medido en la review). La GUC con la que el §0 avisa al §1 es local a la transacción por lo mismo.
--
--       psql -1 -v ON_ERROR_STOP=1 -f qa/cloud/g17_01_reverse_claim_keeps_reverted_at.sql "$SUPABASE_DB_URL"
--
--   Marcha atrás: `qa/cloud/g17_01_rollback.sql` (vuelve al md5 14fc5e2c…).
--
--   Probado en local en las dos direcciones (`qa/cloud/g17_01-local-test.sh`, Postgres 17) contra DOS cuerpos:
--   el real de staging (fixture, md5 14fc5e2c…; el fichero corre sin tocar) y una réplica con un espacio por
--   escritura. En los dos: con el cuerpo viejo el §3 aborta con los cuatro escenarios del ticket; con el nuevo
--   pasa 11/11; el §1-bis repara la cuenta atascada y no toca ni la de solo grupos pura ni la `complete`; el
--   rollback devuelve el md5 de partida; la re-aplicación es no-op; un cuerpo divergido, una cuarta escritura o
--   una cuarta con otra grafía abortan sin tocar nada. Review adversarial de dos lentes (SQL y consumidores).
-- =====================================================================================================

-- ── 0 · Guarda de partida ────────────────────────────────────────────────────────────────────────────
do $guard$
declare
  v_src  text;
  -- Los patrones, no literales: en el cuerpo vivo las escrituras están ALINEADAS (`reverted_at          = null`,
  -- 10 u 11 espacios). Cada uno captura el espacio de los dos lados del `=` para devolverlo tal cual.
  v_pat_old text := '\mreverted_at(\s*)=(\s*)null\M';
  v_pat_new text := '\mreverted_at(\s*)=(\s*)case when kind = ''complete'' then null else reverted_at end';
  v_inv     text := 'reverted_at\1=\2null';
  v_virgen text := '14fc5e2c54766dd7c5706966c7381f51';
begin
  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'migration_progress' and p.pronargs = 2;

  if v_src is null then
    raise exception 'g17_01: migration_progress(text,text) no existe. Abortada.';
  end if;

  if md5(v_src) = v_virgen then
    perform set_config('yala.g17_01_estado', 'virgen', true);
  elsif (select count(*) from regexp_matches(v_src, 'reverted_at\s*=\s*null', 'gi')) = 0
        and (select count(*) from regexp_matches(v_src, v_pat_new, 'g')) = 3
        and md5(regexp_replace(v_src, v_pat_new, v_inv, 'g')) = v_virgen then
    perform set_config('yala.g17_01_estado', 'final', true);
    raise notice 'g17_01: ya aplicada (md5 %). No-op; el §3 se ejecuta igual.', md5(v_src);
  else
    raise exception 'g17_01: migration_progress no es ni el cuerpo de g15_02 ni el de g17_01 (md5 %). Abortada.', md5(v_src);
  end if;
end $guard$;

-- ── 1 · La transformación ────────────────────────────────────────────────────────────────────────────
do $mig$
declare
  v_src text;
  v_new_src text;
  v_pat_old text := '\mreverted_at(\s*)=(\s*)null\M';
  v_pat_new text := '\mreverted_at(\s*)=(\s*)case when kind = ''complete'' then null else reverted_at end';
  v_sust    text := 'reverted_at\1=\2case when kind = ''complete'' then null else reverted_at end';
  v_inv     text := 'reverted_at\1=\2null';
  v_virgen  text := '14fc5e2c54766dd7c5706966c7381f51';
  v_n_literal int;
  v_n_cualquier int;
  v_estado text := coalesce(nullif(current_setting('yala.g17_01_estado', true), ''), 'final');
begin
  if v_estado = 'final' then
    return;
  end if;

  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'migration_progress' and p.pronargs = 2;

  -- Cuántas escrituras tiene la grafía que la sustitución toca (minúsculas, palabra entera, CUALQUIER espaciado
  -- alrededor del `=`: el cuerpo vivo las alinea), y cuántas cualquier escritura de `reverted_at` a null con
  -- otra grafía (mayúsculas, `nullif(…)`, un prefijo). Si difieren, hay una que esta sustitución no tocaría y
  -- la inversa del §0 dejaría de ser exacta: se aborta en vez de adivinar.
  v_n_literal   := (select count(*) from regexp_matches(v_src, v_pat_old, 'g'));
  v_n_cualquier := (select count(*) from regexp_matches(v_src, 'reverted_at\s*=\s*null', 'gi'));

  -- Exactamente TRES: el claim fresco y los dos takeovers (README §«Reversa server-side»). PL/pgSQL no analiza
  -- un UPDATE hasta ejecutarlo, así que una cuarta escritura en una rama que el §3 no recorre (otra tabla, sin
  -- columna `kind`) pasaría en verde y reventaría en la cara del primer usuario (medido en la review con una
  -- réplica). Si el cuerpo vivo tiene otro número, léelo con `pg_get_functiondef` antes de tocar este 3.
  if v_n_literal <> 3 then
    raise exception 'g17_01: «reverted_at = null» (con cualquier espaciado) aparece % vez/veces en migration_progress; se esperaban 3. Abortada.', v_n_literal;
  end if;
  if v_n_cualquier <> v_n_literal then
    raise exception 'g17_01: % escrituras de reverted_at a null y solo % con la grafía esperada. Abortada.',
      v_n_cualquier, v_n_literal;
  end if;

  -- Cada escritura conserva su espaciado: `reverted_at          = null` pasa a
  -- `reverted_at          = case when … end`. Así la inversa es exacta y el §0 reconoce el estado «aplicado».
  v_new_src := regexp_replace(v_src, v_pat_old, v_sust, 'g');
  if (select count(*) from regexp_matches(v_new_src, v_pat_new, 'g')) <> v_n_literal
     or md5(regexp_replace(v_new_src, v_pat_new, v_inv, 'g')) <> v_virgen then
    raise exception 'g17_01: la sustitución no es exactamente invertible (md5 de la inversa %). Abortada.',
      md5(regexp_replace(v_new_src, v_pat_new, v_inv, 'g'));
  end if;
  raise notice 'g17_01: % sustitución(es) de «reverted_at = null».', v_n_literal;

  execute format(
    'create or replace function public.migration_progress(p_device_id text, p_action text) returns jsonb language plpgsql set search_path = public as %L',
    v_new_src);
  raise notice 'g17_01: md5 nuevo de migration_progress: %.', md5(v_new_src);
end $mig$;

-- ── 1-bis · Reparar las cuentas que el bug ya atascó ─────────────────────────────────────────────────
-- Corre también en la rama ya-aplicada: así el fichero re-ejecutado sirve de barrido.
do $repara$
declare
  v_n int;
begin
  update public.profiles
     set reverted_at = coalesce(reverse_frozen_at, migration_updated_at, now())
   where kind = 'groups_only'
     and personal_claimed_at is not null
     and reverted_at is null;
  get diagnostics v_n = row_count;
  raise notice 'g17_01: % cuenta(s) ya revertida(s) recuperan reverted_at.', v_n;
end $repara$;

-- ── 2 · Verificación ESTRUCTURAL ─────────────────────────────────────────────────────────────────────
do $verify$
declare
  v_src text;
  v_ret jsonb;
begin
  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'migration_progress' and p.pronargs = 2;

  -- Por patrón, como el §1: con un literal de un espacio esto fallaría en el cuerpo alineado.
  if (select count(*) from regexp_matches(v_src,
        '\mreverted_at(\s*)=(\s*)case when kind = ''complete'' then null else reverted_at end', 'g')) <> 3 then
    raise exception 'g17_01 verify: la escritura condicional no está tres veces en el cuerpo';
  end if;
  if (select count(*) from regexp_matches(v_src, 'reverted_at\s*=\s*null', 'gi')) <> 0 then
    raise exception 'g17_01 verify: sigue habiendo un reverted_at = null incondicional';
  end if;
  -- `create or replace` fija los atributos: tienen que seguir siendo los de g15_02 (invoker, search_path).
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                  where n.nspname = 'public' and p.proname = 'migration_progress' and p.pronargs = 2
                    and not p.prosecdef and p.proconfig = array['search_path=public']) then
    raise exception 'g17_01 verify: migration_progress perdió sus atributos (security invoker + search_path=public)';
  end if;
  -- El guard de g15_02 sigue en pie: esta migración no lo toca.
  if position($v$if v_kind is distinct from 'complete' and v_reverted is null then$v$ in v_src) = 0 then
    raise exception 'g17_01 verify: el guard de g15_02 ya no está en el cuerpo';
  end if;

  -- La función SIGUE COMPILANDO: plpgsql valida el cuerpo en la primera llamada. Un `sub` sintético sin fila
  -- sale por `no_profile` sin escribir nada, después de recorrer el prólogo.
  perform set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid()::text)::text, true);
  v_ret := public.migration_progress('g17-01-verify', 'reverse_claim');
  if v_ret->>'reason' is distinct from 'no_profile' then
    raise exception 'g17_01 verify: la llamada de humo devolvió % (se esperaba no_profile)', v_ret;
  end if;
  perform set_config('request.jwt.claims', '', true);
end $verify$;

-- ── 3 · Verificación de COMPORTAMIENTO ───────────────────────────────────────────────────────────────
-- El §2 mira TEXTO. Esto recorre los caminos del ticket contra el motor real con usuarios sintéticos. Cada
-- escenario vive en su propio bloque con `exception`, o sea en su propio SAVEPOINT: al terminar lanza
-- `g17_01_deshacer` y vuelve al savepoint, así que no queda ninguna fila y las GUC vuelven a su valor. Los
-- resultados viven en variables de PL/pgSQL, que sobreviven al rollback del savepoint.
--
-- Columnas: etiqueta | partida | secuencia de llamadas `DISPOSITIVO:acción` separadas por `>` | lo que
-- devuelve la ÚLTIMA | `reverted_at` tras la secuencia (`set`/`null`/`-` = no se mira) | rol de las llamadas.
-- Dispositivos: A = el que ya volvió (solo en la partida), B = el segundo, C = el tercero.
-- Partidas:
--   revertida  = `groups_only` + `reverted_at` puesto, sin vuelta en curso (lo que deja `reverse_complete`)
--   rev_ajena  = revertida con una vuelta de X en curso y el lease VENCIDO (para el takeover)
--   complete_marcas = `complete` con `reverted_at` y `reverse_frozen_at` de un run anterior (golden 17)
--   born       = `complete`, nunca migró
--   pura       = `groups_only` que nunca revirtió
--   mip_vieja  = `complete` con una ida abandonada (lease vencido, golden 12)
--
-- Las cuatro primeras filas son los caminos del ticket y FALLAN con el cuerpo de g15_02 (medido en local).
do $conducta$
declare
  v_uid     uuid;
  v_ret     jsonb;
  v_last    text;
  v_rev     text;
  v_frozen  text;
  v_fallos  text := '';
  v_n       int := 0;
  v_paso    text;
  v_dev     text;
  v_act     text;
  e         text[];
  escen text[][] := array[
    array['(a) revertida: claim fresco > salir > reintento → avanza',              'revertida',       'B:reverse_claim>B:reverse_abort>B:reverse_claim',                       'ok',           'set',  'postgres'],
    array['(a) lo mismo con el rol de PostgREST',                                  'revertida',       'B:reverse_claim>B:reverse_abort>B:reverse_claim',                       'ok',           'set',  'authenticated'],
    array['(a) con congelado antes de salir: el abort sigue des-congelando',       'revertida',       'B:reverse_claim>B:reverse_freeze>B:reverse_abort',                      'ok',           'set',  'postgres'],
    array['(b) claim con éxito y respuesta perdida → re-claim idempotente',        'revertida',       'B:reverse_claim>B:reverse_claim',                                       'ok',           'set',  'postgres'],
    array['(c) tres dispositivos: B sube, C pulsa → other_leader',                 'revertida',       'B:reverse_claim>C:reverse_claim',                                       'other_leader', 'set',  'postgres'],
    array['takeover de una vuelta ajena vencida > salir > reintento → avanza',     'rev_ajena',       'B:reverse_claim>B:reverse_abort>B:reverse_claim',                       'ok',           'set',  'postgres'],
    array['revertida: la vuelta del 2.º termina y estampa reverted_at',            'revertida',       'B:reverse_claim>B:reverse_freeze>B:reverse_complete',                   'ok',           'set',  'postgres'],
    array['complete con marcas viejas: el claim fresco las limpia (golden 17)',    'complete_marcas', 'B:reverse_claim',                                                       'ok',           'null', 'postgres'],
    array['born-cloud complete → entra (g15_02)',                                  'born',            'B:reverse_claim',                                                       'ok',           'null', 'postgres'],
    array['solo grupos que nunca revirtió → not_complete (g15_02)',                'pura',            'B:reverse_claim',                                                       'not_complete', 'null', 'postgres'],
    array['ida abandonada con lease vencido → takeover (golden 12)',               'mip_vieja',       'B:reverse_claim',                                                       'ok',           'null', 'postgres']
  ];
begin
  foreach e slice 1 in array escen loop
    v_n := v_n + 1;
    v_last := null; v_rev := null; v_frozen := null;
    begin
      v_uid := gen_random_uuid();
      insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
        values (v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
                'g17-01-verify-' || replace(v_uid::text, '-', '') || '@invalid.local', now(), now());

      perform set_config('yala.kind_write', txid_current()::text, true);
      if e[2] = 'revertida' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, migrated_at, reverted_at,
                                     reverse_frozen_at, leader_device_id, migration_updated_at)
          values (v_uid, 'apple', 'groups_only', now(), now() - interval '2 days', now() - interval '1 day',
                  now() - interval '1 day', 'g17-01-A', now() - interval '1 day');
      elsif e[2] = 'rev_ajena' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, migrated_at, reverted_at,
                                     reverse_in_progress, reverse_frozen_at, leader_device_id, migration_updated_at)
          values (v_uid, 'apple', 'groups_only', now(), now() - interval '2 days', now() - interval '1 day',
                  true, null, 'g17-01-X', now() - interval '90 minutes');
      elsif e[2] = 'complete_marcas' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, migrated_at, reverted_at,
                                     reverse_frozen_at, leader_device_id, migration_updated_at)
          values (v_uid, 'apple', 'complete', now(), '2026-01-01', '2026-02-01', '2026-02-01',
                  null, now());
      elsif e[2] = 'born' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, leader_device_id, migration_updated_at)
          values (v_uid, 'apple', 'complete', now(), 'g17-01-A', now());
      elsif e[2] = 'pura' then
        insert into public.profiles (id, provider, kind, migrated_at, leader_device_id, migration_updated_at)
          values (v_uid, 'apple', 'groups_only', '2026-01-01', 'g17-01-A', now());
      elsif e[2] = 'mip_vieja' then
        insert into public.profiles (id, provider, kind, personal_claimed_at, migrated_at, migration_in_progress,
                                     leader_device_id, migration_updated_at)
          values (v_uid, 'apple', 'complete', now(), '2026-01-01', true, 'g17-01-X', now() - interval '90 minutes');
      else
        raise exception 'partida desconocida %', e[2];
      end if;
      perform set_config('yala.kind_write', '', true);

      perform set_config('request.jwt.claims',
                         json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);
      if e[6] = 'authenticated' then
        perform set_config('role', 'authenticated', true);
      end if;

      -- Toda llamada salvo la última tiene que salir `ok`: si no, el escenario no recorre el camino que dice.
      foreach v_paso in array string_to_array(e[3], '>') loop
        v_dev := 'g17-01-' || split_part(v_paso, ':', 1);
        v_act := split_part(v_paso, ':', 2);
        if v_last is not null and v_last <> 'ok' then
          raise exception 'un paso intermedio devolvió %', v_last;
        end if;
        v_ret := public.migration_progress(v_dev, v_act);
        v_last := case when v_ret->>'ok' = 'true' then 'ok' else coalesce(v_ret->>'reason', '<sin reason>') end;
      end loop;

      -- Con el rol de PostgREST la fila se lee por RLS, como la lee la app (es la suya).
      select case when reverted_at is null then 'null' else 'set' end,
             case when reverse_frozen_at is null then 'null' else 'set' end
        into v_rev, v_frozen
        from public.profiles where id = v_uid;

      raise exception 'g17_01_deshacer';
    exception
      when others then
        if sqlerrm <> 'g17_01_deshacer' then
          v_fallos := v_fallos || format(E'\n  · %s: %s (última respuesta %s)', e[1], sqlerrm, coalesce(v_last, '-'));
        elsif v_last is distinct from e[4] then
          v_fallos := v_fallos || format(E'\n  · %s: esperado %s, obtenido %s', e[1], e[4], v_last);
        elsif e[5] <> '-' and v_rev is distinct from e[5] then
          v_fallos := v_fallos || format(E'\n  · %s: reverted_at esperado %s, obtenido %s', e[1], e[5], v_rev);
        elsif e[3] like '%reverse_abort' and v_frozen is distinct from 'null' then
          v_fallos := v_fallos || format(E'\n  · %s: el abort dejó la cuenta congelada', e[1]);
        end if;
    end;
  end loop;

  if v_fallos <> '' then
    raise exception 'g17_01 conducta: fallaron escenarios (de %):%', v_n, v_fallos;
  end if;
  raise notice 'g17_01 OK · %/% escenarios · el 2.º dispositivo de una cuenta ya revertida puede salir y reintentar.', v_n, v_n;
end $conducta$;
