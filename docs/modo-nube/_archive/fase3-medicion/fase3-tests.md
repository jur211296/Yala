# Fase 3 · Commit 2 (tests) — medición contra HEAD `ca06cfd5`

> ## 🟠 SUPERADO — medición del 2026-07-29 contra `ca06cfd5`
>
> **Desde este HEAD han entrado 84 commits.** Las coordenadas de `SplitSyncManager.swift` derivan hasta
> **+317 líneas** (el fichero pasó de 2.521 a **2.907**) y `SplitSyncStartGate.swift` adelgazó de 292 a
> **149** con el commit 0. La re-medición completa contra `dbb0bab3` (2026-08-04) está en
> **[`fase3-REMEDICION-2026-08-04.md`](fase3-REMEDICION-2026-08-04.md)** — **úsala a ella para escribir
> el commit 1.**
>
> Este informe se conserva como registro de lo que se midió y por qué; **lo que midió era correcto para
> su HEAD** (verificado: 10 de 10 tamaños exactos contra `ca06cfd5`). Lo que lo supera es lo escrito
> después. Deltas propios de este informe:
>
> - Los que mueren enteros son **9 ficheros / 1.730 líneas** (medido hoy).
> - **Faltan 9 ficheros de test NUEVOS** posteriores al 29/07 con acoplamiento al transporte,
>   **3.611 líneas**: el corpus acoplado casi se ha triplicado desde esta medición.
> - **Faltan las 16 anclas de ruta literal** sobre ficheros condenados. Un source-scan sobre un fichero
>   borrado **lanza en RUNTIME, no rompe la compilación** ⇒ un build verde no dice nada de ellas.
> - Son **8** celdas de `resolveWaitByQuiescence` a rescatar, y la justificación correcta es la matriz
>   **empty-store**, no el hard cap (que ya está cubierto en `BootSaveGateLogicTests:141-146`).
>
> **Y el hueco que comparten los ocho:** la heurística «solo derivan las coordenadas del fichero que se
> editó» es válida para la DERIVA y **ciega para las ALTAS**. Hay **15 ficheros de producción nuevos**
> desde `ca06cfd5`, **11 de ellos tocan este subsistema**, y ninguno puede estar aquí.


Todas las cifras salen de `wc -l` / `grep -n` contra el árbol de trabajo en `/Users/jur/Yala`.
Nada viene del plan. Rutas absolutas: prefija `/Users/jur/Yala/`.

## Veredicto en una línea

El plan dice **«10 ficheros de test del transporte (~2.042)»**. La realidad son **9 ficheros que
mueren enteros (1.504 líneas) + 6 ficheros que sobreviven y hay que EDITAR (351 líneas de 1.541)**
⇒ **1.855 líneas, 15 ficheros tocados**. El décimo fichero que el plan cuenta como entero
(`SplitSyncStartGateTests.swift`) es **MIXTO**: 232 de sus 395 líneas tienen que sobrevivir porque
prueban el gate de boot-save del store **PERSONAL**, no el transporte de Grupos.

---

## 1 · Mueren enteros — 9 ficheros, 1.504 líneas

| # | Fichero | wc -l | Sujeto que muere | En `coverage-index`? |
|---|---------|------:|------------------|----------------------|
| 1 | `YalaTests/CKRecordTranslatorTests.swift` | 429 | `Yala/Services/Groups/CKRecordTranslator.swift` (437) | no citado |
| 2 | `YalaTests/GroupsIdentityPurgeGateTests.swift` | 428 | `Yala/App/Logic/GroupsIdentityPurgeGate.swift` (253) | `groups-cross-device-sync`, `groups-backend-g2-sync-channel`, `groups-backend-g4-invites` |
| 3 | `YalaTests/CloudKitGroupsSchemaParityTests.swift` | 157 | source-scan de `CloudKitConstants.swift` + `.ckdb` | `groups-cross-device-sync`, `groups-notifications-deeplinks` |
| 4 | `YalaTests/SplitSyncManagerTests.swift` | 136 | `CKConstants` · `CKRecordTranslator.update` · `SplitZoneError` | no citado |
| 5 | `YalaTests/PendingInviteStoreTests.swift` | 125 | `Yala/Services/Groups/PendingInviteStore.swift` (92) | no citado |
| 6 | `YalaTests/CKRecordTranslatorSanitizeTests.swift` | 76 | `CKRecordTranslator` (sanitize) | no citado |
| 7 | `YalaTests/GroupAcceptShareErrorLogicTests.swift` | 61 | `Yala/App/Logic/GroupAcceptShareErrorLogic.swift` (50) | `groups-cross-device-sync` |
| 8 | `YalaTests/GroupsIdentityBootGuardLogicTests.swift` | 52 | `Yala/App/Logic/GroupsIdentityBootGuardLogic.swift` (44) | `groups-cross-device-sync` |
| 9 | `YalaTests/GroupsICloudAvailabilityGateLogicTests.swift` | 40 | `Yala/App/Logic/GroupsICloudAvailabilityGateLogic.swift` (33) + `GroupsICloudUnavailableView.swift` (61) | `groups-icloud-availability-gate` (área ENTERA muere) |
| | **total** | **1.504** | | |

