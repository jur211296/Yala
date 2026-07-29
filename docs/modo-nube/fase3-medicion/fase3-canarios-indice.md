# Fase 3 · bloque `canarios-indice` — medición contra HEAD `ca06cfd5` (branch 2.0.5)

Todo lo de abajo sale de medición propia contra HEAD. Nada viene del plan; donde el plan y HEAD
discrepan lo digo explícitamente.

**Conjunto "transporte" que uso como referencia de borrado** (lista de ficheros de la §Fase 3 del
plan, verificada fichero a fichero en HEAD):
`Yala/Services/Groups/SplitSyncManager.swift` (2521) · `CKRecordTranslator.swift` (437) ·
`SplitZoneManager.swift` (308) · `CloudKitConstants.swift` (150) · `PendingInviteStore.swift` (92) ·
`PendingLeaveShareTracker.swift` (68) · `Yala/App/Logic/SplitSyncStartGate.swift` (292) ·
`GroupsIdentityPurgeGate.swift` (253) · `GroupsIdentityBootGuardLogic.swift` (44) ·
`GroupsICloudAvailabilityGateLogic.swift` (33) · `Yala/App/Views/Groups/GroupsICloudUnavailableView.swift` (61) ·
`Yala/App/Services/CKShareEntryHandler.swift` (151) · `GroupUserIdentityService.swift` (88, PARCIAL).

---

## (a) Canarios y breadcrumbs que quedan SIN EMISOR

### a.1 · `MetricsCanary` — casos huérfanos (451 líneas hoy)

Cada fila comprobada con `grep` repo-entero (`Yala/` + `YalaTests/` + `YalaUITests/` + `qa/` + docs).

| `MetricsService.swift` | Caso | Emisor(es) HOY | Veredicto |
|---|---|---|---|
| `:43` | `cloudkitGroupSyncGateHardCap` | `SplitSyncManager.swift:650` | **huérfano** |
| `:44` | `cloudkitGroupSyncPromotedToAuto` | `SplitSyncManager.swift:230`, `:401` | **huérfano** |
| `:45` | `cloudkitGroupSyncNoImportPromote` | `SplitSyncManager.swift:645` | **huérfano** (`AppBootstrapper:922`/`:948` solo lo NOMBRAN en comentario; ahí se emite `cloudBootSaveDeferredRepeatedly`) |
| `:46` | `cloudkitGroupZoneRecovered` | `SplitSyncManager.swift:477` | **huérfano** |
| `:47` | `cloudkitGroupRecordsRecovered` | `SplitSyncManager.swift:581` | **huérfano** |
| `:48` | `cloudkitGroupRecordSaveRejected` | `SplitSyncManager.swift:1929` | **huérfano** |
| `:49` | `cloudkitGroupEnqueueDroppedNoEngine` | `SplitSyncManager.swift:1001`, `:1011` | **huérfano** |
| `:50` | `groupsIdentityBootMismatch` | `SplitSyncManager.swift:280` | **huérfano** |
| `:114` + wrapper `:344-346` | `inviteReEmittedFromStore` | `AppBootstrapper.swift:1826` | **huérfano** — el fichero sobrevive, pero la función contenedora `reEmitPendingInviteIfNeeded` (`AppBootstrapper.swift:1811-1828`) lee `PendingInviteStore.current()` y llama `processInvite(shareURL:)`: camino CKShare puro |
| `:115` + wrapper `:348-350` | `invitePendingExpired` | `PendingInviteStore.swift:80` | **huérfano** |

**NO se borran — el error a evitar** (el canal backend también los emite):

