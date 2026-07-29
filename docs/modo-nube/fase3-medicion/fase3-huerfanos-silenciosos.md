# Fase 3 · lente «huérfanos silenciosos» — medición contra HEAD `ca06cfd5` (branch 2.0.5)

Objetivo: lo que queda **roto sin ruido** tras borrar el transporte. No errores de compilación —
comportamiento que se apaga y nadie se entera. Todo con `file:línea` medido contra HEAD; nada del plan.
No se editó ningún fichero del repo.

Leídos antes de empezar: `fase3-ficheros-enteros.md`, `fase3-recortes.md`, `fase3-acoplamientos.md`,
`fase3-conservar.md`, `fase3-canarios-indice.md`, `fase3-tests.md`. Donde uno de ellos ya cubrió un
hallazgo lo digo y no lo re-derivo; lo de abajo marcado **[NUEVO]** no aparece en ninguno de los seis.

---

## Veredicto en 6 líneas

| # | Apagón silencioso | Coordenada raíz | ¿Lo caza el compilador? |
|---|---|---|---|
| **S1** | El flag del canal nuevo está **compilado en `false`** ⇒ al borrar la rama del transporte, ~20 routers se quedan eligiendo una rama que ya no existe | `Yala/Services/CloudSync/CloudSyncFlags.swift:266` | **NO** |
| **S2** [NUEVO] | `movedToBackendAt` pierde su ÚNICO escritor ⇒ el **freeze del miembro y el CTA «vuelve a entrar» nunca vuelven a activarse** | `Yala/Services/Groups/CKRecordTranslator.swift:127`, `:151` | **NO** |
| **S3** [NUEVO] | Muere el desatasco de «esperando aprobación» y el trigger `.remoteInsert` del reconciler — sin espejo en el canal nuevo | `Yala/Services/Groups/SplitSyncManager.swift:1758-1769` | **NO** |
| **S4** [NUEVO] | Detección en vivo de «me sacaron del grupo» — sin espejo en el canal nuevo; queda solo la red de cold boot | `Yala/Services/Groups/SplitSyncManager.swift:2293-2298` → `:1697-1715` | **NO** |
| **S5** | Acciones de UI que pasan a **no-op con spinner**: pull-to-refresh, «invitar», «crear grupo» | `GroupsViewModel.swift:202`, `GroupDetailViewModel.swift:435`, `GroupMembersView.swift:455` | parcial |
| **S6** [NUEVO] | `SoftDeleteObserverLogic.swift` (31 líneas) queda huérfano total y **no está en ninguna lista** | `Yala/App/Logic/SoftDeleteObserverLogic.swift` | **NO** |

---

## S1 · El apagón estructural: el flag está en `false` y el `else` es el transporte

**Medido:**

```
Yala/Services/CloudSync/CloudSyncFlags.swift:266   private static let groupsBackendCompiledDefault = false
Yala/Services/CloudSync/CloudSyncFlags.swift:257-263  static var groupsBackendEnabled  → compiledDefault && CloudRemoteFlags…
```

⇒ **en todo build de producción de HEAD, `CloudSyncFlags.groupsBackendEnabled == false`.** Hay
**38 call-sites de código** (sin contar comentarios) que lo leen. El molde repetido en el repo es
`if flagOn { canal nuevo } else { transporte }`, y hoy **siempre** se ejecuta el `else`.

La Fase 3 borra el `else`. Si el flag no se enciende **en el mismo commit**, cada uno de estos sitios
pasa de «funciona por CloudKit» a «no hace nada», compilando limpio:

| Sitio | Con el flag OFF hoy | Tras la Fase 3 con el flag OFF |
|---|---|---|
| `Yala/App/AppBootstrapper.swift:325` → `GroupsSyncClient.startIfEligible` | no-op (el canal nuevo no arranca) | **no arranca ningún canal**: el `initialize()` del transporte (`:317`) ya no existe |
| `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:394-395` (`syncNowFromPush`) | `return false` inmediato | idem ⇒ push y pull-to-refresh mudos |
| `Yala/Services/CloudSync/CloudSyncRuntime.swift:579` (piggyback del ciclo de Grupos) | no entra | no entra |
| `Yala/App/AppBootstrapper.swift:1247` (re-arranque en foreground) | no-op | no-op |
| `Yala/App/AppBootstrapper.swift:428` (`GroupBatchLeaveStore.hasUnfinishedWork`) | no resume | no resume |
| `Yala/App/AppBootstrapper.swift:1705` (routing de invite) | cae al camino CKShare | **`handleInviteLink` mudo** — ya lo documentó `fase3-conservar.md` §c.1 |
| `Yala/App/Logic/GroupCreateRoutingLogic.swift:29` (`guard flagOn else { return .cloudKit }`) | `.cloudKit` | `.cloudKit` = rama borrada ⇒ crear grupo no guarda nada |
| `Yala/App/ViewModels/GroupDetailViewModel.swift:435` · `Yala/App/Views/Groups/GroupMembersView.swift:455` | rama CKShare | ver S5 |
| `Yala/Services/Groups/GroupService.swift:68` (`routesMembershipToBackend`) | `false` | `false` ⇒ toda operación de membresía sin destino |
| `Yala/App/Logic/GroupsEmptyStateLogic` vía `GroupsContainerView.swift:316`, `:609` | siempre `.standard` | siempre `.standard` ⇒ el empty-state «tus grupos están en tu cuenta» nunca aparece |
| `Yala/App/Logic/GroupFreezeLogic.swift:66` (`GroupBackendCapability.current`) | `.incapableBuild` | `.incapableBuild` ⇒ el CTA de re-join se auto-bloquea (`GroupDetailView.swift:491`) |

**Segundo filo del mismo cuchillo:** `SplitGroup.isBackendGroup` (`Yala/Models/SplitGroup.swift:52`) es
`false` en **todo grupo existente**; su propio doc lo dice (`:47`: «con el flag OFF SIEMPRE es `false`»).
Sus dos únicos escritores a `true` son `GroupBackendMembershipService.swift:81` (grupo nacido backend) y
`GroupsSyncClient.swift:1851`/`:1866` (pull de adopción). Por tanto, **aun encendiendo el flag**, los
routers con forma `flag && group.isBackendGroup` (`GroupDetailViewModel.swift:435`,
`GroupMembersView.swift:455`, `GroupService.swift:68`) siguen cayendo al `else` para todo grupo que ya
existía en el device. No es un problema del flag: es que **no queda camino para un grupo CloudKit-era**.

**Qué vería el usuario:** Grupos abre, la lista se ve (es local), y nada sincroniza, invita, crea ni
propaga. Sin alerta, sin log, sin canario (los 8 canarios de Grupos se van — `fase3-canarios-indice.md`
§a.1 —, así que el dashboard tampoco lo distingue de «sin incidentes»).

---

## S2 · [NUEVO] El marcador de migración pierde su único escritor ⇒ el freeze del miembro nunca se activa

Éste es el hallazgo más caro de mi lente y no aparece en ninguno de los otros cinco ficheros.

### La medición

`grep -rn "movedToBackendAt *=" Yala/` → **2 escritores, los dos en fichero condenado**:

```
Yala/Services/Groups/CKRecordTranslator.swift:127   group.movedToBackendAt = record[F.movedToBackendAt] as? Date        // apply, grupo NUEVO
Yala/Services/Groups/CKRecordTranslator.swift:151   group.movedToBackendAt = record[F.movedToBackendAt] as? Date ?? …   // update
```

(+ el lado de subida `:99-100`. `Yala/Services/Groups/CloudKitConstants.swift:50` es solo la field key.)

Idéntico para su compañero de viaje:

```
Yala/Services/Groups/CKRecordTranslator.swift:128, :158   group.backendReInviteToken = record.encryptedValues[…]
Yala/App/Logic/GroupsIdentityPurgeGate.swift:185          row.backendReInviteToken = nil     ← el ÚNICO otro escritor, y pone nil
```

**⇒ tras la Fase 3, `SplitGroup.movedToBackendAt` (`Yala/Models/SplitGroup.swift:61`) y
`SplitGroup.backendReInviteToken` (`:67`) son campos que NADIE vuelve a escribir.** No están en la lista
de la Fase 4 (la Fase 4 retira 4 campos, pero estos dos son la identidad del estado migrado, no schema
CloudKit muerto: `movedToBackendAt` es el único dato que le dice a un miembro que su grupo se mudó).