Notas por fila:

- **#2** es borrado limpio **solo porque la Fase 2.6 ya sacó `belongsToBackendChannel`** a
  `Yala/Services/CloudSync/Groups/GroupBackendIdentityLogic.swift:63` con su propio test en
  `YalaTests/CloudSync/GroupBackendIdentityLogicTests.swift:95-99`. Verificado ✅. Si esa extracción
  no estuviera hecha, este fichero sería MIXTO.
- **#2, cola del fichero**: `GroupsIdentityPurgeGateTests.swift:342` prueba
  `PendingJoinStore.revokeLegacyMemberKey`, que vive en un fichero **SUPERVIVIENTE**
  (`Yala/Services/Groups/PendingJoinStore.swift:176`). Su único callsite de producción es
  `GroupsIdentityPurgeGate.swift:158`, que muere ⇒ al borrar el test hay que borrar TAMBIÉN
  `revokeLegacyMemberKey` del store, o queda código muerto sin cobertura.
- **#7 no está en la lista de la Fase 3 commit 1.** `GroupAcceptShareErrorLogic` tiene sus 2 únicos
  callsites en `SplitSyncManager.swift:761` y `:825`. Al morir `SplitSyncManager`, el fichero de
  producción queda **huérfano y el compilador NO lo señala** (es un `enum` con `static func`, no da
  warning de "unused"). Añadirlo a la lista de la Fase 3.
- **#9**: es el único fichero cuya muerte **elimina un área completa** del índice de QA
  (`groups-icloud-availability-gate`, `manual`, `lastVerified 2026-07-13`). Impacto en
  `_meta.counts`: `total 134→133`, `manual 58→57`. No afecta al ratchet (`deterministic` no cambia).
  Verificado que **ningún XCUITest** referencia `groups_icloud_gate` /
  `groups_icloud_gate_open_settings` ⇒ no rompe cobertura determinista.

---

## 2 · MIXTOS — 6 ficheros SOBREVIVEN, se les recortan 351 de 1.541 líneas

### 2.1 · EL PELIGROSO — `YalaTests/SplitSyncStartGateTests.swift` (395)

**Este es el caso `GroupPullRescueChannelTests` de la Fase 3, y es peor: el mixto está también en
producción.**

`Yala/App/Logic/SplitSyncStartGate.swift` (292 — la cifra del plan es correcta, la **ruta no**: el
plan no la da y no está en `Yala/Services/Groups/`) contiene **DOS enums**:

| Rango | Símbolo | Consumidores vivos | Destino |
|------:|---------|--------------------|---------|
| `:22-197` | `enum SplitSyncStartGate` | `SplitSyncManager` (todos) **excepto `resolveWaitByQuiescence`** | muere |
| `:97-110` | `SplitSyncStartGate.resolveWaitByQuiescence` | `SplitSyncManager.swift:630` **Y `BootSaveGateLogic.swift-mismo:278`** | **DEBE SOBREVIVIR** |
| `:218-292` | `enum BootSaveGateLogic` | `AppBootstrapper.swift:855-963` (`awaitPersonalImportForBootSave`, ~8 tareas de boot), `recordBootSaveGateOutcome:923`, `MetricsService.swift:51`, `CloudMigrationController.swift:470` | **SOBREVIVE** |

`BootSaveGateLogic` no tiene nada que ver con Grupos: es el gate que evita el `save()` del
`mainContext` durante un import de `NSPersistentCloudKitContainer` a medias — el `_assertionFailure`
**SIGTRAP no atrapable** = crash-loop en un restore de iCloud (H-2026-07-18-8). Borrar
`SplitSyncStartGate.swift` entero reintroduce ese crash **y borra los 9 tests que lo pinnean**.

Desglose del fichero de test:

| Líneas | Contenido | Tests | Destino |
|-------:|-----------|------:|---------|
| 1-14 | header + `import CloudKit` | — | editar (quitar `import CloudKit`) |
| 16-18 | `@Suite("Split Sync Start Gate")` | — | renombrar |
| **19-96** | `decideStart` (matriz de arranque del engine) | 7 | **muere** |
| **98-177** | `resolveWaitByQuiescence` | 8 | **SOBREVIVE** (única cobertura de la dependencia de `BootSaveGateLogic`) |
| **179-191** | `promotedWhileNotQuiescent` | 3 | **muere** |
| **193-203** | `shouldDeferDelegateSave` | 2 | **muere** |
| **205-235** | `needsZoneRecovery` / `needsRecordRecovery` | 5 | **muere** |
| **237-263** | `classifyFailedSave(code: CKError.Code)` | 3 | **muere** |
| **265-395** | `@Suite("Boot Save Gate Logic") struct BootSaveGateLogicTests` | 9 | **SOBREVIVE ENTERO** |

**Muere: 163 líneas (19-96 + 179-263). Sobrevive: 232.**

**Trampa añadida en el índice de QA:** `qa/coverage-index.json` cita este bloque como
`unit:YalaTests/BootSaveGateLogicTests` en **dos** áreas (`groups-cross-device-sync` e
`icloud-sync-multi-device`) — y **ese fichero NO EXISTE**
(`find /Users/jur/Yala -name "BootSaveGateLogicTests.swift"` → 0 resultados). La suite vive dentro
de `SplitSyncStartGateTests.swift`. Quien borre "los 10 ficheros" y luego valide el índice buscando
`BootSaveGateLogicTests` como ruta no encontrará nada ni antes ni después ⇒ el validador no lo caza.
**Recomendación: en el mismo commit, extraer 265-395 + 98-177 a un
`YalaTests/BootSaveGateLogicTests.swift` real** — así el nombre que el índice ya declara pasa a
existir y el mixto desaparece de raíz.

### 2.2 · `YalaTests/GroupJoinReconcileLogicTests.swift` (198) — muere ~71

`Yala/App/Logic/GroupJoinReconcileLogic.swift` **no aparece en la lista de la Fase 3** y es MIXTO:

- Muere: `decide(hasIntent:groupExistsLocally:engineReady:)` (`:34`, único consumidor
  `GroupJoinReconciler.swift:74`, rama CloudKit) y `enqueuePlan` (`:142-157`, construye
  `CKRecordZone.ID` + `CKConstants.recordID`).
- Sobrevive: `decideBackend` (`:67`), `shouldClearBackendIntent` (`:83`),
  `backendMemberMatchesCurrentUser` (`:93`, también desde `GroupExpenseService.swift:646`),
  `shouldApplyIntentDisplayName` (`:107`), `shouldApplyGroupCurrency` (`:120`).

Recortes en el test: **17-41** (4 tests de `decide`, 25 líneas) + **153-198** (3 tests de
`enqueuePlan`, 46 líneas) + `import CloudKit` en `:9`. Sobreviven 15 tests.

### 2.3 · `YalaTests/GroupTransactionBridgeSoftDeleteTests.swift` (326) — muere 43

Fichero del **bridge**, que sobrevive (la Fase 2.3 recableó `freezeForSoftDelete`). Lleva un
polizón: `// MARK: - PendingLeaveShareTracker` en **`:284`** y el test
`pendingLeaveShareTracker_addRemoveAndPersist` (`:286-326`) — `PendingLeaveShareTracker` muere
(68 líneas, callsites vivos en `AppBootstrapper.swift:1164/:1172` y `GroupService.swift:593/:645`).
Borrar **284-326** + la línea 11 del docblock del header. **El compilador SÍ caza este** (referencia
a un tipo borrado). No está citado en `coverage-index`.

### 2.4 · `YalaTests/CloudSync/GroupChannelRoutingTests.swift` (261) — muere 23

Fichero del **canal backend** (G5-A), sobrevive. Su test
`createShare_backendGroup_throwsBackendGroupError` (`:66-88`) instancia
`SplitZoneManager(syncManager: .shared).createShare(...)` (`:76`) y captura
`SplitZoneError` (`:78`, definido en `SplitZoneManager.swift:288`) — ambos mueren. Borrar
**66-88** (MARK incluido). Ojo: las notas de alcance del header (`:9-13`) referencian
`SplitSyncManagerTests` y `CKSyncEngine` y quedan obsoletas. Área:
`groups-backend-g5-cutover` (`manual`, `lastVerified 2026-07-16`) — **pierde la partición C2 del
invite sin sustituto**: decidir por escrito si se declara hueco o se re-expresa como
"grupo backend ⇒ invite por token" contra `GroupBackendInviteParserTests`.

