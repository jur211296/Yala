# Fase 3 · Bloque ACOPLAMIENTOS — medición contra HEAD `ca06cfd5`

Todas las cifras y coordenadas de este documento salen de medición directa contra el árbol de trabajo en
`ca06cfd5`. Donde el plan (`$VAULT/Backlog/modo-nube/MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS.md`, §Fase 3,
líneas 258-289) da un número o una línea, se compara. **No se editó ningún fichero del repo.**

---

## §0 · Corrección de las coordenadas del plan

| Coordenada del plan | Valor en el plan | Valor real en HEAD | Veredicto |
|---|---|---|---|
| `SplitSyncManager.swift` | **2.905** (marcado ✅ verificado) | **2.521** | **MAL, −384.** El ✅ es de antes de `632c951f` («las consultas del store de Grupos viven en `GroupService`») |
| `GroupsIdentityPurgeGate.swift` | 263 | **253** | MAL, −10 |
| `GroupService.propagateBoolCustomKey` | **`:236`** (✅) | **`:246`** | MAL, +10 |
| sus **4** callsites (✅) | `GroupService:228`, `:308`, `SplitSyncManager:2320`, `:2326` | `GroupService.swift:238`, `:318`, `SplitSyncManager.swift:2033`, `:2039` | **los 4 MAL** (los de SplitSyncManager, ~290 líneas desplazados) |
| «10 ficheros de test del transporte (~2.042)» | 10 / 2.042 | **8 ficheros / 1.681 líneas** | MAL. No existen `SplitZoneManagerTests`, `CKShareEntryHandlerTests`, `CloudKitConstantsTests`, `GroupUserIdentityServiceTests`, `PendingLeaveShareTrackerTests` (verificado con `find`). Aparece uno que el plan no lista: `YalaTests/CKRecordTranslatorSanitizeTests.swift` (76) |
| `SplitZoneManager.swift` / `deleteZone` en `:58` | 308 / `:58` (✅) | 308 / `:58` | **OK** |
| `GroupsICloudUnavailableView` + `GroupsICloudAvailabilityGateLogic` | 94 | 61 + 33 = 94 | **OK** |
| `CKRecordTranslator` 437 · `SplitSyncStartGate` 292 · `CKShareEntryHandler` 151 · `CloudKitConstants` 150 · `PendingInviteStore` 92 · `GroupUserIdentityService` 88 · `PendingLeaveShareTracker` 68 · `GroupsIdentityBootGuardLogic` 44 | — | idénticos | **OK** |

**Suma real de los ficheros enteros de producción: 4.498 líneas** (el plan implica 4.892).
Menos **75 líneas que hay que MOVER, no borrar** (§1.1) ⇒ **~4.423 netas de producción.**

Tests: 1.681 − **130 que sobreviven** (§1.1) ⇒ **~1.551 netas.** **Total Fase 3 ≈ 5.974 líneas**, no ~6.934.

Nota de higiene positiva: el `.pbxproj` usa `PBXFileSystemSynchronizedRootGroup`
(`Yala.xcodeproj/project.pbxproj:124-135`) y **cero** referencias individuales a los ficheros condenados
⇒ borrar del disco los saca del build sin cirugía de proyecto. No hay acoplamiento por ahí.

---

## §1 · Tipos declarados DENTRO de un fichero que muere, USADOS por código que sobrevive

Estos son los que hay que **mover**. `grep` de `enum|struct|class|actor|protocol|typealias|extension`
sobre los 13 ficheros condenados, y luego uso fuera de ellos.
**No hay ni una `extension` ni un `Notification.Name` declarado en los ficheros condenados** (verificado):
eso elimina una clase entera de rotura silenciosa.

### 1.1 · `BootSaveGateLogic` — la trampa exacta de la Fase 1, repetida

