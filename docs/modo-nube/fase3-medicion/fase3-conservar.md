# Fase 3 · Bloque «CONSERVAR» — medición contra HEAD `ca06cfd5` (branch 2.0.5)

Todas las cifras salen de `wc -l` / `grep -n` sobre HEAD. Donde el plan
(`$VAULT/Backlog/modo-nube/MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS.md:265-276`) da un número, se
contrasta explícitamente.

## Resumen de coordenadas del plan

| Plan dice | Real en HEAD | Veredicto |
|---|---|---|
| `GroupsIdentityPurgeGate.swift` (263) | **253** | ❌ **STALE**. Eran 263 en `8e666074^`; ese commit dejó neto −10. El plan anota que la extracción ya ocurrió pero **no actualizó el número**. Verificado: `git show 8e666074^:…` → 263, `git show HEAD:…` → 253 |
| `GroupUserIdentityService.swift` (88) | **88** | ✅ |
| `GroupsIdentityBootGuardLogic.swift` (44) | **44** | ✅ |
| `PendingInviteStore.swift` (92) | **92** | ✅ |
| `InviteLinkService` «la parte CloudKit» (sin cifra) | **80 / 270 = 29,6 %** | ⚠️ engañoso: la parte CloudKit es MINORÍA del fichero (ver §b) |
| `belongsToBackendChannel` «ya se extrajo en 2.6» | cierto (`GroupBackendIdentityLogic.swift:63-65`) | ✅ pero **incompleto**: queda MÁS canal backend en el fichero (§d) |
| (regla `.claude/rules`) `groupsBackendCompiledDefault` en CloudSyncFlags`:239` | `:266` | ❌ stale (fuera de mi bloque, se anota de paso) |

**Total que se va en mi bloque: 33 (GroupUserIdentityService) + 80 (InviteLinkService) + 253
(GroupsIdentityPurgeGate) = 366 líneas de producción**, más los recortes de `AppBootstrapper` (§c,
≈150 líneas del camino CKShare) y `GroupsIdentityPurgeGateTests.swift` (428) en el commit 2.

---

## (a) `GroupUserIdentityService.swift` — 88 líneas · `Yala/Services/Groups/GroupUserIdentityService.swift`

### Anatomía: qué muere y qué sobrevive

| Rango | Miembro | Destino | Por qué |
|---|---|---|---|
| `:1-7` | doc de cabecera | **reescribir** | describe el fichero como «fetches the current iCloud user record name» — deja de ser cierto |
| `:9` | `import CloudKit` | **MUERE** | único uso: `CKContainer` en `:32` y `:58` (+`CKConstants.containerID`, y `CloudKitConstants.swift` se borra entero) |
| `:10-11` | `import CryptoKit`, `Foundation` | sobrevive | `deterministicUUID` es CryptoKit puro |
| `:13-16` | `@MainActor final class` + `shared` | sobrevive | |
| `:18` | `defaultsKey = "groups_currentUserRecordName"` | sobrevive | lo leen `:24` y `:49` |
| `:19` | `inflightFetch` | **MUERE** | solo lo usan `currentUserRecordName` y el cancel de `clearCache` |
| `:21` | `cachedRecordName` | **CONSERVAR** (plan) | ver riesgo R1 |
| `:23-25` | `init` | sobrevive | rehidrata `cachedRecordName` de UserDefaults |
| `:27-43` | `currentUserRecordName()` | **MUERE** (17) | `CKContainer(...).userRecordID()` |
| `:45-50` | `clearCache()` | sobrevive **menos `:47-48`** (2) | `:47-48` son el cancel del inflight |
| `:52-59` | `fetchFreshRecordName()` | **MUERE** (8) | CKContainer directo; único consumidor `SplitSyncManager.swift:270` (`runIdentityBootGuard`, que se va con `GroupsIdentityBootGuardLogic`) |
| `:61-68` | `_testSetCachedRecordName` (`#if DEBUG`) | **CONSERVAR** | 10 usos en 3 suites (§consumidores) |
| `:70-73` | `func deterministicMemberID(groupZoneID:)` (instancia) | **YA MUERTO** (4) | **0 callsites en todo el repo** — verificado con `grep -rn "deterministicMemberID(groupZoneID"` y `grep -rn "shared.deterministicMemberID"`: solo aparece su propia definición. Se va gratis |
| `:75-87` | `nonisolated static deterministicUUID` | **CONSERVAR** (plan) | 4 consumidores de producción |