### La cascada de gates que quedan permanentemente en `false`

`SplitGroup.isMigratedFrozen` (`Yala/App/Logic/GroupFreezeLogic.swift:17-24`) →
`GroupFreezeLogic.isFrozen` (`:111-121`), cuyo primer guard es literal:

```
Yala/App/Logic/GroupFreezeLogic.swift:117   guard movedToBackendAt != nil, !isBackendGroup else { return false }
```

Con `movedToBackendAt` siempre `nil`, `isMigratedFrozen` es **siempre `false`**. Consumidores que
cambian de comportamiento sin fallar:

| Consumidor | Coordenada | Qué deja de pasar |
|---|---|---|
| Guard de escritura (gastos) | `Yala/Services/Groups/GroupExpenseService.swift:580` `if group.isMigratedFrozen { throw .movedToBackend }` | **nunca lanza** ⇒ el gasto se guarda local y no viaja a ninguna parte |
| Guard de escritura (grupo) | `Yala/Services/Groups/GroupService.swift:151` | nunca lanza |
| Elegibilidad de gasto | `Yala/App/Logic/GroupExpenseEligibilityLogic.swift:36` | siempre elegible |
| FAB de nuevo gasto | `Yala/App/Views/Groups/GroupDetailView.swift:123` | se muestra siempre |
| Botón Guardar + hint | `Yala/App/Views/Groups/GroupExpenseFormView.swift:709`, `:743-744` | el hint «se movió» nunca se dibuja |
| Acciones de admin | `Yala/App/Views/Groups/GroupMembersView.swift:176` | habilitadas siempre |
| Tarjeta de la lista | `Yala/App/Logic/GroupCardDisplayLogic.swift:29`, `:54` → `GroupCardView.swift:112`, `:237`, `:256` | el estado `.migratedFrozen` **nunca se renderiza** |
| Banner + CTA re-join | `Yala/App/Views/Groups/GroupDetailView.swift:102-109`, `:540` (`MigratedGroupBanner`) | nunca aparece |
| CTA re-join (handler) | `Yala/App/Views/Groups/GroupDetailView.swift:491-495` (`guard let token = group.backendReInviteToken`) | el guard es siempre-falso ⇒ rama inalcanzable |
| `canCurrentUserParticipate` | `Yala/App/ViewModels/GroupDetailViewModel.swift:88` | siempre participa |
| Fila «borrar copia congelada» | `Yala/App/Views/Groups/GroupSettingsView.swift:102` (`movedToBackendAt != nil && ckSystemFieldsData != nil`) | sección nunca visible |

### Qué vería el usuario

Es un **miembro** (no owner) de un grupo cuyo dueño migra al backend después de que salga la Fase 3.
Hoy su device recibe el marcador por el pull de CloudKit, el grupo se congela, la tarjeta dice «se
movió» y hay un botón «vuelve a entrar» con el token dentro. Tras la Fase 3 **no recibe nada**: el grupo
se ve normal, el FAB está ahí, sigue apuntando gastos, `validateGroupIsWritable` los deja pasar, y el
enqueue que los subía ya no existe. **Pérdida de datos percibida como funcionamiento normal**, sin
alerta, sin banner y sin ruta de recuperación (el token del CTA viajaba en el mismo marcador).

### Por qué nadie lo caza

1. **Compila**: los campos siguen existiendo en el `@Model`; los `if` siguen siendo Swift válido.
2. **Los tests siguen verdes y activamente lo tapan**: `GroupFreezeLogicTests`,
   `GroupFreezeGuardTests` y `GroupCardDisplayLogicTests` **inyectan** `movedToBackendAt` como
   parámetro de una función pura — jamás pasan por el escritor real. `fase3-tests.md` §5 los lista como
   «sobreviven intactos», y es cierto: sobreviven verdes sobre una feature apagada.
