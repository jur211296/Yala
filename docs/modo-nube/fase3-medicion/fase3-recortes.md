# Fase 3 · Bloque RECORTES — medición contra HEAD `ca06cfd5` (branch 2.0.5)

Todas las cifras salen de medición propia sobre HEAD. Ficheros de referencia:

| Fichero | Líneas HEAD | Plan | Δ |
|---|---|---|---|
| `Yala/Services/Groups/GroupService.swift` | **1534** | (no cifrado) | — |
| `Yala/Services/Groups/SplitSyncManager.swift` | **2521** | 2.905 ✅ | **−384** |
| `Yala/Services/Groups/SplitZoneManager.swift` | 308 | 308 ✅ | 0 ✓ |
| `Yala/App/Logic/GroupsIdentityPurgeGate.swift` | 253 | 263 | −10 |
| `Yala/Services/Groups/CKRecordTranslator.swift` | 437 | 437 | 0 ✓ |
| `Yala/App/Logic/SplitSyncStartGate.swift` | 292 | 292 | 0 ✓ |
| `Yala/App/Services/CKShareEntryHandler.swift` | 151 | 151 | 0 ✓ |
| `Yala/Services/Groups/CloudKitConstants.swift` | 150 | 150 | 0 ✓ |
| `Yala/Services/Groups/GroupUserIdentityService.swift` | 88 | 88 | 0 ✓ |

---

## (a) `GroupService.propagateBoolCustomKey` — las 5 coordenadas del plan están mal

El plan (`MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS.md:272`) dice, con ✅ de verificado:
`propagateBoolCustomKey` (**`:236`** ✅) con sus **4** callsites ✅ (`GroupService:228`, `:308`,
`SplitSyncManager:2320`, `:2326`).

| Coordenada del plan | Real en HEAD | Δ |
|---|---|---|
| función `:236` ✅ | `GroupService.swift:246` (doc desde `:242`) | **+10** |
| callsite `GroupService:228` | `GroupService.swift:238` (dentro de `setArchived`) | **+10** |
| callsite `GroupService:308` | `GroupService.swift:318` (dentro de `softDelete`) | **+10** |
| callsite `SplitSyncManager:2320` | `SplitSyncManager.swift:2033` | **−287** |
| callsite `SplitSyncManager:2326` | `SplitSyncManager.swift:2039` | **−287** |

Los tres de `GroupService` están desplazados exactamente **+10** (algo creció 10 líneas antes de `:228`);
los dos de `SplitSyncManager` **−287**, coherente con que el fichero adelgazó 384 líneas en la Fase 1/2.
Las marcas ✅ del plan **no son fiables**: `:236`, `:228`, `:308` y las 2.905 líneas venían marcadas y las
cuatro están mal.

**Corrección semántica, no solo de línea: no son 4 recortes, son 2.**
`SplitSyncManager.swift:2033` y `:2039` viven dentro de `handleConflict`
(`SplitSyncManager.swift:1941`), que el **mismo commit borra con el fichero entero** ⇒ se van gratis.
Recortes de verdad: `GroupService.swift:238` y `:318`.

```
GroupService.swift:246   static func propagateBoolCustomKey(zoneID: String, key: String, value: Bool) async {
GroupService.swift:249       let database = CKContainer(identifier: CKConstants.containerID).privateCloudDatabase
GroupService.swift:254       _ = try await database.modifyRecords(saving: [share], deleting: [])
```

### La afirmación «único write a `privateCloudDatabase` que no pasa por `CKSyncEngine`»

`grep -rn privateCloudDatabase Yala/` → **5 hits, ninguno en tests**:

| Hit | Qué es | ¿Write directo? |
|---|---|---|
| `GroupService.swift:249` | container PROPIO → `modifyRecords(saving:[share])` en `:254` | **SÍ** |
| `iCloudSyncService.swift:532` | `allRecordZones()` | no — es LECTURA |
| `SplitSyncManager.swift:329` | `makeEngine(database:)` | no — la DB se entrega al engine |
| `SplitSyncManager.swift:375` | `makeEngine(...)` (recreación) | no |
| `SplitSyncManager.swift:1434` | `makeEngine(...)` | no |

**Literalmente cierta, semánticamente engañosa.** Hay otros dos writes directos a CloudKit que NO pasan por
la cola del engine, solo que no nombran el token `privateCloudDatabase`:

- `SplitZoneManager.swift:154` `let database = engine.database` → `:194` `CKModifyRecordsOperation(recordsToSave:[share])` → `:206` `database.add(modifyOperation)`. Es la **misma** private database, obtenida prestada del engine.
- `SplitZoneManager.swift:239–257` `container.sharedCloudDatabase.deleteRecord(...)` (`leaveShareByZone`).
- Por contraste `createZone`/`deleteZone` (`SplitZoneManager.swift:26`/`:58`) **sí** pasan por el engine (`engine.state.add(pendingDatabaseChanges:)`).

Lo que hace único a `propagateBoolCustomKey` no es «no pasa por CKSyncEngine» sino **que no toca el engine
en absoluto**: construye su propio `CKContainer` en `:249`. Eso es precisamente lo que lo vuelve peligroso
(ver Riesgo 1).

### Dependencias del recorte

- `CKShareCustomKey` (`:238`, `:318`) está definido en **`Yala/App/Models/RouterIntent.swift:22`**, NO en `CloudKitConstants.swift`. Es un enum de `String` puros (no necesita CloudKit). Sus únicos usos son los 4 callsites de `propagateBoolCustomKey` + `CKShareEntryHandler.swift:58–59` (borrado entero) ⇒ tras la Fase 3 queda **enum huérfano con 0 usos**, y el plan no lo nombra.
- `CKRecordNameZoneWideShare` (`:248`) es símbolo del **SDK de CloudKit** (0 definiciones en `Yala/`). Es la razón por la que `import CloudKit` sigue siendo necesario en `GroupService.swift:9` — y por tanto la razón por la que el criterio de salida del plan detectaría el olvido.

---

## (b) Callsites de `enqueueSave` fuera de `SplitSyncManager.swift` — **25 llamadas** (medición exacta)

| Fichero | Líneas | n |
|---|---|---|
| `Yala/Services/Groups/GroupService.swift` | 127, 188, 213, **235**, **301**, 403, 454, 508, 541, 574, 875, 897, 934, 986, 1083, 1094, 1133, 1177 | **18** |
| `Yala/Services/Groups/GroupExpenseService.swift` | 109, 119, 194, 204, 429, 468 | **6** |
| `Yala/Services/Groups/GroupJoinReconciler.swift` | 253 | **1** |

(`235` y `301` son los que acompañan a los `Task` de `propagateBoolCustomKey`.)

**Menciones en comentario que hay que reescribir, no borrar** (9 en producción + 3 en tests):
`GroupService.swift:231, 411, 423, 465, 961, 1167` · `GroupJoinReconciler.swift:101` ·
`GroupJoinReconcileLogic.swift:132` · `GroupsSyncBreadcrumb.swift:135` ·
`YalaTests/CloudSync/GroupChannelRoutingTests.swift:9` · `YalaTests/GroupsIdentityPurgeGateTests.swift:414` ·
`YalaTests/CloudSync/GroupsSyncClientTests.swift:559`. **Ninguna llamada real en los tests.**

### El plan solo nombra `enqueueSave`. La superficie externa real de `SplitSyncManager` es de 13 símbolos

`grep -rn "SplitSyncManager\." Yala/ | grep -v SplitSyncManager.swift`, agregado:

| Símbolo | n | Fichero:línea |
|---|---|---|
| `shared.enqueueSave` | 25 | (tabla arriba) |
| `shared.enqueueDeletion` | **4** | `GroupExpenseService.swift:169, 256, 270, 501` |
| `shared.syncNow` | 3 | `AppBootstrapper.swift:1274` · `GroupDetailViewModel.swift:135` · `GroupsViewModel.swift:203` |
| `shared.acceptShare` | 3 | `ContentView.swift:1692` · `CKShareEntryHandler.swift:94` (fichero entero) · `GroupJoinIntentTracker.swift:133` |
| `shared.setContext` / `shared.initialize` | 2 | `AppBootstrapper.swift:316, 317` |
| `shared.syncStatus` / `.SyncStatus` | 2 | `iCloudSyncService.swift:112, 113` |
| `shared.resetLocalGroupsSyncState` | 1 | `DataWipeService.swift:270` |
| `shared.sendPendingChanges` | 1 | `GroupService.swift:580` |
| `shared.hasEngine` | 1 | `GroupJoinReconciler.swift:71` |