**Muere: 33 líneas (37 %). Sobrevive: 55 (63 %).** No es «un fichero que muere conservando dos
trozos»: es un fichero que sobrevive perdiendo su capa CloudKit.

### Consumidores VIVOS de `deterministicUUID` (si se borra, revienta el canal backend)

| Callsite | Canal | Nota |
|---|---|---|
| `Yala/Services/CloudSync/Groups/GroupBackendIdentityLogic.swift:38` | **BACKEND** | `deterministicMemberID(groupID:memberKey:)` delega aquí. Es la primitiva de identidad del canal nuevo |
| `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:1901` | **BACKEND** | rama `isLegacyMemberKey` de `applyMember`: deriva en el namespace CloudKit-era `"SplitMember"` a propósito, para que el id sea BYTE-IDÉNTICO al del owner en un grupo migrado |
| `Yala/Services/Groups/GroupService.swift:122` | CloudKit (`createGroup`) | muere con el transporte |
| `Yala/Services/Groups/GroupService.swift:928` | CloudKit (`ensureCurrentUserMemberExists`) | muere con el transporte |
| Tests: `YalaTests/CloudSync/GroupBackendIdentityLogicTests.swift:42`, `YalaTests/CloudSync/GroupsSyncClientTests.swift:428`, `YalaTests/GroupJoinReconcilerTests.swift:82` | mixto | `:428` y `:42` son del canal backend (pinean que los dos namespaces NO colisionan) |

⚠️ **Acoplamiento de carpeta:** `GroupBackendIdentityLogic` (canal nuevo, `Yala/Services/CloudSync/Groups/`)
depende de una clase en `Yala/Services/Groups/` (carpeta CloudKit-era). El criterio de salida de la
Fase 3 es `grep -r "import CloudKit" Yala/Services/Groups/ Yala/App/Views/Groups/` → 0: se cumple sin
mover el fichero, porque el `import CloudKit` se va en `:9`. Pero queda una primitiva del canal nuevo
viviendo en la carpeta del viejo.

### Consumidores VIVOS de `cachedRecordName`

| Callsite | Canal | Muere en Fase 3? |
|---|---|---|
| `Yala/App/Services/GroupBackendInviteEntryHandler.swift:127` | **BACKEND** | NO — `legacyMemberKeyForRejoin`, 2º fallback del re-join de grupo migrado (G6-2) |
| `Yala/Services/Groups/GroupExpenseService.swift:614` | **BACKEND+CK** | NO — `selectCurrentUserMemberID`, fallback #3 |
| `Yala/App/Views/Groups/GroupSettingsView.swift:704` | **BACKEND+CK** | NO — `hasOutstandingBalance` (decide si se le deja archivar/salir) |
| `Yala/Services/Groups/GroupJoinReconciler.swift:293` | **BACKEND+CK** | NO — `currentUserMemberExists` |
| `Yala/Services/Groups/GroupService.swift:1019` | **BACKEND+CK** | `refreshCurrentUserFlags` sobrevive (2.6 la re-cableó); su bloque de backfill CloudKit `:1055-1100` muere |
| `Yala/Services/Groups/SplitSyncManager.swift:265` | CloudKit | sí (boot-guard) |
| `Yala/Services/Groups/SplitSyncManager.swift:1649` | CloudKit | sí (`MemberChangeNotificationLogic.classifyNewMember`) |

### 🔴 R1 — EL RIESGO MAYOR DE TODO MI BLOQUE: `cachedRecordName` queda escrito por NADIE

`UserDefaults.standard.set(name, forKey: defaultsKey)` en **`GroupUserIdentityService.swift:41`** es
el **ÚNICO escritor** de la key `groups_currentUserRecordName` en todo el repo (verificado:
`grep -rn "groups_currentUserRecordName" --include="*.swift"` → 1 definición + 2 comentarios; y las
únicas escrituras de la propiedad en memoria son `:24` init, `:40`, `:46` (nil) y `:66` (DEBUG)).

Y esa línea está **DENTRO de `currentUserRecordName()`**, que el plan manda borrar.

⇒ «Conservar `cachedRecordName`» tal cual deja una propiedad **write-once-never**:

* device que viene de un build ≤ Fase 3 → la key ya está persistida ⇒ sigue funcionando;
* **instalación FRESCA (o cualquier device tras `clearCache()`) → `cachedRecordName` es `nil` PARA SIEMPRE.**

Los 4 consumidores backend de arriba caen a rama muerta **en silencio**, y ninguna de las tres
señales de alarma dispara:

1. **compila**: la propiedad existe, los callsites siguen válidos;
2. **los tests siguen VERDES, y activamente lo TAPAN**: las 3 suites que ejercitan estos fallbacks
   inyectan por `_testSetCachedRecordName` (`YalaTests/GroupServiceCurrentUserFlagsTests.swift:58`,
   `YalaTests/GroupJoinReconcilerTests.swift:31`, `YalaTests/CloudSync/GroupsSyncClientTests.swift:572/617/659`)
   — nunca pasan por el escritor real, así que la propiedad *parece* viva;
3. **el degradado solo se ve en instalaciones nuevas**, la población que nadie QA-ea porque el
   QA de upgrade siempre arranca de un container que ya tiene la key.

Consecuencias concretas del `nil` permanente:
* `legacyMemberKeyForRejoin` (`GroupBackendInviteEntryHandler.swift:127`) pierde su 2º fallback ⇒
  **todo re-join de grupo migrado entra como member NUEVO** en devices frescos. Hoy eso es el
  residual §9.3b «device fresco sin ninguno → nil»; tras la Fase 3 pasa a ser el caso GENERAL.
* `GroupService.refreshCurrentUserFlags` (`:1019-1028`): el `else` cae a `currentUserRecordName()`
  (borrado) ⇒ `recordName` queda `""` ⇒ `guard !recordName.isEmpty || backendCanResolve` (`:1029`)
  **retorna temprano si no hay sesión Nube** ⇒ ningún `SplitMember` recibe `isCurrentUser`. Con
  sesión sigue resolviendo por `sub`, así que el daño está acotado a «sin sesión Nube», pero es el
  mismo fallo que 2.6 acaba de arreglar en el sentido contrario.
* `selectCurrentUserMemberID` / `hasOutstandingBalance` / `currentUserMemberExists` pierden su
  fallback iCloud; sobreviven por el fallback `sub` (que 2.6 puso ANTES), así que degradan sin romper
  **siempre que haya sesión Nube**.

**Decisión que el plan no toma y hay que tomar:** o (i) se conserva un escritor de la key (una
variante mínima de `currentUserRecordName()` con `CKContainer`, lo que contradice el criterio
`import CloudKit → 0` en `Yala/Services/Groups/`), o (ii) se acepta el `nil` permanente y entonces
hay que **borrar los 4 fallbacks iCloud junto con el resto** en vez de dejarlos como código
inalcanzable, o (iii) el escritor pasa a ser el canal backend (persistir ahí el recordName ya no
tiene sentido — la identidad es el `sub`). **(ii) es lo coherente con la Fase 3**, pero exige tocar
`GroupBackendInviteEntryHandler`, `GroupExpenseService`, `GroupSettingsView`, `GroupJoinReconciler`
y sus tests, que el plan NO lista.

### R2 — `clearCache()` se queda sin hogar

Su único consumidor es `SplitSyncManager.swift:1466`, dentro de `resetLocalGroupsSyncState()`
(`:1463-1475`) — y **`SplitSyncManager.swift` se borra entero (2.905 líneas)**. Pero
`resetLocalGroupsSyncState` es el default del seam `resetSyncState` de
**`DataWipeService.wipeLocalGroupsDomain` (`Yala/Utils/DataWipeService.swift:269-271`)**, el camino
VIVO de handover «empiezo de cero», pineado por `YalaTests/HandoverGroupsDomainTests.swift:90-95` y
`:395`. Alguien tiene que re-hospedar ese seam (o el fichero entero de la purga de identidad
cacheada) o el borrado de `SplitSyncManager` rompe el handover. El comentario de
`DataWipeService.swift:328` («`groups_currentUserRecordName` NO se toca aquí a propósito: la borra
`clearCache()` del `resetSyncState`») queda mintiendo si se pierde la cadena.

---

## (b) `InviteLinkService.swift` — 270 líneas · `Yala/Services/Groups/InviteLinkService.swift`