| Qué | Dónde |
|---|---|
| Declaración | `Yala/App/Logic/SplitSyncStartGate.swift:218-292` (75 líneas), fichero **condenado**, junto con su `enum Decision` en `:222-247` |
| Usos que **sobreviven** | `Yala/App/AppBootstrapper.swift:881` (`func gateDecision() -> BootSaveGateLogic.Decision`), `:882` (`BootSaveGateLogic.decide(`), `:923` (`recordBootSaveGateOutcome(_ decision: BootSaveGateLogic.Decision)`) |
| **Dependencia oculta** | `BootSaveGateLogic.decide` llama `SplitSyncStartGate.resolveWaitByQuiescence` en **`SplitSyncStartGate.swift:278-284`** ⇒ mover el `enum` sin llevarse `resolveWaitByQuiescence` (`:97-108`) + su `enum WaitResolution` (`:61-66`) no compila |
| Tests que **sobreviven** | `YalaTests/SplitSyncStartGateTests.swift:265-395` (suite `@Suite("Boot Save Gate Logic")` en `:270`, **10 `@Test`**), y **`:389` llama `SplitSyncStartGate.resolveWaitByQuiescence` DIRECTO** para el oráculo de `hardCapIsNeverConsulted_forBootSaves` (`:378`) |

**Por qué no es opcional.** `BootSaveGateLogic` **no es del transporte de Grupos**: es el gate de los
`save()` del **store PERSONAL** en boot temprano — los ~8 boot tasks que embudan por
`AppBootstrapper.awaitPersonalImportForBootSave` (`retryPendingBridges`, `migrateShareGroupZoneIDs`,
drenajes de pagos planificados / tipos de cambio / TX provisionales, reconciles, `sendDueReports`). Su
doc-comment (`SplitSyncStartGate.swift:200-217`) lo dice: protege del `_assertionFailure` interno de
SwiftData (SIGTRAP, no atrapable → crash-loop en cada cold launch de un device restaurado de iCloud).
Vive dentro de `SplitSyncStartGate.swift` solo por **afinidad de razonamiento**, no de dominio.

**Corte exacto que hay que hacer** (a un fichero nuevo, p. ej. `Yala/App/Logic/BootSaveGateLogic.swift`):

- `SplitSyncStartGate.swift:61-66` → `enum WaitResolution` (tipo de retorno)
- `SplitSyncStartGate.swift:97-108` → `static func resolveWaitByQuiescence` (+ su doc `:68-96`)
- `SplitSyncStartGate.swift:198-292` → el bloque `// MARK: - Boot-save gate` completo
- `YalaTests/SplitSyncStartGateTests.swift:265-395` → la suite `Boot Save Gate Logic` completa

**Verificado que NADA más de `SplitSyncStartGate` sobrevive**: los 7 miembros restantes
(`decideStart`, `promotedWhileNotQuiescent`, `shouldDeferDelegateSave`, `needsZoneRecovery`,
`needsRecordRecovery`, `classifyFailedSave`, `FailedSaveDisposition`) tienen su **único** caller de
producción en `SplitSyncManager.swift` (`:207`, `:638`, `:1193`, `:462`/`:550`, `:555`/`:560`/`:565`/`:570`,
`:1904`). Y `resolveWaitByQuiescence` **también** lo llama `SplitSyncManager.swift:630` ⇒ el fichero se
parte en dos, no se borra.

### 1.2 · `CKConstants.zonePrefix` — está en el `init` de un modelo SwiftData vivo, y define la identidad del canal backend

| Qué | Dónde |
|---|---|
| Declaración | `Yala/Services/Groups/CloudKitConstants.swift:125` — `static let zonePrefix = "SplitGroup-"` (fichero **condenado entero**) |
| Uso que **sobrevive** | **`Yala/Models/SplitGroup.swift:102`** — `self.cloudKitZoneID = "\(CKConstants.zonePrefix)\(self.id.uuidString)"`, dentro del `init` del `@Model` |

**Por qué es el hallazgo caro.** `cloudKitZoneID` **no es un detalle de CloudKit**: es el `group_id` del
wire del canal backend, la identidad server-side del grupo. Pruebas en el propio código:

- `Yala/Services/CloudSync/Groups/GroupSyncOutbox.swift:41` — «`group_id` del wire (§A): … `cloudKitZoneID` para el grupo»
- `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:581` — «conjunto de `group_id` (= `cloudKitZoneID`) de los grupos del canal BACKEND»; `:1825`, `:1836` (`model.cloudKitZoneID = delta.groupID`), `:1986`
- `Yala/Services/CloudSync/Groups/GroupMerkleProjection.swift:24` y `:164` (la *keyset column* de la proyección Merkle)
- `Yala/Services/CloudSync/Groups/GroupBackendMembershipService.swift:67` — documenta el formato literal `"SplitGroup-{uuid}"`
- `Yala/Services/CloudSync/Groups/GroupBackendInviteService.swift:38`, `Yala/Services/CloudSync/EntityApplyMap.swift:693` («se copia byte a byte, NUNCA se remapea»)

⇒ **`zonePrefix` hay que MOVERLO con su valor byte-idéntico**, no reescribirlo. Un `"SplitGroup-"`
inlineado mal (o un `"Group-"` «más limpio») cambia la identidad server-side de todo grupo nuevo:
compila, pasa los unit tests locales y rompe el join/merkle contra staging. Y `groups_merkle_fixtures.json`
/ el canon c1 son append-only por contrato (§Fase 5 del plan).

Destino natural: junto a `SplitGroup` o en el namespace de identidad del canal backend
(`Yala/Services/CloudSync/Groups/GroupBackendIdentityLogic.swift`).

### 1.3 · `CKConstants` — los otros 3 miembros con caller superviviente (todos MUEREN, pero exigen trim, no borrado)

| Miembro | Declaración | Callsite en fichero **superviviente** | Qué hay que hacer |
|---|---|---|---|
| `recordID(for:in:)` | `CloudKitConstants.swift:143` | `Yala/App/Logic/GroupJoinReconcileLogic.swift:153` | Borrar con el bloque `EnqueuePlan` (§2.3) |
| `containerID` | `CloudKitConstants.swift:14` | `Yala/Services/Groups/GroupService.swift:249`, `Yala/Services/Groups/InviteLinkService.swift:245` | Mueren con `propagateBoolCustomKey` y con `fetchShareMetadata` |
| `zoneName(for:)` | `CloudKitConstants.swift:127` | solo comentario en `GroupsIdentityPurgeGate.swift:213` (condenado) + `YalaTests/GroupsIdentityPurgeGateTests.swift:232` | Sin superviviente real |

`RecordType`, `GroupMetaField`, `ExpenseField`, `MemberField`, `ShareField`, `SettlementField`,
`zoneID`, `groupID(from:)`, `modelID(from:)`: **cero** usos fuera de `SplitSyncManager.swift`,
`CKRecordTranslator.swift`, `SplitZoneManager.swift` y sus tests. Mueren limpios.

### 1.4 · `GroupUserIdentityService` — trim, y el trim tiene una consecuencia INVISIBLE (§3.1)

El plan ya dice «conservar `deterministicUUID` y `cachedRecordName`». Medido, la partición exacta es:

| Miembro | Línea | Callers supervivientes | Destino |
|---|---|---|---|
| `deterministicUUID(namespace:name:)` | `:77-87` | `GroupsSyncClient.swift:1901`, `GroupBackendIdentityLogic.swift:38`, `GroupService.swift:122`, `:928` | **CONSERVAR** (ya es `nonisolated`, sin CloudKit) |
| `cachedRecordName` (`private(set)`) | `:21` | `GroupSettingsView.swift:704`, `GroupBackendInviteEntryHandler.swift:127`, `GroupExpenseService.swift:614`, `GroupJoinReconciler.swift:293`, `GroupService.swift:1019` | **CONSERVAR** (pero ver §3.1) |
| `_testSetCachedRecordName` (DEBUG) | `:65-67` | `GroupJoinReconcilerTests:31,36`, `GroupServiceCurrentUserFlagsTests:58,64`, `GroupsSyncClientTests:569,572,614,617,656,659` | **CONSERVAR** (10 callsites en 3 suites que sobreviven) |
| `currentUserRecordName()` | `:27-43` | `AppBootstrapper.swift:440`, `GroupService.swift:95`, `:845`, `:1023` | muere (usa `CKContainer`) — **4 callsites supervivientes que hay que recablear** |
| `fetchFreshRecordName()` | `:57-59` | solo `SplitSyncManager.swift:270` | muere |
| `clearCache()` | `:45-50` | solo `SplitSyncManager.swift:1466` | **ver §3.1 — NO borrar sin sustituto** |
| `deterministicMemberID(groupZoneID:)` | `:70-73` | ninguno (el backend usa `GroupBackendIdentityLogic.deterministicMemberID`) | muere |

