---
id: groups-archived-group-rejects-join
status: done
priority: medium
area: groups
created: 2026-09-06
updated: 2026-09-23
source: decisión de Jürgen del 2026-09-06 sobre tickets/qa/rejected-member-cold-tap-does-nothing.md
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - caso raro con dos telefonos; el servidor se probo con 11 escenarios
---

# Un grupo archivado no acepta miembros nuevos

## Qué le pasa al usuario

Un enlace de invitación a un grupo que su dueño ya archivó **sigue funcionando**: el servidor deja
unirse (`join_group` no mira `is_archived`; medido en el ticket de origen). Y la app tiene un texto ya
traducido a 16 idiomas —`groups.reconnect.archived.body`— que promete lo contrario. Hoy ese texto no se
puede enseñar sin mentir.

## Decisión Jürgen (2026-09-06)

**Se hace verdad el comportamiento: un grupo archivado no acepta miembros nuevos.** Elegida entre eso
y reescribir el texto para permitir la entrada. Motivo, tal como se le puso delante y ratificó: es lo que «archivado» significa para cualquiera, y
el copy ya existe.

## Criterio de hecho (AC)

- [x] `join_group` rechaza la unión cuando el grupo está archivado, con un error propio (no un
      genérico), aplicado en **los dos entornos** (staging y prod) con su test de RPC.
      → **prod SÍ · staging NO se pudo: sin credencial de DDL.** Ver «El drift de staging».
- [x] El cliente mapea ese error a `groups.reconnect.archived.*` (copy existente; revisar que el
      cuerpo siga siendo verdad palabra por palabra) y lo enseña como estado, no como error crudo.
      → hecho, y la revisión del cuerpo destapó un hueco: sale a ticket propio.
- [x] Un miembro que YA está dentro de un grupo archivado no se ve afectado (solo se cierra la
      entrada nueva).
- [x] Desarchivar vuelve a abrir la entrada sin más.
- [ ] Device-QA: enlace de un grupo archivado desde un segundo teléfono. **PENDIENTE** — por eso este
      ticket está en `qa` y no en `done`.

---

## ARREGLADO · 2026-09-06 — pasa a QA, falta verlo en dos teléfonos

### La premisa era cierta, y esta vez se midió ejecutándola

Tercera sesión seguida en que toca comprobar la premisa del encargo antes de creérsela; ésta **sí**
se sostuvo. No por leer el código: **ejecutando `join_group` contra la función VIVA de producción**,
en sandbox transaccional (`begin … rollback`, con el rollback comprobado antes de arriesgar nada).
Un grupo con `is_archived = true` y `deleted = false` devolvió:

    {"status":"pendingApproval","changed":true,"rebound":false,…}

y además dejó **1 fila** en `group_members` y **consumió un uso** del invite. El `prosrc` de
producción no mencionaba `is_archived` ni una vez. Y el barrido del esquema entero da el porqué: esa
columna solo aparece en `create_group`, `migrate_group` y `groups_pull_rows_split_groups` — siempre
como dato que se **transporta**, nunca como puerta que decide. **El archivado no restringía nada en
el servidor.**

### Dónde va el gate, que es la única decisión de diseño real

Ponerlo junto al chequeo de `deleted` habría sido una línea, y habría incumplido el tercer AC. Por
`join_group` pasan **cuatro caminos**, y solo dos son «entrada nueva»:

| Camino | Qué es | Decisión |
|---|---|---|
| Rebind legacy (`user_id null`) | Reclamar la fila propia que dejó `migrate_group`. Esa persona **ya estaba** en el grupo | **PASA** |
| Ya-member activo/pendiente | El re-tap del enlace. Hoy es un no-op `changed:false` | **PASA** |
| Ya-member terminal (`rejected`/`left`/`removed`) | No está dentro: pedir entrada otra vez **es** entrada nueva | **RECHAZA** |
| INSERT nuevo | El caso del ticket | **RECHAZA** |

Bloquear las dos primeras es exactamente lo que el AC prohíbe: al del rebind le quitaría el acceso a
su propio historial por una acción reversible que ni siquiera es suya; al del re-tap le pintaría un
aviso donde hoy no pasa absolutamente nada.

Efecto secundario deliberado: **un intento rechazado no consume uso del invite** (el `uses + 1` vive
solo en las ramas que escriben, todas posteriores al `raise`).