| Caso | Emisor que MUERE | Emisores que SOBREVIVEN |
|---|---|---|
| `:93` `groupJoinIntentPersisted` | `SplitSyncManager.swift:790` | `AppBootstrapper.swift:1715` (rama backend `extractBackendInvite`) · `GroupBackendInviteEntryHandler.swift:75` |
| `:34` `cloudkitDuplicateDetected` | — | `GroupService.swift:970`, `:1038`, `:1341` · `SplitGroupDeduplicationService.swift:98` · `GroupBridgePreferenceDeduplicationService.swift:86` · `CategoryDeduplicationService.swift:163/244/250/448` |

**Ya muerto HOY, antes de la Fase 3** (hallazgo aparte): `:37 cloudkitBudgetCSVMirrorRebuilt` tiene
**CERO** emisores en TODO el repo (incluyendo docs y `qa/`). Es un caso zombi que sobrevivió a algún
borrado anterior; el compilador no lo caza porque un `case` de enum sin usar es legal.

### a.2 · `GroupsSyncBreadcrumb` — funciones huérfanas (213 líneas hoy, 25 funciones)

| `GroupsSyncBreadcrumb.swift` | Función | Emisor(es) HOY | Veredicto |
|---|---|---|---|
| `:136` (doc `:133`) | `groupsCkEnqueueSkippedBackendGroup` | `SplitZoneManager.swift:30` (`createZone`), `:145` (`createShare`) · `SplitSyncManager.swift:459` (`zoneRecovery`), `:543` (`recordRecovery`), `:1075` (`enqueueSave`), `:1098` (`enqueueDeletion`) | **huérfana** (6/6 emisores mueren) |
| `:151` (doc `:148`) | `groupsCkMigrationMarkerEnqueued` | `SplitSyncManager.swift:1036` | **huérfana** |
| `:160` (doc `:155`) | `groupsCkPullSkippedBackendGroup` | `SplitSyncManager.swift:1309`, `:1611`, `:1673`, `:1984`, `:2080` | **huérfana** |
| `:169` (doc `:164`) | `groupsCkFetchApplyFailed` | `SplitSyncManager.swift:1550`, `:1688` | **huérfana** |
| `:201` (doc `:192`) | `groupsIdentityChangeRetained` | `SplitSyncManager.swift:1503` | **huérfana** |
| `:210` (doc `:207`) | `groupsIdentityChangePurgeFailed` | `SplitSyncManager.swift:1511` | **huérfana** |

**NO se borra, y está EN MEDIO de las huérfanas** — es la trampa estructural de este fichero:

| `:144` | `groupsDrainSkippedNonBackendGroup` | `GroupsSyncClient.swift:663`, `:675`, `:704` | **SOBREVIVE** — la emite el canal backend |

El MARK `// MARK: - Partición POR-GRUPO (G5-A)` (`:131`) contiene **cinco** funciones intercaladas:
4 del transporte (`:136`, `:151`, `:160`, `:169`) y 1 del canal backend (`:144`) justo en segundo lugar.
Borrar el bloque del MARK de un tirón se lleva el diagnóstico del drain del canal que sobrevive.
Es el MISMO molde de trampa que la Fase 1 documentó para el rango del rescate en `SplitSyncManager`
(código muerto mezclado con guard vivo), pero aquí **ningún test lo protege**: los 25 breadcrumbs de
este fichero tienen **0 referencias en `YalaTests/` y `YalaUITests/`** (verificado), y un `logger.notice`
que desaparece no rompe ningún build.

Las **18 funciones restantes** del fichero se emiten desde `GroupsSyncClient.swift`,
`GroupsMerkleClient.swift` y `GroupMerkleProjection.swift` — canal backend, todas sobreviven.

Corolario del MARK de identidad: `// MARK: - Cambio de identidad de iCloud (C-3)` (`:190`) queda
ENTERO huérfano (sus dos únicas funciones son `:201` y `:210`) ⇒ se va la sección completa `189-212`.

### a.3 · Drift de doc detectado al medir

