# Fase 3 · lente `usa-el-backend` — medición contra HEAD `ca06cfd5` (branch 2.0.5)

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
> - **El commit 1 NO saca CloudKit del subsistema de Grupos**, y es deliberado:
>   `GroupICloudIdentitySeed.swift` (130 líneas, superviviente) tiene `import CloudKit` (`:32`) y un
>   fetch vivo a `CKContainer(...).userRecordID()` (`:51-53`). El canal backend depende de esa identidad.
> - La mitad backend del des-puenteo es **más fuerte** que la CloudKit en tres invariantes, pero **no la
>   cubre**: los dos guards son complementarios por construcción (hueco **G1**).
> - El criterio de salida del plan **no puede dar 0**: cuatro de sus 8 hits actuales sobreviven.
>
> **Y el hueco que comparten los ocho:** la heurística «solo derivan las coordenadas del fichero que se
> editó» es válida para la DERIVA y **ciega para las ALTAS**. Hay **15 ficheros de producción nuevos**
> desde `ca06cfd5`, **11 de ellos tocan este subsistema**, y ninguno puede estar aquí.


**Pregunta única:** ¿qué código marcado para MORIR en la Fase 3 usa TODAVÍA el canal BACKEND?
Todas las coordenadas salen de medición propia (`grep -n`, `wc -l`, `sed -n`) sobre HEAD. Ningún fichero
del repo fue editado. Árbol sucio solo en `screenshots-appstore/` (PNG).

Medición propia de los 13 ficheros del plan **+ `GroupAcceptShareErrorLogic.swift`** (que el plan no
lista y muere igual): **4.548 líneas**.

---

## §0 · EL HALLAZGO QUE CAMBIA EL MARCO: el canal backend está COMPILADO-APAGADO

```
Yala/Services/CloudSync/CloudSyncFlags.swift:266
    private static let groupsBackendCompiledDefault = false

Yala/Services/CloudSync/CloudSyncFlags.swift:254-260
    static var groupsBackendEnabled: Bool {
        get {
            if let override = groupsBackendEnabledTestOverride { return override }
            return groupsBackendCompiledDefault && CloudRemoteFlags.groupsBackendEnabled
        }
```

El doc del propio flag (`:240-243`) lo dice sin ambigüedad: *«HOY es SIEMPRE `false` — ningún path de
producción lo activa … El sync de Grupos vigente lo sigue haciendo CKSyncEngine (`SplitSyncManager`)»*.

⇒ **En todo build de producción de HOY, "el canal backend" no está encendido y "el transporte" es el
ÚNICO canal vivo.** La Fase 3 del plan (leída en
`$VAULT/Backlog/modo-nube/MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS.md:258-289`) **no nombra este flag ni una
vez**, ni como prerrequisito ni como parte del changeset. Su criterio de hecho pide «QA en simulador del
recorrido entero por el canal backend» — QA que solo es posible con el override de tests o con el flag
compilado en `true`.

Esto no es una objeción de alcance: **es lo que convierte tres de mis hallazgos en fallos de producción
en vez de fallos hipotéticos.** Cada resolvedor de identidad de Grupos tiene la forma
`CloudSyncFlags.groupsBackendEnabled ? <identidad backend> : nil` — con el flag OFF el brazo backend es
`nil` y **la única identidad que queda es la CloudKit-era que la Fase 3 borra**:

| Resolvedor | Coordenada | Brazo backend |
|---|---|---|
| `GroupSettingsView.hasOutstandingBalance` | `Yala/App/Views/Groups/GroupSettingsView.swift:706` | `CloudSyncFlags.groupsBackendEnabled ? CloudAuthService.shared.currentUserID : nil` |
| `GroupJoinReconciler.currentUserMemberExists` | `Yala/Services/Groups/GroupJoinReconciler.swift:296` | `CloudSyncFlags.groupsBackendEnabled ? backendUserIDProvider() : nil` |
| `GroupService.refreshCurrentUserFlags` | `Yala/Services/Groups/GroupService.swift:1010` | `backendEnabled ? Self.backendUserIDProvider() : nil` |