3. **La invariante ya perdió su red en la Fase 1** — está escrito en el propio fichero:
   `Yala/App/Logic/GroupFreezeLogic.swift:131`: «INVARIANTE (**sin cobertura desde la Fase 1**…):
   `migrationState != .normal` ⟺ `isFrozen == true`».
4. `qa/coverage-index.json` → área `groups-backend-g6-migration`, clasificación **`manual`** ⇒ ningún
   XCUITest, ningún ratchet.

### Precedente que lo confirma: el mismo bug YA ocurrió en la Fase 1

`markerEnqueuedFlag` (`Yala/Models/SplitGroup.swift:74`) **no tiene ni un escritor a `true` en HEAD**
(`grep -rn "markerEnqueuedFlag *= *true" Yala/ YalaTests/` → 0; `git log -S` señala **`5010db6a`**, la
Fase 1, como el commit que se llevó el setter). Consecuencia medible hoy:

```
Yala/App/Logic/GroupsIdentityPurgeGate.swift:191   if row.isBackendGroup, row.movedToBackendAt != nil, row.markerEnqueuedFlag {
Yala/App/Logic/GroupsIdentityPurgeGate.swift:192       row.markerEnqueuedFlag = false
```

es **código inalcanzable desde la Fase 1**, y el doc de `SplitGroup.swift:71` sigue describiendo un
«reconciler del boot» que ya no existe. Dos consecuencias prácticas:

* corrige a la baja el riesgo R3 de `fase3-conservar.md`: el «re-armado de `markerEnqueuedFlag`» que
  se pierde al borrar la rama de retención **ya estaba perdido**;
* es la prueba de que esta clase de bug (borrar el escritor y dejar vivos a los lectores) **ya se
  escapó una vez en este mismo plan y nadie lo notó**. S2 es la repetición, con consecuencia de usuario.

---

## S3 · [NUEVO] El desatasco de «esperando aprobación» y el trigger `.remoteInsert` no tienen espejo backend

Dentro de `processPendingRemoteChanges` del transporte:

```
Yala/Services/Groups/SplitSyncManager.swift:1758-1760   if !PendingJoinStore.all().isEmpty {
                                                            await GroupJoinReconciler.reconcile(trigger: .remoteInsert, …)
Yala/Services/Groups/SplitSyncManager.swift:1764-1769   if GroupJoinIntentTracker.shared.phase == .pendingApproval,
                                                           let trackedZone = …, let status = GroupService.shared.currentMemberStatus(…)
                                                        { GroupJoinIntentTracker.shared.noteMemberResolved(…) }
```

Inventario completo de callers de `GroupJoinReconciler.reconcile` en HEAD:

| Caller | Trigger | ¿Sobrevive? |
|---|---|---|
| `Yala/App/AppBootstrapper.swift:421` | `.boot` | sí |
| `Yala/App/ContentView.swift:597` | `.foreground` | sí |
| `Yala/App/Views/Groups/GroupInviteOnboardingView.swift:178` | `.acceptShare` | sí |
| `Yala/Services/Groups/GroupJoinIntentTracker.swift:120` | `.acceptShare` (botón «reintentar» del banner) | sí |
| `Yala/Services/Groups/SplitSyncManager.swift:808` | `.acceptShare` | **muere** |
| `Yala/Services/Groups/SplitSyncManager.swift:1760` | `.remoteInsert` | **muere, sin sustituto** |

`GroupsSyncClient.swift` **no aparece** en esa lista (verificado con grep repo-entero): el canal nuevo
no re-dispara el reconciler cuando materializa un grupo por pull, ni desatasca el cover de aprobación.

**Qué vería el usuario:** acaba de aceptar una invitación y está en el cover «esperando aprobación del
admin». El admin le aprueba. Hoy el siguiente pull lo detecta y el cover se cierra solo. Tras la Fase 3
el cover **se queda ahí** hasta que mande la app a background y vuelva (`ContentView.swift:597`) o la
relance. Área `groups-pending-approval-reconnect`, clasificación **`agentic`** ⇒ ningún XCUITest lo mira.

Daño colateral del mismo nudo: `GroupJoinIntentTracker.noteAcceptStarted` (`:55`) y
`noteAcceptSucceeded` (`:60`) se quedan **sin ningún emisor** (los únicos eran
`SplitSyncManager.swift:773` y `:791`) ⇒ la fase `.accepting` del banner de `GroupsContainerView.swift:502`
pasa a ser inalcanzable. Métodos vivos, cero emisores, cero warnings.

