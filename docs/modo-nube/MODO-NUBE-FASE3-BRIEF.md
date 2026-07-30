---
created: 2026-07-29
updated: 2026-07-30
tags: [modo-nube, grupos, fase3, brief]
status: blocked  # commit 0 HECHO (bc486c92) + Fase 2 bis: escritor de identidad (40a4e417) y sexto resolvedor; los commits 1 y 2 siguen bloqueados por el flag
---

# Fase 3 — brief, con las coordenadas medidas y el bloqueo que el plan no nombra

Medición del 2026-07-29 contra HEAD `ca06cfd5`, con 8 agentes en paralelo (6 midiendo por bloque, 2
refutando). Detalle completo en `docs/modo-nube/fase3-medicion/*.md` — 2.465 líneas de informe.
El plan ([[MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS]] §3, Fase 3) marcaba sus cifras como NO VERIFICADAS.

---

## 🔴 BLOQUEO · La Fase 3 no se puede ejecutar todavía

`CloudSyncFlags.swift:266` → `private static let groupsBackendCompiledDefault = false`, y
`groupsBackendEnabled` compone `compilado && remoto`, así que el remoto **solo puede matar**.

⇒ **en todo build de producción de hoy el canal backend está APAGADO y el transporte CloudKit es el
ÚNICO canal vivo de Grupos.** Borrarlo deja la app sin ninguna vía de sync de grupos.

**El plan no nombra este flag ni una vez** — ni como prerrequisito ni como parte del changeset. Y su
criterio de hecho pide «QA en simulador del recorrido entero por el canal backend», que con el flag OFF
no se puede ejercitar: se estaría borrando el único canal que funciona sin haber probado el que queda.

Esto no es una objeción de alcance. Convierte tres hallazgos de hipotéticos en **fallos de producción**,
porque cada resolvedor de identidad de Grupos tiene la forma `groupsBackendEnabled ? <backend> : nil` y
con el flag OFF la única identidad viva es la CloudKit-era que la Fase 3 borra:

| Resolvedor | Coordenada |
|---|---|
| `GroupSettingsView.hasOutstandingBalance` | `GroupSettingsView.swift:706` |
| `GroupJoinReconciler.currentUserMemberExists` | `GroupJoinReconciler.swift:296` |
| `GroupService.refreshCurrentUserFlags` | `GroupService.swift:1010` |

**Decisión de entrada, y es de release, no de refactor:** o el flip compilado a `true` entra en el mismo
lote —y entonces la Fase 3 **es el encendido del canal nuevo**, no limpieza— o los borrados se paran en
la frontera de la Fase 2. No hay tercera opción que deje la app funcionando.

⇒ **Prerrequisito real: bloqueante #4** (las 2 líneas de `CloudBackendConfig`) **+ el flip del
compilado**, como su propio lote, ANTES de cualquier borrado.

---

## Los números medidos (y cuánto se desvían del plan)

| Bloque | Plan | Medido | Nota |
|---|---|---|---|
| Ficheros «enteros» (13) | 4.892 | **4.498** → **4.355** tras `bc486c92` | −384 son solo `SplitSyncManager`: **2.521**, no 2.905. El commit 0 se llevó 143 de `SplitSyncStartGate` (292→149) |
| Recortes en ficheros vivos | no cuantificado | **~460** (139 exactas, ~321 estimadas) | `GroupService` 1.534 → ~1.075 |
| Tests | «10 ficheros, ~2.042» | **1.855 en 15 ficheros** → **1.723** tras `bc486c92` | 9 mueren enteros (1.504) + 6 con recorte (351). El commit 0 sacó 132 de `SplitSyncStartGateTests` (395→263) |
| Canarios y breadcrumbs | no cuantificado | **~74** | `MetricsService` 451→~433 · `GroupsSyncBreadcrumb` 213→~157 |
| **Total** | ~6.934 | **~5.974** → **~5.699** tras `bc486c92` | |

**6 de 13 rutas del plan están mal**: apuntan a `Yala/Services/CloudSync/` cuando el transporte vive en
`Yala/Services/Groups/`. Y `Services/CloudSync/Groups/` **sí existe**, con 14 ficheros de nombre casi
idéntico ⇒ es una trampa activa, no un typo.

**Las 5 coordenadas de `propagateBoolCustomKey` están mal, incluidas 3 marcadas ✅ en el plan**: la
función está en `:246` (no `:236`) y los callsites en `GroupService:238`/`:318` y
`SplitSyncManager:2033`/`:2039`. Y no son 4 recortes sino **2**: los de `SplitSyncManager` viven en
`handleConflict` y se van con el fichero.

---

## 3 de los 13 «ficheros enteros» NO son borrados de fichero entero

| Fichero | Qué esconde | Si se borra entero |
|---|---|---|
| ~~`Yala/App/Logic/SplitSyncStartGate.swift` (292)~~ → **149, RESUELTO en `bc486c92`** | ~~`BootSaveGateLogic` (`:198-292`) + `WaitResolution` (`:61`) + `resolveWaitByQuiescence` (`:97-108`)~~ — ya viven en `BootSaveGateLogic.swift` | ~~reintroduce el crash-loop SIGTRAP del restore de iCloud~~ (H-2026-07-18-8) — el commit 1 ya puede borrar el fichero entero |
| `Yala/Services/Groups/GroupUserIdentityService.swift` (~~88~~ → **85 tras `40a4e417`**) | `deterministicUUID` (`:74-84`), usado por `GroupBackendIdentityLogic.swift:38` y `GroupsSyncClient.swift:1901`, **+ el cache `cachedRecordName` (`:24-28`, `:40-47`)** — el ESCRITOR ya salió a `Services/CloudSync/Groups/` (Fase 2 bis) | rompe la derivación de ids del canal backend **y** deja el cache sin dueño |
| ~~`CKConstants` (en `CloudKitConstants.swift`)~~ → **RESUELTO en `bc486c92`** | ~~`zonePrefix`~~ (+ `zoneName(for:)`) ya vive en `SplitGroupZone` (`Yala/Models/`); el `init` de `SplitGroup.swift:102` apunta ahí | ~~se rompe la identidad de los grupos en el backend~~ — literal `"SplitGroup-"` conservado byte a byte |