**Decisión que hay que tomar antes del primer borrado:** o el flip compilado a `true` va en el MISMO lote
(y entonces la Fase 3 deja de ser «limpieza» y pasa a ser el encendido), o los borrados se paran en la
frontera de la Fase 2. Borrar con el flag en `false` deja la app **sin ningún canal de sync de Grupos**.

---

## §1 · 🔴 R-A · `cachedRecordName` se queda sin escritor, y el escritor es un WARM-UP DE BOOT INCONDICIONAL

Este riesgo lo levantó ya el bloque `conservar` (su R1). Lo que aporto es **el mecanismo exacto y la
consecuencia de usuario**, que cambian su severidad de «degrada» a «pierde la identidad histórica».

### El escritor

```
Yala/Services/Groups/GroupUserIdentityService.swift:18   private let defaultsKey = "groups_currentUserRecordName"
Yala/Services/Groups/GroupUserIdentityService.swift:41       UserDefaults.standard.set(name, forKey: defaultsKey)   ← ÚNICO escritor del repo
```

`:41` vive **dentro de `currentUserRecordName()` (`:27-43`)**, que el plan manda borrar (usa
`CKContainer(identifier: CKConstants.containerID).userRecordID()` en `:32`).

**Y su caller principal es un warm-up de boot que corre en TODOS los arranques, sin ningún gate:**

```
Yala/App/AppBootstrapper.swift:439-440
        // Seed current iCloud user identity for groups and refresh local membership flags.
        Task { @MainActor in
            _ = try? await GroupUserIdentityService.shared.currentUserRecordName()
```

No está gateado por `groupsBackendEnabled`, ni por «tiene grupos», ni por onboarding. Los otros 3
callers (`GroupService.swift:95`, `:845`, `:1023`) son caminos CloudKit que también mueren.

⇒ **Hoy, cualquier device con cuenta iCloud tiene la key poblada desde el primer arranque.** Tras la
Fase 3: **nunca**. Y `clearCache()` (`:45-50`) la borra, así que también se pierde tras cada handover.

### Los 5 consumidores que SOBREVIVEN (4 en caminos del canal backend)

| Consumidor | Coordenada | ¿Tiene fallback por `sub`? |
|---|---|---|
| `GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin` | `Yala/App/Services/GroupBackendInviteEntryHandler.swift:127` | **NO — por diseño**. Es la key CloudKit-era; el `sub` no sirve |
| `GroupExpenseService.selectCurrentUserMemberID` | `Yala/Services/Groups/GroupExpenseService.swift:614` (cadena en `:642-655`) | sí, fallback #2 — pero `nil` con el flag OFF |
| `GroupSettingsView.hasOutstandingBalance` | `Yala/App/Views/Groups/GroupSettingsView.swift:704` | ídem |
| `GroupJoinReconciler.currentUserMemberExists` | `Yala/Services/Groups/GroupJoinReconciler.swift:293` | ídem |
| `GroupService.refreshCurrentUserFlags` | `Yala/Services/Groups/GroupService.swift:1019` | ídem |

### Consecuencia 1 (la más cara): se pierde la membresía histórica del grupo migrado

`legacyMemberKeyForRejoin` (`GroupBackendInviteEntryHandler.swift:106-131`) tiene exactamente dos
fuentes: (1º) el `SplitMember` local con `isCurrentUser` → su `cloudKitUserRecordID` (`:119-121`);
(2º) `cachedRecordName` (`:127`). **En un device FRESCO la primera no existe** (no hay member local) ⇒
la única fuente es la segunda.

