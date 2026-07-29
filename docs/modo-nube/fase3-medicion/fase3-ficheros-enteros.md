# Fase 3 — Bloque «ficheros-enteros»: medición contra HEAD

**HEAD medido:** `ca06cfd5` (branch `2.0.5`). Árbol sucio solo en `screenshots-appstore/` (PNG), nada
bajo `Yala/`. Todas las cifras salen de `wc -l` / `grep -n` contra este HEAD, no del plan.

---

## 1. Tabla maestra: ruta real, líneas reales, delta contra el plan

Los 13 ficheros **EXISTEN**. Ninguno falta. Pero 6 de 13 están en una ruta distinta a la del plan.

| # | Fichero | Ruta REAL | Plan | HEAD | Δ | Ruta del plan |
|---|---|---|---|---|---|---|
| 1 | SplitSyncManager.swift | `Yala/Services/Groups/` | 2905 | **2521** | **−384** | ❌ decía `CloudSync/` |
| 2 | CKRecordTranslator.swift | `Yala/Services/Groups/` | 437 | **437** | 0 | ❌ decía `CloudSync/` |
| 3 | SplitZoneManager.swift | `Yala/Services/Groups/` | 308 | **308** | 0 | ❌ decía `CloudSync/` |
| 4 | SplitSyncStartGate.swift | `Yala/App/Logic/` | 292 | **292** | 0 | ✅ |
| 5 | GroupsIdentityPurgeGate.swift | `Yala/App/Logic/` | 263 | **253** | **−10** | ✅ |
| 6 | CKShareEntryHandler.swift | `Yala/App/Services/` | 151 | **151** | 0 | ✅ |
| 7 | CloudKitConstants.swift | `Yala/Services/Groups/` | 150 | **150** | 0 | ❌ decía `CloudSync/` |
| 8 | PendingInviteStore.swift | `Yala/Services/Groups/` | 92 | **92** | 0 | ❌ decía `CloudSync/` |
| 9 | GroupUserIdentityService.swift | `Yala/Services/Groups/` | 88 | **88** | 0 | ❌ decía `CloudSync/` |
| 10 | PendingLeaveShareTracker.swift | `Yala/Services/Groups/` | 68 | **68** | 0 | ❌ decía `CloudSync/` |
| 11 | GroupsICloudUnavailableView.swift | `Yala/App/Views/Groups/` | 94 | **61** | — | ✅ |
| 12 | GroupsICloudAvailabilityGateLogic.swift | `Yala/App/Logic/` | (con #11) | **33** | — | ✅ |
| 13 | GroupsIdentityBootGuardLogic.swift | `Yala/App/Logic/` | 44 | **44** | 0 | ✅ |
| | **TOTAL** | | **4892** | **4498** | **−394** | |

Notas de la tabla:
- #11+#12 juntos = 61+33 = **94** → el par cuadra exacto con el plan. Esa coordenada está bien.
- **Solo 2 ficheros cambiaron** de tamaño: SplitSyncManager (−384) y GroupsIdentityPurgeGate (−10).
  Los otros 11 están byte-estables. O sea: el plan NO está globalmente desfasado por Fase 1/2 — está
  desfasado en **un solo sitio grande**.
- `Yala/Services/CloudSync/` **sí existe** (74 ficheros, es el canal backend) y tiene un subdirectorio
  `Yala/Services/CloudSync/Groups/` (14 ficheros: `GroupsSyncClient.swift`, `GroupBackendIdentityLogic
  .swift`, …). De ahí la confusión del plan: el transporte viejo vive en `Services/Groups/`, el canal
  nuevo en `Services/CloudSync/Groups/`. **Nombres casi idénticos, carpetas distintas.**

### De dónde salen los −384 de SplitSyncManager (verificado en git log)

| Commit | Asunto | Δ en el fichero |
|---|---|---|
| `5010db6a` | Fase 1 — «fuera la maquinaria de migrar grupos vivos a la nube» | −259 |
| `632c951f` | Fase 2 — «las consultas del store de Grupos viven en GroupService» | −153 |

−259 −153 = −412 brutos; neto −384 tras los `+` de esos mismos commits. La cifra 2905 del plan es
**pre-Fase-1**, exactamente como avisaba el encabezado de «NO VERIFICADAS».

---

## 2. Fan-out: cuántos ficheros hay que re-cablear

`grep -rlw "<Tipo>"`. «app (otros)» excluye el fichero que lo define.

| Tipo principal | Fichero | app (otros) | tests | Riesgo |
|---|---|---|---|---|
| `SplitSyncManager` | #1 | **24** | 3 | 🔴 el epicentro |
| `CKRecordTranslator` | #2 | **10** | 5 | 🟠 3 son Models que SOBREVIVEN |
| `CKConstants` | #7 | **10** | 5 | 🔴 **4 callers de código real sobreviven** |
| `PendingInviteStore` | #8 | **10** | 1 | 🟠 |
| `GroupUserIdentityService` | #9 | **10** | 4 | 🔴 **el canal backend depende de él** |
| `SplitZoneManager` | #3 | 6 | 1 | 🟡 |
| `SplitSyncStartGate` | #4 | 6 | 1 | 🔴 **lleva pasajero** |
| `CKShareEntryHandler` | #6 | 6 | 0 | 🟡 |
| `PendingLeaveShareTracker` | #10 | 4 | 1 | 🟡 |
| `GroupsIdentityPurgeGate` | #5 | 2 | 1 | 🟠 |
| `GroupsICloudAvailabilityGateLogic` | #12 | 1 | 1 | 🟢 |
| `GroupsIdentityBootGuardLogic` | #13 | 1 | 1 | 🟢 |
| `GroupsICloudUnavailableView` | #11 | 1 | 0 | 🟢 |

Tipos secundarios en esos mismos ficheros (también se van): `SplitSyncError` (#1, 0 externos),
`SplitZoneError` (#3, 3 externos + 2 tests), `PendingInviteEntry` (#8, 2 + 1),
`PendingLeaveShareEntry` (#10, 1 + 1), `SplitSyncDelegate` (#1, `private`, 0).

---

## 3. HALLAZGO PRINCIPAL: tres de los 13 NO son borrados de fichero entero

El plan los cuenta como «se va el fichero completo». Tres llevan dentro código que **sobrevive a la
Fase 3** y hay que extraer antes de borrar, no borrar.

### 3.1 🔴 `SplitSyncStartGate.swift` — lleva un pasajero del sync PERSONAL

El fichero declara **DOS** enums:

| Rango | Tipo | Destino |
|---|---|---|
| `:22`–`:196` | `enum SplitSyncStartGate` | se va (gate del transporte de Grupos) |
| `:198`–`:292` | `enum BootSaveGateLogic` (**95 líneas**) | **DEBE SOBREVIVIR** |

`BootSaveGateLogic` no tiene nada que ver con Grupos: es el gate de los `save()` del **store
PERSONAL** en el arranque (`Yala/App/Logic/SplitSyncStartGate.swift:200-201`, doc textual: *«Pure gate
for early-boot **personal-store** `save()`s»*). Su razón de existir es evitar el `_assertionFailure`
de SwiftData (SIGTRAP no capturable → crash-loop en un restore de iCloud). Callers vivos:

- `Yala/App/AppBootstrapper.swift:881`, `:882`, `:923` (dentro de `awaitPersonalImportForBootSave`)
- `Yala/Services/iCloudSyncService.swift:491` (doc)
- `YalaTests/SplitSyncStartGateTests.swift` (celdas `BootSaveGateLogicTests`)

**Y el nudo:** `BootSaveGateLogic.decide` llama en `:278` a
`SplitSyncStartGate.resolveWaitByQuiescence(...)` — o sea depende de una función que está DENTRO del
enum que se borra. Extraer `BootSaveGateLogic` no basta; hay que arrastrar también:

- `Yala/App/Logic/SplitSyncStartGate.swift:97-108` → `static func resolveWaitByQuiescence` (12 líneas)
- `Yala/App/Logic/SplitSyncStartGate.swift:61` → `enum WaitResolution: Equatable` (su tipo de retorno)
- (+ ~55 líneas de doc en `:40-96` que documentan las ramas de esa función)

Coste real: el fichero **no** aporta 292 líneas de borrado; aporta ~185 y obliga a un fichero nuevo.

### 3.2 🔴 `GroupUserIdentityService.swift` — el canal backend lo usa HOY

`Yala/Services/Groups/GroupUserIdentityService.swift:75-87` declara:

```swift
/// `nonisolated`: primitiva pura (solo CryptoKit, sin estado del actor). Compartida con
/// `GroupBackendIdentityLogic` (canal backend), que corre fuera del main actor.
nonisolated static func deterministicUUID(namespace: String, name: String) -> UUID
```

El propio comentario dice que la comparte el canal backend. Callers reales de `deterministicUUID`:

| Caller | ¿Sobrevive Fase 3? |
|---|---|
| `Yala/Services/CloudSync/Groups/GroupBackendIdentityLogic.swift:38` | ✅ canal backend |
| `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:1901` | ✅ canal backend |
| `Yala/Services/Groups/GroupService.swift:122` y `:928` | ✅ servicio núcleo |
| `YalaTests/CloudSync/GroupBackendIdentityLogicTests.swift:42`, `GroupsSyncClientTests.swift:428`, `GroupJoinReconcilerTests.swift:82` | ✅ |

Además `cachedRecordName` (`:21`) lo leen 3 supervivientes que ya lo tratan como identidad *legacy* de
fallback: `GroupBackendInviteEntryHandler.swift:127` (clave de member para el re-join),
`GroupExpenseService.swift:614`, `GroupJoinReconciler.swift:293`, `GroupService.swift:1019`,
`GroupSettingsView.swift:704`.

Lo que sí muere del fichero: `currentUserRecordName()` (`:27-43`), `fetchFreshRecordName()` (`:57-59`)
y el `inflightFetch` — todo lo que toca `CKContainer(identifier: CKConstants.containerID)`. Es un
**split**, no un borrado: ~14 líneas se mudan, ~74 se van.

### 3.3 🔴 `CloudKitConstants.swift` (`enum CKConstants`) — 4 callers de código real sobreviven

Ojo al desajuste de nombres: el fichero es `CloudKitConstants.swift`, el tipo es `CKConstants`.
De los 10 ficheros que lo referencian, 6 son comentarios (los Models documentan «LOCAL-ONLY: JAMÁS en
`CKRecordTranslator`/`CKConstants`»), pero **4 son código que compila y sobrevive**:

| Sitio | Uso | Miembro |
|---|---|---|
| `Yala/Models/SplitGroup.swift:102` | `self.cloudKitZoneID = "\(CKConstants.zonePrefix)\(self.id.uuidString)"` | `zonePrefix` (`:125`) |
| `Yala/App/Logic/GroupJoinReconcileLogic.swift:153` | `CKConstants.recordID(for: memberID, in: zoneID)` | `recordID` (`:143`) |
| `Yala/Services/Groups/GroupService.swift:249` | `CKContainer(identifier: CKConstants.containerID).privateCloudDatabase` | `containerID` (`:14`) |
| `Yala/Services/Groups/InviteLinkService.swift:245` | `CKContainer(identifier: CKConstants.containerID).add(operation)` | `containerID` (`:14`) |

`SplitGroup.swift:102` es el más caro: es el **inicializador de un @Model que sobrevive**, y
`cloudKitZoneID` sigue siendo la clave con la que se vinculan los hijos por `groupZoneID`. Borrar
`zonePrefix` sin sustituto rompe la construcción de todo grupo nuevo.

---

## 4. Riesgos de segundo orden

### 4.1 🟠 `GroupsIdentityPurgeGate.swift` (#5) no es transporte: es la RETENCIÓN del backend
Su encabezado (`:9-16`) dice que existe para lo contrario de borrar: *la identidad de un grupo del
canal BACKEND es el `sub` de la cuenta Yala, NO el Apple ID ⇒ cambiar de Apple ID no debe
destruirlo*, y advierte que borrar esas filas es **PÉRDIDA PERMANENTE** porque el cursor por-grupo
(`GroupSyncCursor.groupCursorsJSON`) sobrevive y el server solo manda `server_seq > cursor` ⇒ nadie
re-entrega lo borrado. Su único caller de runtime es `SplitSyncManager.swift` (que muere), así que
borrarlo *compila*; el riesgo es de diseño: si el evento de cambio de Apple ID sigue disparando
cualquier purga del dominio Grupos por otra vía, se va el guardia que protegía las filas backend.
Verificar que con el transporte fuera **no queda ningún camino de purga por identidad de OS**.

### 4.2 🟠 `CKRecordTranslator` lo citan 3 Models que sobreviven
`SplitExpense.swift:16,31,46`, `SplitGroup.swift:40,48,58,73,79,84`, `SplitMember.swift:36,48,61`.
Todo son **comentarios** (no rompen el build), pero son el contrato documentado de qué campo viaja y
qué es LOCAL-only. Al borrar el traductor esos docs quedan apuntando al vacío: drift garantizado en
los ficheros más delicados del dominio. Igual con `GroupBalanceService.swift:316`
(`CKRecordTranslator.sanitizeAmount`), `SoftDeleteObserverLogic.swift:21`,
`MemberChangeNotificationLogic.swift:104`.

### 4.3 🟢 Los tres pequeños son borrados limpios
- `GroupsIdentityBootGuardLogic` (#13): único caller `SplitSyncManager.swift:275` → muere con él.
- `GroupsICloudAvailabilityGateLogic` (#12) + `GroupsICloudUnavailableView` (#11): único call site
  `Yala/App/ContentView.swift:2064` y `:2071`. Hay que quitar esa rama del `viewForTab(.groups)`.
  Nota de producto: ese gate es el que bloquea el tab sin cuenta iCloud — con Grupos en backend deja
  de aplicar, pero conviene confirmar si hace falta un gate equivalente de «sin sesión de nube».

### 4.4 Tests que se caen o hay que reubicar
`YalaTests/`: `SplitSyncManagerTests`, `CKRecordTranslatorTests`, `CKRecordTranslatorSanitizeTests`,
`CloudKitGroupsSchemaParityTests`, `SplitSyncStartGateTests` (⚠️ contiene las celdas de
`BootSaveGateLogic` que DEBEN sobrevivir), `GroupsIdentityPurgeGateTests`, `PendingInviteStoreTests`,
`GroupJoinReconcileLogicTests`, `GroupTransactionBridgeSoftDeleteTests`,
`CloudSync/GroupChannelRoutingTests`, `CloudSync/GroupsSyncClientTests`,
`CloudSync/GroupBackendIdentityLogicTests`, `GroupJoinReconcilerTests`,
`GroupServiceCurrentUserFlagsTests`.

---

## 5. Cifra honesta para el plan

| Concepto | Líneas |
|---|---|
| Suma de los 13 ficheros en HEAD | **4498** |
| Cifra del plan (pre-Fase-1) | 4892 |
| Error del plan | −394 (98 % concentrado en SplitSyncManager) |
| Código que hay que EXTRAER, no borrar | ~135 (95 `BootSaveGateLogic` + ~17 `resolveWaitByQuiescence`/`WaitResolution` + 13 `deterministicUUID` + ~15 de `CKConstants`) |
| **Borrado neto realista de este bloque** | **≈ 4360** |
| Ficheros que son borrado entero de verdad | **10 de 13** |
| Ficheros que exigen extracción previa | **3** (#4 `SplitSyncStartGate`, #9 `GroupUserIdentityService`, #7 `CloudKitConstants`) |