---

## Los 6 apagones silenciosos — ninguno lo caza el compilador

Cuatro son **nuevos**: no están en el plan.

| # | Qué se apaga | Coordenada raíz |
|---|---|---|
| S1 | ~20 routers `flag ? backend : transporte` se quedan eligiendo una rama que ya no existe | `CloudSyncFlags.swift:266` |
| **S2** | `movedToBackendAt` pierde su ÚNICO escritor ⇒ el freeze del miembro y el CTA «vuelve a entrar» **nunca se activan** | `CKRecordTranslator.swift:127`, `:151` |
| **S3** | Muere el desatasco de «esperando aprobación» y el trigger `.remoteInsert` del reconciler — sin espejo backend | `SplitSyncManager.swift:1758-1769` |
| **S4** | «Me sacaron del grupo» deja de detectarse en vivo; queda solo la red del cold boot | `SplitSyncManager.swift:2293-2298` → `:1697-1715` |
| S5 | Pull-to-refresh, «invitar» y «crear grupo» pasan a **no-op con spinner** | `GroupsViewModel:202` · `GroupDetailViewModel:435` · `GroupMembersView:455` |
| **S6** | `SoftDeleteObserverLogic.swift` (31) queda huérfano total — **no está en ninguna lista del plan** | su único consumidor de producción es `SplitSyncManager` |

### Y el peor de todos, que no es un apagón sino un colapso — ✅ RESUELTO (Fase 2 bis, `40a4e417`)

**`cachedRecordName` se queda sin escritor.** Su único escritor en todo el repo es el
`UserDefaults.set` de `GroupUserIdentityService.swift:41`, **dentro del `currentUserRecordName()` que el
plan borra**. En instalación fresca queda `nil` para siempre ⇒ mueren en silencio sus consumidores vivos,
que son **CINCO, no cuatro** (verificado con `grep -rn "shared.cachedRecordName" Yala/`; los dos de
`SplitSyncManager` —`:265` y `:1649`— no cuentan porque mueren con el fichero):

| Consumidor | Coordenada |
|---|---|
| `GroupService.refreshCurrentUserFlags` | `GroupService.swift:1019` |
| `GroupExpenseService.currentUserMemberID` | `GroupExpenseService.swift:614` |
| `GroupJoinReconciler.currentUserMemberExists` | `GroupJoinReconciler.swift:293` |
| `GroupSettingsView.hasOutstandingBalance` | `GroupSettingsView.swift:704` |
| `GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin` | `GroupBackendInviteEntryHandler.swift:127` |

**Y los tests lo TAPAN**: las 3 suites que los prueban inyectan la identidad con
`_testSetCachedRecordName`, así que compila, pasa y falla solo en un device real. «Conservar
`cachedRecordName`», como dice el plan, es insuficiente: hay que conservar **quién lo escribe**.

#### La decisión, medida: se conserva el escritor (opción 1). Las otras dos se descartaron con datos

**Lo elegido.** El escritor —key, fetch y persistencia— se muda a
`Yala/Services/CloudSync/Groups/GroupICloudIdentitySeed.swift`: donde vive el canal nuevo y donde el
criterio de salida de la Fase 3 (`grep -r "import CloudKit" Yala/Services/Groups/ Yala/App/Views/Groups/`
→ 0) **no mira**. Solo necesita `CKContainer(identifier:).userRecordID()` y
`SwiftDataConfiguration.groupsCloudKitContainerIdentifier`, no `CKConstants` ⇒ no arrastra transporte. El
seed de boot de `AppBootstrapper` entra por ahí y `currentUserRecordName()` queda como fachada que delega,
así que **el commit 1 puede borrar el método sin dejar la identidad sin escritor**.
`GroupUserIdentityService` conserva el cache (`cachedRecordName`) y `deterministicUUID`.

**Opción 2 (derivarlo del canal backend) — DESCARTADA, y es la que parecía mejor.** No se sostiene, por
una circularidad del servidor: `migrate_group` sube los members no-owner como **placeholders `user_id
NULL`** (`qa/cloud/g6_01_migrate_group.sql:158`) y su reclamación **solo** ocurre vía
`join_group(token, p_legacy_member_key)`, que es quien estampa `user_id = v_uid`
(`g7_02_encrypt_groups_cutover.sql:223-241`). La RLS entrega el grupo únicamente a quien ya está
reclamado por `user_id` ⇒ **el `member_key` legacy no puede BAJAR antes del rebind que lo necesita**. Y el
server no puede decírnoslo por otra vía: no conoce el recordName de iCloud del usuario hasta que el
device se lo manda. `isLegacyMemberKey` sirve para elegir el namespace del id local, no para reconocer al
usuario sin identidad previa.

