---
id: secondary-guest-exit-lock-and-outbox
status: in-progress
created: 2026-08-12
updated: 2026-08-26
source: YalaWiki/Bugs/secundaria-salida-de-la-invitada-bloqueo-permanente-y-outbox-de-grupos.md
---


# Cuando la invitada se va: sus gastos de grupo pueden quedarse sin subir, y el error siempre culpa a la conexión

## El síntoma, en lenguaje de usuario

Fui de visita al móvil de alguien, usé Yala con mi cuenta y apunté gastos de un grupo. Al cerrar mi
sesión:

- **mis últimos gastos de grupo pueden no haber subido**, y el borrado de salida se lleva la copia local;
- si algo bloquea el cierre —aunque sea un corte de red de dos segundos— Yala me dice **«revisa tu
  conexión»** y no me deja irme, sin ofrecer el «un momento más» que sí existe para otros;
- y en todo el rato que estuve dentro, **nada me avisó** de que tenía cambios sin subir.

## Lo medido

### 1 · El camino secundario empuja UN outbox; el `.cloud` empuja los dos

`CloudSessionSignOut`:
- camino `.cloud`: empuja **los dos** outboxes antes de cerrar (`pushAllPendingGroupsForSignOut` en
  `:262`, re-verificación conjunta en `:281`);
- camino **secundario**: solo empuja el **personal** (`:334`) y solo re-verifica el personal.

Mientras tanto, el wipe de arranque borra igual `YalaGroups-Secondary` y `YalaSyncMeta-Secondary`
(`SwiftDataConfiguration.swift:831-836`) — **donde vive `GroupSyncOutbox`**. Y la purga de frontera borra
además el espejo del App Group (`SecondarySessionBoundaryPurge.swift:38`), que era la red de
rehidratación.

*NO medido: el impacto e2e (cuántas filas se pierden en la práctica). Sí medida la asimetría.*

**Y el comentario que justifica ese teardown es falso hoy**: dice que en sesión secundaria el canal de
Grupos «ni corre» (`CloudSessionSignOut.swift:357-358`), pero con `groupsBackendEnabled` ON la sesión
secundaria **sí** corre el canal sobre su propio store (`GroupsSyncClient.swift:309`;
`SwiftDataConfiguration.swift:1103` + `:458` montan `YalaGroups-Secondary`) — que es exactamente la
condición en la que ese archivo existe.

### 2 · Las tres salidas de bloqueo son SIEMPRE `.permanent`

`CloudSessionSignOut.swift:345`, `:353` y `:364` construyen `reason: .permanent`. Por tanto:
- el copy «Un momento más» (`ProfileView.swift:434`) **no la alcanza nunca**,
- el presupuesto de reintento de 45 s de `GroupsSignOutRetryDecision` tampoco,
- y `waitingForPending` solo se enciende en el camino solo-grupos (`:426`, `:455`) ⇒ tampoco ve el caption
  «Guardando tus cambios pendientes…».

Un bloqueo transitorio le dice que revise su conexión.

### 3 · La invitada no tiene ninguna superficie que le avise de cambios sin subir

`StorageRowGateLogic.swift:59`: `if isSecondaryActive { return devPanelOverride }`, y
`devPanelOverrideAvailable` es `false` literal en producción ⇒ la fila **«Dónde viven tus datos»**
—detrás de la que vive el banner S11 de cambios pendientes— está **oculta para ella**. Su primera señal
es el aviso de bloqueo al intentar salir.

### 4 · El swap de persona sin reiniciar no la alcanza

`attemptSignOutSwap` tiene un único call-site, en `performCloudSecureSignOut`
(`CloudSessionSignOut.swift:327`). La invitada **siempre** paga el cover terminal y el reinicio. El
alcance cerrado ya está declarado en el panel `signout-swap` del Atlas y el código lo confirma — se anota
por completitud del recorrido, no como defecto.

## Lo que queda del lado del dueño (medido, y no todo es malo)

- **El dueño NO paga un segundo reinicio**, y está medido: el borrado secundario no escribe
  `neutralMountArmed` y su archivo existe ⇒ monta con su mirror y `shouldRelaunch` da `false`. Lo que sí
  cambia es que **llega al Welcome**, porque el borrado pone los tres flags de onboarding a `false`
  (`SwiftDataConfiguration.swift:844-846`).
- **El reclamo de cuenta y la intención de permiso de la invitada sobreviven para siempre** en el
  `UserDefaults` del dueño: `cloudSync.claimAction.<sub de ella>` (no se borra en el sign-out, declarado
  en su cabecera, `CloudClaimActionStore.swift:15-16`) y `yala.groups.pendingConsentRegistration` con su
  `sub` y su hora (`GroupsConsentState.swift:136-138`, su no-borrado está escrito como decisión). **Ambos
  son inertes para él** (van sellados con el `sub` de ella) — se anota porque un lector futuro los verá y
  pensará que son suyos.
- **«Vaciar mis datos» sigue alcanzable para la invitada** y llama `resetAllUserPreferences()`, que hace
  `removeObject` en bloque sobre `UserDefaults.standard` (`ProfileView.swift:961` →
  `DataWipeService.swift:195`). Coincide con el residual (b) del `coverage-index`; re-medido y sigue vivo.
  → cubierto en [[secundaria-la-visita-escribe-en-el-dominio-del-dueno]].