Su doc-comment (`:104`) dice *«Device fresco sin ninguno → `nil` (entra como member nuevo — residual
§9.3b documentado)»* — y **ese framing está equivocado hoy y oculta el hallazgo**: por el warm-up de
`AppBootstrapper:440`, un device fresco con iCloud SÍ tiene el cache poblado cuando el usuario tapea el
link. El «residual §9.3b» es hoy el caso raro (device sin iCloud). Tras la Fase 3 **pasa a ser el caso
GENERAL**: todo re-join de grupo migrado desde device fresco entra como member NUEVO, el server no
puede rebindear la membresía CloudKit-era (`p_legacy_member_key`, `GroupsMembershipClient.swift:338-343`)
y el usuario pierde su atribución y su saldo históricos en ese grupo.

### Consecuencia 2 (con el flag OFF, §0): colapso total de identidad

```
Yala/Services/Groups/GroupService.swift:1028
        guard !recordName.isEmpty || backendCanResolve else { return }
```

Con el flag OFF `backendCanResolve == false`; sin escritor `recordName == ""` ⇒
**`refreshCurrentUserFlags` retorna temprano y NINGÚN `SplitMember` recibe `isCurrentUser`.** Y ese flag
es la entrada de toda la UI: `GroupDetailViewModel.currentUserMember` lee SOLO ese flag (regla de área)
⇒ sin banda de balance, sin FAB, sin editar/liquidar. También cae
`GroupNotificationService.currentMemberID(inZone:)` (`Yala/Services/Groups/GroupNotificationService.swift:229-249`,
`#Predicate { … && $0.isCurrentUser == true }`) ⇒ el usuario deja de recibir avisos de sus propios grupos.

### Por qué ninguna alarma dispara

1. **Compila**: la propiedad y los 5 callsites siguen válidos.
2. **Los tests lo TAPAN activamente**: las 3 suites que ejercitan estos fallbacks inyectan por
   `_testSetCachedRecordName` (`GroupServiceCurrentUserFlagsTests.swift:58`,
   `GroupJoinReconcilerTests.swift:31`, `CloudSync/GroupsSyncClientTests.swift:566/611/653`) — **nunca
   pasan por el escritor real**, así que la propiedad *parece* viva.
3. **El QA de upgrade no lo ve**: la key ya está persistida en cualquier container que haya arrancado
   una vez con un build ≤ Fase 3. Solo se ve en instalación fresca — la población que nadie QA-ea.

**Acción mínima:** decidir explícitamente entre (i) conservar un escritor (contradice el criterio
`import CloudKit → 0` en `Yala/Services/Groups/`), o (ii) borrar los 5 fallbacks CloudKit **en el mismo
commit** en vez de dejarlos como rama muerta — lo que obliga a tocar
`GroupBackendInviteEntryHandler`, `GroupExpenseService`, `GroupSettingsView`, `GroupJoinReconciler`,
`GroupService` y sus tests, ninguno listado por el plan.

---

## §2 · 🔴 R-B · `CKConstants.zonePrefix` ES la identidad server-side del canal backend

```
Yala/Services/Groups/CloudKitConstants.swift:125    static let zonePrefix = "SplitGroup-"   ← fichero CONDENADO ENTERO
Yala/Models/SplitGroup.swift:102     self.cloudKitZoneID = "\(CKConstants.zonePrefix)\(self.id.uuidString)"   ← @Model que SOBREVIVE
```

El bloque `acoplamientos` (§1.2) ya nombró el acoplamiento. Lo que aporto: **la cadena de pruebas de que
el valor es un contrato de wire, y la constatación de que NADA lo valida.**

### Pruebas de que `cloudKitZoneID` es el `group_id` del backend (todas medidas)