**Opción 3 (aceptar el nil) — DESCARTADA, pero se midió y 4 de los 5 no pierden nada.** En una
instalación fresca el fallback iCloud es **estructuralmente inerte** en los cuatro primeros: comparan
`cloudKitUserRecordID == cachedRecordName`, y toda fila born-remote tiene `cloudKitUserRecordID == ""` por
diseño (`GroupsSyncClient.applyMember` lo dice explícito). Ahí quien resuelve es el `sub`
(`refreshCurrentUserFlags` sigue viva por `backendCanResolve`, y `selectCurrentUserMemberID` tiene el
fallback backend ANTES del de iCloud). **El que sí pierde es el quinto**, y lo que pierde es dinero
atribuido: sin `legacyMemberKey` el re-join de un grupo migrado entra como member NUEVO y el historial
CloudKit-era del usuario queda colgando de una fila fantasma. Hoy eso es el residual §9.3b —acotado a
otro Apple ID o a un device sin iCloud— y **tras la Fase 3 pasaría a ser el caso general**. Un residual
que se convierte en el caso normal no es un residual.

**Fecha de caducidad, anotada:** el commit 2 de la Fase 4 retira el entitlement del container de Grupos ⇒
desde ahí el fetch falla siempre y el rebind legacy muere con él, esta vez por decisión de release y no
por un descuido. Las filas placeholder seguirán en el servidor: si hay que hacer algo con ellas, se decide
allí.

**El test tuvo que ser ESTRUCTURAL, y esa es la lección de método.** Rojo antes (exit 65) y verde después
(exit 0), en `YalaTests/GroupICloudIdentitySeedTests.swift` (7 celdas). Las dos rojas miden *dónde vive el
escritor* y *si el seed de boot depende del símbolo que muere*. No hay test de COMPORTAMIENTO que pueda
estar rojo antes del fix: el estado post-Fase 3 es «cache nil **y** identidad de iCloud disponible», y
reproducirlo exige un fetcher inyectable que el fix es quien introduce — inyectar el cache reproduce el
bug tapado, que es exactamente lo que hacen las 3 suites que no lo cazaron. Las otras cinco celdas sí son
de comportamiento y ejercitan la instalación fresca con el cache **vacío** y el **fetcher** inyectado.

⇒ **El hueco declarado en el docblock de `GroupServiceCurrentUserFlagsTests` sigue abierto y no lo cierra
esta pieza**: ese hueco es «el 3er guard exige que el fetch a CKContainer falle», y el fetcher inyectable
vive ahora en el seam, no en el camino que `refreshCurrentUserFlags` recorre (lee el cache o llama a la
fachada). Cerrarlo pide inyectar el proveedor de identidad *en `GroupService`*, que es re-cableo de otro
consumidor. Docblock no tocado a propósito.

#### ¿Comparten mecanismo los otros cinco apagones? Solo en la firma, no en la causa

Medido antes de escribirlo, porque el molde «mueve el escritor» invita a aplicarse a todo:

- **S2 (`movedToBackendAt`) — NO.** Sus dos únicos escritores (`CKRecordTranslator.swift:127`, `:151`)
  hacen `group.movedToBackendAt = record[F.movedToBackendAt] as? Date`: **leen de un `CKRecord`**. El dato
  no está en el device esperando a que alguien lo escriba — llega por CloudKit. Post-Fase 3 no llega de
  ningún sitio, así que mover el escritor no arregla nada: el marcador tiene que viajar por el canal
  backend o el freeze no existe. Es un apagón de **FUENTE**.
- **S3 y S4** — igual que S2: lo que muere es el **evento** (el fetch de CloudKit que desatasca «esperando
  aprobación» / detecta «me sacaron»). Se resuelven espejando el trigger en el pull del canal nuevo, no
  moviendo código.
- **S6 (`SoftDeleteObserverLogic`)** — el inverso: un **consumidor huérfano**, no un escritor perdido. O
  se re-cablea a un emisor del canal nuevo o se borra; mover no aplica.

⇒ **Esta pieza es la única de las seis cuyo problema era de ESCRITOR** (el dato ya vive en el device y
solo faltaba quién lo persistiera). Lo que sí es transferible a las otras cuatro es el **método**: la
firma «compila, pasa en verde, falla en device» viene de suites que inyectan el estado que el apagón
destruye, y contra eso el test que sirve es el que pinnea el **cableado**, no el comportamiento.

#### Dos huérfanos nuevos que la Fase 3 crea aquí, y quedan REPORTADOS (fuera de ámbito)

- **`clearCache()` pierde sus callers** ⇒ tras la Fase 3 nadie puede
  olvidar la identidad de un Apple ID que se fue: la key se queda congelada con el recordName anterior.
  Va de la mano de que el boot-guard entero (`GroupsIdentityBootGuardLogic`) también muere, así que el
  cambio de Apple ID deja de detectarse — decidir junto, no por separado.
  **Actualizado 2026-07-30:** ya no es un caller sino DOS, y no son intercambiables —
  `SplitSyncManager.applyIdentityPurge` (junto a las filas purgadas, el par C-3) y
  `resetLocalGroupsSyncState(clearingIdentityCache: true)` (el handover «empiezo de cero», que borra el
  dominio entero en el acto). Al borrar el transporte hay que preguntarse por cada uno por separado: el del
  handover **no** depende de CloudKit y no puede irse con él.
- **`fetchFreshRecordName()` queda sin callers** (su único uso es `SplitSyncManager.swift:270`, el
  boot-guard) ⇒ borrable con él.
- Y uno que no es de la Fase 3 sino de **2.6**: `legacyMemberKeyForRejoin` es el **sexto resolvedor de
  identidad** y no recibió el re-cableo de 2.6. — ✅ **RESUELTO (Fase 2 bis, 2ª pieza).** Ver la sección
  siguiente: el molde de 2.6 no se podía copiar tal cual, y (A) resultó ALCANZABLE.

### El sexto resolvedor de identidad — ✅ RESUELTO (Fase 2 bis, 2ª pieza)

