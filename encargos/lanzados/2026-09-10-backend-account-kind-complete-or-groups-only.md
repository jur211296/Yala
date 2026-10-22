# Implementar ticket paso 2: backend-account-kind-complete-or-groups-only

## Contexto
Cola autónoma del rediseño de sesiones (Jürgen 2026-09-10). Orden: runbook `session-redesign-implementation-order.md`. Paso 0 (#127) y paso 1 (#128 + deploy gateway) ya en `2.1`.

Decisiones YA tomadas: sección **«Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)»** del ticket + índice `docs/sessions/2026-09-09-desbloqueo-decisiones-rediseno-sesiones.md`. **Mandan.** Incluye **FRESH START de producción** (borrar datos + `auth.users` de las 2 cuentas de Jürgen) ANTES del esquema; staging NO se borra. No repreguntar ese wipe.

MODO AUTÓNOMO HASTA TERMINAR: `/spec` + Plan Mode + `/review-plan` (este paso es **[spec]**), gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket `--solo-crear` antes de cerrar. Ambigüedad NUEVA: elige lo más seguro alineado con Decisiones y regístralo; para solo si falta credencial real (DDL / Supabase / Cloudflare) que no tengas.

Avisos a Frank: (1) bloqueo de acceso real; (2) PR; (3) `/cerrar-total` con resumen de producto + aviso del wipe (iPhone apuntará a cuenta muerta; recrear grupos de prueba); (4) idle — una vez.

## Que se pide
1. Leer primero: Decisiones del ticket → ADR → matriz (filas de este paso) → ticket → runbook DDL staging (`docs/RUNBOOK-staging-ddl.md` u equivalente).
2. Implementar alcance del ticket (columna `kind`, wire, claim/promote/degrade solo via reverse cutover, cliente decode + corrección al refrescar). Staging primero; goldens gateway; luego prod.
3. **Prod wipe** según Decisiones (conteos antes/después medidos en el PR). No ampliar el alcance del borrado.
4. Un ticket = un PR a `2.1`. UI/ruteo del bloque [I] es el paso 3 — fuera de alcance salvo lo mínimo de decode/`kind` cacheado que pide este ticket.
5. `/cerrar-total` al terminar.

## Que NO hay que tocar
marketing/. Wipe de staging. Pasos 3–13. Ampliar el fresh start más allá de lo escrito.

## Como se sabe que esta bien
Criterios de aceptación del ticket; conteos prod anotados; PR mergeado; board/`TICKETS.md` al día; `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Nadie estaba mirando: cada nodo se contesta con mi recomendación y se sigue. Se discute en el PR.
**El desarrollo de cada una, con lo medido, vive en el ticket** (`tickets/backlog/backend-account-kind-complete-or-groups-only.md`, sección «Paso 0»); aquí va el árbol y la respuesta, sin duplicar el porqué.

| # | Nodo de decisión | Respuesta |
|---|---|---|
| 1 | ¿Hay credencial para hacer staging y prod, o hay que parar? | **No hay bloqueo.** El mapa de acceso está invertido respecto a lo documentado: staging admite DDL (`postgres`), y prod se escribe por `apply_migration` aunque `execute_sql` sea de solo lectura. Verificado con control positivo |
| 2 | ¿El backfill es el de la decisión (`personal_claimed_at is not null`)? | **Se completa con `and reverted_at is null`.** El reverse cutover no toca `personal_claimed_at`, así que la fórmula de la decisión clasificaría `complete` una cuenta que volvió a iCloud. Mismo resultado en los dos entornos de hoy (cero filas), distinto en el futuro |
| 3 | ¿Cómo se cumple «escribible solo por RPC»? | **Trigger + guard de transacción**, no regenerar grants por columna (dejaría sin grant a toda columna futura: el noop silencioso de G2) |
| 4 | ¿El guard se abre con un literal o con un token? | **`txid_current()`**. Con un literal, un `set_config(..., false)` filtraría el guard abierto al pool de PostgREST y lo heredaría la siguiente petición de cualquiera |
| 5 | ¿El trigger exime a `postgres` para no bloquear reparaciones? | **No.** Se probó y abría el guard entero en el único banco disponible (`set role` no cambia `session_user`), dejando pasar los cuatro controles negativos |
| 6 | ¿CHECK cruzado `kind='complete' ⇒ personal_claimed_at not null`? | **No.** Rompe un golden vivo (el bloque g3_02 hace `patchProfile({personal_claimed_at: null})` y espera `< 300`). La coherencia queda en rutas + tests, como decidió Jürgen |
| 7 | ¿Endpoint nuevo para promover? | **No: `POST /account/claim` con `kind:"complete"`**, que es la promoción que g3_02 ya hace. Un endpoint nuevo sería una segunda ruta que mantener |
| 8 | ¿Se promueve también la cuenta post-reverse? | **No.** Se escribió y se retiró: contradice al backfill de la propia migración (una re-aplicación la degradaría sola) y volver a la nube tras una reversa es el re-cutover, diferido por diseño |
| 9 | ¿En qué orden van base y Worker? | **La base de un entorno SIEMPRE antes que su Worker**, con `notify pgrst, 'reload schema'` dentro de la migración. Al revés, el Worker pide una columna que no existe y devuelve 502 en cada sign-in |
| 10 | ¿Qué toca del cliente, con el ruteo fuera de alcance? | **Decode + caché sellada + corrección al refrescar.** `YalaAccountLogic.dataLocation` y `RestoreRouter` **NO se tocan**: son ruteo (ticket 3) y su rama `groups_only` escribe `OnboardingMode.groupInvite`, que es never-downgrade cross-device — un fail-safe equivocado ahí es irreversible |
| 11 | ¿Dónde vive el `kind` cacheado? | **Molde `AccountEntitlementStore`**: UserDefaults sellado por `userID`. No Keychain (muere en signOut) ni iCloud-KV (viajaría a otro dispositivo y describiría otra cuenta) |
| 12 | ¿Se amplía el borrado de prod a `auth.audit_log_entries` / `auth.flow_state`? | **No se amplía**: no están en el alcance escrito. Se miden y se nombran en el PR como lo que queda |
| 13 | ¿Cuándo cierra sesión Jürgen? | **ANTES del wipe.** Su JWT es stateless y sigue vivo hasta expirar: con el `sub` ya borrado, cada llamada da 409/502, no una sesión «apuntando a una cuenta que no existe» |