**El 70 % del fichero SOBREVIVE.** Solo 80 líneas (29,6 %) son CloudKit.

| Rango | Miembro | Destino | Consumidores |
|---|---|---|---|
| `:9` | `import CloudKit` | **MUERE** | solo `fetchShareMetadata` (`CKShare.Metadata`, `CKFetchShareMetadataOperation`, `CKContainer`) |
| `:14` | `host` | **sobrevive** | `buildBackendInviteURL:87/112` |
| `:15` | `path` | **sobrevive** | `buildBackendInviteURL:88/114`, `extractBackendInvite:142`, `isInviteLink:226` |
| `:17-25` | `alternateHosts` | **sobrevive** | `extractBackendInvite:141`, `isInviteLink:225` |
| `:27-67` (41) | `buildInviteURL(shareURL:group:members:inviterName:)` | **MUERE** | `GroupDetailViewModel.swift:471` (rama CKShare de `createShareLink`) · `GroupMembersView.swift:486`. Ambos son la rama `else` del `if groupsBackendEnabled && group.isBackendGroup` |
| `:69-126` (58) | `buildBackendInviteURL` | **CONSERVAR** | `GroupBackendInviteService.swift:41` · `YalaTests/GroupBackendInviteParserTests.swift:85/113` |
| `:128-159` (32) | `extractBackendInvite` | **CONSERVAR** | `AppBootstrapper.swift:1706` · 12 aserciones en `GroupBackendInviteParserTests` |
| `:161-167` (7) | `backendPair` (private) | **sobrevive** | lo usa `extractBackendInvite` ×2 |
| `:169-189` (21) | `extractShareURL` | **MUERE** | único callsite de producción: **`AppBootstrapper.swift:1733`** (el guard de §c) + `YalaTests/InviteLinkServiceTests.swift:82/93` |
| `:191-202` (12) | `struct BrandedMetadata` | **sobrevive** | **backend**: `GroupBackendInviteEntryHandler.swift:68`, `AppBootstrapper.swift:1721`. Mueren: `PendingInviteStore.swift:26/31/41`, `CKShareEntryHandler.swift:36`, `AppBootstrapper.swift:1854/1869` |
| `:204-217` (14) | `extractMetadata` | **sobrevive** | **backend**: `AppBootstrapper.swift:1721`. Muere: `:1741` |
| `:219-229` (11) | `isInviteLink` | **sobrevive — y es el guard REAL** | `YalaAppDelegate.swift:94`, `AppBootstrapper.swift:1637`, `InviteRecoveryView.swift:29/129/141`. TODOS vivos en el canal backend. 12 tests en `InviteLinkServiceTests:18-67` |
| `:231-247` (17) | `fetchShareMetadata` | **MUERE** | `AppBootstrapper.swift:1872` · `GroupJoinIntentTracker.swift:130` (rama `.acceptFailed` del retry, que muere con `PendingInviteStore`) |
| `:249-256` | `base64URLEncode` (private) | **sobrevive** | `buildBackendInviteURL:96` |
| `:258-269` | `base64URLDecode` (private) | **sobrevive** | `extractBackendInvite:151` (fallback por `s`) |

**Corolario de forma:** tras el borrado el fichero deja de ser «servicio de invite links de CKShare
con un anexo backend» y pasa a ser «servicio de invite links del canal backend». Los MARK
`// MARK: - Build (backend, G4 DARK)` / `// MARK: - Extract (backend, G4 DARK)` y las etiquetas
«DARK: sin call-sites de UI hoy» (`:76`) quedan obsoletas — hoy SÍ tiene callsite
(`GroupBackendInviteService.swift:41` ← `GroupDetailViewModel.swift:442`).

---

## (c) El guard de `AppBootstrapper` — `Yala/App/AppBootstrapper.swift:1733`

```
1733:        guard let shareURL = InviteLinkService.extractShareURL(from: url) else {
1734:            logger.error("Invalid invite link: \(url.absoluteString, privacy: .public)")
1735:            RouterEntryGate.shared.submit(.showInviteError(
1736:                String(localized: "groups.invite.linkInvalidDetail")
1737:            ))
1738:            return
1739:        }
```

### El plan nombra UN guard; en realidad son TRES capas, y `:1733` NO es la primera