La lista de 2.6 nombraba cinco. Son **seis**:

| # | Resolvedor | Coordenada | Estado |
|---|---|---|---|
| 1 | `GroupService.refreshCurrentUserFlags` | `GroupService.swift:1010` | 2.6 (`08298365`) |
| 2 | `GroupExpenseService.selectCurrentUserMemberID` | `GroupExpenseService.swift:637` | 2.6 (`08298365`) |
| 3 | `GroupJoinReconciler.currentUserMemberExists` | `GroupJoinReconciler.swift:289` | 2.6 (`08298365`) |
| 4 | `GroupSettingsView.hasOutstandingBalance` | `GroupSettingsView.swift:701` | 2.6 (`08298365`) |
| 5 | `GroupNotificationService.currentMemberID(inZone:)` | `GroupNotificationService.swift:229` | 2.6 lo dejó INTACTO a propósito |
| 6 | `GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin` | `GroupBackendInviteEntryHandler.swift:106` | **Fase 2 bis, 2ª pieza** |

El commit de 2.6 re-cableó **cuatro** (1-4). El quinto es el que los demás tienen que **espejar**: resuelve
solo por `isCurrentUser`, con `sortBy joinedAt` + `fetchLimit 1`, y por eso `selectCurrentUserMemberID`
conserva el flag en primera posición. El sexto quedó fuera de la enumeración entera.

**El molde de 2.6 no se podía copiar, y ese es el hallazgo.** Los cinco primeros preguntan «¿quién soy?»
y por eso llevan el fallback por `sub`. El sexto pregunta «¿cuál era **mi ficha legacy**?», que es otra
cosa: en una zona migrada el `sub` resuelve al member **born-backend**, cuyo `cloudKitUserRecordID` está
**vacío por diseño** (`GroupsSyncClient.applyMember` nunca lo escribe) ⇒ añadir ese criterio al predicado
habría devuelto vacío o basura, y el fix habría sido peor que el bug. El criterio elegido identifica la
FILA, no al usuario: la llave sale **siempre de una fila de la zona** y el `cachedRecordName` deja de ser
una FUENTE para pasar a ser un **SELECTOR**. Cascada: (1) `isCurrentUser` con recordName no vacío,
desempate por `joinedAt` más antiguo — el criterio canónico, el mismo de `selectCurrentUserMemberID` y de
`currentMemberID`; (2) la fila cuyo `cloudKitUserRecordID == cachedRecordName`; (3) el cache a pelo **solo
si la zona no tiene censo de la era CloudKit**. Con censo y sin match, `nil`.

**Y el defecto era peor de lo que decía el bullet anterior.** No es que el flag llegue apagado «hasta que
corra `refreshCurrentUserFlags`»: en una zona del canal backend esa función **no lo enciende nunca**
(`GroupService.swift:1119` salta el member entero sin `sub`, y `:1145-1154` lo deja como está). En un 2º
device / reinstalación / restore la fuente 1 está **muerta de forma permanente**, no tarde.

#### ¿(A) resultó alcanzable? **SÍ.** Y el camino no es el que parecía

(A) = el `cloudKitUserRecordID` de mi fila legacy diverge del `cachedRecordName`, con `rejoinRevokedAt`
todavía `nil` ⇒ la fuente 2 devuelve una llave plausible pero equivocada.

La hipótesis razonable —«el cache y la fila mueren juntos, así que (A) no existe»— es **falsa**, y se cae
en dos líneas consecutivas. `performAccountSwitchCleanup` (`SplitSyncManager.swift:1398-1409`) llama:

1. `clearAllLocalGroupData()` (`:1406`), que **se auto-difiere** en la ventana export-only
   (`:1481-1484`, `deferMainContextWork` = `!autoSyncActive`) y retorna **antes** del único call-site de
   `GroupsIdentityPurgeGate.apply` (`:1497`) ⇒ **ni `rejoinRevokedAt` ni borrado de filas**;
2. `resetLocalGroupsSyncState()` (`:1407`), que **no tiene gate** y ejecuta
   `GroupUserIdentityService.clearCache()` (`:1466`) ⇒ identidad borrada en memoria **y** en `UserDefaults`.

El diferido es un `private var` **en memoria** (`:115`) drenado solo por `enableAutoSync()` (`:406`): si el
proceso muere antes de la promoción, la purga **no ocurre jamás** y no queda rastro. El arranque siguiente
re-siembra el cache con el Apple ID NUEVO (`AppBootstrapper.swift:442-445` → `seedIfNeeded`), y
`refreshCurrentUserFlags` **apaga** el `isCurrentUser` de la fila mientras el grupo aún no está marcado
como migrado (`:1155-1158`, `cloudKitMatch == false`); en cuanto el marcador aterriza, `:1145-1154`
congela ese `false` para siempre. Nadie lo corrige después: el boot-guard se **retira** con el flag ON
(`:264`) y con el flag OFF ya no tiene `cached` contra el que comparar (`:265-267`).

**Por qué la llave equivocada es peor que `nil`, dicho sin adornos.** No es solo que no matchee: el
`cachedRecordName` es el recordName del Apple ID que está **en este device ahora**, y `join_group`
rebindea por `member_key = X and user_id is null` sin preguntar de quién es esa fila. Si ese humano es
miembro del mismo grupo y aún no reclamó su placeholder —el handover de device dentro de un grupo—, el
re-join le entrega **su historial y permiso de editarlo**. Es exactamente lo que la revocación C-3 (D1)
existe para impedir, reabierto por el diferido. Por eso la rama 3 devuelve `nil` (residual §9.3b,
declarado) en vez de una llave que el censo de la zona no respalda.

