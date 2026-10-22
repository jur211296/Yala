---
esfuerzo: medium
---
# Los dos snapshots `.ddl` llevan el trigger `cap_future_hlc` y el runbook da `hlc01` por aplicada en staging y producción

## Contexto
La migración `qa/cloud/hlc01_cap_future_hlc.sql` (tope en el servidor a un HLC del futuro, PR #382) ya se aplicó en staging (`fostjbbwstyuunmmefuk`) y en producción (`kefvaiymtgytemwbltlz`) el 2026-10-07: 22 triggers `cap_future_hlc` y sonda `qa/cloud/hlc01-cap-staging-probe.sh` 4/4. Es lo único que se sabe del aplicado: no hay hora, ni número de filas normalizadas, ni quién lo corrió. No lo inventes; si lo encuentras escrito en algún sitio del repo, cítalo con su fuente.

El repo todavía la da por pendiente:
- `docs/RUNBOOK-staging-ddl.md`, sección «`hlc01_cap_future_hlc.sql` — tope a un HLC del futuro (staging y producción, PENDIENTE desde el 2026-10-07)», que dice «Sin aplicar en ningún entorno». Su paso 4 deja esto a Frank: «añadir el trigger a los dos snapshots (`supabase-staging.ddl` y `supabase-groups-staging.ddl`). El banco local (`bash qa/cloud/hlc01-cap-test.sh`, 33 casos) lo tolera: retira el tope antes de sembrar».
- `tickets/backlog/sync-rpcs-accept-a-malformed-hlc.md` habla de la migración como «pendiente de aplicar».

Qué pone la migración (léela entera, son 207 líneas): las funciones `hlc_cap_margin`, `hlc_cap_instant`, `hlc_cap_value`, `hlc_cap_patch` y la función de trigger `cap_future_hlc()`, y un trigger `BEFORE INSERT OR UPDATE` en 22 tablas: 17 del canal personal (`supabase-staging.ddl`) y 5 de Grupos (`split_groups`, `group_members`, `split_expenses`, `split_shares`, `split_settlements`, en `supabase-groups-staging.ddl`). Marcha atrás: `qa/cloud/hlc01_rollback.sql`.

Ojo con los dos snapshots: `supabase-staging.ddl` dice en su cabecera que lo genera `qa/cloud/dump-schema.sh` desde el esquema vivo y que es append-only, y lo cruza `CloudCapabilityManifestParityTests`; `supabase-groups-staging.ddl` es el molde offline compuesto con las migraciones aplicadas, verbatim, por secciones. Además lo leen otros tests de `YalaTests/CloudSync/` (`EntityEmissionParityTests`, `GroupLeaveOwnershipReconcileTests`, `GroupsSyncClientTests`). Sigue la convención de cada fichero.

Antes de esta sesión van en la cola `presentation-net-desarm-has-no-automated-net`, `upload-order-sorts-by-hlc-test-fails-in-ci` y `widget-period-tests-depend-on-the-runner-timezone`; ninguna depende de esta.

Para orientarte: `CLAUDE.md`, `qa/cloud/README.md` (cómo están documentadas las demás migraciones) y la propia migración.

## Que se pide
1. Añadir a los dos `.ddl` lo que `hlc01` dejó en el esquema (funciones y trigger `cap_future_hlc` en sus tablas), cada uno según su convención, sin conectarte a staging ni a producción.
2. Comprobar que los tests que leen esos ficheros siguen pasando con el cambio: lee cómo los parsean y, si dudas de que alguno cambie, déjalo dicho en el PR para que lo confirme el CI. Corre también `bash qa/cloud/hlc01-cap-test.sh` si se puede correr en local sin credenciales.
3. En `docs/RUNBOOK-staging-ddl.md`, marcar `hlc01` como aplicada en staging y producción el 2026-10-07 (22 triggers, sonda 4/4), con el mismo estilo que las otras secciones aplicadas, y quitar el «Sin aplicar en ningún entorno». Deja el procedimiento como registro y marca el paso 4 como hecho.
4. Si `qa/cloud/README.md` tiene una entrada para `hlc01` o un índice de migraciones aplicadas, ponla al día; y actualiza la frase de «pendiente de aplicar» de `tickets/backlog/sync-rpcs-accept-a-malformed-hlc.md`.
5. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). No muevas la card `tablero-decidir-un-telefono-con-la-hora-adelanta-4nvh`: le queda el device-QA con dos iPhones a Jürgen.