---

## S4 · [NUEVO] «Me sacaron del grupo» deja de detectarse en vivo

Cadena completa, medida:

```
Yala/Services/Groups/SplitSyncManager.swift:2291-2298   wasActiveAndCurrent → SoftDeleteObserverLogic.shouldTriggerRemovedSelfCleanup(…)
                                                        → pendingRemovedSelfZoneNames.insert(existing.groupZoneID)
Yala/Services/Groups/SplitSyncManager.swift:1697-1715   drena el set → GroupService.shared.performRemovedSelfCleanup(zoneName:…)
```

`grep -rn "removedSelf" Yala/` da **cero** hits en `Yala/Services/CloudSync/` ⇒ el canal nuevo no tiene
detector equivalente. Lo único que sobrevive es la **red de cold boot**:

```
Yala/App/AppBootstrapper.swift:1146-1150   fetch de SplitMember removidos → performRemovedSelfCleanup
```

**Qué vería el usuario:** el admin le saca del grupo. Hoy, al siguiente pull, el grupo desaparece de su
lista y se limpia. Tras la Fase 3 el grupo **sigue en su lista y editable hasta el siguiente arranque en
frío** de la app. Degradación acotada (no pérdida permanente), silenciosa, y sin error de compilación
porque toda la cadena vive dentro del fichero que se borra.

Nota de alcance: `performRemovedSelfCleanup` (`Yala/Services/Groups/GroupService.swift:611`) sobrevive
—`fase3-recortes.md` §C.2 ya lo dice— pero pierde su trigger en vivo; el que conserva es el de boot.

---

## S5 · Acciones de UI que pasan a no-op con spinner

### 5.1 · Pull-to-refresh de Grupos y del detalle

```
Yala/App/ViewModels/GroupsViewModel.swift:202-206        await SplitSyncManager.shared.syncNow(force:) ; await GroupsSyncClient.shared.syncNowFromUI() ; loadData()
Yala/App/ViewModels/GroupDetailViewModel.swift:134-138   (idéntico)
```

Al quitar la primera línea queda `syncNowFromUI()` (`GroupsSyncClient.swift:423-425`), que delega en
`syncNowFromPush` cuyo primer guard es:

```
Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:394-395   guard CloudSyncFlags.groupsBackendEnabled, sessionCheck(), !stoppedUntilRelaunch, context != nil else { return false }
```

El `Bool` de vuelta **se descarta** en ambos ViewModels. Con el flag OFF (S1) o sin sesión Nube el
usuario tira del gesto en `GroupsContainerView.swift:118` (`.refreshable`), ve girar el spinner, y no
pasa absolutamente nada. Sin alerta, sin log.

### 5.2 · «Invitar» — el caso más limpio de apagón invisible

```
Yala/App/ViewModels/GroupDetailViewModel.swift:435-451   if flag && group.isBackendGroup { token backend } else { SplitZoneManager…createShare }
Yala/App/Views/Groups/GroupMembersView.swift:455-472     (idéntico)
```

El `catch` referencia `SplitZoneError` ⇒ **el compilador obliga a tocar la función**, pero no obliga a
sustituir el `else`. Borrarlo y dejar solo el `if` compila; entonces, para cualquier grupo con
`isBackendGroup == false` (todos los preexistentes) o con el flag OFF:

* `GroupDetailViewModel`: `shareURL` sigue `nil`, `isCreatingShare = false`, ninguna rama de error.
* `GroupMembersView.swift:470-473`: `if shareURL != nil { showShareSheet = true }` ⇒ **no se abre nada**.

**Qué vería el usuario:** pulsa «Invitar» y la app no hace nada. Ni sheet, ni alerta, ni spinner que
termine en error. El fallo más difícil de reportar que existe.

### 5.3 · «Crear grupo»