`GroupsSyncBreadcrumb.swift:158` documenta `site` = `applyRemote`/`conflict`/`bridge` para
`groupsCkPullSkippedBackendGroup`. Los valores REALES en HEAD son `zoneDeletion` (`:1309`),
`applyRemote` (`:1611`, `:1673`), `conflict` (`:1984`), `zoneNotFound` (`:2080`). **`bridge` no lo emite
nadie**, y `zoneDeletion`/`zoneNotFound` no están documentados. Irrelevante para el borrado (todo se va),
pero es la señal de que ese doc-comment ya no se mantenía.

En cambio el doc de `groupsCkEnqueueSkippedBackendGroup` (`:135`) es EXACTO: los 6 slugs que lista
(`enqueueSave`/`enqueueDeletion`/`createZone`/`createShare`/`zoneRecovery`/`recordRecovery`) tienen
emisor cada uno.

### a.4 · Daño colateral en la instrumentación de saves

`SplitSyncManager` emite además **12 pares** `SaveBreadcrumb.willSave/didSave` con etiquetas de sitio
`SplitSync.*` (`:1275/:1277`, `:1344/:1346`, `:1498/:1500`, `:1682/:1684`, `:1888/:1890`, `:1972/:1974`,
`:2016/:2018`, `:2043/:2045`, `:2088/:2090`, `:2204/:2206`, más `SplitSyncManager.completeInitialMemberImport`).
`SaveBreadcrumb` como API **sobrevive** (la usa el store personal), pero esas 12 etiquetas desaparecen
del vocabulario de diagnóstico de saves. Relevante porque la regla de `swiftdata-cloudkit.md` presenta
`SaveBreadcrumb` como la red para volver a nombrar el sitio de un crash de restore sin dSYM.

### a.5 · Contabilidad de líneas de MI bloque

| Fichero | HOY | Se va | Queda |
|---|---|---|---|
| `Yala/Services/Metrics/MetricsService.swift` | 451 | ~17 (8 casos `:43-50` + 2 casos `:114-115` + 2 wrappers `:344-350`); 18 si además se retira el zombi `:37` | ~433 |
| `Yala/Services/CloudSync/Groups/GroupsSyncBreadcrumb.swift` | 213 | ~56 (`133-139`, `147-153`, `154-162`, `163-171`, `189-212`) | ~157 |
| **total bloque** | 664 | **~74** | ~590 |

### a.6 · Regresión de observabilidad, declarada

Asimetría medida: el transporte emite **8 canarios** (wire → Analytics Engine, visibles en dashboard).
El canal backend emite desde sus propios ficheros solo **3** (`groupPushRejected`
`GroupsSyncClient.swift:1301`, `groupMerkleDivergence` `:2172`, `groupPushTokenRegisterFailed`
`PushTokenRegistrar.swift:96`); todo su otro diagnóstico son los 25 breadcrumbs OSLog, legibles solo en
Console.app sobre un device. Clase por clase:

- **Moot post-Fase 3** (describen mecánica de `CKSyncEngine` que deja de existir): `cloudkitGroupSyncGateHardCap`, `cloudkitGroupSyncPromotedToAuto`, `cloudkitGroupSyncNoImportPromote`, `cloudkitGroupEnqueueDroppedNoEngine`.
- **Cubierta en el backend**: rechazo definitivo de escritura → `groupPushRejected` (canario) + `groupsPushDeadLettered` (breadcrumb).
- **Baja de canario a breadcrumb**: recuperación de zona/records (`cloudkitGroupZoneRecovered`, `cloudkitGroupRecordsRecovered`) → lo más cercano es `groupsMirrorRehydrated` (breadcrumb, `GroupsSyncClient.swift:961`).
- **SIN equivalente**: `groupsIdentityBootMismatch`. El canal backend resuelve identidad por `sub` con una cadena de fallbacks recién re-cableada (commit `08298365`, 2.6) y **no tiene ningún canario** de desajuste de identidad. Es el hueco más señalable de los 8.