| Coordenada | Qué dice |
|---|---|
| `Yala/Models/SplitGroup.swift:19` | `@Attribute(.preserveValueOnDeletion) var cloudKitZoneID: String = ""  // "SplitGroup-{uuid}"` |
| `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:501-504` | `backendGroupZoneIDs` = `Set(fetch(isBackendGroup == true).map(\.cloudKitZoneID))` — **el gate del drain** |
| `GroupsSyncClient.swift:662`, `:674`, `:703` | `guard backendZoneIDs.contains(groupID) else { … return }` en insert/update/tombstone |
| `GroupsSyncClient.swift:1836` | `model.cloudKitZoneID = delta.groupID` (el server lo dicta en el pull) |
| `GroupsSyncClient.swift:1901-1904` | deriva el id del member con `"\(delta.groupID):\(memberKey)"` |
| `Yala/Services/CloudSync/Groups/GroupSyncOutbox.swift:41` | «`group_id` del wire (§A) … `cloudKitZoneID` para el grupo» |
| `Yala/Services/CloudSync/Groups/GroupMerkleProjection.swift:24`, `:164` | keyset column de la proyección Merkle |
| `Yala/Services/CloudSync/Groups/GroupBackendMembershipService.swift:67` | documenta el formato literal `"SplitGroup-{uuid}"` |
| `Yala/Services/CloudSync/EntityApplyMap.swift:693` | «se copia byte a byte, NUNCA se remapea» |
| `groups_merkle_fixtures.json:12`, `:31` | canon: `"group_id": "SplitGroup-A1B2C3D4"` / `"SplitGroup-Zebra9"` |
| `gateway/scripts/generate-groups-merkle-fixtures.mjs:130`, `:138` | el generador del canon usa el mismo literal |

### Y NADIE valida el formato

Medido: **`grep` en `gateway/migrations/*.sql` no encuentra ningún `CHECK`/constraint/regex sobre
`group_id`** — el servidor acepta cualquier string. ⇒ un `zonePrefix` re-escrito mal (o «limpiado» a
`"Group-"`) **compila, pasa los unit tests locales, sube al backend sin error y rompe el join, el drain
y la comparación Merkle** de todo grupo nuevo. El `backendZoneIDs.contains(groupID)` del drain
seguiría casando (ambos lados salen del mismo campo local), así que el síntoma no es un skip visible:
es divergencia silenciosa contra el corpus que ya existe en el server con el prefijo viejo.

**Acción:** mover `zonePrefix` con su valor **byte-idéntico** (destino natural:
`Yala/Services/CloudSync/Groups/GroupBackendIdentityLogic.swift` o junto a `SplitGroup`), en un commit
aislado ANTES del borrado, y NO inlinear el literal en `SplitGroup.swift:102`.

**Nota de simetría:** `CKConstants.zoneName(for:)` (`:127`) y `groupID(from:)` (`:135`) mueren limpios —
verificado que sus únicos usos vivos son `SplitSyncManager.swift:2106`/`:2165` (condenado) y un
comentario en `GroupsIdentityPurgeGate.swift:213`. **El backend NO los usa** (lee el campo, no lo
deriva) — y ese comentario `:213` es precisamente la advertencia de por qué: derivar por `id` en vez de
leer `cloudKitZoneID` deja huérfanos en todo grupo born-backend.

---

## §3 · 🔴 R-C · `deterministicUUID` sobrevive, pero su NAMESPACE literal es un contrato cross-device

```
Yala/Services/Groups/GroupUserIdentityService.swift:75-87
    /// `nonisolated`: primitiva pura (solo CryptoKit, sin estado del actor). Compartida con
    /// `GroupBackendIdentityLogic` (canal backend), que corre fuera del main actor.
    nonisolated static func deterministicUUID(namespace: String, name: String) -> UUID
```

El plan ya manda conservarla. Lo que hay que decir es **qué se rompe si alguien la mueve o la
"simplifica"**: hay DOS namespaces y el canal backend usa los DOS a propósito.

| Consumidor backend | Coordenada | Namespace |
|---|---|---|
| `GroupBackendIdentityLogic.deterministicMemberID` | `Yala/Services/CloudSync/Groups/GroupBackendIdentityLogic.swift:37-40` | `memberIDNamespace = "SplitMemberBackend"` (`:32`) |
| `GroupsSyncClient.applyMember`, rama `isLegacyMemberKey` | `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:1900-1902` | **literal `"SplitMember"`** (namespace CloudKit-era, a propósito) |