`GroupCreateRoutingLogic.route` (`Yala/App/Logic/GroupCreateRoutingLogic.swift:28-33`) devuelve
`.cloudKit` con el flag OFF; `GroupsContainerView.swift:621-626` trata `.cloudKit` y `.backend` igual
(abre el form) y el reparto real está en `GroupFormView.swift:272-293`. Aquí el `switch` sobre un enum
protege parcialmente (quitar el `case` sin quitarlo del enum no compila), pero si se deja el `case`
`.cloudKit` vacío o lanzando, **crear grupo falla en silencio con el flag OFF**. El enum
`GroupCreateRoutingLogic.Route` no está en ninguna lista de la Fase 3 (ya lo señaló
`fase3-recortes.md` §Riesgo 5).

---

## S6 · [NUEVO] Barrido sistemático de huérfanos totales de producción

Método: extraje las **1345** declaraciones de tipo de nivel superior de `Yala/` y, para cada tipo cuyo
nombre coincide con su fichero, conté referencias **de código** (excluyendo líneas de comentario) fuera
del propio fichero, separando «dentro de los 13 condenados» vs «fuera». Los que quedan con
`fuera == 0 && dentro > 0` son huérfanos totales tras la Fase 3:

| Fichero | Líneas | Refs de código, solo en condenados | ¿En alguna lista? |
|---|---|---|---|
| `Yala/App/Logic/GroupAcceptShareErrorLogic.swift` | 50 | 2 (`SplitSyncManager.swift:761`, `:825`) | **NO** (lo vieron `fase3-canarios-indice.md` §b.4 y `fase3-tests.md` §4.3 — confirmado por método independiente) |
| **`Yala/App/Logic/SoftDeleteObserverLogic.swift`** | **31** | **1** (`SplitSyncManager.swift:2293`) | **NO, y nadie lo había nombrado** |
| `Yala/App/Logic/GroupsIdentityBootGuardLogic.swift` | 44 | 1 | sí |
| `Yala/App/Logic/GroupsIdentityPurgeGate.swift` | 253 | 1 | sí |
| `Yala/App/Logic/SplitSyncStartGate.swift` | 292 | 11 | sí (mixto — lleva `BootSaveGateLogic`) |
| `Yala/Services/Groups/CKRecordTranslator.swift` | 437 | 19 | sí |

Dos lecturas útiles del barrido:

* **`SoftDeleteObserverLogic.swift` hay que añadirlo a la lista de producción** (+31 líneas), y su
  borrado es lo que hace visible S4 (si se queda, el huérfano tapa que se perdió el detector).
* El hecho de que `CKRecordTranslator` salga como huérfano total **confirma por método independiente**
  la §4.2 de `fase3-ficheros-enteros.md`: las referencias de los 3 Models supervivientes son
  **solo comentarios** (no rompen el build, pero quedan apuntando al vacío).

---

## S7 · Tasks de boot de `AppBootstrapper` que tocan el transporte (inventario completo)

Mi lente pedía este inventario explícito. `AppBootstrapper.swift` = 1 fichero, **11 puntos de contacto**:

| Línea | Qué | Riesgo al borrar |
|---|---|---|
| `:316`, `:317` | `SplitSyncManager.setContext` / `.initialize()` | compila-error ⇒ visible. Pero ver S1: no queda quién arranque nada |
| `:325` | `GroupsSyncClient.startIfEligible` (flag-gated) | queda como único arranque, y es no-op con el flag OFF |
| `:392` | `retryPendingBridges(context:)` | sobrevive; su ENTRADA (`pendingBridgeChangeSet`) la producía el transporte (`SplitSyncManager.swift:1721-1727`). Con el transporte fuera el bridge remoto depende solo de `GroupsSyncClient.swift:2010-2047` |
| `:421` | `GroupJoinReconciler.reconcile(.boot)` | sobrevive — pasa a ser el ÚNICO camino de reconcile junto al foreground (S3) |
| `:428` | `GroupBatchLeaveStore.hasUnfinishedWork()` (flag-gated) | no-op con flag OFF |
| **`:440`** | `_ = try? await GroupUserIdentityService.shared.currentUserRecordName()` — comentario literal: *«Seed current iCloud user identity for groups»* | **es el único sembrador de `groups_currentUserRecordName`**. El compilador obliga a borrar la línea; la CONSECUENCIA es el riesgo R1 de `fase3-conservar.md` (propiedad `write-once-never`). Mi aportación: el sembrador es un **Task de boot**, no un camino de usuario ⇒ nadie lo va a echar de menos revisando flujos |
| `:481` | comentario del camino `PendingInviteStore` | — |
| `:1146-1150` | red de boot de `removedSelf` | **sobrevive y pasa a ser el único detector** (S4) |
| `:1164-1172` | retry de `PendingLeaveShareTracker` | muere con el tracker (S8) |
| `:1274` | `SplitSyncManager.shared.syncNow()` en foreground | muere; el equivalente backend es `:1247`, no-op con flag OFF |
| `:1705-1755`, `:1811-1897` | invite: routing, deferral, `acceptShareFromURL`, re-emisión | ~150 líneas; ya medido en `fase3-conservar.md` §c |