### 1.5 · Tipos condenados cuyos usos supervivientes son código que TAMBIÉN muere (trim dentro de fichero vivo)

No hay que moverlos, pero cada uno es un punto de edición en un fichero que sobrevive — si se olvida,
son errores de compilación encadenados.

| Tipo (declaración) | Usos en fichero **superviviente** |
|---|---|
| `SplitZoneError` — `SplitZoneManager.swift:288` | `GroupDetailViewModel.swift:458`, `GroupMembersView.swift:478` (ambos `(error as? SplitZoneError)?.errorDescription ?? L10n.Groups.Errors.inviteFailed`) · y **`SplitSyncManager.swift:871`** `throw SplitZoneError.engineNotInitialized` |
| `PendingLeaveShareEntry` / `PendingLeaveShareTracker` — `PendingLeaveShareTracker.swift:18` / `:24` | `GroupService.swift:593`, `:645-647` · `AppBootstrapper.swift:1164`, `:1172` · `SplitZoneManager.swift:236` |
| `PendingInviteEntry` / `PendingInviteStore` — `PendingInviteStore.swift:24` / `:48` | `AppBootstrapper.swift:1750`, `:1817`, `:1891` · `ContentView.swift:1739`, `:1752` · **`AppRouter.swift:156`** (dentro de `resetAll()`) · `GroupJoinIntentTracker.swift:122` |
| `SplitSyncManager.SyncStatus` — `SplitSyncManager.swift:25-30` | **`Yala/Services/iCloudSyncService.swift:112-113`** (`var splitSyncStatus: SplitSyncManager.SyncStatus`). Sin lectores: `splitSyncStatus` tiene **0** usos fuera de su propia declaración ⇒ propiedad muerta hoy, borrado limpio |
| `GroupsICloudAvailabilityGateLogic` / `GroupsICloudUnavailableView` | `ContentView.swift:2062-2071` (rama `else if !CloudSyncFlags.groupsBackendEnabled, GroupsICloudAvailabilityGateLogic.shouldShowGate(...)`) |
| `CKShareEntryHandler` — `CKShareEntryHandler.swift:18` | `AppBootstrapper.swift:1875`, `YalaAppDelegate.swift:110` |
| `SplitZoneManager` (clase) | `AppBootstrapper.swift:1168` · `GroupDetailViewModel.swift:446` · `GroupSettingsView.swift:661` · `GroupMembersView.swift:465` · `GroupService.swift:111`, `:345`, `:586`, `:588`, `:624`, `:637` |
| `SplitSyncManager` (clase) | `AppBootstrapper.swift:316`, `:317`, `:1274` · `GroupsViewModel.swift:203` · `ContentView.swift:1692` · `GroupDetailViewModel.swift:135` · **`DataWipeService.swift:270`** (§3.1) · `iCloudSyncService.swift:113` · `GroupJoinReconciler.swift:71`, `:253` · `GroupJoinIntentTracker.swift:133` · `GroupExpenseService.swift:109` + los **~30 `enqueueSave`/`enqueueDeletion`** de `GroupExpenseService`/`GroupService` (§2.3) |

---

## §2 · Ciclos de referencia entre ficheros condenados (qué NO se puede partir en commits)

### 2.1 · Ciclo duro `SplitSyncManager` ↔ `SplitZoneManager` → **commit atómico obligatorio**

```
SplitSyncManager.swift:470   let zoneManager = SplitZoneManager(syncManager: self)
SplitSyncManager.swift:871   throw SplitZoneError.engineNotInitialized   // tipo declarado en SplitZoneManager.swift:288
        ▲                                                                        │
        └── SplitZoneManager.swift:16   private let syncManager: SplitSyncManager │
            SplitZoneManager.swift:19   init(syncManager: SplitSyncManager)  ◄────┘
```