Y hay dos documentos que se quedarían apuntando a un canario sin emisor — **hay que retirarlos en el
mismo commit**, o el próximo incidente se diagnostica con un instrumento muerto:

- `.claude/rules/swiftdata-cloudkit.md:16` — «`cloudkitGroupRecordSaveRejected` en TelemetryDeck es el canario (>0 = incidente de schema/permisos activo)». (Doble drift: TelemetryDeck ya no existe, es `MetricsService`.)
- `docs/modo-nube/MODO-NUBE-GRUPOS-BACKEND-V1-DISENO.md:167` — «el canario `cloudkitGroupRecordSaveRejected` queda vigilando solo la época congelada hasta el retiro».

Riesgo de lectura del gate: el header de `MetricsService.swift:8-9` dice que la condición «canarios en
cero» del encendido se lee del dashboard. Tras la Fase 3, 8 slugs de Grupos son cero **por construcción**,
y la query no puede distinguir «sin incidentes» de «sin emisor» ⇒ un verde que no significa nada.

---

## (b) `qa/coverage-index.json` (2474 líneas)

### b.1 · El área del transporte

| Campo | Valor en HEAD |
|---|---|
| Nombre | **`groups-cross-device-sync`** |
| Rango en el JSON | **líneas 833-880** (48 líneas; el `"area":` está en `:834`) |
| `classification` | **`manual`** |
| `codeGlobs` | **17** |
| `scenarioIDs` | 20 |
| `coverage` | prosa de 5319 caracteres en una sola línea (`:877`) |
| `lastVerified` | `2026-07-29` |

**De los 17 globs, 8 apuntan a ficheros que SOBREVIVEN a la Fase 3:**

| # | Glob | Post-Fase 3 |
|---|---|---|
| 1 | `Yala/Services/Groups/GroupUserIdentityService.swift` | **sobrevive PARCIAL** (el plan conserva `deterministicUUID` + `cachedRecordName`) |
| 2 | `Yala/Services/Groups/SplitGroupDeduplicationService.swift` | **sobrevive** (no está en la lista de borrado) |
| 3 | `Yala/App/ViewModels/GroupsViewModel.swift` | sobrevive |
| 4 | `Yala/App/ViewModels/GroupDetailViewModel.swift` | sobrevive |
| 5 | `Yala/App/Views/Groups/GroupsContainerView.swift` | sobrevive |
| 6 | `Yala/App/Views/Groups/GroupDetailView.swift` | sobrevive |
| 7 | `Yala/App/Views/Groups/GroupRecordsView.swift` | sobrevive |
| 8 | `Yala/Models/SplitGroup.swift` | sobrevive la Fase 3 (la 4 le quita 4 campos) |

**Los 9 que quedan stale:**

`Yala/Services/Groups/SplitSyncManager.swift` · `SplitZoneManager.swift` · `CKRecordTranslator.swift` ·
`CloudKitConstants.swift` · `PendingLeaveShareTracker.swift` · `Yala/App/Logic/SplitSyncStartGate.swift` ·
`GroupsIdentityPurgeGate.swift` · `GroupsIdentityBootGuardLogic.swift` ·
**`GroupAcceptShareErrorLogic.swift`** ← ver b.4.

Nota de contenido: la prosa de `coverage` (`:877`) cita nominalmente `SplitSyncStartGateTests`,
`CloudKitGroupsSchemaParityTests`, `GroupAcceptShareErrorLogicTests`, `GroupsIdentityBootGuardLogicTests`,
`GroupsIdentityPurgeGateTests`, `GroupsIdentityPurgeWiringTests`, `BootSaveGateLogicTests` — **todos** del
transporte. Al borrarlos, el campo `coverage` de esta área se queda casi vacío de sustancia; hay que
reescribirlo, no recortarlo.

### b.2 · La coordenada del plan que está mal: la Fase 1 NO redujo esta área