### 2.5 · `YalaTests/GroupJoinReconcilerTests.swift` (266) — muere 25

Fichero superviviente. `reconcile_engineNotReady_keepsIntent` (`:146-170`) pinnea el seam
`engineReady:` cuyo default de producción es `SplitSyncManager.shared.hasEngine(forOwned:)`
(`GroupJoinReconciler.swift:71`) — y `:253` hace `SplitSyncManager.shared.enqueueSave`. Al morir el
transporte el parámetro `engineReady` desaparece de la firma ⇒ borrar **146-170** y limpiar el
argumento `engineReady:` de los otros 4 tests que lo pasan (`:110`, `:162`, `:198` + fixture).
Se conserva intacto lo que usa `GroupUserIdentityService.deterministicUUID` (`:82`) y
`_testSetCachedRecordName` (`:31`/`:36`) — el plan ya manda conservar ambos. Área:
`groups-pending-approval-reconnect` (`agentic`).

### 2.6 · `YalaTests/InviteLinkServiceTests.swift` (95) — muere 26, y 11 tests hay que REESCRIBIRLOS

| Líneas | Contenido | Destino |
|-------:|-----------|---------|
| 16-65 | 11 tests de `isInviteLink` | **REESCRIBIR, no borrar** |
| 70-95 | 2 tests de `extractShareURL` | **muere** |

`InviteLinkService.isInviteLink` (`Yala/Services/Groups/InviteLinkService.swift:222`) exige el query
param **`s` = CKShare URL** (`:224`, `hasShareParam`) ⇒ post-Fase 3 devolvería `false` para
**todo** link válido. Y tiene **5 callsites vivos que el plan no menciona**:
`YalaAppDelegate.swift:94`, `AppBootstrapper.swift:1637` y
`InviteRecoveryView.swift:29`, `:129`, `:141` (el flujo "recuperar mi invitación", camino de
usuario). El plan solo manda reescribir «el guard de `AppBootstrapper` que usa `extractShareURL`».
**Si `isInviteLink` se queda como está, el deep-link de invitación backend deja de reconocerse y
los 11 tests siguen VERDES** — fallo silencioso de manual. `extractBackendInvite` ya tiene
cobertura propia en `YalaTests/GroupBackendInviteParserTests.swift` (124). No citado en
`coverage-index` por nombre de fichero.

---

## 3 · Totales

| | Ficheros | Líneas |
|---|---:|---:|
| Borrado entero | 9 | 1.504 |
| Recorte dentro de superviviente | 6 | 351 |
| **Total commit 2 (tests)** | **15 tocados** | **1.855** |

**Contra el plan (`~2.042` en 10 ficheros):** −187 líneas (−9 %) y **+5 ficheros tocados**.
Reconstrucción del 10 del plan: mis 9 + `SplitSyncStartGateTests` (395) = 1.899 al HEAD. El plan
infla ~143 líneas más. Ninguno de los 9+1 cambió de tamaño con la Fase 1 salvo
`GroupsIdentityPurgeGateTests` (435 → 428, −7 en la Fase 2.6). Verificado que **no hay solapamiento**
con los 10 test que ya borró la Fase 1 (`5010db6a`).

Los 232 de `SplitSyncStartGateTests` que sobreviven **no se restan del total** arriba: 1.855 es lo
que se va de verdad.

---

## 4 · Riesgos, ordenados

1. **`SplitSyncStartGateTests` + `SplitSyncStartGate.swift` contados como "un fichero del
   transporte".** Es el riesgo mayor y no es solo de test: arrastra `BootSaveGateLogic` de
   producción. Consecuencia si pasa: vuelve el crash-loop SIGTRAP del restore de iCloud
   (H-2026-07-18-8), **sin ningún test rojo que lo avise** — porque los 9 tests que lo pinnean se
   borran en el mismo hunk, y el índice de QA lo cita por un nombre de fichero que no existe.
   Mitigación: extraer 265-395 + 98-177 a `YalaTests/BootSaveGateLogicTests.swift` y mover
   `resolveWaitByQuiescence` + `BootSaveGateLogic` a un fichero propio **ANTES** del borrado,
   commit aislado (mismo molde que la 2.6).