Y **desarchivar reabre la entrada sin más**: el gate lee la columna en el momento de la llamada. No
hay estado derivado, ni marca en el invite, ni nada que limpiar.

### Los once escenarios, medidos

Ejercitados en sandbox contra el motor y el esquema reales antes de aplicar; los cuatro primeros
re-verificados después contra la función **ya aplicada**:

alta nueva en archivado → `yala_group_archived` · re-tap de miembro activo → `changed:false` sin
error · re-entrada de rechazado → `yala_group_archived` · rebind legacy → `rebound:true` · alta en
grupo vivo → entra · `is_archived` **NULL** → entra (la columna es nullable sin default: el
`coalesce` no es decorativo) · grupo borrado → sigue `yala_group_deleted` (g13_03 intacto) · token
inexistente → sigue `yala_invalid_invite` (**no-oráculo intacto**) · el rechazo no gasta uso del
invite · el rechazado no queda dentro · tras desarchivar, entra.

### Por qué se puede aplicar antes de publicar la app

`GroupsRPCError.init(yalaCode:)` devuelve `nil` para un código desconocido y el llamador lo convierte
en `.permanentRejected`, **nunca** en `.transient`. Una app que no conozca `yala_group_archived` lo
trata como rechazo permanente y enseña su mensaje genérico: peor texto, pero **no entra**, que es lo
que este cambio existe para conseguir.

### El cliente: un estado, no un error

El molde era `groupDeleted` (g13_03), pero su presentación no servía. `.showInviteError` tiene el
título fijado a **«Enlace no válido»**, y aquí eso sería falso —el enlace es perfecto y el grupo
existe—; es el mismo motivo por el que `.channelDisabled` tampoco lo usa. Y `.showGroupSyncError`
dice **«Hubo un problema con el grupo»**, que convierte en avería una decisión deliberada de su
admin. El AC pedía literalmente «como estado, no como error crudo».

Así que el aviso trae el **título** (con el nombre del grupo) y el **cuerpo** de
`groups.reconnect.archived.*`, **traducidos a 16 idiomas y hasta hoy sin un solo consumidor** — solo
existían en `L10n.swift:2341-2343`. Cero copy nuevo.

**Su tercer string, `.cta` («Entendido»), NO se usa, y eso costó la parte más cara de la sesión.**
El primer intento lo pintaba con `Button(activeInviteError?.cta ?? …)`, y eso **rompe la app**: con el
label del botón dependiendo del `@State`, el `actions` builder de `.alert` deja la vista sin alcanzar
`idle` y **dejó de completarse el guardado de una transacción** — `TransactionSuccessView` no llegaba
a montarse y `QuickActionsFavoritesUITests` se caía a 10 s de espera, en un área que ningún cruce de
`codeGlobs` habría señalado como afectada por un cambio en invitaciones. Aislado por bisección con
control en las dos direcciones (CTA literal pasa ×2 · dinámico falla ×4 · **título** dinámico pasa) y
anotado como regla durable en `.claude/rules/swiftui-ds.md`. El botón se queda en `common.ok`: se
pierde el matiz «Entendido» frente a «Aceptar».

El nombre sale del `n=` del enlace (`PendingJoinEntry.branded.name`), leído **antes** de limpiar el
intent, con `groups.reconnect.fallbackGroupName` («este grupo») cuando el enlace no lo traía — que es
el hueco exacto para el que ese string se escribió.

**Detalle de diseño que evitó ensanchar el cambio:** el aviso reusa el ANCHOR de invite. La alerta
pasó de `String?` a `InviteAlertContent` (título + cuerpo + CTA) porque el título ya no puede vivir
fijado en la vista con dos productores. Abrir una alerta nueva habría obligado a declararla en los
gates de readiness del router (`hasActiveInviteError`, en dos sitios) y a tocar su tabla de tests,
por un aviso que ya cabía donde estaba.

El fallo es **permanente**: el intent se limpia. Es la diferencia con `.channelDisabled`, el otro
caso en que el enlace es bueno — un canal apagado vuelve solo con un deploy; un grupo archivado no
se desarchiva solo, y conservar el intent haría reintentar en cada arranque durante los siete días
del TTL sin que nada cambie.

### Verificado por mutación, no por su verde