Ciclo **bidireccional real de código** (no de comentarios), agravado por `SplitZoneError` viviendo dentro
del fichero del otro. Es el mismo patrón que forzó el commit atómico en la Fase 1
(`GroupFetchQuiescenceGate` ↔ `SplitSyncManager.privateFetchGateSignal`). **Los dos ficheros van en el
mismo commit, sin excepción.**

### 2.2 · Ciclo `SplitZoneManager` → `PendingLeaveShareTracker` con árbitro superviviente

`SplitZoneManager.swift:236` usa `PendingLeaveShareTracker`, y `GroupService.swift:593`/`:645` **también**
(fichero superviviente). No es ciclo, pero sí un triángulo: el trio
`SplitZoneManager` + `PendingLeaveShareTracker` + el bloque `leaveGroup`/`performRemovedSelfCleanup` de
`GroupService.swift:578-652` tiene que caer junto o `GroupService` no compila.

### 2.3 · Cadena `enqueueSave`/`enqueueDeletion` — 1 declaración, ~30 callsites en 3 ficheros supervivientes

`enqueueSave`/`enqueueDeletion` se declaran en `SplitSyncManager.swift` y se llaman desde:

- `Yala/Services/Groups/GroupExpenseService.swift` — `:109`, `:119`, `:169`, `:194`, `:204`, `:256`, `:270`, `:429`, `:468`, `:501` (10)
- `Yala/Services/Groups/GroupService.swift` — `:127`, `:188`, `:213`, `:235`, `:301`, `:403`, `:454`, `:508`, `:541`, `:574`, `:875`, `:897`, `:934`, `:986`, `:1083`, `:1094`, `:1133`, `:1177` (18)
- `Yala/Services/Groups/GroupJoinReconciler.swift:253` (1)

Y su proyección testeable en fichero superviviente: `Yala/App/Logic/GroupJoinReconcileLogic.swift`
declara **`struct EnqueuePlan`** en `:135-141` y `static func enqueuePlan` en `:143-173` («oráculo:
`CKConstants` / `enqueueSharedSave`»); su test es `YalaTests/GroupJoinReconcileLogicTests.swift:165-176`.
Todo ese bloque muere y es **la única razón por la que `GroupJoinReconcileLogic.swift` importa CloudKit**
(`:23` — usa `CKCurrentUserDefaultName` y `CKRecordZone.ID`).

### 2.4 · Aristas unidireccionales que fijan el orden dentro de los ficheros condenados

`SplitSyncManager` → `GroupsIdentityPurgeGate.apply` (`:1497`, único callsite) ·
`SplitSyncManager` → `GroupsIdentityBootGuardLogic.decide` (`:275`, único callsite) ·
`SplitSyncManager` → `PendingInviteStore` (`:760`) · `SplitSyncManager` → `CKRecordTranslator` (18 sitios) ·
`CKShareEntryHandler` → `SplitSyncManager` (`:94`) + `PendingInviteEntry`/`Store` (`:51`, `:111`, `:128`) ·
`SplitZoneManager` → `CKRecordTranslator` (`:274`) · `CKRecordTranslator` → `CKConstants` (30 sitios).
Consecuencia: **`CloudKitConstants.swift` y `CKRecordTranslator.swift` son las hojas del grafo — van
últimos o en el mismo commit; ninguno puede ir primero.**

### 2.5 · `CKShareCustomKey` — vive en un fichero que sobrevive, muere igual

`enum CKShareCustomKey` está declarado en **`Yala/App/Models/RouterIntent.swift:22-25`** (superviviente).
Sus 4 usos: `CKShareEntryHandler.swift:58`, `:59` (condenado) y `SplitSyncManager.swift:2033`, `:2039`
(condenado), más `GroupService.swift:238`, `:318` (los callsites de `propagateBoolCustomKey`). Al morir
todos, el `enum` queda huérfano dentro de `RouterIntent.swift`.