Verificado además que **el transporte NO emite ninguna `Notification`**: en los 13 ficheros condenados
hay un solo uso de `NotificationCenter` y es un `addObserver` (`SplitSyncManager.swift:599`, observador
de `.iCloudFirstImportCompleted`, retirado en `:660`). **Cero `Notification.Name` declarados en ficheros
condenados** ⇒ el eje «emisor muere / observador sobrevive» está limpio en el sentido de NotificationCenter.
Donde sí hay emisor↔observador es en `SessionState.markRemoteChangePending()`: el transporte lo emite en
`SplitSyncManager.swift:1347`, `:1501`, `:1754`, y el canal nuevo también
(`GroupsSyncClient.swift:1516`) ⇒ **no queda huérfano**. Igual con
`GroupNotificationService.processRemoteChanges` (`SplitSyncManager.swift:1752` muere;
`GroupsSyncClient.swift:206` sobrevive) y con `MemberChangeNotificationLogic`
(`GroupsSyncClient.swift:1565-1617` lo sigue usando).

---

## S8 · Colas persistidas cuyo consumidor muere (residuo, no pérdida)

| Key de `UserDefaults` | Declarada en | Único purgador | Tras la Fase 3 |
|---|---|---|---|
| `yala.groups.pendingInvite` | `Yala/Services/Groups/PendingInviteStore.swift:49` | su propio `clear()` (`:89`) + `AppRouter.swift:156` (`resetAll`) | **sin purgador**: `DataWipeService.swift` no la nombra (grep → 0 hits) ⇒ sobrevive incluso al «empiezo de cero» |
| `yala.groups.pendingLeaveShareZones` | `Yala/Services/Groups/PendingLeaveShareTracker.swift:25` | `remove()` desde `AppBootstrapper.swift:1172` | **sin consumidor**: el retry de boot muere. Entradas ya persistidas = «salí del grupo pero el share no se soltó», nadie lo reintenta |
| `SplitSync_ContainerMigrated_v1` | `Yala/Services/Groups/SplitSyncManager.swift:292` | ninguno | huérfana |
| entradas de `PendingJoinStore` con `isBackendJoin == false` | `Yala/Services/Groups/PendingJoinStore.swift:59` | la rama CloudKit de `GroupJoinReconciler.swift:70-95` | esa rama muere ⇒ un intent CKShare de la base instalada **no tiene handler**: sobrevive hasta el TTL y jamás completa el join |

Impacto de usuario bajo-medio (la Fase 4 retira el schema CloudKit), pero el `pendingLeaveShareZones`
y el `PendingJoinStore` no-backend son **promesas al usuario que dejan de cumplirse en silencio**, y
las dos primeras keys contradicen la promesa de `DataWipeService` / `AppRouter.resetAll()` de dejar el
device limpio.

---

## S9 · Gates que NO son un problema (medido, para que nadie pierda tiempo)

Honestidad de medición — tres cosas que parecen riesgo de mi lente y no lo son:

1. **`iCloudSyncService.splitSyncStatus`** (`Yala/Services/iCloudSyncService.swift:112-113`): la UI de
   estado de sync **nunca** mostró el estado del transporte. `splitSyncStatus` tiene **0 lectores**
   fuera de su declaración; el banner (`SyncStatusBanner.swift:88-97`) lee `service.status`, el personal.
   Borrado limpio. (Coincide con `fase3-acoplamientos.md` §1.5.)