| Capa | Coordenada | Qué exige | Efecto |
|---|---|---|---|
| **1** | `AppBootstrapper.swift:1637` (`if InviteLinkService.isInviteLink(url)`), `YalaAppDelegate.swift:94`, `InviteRecoveryView.swift:29`/`:129`/`:141` | `isInviteLink` (`:222-229`) exige `hasShareParam` — **el parámetro `s` en CUALQUIER link** | **ESTE es el «usa `s` como validez de cualquier link»**. Un link backend solo pasa porque `buildBackendInviteURL` mete un `s` SINTÉTICO a propósito (`:73-76`) |
| **2** | `AppBootstrapper.swift:1705-1731` | `CloudSyncFlags.groupsBackendEnabled` **&&** `extractBackendInvite != nil` → handler backend + `return` | con el flag ON un link backend **jamás llega a `:1733`** |
| **3** | `AppBootstrapper.swift:1733` | `extractShareURL != nil`, si no → alert `groups.invite.linkInvalidDetail` | rechaza cualquier cosa que no sea CKShare |

### Qué hay que reescribir, en orden de peligro

1. **La condición del flag en `:1705` tiene que caer o invertirse.** Si se borra el cuerpo de `:1733`
   dejando `if CloudSyncFlags.groupsBackendEnabled, let backendInvite = …`, un device con el flag
   **OFF** (que es **todo device de producción hoy**: `groupsBackendCompiledDefault = false`,
   `Yala/Services/CloudSync/CloudSyncFlags.swift:266`) **no evalúa el parser** y cae a un `guard` que
   ya no existe ⇒ `handleInviteLink` **no hace NADA, sin log y sin alert**. Es exactamente el
   «apagón silencioso que no falla al compilar» del que avisa la Fase 3.
2. **El `else` del error tiene que re-anclarse al parser backend**: `if let backendInvite = extractBackendInvite(from: url) { … } else { logger.error + showInviteError }`. El copy
   `groups.invite.linkInvalidDetail` se conserva (sirve igual para un link backend malformado).
3. **`isInviteLink` debe SEGUIR exigiendo `s`.** Es un par ACOPLADO con el AASA, que vive en OTRO
   repo-de-verdad y se despliega aparte (Vercel): `Web/public/.well-known/apple-app-site-association`
   declara `"?": { "s": "*" }` (verificado). Relajar `isInviteLink` sin tocar el AASA no gana nada
   (iOS no enruta links sin `s`); relajar el AASA sin tocar `isInviteLink` hace que lleguen y se
   descarten. Y el peligro real es el inverso: alguien que «limpie» el `s` redundante de
   `buildBackendInviteURL` (`:84-96`, se ve como cosmético una vez muerto el CKShare) **rompe los
   universal links de toda la base instalada**. Ese porqué está hoy en el doc de `:73-76`; hay que
   moverlo a la regla durable, porque el fichero que lo explica pierde su contexto CKShare.
4. **La cola de deferral pre-bootstrap es DOBLE y solo una mitad sobrevive.** El camino backend tiene
   la suya (`:1707-1720`, `GroupBackendInviteEntryHandler.persistIntent`); la CKShare usa
   `PendingInviteStore` (`:1747-1755`), y `PendingInviteStore.swift` (92) está en la lista de
   ficheros a borrar. Se van con él: `reEmitPendingInviteIfNeeded` (`:1811-1828`),
   `shouldReEmitInvite` (`:1834-1841`), `isInviteIntent` (`:1844-1849`), `processInvite`
   (`:1854-1861`), `acceptShareFromURL` (`:1867-1897`), `isRecoverableInviteFetchError` (`:1903+`),
   `InviteRouteDecision` (`:1762-1770`) + `inviteRouteDecision` (`:1780-1806`), y el flag
   `isProcessingInvite`. ≈150 líneas de `AppBootstrapper`. **Cuidado**:
   `GroupJoinIntentTracker.swift:130` y `AppBootstrapper.isRecoverableInviteFetchError` se referencian
   entre sí desde otro fichero (`GroupJoinIntentTracker.swift:135`).
5. **La entrada por PEGADO MANUAL comparte el guard**: `InviteRecoveryView` (rama C del Welcome
   Chooser) valida SOLO con `isInviteLink` (`:29`, `:129`, `:141`) y entrega la URL a
   `ContentView.swift:341` → `AppBootstrapper.shared.handleInviteLink(url)`. O sea, todo lo de
   arriba aplica también al camino sin universal link — que es el que NO sigue redirects HTTP y por
   eso existe `alternateHosts`.