Y en el mismo fichero superviviente: **`struct InviteMetadata`** (`RouterIntent.swift:50-79`) tiene
`let shareMetadata: CKShare.Metadata` **no-opcional** (`:55`, `:64`) y su `==` compara
`shareMetadata.share.recordID` (`:77`). Está en **3 cases de `RouterIntent`** (`:105`
`presentGroupInviteOnboarding`, `:106` `presentGroupReconnect`, `:110` `offerRestoreBeforeInvite`) y en
`ContentView.swift:69`, `:88`, `:92`, `:1651`, `:1698`, `:1701`, `GroupInviteOnboardingView.swift:31`,
`:35`, `GroupReconnectView.swift:17`. **Es CloudKit-tipado por construcción** ⇒ es lo que impide cumplir
el criterio de salida sin tocar el router y 2 vistas. El plan no lo menciona.

---

## §3 · Riesgos que NO dan error de compilación (los que el compilador no va a señalar)

### 3.1 · RIESGO MAYOR — el handover deja de borrar la identidad cacheada del usuario anterior, y el test sigue VERDE

`DataWipeService.wipeLocalGroupsDomain` tiene su seam `resetSyncState` con **valor por defecto**:

```
Yala/Utils/DataWipeService.swift:269-271
    resetSyncState: @MainActor () -> Void = {
        SplitSyncManager.shared.resetLocalGroupsSyncState()
        …
        GroupsOutboxMirror()?.purgeAll()
    }
```

y `SplitSyncManager.resetLocalGroupsSyncState()` (`SplitSyncManager.swift:1463-1473`) hace, en su cuerpo:

```
    clearState(name: "private")
    clearState(name: "shared")
    GroupUserIdentityService.shared.clearCache()      // ← :1466
```

`DataWipeService.swift:328-330` documenta **explícitamente** que depende de eso:

> «`groups_currentUserRecordName` NO se toca aquí a propósito: la borra `clearCache()` del
> `resetSyncState`, que además tira el valor EN MEMORIA del singleton (borrar solo la key dejaría al
> proceso vivo operando con la identidad cacheada del usuario anterior).»

Al morir `SplitSyncManager`, ese default se reescribe (obligado por el compilador) y **lo natural es
dejarlo solo con `GroupsOutboxMirror()?.purgeAll()`** — con lo que la key `groups_currentUserRecordName`
sobrevive al «empiezo de cero» del Welcome y el humano NUEVO hereda el record name del anterior. Sus 5
lectores supervivientes (§1.4) lo usarían: `GroupBackendInviteEntryHandler.swift:127` resuelve con él
**la identidad con la que se entra a un grupo** y `GroupService.swift:1019` la usa en el mismo camino.
Eso es exactamente la trampa (3) que `.claude/rules/swiftdata-cloudkit.md` documenta («con una sola
credencial viva, el humano nuevo entra COMO el anterior con permiso de editar y borrar»).

**Y no lo caza nadie:** `YalaTests/HandoverGroupsDomainTests.swift:86-96`
(`wipeLocalGroupsDomain_alwaysPairsRowDeletionWithSyncStateReset`) solo cuenta invocaciones del closure
inyectado (`#expect(resetSyncStateCalls == 1)`), **no su contenido**. El test queda verde con el default
vacío. El único que mira contenido es `:389-395`, y solo busca `GroupsOutboxMirror()?.purgeAll()` y la
ausencia de `purgeGroupsSyncState(`.

⇒ **Acción**: en el mismo commit que borra `SplitSyncManager`, el default de `resetSyncState` debe seguir
borrando `groups_currentUserRecordName` (llamando al `clearCache()` conservado de
`GroupUserIdentityService`, §1.4), **y** hay que añadir al test la aserción de contenido.

### 3.2 · `CloudKitGroupsSchemaParityTests` lee `CloudKitConstants.swift` por RUTA — el plan lo pone en la Fase 4, pero el fichero muere en la 3

`YalaTests/CloudKitGroupsSchemaParityTests.swift:43`:

```
repoRoot.appendingPathComponent("Yala/Services/Groups/CloudKitConstants.swift")
```