**Medido con 5 lentes independientes + refutación por hallazgo (2026-07-30).** Tres refutadores no
pudieron tumbar este camino y verificaron las 36 citas una a una; los que sí refutaron alguna variante lo
hicieron por no recorrer la cadena entera (daban el cache por vacío, sin ver el re-seed del boot
siguiente). Refutados con datos: los caminos por el backfill heurístico + LWW de `CKRecordTranslator:304`
(mueren en `migrate_group`, que rechaza `member_key` duplicado y ≠1 owner) y los de las fronteras de wipe
(ahí las filas se borran **antes** del reset, el par está bien acoplado).

**Caveat de calendario, honesto:** hoy no existe cliente Swift de `migrate_group` (`5010db6a` borró el
uploader), así que ningún grupo puede llegar al estado servidor «migrado con placeholders `user_id NULL`»
desde esta app. Lo que ya está vivo es la **fabricación silenciosa de la divergencia** (los pasos locales).
Es el ⚠️ H2 de `SplitSyncManager.swift:259-263` con un agravante nuevo: el daño no lo causa el encendido
del flag, lo causa un estado que el encendido **encuentra ya escrito**.

#### Una cosa que queda REPORTADA, fuera de ámbito

> La grieta del diferido, que estaba aquí, se **CERRÓ el 2026-07-30** fuera de la Fase 3: era un bug de
> privacidad vivo en producción con el flag apagado. Se hicieron **las dos** cosas que este brief planteaba
> como alternativas, porque no eran alternativas sino mitades: el intent es durable
> (`GroupsIdentityPurgeIntent`, UserDefaults sin TTL, retomado en `AppBootstrapper` 16.4.4 tras la
> quiescencia) **y** el `clearCache()` se movió a la mitad que se difiere
> (`resetLocalGroupsSyncState(clearingIdentityCache:)`). El contrato quedó en
> `.claude/rules/swiftdata-cloudkit.md` y las celdas en `GroupsIdentityPurgeDurabilityTests`.

- **El `fetchLimit = 1` sin `sortBy` sobre un predicado que casa varias filas** era una moneda al aire
  (una zona migrada puede tener DOS filas marcadas del mismo humano: la legacy y la born-backend de un
  re-join que no rebindeó). Aquí queda cerrado; el patrón puede estar en otros fetches de members.

---

## Otros dos que exigen decisión, no ejecución

- **Borrar `GroupsIdentityPurgeGate` se lleva `.deleteLocalRows`** (`:201-252`), la mitad que BORRA ⇒
  tras la Fase 3 no queda purga automática ante cambio de Apple ID: regresión de `31dded30` para las
  filas CloudKit-era.
- **`isInviteLink` (`InviteLinkService:1637`) es el guard verdadero**, no el `:1733` que dice el plan; y
  si se conserva la condición `groupsBackendEnabled` de `:1705`, con el flag OFF `handleInviteLink` queda
  **mudo**.

---

## Partición correcta: TRES commits, no dos

El ciclo duro `SplitSyncManager` ↔ `SplitZoneManager` y las ~30 llamadas a `enqueueSave`/`enqueueDeletion`
en 3 ficheros supervivientes **prohíben subdividir el commit de producción**.

**Commit 0 — movimientos. ✅ HECHO: `bc486c92` (2026-07-29).**
`BootSaveGateLogic` + `WaitResolution` + `resolveWaitByQuiescence` → `Yala/App/Logic/BootSaveGateLogic.swift`
(169); su suite (9 celdas) → `YalaTests/BootSaveGateLogicTests.swift` (147); `zonePrefix` + `zoneName(for:)`
→ `enum SplitGroupZone` en `Yala/Models/SplitGroupZone.swift` (32), con el literal `"SplitGroup-"` intacto.
Build `Yala` + `Yala Dev` verdes sin warnings nuevos; **5.221 tests / 483 suites en verde**;
`validate-coverage.sh` → `RESULT: OK`. Cero cambios de comportamiento.

**Lo que cambió respecto a lo que decía este brief, medido al ejecutarlo:**

- **`SplitSyncStartGate.swift` adelgaza 292 → 149, no 292 → ~197.** Salen las tres piezas juntas (147
  líneas), porque `WaitResolution` y `resolveWaitByQuiescence` se llevan sus docblocks completos. El commit 1
  borra 149, no 292 ⇒ **el total de «ficheros enteros» baja de 4.498 a 4.355**.
- **`resolveWaitByQuiescence` tenía DOS callers de producción, no uno.** Además de `BootSaveGateLogic.decide`
  lo llama `SplitSyncManager.evaluateQuiescentPromotion` (`:630`), que muere en la Fase 3. Como el dueño
  tiene que ser el que sobrevive, la función quedó **dentro de `BootSaveGateLogic`** y ese callsite ahora
  dice `BootSaveGateLogic.resolveWaitByQuiescence` — se va con el fichero, sin trabajo extra para el commit 1.
- **`zoneName(for:)` SÍ tiene caller superviviente, pero es un TEST**, no producción:
  `GroupsIdentityPurgeGateTests` lo usa como control negativo de la derivación (`zona real ≠ derivada`).
  Se movió con `zonePrefix`. El **parser inverso `groupID(from:)` tiene 0 callers supervivientes** (todos en
  `SplitZoneManager`/`SplitSyncManager` y sus tests) ⇒ **se queda en `CKConstants`**, igual que
  `zoneID(for:)`, los dos apuntando ya al nuevo dueño. `CloudKitConstants.swift`: 150 → 149.
