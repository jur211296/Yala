---
created: 2026-08-04
updated: 2026-08-04
tags: [modo-nube, grupos, fase3, medicion, chip-a1]
status: active
---

# Fase 3 — re-medición completa contra HEAD (chip A1)

**Medido el 2026-08-04 contra `dbb0bab3`** (rama `2.0.5`, árbol limpio, `origin/2.0.5` sincronizado).
Sustituye como fuente de coordenadas a `MODO-NUBE-FASE3-BRIEF.md` y a los 8 informes de esta carpeta,
que se midieron el **2026-07-29 contra `ca06cfd5`**. Ninguna cifra de aquí se hereda: todas llevan el
comando que las produce y todas las rutas se resolvieron por `find`, nunca por la ruta de un documento.

**Objetivo:** que el commit 1 (producción, atómico e indivisible) se pueda escribir sin re-descubrir nada.

> **El HEAD del encargo ya no es el HEAD.** El chip A1 fijaba `267690a7`. Durante la medición entró
> `dbb0bab3` (`docs(nube): el repo decía «pendiente de verificar en device» y ya no lo está`), que es el
> chip C1: **1 fichero, `.md`, +81/−0**. `git rev-list --count 267690a7..HEAD` → `1`. No mueve ni una
> coordenada de código. Todo lo de abajo está anclado en `dbb0bab3`.

**Método.** 8 mediciones independientes en paralelo (una por apartado) + refutación adversarial de los 4
apartados con coste (recortes, consumidores nuevos, apagones, tests), más verificación propia de los
hallazgos caros. Los refutadores tumbaron **24 afirmaciones** y señalaron **42 omisiones**; lo refutado
**no** se propaga a este documento, y lo que sobrevivió con matices lleva el matiz escrito.

---

## 0 · La ventana ciega es tres veces mayor de lo que se creía

| | Se creía | Medido |
|---|---|---|
| Commits desde el baseline del brief (`ca06cfd5`) | «~29 entre el 30/07 y el 04/08» | **84** |
| Commits desde el último toque del brief (`b422565e`, 2026-07-30 14:26) | — | **61** |
| Commits desde el congelado de los 8 informes (`c4ec5cd9`, 2026-07-29 14:19) | — | **83** |

```bash
git rev-list --count ca06cfd5..HEAD
```

Los 8 informes de esta carpeta se escribieron en **una sola corrida** y no se han vuelto a tocar nunca.

**Y la consecuencia que importa más que el número:** la heurística que el brief da por buena —«solo
derivan las coordenadas del fichero que se editó»— **se confirma para la deriva** (comprobada sobre 8
ficheros con 0 commits desde `ca06cfd5`: las 8 coordenadas siguen exactas) **y es ciega para las altas**.
Desde `ca06cfd5` hay **15 ficheros de producción nuevos** bajo `Yala/`, **11 de ellos tocan este
subsistema**, y un fichero nuevo no tiene coordenada vieja que derivar. Usar la heurística como criterio
de suficiencia es lo que dejó fuera del brief todo el apartado 3 de este documento.

```bash
git diff --name-status --diff-filter=A ca06cfd5..HEAD -- Yala/
```

Segundo matiz, dentro de un fichero que **sí** se editó: la deriva **no es un desplazamiento uniforme**.
En `GroupService.swift` los 18 `enqueueSave` derivan entre **+5 y +128**. Restar un offset constante no
funciona: hay que re-localizar símbolo a símbolo.

---

## 1 · Los 14 ficheros que el commit 1 borra enteros

Las 14 rutas y sus tamaños **se confirman exactos**, cero discrepancias. `find` devolvió **una sola ruta
por nombre** en los catorce casos: ningún homónimo en `Yala/Services/CloudSync/Groups/` (15 ficheros, la
casa del canal nuevo, **todos supervivientes**) colisiona con estos.

| Líneas | Ruta real (resuelta por `find`) | Δ vs. informe del 29/07 |
|---:|---|---:|
| 2.907 | `Yala/Services/Groups/SplitSyncManager.swift` | **+386** |
| 415 | `Yala/Services/Groups/CKRecordTranslator.swift` | −22 |
| 308 | `Yala/Services/Groups/SplitZoneManager.swift` | 0 |
| 256 | `Yala/App/Logic/GroupsIdentityPurgeGate.swift` | +3 |
| 151 | `Yala/App/Services/CKShareEntryHandler.swift` | 0 |
| 149 | `Yala/App/Logic/SplitSyncStartGate.swift` | **−143** |
| 144 | `Yala/Services/Groups/CloudKitConstants.swift` | −6 |
| 92 | `Yala/Services/Groups/PendingInviteStore.swift` | 0 |
| 85 | `Yala/Services/Groups/GroupUserIdentityService.swift` | −3 |
| 68 | `Yala/Services/Groups/PendingLeaveShareTracker.swift` | 0 |
| 61 | `Yala/App/Views/Groups/GroupsICloudUnavailableView.swift` | 0 |
| 44 | `Yala/App/Logic/GroupsIdentityBootGuardLogic.swift` | 0 |
| 33 | `Yala/App/Logic/GroupsICloudAvailabilityGateLogic.swift` | 0 |
| 31 | `Yala/App/Logic/SoftDeleteObserverLogic.swift` | *(no estaba en la tabla del 29/07)* |
| **4.744** | **total** | **+246 sobre 4.498** |

**Son 14, no 13.** El brief dice «los 13 ficheros» en su partición de commits (`:348`) aunque detecte
`SoftDeleteObserverLogic` por separado como hallazgo S6. La lista de 14 es la correcta.

**Solo 7 de las 14 están en `Yala/Services/Groups/`**: cinco viven en `Yala/App/Logic/`, una en
`Yala/App/Services/`, una en `Yala/App/Views/Groups/`.

**El fichero que la Fase 3 borra creció 386 líneas mientras esperaba a que lo borraran.**
`git diff --stat ca06cfd5 HEAD -- <los 14>` → `6 files changed, 494 insertions(+), 279 deletions(-)`.

### 1.1 · Los dos «no son borrado entero» que el commit 0 resolvió — verificados

| Fichero | Qué escondía | Estado hoy |
|---|---|---|
| `SplitSyncStartGate.swift` | `BootSaveGateLogic` + `WaitResolution` + `resolveWaitByQuiescence` | **RESUELTO**: viven en `Yala/App/Logic/BootSaveGateLogic.swift` (169 líneas). Borrable entero |
| `CloudKitConstants.swift` | `zonePrefix` + `zoneName(for:)` | **RESUELTO**: viven en `Yala/Models/SplitGroupZone.swift` (**42** líneas, no 32 como dice el brief `:310`) |

### 1.2 · `GroupUserIdentityService.swift` — el único que sigue sin ser borrado entero, y el brief lo describe mal

El brief y el chip dicen «conserva `deterministicUUID` + `cachedRecordName`». **Medido, son cinco los
miembros con consumidor superviviente en producción, no dos.**

```bash
grep -n "func \|var \|static let " Yala/Services/Groups/GroupUserIdentityService.swift
grep -rn "GroupUserIdentityService" Yala/ YalaWidgets/ YalaShare/
```

| Miembro | Línea | Consumidores supervivientes | Destino |
|---|---:|---|---|
| `shared` | 22 | — | **conservar** (es el singleton) |
| `cachedRecordName` | 24 | `GroupBackendInviteEntryHandler`, `GroupSettingsView`, `GroupExpenseService`, `GroupJoinReconciler`, `GroupService` | **conservar** |
| `currentUserRecordName()` | 34 | `GroupService.swift:140`, `:947`, `:1125` + `GroupICloudIdentitySeed` | **conservar** (ya es fachada que delega en el seed) |
| `applySeededRecordName()` | 40 | `GroupICloudIdentitySeed.swift:106` — **el canal NUEVO** | **conservar** |
| `clearCache()` | 44 | `GroupICloudIdentitySeed.swift` | **conservar** |
| `fetchFreshRecordName()` | 54 | único caller `SplitSyncManager.swift:333` — **muere** | **borrable** |
| `_testSetCachedRecordName` | 62 | 6 suites de test | **conservar** (seam) |
| `deterministicMemberID` | 67 | **cero call-sites reales** (ya muerto antes de la Fase 3) | **borrable** |
| `deterministicUUID` | 74 | `GroupBackendIdentityLogic.swift:38`, `GroupsSyncClient.swift:2499` | **conservar** |

⇒ **de las 85 líneas, lo que muere son 2 miembros.** `fetchFreshRecordName` usa
`CKContainer(identifier: CKConstants.containerID)`, así que muere **forzado** por la desaparición de
`CloudKitConstants.swift` — y su único caller muere el mismo día. Coincidencia afortunada que nadie
había verificado.

### 1.3 · Cuál es el trabajo real: los acoplamientos, no los imports

**Cuatro de los catorce tienen CERO acoplamiento de código con producción superviviente**
(`CKRecordTranslator`, `GroupsIdentityPurgeGate`, `GroupsIdentityBootGuardLogic`,
`SoftDeleteObserverLogic`), y `SplitSyncStartGate` es el quinto. Borrarlos no obliga a un solo recorte
de código: solo dejan comentarios apuntando al vacío.