## Nota de higiene documental encontrada por el camino

El residual GDPR del `qa/coverage-index.json` (área de sesión secundaria, residual (a)) **caducó con C1**:
dice que el consent de Grupos de la invitada «es `.localOnly` y nunca llega a su backend… su registro de
aceptación muere en el wipe», citando `GroupsConsentState.swift:58-61`. Hoy esas líneas son el docblock de
`snapshotKey`, y el registro **viaja a la cuenta por RPC** (append-only en servidor,
`GroupsConsentRegistrar.swift:88`). Lo que muere en la purga es la copia **local**.

## El fix

1. **Empujar los dos outboxes en el camino secundario**, igual que el `.cloud`. Es la asimetría más
   barata de cerrar y la que puede perder datos.
2. **Clasificar el bloqueo** en vez de emitir `.permanent` siempre: el mecanismo (`BlockReason`,
   `GroupsSignOutRetryDecision`) ya existe y está escrito para esto.
3. **Decidir qué ve la invitada sobre sus cambios pendientes.** Hoy la fila está oculta a propósito
   (evita que toque el almacenamiento del dueño), así que la superficie tendrá que ser otra — un banner
   propio, no la fila.
4. Corregir el comentario de `:357-358` en el mismo movimiento.

## Relacionados

- [[secundaria-la-visita-escribe-en-el-dominio-del-dueno]] — la entrada del mismo recorrido
- [[grupos-invitado-el-no-no-tiene-pantalla]]

## Implementación · pieza 1 (2026-08-12)

Re-medido y **confirmado literal**: el camino `.cloud` empuja los dos outboxes (`:262` el de grupos,
`:281` la re-verificación conjunta `residualPersonal + residualGroups`) y el secundario empujaba solo
el personal y re-verificaba solo el personal.

El camino secundario gana el `pushAllPendingGroupsForSignOut(context:)` **antes** del teardown (donde
la guardia de generación abortaría el ciclo, mismo racional que el paso 2 del `.cloud`) y su
re-verificación de S2 pasa a sumar `liveGroupsPendingCount`. `performSecondaryCloudSignOut` recibe
ahora el `ModelContext` que `signOut(context:)` ya tenía y pasaba a los otros tres caminos.

**Y el comentario falso, corregido en el mismo movimiento** (§1 del ticket): decía que en secundaria
el canal de Grupos «ni corre», justificando no empujar precisamente en la configuración en la que ese
archivo existe.

Pin: `SecondarySignOutPushesBothOutboxesTests` (2, source-scan — `performSecondaryCloudSignOut` es
privado y su camino exige runtime de red; lo que hay que fijar es que el paso exista, que vaya ANTES
del teardown y que la re-verificación cuente los dos).

## Lo que sigue abierto

### 2 · las tres salidas de bloqueo son siempre `.permanent` — NO tocada

Sigue igual (`:345`, `:353`, `:364`). Es un cambio de clasificación con mecanismo ya existente
(`BlockReason`, `GroupsSignOutRetryDecision`), pero decide qué ve la persona en un error y prefería no
mezclarlo con el fix que puede perder datos: son dos commits distintos y el segundo necesita mirar la
tabla de reintentos entera, no solo estas tres líneas.

### 3 · la invitada no ve sus cambios pendientes — NO tocada (y es diseño)

`StorageRowGateLogic.swift:59` esconde la fila a propósito, así que la superficie tiene que ser otra
—un banner propio— y eso es producto, no un guard. **Nota**: el banner de hidratación que esta misma
sesión amplió (`d10adddd`) es el molde más cercano que hay hoy para ese banner.

### 4 · el swap sin reiniciar no la alcanza

Anotado por completitud en el ticket, confirmado por el código, **no es un defecto**. Sin cambios.

migrated from YalaWiki Bugs/secundaria-salida-de-la-invitada-bloqueo-permanente-y-outbox-de-grupos.md @ 1934e8ad

---

## DECISIÓN DEL OWNER · 2026-09-03 — la invitada ve un aviso propio antes de salir

**Aprobada la pieza 3** con la salida «banner propio»: al cerrar sesión con cambios de grupo sin
subir, la invitada ve un aviso que le dice que los tiene y le deja **esperar o salir igualmente**.

**Por qué no las otras dos.** «No avisar» es lo que pasa hoy y es pérdida de datos en silencio.
«Bloquear la salida» no se elige por una razón de producto que el ticket ya apuntaba y conviene dejar
escrita: la invitada está en el móvil de OTRA persona y ese móvil hay que devolverlo — un cierre que
no se puede completar la deja atrapada, y con mala red es un final peor que perder un gasto.

**Superficie**: tiene que ser nueva. La fila donde vive esa información está oculta a propósito en
sesión de visita, así que no vale reutilizarla. El molde más cercano del repo es el banner de
hidratación (`d10adddd`).

La pieza 2 (clasificar el error de salida en vez de decir siempre «revisa tu conexión») no dependía de
esta decisión y sigue siendo código pendiente — con el aviso del ticket: hay que mirar la tabla de
reintentos entera, no solo las tres líneas.