## Que NO hay que tocar
- La migración, la sonda, el rollback ni ningún entorno de Supabase: esto es solo documentación y snapshots.
- Los tickets `tickets/qa/personal-clock-ahead-wins-every-conflict-until-real-time-catches-up.md` y `tickets/qa/groups-clock-ahead-wins-every-conflict-until-real-time-catches-up.md` siguen en `qa` (device-QA pendiente); como mucho, añade una línea con la fecha del aplicado.
- Código Swift: en esta sesión no se compila iOS ni se arranca simulador.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): si aparece una decisión de producto o de riesgo entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion.

Gate tras el CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR de `widget-period-tests-depend-on-the-runner-timezone` sigue en CI. Si sigue, espera a que entre y rebasa una sola vez. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue.

Mini limpia al cerrar: sin simuladores encendidos, sin worktree ni cachés de esta sesión tras el merge, sin borrar nada de otra sesión viva.

## Como se sabe que esta bien
- Los dos `.ddl` llevan el trigger `cap_future_hlc` (y sus funciones) en las 22 tablas, según la convención de cada fichero.
- El runbook da `hlc01` por aplicada en staging y producción el 2026-10-07 con 22 triggers y sonda 4/4, sin datos inventados.
- Los tests que leen los `.ddl` pasan en el CI del PR.
- PR a 2.1 en auto-merge, Mini limpia.

## Paso 0

Decidido por Frank (04:30 Lima, sin nadie delante; ninguna decisión de producto):

- **`supabase-staging.ddl`** es append-only y una reducción legible: la sección `hlc01` va AL FINAL, con las cinco
  funciones y el `revoke` verbatim de la migración y los 17 `CREATE TRIGGER` expandidos del bucle `do $$`. No se toca la
  cabecera. La normalización (`update … set hlc = hlc`) es datos, no esquema: no entra en ningún `.ddl`.
- **`supabase-groups-staging.ddl`** es el molde «verbatim por secciones»: nueva **§10** (la §9 ya está citada por
  `g14_01`, tejida en sitio). Las funciones viven en `public` y son las mismas para los dos canales: se repiten verbatim
  en §10 para que cada molde se lea solo, y se dice. Los 5 triggers de Grupos, expandidos. Una línea más en la cabecera
  de «Applied migrations», que es donde ese fichero lleva la cronología.
- **Tests:** solo `CloudCapabilityManifestParityTests` y `EntityEmissionParityTests` parsean un `.ddl` (el personal), y
  solo reaccionan a `CREATE TABLE x (` … `);`. Lo añadido no lleva ninguna de las dos formas ⇒ no cambia lo que leen.
  Los de Grupos (`GroupLeaveOwnershipReconcileTests`, `GroupsSyncClientTests`) solo lo citan en comentarios.
- **Runbook:** la sección pasa a «APLICADA … 2026-10-07» con 22 triggers y sonda 4/4; sin hora, filas ni autor (no
  constan en el repo). El procedimiento queda como registro y el paso 4 se marca hecho.
- **`qa/cloud/README.md`** no tiene entrada `hlc01`; su índice (generado) lista las migraciones. Asumido: entrada corta
  que apunta al runbook (sin duplicarlo) y reindexar con `scripts/indexar_doc.py`.
- Tickets en `qa`: una línea con la fecha del aplicado, nada más. Card del tablero: no se toca.