El epicentro es `SplitSyncManager`: **45 call-sites de código en 14 ficheros supervivientes**.

---

## 2 · Los recortes en ficheros que sobreviven

**La línea base del 29/07 era correcta** — 10 de 10 tamaños exactos contra `ca06cfd5`. Lo que la invalida
es lo escrito después.

### 2.1 · `propagateBoolCustomKey` — las 5 coordenadas derivaron, la corrección semántica aguanta

| Coordenada | 29/07 | **HOY** | Δ |
|---|---|---|---:|
| definición | `GroupService:246` | **`GroupService.swift:291`** | +45 |
| callsite `setArchived` | `GroupService:238` | **`:283`** | +45 |
| callsite `softDelete` | `GroupService:318` | **`:363`** | +45 |
| callsite `handleConflict` | `SplitSyncManager:2033` | **`:2350`** | +317 |
| callsite `handleConflict` | `SplitSyncManager:2039` | **`:2356`** | +317 |

**Siguen siendo 2 recortes, no 4**: los dos de `SplitSyncManager` viven dentro de `handleConflict`
(hoy `:2258`) y mueren gratis con el fichero. El riesgo se confirma sin cambios: `propagateBoolCustomKey`
se construye su propio `CKContainer` en `:294` ⇒ **el compilador no lo caza**, y es el único write a
`privateCloudDatabase` que no pasa por `CKSyncEngine`.

### 2.2 · `enqueueSave` / `enqueueDeletion` — 29 llamadas reales en 3 ficheros supervivientes

```bash
grep -rn "\.enqueueSave(\|\.enqueueDeletion(" Yala/ --include="*.swift" | grep -v "Groups/SplitSyncManager.swift"
```

| Fichero | `enqueueSave` | `enqueueDeletion` |
|---|---|---|
| `Yala/Services/Groups/GroupService.swift` | 18 — `172, 233, 258, 280, 346, 408, 459, 513, 546, 592, 977, 999, 1036, 1088, 1209, 1220, 1261, 1305` | 0 |
| `Yala/Services/Groups/GroupExpenseService.swift` | 6 — `109, 119, 194, 204, 429, 468` | 4 — `169, 256, 270, 501` |
| `Yala/Services/Groups/GroupJoinReconciler.swift` | 1 — `253` | 0 |

El brief decía «~30 en 3 ficheros»: **correcto**. **Confirma la indivisibilidad del commit 1.**

### 2.3 · La superficie externa de `SplitSyncManager` creció en 4 símbolos

Los cuatro son **altas posteriores al 29/07** y ninguno está en el brief:

| Símbolo nuevo | Coordenada |
|---|---|
| `resumeDeferredIdentityPurgeIfNeeded` | `AppBootstrapper.swift:386` |
| `forgetBridged` | `AppBootstrapper.swift:1181` |
| `hasCompletedFetchCycleOnAllEngines` | `GroupChannelFreshness.swift:41` |
| `zoneFetchFailedThisSession` | `GroupChannelFreshness.swift:42` |

Superficie completa hoy: **14 miembros distintos + 1 tipo anidado** (`SplitSyncManager.SyncStatus`, en
`iCloudSyncService.swift:112`), en **45 líneas** de ficheros supervivientes.

### 2.4 · Recortes que el brief no tiene

| Fichero | Rango HOY | Qué es | Líneas |
|---|---|---|---:|
| `Yala/App/AppBootstrapper.swift` | **`:371–387`** | bloque 16.4.4 entero (`resumeDeferredIdentityPurgeIfNeeded`). Borrar solo `:386` deja un `Task` que arranca, espera quiescencia y no hace nada | **17** |
| `Yala/App/AppBootstrapper.swift` | `:1178–1182` | el `onBridged` → 1 línea | 5→1 |
| `Yala/App/AppBootstrapper.swift` | `:1297–1320` + `:451–454` | `retryPendingLeaveShares` + su callsite | 28 |
| `Yala/App/Views/Groups/GroupSettingsView.swift` | `:651–673` (forzado) · `:58–63`, `:100–104`, `:184–208`, `:619–648` (la feature entera) | `performDeleteFrozenCopy` → `deleteZone` | 23 ó **89** |
| `Yala/Services/Groups/GroupChannelFreshness.swift` | `:41–42` | las 2 señales CloudKit — **ver §3** | 2 |
| `Yala/App/YalaAppDelegate.swift` | `:103–112` + `import` `:10` | `application(_:userDidAcceptCloudKitShareWith:)` | 10 |
| `Yala/App/ContentView.swift` | `:1692`, `:1739`, `:1752`, `:2063–2071` | `acceptShare`, `PendingInviteStore.clear()` ×2, el brazo `else if` que consume **dos** de los 14 | ~12 |
| `Yala/App/Models/AppRouter.swift` | `:156` | `PendingInviteStore.clear()` | 1 |
| `Yala/App/ViewModels/GroupDetailViewModel.swift` | `:135`, `:467`, `:479`, `:490–497` | `syncNow` + `createShare` + `SplitZoneError` + helper | ~15 |
| `Yala/App/Views/Groups/GroupMembersView.swift` | `:466`, `:479`, `:484–494` | idem | ~18 |

> ⚠️ **`PendingInviteStore` es el hueco más grande del brief: un fichero entero de la lista de borrado
> sin un solo recorte contabilizado.** Tiene **7 call-sites** en ficheros supervivientes —
> `AppBootstrapper:1967`, `:2034`, `:2108` · `ContentView:1739`, `:1752` · `AppRouter:156` ·
> `GroupJoinIntentTracker:122` — y su tipo `PendingInviteEntry` muere con él.

### 2.5 · La frontera que hay que fijar antes de dar un total

**No hay un total defendible sin declarar antes qué se cuenta**, y el brief usa los dos criterios a la
vez sin decirlo:

- **Frontera estricta** (solo lo que rompe el build): `GroupSettingsView` aporta **1** línea (`:661`).
- **Frontera de feature** (la funcionalidad muere entera): aporta **89**.

Con la frontera estricta y las altas incorporadas, el bloque de recortes exactos pasa de las **139**
líneas del 29/07 a **≥ 220**, con `GroupService.swift` en **89** (era 85) y **≥131** fuera. La cifra es
una **cota inferior**: los bloques C.2 (muertes de función completa —`createGroup`,
`ensureCurrentUserMemberExists`, `refreshCurrentUserFlags`, `leaveGroup`,
`updateCurrentUserDisplayName`—, ~321 líneas estimadas el 29/07) **no se re-midieron** y sus coordenadas
han derivado con seguridad. Anclas de hoy: `createGroup :125`, `setArchived :262`, `softDelete :313`,
`addMember :382`, `leaveGroup :550`, `performRemovedSelfCleanup :629`,
`ensureCurrentUserMemberExists :945`, `updateCurrentUserDisplayName :1048`, `refreshCurrentUserFlags :1104`.

### 2.6 · Dos correcciones concretas al informe del 29/07

- **R7 ya no existe.** `GroupService.deleteGroup` (con su `SplitZoneManager.deleteZone`) se borró entero
  en `d5dfc629`. El recorte ya está hecho.
- **R10 creció de 2 a 8 líneas** (`:646–653`): el endurecimiento de `b1a9333d`/`c8ce41fd` insertó la
  desambiguación de `shareRow` **dentro** del recorte. Es el patrón general: **endurecer código condenado
  engorda su recorte.**

### 2.7 · `InviteLinkService` — el brief sobrestima el recorte

Lo único que el compilador obliga a tocar es **`fetchShareMetadata` (`:231–247`) + el `import CloudKit`
de `:9` = 18 líneas**. `buildInviteURL` (`:27–67`) y `extractShareURL` (`:169–189`) **no usan ni un solo
tipo de CloudKit**: reciben y devuelven `URL`. Borrarlas es una **decisión de producto** («retirar el
canal de invitación por CKShare»), no una consecuencia mecánica: cuesta +62 líneas y rompe
`AppBootstrapper:1950`, `GroupDetailViewModel:492` y `GroupMembersView:487`. `buildBackendInviteURL`
(`:69–126`) y `extractBackendInvite` (`:128–159`) sobreviven intactas.

### 2.8 · Canarios y breadcrumbs que se quedan sin emisor

**8 breadcrumbs** de `Yala/Services/CloudSync/Groups/GroupsSyncBreadcrumb.swift` (fichero
**superviviente**) quedan sin un solo emisor. El informe del 29/07 listaba **6**; se suman
`groupsIdentityPurgeDeferred` (`:230`) y `groupsIdentityPurgeResumed` (`:236`), nacidos con el
endurecimiento de la purga de identidad:

`groupsCkEnqueueSkippedBackendGroup` (`:147`) · `groupsCkMigrationMarkerEnqueued` (`:162`) ·
`groupsCkPullSkippedBackendGroup` (`:171`) · `groupsCkFetchApplyFailed` (`:180`) ·
`groupsIdentityChangeRetained` (`:212`) · `groupsIdentityChangePurgeFailed` (`:221`) ·
`groupsIdentityPurgeDeferred` (`:230`) · `groupsIdentityPurgeResumed` (`:236`)

> **Trampa estructural:** dentro del `// MARK: - Partición POR-GRUPO (G5-A)` (`:142`) conviven las
> huérfanas con **`groupsDrainSkippedNonBackendGroup` (`:155`), que SOBREVIVE** — la emiten
> `GroupsSyncClient:789`, `:801`, `:854`. **Borrar el bloque del MARK de un tirón se lleva el diagnóstico
> del drain del canal que se queda.**

Además quedan sin emisor **8 canarios** de `MetricsService.swift`: `cloudkitGroupSyncPromotedToAuto`,
`groupsIdentityBootMismatch`, `cloudkitGroupZoneRecovered`, `cloudkitGroupRecordsRecovered`,
`cloudkitGroupSyncNoImportPromote`, `cloudkitGroupSyncGateHardCap`, `cloudkitGroupEnqueueDroppedNoEngine`,
`cloudkitGroupRecordSaveRejected`; más `invitePendingExpired` (único emisor `PendingInviteStore.swift:80`)
e `inviteReEmittedFromStore` (único emisor `AppBootstrapper.swift:2043`).

**`cloudkitDuplicateDetected` NO queda huérfano** — conserva 7 emisores fuera del alcance del commit 1.

---

## 3 · Los consumidores nacidos DESPUÉS del 29/07

Por definición no están en ningún informe. **Es el apartado con más riesgo de hueco silencioso, y el que
justifica el chip entero.**

### 3.1 · El gate de frescura — dos ficheros nuevos, cero menciones en el brief

`find . -name "GroupChannelFreshness*.swift"` devuelve **tres** rutas y hay que separarlas:

| Ruta | Líneas | Qué es | ¿muere? |
|---|---:|---|---|
| `Yala/Services/Groups/GroupChannelFreshness.swift` | **140** | adaptador de runtime | **NO** |
| `Yala/App/Logic/GroupChannelFreshnessGate.swift` | **141** | decisión PURA por zona | NO |
| `YalaTests/GroupChannelFreshnessGateTests.swift` | 138 (10 `@Test`) | — | — |

Los dos de producción son **ALTAS** posteriores al 29/07. `grep -c` sobre el brief y sobre los 8 informes
→ **0 menciones en ambos**. El chip solo nombraba el primero: **son dos**.

**Las coordenadas del chip son exactas hoy:**

```
Yala/Services/Groups/GroupChannelFreshness.swift
41:   SplitSyncManager.shared.hasCompletedFetchCycleOnAllEngines,
42:   cloudKitZoneFetchFailed: { SplitSyncManager.shared.zoneFetchFailedThisSession($0) }
130:  belongsToBackendChannel: GroupZoneCacheGate.belongsToBackendChannel(
```

Ambas dentro de `ChannelSignals.live()` (`:37–44`). Sus proveedores viven en el fichero moribundo
(`SplitSyncManager.swift:194–196` y `:200–202`), alimentados por `enginesWithCompletedFetchCycle` (`:166`)
y `zonesWithFailedFetchThisSession` (`:174`); `engineNames = ["private","shared"]` (`:178`) y el `isSubset`
exige **los dos** engines.

**Qué decide `belongsToBackendChannel`:** a qué canal se le pide la evidencia, **no** si la zona es
válida. Los dos cuantificadores son opuestos a propósito: «asentada» es ALL-row, «del canal backend» es
ANY-row. ⇒ **`belongsToBackendChannel == false` es exactamente el conjunto de zonas cuya evidencia sale
del fichero que el commit 1 borra.**

**A quién autoriza:**

| Consumidor | Coordenada | Qué le concede |
|---|---|---|
| `Yala/Services/Groups/OrphanedBridgedTxSweeper.swift` (326 líneas, **NUEVO**) | consulta `:190`, cierre `:205–212`, consumo `:234–235` y `:245`, **acciones destructivas `:256–267`** (`.releasePointers` y `context.delete(tx)`), canario `:295` | **borrar transacciones puenteadas** |
| `Yala/App/Views/Transactions/NewTransactionView.swift` | decisión `:174–175`, función `:158–182`, call-site `.onAppear` `:563`; gobierna `isBridgedReadOnly` (`:91`) e `isBridgedCasoA` (`:104`) | **habilitar Borrar/Duplicar** |
| `Yala/App/AppBootstrapper.swift` | `awaitGroupsChannelEvidence` `:1071–1105` (poll 2 s, tope 60 s), consulta `:1093`, guard `:433`, barrido `:437` | que el barrido corra o no |

**Qué significa «falla cerrado» hoy, y qué pasa después del commit 1** — el efecto es **asimétrico** entre
los dos consumidores:

- **Barredor:** no toca nada; cuenta el motivo en `deferredByVerdict` y lo emite al canario. Nada se
  destruye, la limpieza se pospone.
- **Editor:** `bridgedPointerResolves = found || !isFresh` ⇒ con `isFresh == false` sale **`true`** aunque
  el fetch venga vacío ⇒ solo-lectura y **Borrar/Duplicar desactivados**. Es el sesgo correcto, pero es
  también el que **atrapa** el dinero fantasma.

Tras el commit 1 las líneas `:41–42` no compilan, y **ese estado deja de ser transitorio: pasa a ser
permanente y sin auto-sanación, porque ya no hay canal que pueda despertar.**

> **Y esas zonas existen y se pueden seguir creando HOY.** `GroupFormView.swift:272–287` enruta a
> `GroupService.createGroup` (rama CloudKit) siempre que `CloudSyncFlags.groupsBackendEnabled` sea `false`
> — exactamente el estado que produce el drill del kill-switch. Ningún escritor local puede voltearlas
> después: `isBackendGroup = true` solo lo ponen `GroupsSyncClient:2399`/`:2423`,
> `GroupBackendMembershipService:131`/`:166` y el merge del dedup, y ninguno alcanza una zona que el
> servidor no enumera. **Punto fijo.**

### 3.2 · Los 4 sitios de des-puenteo del tombstone

| Sitio | Canal | Coordenada HOY |
|---|---|---|
| 1 — `case .splitExpense` | CloudKit (**muere**) | `SplitSyncManager.swift:2735–2737` |
| 2 — `case .splitSettlement` | CloudKit (**muere**) | `SplitSyncManager.swift:2742–2744` |
| 3 — `applyExpense`, rama tombstone | backend (vive) | `GroupsSyncClient.swift:2228–2242` |
| 4 — `applySettlement`, rama tombstone | backend (vive) | `GroupsSyncClient.swift:2294–2301` |

Acumuladores CloudKit en `:1893–1894`, drenaje `:1966–1975` gateado por `didPersistBatch` (`:1908`/`:1915`),
freeze antes en `:1932–1944`. Lado backend: `drainSoftDeleteFreeze` `:1917` → `drainUnbridge` `:1918`
(definido `:1937–1947`).

**Comparado línea a línea, la mitad backend es estrictamente MÁS FUERTE en tres invariantes** (tiene
`context.rollback()` donde la CloudKit solo tiene `didPersistBatch`; tiene protección contra
tombstone-luego-upsert en la misma página, `:2244`/`:2303`, que la CloudKit no tiene; su tombstone de
grupo sí congela).

**Pero la respuesta a «¿cubre todo lo que hoy cubren las cuatro?» es NO, y el hueco es estructural:**

> **G1 — El alcance. Los dos guards son COMPLEMENTARIOS por construcción.**
> El G6-3 de `SplitSyncManager:1899` descarta del bucle de deletions **toda zona backend**, y el canal
> backend solo ve las zonas que el **servidor** enumera. ⇒ el conjunto que cubre CloudKit es exactamente
> el **complemento** del que cubre el backend, y borrarlo no traslada su carga a nadie.
> **Caso concreto sin cubrir:** dos miembros de un grupo nacido en CloudKit. El miembro B borra un gasto.
> El miembro A **conserva su `TransactionItem` puenteada viva para siempre**, apuntando a un `SplitExpense`
> que en su store nunca se borrará. Dinero fantasma en Panel, presupuestos y reportes — **y atrapado**,
> porque en una zona no-fresca `bridgedPointerResolves` vale `true` (§3.1): ni editable ni borrable.
> **G1 y el gate de frescura son el mismo agujero visto desde los dos lados.**

> **G2 — El borrado del GRUPO entero en CloudKit no va por `applyRemoteDeletion`.**
> Su `case .groupMeta` (`:2715–2734`) está declarado **sin emisor**. En CloudKit un grupo se borra
> borrando su **ZONA**: `handleFetchedDatabaseChanges` `:1409–1435` → `deleteGroupCache` `:2429` →
> `GroupZoneCacheGate.deleteCache`. **Ese camino cascadea las filas pero NO congela ni suelta el puente
> personal.** Al morir el fichero desaparece la limpieza local de una zona que CloudKit dice que ya no
> está. El equivalente backend (`:2355–2365`) sí congela, pero solo para zonas backend.