`GroupsSyncClient.swift:1893-1899` explica por qué: el member de un grupo MIGRADO tiene que derivar en
el namespace CloudKit-era para que su UUID local sea **byte-idéntico** al que ya usó el owner en
`GroupService.swift:122`/`:928`. Los dos únicos sitios que usan ese literal `"SplitMember"` para derivar
son `GroupUserIdentityService.swift:72` (que muere: `deterministicMemberID(groupZoneID:)`, **0 callsites
en todo el repo — verificado**) y `GroupsSyncClient.swift:1901` (que vive).

⇒ **`deterministicUUID` no es solo «una función que se conserva»: es una primitiva del canal NUEVO que
seguirá viviendo en la carpeta del canal VIEJO** (`Yala/Services/Groups/`). Se cumple el criterio de
salida (`import CloudKit` se va en `:9`), pero el fichero pierde toda su razón de estar ahí. Si en
algún momento se mueve, el namespace `"SplitMemberBackend"` (`:32`) y el literal `"SplitMember"`
(`:1901`) tienen que viajar sin tocarse: cambiar cualquiera de los dos re-deriva todos los ids locales
de member y **duplica cada miembro en cada device**, sin error de compilación ni test rojo (los tests
que lo pinean, `CloudSync/GroupBackendIdentityLogicTests.swift:35-44` y
`CloudSync/GroupsSyncClientTests.swift:407/428/432`, comparan las dos funciones entre sí — se moverían
juntos y seguirían verdes).

---

## §4 · 🔴 R-D · `ContentView` presenta el onboarding de invitación del BACKEND con la vista y el cover del CANAL VIEJO

**Este acoplamiento no aparece en ninguno de los otros cinco ficheros de medición.**

No existe ninguna `GroupBackendInviteOnboardingView` (verificado con `find`). El intent backend
**reusa la vista CloudKit-era**:

```
Yala/App/ContentView.swift:878-885
        case .presentGroupBackendInviteOnboarding(let zone):
            if !hasCompletedOnboarding {
                pendingInviteMetadata = nil  // backend: sin CKShare metadata — visual genérico
                showGroupInviteOnboarding = true
            } else { … GroupBackendInviteEntryHandler.continueFlow(zoneName: zone) }
```

y ese `showGroupInviteOnboarding` monta el **mismo** cover que el camino CloudKit (`:849`):

```
Yala/App/ContentView.swift:1733-1747
    .fullScreenCover(isPresented: $showGroupInviteOnboarding) {
        GroupInviteOnboardingView(inviteMetadata: pendingInviteMetadata) { outcome in
            if GroupInviteOnboardingLogic.shouldClearPendingInvite(outcome: outcome) {
                PendingInviteStore.clear()          // :1739  ← CONDENADO
            }
            hasCompletedOnboarding = true            // :1743  ← el backend DEPENDE de estas 3
            showGroupInviteOnboarding = false        // :1744
            pendingInviteMetadata = nil              // :1745
        }
```

⇒ **`:1739` es la única línea CloudKit de esa closure; `:1743-1745` son la terminación del onboarding
del canal BACKEND.** Borrar la closure, o el cover, o «el bloque de PendingInviteStore» de más, deja al
invitado backend fresco con el cover **pegado** y sin `hasCompletedOnboarding = true`. El compilador
señala `:1739` (tipo borrado) pero **no protege `:1743-1745`** — un borrado por bloque las arrastra sin
una sola queja.

Cadena completa que el canal backend comparte con la vista condenada, medida:

| Pieza | Coordenada | Estado |
|---|---|---|
| `GroupInviteOnboardingView` | `Yala/App/Views/Groups/GroupInviteOnboardingView.swift` | **SOBREVIVE** (la usa el backend). Su `import CloudKit` en `:13` está **MUERTO** — 0 símbolos `CK*` |
| `GroupInviteOnboardingLogic` + `JoinIntentPhase` + `Step` | `Yala/App/Logic/GroupInviteOnboardingLogic.swift:19-107` | **SOBREVIVE** |
| `GroupJoinIntentTracker` | `Yala/Services/Groups/GroupJoinIntentTracker.swift` | **SOBREVIVE** — lo alimenta el backend en `GroupBackendInviteEntryHandler.swift:208`, `:210`, `:235` |
| `InviteMetadata` (`shareMetadata: CKShare.Metadata` **no-opcional**) | `Yala/App/Models/RouterIntent.swift:50-79` | el backend pasa **`nil`** (`ContentView.swift:883`) ⇒ borrar el parámetro `inviteMetadata:` es seguro para el backend, pero es un cambio de firma en una vista compartida |

**Falso positivo que descarté (y por qué es sutil):** `GroupJoinIntentTracker.retry()` toca
`PendingInviteStore.current()` en `:122` — dentro de `case .acceptFailed`. El canal backend **SÍ** pone
el tracker en `.failed(.acceptFailed(…))` (`GroupBackendInviteEntryHandler.swift:235`), pero con
`recoverable: false`, y la UI enruta ese caso al chip **sin botón de retry**
(`GroupsContainerView.swift:536-547` — `case .acceptFailed(recoverable: false), .expired:` → chip
`invite_expired_banner` con solo una X). Solo `SplitSyncManager` emite `recoverable: true`. ⇒ el `case
.acceptFailed` de `retry()` (`:121-138`) es CloudKit-only y se puede borrar. **Verificarlo así, por la
propagación de `recoverable`, no por «el backend llama a retry()»** — que sí lo hace.

---

## §5 · 🟠 R-E · Las credenciales de re-join del canal BACKEND se revocan en un fichero condenado