Medido con `git show 5010db6a^:qa/coverage-index.json` vs `5010db6a` vs `HEAD`:

| | pre-Fase 1 | post-Fase 1 | HEAD |
|---|---|---|---|
| `groups-cross-device-sync` — globs | 17 | **17** | **17** |
| — scenarioIDs | 20 | 20 | 20 |
| — `coverage` (chars) | 4957 | 4865 | 5319 |
| `groups-backend-g6-migration` — globs | **26** | **8** | **8** |

⇒ El área que la Fase 1 **REDUJO** es **`groups-backend-g6-migration`** (líneas 2422-2439, `manual`,
`lastVerified: 2026-07-28`): le quitó **18 globs** (los 7 ficheros de producción + 11 de test de la
maquinaria de migración). `groups-cross-device-sync` — el área del **transporte** — no cambió de
estructura ni en la Fase 1 ni en la Fase 2: solo se le editó la prosa de `coverage`. La premisa de
partida confunde dos áreas distintas.

Detalle útil: `groups-backend-g6-migration` conserva 8 globs y **2 de ellos mueren en la Fase 3**
(`CKRecordTranslator.swift`, `CloudKitConstants.swift`); los otros 6 (`GroupFreezeLogic.swift`,
`GroupCardDisplayLogic.swift`, `GroupCardView.swift`, `SplitMember.swift`, `GroupFreezeGuardTests.swift`,
`GroupCardDisplayLogicTests.swift`) son exactamente lo que la Fase 4 se lleva ⇒ esta área muere a
plazos entre la 3 y la 4.

### b.3 · No es UN área: son CINCO — y una hace FALLAR el validador

El plan trata `qa/coverage-index.json` como un ítem de una línea del Commit 2. Barrí los 134 areas
resolviendo cada glob contra el filesystem: **5 áreas** quedan con globs sin match tras la Fase 3.
Ninguna es `deterministic` (⇒ el ratchet no se dispara), pero una es un **fallo duro**:

| Área | Líneas JSON | Class | Globs stale / total | Consecuencia |
|---|---|---|---|---|
| `groups-cross-device-sync` | 833-880 | manual | **9 / 17** | recortar + reescribir `coverage` |
| **`groups-icloud-availability-gate`** | **965-976** | manual | **2 / 2** | **`codeGlobs` queda VACÍO ⇒ `validate-coverage.py:61-62` es error DURO (`exit 1`)**. Hay que BORRAR el área, no recortarla |
| `groups-pending-approval-reconnect` | 1040-1072 | agentic | 2 / 14 (`PendingInviteStore.swift`, `CKShareEntryHandler.swift`) | recortar |
| `groups-backend-g5-cutover` | 2409-2421 | manual | 1 / 3 (`SplitZoneManager.swift`) | recortar |
| `groups-backend-g6-migration` | 2422-2439 | manual | 2 / 8 | recortar |

`groups-icloud-availability-gate` no es solo un recorte de globs: la FEATURE entera (el gate de «Grupos
necesita iCloud») es exclusiva del canal CloudKit, y su `coverage` apunta a
`YalaTests/GroupsICloudAvailabilityGateLogicTests` (40 líneas), que también se va. Borrar el área es lo
correcto ⇒ y eso **obliga** a tocar `_meta.counts` (b.5), que es justo lo que nadie valida.

### b.4 · Fichero de producción que muere y NO está en la lista de la Fase 3

`Yala/App/Logic/GroupAcceptShareErrorLogic.swift` (**50 líneas**) + `YalaTests/GroupAcceptShareErrorLogicTests.swift`
(**61 líneas**). Sus **únicos dos callsites de producción** son `SplitSyncManager.swift:761` y `:825`
(verificado con grep repo-entero). Al morir `SplitSyncManager` queda código muerto que compila limpio
y con su suite en verde ⇒ nadie lo señala. Es glob de `groups-cross-device-sync` y su reemplazo del
canal backend ya existe (`GroupBackendAcceptErrorLogic.swift`, que se declara «molde de
`GroupAcceptShareErrorLogic` (canal CloudKit)» en su `:6`).