---

## (d) `GroupsIdentityPurgeGate.swift` — **253** líneas (plan: 263) · `Yala/App/Logic/GroupsIdentityPurgeGate.swift`

`belongsToBackendChannel` sí está fuera (`GroupBackendIdentityLogic.swift:63-65`, commit `8e666074`).
**Pero queda bastante más canal backend en el fichero.** `decideForZone` es la parte LIMPIA; el
problema está en el adaptador y en los consumidores.

### `decideForZone` (`:108-119`) y sus consumidores

| Consumidor | Coordenada | Nota |
|---|---|---|
| `decide` (conveniencia 1 fila) | `:122-126` | solo lo usan los tests (`GroupsIdentityPurgeGateTests.swift:267-281`) |
| `apply` | `:169-173` | único consumidor de producción de la decisión |
| tests | `GroupsIdentityPurgeGateTests.swift:267-284` | 9 aserciones sobre `decide` + 1 sobre `decideForZone` |
| **producción, indirecto** | `SplitSyncManager.swift:1497` → `GroupsIdentityPurgeGate.apply(in: modelContext)` | **el ÚNICO callsite de producción del fichero entero** |

Su única dependencia backend restante es la llamada a `belongsToBackendChannel` en `:115-116`. Eso
está resuelto. ✅

### Lo que el plan NO menciona: 4 piezas más del canal backend en este fichero

| Pieza | Coordenada | Por qué es del canal BACKEND |
|---|---|---|
| Seam `hasCloudSession` con default real | `:156` → `CloudAuthService.shared.hasSession` | la sesión de la cuenta **Yala**, no iCloud. **Pineado por source-scan**: `YalaTests/GroupsIdentityPurgeGateTests.swift:423-427` (`theGateDefaultsToTheRealSessionAndTheRealJoinStore`) exige el literal `hasCloudSession: @MainActor () -> Bool = { CloudAuthService.shared.hasSession }` |
| Seam `revokePendingJoinCredential` | `:157-159` + `:199` → `PendingJoinStore.revokeLegacyMemberKey(zoneName:)` (`Yala/Services/Groups/PendingJoinStore.swift:174`, 215 líneas, **NO está en la lista de borrados del plan**) | revoca la credencial de re-join del canal backend. Mismo test source-scan lo pinea con el literal `PendingJoinStore.revokeLegacyMemberKey(zoneName: $0)` |
| Rama `.retainRevokingRejoinCredentials` completa | `:176-199` (24 líneas) — `row.backendReInviteToken = nil` (`:185`), `row.rejoinRevokedAt = revokedAt` (`:187`) | es la **única implementación en el repo** de «revocar las credenciales de re-join del canal backend de una zona». La lee `GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin` (`:112`, `guard group.rejoinRevokedAt == nil`) — consumidor **VIVO del canal backend** |
| Contadores + breadcrumb de retención | `:135-143` + caller `SplitSyncManager.swift:1503-1509` (`GroupsSyncBreadcrumb.groupsIdentityChangeRetained`) | telemetría del canal backend |

Lo único puramente CloudKit dentro de la rama de retención es el re-armado de `markerEnqueuedFlag`
(`:191-193`), porque el marcador vivía en `engine.state`.

### 🟠 R3 — borrar el fichero borra también la MITAD que BORRA (regresión de `31dded30`)

Las tres entradas del gate son CloudKit y se van todas:

* `SplitSyncManager.handleAccountChange(.signOut)` — `:1367` (evento de CKSyncEngine)
* `SplitSyncManager.handleAccountChange(.switchAccounts)` — `:1380`
* `SplitSyncManager.runIdentityBootGuard()` — `:254-282`, y **ya está inerte con el flag ON**
  (`guard !CloudSyncFlags.groupsBackendEnabled else { return }`, `:265`)