> **G3 — `GroupsIdentityPurgeIntent` pierde ARMADOR y DRENADOR a la vez.** *(verificado personalmente)*
> ```bash
> grep -rn "GroupsIdentityPurgeIntent\." Yala/
> #  SplitSyncManager.swift:1530 (isArmed) :1531 (armedAt) :1625 (arm()) :1671 (disarm())
> ```
> **Los cuatro están dentro del fichero que muere**, y el retome `resumeDeferredIdentityPurgeIfNeeded`
> (`:1529–1535`) también, aunque su call-site esté en `AppBootstrapper:386`.
> **Es exactamente la trampa que se evitó a propósito con `GroupsPendingBridgeResume`**, cuya decisión
> está escrita en `.claude/rules/swiftdata-cloudkit.md`: «dejarlo dentro habría convertido el intent en
> una intención SIN DRENADOR el día del borrado». Aquí no se hizo.
> **Caso concreto:** un usuario que actualiza con el intent YA ARMADO en disco (cambio de Apple ID
> ocurrido, purga diferida) **nunca la ejecuta**, en silencio y para siempre. Es una purga de
> **privacidad** (C-3). El brief nombra la pérdida de `.deleteLocalRows` pero **no** este intent.
> **Y es invisible al grep:** `GroupsIdentityPurgeIntent` seguirá dando **20 hits** tras el commit 1
> (fichero propio + tests + comentarios) y parecerá sano.

### 3.3 · Los demás huérfanos que el commit 1 crea, y que no están en ninguna lista

| Símbolo | Menciones en brief/informes | Qué pasa |
|---|---:|---|
| `Yala/App/Logic/CloudKitGroupMetaApplyLogic.swift` | **0 / 0** | **Huérfano total**: su único call-site de producción es `SplitSyncManager:2578` *(verificado)*. Misma familia que el S6 que el brief sí documenta. Con él muere el guard fail-cerrado que impide que el canal CloudKit fabrique el duplicado MIXTO de `SplitGroup` |
| `GroupZoneCacheGate.classify` / `.deleteCache` | **0 / 0** | Pierden **todos** sus call-sites (`SplitSyncManager:1403`, `:2397`, `:2430`). Solo `belongsToBackendChannel` conserva consumidores vivos |
| `GroupFreezeLogic.zoneBlocksCloudKitWrites` (`:149`) | 0 / 0 | Sus **seis** consumidores están en `SplitSyncManager` (`:521`, `:605`, `:1135`, `:1148`, `:1165`, `:1188`) |
| `SplitGroupZone.zoneName(for:)` | (mencionado al revés) | Pierde su único caller de producción (`CloudKitConstants.swift:126`). `zonePrefix` sí sobrevive (`SplitGroup.swift:102`) |
| `BootSaveGateLogic.resolveWaitByQuiescence(reachedHardCap:)` | 0 / 0 | El único llamador que pasa `true` es `SplitSyncManager:693`. Tras el commit 1 **el parámetro es inalcanzable en producción** |

### 3.4 · El commit 1 NO saca CloudKit del subsistema de Grupos

`Yala/Services/CloudSync/Groups/GroupICloudIdentitySeed.swift` (**130 líneas, fichero NUEVO,
superviviente**) tiene `import CloudKit` en `:32` y un fetch **vivo** a
`CKContainer(identifier:).userRecordID().recordName` en `:51–53`, con su `inflight` coalescente (`:60`),
su key de `UserDefaults` (`:43`) y su call-site en `AppBootstrapper.swift:490`.

**Es deliberado** —es la pieza de la Fase 2 bis (`40a4e417`) que conserva el escritor de identidad— pero
significa que **el canal backend superviviente depende de una identidad que solo un fetch a CloudKit puede
sembrar**, y que el criterio de salida del plan (§8) es doblemente falso.

---

## 4 · Los apagones silenciosos S1–S6

| # | Estado HOY | Cambio respecto al brief |
|---|---|---|
| **S1** | **Bloqueo LEVANTADO** | El flag compilado es `true` en `:285`, no `false` en `:266` |
| **S2** | **Pérdida ya consumada; coste de usuario CERO** | El brief lo llamaba «el hallazgo más caro». Es el más barato |
| **S3** | **Partido en tres: uno CERRADO, dos abiertos** | El desatasco de «esperando aprobación» ya tiene espejo backend |
| **S4** | **ABIERTO — y la señal YA LLEGA al cliente y se descarta** | El brief no lo vio |
| **S5** | **ABIERTO**, no re-cableado por la Fase 2 | Confirmado: las dos rutas llaman primero al transporte |
| **S6** | **CONFIRMADO exacto** | Único hallazgo del brief que sobrevive sin una corrección |

### S1 · El bloqueo está levantado, pero el getter sigue compuesto

```
Yala/Services/CloudSync/CloudSyncFlags.swift:285
    private static let groupsBackendCompiledDefault = true
```

**Corrección doble: cambió el valor *y* la línea (+19).** Pero el getter compuesto (`:273–279`) sigue
siendo `compilado && CloudRemoteFlags.groupsBackendEnabled` ⇒ **un kill remoto durante la Fase 3 devuelve
exactamente el escenario que el brief describía, pero ya sin rama a la que caer.** Eso no es un residuo
teórico: es la definición operativa del kill.

Censo: **103 hits** de `groupsBackendEnabled` en `Yala/`, **54 no-comentario** en 43 ficheros. De los que
*son* routers, **25 eligen entre ramas que ambas sobreviven** y **6 mueren con su rama**:

| Router con rama condenada | ¿Lo caza el compilador? |
|---|---|
| `SplitSyncManager.swift:327` | muere con el fichero |
| `GroupDetailViewModel.swift:455` → `SplitZoneManager.createShare` | **SÍ** |
| `GroupMembersView.swift:455` → idem | **SÍ** |
| `ContentView.swift:2063` → `GroupsICloudUnavailableView()` (`:2071`) | **SÍ** |
| `AppBootstrapper.swift:1860` → `processCKShareInviteLink` → `PendingInviteStore.save` | **SÍ** |
| **`GroupFormView.swift:273`** → `case .cloudKit` → `GroupService.createGroup` | **NO** |

> **`GroupFormView.swift:273` es el único de los seis que se apaga sin ruido**, porque su rama condenada
> está a un salto: el error de compilación aparece *dentro* de `GroupService`, y quien lo arregle tiene
> delante un `case .cloudKit` que sigue verde apuntando a un camino que ya no crea nada.

### S2 · `movedToBackendAt` — el hallazgo se invierte

**Corrección 1: hay un TERCER escritor y sobrevive.** `SplitGroupDeduplicationService.swift:138`
*(verificado personalmente)*. No invalida la tesis, la matiza: es un **propagador**, no una fuente — su
valor sale de `dups.compactMap(\.movedToBackendAt).min()`. Pero el brief afirmaba «2 escritores» y un plan
que se apoye en el número literal se lleva una sorpresa.

**Corrección 2, la que cambia la decisión: la pérdida ya está consumada y vale cero.** La cadena está
muerta en tres eslabones independientes: acuñador cliente **borrado** (`GroupMigrationUploader`, `5010db6a`,
2026-07-28), acuñador servidor **revocado**, columna en el wire **inexistente** (`0 hits` de
`moved_to_backend` en `gateway/`).

⇒ **`movedToBackendAt` es `nil` en todo el parque instalado.** El freeze del miembro
(`GroupExpenseService.swift:580`, `GroupService.swift:196`) y el CTA «vuelve a entrar»
(`GroupDetailView.swift:493`) **ya no se activan hoy, y no pueden.** El guard raíz derivó de `:117` a
`GroupFreezeLogic.swift:121`.

> **Precisión sobre por qué producción quedó protegida.** No fue por el flip compilado: el término
> **remoto** `GROUPS_BACKEND_ROLLOUT_PERCENT` de producción nació en `"0"` (`49722ab6`, 2026-07-17) y solo
> pasó a `"100"` en **`98d6415d` (2026-07-31)**, tres días *después* de borrar el uploader. Hubo una
> ventana de 5 h el 2026-07-18 con el flag compilado en `true` y el uploader vivo (`2efd2929` →
> `2d75bb80`, un `qa(temp)` que se commiteó pese a decir «JAMÁS COMMITEAR»), pero el getter compuesto era
> `false` por el percent. **El enunciado correcto es «lo protegió el rollout percent en 0», no «nunca
> coexistieron».**

### S3 · Partido en tres

- **S3a · «esperando aprobación» — CERRADO.** El canal nuevo ya lo desatasca:
  `GroupsSyncClient.swift:1978–1994` (`publishTrackedJoinPhaseIfNeeded`), traído por `479e8e81`,
  posterior al brief; segundo emisor en `GroupBackendInviteEntryHandler.swift:281`. **Esta pieza no pierde
  nada en la Fase 3.**