(vía `#filePath`, mismo patrón que `LocalizationParityTests`; también `:13`, `:25`, `:56`, `:127`).

El plan borra `CloudKitConstants.swift` en **Fase 3 commit 1** (línea 266) pero asigna
`CloudKitGroupsSchemaParityTests` a **Fase 4 commit 1** (línea 302). Entre las dos fases la suite
**falla en RUNTIME, no al compilar** — el `String` de la ruta compila igual. Y `/gate` corre unit tests
⇒ deja el árbol rojo entre fases, con un fallo que no señala a ningún símbolo.
**Corrección:** `CloudKitGroupsSchemaParityTests.swift` (157 líneas) baja a **Fase 3 commit 2**.

`YalaTests/GroupsIdentityPurgeGateTests.swift:381`, `:389`, `:402`, `:410` leen
`Yala/Services/Groups/SplitSyncManager.swift` y `:423` lee `GroupsIdentityPurgeGate.swift` — ahí sí es
coherente: ambos ficheros y el test mueren en el mismo par de commits.

### 3.3 · El criterio de salida `grep -r "import CloudKit"` → 0 alcanza 2 ficheros que el plan NO lista

`grep -rln "import CloudKit" Yala` da 25 ficheros. En las dos rutas del criterio de salida (línea 286
del plan) quedan, tras borrar los condenados:

| Fichero (sobrevive) | Situación medida |
|---|---|
| `Yala/Services/Groups/GroupService.swift` | `import CloudKit` real: `CKRecordZone.ID`/`CKCurrentUserDefaultName` en `propagateBoolCustomKey` (`:246-247`) y `CKContainer` en `:249`. Se va con el trim que el plan sí pide |
| `Yala/Services/Groups/InviteLinkService.swift` | `import CloudKit` real: `CKShare.Metadata` en `fetchShareMetadata` (`:234`) y `CKContainer` en `:245`. Se va con el trim que el plan sí pide |
| **`Yala/App/Views/Groups/GroupInviteOnboardingView.swift:13`** | **`import CloudKit` MUERTO hoy** — cero símbolos `CK*` en el fichero. El plan no lo menciona; sin quitarlo el criterio de salida no da 0 |

Bonus fuera de las rutas del criterio, mismo caso (imports muertos, cero símbolos `CK*`):
`Yala/App/Views/Shared/SyncStatusBanner.swift:13` y `Yala/App/Models/SessionState.swift:8`.

Y **`InviteLinkService.BrandedMetadata`** (`InviteLinkService.swift:195-203`) sobrevive dentro del
fichero trimado: lo consume el canal backend en
`Yala/App/Services/GroupBackendInviteEntryHandler.swift:68` y `AppBootstrapper.swift:1721`, `:1741`,
`:1854`, `:1869`. No es CloudKit-tipado (`Codable`, `Sendable`) — se queda. Ojo con borrarlo por arrastre
al vaciar `PendingInviteStore.swift:26`, `:31`, `:41`, que es quien más lo usa.

### 3.4 · `SplitZoneManager` (308 líneas, incl. `deleteZone`) no tiene NINGÚN test unitario

`find` de `SplitZoneManagerTests.swift` → **no existe**. Tampoco `CKShareEntryHandlerTests`,
`CloudKitConstantsTests`, `GroupUserIdentityServiceTests`, `PendingLeaveShareTrackerTests`. Los seis
métodos públicos de `SplitZoneManager` (`createZone:26`, `deleteZone:58`, `createShare:140`,
`leaveShare:228`, `leaveShareByZone:238`, `ownerName:269`) se borran **a ciegas** — nada verde/rojo va a
confirmar que su desaparición no arrastró un camino vivo. El plan cifra 10 ficheros de test como si
hubiera cobertura simétrica; no la hay.

### 3.5 · Orden del emisor de notificaciones — ya avisado en las reglas, con líneas que hay que RE-verificar