- **`CloudKitGroupsSchemaParityTests` NO se rompe con el movimiento.** Lee el fichero por ruta pero parsea
  solo los 5 enums de campos, y `zonePrefix` nunca fue uno de ellos. Lo único que quedó obsoleto es el
  comentario de `:74`, que usaba `zonePrefix` como ejemplo del fallo de parseo; corregido a una formulación
  genérica. El adelanto de este test al commit 2 sigue en pie: el fichero que lee muere ahí.
- ⚠️ **DEUDA para el commit 2, nueva. Y son 9 celdas, no 8** (verificado en la otra Mac el 2026-07-29):
  a las ocho `resolveByQuiescence_*` hay que sumar **`mirrorNotConfirmedOff_matrixUnchanged`**, cuyo nombre
  habla de la matriz del mirror pero que ejercita la función igual. Quien mueva «las 8» dejará ese caso
  atrás. En el fichero nuevo la función solo tiene HOY **una** llamada indirecta
  (`BootSaveGateLogicTests.swift:141`, comparando el gate de grupos contra el de boot-save), así que sin el
  rescate se queda prácticamente sin cobertura propia. Las **8 celdas de `resolveWaitByQuiescence`** más esa
  novena se quedaron en
  `SplitSyncStartGateTests.swift`, que el commit 2 borra, **aunque cubren código que sobrevive** (la función
  vive ahora en `BootSaveGateLogic`). Fuera del alcance del commit 0 —que movía la suite nombrada, no esa—
  pero si el commit 2 borra el fichero sin moverlas, `resolveWaitByQuiescence` se queda sin un solo test.
  Muévelas a `BootSaveGateLogicTests.swift`. El fichero mide hoy 263 líneas (395 − 132 del commit 0).
- **Índice de cobertura:** `Yala/Models/SplitGroupZone.swift` entra en `groups-cross-device-sync` (18 globs)
  y `Yala/App/Logic/BootSaveGateLogic.swift` en **`icloud-sync-multi-device`** (7 globs) — el gate de
  boot-saves pertenece al área que sobrevive, no a la del transporte. Los dos `lastVerified` a `2026-07-29`
  por drift de glob, no por re-verificación de sync.

**Commit 1 — producción, atómico e indivisible.** Los 13 ficheros ya vaciados de lo movido + los trims de
`GroupService`, `GroupExpenseService`, `GroupJoinReconciler`, `GroupJoinReconcileLogic`,
`AppBootstrapper`, `ContentView`, `AppRouter`, `YalaAppDelegate`, `GroupDetailViewModel`,
`GroupMembersView`, `GroupSettingsView`, `GroupsViewModel`, `GroupJoinIntentTracker`, `iCloudSyncService`,
`InviteLinkService`, `RouterIntent`, `SplitGroup` y **`DataWipeService`**.

**Commit 2 — tests y coverage.** Los 8 ficheros de test del transporte (1.681 menos las **132** movidas en
el commit 0) **+ las 8 celdas de `resolveWaitByQuiescence` que hay que RESCATAR de
`SplitSyncStartGateTests.swift` antes de borrarlo** (ver la deuda del commit 0) + **`CloudKitGroupsSchemaParityTests.swift` (157), adelantado de la Fase 4** porque lee
`CloudKitConstants.swift` por RUTA y el fichero muere aquí + las **5 áreas** de `qa/coverage-index.json`
+ `_meta.counts`.

### Trampas del índice de cobertura

- La Fase 1 **no** redujo el área del transporte: redujo `groups-backend-g6-migration` (26→8 globs).
  `groups-cross-device-sync` (`manual`) tiene **18 globs** tras `bc486c92` (entró `SplitGroupZone.swift`),
  9 de los cuales sobreviven.
- **`groups-icloud-availability-gate` (JSON `965-976`) pierde sus 2 únicos globs, y `codeGlobs` vacío es
  error DURO** (`validate-coverage.py:61`) ⇒ hay que **borrar el área** y bajar `_meta.counts` a
  `total 133 / manual 57`. Los globs sin match son solo WARN, y **`counts` no lo valida nadie**.
- ~~El índice cita `unit:YalaTests/BootSaveGateLogicTests` escondida en `SplitSyncStartGateTests.swift`~~ —
  **RESUELTO en `bc486c92`**: la suite tiene su fichero y la cita es literal. La cita vive en DOS áreas
  (`groups-cross-device-sync` y `icloud-sync-multi-device`); la segunda es la dueña del gate y sobrevive.
- El criterio de salida `grep -r "import CloudKit"` del plan **no escanea `App/Logic/`**, donde
  sobreviven `GroupJoinReconcileLogic.swift:15` y `GroupAcceptShareErrorLogic.swift:23` — ninguno en las
  listas del plan.

---

## Reportado y SIN dueño — lo que se pierde al morir el proceso

Salieron de clasificar los diez diferidos de `SplitSyncManager` al arreglar la grieta de la purga
(`7c7fb7f6`). **Ninguno depende del flag ni de la Fase 3: fallan hoy.** No estaban escritos en ningún
sitio hasta el 2026-07-30.