- **S3b · el trigger `.remoteInsert` — ABIERTO, pero su valor está medido y es bajo.** Hoy en
  `SplitSyncManager.swift:2053` (brief: `:1760`, +293). **El propio repo ya midió que espejarlo no habría
  arreglado el caso de usuario que el brief le atribuye**
  (`GroupInviteOnboardingLogic.swift:109–113`): el reconciler dispara `.correctAndClear` con el member
  presente aunque esté `pendingApproval`, así que el intent ya está limpio cuando llega la aprobación. El
  brief le asigna a S3b un daño que era de S3a, y S3a ya está cerrado por otra vía.
- **S3c · la fase `.accepting`.** Sus escritores son **tres**: `GroupJoinIntentTracker.swift:57` (dentro de
  `noteAcceptStarted`, cuyos únicos emisores son `SplitSyncManager:836` y `:854` — condenados), `:128`
  (rama `.acceptFailed` de `retry()`, cuyo cuerpo llama `SplitSyncManager.shared.acceptShare` en `:133`) y
  `:158` (**solo `#if DEBUG`**, hook de XCUITest). ⇒ **en un binario de RELEASE no queda ningún camino de
  producción que la escriba.** Lo que el brief no presupuesta: **el botón «reintentar» del banner pierde su
  implementación**, y eso sí lo caza el compilador.

### S4 · «Me sacaron del grupo» — abierto, y mucho más barato de lo que parece

Coordenadas de hoy (deriva de +347/+231 respecto al brief): detección
`SplitSyncManager.swift:2643–2647`, drenaje `:1928–1980` → `GroupService.performRemovedSelfCleanup`
(`GroupService.swift:629`). Red de cold boot que sobrevive: `AppBootstrapper.swift:1284–1288`.
`grep -rn "removedSelf" Yala/Services/CloudSync/` → **0**: el canal nuevo no tiene detector.

**(a) ¿Llega el evento? SÍ, ya llega, ya se parsea, y no lo lee nadie.** *(verificado personalmente)*

El camino obvio no sirve: `remove_member` no borra la fila, la pone en `removed`, y en ese instante la RLS
y el gateway dejan de entregarla ⇒ no llega tombstone ni upsert. **Pero el gateway manda la señal en
negativo**, en el campo `memberships` de `GET /groups/pull` (`gateway/src/groups/routes.ts:481`), y el
cliente **lo decodifica**:

```bash
grep -rn "\.memberships" Yala/ YalaTests/ | grep -vE ":\s*(///|//)"
# Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:2755:   memberships: decoded.memberships ?? []
```

**Una escritura, cero lecturas.** `GroupPulledPage.memberships` (`:3098`) es un campo escrito y jamás
consultado, y Swift no avisa porque un `let` de `struct` se consume en el init sintetizado.

**(b) Coste de espejarlo:** 1 fichero de producción (`GroupsSyncClient.swift`) + 1 de test, **15–30 líneas,
0 servidor** — el wire ya lo lleva, y `applyGroupMeta` con `.tombstone` (`:2334–2364`) ya hace exactamente
esta figura. **Con un matiz que hay que presupuestar:** el destino natural,
`GroupService.performRemovedSelfCleanup`, **sobrevive de nombre pero no de cuerpo** — `:653` y `:666`
usan `SplitZoneManager` y `:674–675` usa `PendingLeaveShareTracker`, los dos condenados. Esa cirugía entra
en el commit 1 **por compilación, la espeje alguien o no**; lo que queda tras vaciarla es la mitad local
(`performLocalCleanupAndDelete`, `:679`), y lo que se pierde es soltar el CKShare y el retry persistido.
Riesgo a vigilar: un `memberships` vacío por error transitorio borraría grupos vivos — la mitigación es el
mismo sesgo fail-closed que ya usa `[R4]` en `:2894–2902`.

**(c) Coste de declarar la pérdida:** el admin le saca del grupo y su device **no se entera hasta el
siguiente arranque en frío**. Hasta entonces el grupo sigue en su lista, abierto y editable; los gastos
que apunte ahí **se guardan localmente y no viajan**, y al relanzar el grupo desaparece con ellos dentro.
**Es el único de los tres apagones de fuente con pérdida de datos real para el usuario.**

### S5 · No lo cerró la Fase 2: lo duplicó

```
Yala/App/ViewModels/GroupsViewModel.swift:202-206     :203 muere · :204 vive
Yala/App/ViewModels/GroupDetailViewModel.swift:134-138 :135 muere · :136 vive
```

**S5.1 queda estructuralmente sano**: al quitar la línea del transporte queda un drain real. Residuo
aparte (no es de la Fase 3): el `Bool` de `syncNowFromUI()` **se descarta en los dos sitios** ⇒ sin sesión
Nube o con kill remoto el usuario ve girar el spinner y no pasa nada, sin alerta ni log.

**S5.2 «Invitar»** (`GroupDetailViewModel:455`, `GroupMembersView:455`): el compilador obliga a pasar por
ahí, pero **no obliga a sustituirlo** — borrar el `else` compila, y entonces todo grupo con
`isBackendGroup == false` pulsa «Invitar» y no ocurre nada (`GroupMembersView.swift:472–474`).

**S5.3 «Crear grupo»** es el único apagón realmente silencioso de S5 — ver `GroupFormView.swift:273` en §S1.

### S6 · `SoftDeleteObserverLogic` — confirmado exacto

31 líneas · único consumidor de producción `SplitSyncManager.swift:2643` (**muere**) · 5 call-sites en
`YalaTests/GroupTransactionBridgeSoftDeleteTests.swift`, que **no** se borra. **Huérfano total confirmado.**

---

## 5 · `GroupsIdentityPurgeGate` — el símbolo que el brief tiene mal

⚠️ **`deleteLocalRows` NO es una función.** *(verificado personalmente)*

```bash
grep -rn "deleteLocalRows" Yala/
# Yala/App/Logic/GroupsIdentityPurgeGate.swift:101:  case deleteLocalRows      <- CASE del enum Outcome
# ...:116, :121  (retornos de decideForZone)
# ...:204        (case del switch dentro de apply)
```

| Símbolo | Línea |
|---|---:|
| `enum GroupsIdentityPurgeGate` | 90 |
| `enum Outcome` | 98 |
| **`case deleteLocalRows`** | **101** |
| `case retainRevokingRejoinCredentials` | 104 |
| `static func decideForZone` | 111 |
| `static func decide` | 125 |
| `struct Result` | 136 |
| **`static func apply` — quien EJECUTA** | **156** |
| **`private static func deleteRows`** | **225** |

El brief y el documento de control citan «`GroupsIdentityPurgeGate.deleteLocalRows` (`:201–252`)». Ni el
símbolo ni el rango existen: `:204` es el `case .deleteLocalRows:` dentro del `switch` de `apply`.

**La sustancia se sostiene:** borrar el fichero deja el cambio de Apple ID **sin purga automática** para
las filas CloudKit-era ⇒ regresión de `31dded30`. **Pero la decisión no es sobre `deleteLocalRows`: es
sobre `apply` y `deleteRows`**, y va junto con el boot-guard (`GroupsIdentityBootGuardLogic`, que también
muere) **y con G3** (§3.2), que es la mitad que el brief no nombra.

`belongsToBackendChannel` ya **no** vive aquí: se extrajo a
`Yala/Services/CloudSync/Groups/GroupBackendIdentityLogic.swift:63` en la Fase 2.6. No es un recorte
pendiente.

---

## 6 · Los tests del commit 2

### 6.1 · Los 9 que mueren enteros — 1.730 líneas *(verificado personalmente)*

| Líneas | Ruta real |
|---:|---|
| 452 | `YalaTests/GroupsIdentityPurgeGateTests.swift` |
| 429 | `YalaTests/CKRecordTranslatorTests.swift` |
| 263 | `YalaTests/SplitSyncStartGateTests.swift` |
| 157 | `YalaTests/CloudKitGroupsSchemaParityTests.swift` |
| 136 | `YalaTests/SplitSyncManagerTests.swift` |
| 125 | `YalaTests/PendingInviteStoreTests.swift` |
| 76 | `YalaTests/CKRecordTranslatorSanitizeTests.swift` |
| 52 | `YalaTests/GroupsIdentityBootGuardLogicTests.swift` |
| 40 | `YalaTests/GroupsICloudAvailabilityGateLogicTests.swift` |
| **1.730** | **total — son 9, el brief dice 8** |

### 6.2 · Lo que nadie cubre — con un matiz que cambia el riesgo

El brief afirma que `SplitZoneManager`, `CKShareEntryHandler`, `GroupUserIdentityService` y
`PendingLeaveShareTracker` «se borran sin que ningún test lo note». **Medido, eso solo es cierto para uno:**

| Tipo | Suite propia | Referenciado en |
|---|---|---|
| `SplitZoneManager` | no | `GroupChannelRoutingTests` |
| `PendingLeaveShareTracker` | no | `GroupTransactionBridgeSoftDeleteTests` |
| `GroupUserIdentityService` | no | **8 suites** |
| **`CKShareEntryHandler`** | **no** | **cero referencias en todo `YalaTests/` y `YalaUITests/`** |

