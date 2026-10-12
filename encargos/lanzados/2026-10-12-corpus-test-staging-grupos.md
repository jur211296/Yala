# Los usuarios de test de staging acumulan grupos sin límite y eso pone fecha de caducidad a los goldens

## Contexto
Card del tablero `tablero-los-usuarios-de-test-de-staging-acumulan-7wn6` (Yala 2.1, high). Ticket: `tickets/backlog/corpus-de-test-de-staging-crece-sin-limite.md`. Cada corrida completa de los goldens añade ~20 grupos al usuario de prueba A y ~15 al B de staging, y nadie los quita: el pull crece lineal y el golden G2·2 rompe hacia ~1.220 grupos. Lee el ticket, `docs/RUNBOOK-staging-ddl.md`, los goldens del gateway y cómo se crean esos grupos antes de proponer nada.

## Reglas duras de datos (obligatorias)
1. **Primero se mide.** Antes de cambiar nada, cuenta los grupos actuales de A y B en staging (y cuántos crea una corrida) y déjalo en el PR.
2. **Solo staging, solo A y B.** Cualquier borrado se hace únicamente sobre grupos de los usuarios de prueba A y B en el proyecto de staging. **Nunca en producción.** Comprueba el proyecto/URL antes de cada operación que escriba y aborta si no es staging.
3. **Nunca `groups_forget_user`.**
4. **Documenta antes de borrar**: qué se va a borrar (criterio, conteo, ids o patrón) se escribe en el PR/ticket antes de ejecutarlo. Nada de borrados masivos sin ese registro.
5. Preferencia de diseño: limpieza **segura e idempotente al terminar cada corrida** (solo lo que esa corrida creó), o **usuarios rotativos**. Elige en el Paso 0 y justifica. Una purga de lo acumulado, si hace falta, va acotada a A/B, documentada y con dry-run primero.
6. Las credenciales de prueba se cargan como indica el repo, sin imprimirlas ni copiarlas a ficheros nuevos.

## Qué se pide
- Medición inicial y final del conteo.
- Que el número de grupos de los usuarios de test deje de crecer por corrida (o que los goldens dejen de depender de él), con test/guarda que lo demuestre.
- Actualizar el runbook/README que corresponda.

## Qué NO hay que tocar
- Producción, el esquema/DDL, RLS, funciones de borrado de usuario, la app iOS salvo que haga falta para los goldens, marketing/.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de Mini
- Si compilas iOS: `nice -n 10 xcodebuild -jobs 2`, load < 8, pipeline serial (limpiar → build sin sim → 1 sim → tests → apagar y erase). DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees retirados: bórralos al cerrar sin preguntar.
- Gate tras el CI del PR anterior (#466): arranca ya sobre `origin/2.1`; justo antes del gate, si #466 sigue en CI espera a que entre y rebasa una sola vez; si falla, rebasa con lo que haya.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
Conteo medido antes/después en el PR; una corrida completa de goldens ya no deja grupos nuevos en A/B (o los goldens no dependen del conteo); nada tocado fuera de staging A/B; PR abierto a 2.1 y ticket a done. Al terminar, `/cerrar-total` (Mini limpia).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Medido antes de decidir (2026-10-12, staging `fostjbbwstyuunmmefuk`, como `postgres` por el MCP, solo lectura).**
Con el predicado del pull (`group_members` del usuario, `deleted=false`, `status in (active,pendingApproval,rejected)`):
A **736** grupos, B **838**. De ellos, prefijo `g2-goldens-`: A 629 (18 con el grupo borrado, 37 archivados), B 723
(673 activos, 41 pendientes, 9 rechazados); prefijo `g8-fanout-` (push.fanout): A 76, B 76. Una corrida completa de
`groups.goldens` crea **19 grupos: los 19 entran en el pull de A y 14 en el de B** (cortes del 2026-09-07 21h y 2026-09-08
16h), más 1 de `push.fanout` en los dos.

**D1 · Mecanismo: «relevo» al custodio, no borrado.** Medido en las funciones de staging: el dueño de un grupo no puede
salir por ninguna vía pública (`leave_group` → `yala_owner_cannot_leave`; `remove_member` → `yala_cannot_remove_owner`),
y la única que lo saca sin heredero es `groups_forget_user`, prohibida. Así que siempre queda UNA membresía por grupo, y
la pregunta es de quién. Se le traspasa a un **cuarto usuario de test, el custodio** (`i5-goldens-custodio@test.yala`),
con RPCs públicos: los no-dueños de A/B salen con `leave_group` (un B rechazado vuelve a entrar con invitación nueva y
sale), el custodio entra y se aprueba, el dueño hace `transfer_group_ownership` y sale. **Ningún golden hace pull con el
custodio**, así que sus grupos no le cuestan nada a nadie. Descartados: usuarios rotativos por corrida (el alta por
`/auth/v1/signup` está cerrada en staging: `mailer_autoconfirm=false` y GoTrue rechaza los dominios de test); limpieza
por SQL como `postgres` al final de cada corrida (los goldens no tienen ni deben tener credencial privilegiada); DDL de
una función de purga (fuera de alcance).

**D2 · Al terminar cada corrida, solo lo de esa corrida.** Los helpers que llaman a `create_group` apuntan cada `gid` que
crean (registro en el punto único, no test a test: un test nuevo no puede olvidarlo). Un `afterAll` releva esos grupos y
**falla** si alguno sigue en el pull de A o B, nombrando el `gid` y el motivo. Es la guarda que pide el encargo: se
comprueba por `gid`, no por el total, para que una corrida paralela no la ponga roja.

**D3 · `3-quater` (grupo borrado) lo protagoniza el custodio, no A.** Un grupo borrado no admite traspaso ni salida
(`transfer_group_ownership` exige `deleted=false`), así que A se quedaba con uno por corrida para siempre. Mismo
contrato del golden (token real de grupo borrado → `yala_group_deleted`; token inventado → `yala_invalid_invite`); cambia
solo quién crea y borra.

**D4 · Archivados: el dueño desarchiva antes del relevo.** `join_group` rechaza la entrada a un grupo archivado
(`yala_group_archived`, g13_05). El relevo lo desarchiva con un push de meta y HLC de ahora (el tope de `hlc01` es
`now()+60 s`, así que no se usa HLC del futuro).

**D5 · Purga de lo acumulado: sí, con el mismo relevo, acotada y con dry-run.** Sin ella los goldens siguen en rojo por
timeout (ya lo estaban con 631/702). Alcance: solo membresías de A y B en grupos `g2-goldens-*` y `g8-fanout-*`, que
son los que crean estos goldens. **Fuera**: `g6-migrate-*` y `rls-*` (otras suites, no crecen) y los 18 grupos de A ya
borrados (no admiten relevo sin SQL directo; quedan como residuo documentado). Se escribe en el ticket ANTES de correr,
con el dry-run delante.

**D6 · Credencial del custodio.** Se crea por SQL como C (receta de `qa/cloud/README.md` §g12_01), pero la contraseña
se genera en local y por el MCP solo viaja su hash bcrypt. Va al `test-users.env` existente (sin fichero nuevo ni copia).
Sin `USER_CUSTODIO_PASS`, `groups.goldens` y `push.fanout` fallan en su `beforeAll` antes de crear nada: correr sin
custodio volvería a acumular en silencio.

**Asumido:** el custodio es un usuario de test más de staging (precedente: C, creado igual el 2026-09-10). Su conteo
crece ~20 por corrida y no lo lee ningún golden; si algún día estorba, se purga por SQL acotado a él.