⇒ tras la Fase 3 **no queda NINGÚN camino automático que purgue el dominio Grupos cuando cambia el
Apple ID del OS**. Para el canal backend eso es correcto por diseño (D1: la identidad es el `sub`).
Para las filas CloudKit-era que sobrevivan localmente **no lo es**: `case .deleteLocalRows` (`:201-207`)
y `deleteRows` (`:222-252`, 31 líneas) se van con el fichero, y son lo que hoy garantiza que los
grupos del humano ANTERIOR no queden visibles en la lista del nuevo — el fix de `31dded30`. El único
camino que queda es el explícito «empiezo de cero» del Welcome
(`DataWipeService.wipeLocalGroupsDomain`), que **no pasa por este gate** y depende de que el usuario
lo elija. Y el propio docblock del gate ya avisa de que un handover por la vía del OS **sin** pasar
por el Welcome es alcanzable (`:34-41`, residual D4 ratificado por el owner).

Decisión que hay que tomar antes de borrar: o se acepta que las filas CloudKit-era huérfanas queden
locales (defendible: sin engine ya no sincronizan, y la Fase 4 borra su schema), o hay que conservar
`deleteRows` bajo otro dueño. **No es un no-op**, y el plan lo trata como si el fichero muriera
entero sin consecuencias.

### Nota de tests

`YalaTests/GroupsIdentityPurgeGateTests.swift` son **428 líneas**: 11 tests de comportamiento sobre
`apply` (`:80-350`) + 10 aserciones de decisión pura (`:267-284`) + un suite de **cableado
source-scan** (`GroupsIdentityPurgeWiringTests`, `:366-428`) con 5 tests que leen el TEXTO de
`SplitSyncManager.swift` y de `GroupsIdentityPurgeGate.swift`. Esos 5 **fallarán al borrar el
transporte** (buscan literales como `"GroupsIdentityPurgeGate.apply(in: modelContext)"`,
`"case .signOut:"`, `"private func recreateEnginesAfterIdentityChange()"`,
`"guard !(group.isBackendGroup || group.isMigratedFrozen) else {"`) — y fallarán **leyendo un
fichero que ya no existe**, o sea con un error de I/O, no con un mensaje que explique nada. Hay que
borrarlos en el commit 2 del mismo lote, no dejarlos «para después».

---

## Checklist de conservación (lo mínimo que NO se puede borrar)

```
Yala/Services/Groups/GroupUserIdentityService.swift
  :21   cachedRecordName            ← 4 consumidores backend VIVOS (pero ver R1: nadie lo escribirá)
  :23-25 init                        ← única rehidratación que queda
  :45-46,:49-50 clearCache           ← seam del handover (ver R2)
  :61-68 _testSetCachedRecordName    ← 10 usos en 3 suites
  :75-87 deterministicUUID           ← GroupBackendIdentityLogic:38 + GroupsSyncClient:1901

Yala/Services/Groups/InviteLinkService.swift
  :14-25  host / path / alternateHosts
  :69-126 buildBackendInviteURL      ← GroupBackendInviteService:41
  :128-167 extractBackendInvite + backendPair ← AppBootstrapper:1706
  :191-217 BrandedMetadata + extractMetadata  ← GroupBackendInviteEntryHandler:68, AppBootstrapper:1721
  :219-229 isInviteLink              ← 5 callsites; su exigencia de `s` está acoplada al AASA
  :249-269 base64URLEncode/Decode

Yala/Services/CloudSync/Groups/GroupBackendIdentityLogic.swift  (entero — canal nuevo)
Yala/Services/Groups/PendingJoinStore.swift                     (entero — NO está en el plan)
Yala/App/Services/GroupBackendInviteEntryHandler.swift           (entero, 267 líneas)
Yala/Services/CloudSync/Groups/GroupBackendInviteService.swift   (entero, 55 líneas)
SplitGroup.rejoinRevokedAt / backendReInviteToken                ← los lee legacyMemberKeyForRejoin
```

## Ranking de riesgos de mi bloque

1. **R1** (`cachedRecordName` sin escritor) — silencioso, compila, los tests lo TAPAN por inyección,
   degrada solo instalaciones frescas. Es el peor de los tres.
2. **R3** (se va la mitad que borra ⇒ regresión de `31dded30` para filas CloudKit-era).
3. **§c.1** (el flag `groupsBackendEnabled` en `:1705` deja `handleInviteLink` mudo con flag OFF).
4. **R2** (`clearCache` pierde hogar ⇒ rompe el handover pineado).
5. **§c.3** (el `s` sintético parece cosmético y su borrado rompe universal links de la base instalada).