⇒ para tres de los cuatro **el compilador sí lo nota** (sus suites dejan de compilar), que es el
comportamiento deseable. **El que de verdad se va sin que nada lo note es `CKShareEntryHandler`.**

### 6.3 · La deuda del commit 0 — son 8 celdas, y la justificación del brief es la equivocada

`resolveWaitByQuiescence` vive hoy en `Yala/App/Logic/BootSaveGateLogic.swift:82` (fichero de 169 líneas)
y las celdas que la cubren siguen en `YalaTests/SplitSyncStartGateTests.swift` (263 líneas), que el
commit 2 borra.

**El brief se contradice a sí mismo:** su viñeta de deuda (`:332–335`) dice «**son 9 celdas, no 8**»; su
párrafo operativo de Commit 2 (`:352–353`) dice «**las 8 celdas**». **El correcto es 8**:
`mirrorNotConfirmedOff_matrixUnchanged` habla de la matriz del mirror y no pertenece al rescate. Quien
construya el commit leyendo el párrafo operativo hace lo correcto; hay que resolver la inconsistencia en
el documento, no tratarla como una trampa que muerde por defecto.

**Y la justificación del rescate hay que cambiarla.** El brief dice que sin él la función «se queda
prácticamente sin cobertura». **Falso:** conserva 9 llamadas indirectas vía `decide` **más** una directa
en `BootSaveGateLogicTests.swift:141–146` que ya ejercita `reachedHardCap: true → .start`, la misma
aserción que `resolveByQuiescence_hardCap_startsRegardless`. **Lo que sí queda descubierto** es (a) la
matriz de la rama **empty-store** (celdas `:147`, `:157`, `:168` — las únicas que cruzan
`hasObservedImportActivity` × `noImportGraceElapsed` × `isQuiescent`) y (b) las celdas `.keepWaiting` de
la rama normal (`:108`, `:118`, `:137`). **El argumento correcto para rescatar es la matriz empty-store,
no el hard cap.** Cambia la justificación, no la recomendación: se mueven a `BootSaveGateLogicTests.swift`.

> **Y hay una consecuencia que nadie había medido:** tras el commit 1 el único llamador que pasa
> `reachedHardCap: true` (`SplitSyncManager:693`) desaparece ⇒ **el parámetro queda inalcanzable en
> producción**. Las dos aserciones que lo pinnean cubrirían una rama que producción ya no puede ejecutar.
> Direcciones (sin decidir): conservarlo como contrato explícito y anotar por qué (coste 0), o podarlo
> —pero eso es cambio de producción y el commit 2 es «tests y coverage».

### 6.4 · `CloudKitGroupsSchemaParityTests` — confirmado, sigue leyendo por RUTA

`YalaTests/CloudKitGroupsSchemaParityTests.swift:43` construye la ruta a
`Yala/Services/Groups/CloudKitConstants.swift`. **Sigue habiendo que adelantarlo de la Fase 4.**

### 6.5 · Los tests híbridos — el hueco que el brief no tiene

El brief solo contempla ficheros que mueren enteros. **Hay 9 ficheros de test NUEVOS (posteriores al
29/07) con acoplamiento al transporte, 3.611 líneas en total, y ninguno está en `fase3-tests.md`:**

| Fichero | Hits a símbolos moribundos | Líneas |
|---|---:|---:|
| `YalaTests/GroupRemoteDeletionUnbridgeTests.swift` | 9 | **1.230** |
| `YalaTests/GroupsPendingBridgeDurabilityTests.swift` | 19 | 757 |
| `YalaTests/GroupZoneCacheGateTests.swift` | 6 | 316 |
| `YalaTests/GroupsIdentityPurgeDurabilityTests.swift` | 24 | 262 |
| `YalaTests/CloudSync/GroupRefreshFlagsZoneGateTests.swift` | 4 | 260 |
| `YalaTests/CloudSync/GroupCloudKitWriteZoneGateTests.swift` | 5 | 242 |
| `YalaTests/GroupBackendInviteEntryHandlerLegacyKeyTests.swift` | 7 | 203 |
| `YalaTests/GroupICloudIdentitySeedTests.swift` | 13 | 196 |
| `YalaTests/CloudSync/CloudKitGroupMetaApplyLogicTests.swift` | 7 | 145 |

`fase3-tests.md` cuenta 1.855 líneas en 15 ficheros: **el corpus de test acoplado al transporte casi se ha
triplicado desde que se midió.** (Dos de los nueve —`GroupsIdentityPurgeDurabilityTests` y
`GroupICloudIdentitySeedTests`— sí aparecen en el brief, en otro contexto.)

### 6.6 · Las 16 anclas de ruta literal — el modo de fallo peor

`grep -rn 'Yala/Services/Groups/SplitSyncManager.swift' YalaTests/ YalaUITests/` → **14 ocurrencias en 6
ficheros** (`GroupsIdentityPurgeGateTests:381, :401, :414, :429` · `GroupsPendingBridgeDurabilityTests:601,
:624, :708, :733` · `GroupZoneCacheGateTests:261, :285, :303` · `GroupCloudKitWriteZoneGateTests:194, :210`
· `CloudKitGroupMetaApplyLogicTests:89` · `GroupRemoteDeletionUnbridgeTests:1064`), más
`GroupsIdentityPurgeGateTests:447` y `CloudKitGroupsSchemaParityTests:43` ⇒ **16 source-scans sobre
ficheros condenados.**

> **Un source-scan sobre un fichero borrado lanza en RUNTIME, no rompe la compilación.** Un `xcodebuild`
> verde no dice nada de ellos. Es la misma familia de «Executed 0 tests» que la regla de attest describe.

### 6.7 · Dos suites que se quedan sin sujeto

- **`CloudKitGroupMetaApplyLogicTests`** (145 líneas): la lógica que pinnea queda con **0 call-sites de
  producción** (§3.3).
- **`GroupCloudKitWriteZoneGateTests`** (242 líneas): **doblemente afectada** — sus 2 source-scans se
  rompen **y** `GroupFreezeLogic.zoneBlocksCloudKitWrites`, la función que pinnea, se queda sin llamador.

`Yala.xcodeproj/project.pbxproj` **no necesita edición**: usa `PBXFileSystemSynchronizedRootGroup` (7
grupos) y `grep -c` de los nombres de suite → **0**. `git rm` basta.

---

## 7 · El índice de cobertura *(medido personalmente)*

**Hoy:** `_meta.counts` = `total 134 / deterministic 41 / agentic 35 / manual 58 /
deterministicSinXCUITest 0`, `backlogBaseline 0`. `bash qa/validate-coverage.sh` → **`RESULT: OK`** (con
4 WARN preexistentes de `sin scenarioIDs`, ajenos a la Fase 3).

### 7.1 · Las 5 áreas cuyos `codeGlobs` apuntan a ficheros condenados

Cruce programático de cada `codeGlobs` contra el filesystem real y contra los 14 moribundos:

| Área | classification | globs | mueren | ¿queda vacía? |
|---|---|---:|---:|---|
| `groups-cross-device-sync` | manual | **24** | 8 | no — quedan 16 |
| **`groups-icloud-availability-gate`** | **manual** | **2** | **2** | **SÍ ⇒ ERROR DURO** |
| `groups-pending-approval-reconnect` | agentic | 14 | 2 | no — quedan 12 |
| `groups-backend-g5-cutover` | manual | 4 | 1 | no — quedan 3 |
| `groups-backend-g6-migration` | manual | 8 | 2 | no — quedan 6 |

**Respuesta a «¿cae alguna otra en lo mismo?»: NO.** Solo una, y es la que el brief ya señalaba.

*(Nota: `groups-cross-device-sync` tiene **24** globs, no los 18 que dice el brief tras `bc486c92`.)*

### 7.2 · La trampa, confirmada en el validador

```bash
sed -n '61,62p' qa/validate-coverage.py
#     if not a.get("codeGlobs"):
#         errors.append(f"{name}: codeGlobs vacio")
```

**Error DURO.** ⇒ hay que **borrar el área** `groups-icloud-availability-gate` (classification `manual`) y
bajar `_meta.counts` **a mano** (los `counts` no los valida nadie):

**`total 134 → 133` · `manual 58 → 57`** · `deterministic` y `agentic` sin cambios.

### 7.3 · Corrección al brief: las áreas afectadas son 9, no 5

Las 5 de arriba lo son **por `codeGlobs`**. Pero las **citas a suites que el commit 2 borra** tocan
**7 áreas**, y **4 de ellas no están en la lista de las 5**:

| Área | Suites borradas que cita |
|---|---|
| `groups-cross-device-sync` | `SplitSyncManagerTests`, `SplitSyncStartGateTests`, `GroupsIdentityBootGuardLogicTests`, `GroupsIdentityPurgeGateTests`, `CloudKitGroupsSchemaParityTests` |
| `groups-icloud-availability-gate` | `GroupsICloudAvailabilityGateLogicTests` |
| `groups-backend-g6-migration` | `CloudKitGroupsSchemaParityTests` |
| **`groups-notifications-deeplinks`** | `CloudKitGroupsSchemaParityTests` |
| **`icloud-sync-multi-device`** | `SplitSyncStartGateTests` |
| **`groups-backend-g2-sync-channel`** | `GroupsIdentityPurgeGateTests` |
| **`groups-backend-g4-invites`** | `GroupsIdentityPurgeGateTests` |

⇒ **unión: 9 áreas tocadas por el commit 2**, no 5. Toda cita a una suite borrada hay que retirarla o el
índice queda mintiendo.

Conteos exactos de citas: `GroupsIdentityPurgeGateTests` **7** · `SplitSyncStartGateTests` **4** ·
`CloudKitGroupsSchemaParityTests` **3** · `SplitSyncManagerTests`, `GroupsIdentityBootGuardLogicTests`,
`GroupsICloudAvailabilityGateLogicTests` **1** cada una · `CKRecordTranslatorTests`,
`CKRecordTranslatorSanitizeTests`, `PendingInviteStoreTests` **0**.

---

## 8 · El criterio de salida miente más de lo que decía el brief *(medido personalmente)*

### 8.1 · El grep del plan, hoy

```bash
grep -r "import CloudKit" Yala/Services/Groups/ Yala/App/Views/Groups/   # → 8 ficheros
```

El plan pide que dé **0**. **No puede dar 0, y no solo por el punto ciego de `App/Logic/`.** De esos 8, la
mitad **sobrevive al commit 1**:

| Fichero (dentro de las carpetas que el plan SÍ escanea) | Destino |
|---|---|
| `Yala/Services/Groups/CKRecordTranslator.swift` | muere |
| `Yala/Services/Groups/CloudKitConstants.swift` | muere |
| `Yala/Services/Groups/SplitSyncManager.swift` | muere |
| `Yala/Services/Groups/SplitZoneManager.swift` | muere |
| **`Yala/Services/Groups/GroupService.swift`** | **SOBREVIVE** |
| **`Yala/Services/Groups/GroupUserIdentityService.swift`** | **SOBREVIVE** |
| **`Yala/Services/Groups/InviteLinkService.swift`** | **SOBREVIVE** |
| **`Yala/App/Views/Groups/GroupInviteOnboardingView.swift`** | **SOBREVIVE** |

El brief solo señalaba el punto ciego de `Yala/App/Logic/` (donde están `SplitSyncStartGate.swift`, que
muere, y `GroupJoinReconcileLogic.swift` + `GroupAcceptShareErrorLogic.swift`, que sobreviven). **El
problema es mayor: dentro de las carpetas que el grep sí mira ya hay cuatro supervivientes.**

Repo-wide hay **25 ficheros** con `^import CloudKit` en `Yala/` (`YalaWidgets/`, `YalaShare/` y
`YalaUITests/`: **0**; `YalaTests/`: 15).

### 8.2 · El criterio correcto, propuesto

El valor esperado depende de decisiones abiertas (si `InviteLinkService` retira solo `fetchShareMetadata`
o el canal CKShare entero; si `GroupService` y `GroupUserIdentityService` conservan su import tras los
recortes). **Por eso el criterio no puede ser un número a secas: tiene que ser una lista nominal.**

```bash
# Criterio de salida de la Fase 3 — lista NOMINAL, no un cero
grep -rln "^import CloudKit" Yala/ | sort
```

**Debe devolver exactamente los supervivientes esperados y ninguno de los 14.** El freno útil es el
complementario:

```bash
# NINGUNO de estos debe seguir existiendo tras el commit 1
grep -rln "^import CloudKit" Yala/Services/Groups/SplitSyncManager.swift \
  Yala/Services/Groups/CKRecordTranslator.swift \
  Yala/Services/Groups/SplitZoneManager.swift \
  Yala/Services/Groups/CloudKitConstants.swift \
  Yala/App/Logic/SplitSyncStartGate.swift \
  Yala/App/Services/CKShareEntryHandler.swift 2>/dev/null | wc -l   # esperado: 0
```

> ⚠️ **El criterio falso está CODIFICADO en un test vivo**, no solo en documentación:
> `YalaTests/GroupICloudIdentitySeedTests.swift:59–65` define `transportDirectories = ["Yala/Services/Groups/",
> "Yala/App/Views/Groups/"]` citando literalmente el grep del plan. Tocar el criterio toca ese test.

### 8.3 · Los greps que deben SEGUIR dando hits — el freno de verdad

Medido hoy, y esperado tras el commit 1 (**cota superior**: solo descuenta los hits que viven dentro de los
14 ficheros; los recortes en supervivientes bajarán algunos más):

| Símbolo | HOY | en los 14 | **Esperado (cota sup.)** |
|---|---:|---:|---:|
| `GroupJoinReconcileLogic` | 52 | 0 | **52** |
| `GroupAcceptShareErrorLogic` | 17 | 2 | **15** |
| `BootSaveGateLogic` | 41 | 4 | **37** |
| `GroupZoneCacheGate` | 51 | 5 | **46** |
| `OrphanedBridgedTxSweeper` | 42 | 1 | **41** |
| `GroupsSyncClient` | 324 | 9 | **315** |

**Y tres frenos que la lista de seis no tiene, y que deberían estar** (son los que detectarían los huecos
de §3, que ningún otro detecta):

| Símbolo | HOY | en los 14 | **Esperado** | Qué detecta |
|---|---:|---:|---:|---|
| `GroupChannelFreshness` | 51 | 1 | **50** | que el gate de frescura sobreviva al desmontaje de su brazo CloudKit |
| `GroupsPendingBridgeResume` | 14 | 2 | **12** | que el retome del bridge no se vaya con el `onBridged` |
| `GroupICloudIdentitySeed` | 32 | 1 | **31** | que el escritor de identidad de la Fase 2 bis siga en pie |

> **Ninguno de estos contadores detecta G3.** `GroupsIdentityPurgeIntent` pasa de 28 a **20 hits** y
> parece sano, porque los 20 que quedan son su propio fichero, sus tests y comentarios: **el intent se
> queda sin armador y sin drenador sin que ningún número lo delate.** El freno para G3 no es un grep de
> símbolo: es comprobar que `arm()` y `disarm()` tienen call-site de producción.

```bash
# Freno específico para G3 — debe dar ≥1 en un fichero SUPERVIVIENTE
grep -rn "GroupsIdentityPurgeIntent\.\(arm\|disarm\)()" Yala/ | grep -v "Services/Groups/SplitSyncManager.swift"
```

---

## 9 · Las dos decisiones del owner — inventario, sin veredicto

### A2 · Qué evidencia se concede al gate de frescura cuando desaparezca su brazo CloudKit

| # | Dirección | Código a tocar | Coste / modo de fallo |
|---|---|---|---|
| **i** | **Seguir fallando cerrado**: sustituir `:41–42` por constantes `false` | `GroupChannelFreshness.swift:37–44` | La limpieza de esas zonas **no se hace nunca**: huérfanas permanentes, dinero fantasma **atrapado** (ni editable ni borrable). Y el canario `bridgedTxOrphanSweepDeferred` pasa a emitirse en **todos** los arranques con candidatas ⇒ deja de significar «el gate está frenando algo» y **se pierde la superficie de observación del subsistema** |
| **ii** | **Conceder evidencia**: colapsar la rama CloudKit a `.fresh` | `GroupChannelFreshnessGate.swift:134–136` | **La dirección que destruye.** Un device recién reinstalado monta el store de Grupos vacío mientras el espejo personal ya entregó las `TransactionItem` ⇒ el barredor **borra** las virtuales y **suelta** las de cuenta real, **y esas mutaciones se exportan por el espejo personal a los demás devices**. Es el escenario exacto que este gate se escribió para impedir, generalizado a todo el corpus legacy |
| **iii** | **Sacar las zonas legacy del conjunto de CANDIDATAS** (no del veredicto) | `OrphanedBridgedTxSweeper:205–212`, `:234–235`, `:245` | Huérfanas permanentes igual que (i), pero **en silencio**; el canario recupera su significado para las zonas backend. Se pierde la única señal de cuántas huérfanas legacy hay en la flota |
| **iv** | **Asimetría deliberada**: el editor concede, el barredor sigue cerrado | `NewTransactionView:174–175` | Devuelve al usuario la salida manual sin que ningún código destruya solo. **Rompe el invariante declarado en `GroupChannelFreshness.swift:8–12`** («una sola primitiva para los dos»). Y hay **dos** tests que pinnean lo que tocaría: `freshnessGate_hasExactlyItsThreeProductionCallSites` y `editorResolvesThePointer`, cuyo `#expect` cita el literal de `NewTransactionView.swift:91` |
| **v** | **Cerrar la causa aguas arriba**: dar a las zonas legacy un camino al backend antes de borrar el transporte | fuera del commit 1 (no hay uploader ni RPC) | Único camino que elimina la clase entera de huecos, G1 y G2 incluidos. **Es un épico, no un commit** |

