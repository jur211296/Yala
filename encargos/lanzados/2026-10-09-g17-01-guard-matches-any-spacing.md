---
esfuerzo: high
---
# g17_01 aborta en staging: la guarda busca «reverted_at = null» con un espacio y el cuerpo real los tiene alineados

**Prioridad:** high · **Card:** la de este brief (enlazada a PR #423 y a gk5w) · **Bloquea:** gk5w (`reverse-exit-on-a-reverted-account-rejects-the-retry`)

## Qué pasó (medido 2026-10-09 18:4x Lima, desde el box)

- Staging (`fostjbbwstyuunmmefuk`) y producción (`kefvaiymtgytemwbltlz`) están iguales y cuadran con la partida del RUNBOOK:
  `md5(prosrc) = 14fc5e2c54766dd7c5706966c7381f51`, `md5(pg_get_functiondef) = 12e4491bbdb9ad06a468ae04ec683787`,
  3 escrituras `reverted_at\s*=\s*null` (regexp, gi), K = 0 cuentas atascadas en los dos.
- Al aplicar `qa/cloud/g17_01_reverse_claim_keeps_reverted_at.sql` en staging abortó (sin tocar nada, md5 igual después):
  `g17_01: «reverted_at = null» aparece 0 vez/veces en migration_progress; se esperaban 3. Abortada.`
- Causa: en el cuerpo vivo las escrituras están alineadas: 2 veces `reverted_at          = null` (10 espacios) y 1 vez
  `reverted_at           = null` (11 espacios). El fichero cuenta y reemplaza el literal `'reverted_at = null'` (`v_old`,
  línea ~104), y la inversa del §0 («ya aplicada») hace `replace(v_src, v_new, v_old)` con ese mismo literal. El banco local
  (`qa/cloud/g17_01-local-test.sh`) pasó porque usa una réplica escrita a mano con un solo espacio.

## El cuerpo REAL, ya exportado para ti (no hace falta acceso a la base)

- `~/Claude/tmp-frank/g17-01-real/staging-migration_progress.prosrc.txt` — `prosrc` exacto de staging (md5 `14fc5e2c…`, verificado).
- `~/Claude/tmp-frank/g17-01-real/staging-migration_progress.functiondef.sql` — `pg_get_functiondef` completo (md5 `12e4491b…`).
Producción tiene los mismos md5, así que es el mismo cuerpo.

## Que se pide

1. Arranca sobre `origin/2.1` (si el PR #423 aún no está mergeado, sobre su rama `encargo/2026-10-09-reverse-exit-on-a-reverted-account-rejects-the-retry`).
2. Corrige `g17_01_reverse_claim_keeps_reverted_at.sql`:
   - Contar y sustituir las escrituras con regexp (`reverted_at\s*=\s*null`, sin depender del espaciado), **sin dejar de exigir exactamente 3**
     y sin dejar de abortar si hay una cuarta o una grafía que la sustitución no tocaría.
   - La sustitución tiene que ser exactamente invertible (conserva el espaciado original de cada una, por ejemplo con
     `regexp_replace` capturando el espacio), para que la detección de «ya aplicada» por la inversa exacta siga dando el md5 `14fc5e2c…`.
   - La detección de «ya aplicada» (§0) y el §2 de verificación con la misma lógica.
3. Corrige `g17_01_rollback.sql` igual: que vuelva al md5 `14fc5e2c54766dd7c5706966c7381f51` partiendo del cuerpo real transformado.
4. **Pruebas contra el cuerpo real**, no contra la réplica: en el Postgres desechable del banco local, crea la función con el
   `functiondef` exportado (si necesita tablas/tipos, los mínimos para que compile) y comprueba:
   - **Test rojo:** el fichero VIEJO (el de `origin/2.1` o la rama del #423) aborta con «0 vez/veces» contra ese cuerpo.
   - El fichero nuevo: 3 sustituciones, md5 nuevo estable, re-aplicar es no-op, el rollback devuelve exactamente `14fc5e2c…`,
     y un cuerpo con una cuarta escritura o divergido sigue abortando.
   - El §3 de conducta (11 escenarios) en verde, si el banco puede correrlo contra el cuerpo real; si no, dilo en el PR.
   - Deja el test en `qa/cloud/` (que el script de banco lo corra) y el cuerpo real como fixture en el repo.
   - Apunta en el PR el md5 nuevo que da el cuerpo real transformado: lo comprobaré al aplicar.
5. Actualiza `docs/RUNBOOK-staging-ddl.md` § g17_01: el paso 1 cuenta con regexp, y la nota del espaciado.
6. **NO apliques nada en staging ni en producción** (ni Management API, ni MCP, ni psql). Eso lo hace Frank desde el box después del merge.
7. Rebase al final, sin esperar a nadie: justo antes de abrir el PR, `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí cualquier conflicto (strict=false).
8. Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre. Va SIN --fecha (la fecha de las cards es opcional desde el ADR-068; no pongas fecha de relleno).
9. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza de worktree/tmux/cachés). Card de este brief a «done» (frank) con el md5 nuevo en la nota; gk5w se queda en blocked (jurgen) hasta que Frank aplique.

## Pipeline
No hay Swift: no compiles la app ni enciendas simuladores. Solo Postgres desechable y `npm test` del gateway si tocas goldens.

## Paso 0

Auto-contestado (sesión autónoma, sin nadie delante).

- **Base:** `origin/2.1` en `af8422892`; el #423 ya está mergeado (`cb622367e`), así que no hace falta su rama.
- **Patrón estricto** (el que se cuenta y se sustituye): `\mreverted_at(\s*)=(\s*)null\M`, sensible a mayúsculas, con
  límites de palabra para que `nullif(…)` o `v_reverted_at` no cuenten. Tiene que dar exactamente 3.
- **Patrón amplio** (red): `reverted_at\s*=\s*null` con `gi`, sin límites. Si da distinto que el estricto, hay una grafía
  que la sustitución no tocaría (mayúsculas, `nullif`…) y se aborta igual que hoy.
- **Sustitución invertible:** `regexp_replace` con `\1` y `\2` capturando el espacio de cada lado del `=`; la inversa
  hace lo mismo con la expresión nueva. Se mantiene la detección de «ya aplicada» por la inversa exacta (md5 virgen), sin
  md5 propio fijado en la migración; el md5 nuevo se apunta en el RUNBOOK y se fija en el banco.
- **§2:** cuenta la expresión nueva por regexp (= 3) y la amplia (= 0), en vez de `position` del literal con un espacio.
- **Fixture:** el `pg_get_functiondef` real va a `qa/cloud/fixtures/migration_progress.g15_02.functiondef.sql`.
  Es código de función, sin datos de usuarios.
- **Banco:** corre la batería entera dos veces: contra el cuerpo real (con el fichero SIN tocar, porque su md5 ya es el
  de producción) y contra la réplica de un espacio (variante de espaciado). Añade un caso de grafía en mayúsculas y fija
  el md5 final del cuerpo real. `auth.uid()` se emula con la definición de Supabase (lee `request.jwt.claims`).
- **Test rojo:** el fichero de `origin/2.1` contra el cuerpo real, corrido una vez en la sesión y apuntado en el PR (no
  se deja en el banco: depende de git).
- **Sin tickets nuevos** salvo que salga algo por el camino.