⇒ **`enqueueDeletion` (4) falta en la lista del plan** y es el par exacto de `enqueueSave`. Total de líneas
de callsite externo: **41** (25 + 4 + 12; se descuenta `CKShareEntryHandler.swift:94`, que muere con su fichero).

**Bonus no listado en el plan:** `Yala/App/Logic/GroupJoinReconcileLogic.swift` (161 líneas) contiene en
`:130–160` el oráculo `EnqueuePlan`/`enqueuePlan` — «proyección testeable de lo que `enqueueSave` encolará»,
con `CKCurrentUserDefaultName`, `CKRecordZone.ID` y `CKConstants.recordID`. Muere con el transporte (**31
líneas + el `import CloudKit` de `:15`**) y el fichero no está en ninguna lista de la Fase 3.

---

## (c) Lo que queda de CloudKit puro en `GroupService.swift`

`grep -nE "CKRecord|CKShare|cloudKitZoneID|privateCloudDatabase|import CloudKit|CKContainer|CKConstants|SplitSyncManager|CKCurrentUserDefaultName|ckSystemFields"` → **71 líneas**. Pero el grep miente por un motivo importante:

> ⚠️ **`cloudKitZoneID` NO es CloudKit — es el `groupID` del canal BACKEND.** Los RPC del canal nuevo lo pasan
> como identificador de grupo: `GroupService.swift:417`, `:473`, `:556`, `:765`, `:782`, `:788`
> (`backendMembershipFactory().remove/approve/leave/transferOwnership(groupID: group.cloudKitZoneID)`).
> Es el nombre desafortunado de la clave primaria del dominio. **No se puede borrar en la Fase 3 ni renombrar
> a la ligera** (aparece en 30+ líneas de este fichero y en los `#Predicate` de `group(for:)`,
> `currentUserMember(zoneID:)`, `accountDeletionGroupsSummary`).

### C.1 — Recortes EXACTOS (rango de borrado inequívoco)

| # | Bloque | Rango | Líneas |
|---|---|---|---|
| R1 | doc de cabecera («Creates CKRecordZones via SplitZoneManager…») | `:6` | 1 |
| R2 | `import CloudKit` | `:9` | 1 |
| R3 | `setArchived`: comentario 2-canales + `enqueueSave` + `zoneID` + `Task` | `:231–239` | 9 |
| R4 | `propagateBoolCustomKey` + su doc | `:242–260` | 19 |
| R5 | `softDelete`: comentario + `enqueueSave` | `:298–301` | 4 |
| R6 | `softDelete`: `zoneID` + `Task` | `:316–319` | 4 |
| R7 | `deleteGroup`: comentario + `SplitZoneManager…deleteZone` | `:344–345` | 2 |
| R8 | `leaveGroup`: `sendPendingChanges` | `:580` | 1 |
| R9 | `leaveGroup`: bloque `leaveShare` + `PendingLeaveShareTracker` | `:583–594` | 12 |
| R10 | `performRemovedSelfCleanup`: captura `ownerName` | `:623–624` | 2 |
| R11 | `performRemovedSelfCleanup`: bloque `leaveShareByZone` + tracker | `:636–648` | 13 |
| R12 | doc `:1317` («Vienen de `SplitSyncManager`, que la Fase 3 borra entero») | `:1317` | 1 |
| R13 | los 16 `enqueueSave` restantes del fichero | 127,188,213,403,454,508,541,574,875,897,934,986,1083,1094,1133,1177 | 16 |
| | | **subtotal** | **85** |

Fuera de `GroupService.swift`, exacto: **54** líneas
(`GroupExpenseService` 10 · `GroupJoinReconciler` 2 · `AppBootstrapper` 3 · `ContentView` 1 ·
`GroupDetailViewModel` 1 · `GroupsViewModel` 1 · `iCloudSyncService` 2 · `DataWipeService` 1 ·
`GroupJoinIntentTracker` 1 · `GroupJoinReconcileLogic` 32).

**TOTAL EXACTO = 139 líneas.**

### C.2 — Muertes de función / rama (ESTIMACIÓN: dependen de una decisión de producto, no de mecánica)