2. **`CloudKitGroupsSchemaParityTests` está agendado en la Fase 4 y sus dependencias mueren en la
   Fase 3.** Es un source-scan por `#filePath` (`:43` → `Yala/Services/Groups/CloudKitConstants.swift`,
   `:51` → `Cloudkit Schemas/groups-production.ckdb`), **no un enlace de compilación**: tras borrar
   `CloudKitConstants.swift` el test **compila y se pone ROJO en runtime** (`try String(contentsOf:)`
   lanza). Es la clase de fallo que el plan dice querer evitar. Adelantarlo a la Fase 3 commit 2.
   Corolario: la Fase 4 commit 1 manda editar `CloudKitConstants.swift` y `CKRecordTranslator.swift`
   — ficheros que la Fase 3 ya borró. Contradicción interna del plan.

3. **`GroupAcceptShareErrorLogic.swift` (50) falta en la lista de producción de la Fase 3.** Sus 2
   callsites (`SplitSyncManager:761`, `:825`) mueren y el fichero queda huérfano **sin warning del
   compilador**. Su test (61) sí lo he contado arriba.

4. **`isInviteLink` (§2.6): fallo silencioso de manual.** 11 tests verdes sobre una función que
   post-Fase 3 rechaza todos los links reales, con 5 callsites vivos incluido el flujo de usuario
   `InviteRecoveryView`.

5. **Semántico, fuera de la lista pero conviene anotarlo:** `YalaUITests/Flows/OnboardingGroupsOnlyGuardUITests.swift`
   (2 tests, área **`deterministic`**) pinnea "sin cuenta iCloud ⇒ el guard bloquea 'Solo grupos'".
   Cuelga de `iCloudSyncService.shared.isAccountAvailable` directo
   (`OnboardingView.swift:511`), **no** de `GroupsICloudAvailabilityGateLogic` ⇒ **compila y pasa
   igual**, pero pinnea una regla de producto que deja de ser cierta cuando Grupos no necesita
   iCloud. No es rojo; es cobertura determinista que se queda mintiendo. Decidir por escrito.

## 5 · Cosas verificadas que NO son problema

- **`Yala.xcodeproj/project.pbxproj` usa `PBXFileSystemSynchronizedRootGroup`** (7 ocurrencias) y
  ninguno de los ficheros de test aparece listado individualmente ⇒ `git rm` basta, sin editar el
  proyecto.
- **Sobreviven intactos** (sus "hits" de transporte son campos `zoneID`/`groupZoneID`/`cloudKitZoneID`
  del modelo, que siguen siendo la identidad del grupo en el canal backend, o un `import CloudKit`
  del canal personal): `GroupsExportBuilderTests` (402, 46 hits — todos campos del modelo),
  `SplitGroupDeduplicationServiceTests` (106), `CloudSync/GroupsSyncClientTests` (1.869),
  `CloudSync/GroupBridgeCloudSyncIntegrationTests` (256), `GroupServiceCurrentUserFlagsTests` (243),
  `PendingJoinEntryBackCompatTests` (57), `GroupPersonalPreferencesTests` (39),
  `GroupBridgePreferenceDedupPlanTests` (65), `iCloudSyncServiceTests` (334),
  `SyncStatusBannerTests` (106), `AppBootstrapperTests` (379), `AppRouterTests` (359),
  `TabBarConfigurationSecondaryTests` (112), `HandoverGroupsDomainTests` (398).
- **`PendingJoinStore` y su `legacyMemberKey` SOBREVIVEN** — son del canal backend
  (`GroupBackendInviteEntryHandler.swift:85-98`, `:106`, `:182`;
  `GroupsMembershipClient.swift:338-343` → `p_legacy_member_key`). `PendingJoinStoreTests.swift`
  (199) no se toca. **No confundir con `PendingInviteStore`** (92 líneas, transporte, muere) —
  los nombres se diferencian en una sílaba y sus tests en 2 letras.
- **Único source-scan que apunta a un fichero que muere sin morir él mismo**: el de
  `CloudKitGroupsSchemaParityTests` (riesgo 2). El de `GroupsIdentityPurgeGateTests`
  (`:381/:389/:402/:410` → `SplitSyncManager.swift`; `:423` → `GroupsIdentityPurgeGate.swift`) se va
  con su propio fichero. `HandoverGroupsDomainTests` escanea `DataWipeService.swift` y
  `GroupTransactionBridge.swift`, ambos supervivientes.