2. **`ckSystemFieldsData`**: pierde sus escritores (`CKRecordTranslator`), pero sus lectores
   supervivientes lo tratan ya como «huella legacy» — `GroupService.swift:1395`
   (`hasLegacyCloudKitFootprint`, aviso GDPR) y `GroupSettingsView.swift:662` (limpieza manual). Un
   `nil` permanente para datos nuevos es semánticamente correcto ahí.
3. **`GroupsBetaGateLogic` / `groupsBetaUnlocked`**: `CKShareEntryHandler.swift:43` es solo **uno de
   seis** escritores; sobreviven `AppBootstrapper.swift:590`, `:1712`,
   `GroupBackendInviteEntryHandler.swift:72`, `OnboardingView.swift:1813`, `GroupsBetaGateView.swift:103`.
   El tab no se queda bloqueado. (Sí conviene saber que `:1712` es flag-gated — S1.)

---

## Coordenadas del plan que están mal, según MI medición

Solo las que toco desde esta lente (las de tamaño ya las corrigieron los otros cinco ficheros y
coinciden con mi `wc -l`: los 13 ficheros del plan suman **4498** en HEAD, no 4892):

| Coordenada / afirmación del plan | Real en HEAD |
|---|---|
| Lista de producción de 13 ficheros | Faltan **2**: `Yala/App/Logic/GroupAcceptShareErrorLogic.swift` (50) y **`Yala/App/Logic/SoftDeleteObserverLogic.swift` (31)** ⇒ **15 ficheros, 4579 líneas** |
| Implícito: «borrar el transporte no cambia comportamiento porque el canal backend ya lo duplica (Fase 2)» | El canal backend está **compilado OFF** (`CloudSyncFlags.swift:266`) y `isBackendGroup` es `false` en todo grupo preexistente ⇒ la duplicación de la Fase 2 **no está en el camino de ejecución de ningún device de producción**. La Fase 3 no es un borrado neutral: es un cutover |
| Implícito: el freeze/CTA de migración es del canal backend | Su dato de entrada (`movedToBackendAt`, `backendReInviteToken`) **solo** lo escribe `CKRecordTranslator.swift:127`/`:151`/`:128`/`:158` ⇒ la feature muere con la Fase 3 (S2) |
| `markerEnqueuedFlag` como parte viva de la rama de retención | **Sin escritor a `true` desde la Fase 1 (`5010db6a`)** ⇒ `GroupsIdentityPurgeGate.swift:191-193` ya es inalcanzable en HEAD |

---

## Orden de mitigación que sugiere esta lente

1. **Antes de borrar nada**: decidir por escrito si la Fase 3 **enciende el flag** (`CloudSyncFlags.swift:266`)
   en el mismo commit. Si no lo enciende, la Fase 3 no es «borrar el transporte»: es «apagar Grupos».
   Y si lo enciende, hace falta el camino que ponga `isBackendGroup = true` en los grupos preexistentes
   (hoy solo lo hacen `GroupBackendMembershipService.swift:81` y el pull `GroupsSyncClient.swift:1851`/`:1866`).
2. **Decidir el destino del marcador de migración (S2)**: o el canal backend entrega
   `movedToBackendAt`/`backendReInviteToken` (hoy no están en `GroupEntityEmissionMap` ni en
   `GroupMerkleProjection`), o el freeze del miembro y su CTA se borran **explícitamente** con sus 12
   consumidores y sus tests — no se dejan verdes sobre una feature apagada.
3. **Portar al canal nuevo, en el mismo commit**: el desatasco de `.pendingApproval` y el trigger
   `.remoteInsert` (S3) y el detector de `removedSelf` (S4). Son ~15 líneas cada uno y son
   comportamiento que el usuario nota.
4. **Cerrar los no-ops de UI (S5)** con una rama de error de verdad, no con un `else` borrado.
5. **Añadir a la lista de borrado** `SoftDeleteObserverLogic.swift` y `GroupAcceptShareErrorLogic.swift`
   (S6), y a la de purga las 3 keys de `UserDefaults` (S8).