| Bloque | Rango | Líneas | Por qué muere | Confianza |
|---|---|---|---|---|
| `createGroup` | `:80–142` | **63** | es la rama `.cloudKit` de `GroupCreateRoutingLogic` (`GroupFormView.swift:277–288`); la `.backend` es `GroupBackendMembershipService.createGroup` (`GroupFormView.swift:293`). Sin canal CloudKit el `switch` colapsa | alta (±15 con el arm del switch) |
| `ensureCurrentUserMemberExists` | `:840–938` | **99** | identidad 100 % CloudKit (`:845 currentUserRecordName()`); **PROHIBIDA para el canal backend** (regla A1, `GroupJoinReconciler.swift:101`). Callsites vivos: `ContentView.swift:1676`, `GroupJoinReconciler.swift:206` — ambos del accept-share CloudKit | alta (±20) |
| `leaveGroup` rama CloudKit + des-anidar el guard `routesMembershipToBackend` | `:555–581` | **~20** | tras la Fase 3 el `if` de `:555` es el único camino | media (±8) |
| `refreshCurrentUserFlags` | `:1002–1190` (189) | **~120** | resolución de recordName `:1013–1028`, métricas de duplicados `:1033–1044`, backfill legacy `:1054–1097`, backfill in-loop `:1121–1136`, cascada `cloudKitMatch` `:1138–1159`, inferencia `isGroupOwner` `:1165–1179`. Sobrevive solo la rama por `sub` | **baja (±30)** — es el bloque más entrelazado del recorte |
| `updateCurrentUserDisplayName`: métricas de duplicados de sync | `:958–976` | **~19** | `MetricsService.cloudkitDuplicateDetected` sin sync que produzca duplicados | media (±10) |
| | | **~321** | | |

**Sobrevive, contra lo que sugiere el grep:**
- `performRemovedSelfCleanup` (`:611–649`) **no** muere entera: pierde R10+R11 pero conserva su otro trigger vivo, la red de boot `AppBootstrapper.swift:1150` (`freezeOrphanedGroupsAndRemovedSelves`). El otro trigger, `SplitSyncManager.swift:1715`, sí muere.
- `hasLegacyCloudKitFootprint` (`:1380–1382`, `:1395` `groups.contains { $0.ckSystemFieldsData != nil }`) **se queda**: `ckSystemFieldsData` no está ni en la lista de la Fase 3 ni en la de la Fase 4, y es la señal del aviso GDPR de «Eliminar mi cuenta». Vive además en `GroupFreezeLogic.swift:22,35`, `GroupSettingsView.swift:102,662`, `SplitSyncStartGate.swift:134,147` y en los 5 modelos `Split*`.
- Toda la sección `:1315–1454` (`group(for:)`, `currentUserMember`, `currentMemberStatus`, `accountDeletionGroupsSummary`, `mostRecentGroup`) se conserva — es exactamente lo que la Fase 2 §2.4 extrajo para sobrevivir. Solo hay que actualizar el comentario `:1317`.

### C.3 — Total del bloque de recortes

| | Líneas | Naturaleza |
|---|---|---|
| Exacto (C.1) | **139** | medido, rango inequívoco |
| Estimado (C.2) | **~321** (rango 260–390) | muerte de función/rama, sujeta a decisión |
| **TOTAL** | **~460** (rango **400–530**) | **30 % medición exacta, 70 % estimación** |

Para calibrar: `GroupService.swift` pasaría de **1534 → ~1075 líneas**.

---

## Riesgos, ordenados

### 🔴 1 — Los 2 recortes que quedan son justo los que el compilador NO delata

`propagateBoolCustomKey` **no referencia el engine**: se construye su propio `CKContainer` en `:249`.
Borrar `SplitSyncManager.swift` + `SplitZoneManager.swift` la deja compilando perfecta, y sus dos callsites
vivos están dentro de `Task { … }` en `setArchived`/`softDelete` — tampoco rompen. De los 4 callsites del
plan, los 2 que el compilador señalaría (`SplitSyncManager:2033/:2039`) se van gratis con el fichero, y los
2 que exigen trabajo manual son **invisibles al build**.

Si se olvidan: al archivar o borrar un grupo la app sigue abriendo una conexión a `privateCloudDatabase` de
un container cuyo schema la Fase 4 retira, contra una zona que ya no existe. El fallo es **mudo por diseño**
— el `catch` de `:255–259` solo hace `print` bajo `#if DEBUG`, sin breadcrumb ni canario. El usuario ve
«archivado» y nada más.

Única red: el criterio de salida `grep -r "import CloudKit" Yala/Services/Groups/` → 0, que funciona **solo**
porque `CKRecordNameZoneWideShare` (`:248`) es un símbolo del SDK. Si alguien lo sustituye por un literal
mientras limpia, el grep da 0 con el código vivo. **Recomendación: borrar R4 en el primer hunk del commit 1,
antes de tocar cualquier fichero entero, y verificar los 2 callsites a mano.**