**El dato que falta para ponderar, y que no está en el repo:** cuántas zonas con
`isBackendGroup == false` hay en la flota. Se lee del canario `bridgedTxOrphanSweepDeferred` en el
dashboard de Analytics Engine (su `detail` desglosa por veredicto), **no del código**.

### A3 · S2 / S3b / S4, uno por uno

| | **S2** marcador | **S3b** `.remoteInsert` | **S4** «me sacaron» |
|---|---|---|---|
| **¿Llega el evento?** | **NO, y no puede.** Sin columna server, sin RPC (revocada), sin acuñador cliente | **N/A** — el repo ya midió que el reconciler no arreglaba el caso | **SÍ. Llega, se parsea, y nadie lo lee** (`page.memberships`) |
| **Coste de espejarlo** | Reconstruir una épica borrada: columna + grant + RPC + ~537 líneas. **Toca servidor y base** | Bajo, **pero el beneficio medido es nulo** | **15–30 líneas, 1 fichero, 0 servidor** + la cirugía obligatoria de `performRemovedSelfCleanup` |
| **Coste de declarar la pérdida** | **CERO daño de usuario**: `movedToBackendAt` es `nil` en todo el parque | Una línea de doc | **Grupo fantasma editable hasta el cold boot, y pérdida de lo escrito en esa ventana** |

**La asimetría, de un vistazo:** el brief marcaba S2 como el hallazgo caro y no vio que S4 tuviera espejo
posible. **Se intercambian: S2 es gratis de declarar y S4 es barato de arreglar** — y S4 es el único de
los tres con pérdida de datos real. **S6** no es de esta familia: es un huérfano, y se re-cablea o se
borra.

---

## 10 · Bugs encontrados — REPORTADOS, no arreglados

| # | Bug | Coordenada |
|---|---|---|
| **B-1** | **`GroupPulledPage.memberships`: campo escrito, jamás leído — y dos comentarios prometen lo contrario.** `GroupsSyncClient.swift:2896` y `GroupsSyncBreadcrumb.swift:103` dicen «la limpieza llega por memberships del pull» y lo usan para justificar **no** remediar: cuando el Merkle detecta corpus remoto vacío con local no vacío —la firma exacta de una remoción de membership— el cliente hace `skip` sin canario **fiándose de una limpieza que no existe**. Misma familia que el `AppAttestClient.ensureRegistered()` de `.claude/rules/gateway-attest.md`. No lo caza el compilador ni ningún test | `GroupsSyncClient.swift:2755`, `:3098`, `:2896` |
| **B-2** | `markerEnqueuedFlag` no tiene ningún escritor a `true` en producción ⇒ el bloque es inalcanzable. **Sí tiene cobertura de test** (`GroupsIdentityPurgeGateTests:252`, con 2 aserciones). **Es efímero: se va con el commit 1**, porque vive en uno de los 14 | `GroupsIdentityPurgeGate.swift:194–196` |
| **B-3** | `MetricsService.swift:37 cloudkitBudgetCSVMirrorRebuilt` sigue con **cero emisores** en todo el repo. Zombi anterior a la Fase 3, ya detectado el 29/07 | `MetricsService.swift:37` |
| **B-4** | El código y el plan se contradicen: `ContentView.swift:2070` afirma «La lógica pura y la vista NO se borran (retiro real post-G6)» refiriéndose a `GroupsICloudAvailabilityGateLogic` y `GroupsICloudUnavailableView`, que **sí** están los dos en la lista de 14 | `ContentView.swift:2070` |
| **B-5** | Coordenada rancia dentro del propio código: `AppBootstrapper.swift:378` cita en comentario «`SplitSyncManager.initialize()` (:317)»; hoy está en `:320` | `AppBootstrapper.swift:378` |

---

## 11 · Lo que NO se pudo medir — huecos declarados

1. **No se compiló nada.** Regla de solo-lectura del chip. Toda afirmación de «esto rompe el build» es
   inferencia por desaparición de tipo, no un `xcodebuild`. **El conjunto real de errores del commit 1 solo
   lo da el compilador**, y puede incluir acoplamientos que ningún grep de estos símbolos alcanza
   (extensiones, conformances, tipos anidados).
2. **No se corrió ni un test**, así que «rojo en runtime» para los 16 source-scans es una predicción
   estructural. Tampoco hay **verificación por mutación** de que las 8 celdas rescatadas cubran de verdad
   `resolveWaitByQuiescence`: eso exige editar.
3. **No se sabe cuántas zonas `isBackendGroup == false` hay en la flota.** Es la variable que decide si G1
   y A2 son un residual académico o un incidente de datos. Se responde con el dashboard de Analytics
   Engine, no con el repo.
4. **No se verificó nada en device.** El fix del gate está verificado en device el 2026-08-04 **solo en su
   caso POSITIVO** (canal fresco ⇒ repara). El caso negativo sigue sin ejercitar.
5. **No se re-midieron los bloques C.2** (`createGroup`, `ensureCurrentUserMemberExists`,
   `refreshCurrentUserFlags`, `leaveGroup`, `updateCurrentUserDisplayName`, ~321 líneas estimadas el
   29/07). Sus anclas de hoy están en §2.5; sus rangos, no.
6. **No se recorrieron los 84 commits uno a uno.** La ventana se cruzó por ficheros añadidos
   (`--diff-filter=A`) y por greps de símbolo ⇒ **un consumidor nuevo dentro de un fichero preexistente y
   que use un símbolo distinto de los barridos se escaparía igual.**
7. **No se confirmó que `migrate_group` esté revocada en PRODUCCIÓN.** El único DDL del repo es de staging
   y su afirmación de «aplicado a los dos entornos» es un comentario, no una observación. *(Existe una vía
   de solo-lectura vía el MCP de Supabase; no se ejecutó — es acción de infraestructura y requiere OK del
   owner.)*
8. **No se observó `CloudRemoteFlags.groupsBackendEnabled` en runtime.** Se sabe que el `.toml` dice `100`,
   no que un device concreto lo lea `true`. Todo §S1 razona sobre estructura.
9. **No se verificó la exhaustividad de los routers de categoría D.** No se hizo análisis de alcanzabilidad
   transitiva: `GroupFormView:273` alcanza código condenado a dos saltos y se encontró a mano. **Puede
   haber más como él**, y son justo los que el compilador no destapa.
10. **No se tocó `gateway/`** más allá de leer los dos `GROUPS_BACKEND_ROLLOUT_PERCENT`.

---

## 12 · Resumen de correcciones al brief

| # | Qué decía el brief | Qué dice la realidad |
|---|---|---|
| 1 | 13 ficheros enteros, 4.355 líneas | **14 ficheros, 4.744 líneas** |
| 2 | `SplitSyncManager` 2.521 · `CKRecordTranslator` 437 · `SplitSyncStartGate` 292 · `GroupsIdentityPurgeGate` 253 · `CloudKitConstants` 150 · `GroupUserIdentityService` 88 | **2.907 · 415 · 149 · 256 · 144 · 85** |
| 3 | `GroupsIdentityPurgeGate.deleteLocalRows` es una función (`:201–252`) | **Es un `case` del enum `Outcome` (`:101`).** Ejecuta `apply` (`:156`) con el privado `deleteRows` (`:225`) |
| 4 | 8 ficheros de test mueren enteros | **9 ficheros, 1.730 líneas** |
| 5 | `isInviteLink` está en `InviteLinkService:1637` y con el flag OFF `handleInviteLink` queda mudo | **Caducado.** El fichero tiene 270 líneas y la definición está en **`:222`**; el enrutado se rehizo con `GroupInviteChannelRoutingLogic` (`AppBootstrapper:1855–1900`) y hay rama `.backendUnavailable` explícita |
| 6 | Criterio de salida: `grep "import CloudKit"` en 2 carpetas → 0 | **Imposible.** Hoy da 8 y **4 de ellos sobreviven**; y el criterio está codificado en `GroupICloudIdentitySeedTests:59–65` |
| 7 | 5 áreas del coverage-index | **5 por `codeGlobs`, pero 9 en total** contando las citas a suites borradas |
| 8 | «9 celdas» de `resolveWaitByQuiescence` (y «8» en su párrafo operativo) | **8**, y la justificación correcta es la matriz **empty-store**, no el hard cap |
| 9 | S2 es el hallazgo más caro | **La pérdida ya está consumada y su coste de usuario es cero** |
| 10 | S4 sin espejo posible | **La señal ya llega al cliente y nadie la lee** (`page.memberships`) |
| 11 | `SplitGroupZone.swift` (32 líneas) | **42** |
| 12 | «los 4 sin suite propia se borran sin que nada lo note» | **Solo `CKShareEntryHandler`**; los otros tres los caza el compilador |
| 13 | — | **Nuevo: G1, G2, G3, el gate de frescura, `CloudKitGroupMetaApplyLogic`, `GroupZoneCacheGate`, los 9 tests híbridos y las 16 anclas de ruta literal no están en ninguna lista** |