- ~~**El bridge remoto de Grupos se pierde para siempre.**~~ **ARREGLADO el 2026-07-30, en los DOS canales.**
  `GroupsPendingBridgeIntent` (UserDefaults, sin TTL, tope de 3 intentos por ID) lo arman el transporte
  CloudKit (`SplitSyncManager.notePendingBridge`) y el canal backend
  (`GroupsSyncClient.applyPulledPage` → `armBridgeIntent`, **no** `scheduleBridge`), y
  lo retoma `GroupsPendingBridgeResume.resumeIfNeeded(context:)` dentro de
  `AppBootstrapper.retryPendingBridges`, detrás de sus dos gates. Al medirlo apareció una segunda mitad que
  el reporte no tenía: el drenaje limpiaba los Sets **antes** de llamar al bridge, así que las cuatro
  superficies de throw de `bridgeRemoteExpenses` —y su `catch` por gasto— perdían el lote **con la app
  viva**; por eso `bridgeRemote*` devuelven ahora los IDs realmente puenteados y el desarme es por ID
  cumplido. Contrato en `.claude/rules/swiftdata-cloudkit.md`.

  ~~**Y su gemelo en el canal backend, que el fix del 2026-07-30 dejó fuera de ámbito.**~~ **CERRADO el
  mismo día**, que es lo que D-R1 ponía como condición del flip («su fix tiene que cubrir los dos canales,
  no solo el viejo»). Dos cosas que el reporte del gemelo no tenía y que solo aparecen al cablearlo:
  **(a) «armar donde se acumula» NO basta aquí.** `GroupsSyncClient.scheduleBridge` abre con
  `guard !expenseIDs.isEmpty || !settlementIDs.isEmpty, GroupTransactionBridge.shared.isReady else { return }`,
  y ese `return` es anterior a toda acumulación: con el bridge aún sin `ModelContext` los IDs se tiraban ahí
  mismo, sin rastro. **El `arm` acabó en `applyPulledPage` y no «antes del guard»**, que es lo que pedía la
  formulación fácil: desde ahí cubre CUATRO caminos en vez de uno —el `guard` de `isReady`, la quiescencia
  diferida, el `catch` del save de la página y la ventana de `drainSoftDeleteFreeze`, que hace su propio
  `save()` del store personal sin gate—. Quien lo busque en `scheduleBridge` no lo va a encontrar. El otro
  camino, el que sí espeja al canal viejo, es la
  quiescencia: difiere a `scheduleBridgeRetry`, un `Task` con `sleep` en memoria que además **se cancela en
  cuanto otro lote entra en la ventana** (el canal viejo no lo sufre porque sus IDs viven en Sets
  acumulativos; aquí viajan capturados en el closure). Y perder ahí es igual de permanente que en CloudKit:
  `applyPulledPage` persiste `groupCursorsJSON` en el MISMO `saveWithAuthor` que inserta las filas, así que
  el servidor no re-emite el delta.
  **(b) El retome habría descartado ENTERO lo que arma el canal nuevo.** Clasificaba como *abandonado* todo
  ID cuya zona fuese de un grupo `isBackendGroup` —correcto para lo que armó CloudKit—, y
  `GroupsSyncClient.applyGroupMeta` enciende ese flag en **todos** sus grupos. Por eso el intent persiste
  ahora el `Channel` de cada ID (campos opcionales en el decode ⇒ un payload viejo se lee como «todo
  CloudKit»). Verificado por mutación: neutralizar el `arm` del canal nuevo ⇒ exit 65 con 4 celdas rojas;
  sano, exit 0.

- **El retome del intent YA NO vive en `SplitSyncManager.swift`, y eso cambia lo que el commit 1 puede
  borrar.** Estaba en `:2014-2139` — dentro de uno de los 13 ficheros que el commit 1 borra ENTEROS—, así
  que tras la Fase 3 el intent se habría seguido armando (el canal backend le sobrevive) sin nadie que lo
  drenara: el patrón exacto de `quotaFailedRecordIDs`, y **peor que no tener intent**, porque habría IDs
  acumulándose en `UserDefaults` sin salida. Mudado a **`Yala/Services/Groups/GroupsPendingBridgeResume.swift`**
  (mismo trabajo y misma razón que el commit 0, `bc486c92`), sin `import CloudKit` ⇒ respeta el criterio de
  salida. Lo que queda en el transporte es `SplitSyncManager.forgetBridged(expenseIDs:settlementIDs:)`, el
  olvido del camino rápido en memoria: **al commit 1 le basta con borrar el argumento `onBridged` del
  call-site de `AppBootstrapper.retryPendingBridges` — una línea— y el retome sigue en pie.**
- ~~**`applyPulledPage` no hace `context.rollback()` cuando su save falla, y su mirror declarado SÍ.**~~
  **ARREGLADO el 2026-07-30**, antes del flip y por la misma razón que el bridge: el paso 2 es lo que
  enciende este camino, y encenderlo dejaba datos nuevos encima de un agujero conocido. `GroupsSyncClient.
  applyPulledPage` se declara «mirror de `SyncApplyEngine.applyPage`, A1» pero copió el `return false` sin el
  `context.rollback()` que el comentario de la original llama **obligatorio** — y **los dos corren sobre el
  MISMO `mainContext` compartido**, así que no había ninguna diferencia de contexto que lo justificara:
  `AppBootstrapper` pasa el mismo `context` a `CloudSyncRuntime.startShared` (`:311`) y a
  `GroupsSyncClient.startIfEligible` (`:329`). El daño no era perder el bridge: si un save ajeno flusheaba
  esas filas bajo el autor por defecto, el drain las capturaba (filtra por
  `tx.author != Self.outboxSaveAuthor`) y las **re-empujaba al servidor como ediciones locales con HLC
  fresco** — laundering del grafo remoto a medias. Con el rollback el cursor tampoco avanza ⇒ el próximo pull
  re-pide la página, idempotente. El `arm` del `catch` se conserva como red REDUNDANTE (revertidas las filas,
  el retome las clasifica *abandonado* y las retira sin gastar presupuesto). Pinneado por
  `GroupsSyncClientTests.apply_saveFails_rollsBack_andCursorDoesNotAdvance` con el seam
  `_testThrowOnApplySave` (molde del canal personal); mutación verificada: quitar el `rollback()` deja DOS
  aserciones rojas — contexto sucio Y cursor avanzado.