### b.5 · `_meta` — valores actuales y qué hay que ajustar a mano

```
:15   "backlogBaseline": 0
:17   "agenticBacklogBaseline": 5
:30   "counts": {
:31     "total": 134,
:32     "deterministic": 41,
:33     "agentic": 35,
:34     "manual": 58,
:35     "deterministicSinXCUITest": 0
```
(`41 + 35 + 58 = 134` ✓ coherente hoy.)

Salida real del validador en HEAD (`bash qa/validate-coverage.sh`):
`Areas: 134 | deterministic: 41 cubiertas(XCUITest): 41 backlog: 0` → **`RESULT: OK`**, sin ningún
`WARN glob sin match` (el índice está limpio hoy; los 30 WARN son todos `sin scenarioIDs`/`sin lastVerified`).

**Valores objetivo tras la Fase 3** (si se borra `groups-icloud-availability-gate`, que es lo indicado):
`total: 133` · `deterministic: 41` (sin cambio) · `agentic: 35` (sin cambio) · `manual: 57` ·
`deterministicSinXCUITest: 0` · `backlogBaseline: 0` (sin cambio) · `agenticBacklogBaseline: 5` (sin cambio).

**Tres hechos del validador que cambian la naturaleza del riesgo** (leídos en `qa/validate-coverage.py`,
107 líneas):

1. **`_meta.counts` NO se valida en absoluto.** No hay una sola línea que lo lea. Es documentación pura:
   si se olvida, el índice miente y **nada** lo caza — ni el pre-push, ni CI, ni `/gate`. El único que
   lo notaría es un humano comparando con la línea `Areas: N` que el script imprime.
2. **Un glob sin match es solo WARN** (`:70-72`), no bloquea. ⇒ borrar los 9+5 ficheros sin tocar el
   índice **pasa el gate** con 14 warnings que se pierden entre los 30 que ya salen hoy.
3. **`codeGlobs` vacío sí es error DURO** (`:61-62`). Es lo único de mi bloque que BLOQUEA, y afecta a
   una sola área: `groups-icloud-availability-gate`.

Sobre el ratchet: `backlogBaseline = 0` y backlog real `= 0` ⇒ **cero holgura**, pero también cero
exposición en esta fase: ninguna de las 5 áreas afectadas es `deterministic`, y las 41 deterministas
conservan su `coverage: "xcuitest:…"`. El ratchet no se dispara **siempre que el Commit 2 no reclasifique
ni degrade ninguna área determinista**.

### b.6 · Los ficheros de test del transporte, medidos

El plan dice «los 10 ficheros de test del transporte (~2.042, NO VERIFICADO)». Medido:

| Fichero | Líneas |
|---|---|
| `YalaTests/CKRecordTranslatorTests.swift` | 429 |
| `YalaTests/GroupsIdentityPurgeGateTests.swift` | 428 |
| `YalaTests/SplitSyncStartGateTests.swift` | 395 |
| `YalaTests/CloudKitGroupsSchemaParityTests.swift` | 157 |
| `YalaTests/SplitSyncManagerTests.swift` | 136 |
| `YalaTests/PendingInviteStoreTests.swift` | 125 |
| `YalaTests/CKRecordTranslatorSanitizeTests.swift` | 76 |
| `YalaTests/GroupAcceptShareErrorLogicTests.swift` | 61 |
| `YalaTests/GroupsIdentityBootGuardLogicTests.swift` | 52 |
| `YalaTests/GroupsICloudAvailabilityGateLogicTests.swift` | 40 |
| **total** | **1899** |

(≈143 menos que la cifra del plan, que estaba marcada como no verificada.)