### 🟠 2 — El criterio de salida del plan no cubre los directorios donde queda CloudKit

El plan valida `grep -r "import CloudKit" Yala/Services/Groups/ Yala/App/Views/Groups/` → 0. Inventario real
de `import CloudKit` en HEAD (12 hits):

| Fichero | ¿En la lista de borrado del plan? | ¿Lo ve el grep del criterio? |
|---|---|---|
| `Yala/Services/Groups/{SplitSyncManager,CKRecordTranslator,CloudKitConstants,SplitZoneManager,GroupUserIdentityService}.swift` | sí | sí |
| `Yala/Services/Groups/InviteLinkService.swift` | recorte parcial | sí |
| `Yala/Services/Groups/GroupService.swift:9` | recorte (R2) | sí |
| `Yala/App/Views/Groups/GroupInviteOnboardingView.swift:13` | **NO** | **sí → el criterio FALLARÁ** |
| `Yala/App/Services/CKShareEntryHandler.swift:13` | sí | **no** (dir fuera de scope) |
| `Yala/App/Logic/SplitSyncStartGate.swift:19` | sí | **no** |
| `Yala/App/Logic/GroupJoinReconcileLogic.swift:15` | **NO** | **no** → sobrevive con `CKRecordZone.ID`/`CKCurrentUserDefaultName` en `:148–153` |
| `Yala/App/Logic/GroupAcceptShareErrorLogic.swift:23` | **NO** | **no** → `CKError.Code` en la firma de `:42` |

⇒ el criterio da un **falso verde** para `App/Logic/` y un **falso rojo** por `GroupInviteOnboardingView`.
Ampliarlo a `Yala/App/Logic/ Yala/App/Services/ Yala/App/Models/` antes de usarlo como puerta.

### 🟡 3 — La regla G6-3 del orden del changeset: coordenadas VÁLIDAS

`.claude/rules/swiftdata-cloudkit.md` pide verificar ese orden antes de borrar el emisor del transporte.
**Verificado contra HEAD, las cuatro exactas** (a diferencia del plan):

```
SplitSyncManager.swift:1562   let backendZoneNames = backendGroupZoneNames(context: modelContext)
SplitSyncManager.swift:1610   if backendZoneNames.contains(record.recordID.zoneID.zoneName) {      // descarte records
SplitSyncManager.swift:1672   if backendZoneNames.contains(deletion.recordID.zoneID.zoneName) {    // descarte deletions
SplitSyncManager.swift:1723   pendingBridgeChangeSet.newExpenses.append(contentsOf: ...)           // relleno changeset
```

Los cuatro viven dentro del fichero que se borra entero ⇒ la duplicación de avisos se resuelve por
construcción, **siempre que el emisor del canal backend ya emita**. No es riesgo del bloque de recortes.

### 🟡 4 — `ensureCurrentUserMemberExists` vs «conservar `deterministicUUID` y `cachedRecordName`»

El plan conserva de `GroupUserIdentityService.swift` (88 líneas) solo esos dos símbolos. Pero
`currentUserRecordName()` (`:27`) tiene **4 callsites vivos**: `GroupService.swift:95` (`createGroup`),
`:845` (`ensureCurrentUserMemberExists`), `:1023` (`refreshCurrentUserFlags`) y
`AppBootstrapper.swift:440`. Los tres primeros son las tres muertes estimadas de C.2 — o sea, el recorte de
`GroupUserIdentityService` y las tres funciones de `GroupService` **tienen que caer en el mismo commit** o el
build rompe. Aquí el compilador sí ayuda; solo hay que no partirlo en dos.

### 🟡 5 — Huérfanos silenciosos que quedan tras el recorte

- `CKShareCustomKey` (`RouterIntent.swift:22`): 0 usos tras la Fase 3, enum vivo. No listado.
- `PendingLeaveShareTracker` (68 líneas, en la lista) — sus 3 callsites son R9, R11 y el retry de boot `AppBootstrapper.swift:1159+`. Ese retry de boot **no** está listado como recorte.
- `GroupFormView.swift:271–288`: el `switch GroupCreateRoutingLogic.route(...)` se queda con un solo `case`; `GroupCreateRoutingLogic` (`Yala/App/Logic/`) no está en ninguna lista.
