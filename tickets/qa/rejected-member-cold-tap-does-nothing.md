---
id: rejected-member-cold-tap-does-nothing
status: qa
priority: high
area: groups
created: 2026-09-04
source: medido al verificar el re-join backend antes de podar guest-journey-dead-screens (2026-09-04)
---

# A quien rechazaron de un grupo, tapear un enlace nuevo con la app cerrada no le hace nada — y así se queda

## Qué le pasa a la persona

Me rechazaron la entrada a un grupo. El admin se lo repiensa y me manda un enlace nuevo. Cierro la
app —o simplemente hace rato que no la abro—, tapeo el enlace y **no pasa absolutamente nada**. Ni
entro, ni me sale un aviso, ni se queda pendiente. Vuelvo a tapear: nada otra vez. Lo único que mi
app me ofrece sobre ese grupo es «Salir del grupo».

No es una carrera que se resuelva reintentando: **es el estado estable**. Mientras exista la fila
local de mi membresía rechazada, ese enlace no me va a servir nunca.

Si la app está ABIERTA cuando tapeo, funciona bien. El desenlace depende de si la app estaba viva,
cosa que la persona no percibe ni puede controlar.

## Por qué es nuevo: lo introdujo `g13_02` el 2026-09-03

Es un efecto colateral, no medido, del arreglo de `guest-decline-has-no-screen` —el que hace que al
rechazado no se le esfume el grupo—, que está **al 100 % en producción** desde el 2026-09-03.

Antes de `g13_02`, `rejected` salía del filtro de membresías: el grupo se limpiaba en local, no
quedaba fila, y este mismo tap en frío **sí** disparaba el join. Al conservar la fila para poder
enseñar el aviso, se activó un camino que ya estaba roto y que hasta entonces nadie pisaba.

## La cadena, medida el 2026-09-04 sobre `2.1` @ `ae928345`

Los cinco eslabones verificados uno a uno en este árbol:

1. **El filtro conserva al rechazado.** `gateway/src/groups/routes.ts:469` →
   `status=in.(active,pendingApproval,rejected)`. Es `g13_02`, y la policy correspondiente está
   aplicada en producción (comprobado contra el servidor: `group_members_select_own_rejected` con
   sus dos condiciones).
2. **El pull escribe esa fila en local, con su estado.**
   `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:2640` (`model.status`) y `:2645`
   (`model.userID`). La fila `rejected` aterriza y se queda.
3. **En frío, el tap no produce UI.** `Yala/App/AppBootstrapper.swift:2107-2117`: con
   `!isInitialized` se persiste el intent y se **retorna sin un solo `submit`**. Su propio
   comentario dice «el trigger boot del reconciler lo completa» — y ahí está el fallo, porque no lo
   completa.
4. **La decisión del reconciliador es ciega al estado.**
   `Yala/App/Logic/GroupJoinReconcileLogic.swift:73` → `if memberLocallyPresent { return
   .correctAndClear }`. Su firma (`:66-72`) recibe `flagEnabled`, `hasSession`, `isConsented` y
   `memberLocallyPresent` — **no hay parámetro de estado**, y esa línea gana antes que sesión,
   consent y join.
5. **El estado se lee DESPUÉS de borrar el intent.** En
   `Yala/Services/Groups/GroupJoinReconciler.swift`, `PendingJoinStore.clear` está en `:144` y
   `if let status = backendMember?.memberStatus` en `:146`. Cuando el estado entra en escena, el
   intent ya no existe: solo sirve para publicar una fase, no para decidir.

⇒ **`join_group` no llega a llamarse nunca.**

## Dos daños más, del mismo tronco

- **Un canario que miente.** `GroupJoinReconciler.swift:150` emite `groupJoinIntentReconciled` con
  `detail: "boot|backendMemberPresent"` — reporta un join reconciliado que **no ocurrió**. Cualquier
  lectura de esa serie para decidir el encendido está inflada por arriba.
- **La misma ceguera afecta al expulsado y al que se fue.** `GroupService.swift:628` llama a
  `PendingJoinStore.clear(zoneName:)` dentro de la limpieza de «me sacaron», y puede borrar un
  intent de invitación **más nuevo** que la propia limpieza.

## La causa raíz ya estaba escrita, y se parcheó solo el síntoma

`qa/coverage-index.json`, área `groups-pending-approval-reconnect`, recoge del device-QA del
**2026-07-31** (dos iPhones reales contra producción): «`reconcileBackendEntry` dispara
`.correctAndClear` con el member presente AUNQUE esté `pendingApproval` ⇒ el intent ya está limpio».

Aquel arreglo tapó el banner pegado y no la ceguera al estado. `g13_02` le acaba de dar una segunda
víctima, peor que la primera. Y el `lastVerified` de esa área es **2026-08-06**: anterior al cambio
que la rompió.

## Por qué no lo cazó ningún test

`YalaTests/GroupJoinReconcileLogicTests.swift` tiene 18 pruebas y **cero** menciones de `status`
(medido: `grep -c "status"` → 0). La tabla de `decideBackend` son cinco casos y ninguno tiene esa
dimensión. `YalaTests/GroupJoinReconcilerTests.swift:213-246` monta el member con
`status = pendingApproval` y afirma `correctAndClear`: **el test fija el comportamiento roto**.

Tampoco hay XCUITest de re-join por enlace en frío.

## El arreglo, y lo que NO es

**No necesita ninguna pantalla.** Este bug muere aguas arriba de cualquier presentación, así que la
maquinaria de reconexión (`GroupReconnectView`) no lo habría rescatado — se comprobó al podarla.

Las dos piezas:

1. Que `decideBackend` **reciba el estado**: un member presente en estado terminal (`rejected`,
   `left`, `removed`) debe devolver `.join`, no `.correctAndClear`. Y el test que hoy fija el
   comportamiento roto se actualiza con él.
2. Un guard en `GroupService.swift:628` para no borrar un intent de invitación más reciente que la
   limpieza que lo pisa.

**El copy ya existe y está traducido**, precisamente porque se conservó al podar: los cuerpos
`groups.reconnect.rejectedRetry.*`, `.leftRetry.*` y `.removedRetry.*` están en los 16 locales y
dicen exactamente lo que hay que decirle a esta persona.

⚠️ **`groups.reconnect.archived.body` NO se puede reusar tal cual**: afirma que un grupo archivado
no acepta miembros nuevos y hoy eso es **falso** — `join_group` no mira `is_archived` en ninguna de
sus líneas. Ponerlo delante del usuario sería una mentira; arreglar eso es decisión de producto
aparte.

## Lo que no se midió

No se ejecutó en dispositivo. Que el enlace en frío llegue siempre antes de `isInitialized` es
**inferido** de la existencia de la rama R4, del `forceFetchAndWait(timeout: 15)` de
`AppBootstrapper.swift:223` y de que `isInitialized = true` está en `:564`. Un device-QA de cinco
minutos —ser `rejected`, matar la app, tapear el enlace— lo confirma o lo tumba, y es el primer
paso recomendado al abrir este ticket.

---

## ARREGLADO · 2026-09-04 — pasa a QA, falta verlo en un teléfono

**Decisión del owner: re-solicitar en silencio.** Tapear el enlace ES la petición, así que el camino
en frío pasa a comportarse como el caliente. Sin pantallas nuevas, sin copy nuevo, sin tocar el
servidor.

### El arreglo obvio no servía, y por eso el diseño tiene una pieza más

Que `decideBackend` mirara el estado **se auto-anula**: `memberLocallyPresent` y el estado se leen de
la fila LOCAL, que sólo refresca el pull. Tras un join correcto la fila sigue diciendo `rejected`
hasta la siguiente bajada, así que la pasada siguiente decidiría lo mismo otra vez.

Y al revés, el peligro simétrico: si el gate fuera sólo «member terminal ⇒ pedir entrada», el intent
—que vive 7 días— re-solicitaría en cada arranque **sin que nadie tapee nada**, y el admin recibiría
solicitudes fantasma de alguien a quien ya rechazó.

⇒ Hace falta el bit «esta persona **acaba** de tapear», y **tiene que vivir en memoria del proceso**:

- Un `Set` de groupIDs armado en `GroupBackendInviteEntryHandler.persistIntent`, que es el choke point
  de los dos taps (el warm por `handle`, el frío por `AppBootstrapper.persistBackendInviteIntent`).
  Verificado: son sus únicos dos llamadores.
- **Nunca se persiste.** Ése es el mecanismo, no un detalle: en cualquier arranque que no empiece con
  un tap, el set está vacío y el intent guardado no puede pedir entrada por su cuenta.
- Se **consume** en `attemptJoin`, justo antes del RPC y único call-site de `join_group` ⇒ un tap vale
  como mucho una solicitud, aunque boot y foreground corran en el mismo arranque.
- Y se **re-arma** en toda rama que conserve el intent (`.sessionRequired`, `.transient`,
  `.channelDisabled` y el `catch` genérico). Sin esa simetría, un corte de red de dos segundos
  convertía el tap en pérdida silenciosa: arm gastado, RPC fallido, reconciler que ya no reintenta.
  Comprobado que la simetría es completa: las tres ramas que conservan re-arman, la que limpia no.

### Alcance real: sólo `rejected`

`left` y `removed` **nunca tienen fila local**. El servidor los excluye del pull a propósito
(`gateway/src/groups/routes.ts:466-468`: «a quien EXPULSAN le sigue desapareciendo en silencio, que
es una frontera deliberada»), y sin fila el tap entra por el camino de alta nueva, que ya funciona.
`isTerminal` los cubre por completitud del switch, no porque sean alcanzables — y por eso **no se
cableó su copy**: habría sido fabricar código inalcanzable, justo lo que se barrió esta mañana.

### Verificado por mutación, no por su verde

Revertido el gate a su forma original, el test cae con **`counter.calls → 0`** — cero llamadas a
`join_group`, que es literalmente lo que le pasa hoy a la persona. Los dos tests cuentan el
`joinProvider`: 0 sin tap, exactamente 1 con tap tras correr boot y foreground.

El canario que mentía deja de mentir en este camino: con member terminal emite
`|backendMemberTerminal` en vez de `|backendMemberPresent`. **Quedan otros emisores sin revisar** —
`GroupsSyncClient` publica `backendPull|<status>` cuando la fase se mueve, así que un rechazo
materializado por pull sigue entrando en la serie como «reconciled». Su detail lleva el status, así
que el dashboard puede separarlo; decidir si se toca es aparte.

### Lo que falta, y por qué esto está en `qa` y no en `done`

**La cadena está medida en código y verificada por tests, pero nunca se ha visto en un teléfono.**
El device-QA de cinco minutos sigue siendo el paso que la confirma: ser `rejected` en un grupo,
matar la app, tapear un enlace nuevo, y comprobar que la solicitud llega al admin — **una sola vez**.

### Un segundo bug salió de aquí

Al medir el fan-out apareció que **un re-tap estando ya pendiente vuelve a notificar al admin, hoy,
en producción**. Es del lado del servidor y va aparte: `tickets/backlog/rejoin-tap-renotifies-admins.md`.