Aviso de forma, del mismo tipo que costó la Fase 1: **dos suites hacen source-scan por RUTA** sobre
ficheros que la Fase 3 borra —
`GroupsIdentityPurgeWiringTests` (suite dentro de `GroupsIdentityPurgeGateTests.swift:367`, scans en
`:381`, `:389`, `:402`, `:410`, `:423`) y `CloudKitGroupsSchemaParityTests` (`:43`, lee
`Yala/Services/Groups/CloudKitConstants.swift` vía `#filePath`). Aquí sí hay red: ambas referencian
además los TIPOS borrados (`GroupsIdentityPurgeGate`, `CKConstants`) ⇒ el compilador las señala en el
Commit 1. No es el caso de `HandoverGroupsWiringTests` (`HandoverGroupsDomainTests.swift:309-398`), que
escanea ficheros que **sobreviven pero se recortan** (`ContentView.swift`, `AppBootstrapper.swift`,
`DataWipeService.swift`, `GroupTransactionBridge.swift`): esos scans fallan como **assert rojo**, no
como error de compilación. Revisadas sus 6 aserciones: ninguna cita símbolos del transporte
(`wipeLocalGroupsDomain`, `isDomainOpenForBridge`, `checkHasExistingData`,
`GroupsOutboxMirror()?.purgeAll()`, `purgeGroupsSyncState(`) ⇒ riesgo bajo, pero es la suite a mirar si
sale un rojo raro.

---

## Anexo · coordenadas del plan que NO casan con HEAD

Verificadas por medición directa. Incluyo las marcadas con ✅ («verificado») porque son las peligrosas:
un ✅ desactiva la comprobación del que ejecuta.

| Coordenada del plan | HEAD | Delta |
|---|---|---|
| `SplitSyncManager.swift` **2905** ✅ | **2521** | −384 (la Fase 1 lo recortó DESPUÉS de que se marcara el ✅) |
| `GroupsIdentityPurgeGate.swift` 263 | **253** | −10 |
| `GroupService.propagateBoolCustomKey` en **`:236`** ✅ | **`:246`** | +10 |
| sus 4 callsites: `GroupService:228`, `:308`, `SplitSyncManager:2320`, `:2326` ✅ | `GroupService:238`, `:318`, `SplitSyncManager:2033`, `:2039` | +10 / +10 / −287 / −287 |
| `CKRecordTranslator.swift` 437 · `SplitZoneManager.swift` 308 (+ `deleteZone` en `:58`) · `SplitSyncStartGate.swift` 292 · `CKShareEntryHandler.swift` 151 · `CloudKitConstants.swift` 150 · `PendingInviteStore.swift` 92 · `GroupUserIdentityService.swift` 88 · `PendingLeaveShareTracker.swift` 68 · `GroupsICloudUnavailableView + GateLogic` 94 · `GroupsIdentityBootGuardLogic.swift` 44 | idénticos | ✓ |

Dato colateral de tamaño: «los callsites de `enqueueSave` fuera del fichero» son **25**
(`GroupService.swift` ×18, `GroupExpenseService.swift` ×6, `GroupJoinReconciler.swift:253`) — un ítem de
media línea en el plan que es la superficie de recorte más grande del Commit 1 después del propio
`SplitSyncManager`.

**Y una coordenada que SÍ está exacta, y conviene decirlo** porque
`.claude/rules/swiftdata-cloudkit.md` obliga a comprobarla antes de borrar el emisor del transporte
(orden que evita avisos duplicados): `backendZoneNames` se calcula en `SplitSyncManager.swift:1562`,
descarta records en `:1610` y deletions en `:1672`, y `pendingBridgeChangeSet` no se rellena hasta
`:1723` (el `processRemoteChanges` que lo consume está en `:1752`). Las 4 anclas de la regla siguen
siendo exactas en HEAD ⇒ el invariante «un grupo backend nunca entra en el changeset del transporte»
se puede verificar tal como está escrito.