- Rama del handler inalcanzable → **exit 65**, caen los 2 tests del aviso; los 2 controles siguen verdes.
- `classify` mandando `.groupArchived` a `.generic` → **exit 65**, caen **5**: la pure logic **y** el
  comportamiento. La cadena entera está atada.

Y los tests llevan su **control en la dirección contraria**, que es la mitad que da la prueba:
`.invalidInvite` y `.groupDeleted` conservan su camino. Sin eso, un cableado que mandara *todos* los
fallos permanentes al aviso nuevo pasaría en verde.

### El drift de staging, declarado y no disimulado

**Aplicada solo en producción.** No hay credencial de DDL de staging: el conector MCP lista
únicamente el proyecto de producción (re-medido hoy) y `~/Secrets/yala-supabase-test/` solo tiene
JWTs de usuario. Es el **mismo bloqueo** con el que g13_04 quedó pendiente el 2026-09-04, así que
~~staging arrastra ahora **tres** migraciones~~ — **RESUELTO el 2026-09-08**: las tres aplicadas en staging y verificadas por md5 (`join_group` `4982b50d…`/5365, `apply_group_delta` `61c38595…`, el reader `2cac864c…`), grants intactos y `anon` revocado. Se destrabó dando acceso al proyecto de staging por el conector. Registro: `docs/RUNBOOK-staging-ddl.md`. Lo que decía: cuando esto se escribió eran
dos, y `g14_01` (el presupuesto de grupo) se sumó después. Se cierran aplicando los `.sql` en orden
cuando haya acceso; ninguna rompe nada mientras tanto (los goldens no miran `changed` ni este código
de error). **Es un acceso de Jürgen, no una tarea pendiente mía**, y el procedimiento con su orden y
verificación está en `docs/RUNBOOK-staging-ddl.md`.

De paso: `supabase-groups-staging.ddl` **estaba desfasado** respecto a producción —le faltaban
g13_03 y g13_04, aplicadas en la BD y nunca traídas al molde— y ahora vuelve a reflejar el `prosrc`
vivo.

El gateway **no necesita cambios ni despliegue**: propaga cualquier `/^yala_[a-z_]+$/` como 400 con
el código preservado, sin allowlist de códigos de error.

### Lo que sale de aquí a un ticket propio

El AC pedía «revisar que el cuerpo siga siendo verdad palabra por palabra», y la revisión encontró
algo. El cuerpo dice **«ya no acepta cambios»**, y eso es más de lo que el archivado hace hoy: ni
`GroupService.validateGroupIsWritable` ni `GroupExpenseService.validateGroupIsWritable` miran
`isArchived` (solo `isMigratedFrozen`), y en el servidor ninguna función lo consulta como gate.

Para **quien recibe este aviso** la frase es verdad y describe justo lo que le acaba de pasar:
intentó un cambio —entrar— y el grupo no lo aceptó. Lo que no es verdad es su lectura universal.
Cerrar ese hueco es otra decisión de producto (y el encargo prohíbe expresamente inventar otra
semántica de «archivado»), así que sale a
[[groups-archived-still-accepts-changes]].

### Lo que falta, y por qué esto está en `qa`

**El device-QA no se ha hecho.** Son dos teléfonos: A crea un grupo y reparte el enlace, A archiva el
grupo, B tapea el enlace y tiene que ver **«<grupo> fue archivado»** con su cuerpo y su «Entendido» —
no «Enlace no válido» ni «Hubo un problema con el grupo». Y la comprobación que cierra el AC de
reversibilidad: A desarchiva, B vuelve a tapear, y ahora **sí** entra como pendiente.

Vale la pena añadirlo al montaje de dos teléfonos de `qa/guion-tanda.md`, que ya cubre otros tres
tickets con la misma pareja.

## Relacionados

- [[rejected-member-cold-tap-does-nothing]] — donde se midió que el copy mentía.
- [[groups-archived-still-accepts-changes]] — el hueco que destapó revisar ese copy.

## Corrección al guion · 2026-09-16 (barrido de QA)

**«Lo que falta» (:181)** — el aviso no trae «Entendido»: el botón es **«OK»** (`common.ok`), como
explica la propia implementación (:112-120). Lo que hay que ver en B es el título «<grupo> fue archivado»
con su cuerpo y un botón OK.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Caso raro (un enlace a un grupo archivado) que pide dos teléfonos. El servidor se probó con 11 escenarios y el cliente lo cubren los tests de `groupArchived`.