`.claude/rules/swiftdata-cloudkit.md` fija que el anti-duplicado depende de un ORDEN dentro de
`SplitSyncManager.swift`: `backendZoneNames` en `:1562`, descarte de records en `:1610`, de deletions en
`:1672`, y `pendingBridgeChangeSet` no se rellena hasta `:1723`; y dice literalmente «al abrir la Fase 3,
verificar este orden antes de borrar el emisor del transporte». Como el fichero perdió 384 líneas
respecto a la cifra del plan, **esas 4 líneas también hay que re-anclarlas antes de usarlas** — no
asumirlas.

---

## §4 · `qa/coverage-index.json` — 5 áreas afectadas (el plan solo dice «+ `_meta.counts`»)

`_meta.counts` hoy: `{total: 134, deterministic: 41, agentic: 35, manual: 58, deterministicSinXCUITest: 0}`;
`backlogBaseline: 0`, `agenticBacklogBaseline: 5`.

| `area` | clasificación | `lastVerified` | `codeGlobs` condenados |
|---|---|---|---|
| `groups-cross-device-sync` | manual | 2026-07-29 | `SplitSyncManager.swift`, `SplitSyncStartGate.swift`, `GroupsIdentityBootGuardLogic.swift`, `GroupUserIdentityService.swift`, `SplitZoneManager.swift`, `CKRecordTranslator.swift`, `CloudKitConstants.swift`, `PendingLeaveShareTracker.swift`, `GroupsIdentityPurgeGate.swift` (**9 de 13**) |
| `groups-icloud-availability-gate` | manual | 2026-07-13 | `GroupsICloudAvailabilityGateLogic.swift`, `GroupsICloudUnavailableView.swift` (**el área entera desaparece**) |
| `groups-pending-approval-reconnect` | agentic | 2026-07-29 | `GroupUserIdentityService.swift`, `PendingInviteStore.swift`, `CKShareEntryHandler.swift` |
| `groups-backend-g5-cutover` | manual | 2026-07-16 | `SplitZoneManager.swift` |
| `groups-backend-g6-migration` | manual | 2026-07-28 | `CKRecordTranslator.swift`, `CloudKitConstants.swift` |

`groups-icloud-availability-gate` se queda **sin ningún `codeGlob`** ⇒ hay que borrar el área, no solo
tocar su `lastVerified`, y bajar `_meta.counts.manual` y `total`. `bash qa/validate-coverage.sh` es la
comprobación.

---

## §5 · Orden mínimo que compila (derivado de §1 y §2)

1. **Commit previo (opcional, aislado, sin riesgo):** mover `BootSaveGateLogic` + `WaitResolution` +
   `resolveWaitByQuiescence` a fichero propio, y la suite `Boot Save Gate Logic` a
   `YalaTests/BootSaveGateLogicTests.swift`. Mover `zonePrefix` (con su valor literal) fuera de
   `CloudKitConstants.swift`. **Compila y pasa tests por sí solo** ⇒ saca 2 acoplamientos del commit
   grande sin abrir ninguna ventana.
2. **Commit 1 (producción, atómico e indivisible):** los 13 ficheros (ya vaciados de lo movido) +
   los trims de `GroupService`, `GroupExpenseService`, `GroupJoinReconciler`, `GroupJoinReconcileLogic`,
   `AppBootstrapper`, `ContentView`, `AppRouter`, `YalaAppDelegate`, `GroupDetailViewModel`,
   `GroupMembersView`, `GroupSettingsView`, `GroupsViewModel`, `GroupJoinIntentTracker`,
   `iCloudSyncService`, `InviteLinkService`, `RouterIntent`, `SplitGroup`, **`DataWipeService` (§3.1)**
   y los 3 `import CloudKit` muertos. El ciclo `SplitSyncManager` ↔ `SplitZoneManager` (§2.1) y las
   ~30 llamadas a `enqueueSave` (§2.3) **prohíben cualquier subdivisión**.
3. **Commit 2 (tests + coverage):** los 8 ficheros de test del transporte (1.681 líneas, menos las 130
   ya movidas en el paso 1) **+ `CloudKitGroupsSchemaParityTests.swift` (157, adelantado de la Fase 4,
   §3.2)** + las 5 áreas de `qa/coverage-index.json` + `_meta.counts`.