Ampliación de lo que `conservar` (§d) y `tests` (#2) vieron por separado; lo pongo junto porque es una
cadena, no dos hallazgos.

```
Yala/App/Logic/GroupsIdentityPurgeGate.swift:156      hasCloudSession: … = { CloudAuthService.shared.hasSession }
Yala/App/Logic/GroupsIdentityPurgeGate.swift:157-159  revokePendingJoinCredential: … = { PendingJoinStore.revokeLegacyMemberKey(zoneName: $0) }
Yala/App/Logic/GroupsIdentityPurgeGate.swift:176-199  rama .retainRevokingRejoinCredentials
                                                       :185  row.backendReInviteToken = nil
                                                       :187  row.rejoinRevokedAt = revokedAt
```

- `PendingJoinStore.revokeLegacyMemberKey` vive en un fichero **SUPERVIVIENTE**
  (`Yala/Services/Groups/PendingJoinStore.swift:174`, 215 líneas, **no listado en el plan**) y su ÚNICO
  callsite de producción es `GroupsIdentityPurgeGate.swift:159`, que muere.
- `SplitGroup.rejoinRevokedAt` lo lee un consumidor **VIVO del canal backend**:
  `GroupBackendInviteEntryHandler.swift:113` — `guard group.rejoinRevokedAt == nil else { return nil }`.
- La sesión del gate es la de la cuenta **Yala** (`CloudAuthService.shared.hasSession`), no iCloud: es
  decir, este fichero «del transporte» es la única implementación del repo de *«revocar las credenciales
  de re-join del canal BACKEND de una zona»*.

⇒ tras el borrado, `rejoinRevokedAt` **nunca se escribe** ⇒ el guard de `:113` es siempre `nil` ⇒ nunca
corta. Y el otro extremo: `case .deleteLocalRows` (`:201-207`) + `deleteRows` (`:222-252`) se van con el
fichero, así que tampoco queda camino automático de purga por cambio de Apple ID. Combinado con la
regla de área («con una sola credencial viva, el humano nuevo entra COMO el anterior con permiso de
editar y borrar»), esto es una **regresión de frontera de usuario en el canal nuevo**, no un no-op.

---

## §6 · 🟠 R-F · Un gate VIVO en producción que el plan borra, contra el contrato escrito en el código

```
Yala/App/ContentView.swift:2063-2071
            } else if !CloudSyncFlags.groupsBackendEnabled,
                      GroupsICloudAvailabilityGateLogic.shouldShowGate(
                          isAccountAvailable: syncService.isAccountAvailable,
                          isUITest: UITestHooks.isActive
                      ) {
                // M1 / D8 (G5-C): el gate CloudKit-era (sin iCloud del OS) se RETIRA bajo el flag — el
                // canal grupos→backend no exige la cuenta iCloud del sistema. Con flag OFF (TODO device
                // prod hoy) es byte-idéntico. La lógica pura y la vista NO se borran (retiro real post-G6).
                GroupsICloudUnavailableView()
```

El comentario `:2071` es explícito: **«La lógica pura y la vista NO se borran (retiro real post-G6)»**.
El plan (`:266`) las borra en la Fase 3 commit 1. Y por §0 (`groupsBackendEnabled == false` en todo
device de producción) **ese gate es el que hoy se muestra de verdad**: borrarlo devuelve a un device sin
iCloud el `GroupsContainerView` con spinner/empty-state mudo, que es exactamente el estado que el gate
se creó para eliminar.

Colateral verificado: las 3 keys L10n (`Yala/Utils/L10n.swift:2302` `enum ICloudGate`) quedan huérfanas
en los 16 locales. **No pone rojo nada**: `YalaTests/LocalizationParityTests.swift:52` y `:72` solo
comparan locales entre sí (orphans cross-locale), no contra el código.

---

## §7 · Claves de `UserDefaults` declaradas en ficheros condenados — inventario completo

| Key | Declarada en | ¿La usa el canal backend? |
|---|---|---|
| `groups_currentUserRecordName` | `GroupUserIdentityService.swift:18` | **SÍ — 4 consumidores backend** (§1). Queda sin escritor |
| `yala.groups.pendingInvite` | `PendingInviteStore.swift:49` | no. Pero la limpia `AppRouter.resetAll()` (`Yala/App/Models/AppRouter.swift:156`), que **sí** está en el camino de cierre del backend (`Yala/Utils/SwiftDataConfiguration.swift:382-384` documenta esa cadena). Compiler-visible |
| `yala.groups.pendingLeaveShareZones` | `PendingLeaveShareTracker.swift:25` | no. **Residual:** su retry de boot (`AppBootstrapper.swift:1163-1180`) muere con `SplitZoneManager` ⇒ un `leaveShare` que falló queda pendiente **para siempre**, con la key colgando. Nadie la borra |
| `SplitSync_ContainerMigrated_v1` | `SplitSyncManager.swift:292` | no. Key zombi tras el borrado (inofensiva) |
| `AppPreferences.Keys.groupsBetaUnlocked` (escritura) | `CKShareEntryHandler.swift:43` | **NO es riesgo — verificado**: el backend tiene escritores propios en `GroupBackendInviteEntryHandler.swift:72` y `AppBootstrapper.swift:1712` |
| `AppPreferences.Keys.hasCompletedOnboarding` (lectura) | `CKShareEntryHandler.swift:55` | solo lectura |

---

## §8 · Trampas que BUSQUÉ y NO existen (para que nadie las vuelva a buscar)

| Sospecha | Medición | Veredicto |
|---|---|---|
| `Notification.Name` declarado en un fichero condenado que el backend observe | `grep "Notification.Name\|\.post(name\|addObserver\|publisher(for"` sobre los 14 condenados → **1 solo hit**: `SplitSyncManager.swift:599`/`:660`, que **observa** `.iCloudFirstImportCompleted` (declarada en el canal personal) | **Limpio.** Cero nombres de notificación declarados en código condenado ⇒ una clase entera de rotura silenciosa descartada |
| `enqueueSave`/`enqueueDeletion` es también el write-path del backend | el drain backend NO usa outbox por-mutación: usa **SwiftData History** (`GroupsSyncClient.swift:501-720`, `HistoryChange` / `DefaultHistoryInsert/Update/Delete`, `translateChange`) | **Limpio.** Borrar los ~29 `enqueueSave`/`enqueueDeletion` no le quita nada al backend |
| El gate de zonas del drain vive en `SplitSyncManager` | el backend tiene su copia propia: `GroupsSyncClient.swift:501` `backendGroupZoneIDs`. La del transporte es `SplitSyncManager.swift:853` `backendGroupZoneNames`. **Predicado idéntico** (`isBackendGroup == true`), ficheros distintos | **Limpio** |
| La autoexclusión de avisos del backend cuelga de `cachedRecordName` | `GroupsSyncClient.classifyNewMemberForNotification` (`:1574-1598`) pasa `currentUserRecordID: currentUserIDProvider()?.lowercased()` — el **`sub`**, no el recordName. Solo `SplitSyncManager.swift:1649` usa `cachedRecordName` ahí | **Limpio** — pero era la trampa esperada; conviene no «unificar» las dos llamadas al borrar |
| El widget / la share extension tocan código condenado | `grep` de los 13 tipos en `YalaWidgets/` y `YalaShare/` → **0 hits** | **Limpio** |
| El servidor valida el formato de `group_id` | `grep -iE "check\|constraint\|like\|~"` sobre `group_id` en `gateway/migrations/*.sql` → **0** | **NO limpio, al contrario** — refuerza §2: nada caza un prefijo mal escrito |
| `deterministicMemberID(groupZoneID:)` (instancia) hay que conservarla | `grep -rn "deterministicMemberID(groupZoneID"` y `"shared.deterministicMemberID"` → solo su propia definición (`GroupUserIdentityService.swift:70-73`) | **Ya muerta hoy.** Se va gratis; el backend usa `GroupBackendIdentityLogic.deterministicMemberID` |

---

## §9 · Ranking de MI lente

| # | Riesgo | Compilador | Test | Severidad |
|---|---|---|---|---|
| 1 | **§0 — el canal backend está compilado-OFF**; borrar el transporte deja Grupos sin ningún canal | no | no | 🔴 bloqueante de decisión |
| 2 | **§1 R-A — `cachedRecordName` sin escritor** (`AppBootstrapper:440` es el warm-up incondicional que hoy la puebla) ⇒ pérdida de la membresía histórica en re-join de grupo migrado, y con flag OFF colapso de `isCurrentUser` | no | **los tests lo TAPAN** por inyección | 🔴 |
| 3 | **§2 R-B — `zonePrefix` es el `group_id` del wire** y ninguna capa valida el formato | sí (la referencia) / **no** (el valor) | no | 🔴 |
| 4 | **§4 R-D — el onboarding de invite del backend usa la vista y el cover del canal viejo**; `ContentView.swift:1743-1745` tiene que sobrevivir a un borrado por bloque | parcial (solo `:1739`) | no | 🔴 |
| 5 | **§5 R-E — `rejoinRevokedAt` deja de escribirse** ⇒ el guard backend de `GroupBackendInviteEntryHandler:113` nunca corta | no | no | 🟠 |
| 6 | **§6 R-F — se borra un gate VIVO** contra el contrato escrito en `ContentView.swift:2071` | no | no | 🟠 |
| 7 | **§3 R-C — namespaces de `deterministicUUID`**: contrato cross-device, y los tests que lo pinean se moverían con él | no | **no** (se auto-consistentan) | 🟠 al mover |
| 8 | §7 — `yala.groups.pendingLeaveShareZones`: un leave pendiente queda huérfano para siempre | no | no | 🟡 |