- **`quotaFailedRecordIDs` es una intención sin drenador.** `retryQuotaFailedRecords()`
  (`SplitSyncManager.swift:1616`) **no tiene ni un call-site en la app** — su única otra mención es el
  comentario de `:1480`, que afirma que corre en foreground. Verificado con grep el 2026-07-30. Si la cuota
  de CloudKit falla, esos records no se reintentan jamás y nadie se entera.
- **La ventana export-only y el EVENTO ENTERO — VEREDICTO MEDIDO (2026-07-30), y resuelve la discrepancia
  entre dos sesiones.** Dos informes se contradecían: el de la purga decía «inalcanzables hoy, no hay
  auto-fetch en export-only»; el del bridge los dejaba como pendientes con el agravante de que se pierde la
  FILA, no solo su bridge. **Los dos aciertan en una mitad y fallan en la otra, y por eso parecían
  incompatibles.**

  **Alcanzabilidad HOY: NO.** Los dos `append` solo corren dentro de `handleFetchedDatabaseChanges`
  (`SplitSyncManager.swift:1303-1305`) y `handleFetchedRecordZoneChanges` (`:1669-1671`), a los que solo
  llega un evento `fetched*` nacido de una operación de fetch del engine. En todo `Yala/` hay **cuatro**
  llamadas a `fetchChanges()`, en tres sitios, y las tres están gateadas por `autoSyncActive`: las dos de
  `enableAutoSync` (`:437`/`:439`) corren DESPUÉS de `autoSyncActive = true` (`:374`, síncrono en el mismo
  actor ⇒ no hay ventana intermedia); la de `acceptShare` (`:813`) está dentro de `if autoSyncActive, let
  sharedEngine` —la pista del owner se confirma **sin excepciones**: no hay otra llamada a fetch en esa
  función ni en su `catch`, y `container.accept(metadata)` es una operación de contenedor, no del engine—;
  y la de `fetchEngineChanges` (`:1002`) solo la alcanza `syncNow`, cuyas DOS ramas gatean
  (`awaitReadyForForcedFetch` espera a la promoción y devuelve `false` al expirar, `:983-997`; la rama
  no-forzada hace `guard autoSyncActive else { return }`, `:950-953`). Los `sendChanges` manuales que sí
  ocurren en export-only (`createShare`, `SplitZoneManager.swift:161`) no tienen camino a un evento
  `fetched*`: el SDK separa la vía de envío (eventos `sent*`) de la de fetch. Y los push de CloudKit van al
  canal interno del engine (`YalaAppDelegate.swift:60-64`), que con `automaticallySync = false` no programa
  sync.

  **Gravedad SI alguien lo alcanza: la que decía el segundo informe, y peor de lo que suena.** El
  `.stateUpdate` se persiste en el delegate **sin pasar por ningún gate**, y Apple documenta que ese estado
  se guarda junto a los cambios fetcheados antes de recibirlo ⇒ el token avanza aunque el handler haya
  diferido, y el record **nunca se aplicó**. Morir antes de `drainDeferredFetchEvents()` pierde **la fila**:
  el gasto no aparecería ni dentro de Grupos. Cubrirlo exige persistir CKRecords serializados, no UUIDs —
  es otra pieza, y no hay un solo test que impida que alguien abra el camino.

  **¿Cambia con el flip? NO.** El mecanismo que llena los buffers es byte-idéntico con el flag ON:
  `SplitSyncManager.initialize()` no lo lee (`AppBootstrapper.swift:320` gatea solo por `uiTestActive` y la
  sesión secundaria), `SplitSyncStartGate.decideStart` decide con tres señales de iCloud y ninguna es el
  flag, y `shouldDeferDelegateSave(autoSyncActive:)` sigue siendo `!autoSyncActive`. No aparece ningún
  camino nuevo de fetch: el canal backend nunca llama al manager, el link de invitación backend DESVÍA en
  vez de añadir, y la migración G6 ya no existe en el cliente (0 llamadas a `migrate_group` en `Yala/`, la
  mató la Fase 1). **La población afectada tampoco se encoge**: con el flag ON el canal CloudKit sigue
  siendo el único que trae las filas de los grupos NO migrados (el guard G6-3 solo filtra
  `isBackendGroup == true`), así que un evento perdido ahí seguiría perdiendo la fila igual que hoy.
  Dos efectos de segundo orden, ambos en el DRAIN y no en el llenado, quedan anotados por si alguien
  reabre esto: (a) con el flag ON `backendGroupZoneNames` deja de ser siempre-vacío, así que un evento
  bufferado de una zona que voltee a backend durante la ventana se descartaría al drenar con el token ya
  avanzado —y el rescate C-4 PIEZA 2 **no existe en esta rama** (verificado: 0 referencias a
  `GroupPullRescueGate`, lo borró la Fase 1)—; (b) el boot-guard de identidad se retira con el flag ON
  (`:278`), lo que hace MENOS alcanzable el `deferredClearAllRequested` que nuquea los buffers en el drain.

  ⇒ **No bloquea el paso 2.** Sigue sin dueño, con la clasificación corregida: *inalcanzable hoy y tras el
  flip, catastrófico si alguien lo alcanza, sin ningún test que lo impida.*

## Dos cosas ya muertas hoy (limpieza gratis, sin relación con la Fase 3)

- `GroupUserIdentityService.swift:70-73` — `deterministicMemberID(groupZoneID:)`, **0 callsites**.
- `MetricsService.swift:37` — `cloudkitBudgetCSVMirrorRebuilt`, **0 emisores** en todo el repo.
