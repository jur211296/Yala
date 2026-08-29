<!-- INDICE:inicio — generado por scripts/indexar_doc.py, no editar a mano -->

## Índice (16 entradas)

> **No hace falta leer este fichero entero** — son 91 KB. Localiza la entrada
> aquí y salta a ella.

- `—` [E1 · Usuario existente Yala Completo que actualiza](#e1--usuario-existente-yala-completo-que-actualiza)
- `—` [Invariante (ii) — «El sign-in de Apple/Google es 100 % independiente del container privado»](#invariante-ii--el-sign-in-de-applegoogle-es-100--independiente-del-container-privado)
- `—` [Críticas](#crticas)
- `—` [Altas](#altas)
- `—` [Medias](#medias)
- `—` [Bajas](#bajas)
- `—` [Lo que SÍ cumple (verificado con lente inversa, no depende de ningún flag apagado)](#lo-que-s-cumple-verificado-con-lente-inversa-no-depende-de-ningn-flag-apagado)
- `—` [A.1 Hallazgos que cayeron por completo](#a1-hallazgos-que-cayeron-por-completo)
- `—` [A.2 Sub-afirmaciones caídas dentro de hallazgos que sí sobrevivieron](#a2-sub-afirmaciones-cadas-dentro-de-hallazgos-que-s-sobrevivieron)
- `—` [E2 · Usuario existente Solo Grupos que actualiza](#e2--usuario-existente-solo-grupos-que-actualiza)
- `—` [E4 · Usuario nuevo que elige nube (backend propio)](#e4--usuario-nuevo-que-elige-nube-backend-propio)
- `—` [E5 · Usuario nuevo Solo Grupos](#e5--usuario-nuevo-solo-grupos)
- `—` [E3 · Usuario nuevo que elige iCloud](#e3--usuario-nuevo-que-elige-icloud)
- `—` [E6 · Usuario existente en iCloud que migra sus datos personales a la nube](#e6--usuario-existente-en-icloud-que-migra-sus-datos-personales-a-la-nube)
- `—` [Invariante (i) — «Siempre se identifica si el container privado de iCloud está en uso o libre»](#invariante-i--siempre-se-identifica-si-el-container-privado-de-icloud-est-en-uso-o-libre)
- `—` [Meta — «No seguir generando container de grupos en iCloud»](#meta--no-seguir-generando-container-de-grupos-en-icloud)

<!-- INDICE:fin -->

---
created: 2026-07-27
updated: 2026-07-27
tags: [modo-nube, auditoria, escenarios]
---

# Modo Nube — Auditoría de escenarios de usuario (branch 2.0.5)

> **Reencuadre del owner (2026-07-27, mismo día): el estado DARK NO es el problema** — es esperado y deliberado. La pregunta real que este informe debe contestar es **«el día que se enciendan los flags, ¿funcionará como espero?»**. Léelo con esa lente: lo que importa es qué hallazgos **sobreviven al encendido**, no que hoy nada sea alcanzable. Esa relectura, agrupada en A (código que no existe) / B (existe pero no cumple el objetivo) / C (bugs que el encendido estrena) / D (lo que sí cumple), y las **7 decisiones** que cierran las brechas, viven en [[MODO-NUBE-DECISIONES-ESCENARIOS]] — **ese documento es la SSOT y gana sobre este cuando difieran**.

Auditoría de código, solo lectura, sobre `/Users/jur/Yala` branch `2.0.5`. Toda afirmación de
comportamiento lleva su `ruta/relativa.swift:linea`. Convención usada en todo el documento:

- **ACTIVO** — produce comportamiento de usuario hoy, en un build de producción (scheme `Yala`, sin `DEV_BUILD`).
- **DARK** — el código existe y compila, pero un flag o una config apagada impide que produzca comportamiento
  de usuario. **Un flujo DARK no cumple ninguna expectativa de producto.**
- **NO EXISTE** — no hay código, o hay código sin ningún callsite (código muerto).

---

## §0 · Veredicto

1. **La implementación actual NO entrega el UX de Modo Nube. Entrega cero por ciento de él a un usuario de producción**: los dos gates maestros (`CloudBackendConfig.isConfigured == false`, `CloudBackendConfig.swift:42-44`; `groupsBackendCompiledDefault = false`, `CloudSyncFlags.swift:239`) apagan la épica completa en todos los builds, incluido `Yala Dev` para grupos.
2. **Lo construido es mucho y es de buena calidad**: migración, reversa, adopt de 2º device, sesión secundaria, canal de grupos backend, consents, hojas de alcance destructivo, 4 caminos de sign-out. Nada de eso es alcanzable: la fila «Dónde viven tus datos» está oculta (`StorageRowGateLogic.swift:30`) y `CloudMigrationController.shared` nunca se instancia (`CloudMigrationController.swift:152`).
3. **Dos piezas del diseño no están DARK, están sin construir**: la elección born-cloud (`WelcomeAccountChoiceLogic.visibleNewOptions`, `WelcomeAccountChoiceLogic.swift:36`) no tiene **ningún callsite** en `Yala/` — es código muerto con tests verdes; y **no existe una sola línea en el repo que borre una zona del container privado** (grep de `deleteRecordZone|CKModifyRecordZones|purgeCloudKit` = 0 hits).
4. **La meta «dejar de generar container de grupos en iCloud» está incumplida y va en dirección contraria**: hay 7 caminos que crean o engordan ese container, 5 ACTIVOS hoy, y uno **sin ninguna acción del usuario** (`recoverOwnedGroupZonesIfNeeded` en cada arranque, `SplitSyncManager.swift:397-434`).
5. **La invariante «siempre se sabe si el container privado está en uso» está incumplida por cableado, no por imposibilidad**: el detector existe, es barato y está device-validado (`CKIdentityCapture.swift:43-51`, `:249-266`), y sus únicos consumidores de producto están dentro de la migración DARK.
6. **La invariante «sign-in independiente del container» se cumple en la autenticación y se incumple en el perímetro**: `CloudAuthService` no toca iCloud y su credencial es device-only (`CloudAuthKeychainStorage.swift:43`), pero el tab Grupos exige cuenta iCloud del OS (ACTIVO, `ContentView.swift:1960`) y la identidad del miembro de grupo **es** el Apple ID (`GroupUserIdentityService.swift:26-32`).
7. **La señal de iCloud de toda la app es el token de iCloud Drive, no el estado de CloudKit**: `FileManager.ubiquityIdentityToken != nil` (`SwiftDataConfiguration.swift:36-38`), cero `accountStatus`, cero `CKAccountChanged`. Ese booleano decide el mount del mirror, el gate de Grupos y el restore.
8. **Grupos no exige sign-in en ningún punto, y con el flag encendido tampoco tendría una puerta**: el árbol del tab tiene 2 gates (código beta `"1050"` y cuenta iCloud) y ninguna rama consulta `CloudAuthService.hasSession` (`ContentView.swift:1952-1971`). Con el flag ON el sign-in sería obligatorio para **crear** y para **unirse por invite backend**, nunca para entrar.
9. **La migración de grupos, cuando se encienda, no puede completar el corte**: es owner-only por predicado (`GroupMigrationUploader.swift:123-126`), no hay camino del invitado ni server-side, y no borra la zona. Un owner que no abra la app mantiene su zona indefinidamente.
10. **Lo único nuevo de esta épica que un usuario de producción ve hoy son las hojas de alcance destructivo** (`DestructiveScopeLogic`), y en un device sin cuenta iCloud una de sus filas miente: dice «iCloud — También se borran» sobre un store que no tiene mirror (`DestructiveScopeLogic.swift:95-98`).
11. **El riesgo real inmediato no es de Modo Nube, es de handover de dispositivo**: tras «Cerrar sesión» + «Soy nuevo», el store de GRUPOS sobrevive el wipe por diseño (`DataWipeService.swift:280-284`) y el bridge materializa los gastos del usuario anterior en las finanzas del nuevo (`GroupTransactionBridge.swift:150`), con el gate beta ya desbloqueado (`DataWipeService.swift:270`).
12. **Qué falta para que E1..E6 existan**, en orden: (i) proyecto Supabase de producción y `isConfigured`; (ii) el callsite born-cloud; (iii) una puerta de sign-in real en Grupos; (iv) el borrado de zona personal y de grupos; (v) cablear `CKIdentityCapture` como detector del eje D fuera de la migración; (vi) decidir los 17 estados huérfanos del §4 antes de encender nada.

---

## §1 · Los cuatro ejes de estado

| Eje | Pregunta | SSOT real en el código | Valor por defecto / valor real hoy |
|---|---|---|---|
| **A** | ¿Dónde viven los datos personales? | `CloudSyncFlags.storageMode` (getter compuesto, `CloudSyncFlags.swift:164-171`) sobre `StorageModePersistence` — key `UserDefaults` `"cloudSync.storageMode"` (`CloudSyncFlags.swift:37`) | **`.icloud` siempre**. Ante key ausente el `read()` devuelve `.icloud` (`:52-57`). `.cloud` es DARK inalcanzable: sus dos writes (`MigrationWorkExecutor.swift:425` y `:1126`) cuelgan de `isConfigured` |
| **B** | ¿Identidad de cuenta de nube? | `CloudAuthService.shared` (`AuthClient` de Supabase) + Keychain propio `com.yala.cloudauth` (`CloudAuthService.swift:130`, `CloudAuthKeychainStorage.swift:26`) | **Ausente por construcción**: `client == nil` si `!isConfigured` (`CloudAuthService.swift:161-183`) ⇒ `hasSession == false` (`:204`) y `signIn` lanza `.notConfigured` (`:265`) |
| **C** | ¿Dónde viven los grupos? | Dos capas: device `CloudSyncFlags.groupsBackendEnabled` (`CloudSyncFlags.swift:230-236`) y por-grupo `SplitGroup.isBackendGroup` (LOCAL-only, `SplitGroup.swift:52`) + `movedToBackendAt` (viaja por CloudKit, `:58`) | **CloudKit / CKSyncEngine + CKShare siempre**. `groupsBackendCompiledDefault = false` sin `#if` (`:239`) y el getter es `compilado && remoto` con short-circuit (`:233`) ⇒ **el remote-config no puede encenderlo, solo matarlo** |
| **D** | ¿El container privado de iCloud está ocupado por datos de Yala? | **No existe SSOT.** No hay variable, flag ni consulta que lo represente | Se **infiere** en cada punto de decisión desde conteos del store local (`ContentView.swift:875-885`, `iCloudSyncService.swift:684-717`) o timestamps del iCloud KV (`RestoreOfferGate.swift:26-39`) |

**Tercer estado del eje A que sí ocurre hoy y no está en el enum**: `PersonalStoreDecision.localNoMirror`
(`SwiftDataConfiguration.swift:236-243`, rama 4), el device sin cuenta iCloud. `StorageMode` solo tiene
`.icloud` y `.cloud` (`CloudSyncFlags.swift:27-30`), así que toda la lógica lo trata como «iCloud».

**Eje de facto no enumerado (D'): el derecho de uso.** `isProUser` se deriva solo de
`StoreKit.Transaction.currentEntitlements` (`StoreKitManager.swift:243`) y de él cuelgan tanto features como
**límites de creación de cuentas y presupuestos** (`FeatureGateService.swift:126-130`). Cero `appAccountToken`
en el repo: el derecho está atado al Apple ID de App Store, no a la cuenta de nube.

**Forma de la app (no es un eje de estado, es una recomposición):** no existe ningún enum que nombre «Yala
Completo / Solo Grupos / personal-solo». Se recompone en cada call-site desde
`(OnboardingMode, UsageFocus)` vía `ShellModeLogic.effective` (`ShellModeLogic.swift:32-34`), con la
frontera shell-vs-behavior documentada solo en un comentario (`:8-12`).

---

## §2 · Tabla maestra de estados alcanzables

Notación — **A**: `iCloud` (mirror `.private`) · `local` (sin cuenta iCloud) · `cloud` (backend propio) ·
`sec` (store secundario M1). **B**: `—` sin sesión · `SIWA`/`Google`. **C**: `CK` CloudKit ·
`BE` backend · `n/a`. **D**: `libre` · `ocupado` · `n/a`.

| # | A | B | C | D | ¿Hoy? | Cómo se llega, o por qué no | Evidencia |
|---|---|---|---|---|---|---|---|
| 1 | iCloud | — | n/a | libre | **SÍ** | Alta nueva. Única opción visible del Welcome | `WelcomeAccountChoiceLogic.swift:52-64` |
| 2 | iCloud | — | CK | libre→ocupado | **SÍ** | Yala Completo con grupos (código beta o invitación) | `GroupsBetaGateLogic.swift:34`; `GroupService.swift:101` |
| 3 | iCloud | — | n/a | **ocupado** | **SÍ** | Returning user: reinstalación → «Ya tengo cuenta» → Restaurar iCloud | `WelcomeRestoreView.swift:55-57` |
| 4 | iCloud | — | CK | ocupado | **SÍ** | Igual que 3 con grupos; `RestoreRouter` respeta el `onboardingMode` restaurado | `RestoreDestination.swift:27-34` |
| 5 | iCloud (Solo Grupos legado) | — | CK | ocupado | **SÍ** | `onboardingMode == .groupInvite`; shell reducida a `[.groups]` | `ShellModeLogic.swift:33`; `TabBarConfiguration.swift:96` |
| 6 | iCloud (Solo Grupos D1) | — | CK | ocupado | **SÍ** | `usageFocus == .groupsOnly` tras vaciar datos con grupos vivos; **sigue con store personal** | `UsageFocus.swift:17-19`; `GroupsRetentionView.swift:64` |
| 7 | **local** | — | n/a | n/a | **SÍ** | Device sin cuenta iCloud. El tab Grupos queda BLOQUEADO. El mount es `.automatic`, **no sin-mirror** | `SwiftDataConfiguration.swift:701-702`; `GroupsICloudAvailabilityGateLogic.swift:31-32` |
| 8 | iCloud | — | CK | ocupado + marker de migración | **NO** | Exige que otro device escriba `CloudMigrationMarker`; nadie lo escribe hoy | `CloudMigrationMarker.swift:16-20` |
| 9 | cloud | SIWA | CK congelado | ocupado | **NO** — DARK | Cutover completo. `.cloud` solo se escribe tras claim autenticado | `MigrationWorkExecutor.swift:425`; `CloudBackendConfig.swift:42-44` |
| 10 | cloud | Google | CK congelado | ocupado | **NO** — DARK | Idéntico a 9 (el chooser ofrece ambos, sin preselección) | `StorageSignInChooserView.swift:21` |
| 11 | cloud | SIWA/Google | **BE** | ocupado congelado | **NO** — DARK ×2 | Exige `isConfigured` **y** `groupsBackendEnabled` | `CloudSyncFlags.swift:239` |
| 12 | iCloud | SIWA/Google | **BE** | ocupado | **NO** — DARK | «Sesión solo-grupos»: estado **previsto y codificado** (el código ya asume A⊥B en el cierre) | `CloudSignOutFlowLogic.swift:32-37`, `:57` |
| 13 | sec | SIWA/Google | CK del dueño | ocupado por el dueño | **NO** — DARK | Entrada secundaria M1; el getter devuelve `.cloud` con la key persistida en `.icloud` | `CloudSyncFlags.swift:167`, `:209-212` |
| 14 | **local** | SIWA/Google | BE | n/a | **NO** — **NO EXISTE** | Born-cloud «mis datos sin depender de Apple»: sin callsite, y `StorageMode` no tiene caso local | `WelcomeAccountChoiceLogic.swift:36`; `CloudSyncFlags.swift:27` |
| 15 | cloud | — | cualquiera | cualquiera | Transitorio, **neutralizado** | Sin `currentUserID` o sin registro de claim el runtime queda `.idle` | `LiveCloudSessionProvider.swift:51-59` |
| 16 | cloud + `mirrorOffArmed=false` | — | — | — | **Alcanzable y es el limbo** | El mirror exige el PAR completo para apagarse ⇒ mirror ON con modo nube: doble escritura | `SwiftDataConfiguration.swift:241-242`; `MigrationRunner.swift:582-596` |
| 17 | iCloud | SIWA ≠ dueño | CK | ocupado por otro | **NO** — DARK | `CrossAccountEntryGuardLogic` → `.blockedForeignData` + `signOut()`. **Falla ABIERTO** si el fetch lanza | `CrossAccountEntryGuardLogic.swift:50-58`; `ContentView.swift:875-885` |

**Lectura.** Las filas 1-7 son el **100 % del universo de producción**: A ∈ {iCloud, local}, B siempre
ausente, C siempre CloudKit. Los ejes B y C **no tienen variabilidad en producción**. La única variabilidad
real es (forma × D). Las filas 9-13 están diseñadas y construidas. La fila 14 —el usuario bandera del
épico— es el agujero: ni código ni entrada. La fila 16 es un agujero distinto y peor: es un estado
**alcanzable** que nadie quiere.

---

## §3 · Escenario por escenario

### E1 · Usuario existente Yala Completo que actualiza

**Expectativa del dueño.** (a) Ve una sección «Dónde viven tus datos» que le dice que está en iCloud
privado, con estado de sync, y la posibilidad de migrar a nube con su consentimiento. (b) Puede borrar
sus datos y el borrado alcanza **solo** los datos personales. (c) Puede cerrar sesión y volver: al Welcome
con los datos de iCloud disponibles, y si no quiere volver a ellos, entrar en modo nube (porque iCloud está
ocupado) o con otra cuenta Google/Apple. (d) Al entrar a Grupos se le exige sign-in para no seguir generando
container de grupos en iCloud, y sus grupos legacy migran al backend al 100 %.

**Recorrido real.**

1. Abre la app tras actualizar. Los 4 hooks destructivos pre-mount son no-op (`YalaApp.swift:68-79`). El
   store personal se monta exactamente igual que antes: `.iCloudMirror` (`SwiftDataConfiguration.swift:236-243`).
2. En el bootstrap, los 3 pasos nuevos de la épica son no-ops verificados: remote-config sin tráfico
   (`AppBootstrapper.swift:273-275`), `CloudMigrationController.shared == nil` (`:282-285`), migración de
   grupos no corre (`:421`). El motor CloudKit de Grupos **sí** arranca, sin gate (`:308`).
3. Ajustes → sección de datos. Ve: Exportar / Importar, **«iCloud»** (`ProfileView.swift:901`) y **«Vaciar
   datos»** (`:935-946`). La fila «Dónde viven tus datos» **no está**: `StorageRowGateLogic.swift:30` hace
   `guard isConfigured`.
4. «Vaciar datos» → hoja de alcance con 3 filas → segunda confirmación → borra 12 entidades del store
   personal y **ninguna** `Split*` (`DataWipeService.swift:44-186`, exclusión en `:280-284`).
5. «Cerrar sesión» → `CloudSignOutFlowLogic.path` resuelve `.privateReset` (`:51-59`) →
   `performPrivateReset` no borra nada, solo 3 flags de onboarding (`CloudSessionSignOut.swift:190-195`) →
   Welcome en sesión. Re-entrada por «Ya tengo una cuenta», que con una sola opción visible hace **bypass
   directo** a Restaurar iCloud (`WelcomeAccountChoiceLogic.swift:66-68`; `WelcomeFlowContainer.swift:137`).
   Segunda puerta: el alert «Detectamos tu cuenta» del Hero con «Cargar mis datos».
6. Tab Grupos → pared de código beta `"1050"` (`GroupsBetaGateLogic.swift:20`) → gate de cuenta iCloud
   (`ContentView.swift:1960`) → `GroupsContainerView`. **Ninguna de las 3 ramas consulta la sesión de nube.**
   Cada grupo nuevo encola una `CKRecordZone` (`GroupService.swift:101` → `SplitZoneManager.swift:44`) y cada
   invitación un `CKShare` (`GroupMembersView.swift:449-462`).

| Punto de la expectativa | Realidad | Veredicto |
|---|---|---|
| (a) Sección «Dónde viven tus datos» = iCloud privado | La fila está oculta; la pantalla existe y su `statusCard` sí lo diría (`StorageSettingsView.swift:141`). Mitigación: la fila «iCloud» sí es ACTIVA y su copy dice que los datos se almacenan en su cuenta personal de iCloud | **NO CUMPLE** (DARK) |
| (a) Estado de sync debajo del status | `syncStatusSection` solo se inserta en `uiState == .cloudActive` (`StorageSettingsView.swift:117`, `:252`) | **NO CUMPLE**, pero el estado de sync de iCloud sí vive en `iCloudSyncSettingsView` (ACTIVO) |
| (a) Posibilidad de migrar a nube | `configureShared` retorna antes de construir nada ⇒ sin controller no hay runner y `persistLocalMode` jamás corre (`CloudMigrationController.swift:152`; `MigrationWorkExecutor.swift:425`) | **NO CUMPLE** (DARK) |
| (b) Borrado solo de datos personales | 12 entidades del store personal, cero `Split*`, exclusión documentada y pinneada por test | **CUMPLE** |
| (c) Cerrar sesión → Welcome con datos disponibles | `.privateReset` no borra ninguna fila ni archivo; dos puertas de re-entrada | **CUMPLE** |
| (c) Entrar en modo nube porque iCloud está ocupado | Las cards Apple/Google exigen `isConfigured && remoteCloudEnabled`; «empezar en nube» **no existe como pantalla** | **NO CUMPLE** (NO EXISTE) |
| (d) Grupos exige sign-in | 2 gates, ninguno lee `hasSession`. Con el flag ON el sustituto sería un CTA de empty state (solo con lista vacía) y el gate al **crear** | **NO CUMPLE** |
| (d) Migración del 100 % de los grupos + liberar iCloud | Flag compilado `false`; predicado owner-only + `ckSystemFieldsData != nil`; el uploader no borra la zona | **NO CUMPLE** (DARK + incompleto por diseño) |

**Brechas (evidencia).** `E1-01` fila oculta (`StorageRowGateLogic.swift:30`, `ProfileView.swift:915`) ·
`E1-02` controller nil (`CloudMigrationController.swift:152`) · `E1-07` sin puerta a nube ni a otra cuenta
(`WelcomeAccountChoiceLogic.swift:60`, `:36`) · `E1-09` Grupos sin sign-in (`ContentView.swift:1952`) ·
`E1-10` migración de grupos DARK y owner-only (`CloudSyncFlags.swift:239`; `GroupMigrationUploader.swift:123-126`)
· `E1-11` sin detección de ocupación (`iCloudSyncService.swift:531`) · `E1-N1` freeze viaja por CloudKit pero
la re-entrada depende de flags locales (`SplitGroup.swift:54-61`; `GroupFreezeLogic.swift:43-50`) ·
`E1-N4` el guard cross-cuenta falla **abierto** con `try?` + `?? 0` (`ContentView.swift:882-884`) ·
`E1-N3` la fila iCloud de las hojas destructivas miente en un device sin cuenta iCloud
(`DestructiveScopeLogic.swift:95-98`) — **lo único de esta tanda visible HOY**.

---

### E2 · Usuario existente Solo Grupos que actualiza

**Expectativa del dueño.** Al entrar a Grupos se le exige sign-in con Apple o Google; sus grupos legacy
migran al backend y se deja de generar container de grupos en iCloud; al salir, el dispositivo queda
disponible para otro usuario, y al volver a entrar con su usuario de nube recupera todos sus grupos.

**Quién es en el código.** `OnboardingMode.groupInvite` (`OnboardingView.swift:1794-1843`): shell reducida a
`[.groups]`, sin cuenta ni saldo personal, `groupsBetaUnlocked = true` (`:1813`). **Matiz que cambia el
diagnóstico**: aunque no tenga «datos personales», **ya ocupa el container privado personal** — el store se
monta `.private` sin mirar el modo (`SwiftDataConfiguration.swift:697-700`) y el alta siembra categorías ahí
(`OnboardingView.swift:1817-1818`).

**Recorrido real.** Abre la app y **no ve nada nuevo**: `runReturningUserPostChecks` salta What's New para
group-invite (`ContentView.swift:1042`). Entra a Grupos sin firmar nada. Crea un grupo: zona CloudKit nueva.
Invita: CKShare nuevo. «Salir de Yala en este dispositivo» → `.privateReset` → no borra nada.

| Punto de la expectativa | Realidad | Veredicto |
|---|---|---|
| Sign-in exigido al entrar a Grupos | Ninguna rama de `viewForTab(.groups)` lee `hasSession` (`ContentView.swift:1957-1970`). Con el flag ON el sign-in es obligatorio para **crear** y para el invite backend, no para entrar; y encender el flag **retira** el gate de iCloud sin sustituto | **NO CUMPLE** |
| Sus grupos migran; se deja de generar container | Uploader DARK (flag + sesión + consent) y owner-only. Un Solo Grupos que llegó por invitación depende de que el owner ajeno abra su app | **NO CUMPLE** |
| Al salir, el device queda limpio para otro | `.privateReset` resetea 3 flags; el wipe de «Soy nuevo» excluye el dominio Grupos por diseño (`DataWipeService.swift:280-284`). Aislamiento real: solo si cambia el **Apple ID** (`runIdentityBootGuard`, ACTIVO) | **NO CUMPLE** en handover sin cambio de Apple ID |
| Al volver con su usuario de nube ve sus grupos | `isConfigured == false` ⇒ `client` nil ⇒ `hasSession` siempre false. La recuperación es por **Apple ID**, no por cuenta | **NO CUMPLE** (DARK) |
| El sign-in de grupos no toca el container | `GroupsSignInView` autentica y nada más: sin controller, sin adopt, sin `StorageMode` | **CUMPLE** (pero DARK) |

**Brechas.** `E2-04 + NEW-E2-01 + NEW-E2-03` — la fuga de handover, y es la más grave del informe porque es
**ACTIVA**: el store de grupos sobrevive el wipe, el bridge no comprueba identidad (resuelve el grupo por
`cloudKitZoneID` y crea TX virtuales / drafts del Inbox, `SplitSyncManager.swift:1728`,
`GroupTransactionBridge.swift:150`, `GroupService.swift:1178`), y `groupsBetaUnlocked` está excluido del
barrido (`DataWipeService.swift:270`) así que el usuario B entra a Grupos sin el código. Consecuencia: **B ve
gastos de A en Panel, Inbox, presupuestos y reportes**. NO VERIFICADO en device. ·
`E2-05` recuperación atada al Apple ID (`CloudBackendConfig.swift:42`) · `NEW-E2-02` con el flag ON esta
cohorte tampoco alcanza el purgado: `exitYalaOnThisDevice` (`CloudSessionSignOut.swift:117`) solo lo invoca
la 2ª fila del layout, y la fila que esta cohorte ve llama `signOut()` → `privateReset`
(`ProfileView.swift:1101`) · `NEW-E2-04` el copy dice «tus grupos siguen en **tu** iCloud» y los grupos
llegados por invitación viven en la private DB del owner (`Localizable.strings:5188`).

---

### E3 · Usuario nuevo que elige iCloud

**Expectativa del dueño.** (a) Yala Personal funciona sin problemas, con los datos en el container privado
de iCloud, igual que un usuario existente. (b) Apenas entra a Grupos se le exige sign-in con Google o Apple;
Grupos es 100 % nube desde el inicio y no se crea nada de grupos en iCloud.

**Recorrido real.** Splash → Welcome Hero → «Empezar» → chooser de 3 cards → «Soy nuevo» → onboarding de 8
pasos (`OnboardingStepPlan.swift:19-40`) → paso final con grid de privacidad → app. **En ningún paso se le
pregunta dónde viven sus datos**: obtiene iCloud por ausencia de la key `cloudSync.storageMode`. Tab Grupos:
código beta, luego cuenta iCloud, luego `GroupsContainerView` con CTA «crear grupo». Crear → zona CloudKit.

| Punto de la expectativa | Realidad | Veredicto |
|---|---|---|
| (a) Datos en el container privado, igual que un existente | `.iCloudMirror` → `.private(iCloud.com.jurgenschmidt.yala)`, misma rama y mismo archivo (`SwiftDataConfiguration.swift:695-700`) | **CUMPLE** |
| (a) …por elección | No hay pantalla de elección: `visibleNewOptions` sin callsite (`WelcomeAccountChoiceLogic.swift:36`); el onboarding no tiene paso de ubicación | **CUMPLE por defecto, no por elección** |
| (b) Sign-in exigido al entrar a Grupos | Cero referencias a `CloudAuthService` en el árbol del tab; el empty state con CTA de sign-in exige `flagOn` (`GroupsEmptyStateLogic.swift:29`) | **NO CUMPLE — invertido** |
| (b) Grupos 100 % nube, nada en iCloud | `route` devuelve `.cloudKit` siempre → `createZone` (`saveZone` + `GroupMeta`) + `createShare` al invitar. El engine arranca en el boot sin gate | **NO CUMPLE — invertido** |
| (b) …y en su lugar se le exige | Código beta `"1050"` y cuenta iCloud del OS, con copy «Tus grupos se comparten y sincronizan con tu cuenta de iCloud» (`Localizable.strings:4856`) | **CONTRARIO** a la expectativa |
| Invariante (ii): sign-in independiente del container | `CloudAuthService` no referencia `storageMode`/`isICloudAvailable`/`ubiquityIdentityToken`; sesión en Keychain propio | **CUMPLE** (pero DARK) |

**Brechas.** `E3-03`, `E3-04` (críticas, arriba) · `E3-07` sin sonda de ocupación: 7 `CKContainer(` en `Yala/`,
ninguno lo es · `E3N-01` **la zona de un grupo es IRREVERSIBLE en producción**: `deleteGroup` abre con
`#if !DEBUG throw .deleteDisabled` (`GroupService.swift:325-328`) y la UI de «Borrar grupo» llama
`softDelete`, que solo pone `isHiddenForAll = true` · `E3N-02` el testigo
`containerWasCreatedWithCloudKit` se reescribe en **cada** arranque (`YalaApp.swift:81-82`), así que quien
onboardea sin iCloud, lo activa y relanza sube sus datos locales al espejo **sin aviso** ·
`E3N-03` el chip de grupos del progreso de restore cuenta `SplitGroup`, que no viene de ese import
(`RestoreProgressView.swift:110`, `:143`).

---

### E4 · Usuario nuevo que elige nube (backend propio)

**Expectativa del dueño.** (a) Firma con Apple/Google al registrarse, y al entrar a Grupos **no** se le
vuelve a pedir sign-in: se reusa el de la nube. (b) Si más adelante migra sus datos personales a iCloud, su
sign-in de Grupos se mantiene idéntico.

**Recorrido real: no hay recorrido.** El punto de entrada no existe. `visibleNewOptions` tiene 6 hits en
`YalaTests/` y **cero en `Yala/`** (`WelcomeAccountChoiceLogic.swift:36`); `WelcomeFlowStep` no tiene
sub-chooser para «Soy nuevo» y la rama `.new` va directa al onboarding
(`WelcomeFlowContainer.swift:73`), cuyos 8 pasos no incluyen ubicación de datos ni sign-in
(`OnboardingStepPlan.swift:17`). **No es DARK: falta el callsite. Ni un flag lo destapa.**

| Punto de la expectativa | Realidad | Veredicto |
|---|---|---|
| Elegir nube al registrarse | Función pura con tests y cero consumidores | **NO EXISTE** |
| No ocupar el container privado de iCloud | El mount mirror-OFF exige el PAR `.cloud + mirrorOffArmed`; `mirrorOffArmed` solo se escribe **tras exportar el marcador a CloudKit** (`MigrationWorkExecutor.swift:457`, `:475`). Modo nube sin ocupar iCloud solo es representable vía sesión secundaria M1 (DARK) | **NO CUMPLE** |
| (a) Reuso del sign-in en Grupos | Mecánica **correcta**: fuente única `CloudAuthService.shared`, decisión en el productor (`GroupCreateRoutingLogic.swift:28`), belt en la vista que auto-cierra con sesión viva (`GroupsSignInView.swift:112`) | **CONSTRUIDO Y CORRECTO, 100 % DARK** |
| (a) …y sin pasos extra | Con el flag ON y sesión viva pero sin consent de grupos, `route` devuelve `.needsConsent`: `groupsConsentAcceptedAt` es una key distinta de `cloudConsentAcceptedAt` | Divulgación adicional deliberada, no re-sign-in |
| (b) Migrar a iCloud sin perder el sign-in de Grupos | Ninguno de los 6 efectos de la reversa cierra sesión; `MigrationRunner` no menciona grupos; `startIfEligible` no lee `storageMode` | **CUMPLE estructuralmente** |
| (b) …para este usuario | `ReverseEligibility` hace `guard hasCKMap else return .degradedNoMap` y su doc dice que un born-cloud queda **EXCLUIDO en v1** (`MigrationWorkExecutor.swift:89-99`, `:74`) | **NO EXISTE para E4** (diferido declarado) |

**Brechas.** `E4-01` (arriba) · `E4-02` todo camino a `.cloud` pasa antes por iCloud · `E4-06` born-cloud
excluido de la reversa, y la UI colapsa las 3 causas en un texto plano sin salida
(`Localizable.strings:4684`) · `N1` **migrar re-pide sign-in y permite elegir otro proveedor**:
`StorageSettingsView` presenta el chooser sin condición (`:102`) y `startMigration` llama `signIn(with:)` sin
guard de sesión (`CloudMigrationController.swift:249`, `:266`) ⇒ personal en una cuenta y grupos en otra,
contra el copy `groups.signin.accountNote` (`Localizable.strings:4889`) · `N2` `degradedNoMap` puede
bloquear la reversa a un **migrado**, no solo a un born-cloud: `hasCKMap` exige `ckRecordName != nil`, que
solo se escribe en outcome `.captured`, y el único sitio que re-captura está **dentro** de la reversa que
`hasCKMap` bloquea (círculo cerrado, `MigrationWorkExecutor.swift:265`, `:864`, `:97`) · `N3` el sign-in de
Grupos no tiene guard cross-cuenta y esa sesión es la que luego reclamaría el corpus personal
(`GroupsSignInView.swift:7` vs `WelcomeCloudSignInView.swift:424`).

---

### E5 · Usuario nuevo Solo Grupos

**Expectativa del dueño.** (a) Sign-in obligatorio con Google o Apple al elegir Solo Grupos; sus grupos viven
en su cuenta propia. (b) Si más adelante pasa a Yala Completo, elige entonces dónde viven sus datos
personales (iCloud si el container no está ocupado, o nube), reusando la cuenta de grupos.

**Recorrido real.** Onboarding → paso `.purpose` → card «Dividir gastos con amigos», que comprueba
`isAccountAvailable`: **sin cuenta iCloud del OS muestra un alert y la elección no se aplica**
(`OnboardingView.swift:509-517`). Con iCloud: `completeGroupsOnlyOnboarding` escribe prefs, desbloquea el
gate beta y siembra categorías **en el store personal ya montado con mirror `.private`**. Cero sign-in en
todo el flujo (grep de `CloudAuthService` en `OnboardingView.swift` = 0). Pasar a Completo:
`FullModeActivationView` es un wrapper de `OnboardingView` con prefill, sin una sola referencia a ubicación
de datos (`:25`, `:91`).

| Punto de la expectativa | Realidad | Veredicto |
|---|---|---|
| (a) Sign-in Apple/Google obligatorio | No existe paso de sign-in; el tab no exige sesión; `GroupsSignInView` es DARK y solo por acción | **NO CUMPLE — invertido** |
| (a) …lo que se exige en su lugar | **Cuenta iCloud del sistema operativo**, sin alternativa: ser Solo Grupos sin iCloud es imposible | **CONTRARIO** |
| (a) Grupos en su cuenta propia | `route` → `.cloudKit` siempre; zona por grupo en el container **dedicado** de grupos + CKShare al invitar | **NO CUMPLE** |
| Precondición de (b): «solo si el container no está ocupado» | `personalStoreDecision` devuelve `.iCloudMirror` con solo tener cuenta iCloud, **antes de cualquier pantalla**, y el alta siembra ahí ⇒ la precondición es **inalcanzable por construcción** | **NO CUMPLE** |
| (b) Elegir ubicación al pasar a Completo | `FullModeActivationView` no ofrece ninguna elección; al completar solo cambia `onboardingMode`, `usageFocus` y la tab bar | **NO EXISTE** |
| (b) Reusar la cuenta de grupos al migrar | La única superficie está oculta, y además `startMigration` re-lanza el sign-in interactivo sin early-return por `hasSession`, con un chooser que **no preselecciona ni bloquea** el proveedor de la sesión viva | **NO CUMPLE** (DARK) |
| Tras el alta, se comporta como un Solo Grupos normal | Tab bar `[.groups]`, `ShellMode.groupsFocused`, bridge en virtual-pair, Perfil desde el toolbar | **CUMPLE** |

**Brechas.** `E5-04` (crítica, arriba) · `E5-02`, `E5-06`, `E5-07`, `E5-09` (arriba) ·
`E5-N1` **los gastos de grupo de un Solo Grupos se espejan al container privado PERSONAL**: el bridge crea
TX virtuales también en `.groupInvite` (`GroupTransactionBridge.swift:150`, `:212`) y `TransactionItem` es
del `personalSchema`, que se monta `.private` ⇒ importes, fechas y descripciones acaban como
`CD_TransactionItem` en el iCloud personal · `E5-N2` `deleteGroup` deshabilitado en release ·
`E5-N3` **copy ACTIVO que promete la arquitectura vieja como valor**: What's New afirma que todo viaja por
tu iCloud privado, «sin servidores nuestros» (`Localizable.strings:4432`), y ni él ni el gate
(`:4856`) están gateados por `groupsBackendEnabled` — al encender el backend quedan **falsos**, y uno es
promesa de privacidad · `E5-N4` «Tu cuenta de Yala» no ofrece ningún camino para llevar lo personal a la
nube (`YalaAccountLogic.swift:60`).

---

### E6 · Usuario existente en iCloud que migra sus datos personales a la nube

**Expectativa del dueño.** (a) Al migrar, el container privado de iCloud queda **libre** y reutilizable
—por si en el futuro quiere crear ahí una cuenta privada nueva—. (b) Se fuerza sign-in en Grupos: sign-in y
listo, sin limitaciones sobre qué cuenta puede usar.

**Recorrido real.** No hay recorrido: la fila desde la que se migra está oculta y el controller es nil
(`CloudBackendConfig.swift:23`, `:42`; `StorageRowGateLogic.swift:30`; `CloudMigrationController.swift:152`).
Con el backend encendido, el flujo sería: consent de 7 puntos → doble confirmación destructiva → chooser
Apple/Google → auth → progreso por fases → card bloqueante «reinicia Yala» → relanzamiento con mirror OFF.

| Punto de la expectativa | Realidad | Veredicto |
|---|---|---|
| (a) El container privado queda libre | **Cero código de borrado** en todo el repo. La migración solo persiste un flag para apagar el mirror y además **INSERTA** un `CloudMigrationMarker` con el mirror vivo para que se exporte (`MigrationWorkExecutor.swift:457`, `:471`) | **NO CUMPLE — NO EXISTE** |
| (a) …y los grupos dejan de ocupar | `GroupCreateRoutingLogic` no mira `storageMode`: post-migración sigue creando zonas nuevas allí, y el engine de grupos arranca **antes** precisamente porque el mirror personal está OFF (`SplitSyncStartGate.swift:53`) | **NO CUMPLE** |
| (a) Salida para tener un iCloud limpio | Ninguna: la reversa **necesita** la zona (`hasCKMap`), «Vaciar mis datos» en `.cloud` borra filas sin mirror que las exporte, y «Eliminar cuenta» declara que la copia congelada no se toca (`AccountDeletionService.swift:118`) | **NO CUMPLE** |
| (b) Sign-in forzado en Grupos | 2 puertas (beta, iCloud), cero referencias a `CloudAuthService`. Con el flag ON los 3 productores de sign-in son CTA, nunca puerta | **NO CUMPLE** |
| (b) Sin limitaciones de cuenta | `CloudAuthService.shared` es una única sesión process-global y `GroupsSignInView` se auto-cierra con sesión viva ⇒ al migrado se le **impone** la cuenta de sus datos personales; no existe switcher | **NO CUMPLE** |
| Post-migración deja de depender de iCloud | El gate «Grupos necesita iCloud» no lee `storageMode`: un migrado que desactive iCloud pierde el tab Grupos entero | **NO CUMPLE** mientras los grupos vivan en CKShare |
| El sign-in de Grupos sobrevive la reversa | Verificado: ningún efecto de la reversa cierra sesión | **CUMPLE** |

**Brechas.** `E6-01`, `E6-02`, `E6-03`, `E6-05` (arriba) · `E6-09` **ninguna superficie de migración dice que
iCloud sigue ocupado**: revisados los 7 puntos del consent (`Localizable.strings:4713-4719`),
`storage.migrate.*`, `storage.confirm.migrate*`, `storage.status.*`, `revert.desenlaceNote` (`:5332`) y
`yalaAccountDataLocationCloud` (`:5314`) — grep de «cuota | espacio de iCloud» en `es.lproj` = 0 hits. La
única frase honesta vive en el borrado de cuenta (`:5098`) ·
`E6-N1` **tras migrar, cerrar sesión devuelve el device a `.icloud` y el Welcome hace bypass directo a
RESTAURAR la copia congelada obsoleta** (`SwiftDataConfiguration.swift:372`, `:236`;
`WelcomeAccountChoiceLogic.swift:59`; `WelcomeFlowContainer.swift:137`): dos corpus divergentes editables,
sin aviso · `E6-N2` la cuenta de Grupos del migrado no es elegible · `E6-10` se oculta la fila «iCloud» de
Ajustes justo cuando los grupos siguen allí (`ProfileView.swift:898`).

---

## §4 · Escenarios no enumerados que hay que decidir

Cada fila es un estado o transición que el código produce o puede producir y que **ningún escenario del
dueño cubre**. La columna final es la consecuencia concreta si se ignora.

| # | Escenario / estado huérfano | Estado | Evidencia | Consecuencia para el usuario si se ignora |
|---|---|---|---|---|
| 1 | **Handover de dispositivo sin cambiar el Apple ID** (usuario B tras «Cerrar sesión» + «Soy nuevo») | **ACTIVO** | `DataWipeService.swift:280-284`, `:270`; `GroupTransactionBridge.swift:150`; `SplitSyncManager.swift:1728` | B ve los grupos de A y, vía el bridge, **gastos de A en su Panel, Inbox, presupuestos y reportes**. Y entra a Grupos sin el código beta |
| 2 | **Cambio de Apple ID en el mismo dispositivo** | **ACTIVO** | `AppBootstrapper.swift:781-794` (única rama: local→iCloud) | No se detecta: el corpus del Apple ID anterior convive con el container del nuevo. El iKV es per-Apple-ID, así que Hero y `RestoreOfferGate` leen 0 y no notan nada |
| 3 | **Cambio/cierre de Apple ID con grupos ya migrados al backend** | DARK-FLAG | `SplitSyncManager.swift:1425-1439`, `:1460-1485`; `GroupsSyncClient.swift:469-471` | Se borran **todos** los `SplitGroup` locales pero **no** `GroupSyncCursor`: con el high-water intacto el pull incremental no re-entrega el historial ⇒ los grupos migrados desaparecen **de forma permanente** |
| 4 | **iCloud presente pero iCloud Drive desactivado** | **ACTIVO** | `SwiftDataConfiguration.swift:36-38`; entitlements `CloudDocuments` | Store local sin respaldo y **tab Grupos bloqueado entero**, con el container CloudKit perfectamente usable y probablemente ya ocupado. Semántica exacta de plataforma NO VERIFICADA |
| 5 | **Cuota de iCloud llena** | **ACTIVO** (y bloquea el cutover) | `iCloudSyncService.swift:426-436`; `SyncStatusBanner.swift:35`; grep de cuota en `es.lproj` = 0 | La señal más autoritativa que la app recibe se degrada a «Sin conexión o iCloud no está disponible». Y en modo nube deja el cutover en limbo permanente |
| 6 | **Cutover interrumpido / export del marcador imposible** | DARK-CONFIG | `MigrationRunner.swift:582-596`; `MigrationWorkExecutor.swift:425`, `:661-679`; `SwiftDataConfiguration.swift:241-242` | `storageMode` ya en `.cloud` con `mirrorOffArmed=false` ⇒ **mirror ON: doble escritura indefinida**, UI al 89 %, sin tope, sin degradación a fallo y sin escape en producción |
| 7 | **Segundo dispositivo del mismo usuario tras el cutover** | DARK | `MigrationStateMachine.swift:622-646`; `StorageSettingsView.swift:165` | El «auto-bloqueo» no existe: el único consumidor de producto cambia un **copy** en una fila oculta. El 2º device sigue escribiendo al container congelado y deja filas huérfanas |
| 8 | **Reinstalar estando en modo nube** | DARK | `CloudSyncFlags.swift:37`, `:52`; `RestoreOfferGate.swift:26` | `storageMode` vive en `UserDefaults` y el uninstall lo borra ⇒ boot en `.icloud` con mirror ON, y el usuario aterriza en su **copia congelada pre-migración**. El faro sobrevive pero su único lector está en una pantalla DARK |
| 9 | **Restore que no distingue «no hay datos» de «no pude traerlos»** | **ACTIVO** | `RestoreProgressView.swift:150`; `WelcomeRestoreView.swift:55`, `:113`; `OnboardingResetHelper.swift:25` | Un timeout del import se presenta como «No hay datos asociados a tu cuenta»; «Empezar de cero» no borra nada ni confirma ⇒ **doble contabilidad** al llegar el import |
| 10 | **Gasto del invitado durante la migración de su grupo** | DARK-FLAG | `AppBootstrapper.swift:421`; `GroupMigrationUploader.swift:170`, `:181`; `SplitSyncManager.swift:1518` | El uploader se gatea por la quiescencia del import **personal**, no del fetch de grupos; tras el paso 3 el pull descarta todo record de la zona y el seed lee el store local ⇒ **pérdida silenciosa de un gasto** |
| 11 | **Un grupo cuyo owner no abre la app** | DARK-FLAG | `GroupMigrationUploader.swift:123-126` | El corte a backend **no puede completarse nunca**: sin owner activo no hay migración, ni por el invitado ni server-side |
| 12 | **Salud del sync en modo nube** | DARK | `CloudSyncRuntime.swift:494`; `StorageSettingsView.swift:258`; `SyncStatusBanner.swift:91` | Una sesión caducada con cambios pendientes solo se anuncia en la pantalla «Dónde viven tus datos», a 3 taps y con fila oculta. El banner global solo observa `iCloudSyncService` |
| 13 | **Los ~10 gates de «¿es seguro guardar ahora?» en modo nube** | DARK-CONFIG | `SyncQuiescenceCoordinator.swift:6-24`; `iCloudSyncService.swift:94-101`; `SubcategoryDedupGate.swift:41-46`; `NotificationService.swift:531`; `ApplePayDraftService.swift:44` | Con el mirror apagado no existe ningún `importEvent`, así que `isImportQuiescent` devuelve **`true` siempre**: notificaciones canceladas contra un grafo a medio aplicar, drafts materializados sobre datos incompletos, dedup colapsando entidades sin su pareja |
| 14 | **El estado `.localNoMirror` no es sin-mirror** | **ACTIVO** | `SwiftDataConfiguration.swift:701-702`, `:663-670`, `:687-689` | La rama «local» es la **única** que no declara su modo de CloudKit y hereda `.automatic`, que el propio fichero llama peligroso porque adjunta `NSPersistentCloudKitContainer`. Es la causa mecánica del upload silencioso del §3/E3N-02 |
| 15 | **La suscripción Pro no viaja con la cuenta de nube** | mecanismo ACTIVO, consecuencia DARK | `StoreKitManager.swift:243`; `FeatureGateService.swift:126-130`; cero `appAccountToken` | Quien migra a la nube para dejar de depender de Apple y entra con su cuenta Yala en un device con otro Apple ID **ve sus datos y pierde Pro sobre ellos**, con el límite de creación aplicado a un corpus que ya lo excede |
| 16 | **El consent GDPR de Grupos nunca llega al backend en estado mixto** | DARK | `GroupsConsentState.swift:35-45`; `PreferenceSyncService.swift:96-100` | En `.icloud` el registro va al iKV del Apple ID, no a la cuenta. Al backend solo lo lleva el drenaje del cutover, que un usuario mixto nunca ejecuta — y ese flag device-level es el que decide saltarse el consent |
| 17 | **Pérdida de respaldo sin aviso** | **ACTIVO** | `iCloudSyncService.swift:56`, `:247`; `SyncStatusBanner.swift:40-43`; `AppBootstrapper.swift:785-791`; `iCloudSyncSettingsView.swift:29`, `:214-218` | `.noAccount` nunca llega al banner (`needsAttention` solo cubre failed/stalled); el aviso de mismatch se **consume aunque no se muestre** si llega durante el onboarding; y los CTAs de recuperación son código muerto (`isAutoRecoveryAvailable` es un `let false` y «Revisar y reparar» tiene el cuerpo vacío) |

---

## §5 · Las dos invariantes del dueño, y la meta

### Invariante (i) — «Siempre se identifica si el container privado de iCloud está en uso o libre»

**INCUMPLIDA.** No es un flag apagado: la consulta no existe, y la señal que sí existe mide otra cosa.

1. **Barrido exhaustivo.** Grep sobre `Yala/` de
   `privateCloudDatabase|allRecordZones|CKFetchRecordZonesOperation|CKModifyRecordZonesOperation|deleteRecordZone|records(matching|accountStatus|CKContainer(`
   → 14 hits, de los cuales **13 son del container de GRUPOS** (`SplitZoneManager.swift:239-257`,
   `SplitSyncManager.swift:259-346`, `GroupService.swift:239`, `InviteLinkService.swift:245`,
   `GroupUserIdentityService.swift:32`). El único del dominio personal es
   `iCloudSyncService.swift:531-532`, un **ping para despertar el motor** cuyo resultado se descarta con `_ =`.
   `accountStatus` = **0 hits**. `CKAccountChanged` = **0 hits**.
2. **La señal elegida es la equivocada.** La única función que responde «¿hay iCloud?» es
   `isICloudAvailable() = FileManager.default.ubiquityIdentityToken != nil`
   (`SwiftDataConfiguration.swift:36-38`) — la identidad de **iCloud Drive / Documents**, no el estado de la
   cuenta CloudKit; el entitlement declara `CloudDocuments` y `ubiquity-container-identifiers` además de
   CloudKit. Ese booleano gobierna el mount del mirror, el gate duro de Grupos, la card «Solo grupos» del
   onboarding, el Hero y el restore.
3. **Las 6 señales sustitutas, y por qué ninguna es autoritativa.**

| Señal | Qué mide | Estado | Falla cuando |
|---|---|---|---|
| `ICloudAccountSummary.hasAnyData` (`iCloudSyncService.swift:669-672`, `:684-717`) | conteos del store **LOCAL** tras esperar quiescencia | ACTIVO | import lento o timeout ⇒ «no hay datos»; el `settled` se descarta (`RestoreProgressView.swift:150`) |
| `RestoreOfferGate.hasReturningSignal` (`RestoreOfferGate.swift:26-28`) | timestamps del **iCloud KV** | ACTIVO | otro Apple ID: 0/0 ⇒ «fresh real» aunque el container esté lleno |
| `markerDecision()` (`CloudMigrationController.swift:574-578`) | presencia del `CloudMigrationMarker` importado | **DARK** | controller nil |
| `hasCKMap` (`CloudMigrationController.swift:562-563`) | ≥1 `SyncIdentity` con `ckRecordName != nil` | **DARK** | solo post-migración; se pierde al reinstalar |
| `containerWasCreatedWithCloudKit` (`SwiftDataConfiguration.swift:651-659`) | testigo local | ACTIVO pero **autoanulado**: se reescribe en cada arranque (`YalaApp.swift:81`) | siempre, entre sesiones |
| `hasLocalData` del guard cross-cuenta (`ContentView.swift:875-885`) | conteos locales con `try?` + `?? 0` | ACTIVO | **falla ABIERTO** si el fetch lanza |

4. **El detector ya existe, está device-validado, y no está cableado.** `CKIdentityCapture` abre el store
   personal en SQLite **READ-ONLY** y lee la side-table `ANSCKRECORDMETADATA`, con veredicto tri-estado por
   fila (`captured` / `exportPending` / `noMetadata` / `failed`, `CKIdentityCapture.swift:43-51`); y
   `scanOrphanMetadata` cuenta records que **viven en el container sin fila local viva** (`:249-266`) —
   literalmente «el container está ocupado por cosas que yo no tengo». Sin red, sin cuenta, promovido a
   producción tras el spike S5. Sus call-sites de producto son **solo** el interior de
   `MigrationWorkExecutor` (`:265`, `:678`, `:866`, `:879`) más el panel DEV. **La invariante falla por
   cableado, no por capacidad.**
5. **11 sitios que deberían consultarla y no lo hacen**, encabezados por el mount del store personal
   (`SwiftDataConfiguration.swift:236-243` — la decisión más irreversible de la app, tomada con la señal más
   pobre), «Soy nuevo» (`WelcomeFlowContainer.swift:75-81`), `onStartFresh`
   (`WelcomeRestoreView.swift:113`), `FullModeActivationView.swift:26-32`, la creación de zona de grupo
   (`SplitZoneManager.swift:26-53`, donde **el eje D del container de grupos no tiene ni señales-proxy**) y
   la etiqueta ☁️ de las hojas destructivas (`DestructiveScopeLogic.swift:95-98`).

### Invariante (ii) — «El sign-in de Apple/Google es 100 % independiente del container privado»

**CUMPLIDA en la autenticación. INCUMPLIDA en el perímetro.**

Lo que cumple, verificado con greps de exit 1: `CloudAuthService` no referencia `storageMode`,
`isICloudAvailable`, `ubiquityIdentityToken`, `isAccountAvailable` ni `CKContainer`; el `AuthClient` se
construye solo desde `CloudBackendConfig` (`CloudAuthService.swift:161-183`); la credencial vive en Keychain
propio con `AfterFirstUnlockThisDeviceOnly`, así que **jamás viaja al Keychain de iCloud**
(`CloudAuthKeychainStorage.swift:43`); el provider no queda fijado (`CloudAuthService.swift:446`);
`GroupsSignInView` lo declara por escrito (`:5-8`); y el código **ya modela A⊥B en el cierre**: la fila
`.groupsOnlySignOut` es exactamente (A=`.icloud`, B presente, C=backend) (`CloudSignOutFlowLogic.swift:32-37`).

Los acoples del perímetro, por dirección:

| Dirección | Acople | Estado | Evidencia |
|---|---|---|---|
| D → C | El tab Grupos exige cuenta iCloud del OS; su retiro está cableado **solo** al flag de backend, no a la presencia de sesión propia | **ACTIVO** | `GroupsICloudAvailabilityGateLogic.swift:31-32`; `ContentView.swift:1960` |
| D → C | **La identidad del miembro de grupo ES el Apple ID**: el UUID del `SplitMember` se deriva del `userRecordID()` de iCloud | **ACTIVO** | `GroupUserIdentityService.swift:26-32`; `GroupService.swift:85`, `:112` |
| B → D | La única defensa cross-device de coherencia de cuenta (`CloudBeacon`) vive **dentro del iCloud del Apple ID** y es fail-open: sin faro `ProviderMismatchLogic` devuelve `.proceed` | DARK | `CloudBeacon.swift:45-60`; `ProviderMismatchLogic.swift:45-58` |
| A → B | `CrossAccountEntryGuardLogic` bloquea el sign-in ajeno si hay corpus local — guard deliberado, pero **falla abierto** | DARK | `CrossAccountEntryGuardLogic.swift:50-58`; `ContentView.swift:882-884` |
| B → A | `.cloudSecureSignOut` arma el borrado de **archivos** del store personal en el boot: cerrar sesión de una identidad borra el corpus local (intencional, y el acople más fuerte del conjunto) | DARK | `CloudSignOutFlowLogic.swift:25-27`; `SwiftDataConfiguration.swift:342-459` |
| B → D | El registro de consent de Grupos (que es de la CUENTA) se guarda en el iKV **per-Apple-ID** cuando el modo es `.icloud` | DARK | `GroupsConsentState.swift:31-70`; `PreferenceSyncService.swift:96-100` |

**No es violación** que migrar a un backend propio exija cuenta en ese backend: es la definición del
destino. Y **no encontré** ningún camino de sign-in que consulte `isAccountAvailable`, ni ninguna migración
que fuerce un provider concreto — el defecto ahí es el inverso (§3/E4, `N1`).

### Meta — «No seguir generando container de grupos en iCloud»

**INCUMPLIDA, y con 7 caminos abiertos.** Raíz común: `route` abre con `guard flagOn else { return .cloudKit }`
(`GroupCreateRoutingLogic.swift:29`) y el flag es `false` compilado sin ningún `#if`.

| # | Camino | Cadena | Estado |
|---|---|---|---|
| M1 | Crear grupo | `GroupFormView.swift:272-283` → `GroupService.swift:101` → `SplitZoneManager.createZone` (`saveZone` + `GroupMeta`) | **ACTIVO** |
| M2 | Invitar (CKShare nuevo) | `GroupMembersView.swift:449-462` → `SplitZoneManager.createShare` (`:190`). El `else` se toma **también con el flag ON** si el grupo no es backend | **ACTIVO** |
| M2' | Invitar sobre un grupo YA migrado tras reinstalar | `createShare` solo guardea `!isBackendGroup`, testigo **LOCAL-only** que se pierde al reinstalar; `movedToBackendAt` (que sí viaja) no se consulta, y `GroupFreezeLogic.swift:51` declara al owner NO congelado en esa ventana ⇒ **mintea un CKShare nuevo sobre la zona congelada** | DARK-FLAG |
| M3 | **Zone recovery del boot** | `SplitSyncManager.initialize()` (`AppBootstrapper.swift:308`, sin gate por flag ni por `storageMode`) → `recoverOwnedGroupZonesIfNeeded` (`:397-434`) → `createZone` en `:428`. **Sin ninguna acción del usuario** | **ACTIVO** |
| M4 | Todo write de grupo | `enqueueSave` / `enqueueSharedSave` / `markPendingChange` (`SplitSyncManager.swift:1108-1141`) | **ACTIVO** |
| M5 | Aceptar un CKShare legacy | `acceptShare` (`:701-731`), sin guard de flag ni de sesión. El invitado escribe en el container del owner | **ACTIVO** |
| M6 | Propagar `isArchived` / `isHiddenForAll` | `GroupService.propagateBoolCustomKey` (`:236-249`) | **ACTIVO** |
| M7 | Marcador de migración sobre un grupo migrado | `enqueueMigrationMarker` (`SplitSyncManager.swift:1115-1125`) — deliberadamente sin guard, y necesario por diseño | DARK-FLAG |

**Liberación: inexistente.** Cero `deleteRecordZone` / `CKModifyRecordZones` / `purgeCloudKit` en el repo.
Los 3 call-sites de `deleteZone` son: `GroupSettingsView.swift:661` (manual, owner-only, exige
`movedToBackendAt != nil`, es decir post-migración), `GroupService.swift:335` (dentro del `#else` de
`#if !DEBUG throw .deleteDisabled` ⇒ **DEBUG-only**) y el recovery, que la **crea**. El propio código lo
admite: «la zona CloudKit quedó viva» (`GroupFreezeLogic.swift:30`). En producción **borrar un grupo no
libera nada**: solo hay `softDelete`, que pone `isHiddenForAll = true`.

**Deuda no enumerada: el container PERSONAL también tiene datos de grupos.** El propio código documenta que
sin `cloudKitDatabase: .none` el store de grupos se adjunta al container **primario** y crea record types
`CD_Split*` allí, con doble cuota (`SwiftDataConfiguration.swift:729-737`), y `CKIdentityCapture.swift:15-16`
registra como hallazgo **verificado en device** que hay zonas `SplitGroup-*` residuales en las side-tables
del store personal. Nada las detecta y nada las borra. Estado server-side **NO VERIFICADO**.

---

## §6 · Informe de diferencias entre escenarios

Una fila por decisión de producto. `E1` Completo existente · `E2` Solo Grupos existente · `E3` Nuevo iCloud ·
`E4` Nuevo nube · `E5` Nuevo Solo Grupos · `E6` Migrador.

| Decisión de producto | E1 | E2 | E3 | E4 | E5 | E6 |
|---|---|---|---|---|---|---|
| **¿Se exige sign-in de cuenta propia?** | No | No | No | — (escenario inalcanzable) | No | No |
| **¿Qué se exige en su lugar para Grupos?** | Código beta `"1050"` + cuenta iCloud del OS | Ya desbloqueado + cuenta iCloud | Código beta + cuenta iCloud | — | **Cuenta iCloud como requisito del alta** (sin ella la elección no se aplica) | Código beta + cuenta iCloud, **también post-migración** |
| **¿Elige dónde viven sus datos personales?** | No (la fila está oculta) | No | No (lo obtiene por ausencia de key) | **La pantalla no existe** | No, ni al alta ni al pasar a Completo | Sí en el diseño, **inalcanzable** en producción |
| **Dónde viven los datos personales (real)** | iCloud privado (mirror `.private`) | iCloud privado (aunque «no tenga datos personales») | iCloud privado | iCloud privado por fuerza: `.cloud` exige pasar antes por él | iCloud privado desde el primer boot | iCloud privado; `.cloud` es DARK |
| **Dónde viven los grupos (real)** | CloudKit (zona + CKShare) | CloudKit | CloudKit | CloudKit (el routing no mira `storageMode`) | CloudKit | CloudKit, **incluso después de migrar** |
| **¿Ocupa el container privado personal?** | Sí | **Sí** (categorías del alta + gastos de grupo vía bridge) | Sí | Sí | **Sí**, y además los importes de sus gastos de grupo | Sí, y **nunca se libera** |
| **¿Ocupa el container de grupos?** | Sí, +1 zona por grupo | Sí | Sí | Sí | Sí | Sí, y sigue creciendo tras migrar |
| **¿Se detecta si el container está ocupado?** | No | No | No | No | No | No |
| **Qué hace «Cerrar sesión» / «Salir de Yala»** | `.privateReset`: 3 flags, **cero datos borrados** → Welcome en sesión | `.privateReset`: **los grupos del saliente siguen visibles** | `.privateReset` | — | `.privateReset` | `.privateReset` hoy; con `.cloud` sería `.cloudSecureSignOut` (borra archivos del store personal en el boot) y devolvería el device a `.icloud` **restaurando la copia obsoleta** |
| **Qué hace «Vaciar datos»** | 12 entidades del store personal; **ninguna** `Split*`; emite `lastWipeTimestamp` | Igual (`wipeDataGroupsOnly`), los grupos intactos | Igual | — | Igual | Igual, pero en `.cloud` **sin mirror que exporte los deletes** |
| **Camino a Yala Completo** | n/a | Existe (5 CTAs) pero **sin elección de ubicación** | n/a | n/a | `FullModeActivationView` = wrapper de onboarding con prefill; solo cambia modo, focus y tab bar | n/a |
| **Camino a modo nube** | Oculto (fila + controller nil) | Oculto (y la fila **no** está gateada por `isGroupInviteMode`: al encender el backend la vería) | Oculto | **No existe** | Oculto, y además re-lanza el sign-in interactivo | Oculto |
| **Camino de vuelta a iCloud** | n/a | n/a | n/a | **Excluido en v1** (`degradedNoMap`) | n/a | Existe y está completo, pero DARK; y `degradedNoMap` puede excluir también a un migrado |
| **Qué ve de nuevo tras actualizar** | Nada de la épica; solo las hojas de alcance destructivo | **Nada**: What's New se salta para group-invite | n/a | n/a | n/a | Nada |

---

## §7 · Registro de brechas priorizado

Solo hallazgos que **sobrevivieron** a la refutación. Los IDs agrupados en una fila son el mismo defecto
visto desde varios escenarios. Los refutados están en el Apéndice A.

### Críticas

| ID(s) | Título | Escenarios | Refutación | Evidencia | Qué habría que decidir o cambiar |
|---|---|---|---|---|---|
| E6-01 | **El container privado de iCloud nunca se libera; el código para hacerlo no existe** | E1, E2, E5, **E6** | CONFIRMADO (grep repetido sobre todo el repo: 0 hits) | `MigrationWorkExecutor.swift:457`, `:471`; `SwiftDataConfiguration.swift:236`, `:300` | Implementar la operación que el vault ya diseñó con nombre propio (§m.3.1) o retirar la promesa de «iCloud queda libre» del épico |
| E3-04 · E2-01 · E5-01 · E4-03 · E6-02 · E7-11 · META | **Grupos crea y engorda el container de iCloud por 7 caminos, 5 ACTIVOS, uno sin acción del usuario; ninguna zona se libera** | todos | CONFIRMADO (los refutadores corrigen que la zona nace en el container **dedicado** de grupos, no en el personal, y que `deleteZone` existe con 2 call-sites, ambos inalcanzables en release) | `GroupCreateRoutingLogic.swift:29`; `GroupService.swift:101`; `SplitZoneManager.swift:44`, `:190`; `SplitSyncManager.swift:397-434`, `:701-731` | Decidir el orden del corte: ninguna de las 3 cosas (dejar de crear, migrar lo existente, liberar) funciona sin las otras dos |
| E3-03 · E1-09 · E2-02 · E5-02 · E5-10 · E6-05 | **Entrar a Grupos NO exige sign-in, y con el flag ON tampoco habría puerta** | todos | CONFIRMADO. Refutado el matiz «ni con el flag ON»: con flag ON el sign-in **sí** es obligatorio para crear y para el invite backend | `ContentView.swift:1952-1971`; `GroupsEmptyStateLogic.swift:29`; `GroupCreateRoutingLogic.swift:28` | Construir el gate de **entrada** al tab (hoy no existe) y decidir qué pasa con los grupos CloudKit visibles de un usuario sin sesión |
| E1-10 · E2-03 | **La migración de grupos está DARK y, encendida, no puede cubrir el 100 %** | E1, E2, E6 | CONFIRMADO. El refutador añade un segundo excluyente: el predicado exige también `ckSystemFieldsData != nil` | `CloudSyncFlags.swift:239`, `:233`; `GroupMigrationUploader.swift:97`, `:123-126` | Decidir el camino del invitado o el server-side. Sin uno de los dos el corte de CloudKit es imposible por construcción |
| E5-04 | **El container privado queda ocupado desde el primer boot, sin mirar la forma de uso** | E5 (y E2, E3) | CONFIRMADO. Refuerzo del refutador: el restore del producto **depende** de que esas filas estén en iCloud | `SwiftDataConfiguration.swift:236`, `:695`; `YalaApp.swift:82`; `OnboardingView.swift:1818` | La precondición «ofrecer iCloud solo si el container está libre» es inalcanzable mientras el mount preceda a toda pantalla. Decidir si el mount se retrasa o si la precondición se abandona |

### Altas

| ID(s) | Título | Escenarios | Refutación | Evidencia | Qué habría que decidir o cambiar |
|---|---|---|---|---|---|
| E2-04 · NEW-E2-01 · NEW-E2-03 | **Handover de dispositivo: los grupos y los gastos del usuario anterior llegan al store personal del nuevo** — el único riesgo ACTIVO de esta tanda | E2 | E2-04 PARCIAL (el aislamiento sí existe por cambio de Apple ID); NEW-E2-01 y NEW-E2-03 nuevos del verificador | `DataWipeService.swift:280-284`, `:270`; `GroupTransactionBridge.swift:150`; `SplitSyncManager.swift:1728`; `GroupsBetaGateLogic.swift:34` | Decidir si el wipe de «Soy nuevo» debe incluir el dominio Grupos (hoy excluido **con test que lo pinnea**), o si el bridge debe comprobar identidad |
| E1-11 · E2-06 · E3-07 · E5-05 · E6-07 · E7-04 · INV-01 · INV-05 | **No existe detección de ocupación del container; la señal única mide iCloud Drive; el detector existe y no está cableado** | todos | CONFIRMADO como ausencia; los refutadores acotan que sí hay respuestas *operativas* (restore por import-then-count, `hasCKMap`) pero ninguna autoritativa | `iCloudSyncService.swift:531`; `SwiftDataConfiguration.swift:36-38`; `CKIdentityCapture.swift:43-51`, `:249-266`; `MigrationWorkExecutor.swift:265` | Cablear `CKIdentityCapture` fuera de la migración (boot, Welcome, restore, hojas destructivas) y sustituir `ubiquityIdentityToken` por `accountStatus` + observación de `CKAccountChanged` |
| E4-01 · E1-07 · E5-06 · E3-02 · E6-N3 | **No existe ninguna elección de ubicación de datos: `visibleNewOptions` es código muerto y no hay puerta a nube tras el sign-out** | E1, E3, E4, E5 | CONFIRMADO: 6 hits en tests, 0 en `Yala/`; `bornCloudEnabled` no aparece en ningún fichero de `Yala/` | `WelcomeAccountChoiceLogic.swift:36`, `:11`, `:60`; `WelcomeFlowContainer.swift:73`, `:137`; `FullModeActivationView.swift:25` | Decidir si born-cloud entra en v1. Hoy no es «flag apagado», es una función sin consumidor con tests verdes |
| E1-01 · E5-07 | **La sección «Dónde viven tus datos» no existe en producción** | E1, E5, E6 | CONFIRMADO (2 entry points, ambos gateados) | `StorageRowGateLogic.swift:30`; `ProfileView.swift:915`; `CloudBackendConfig.swift:23`, `:42` | Es el gate maestro: nada de la épica se puede probar con usuarios reales hasta que exista el proyecto Supabase de producción |
| E1-02 | **Migrar a nube es inalcanzable: el controller nunca se instancia** | E1, E5, E6 | PARCIAL: cae la unicidad (hay **dos** writes de `.cloud`, `:425` y `:1126`), no la conclusión | `CloudMigrationController.swift:152`; `AppBootstrapper.swift:282`; `MigrationWorkExecutor.swift:425` | — (consecuencia del anterior) |
| E2-05 | **Volver a entrar con el usuario de nube no existe: la recuperación está atada al Apple ID** | E2 | CONFIRMADO, sin refutación posible | `CloudBackendConfig.swift:42`; `CloudAuthService.swift:204`; `WelcomeAccountChoiceLogic.swift:52` | — |
| E6-03 | **No existe ninguna salida para el usuario que quiera un iCloud limpio** | E6 | CONFIRMADO, bajado a alta: el mecanismo sí existe y está ACTIVO en `.icloud` (el wipe propaga deletes por el mirror) | `MigrationWorkExecutor.swift:89`; `DataWipeService.swift:44`; `AccountDeletionService.swift:118`; `GroupSettingsView.swift:658` | Decidir si «liberar iCloud» es una acción de usuario propia o un efecto del borrado de cuenta |
| E7-07 · CRIT-N3 | **El cutover puede quedar atascado para siempre en modo nube con el mirror encendido** | E6, E4 | CONFIRMADO. `CRIT-N3` añade que es **determinista** (iCloud lleno o sin cuenta), no solo por interrupción | `MigrationRunner.swift:582-596`; `MigrationWorkExecutor.swift:425`, `:661-679`; `iCloudSyncService.swift:426-436`; `SwiftDataConfiguration.swift:241-242` | Poner precondición de iCloud en la ENTRADA del cutover, y tope + degradación a `failedRollback` en el paso 4 |
| E7-09 | **Reinstalar estando en modo nube devuelve al usuario a su copia congelada de iCloud** | E6 | CONFIRMADO: el único lector del faro es una rama de una pantalla DARK | `CloudSyncFlags.swift:37`, `:52`; `WelcomeCloudSignInView.swift:403`; `RestoreOfferGate.swift:26` | Cablear el faro (que sobrevive al uninstall) al boot o al Hero |
| E6-N1 | **Tras migrar, cerrar sesión devuelve el device a `.icloud` y el Welcome hace bypass directo a restaurar la copia obsoleta** | E6 | Nuevo del verificador. El residual declarado por el owner era otro | `SwiftDataConfiguration.swift:372`, `:236`; `WelcomeAccountChoiceLogic.swift:59`; `WelcomeFlowContainer.swift:137` | Dos corpus divergentes editables sin aviso: decidir si el sign-out `.cloud` debe dejar el device en un estado que no ofrezca restore |
| E7-08 | **El «auto-bloqueo» del 2º dispositivo no existe: solo cambia un copy en pantalla oculta** | E6 | CONFIRMADO: único consumidor de producto = un ternario de copy | `MigrationStateMachine.swift:622`; `StorageSettingsView.swift:165`; `StorageRowGateLogic.swift:30` | Convertir `markerReconciliation` en gate de boot, o aceptar y documentar las filas huérfanas |
| E7-10 | **Un gasto del invitado puede perderse en silencio durante la migración del grupo** | E2, E6 | CONFIRMADO: encadenado completo verificado | `AppBootstrapper.swift:421`; `GroupMigrationUploader.swift:170`, `:181`; `SplitSyncManager.swift:1518` | Gatear el uploader por la quiescencia del **fetch de grupos**, no del import personal |
| E7-05 | **El restore no distingue «no hay datos» de «no pude traerlos», y «Empezar de cero» no borra ni confirma** | E1, E3 | CONFIRMADO; el refutador estrecha la ventana (`hasAnyData` es un OR de 3 conteos) | `RestoreProgressView.swift:150`; `WelcomeRestoreView.swift:55`, `:113`; `OnboardingResetHelper.swift:25` | Propagar el `settled` a un estado `.error` distinto de `.notFound`, y exigir borrado explícito antes de sembrar |
| E7-03 | **Un cambio de Apple ID en el mismo dispositivo no se detecta** | E1..E6 | CONFIRMADO; corrección: el flag **no** se auto-desarma a la primera | `AppBootstrapper.swift:781`, `:774`, `:740` | Añadir la rama «otro Apple ID» (el eje B ya tiene la protección análoga) |
| E7-02 · N3 · E1-N2 | **La puerta de sign-in de Grupos renuncia al guard cross-cuenta y el bridge es ciego a la identidad** | E1, E2, E4, E7 | CONFIRMADO textualmente (la cabecera lo declara; el bridge no tiene ni una referencia a `CloudAuthService`) | `GroupsSignInView.swift:7`; `GroupTransactionBridge.swift:150`; `CrossAccountEntryGuardLogic.swift:53` | Si esa puerta se convierte en el gate obligatorio de Grupos, necesita al menos las protecciones del sign-in personal |
| E7-12 | **En modo nube no hay ninguna señal proactiva de salud del sync** | E4, E6 | CONFIRMADO: único consumidor a 3 taps y en fila oculta | `CloudSyncRuntime.swift:494`; `StorageSettingsView.swift:258`; `SyncStatusBanner.swift:91` | El banner global solo observa `iCloudSyncService`: hay que darle una segunda fuente |
| CRIT-N1 | **En modo nube toda la familia de gates de quiescencia queda inerte (10 ficheros que nadie citó)** | E4, E6 | Nuevo del crítico | `SyncQuiescenceCoordinator.swift:6-24`; `iCloudSyncService.swift:94-101`; `SubcategoryDedupGate.swift:41-46`; `NotificationService.swift:531`; `ApplePayDraftService.swift:44` | Enumerar los consumidores y migrarlos al coordinador **antes** de encender `.cloud`. Hoy la lista no existe en ningún sitio |
| CRIT-N2 | **Un cambio/cierre de Apple ID borra los grupos BACKEND y el cursor sobrevive: no vuelven** | E2, E6 | Nuevo del crítico. La asimetría con `purgeGroupsSyncState` es el defecto | `SplitSyncManager.swift:1425-1439`, `:1460-1485`, `:2059-2088`; `CloudSessionSignOut.swift:595-596` | Gatear el handler reactivo por canal, o borrar cursor y outbox junto con las filas |
| E5-N1 | **Los gastos de grupo de un Solo Grupos se espejan al container privado PERSONAL** | E2, E5 | Nuevo del verificador | `GroupTransactionBridge.swift:150`, `:212`; `SwiftDataConfiguration.swift:101`, `:699` | Un «Solo Grupos» no es un usuario sin datos personales en iCloud: decidir si eso es aceptable o si el bridge debe cambiar |
| E5-N3 | **Copy ACTIVO que promete la arquitectura vieja como valor de producto** («sin servidores nuestros») | E5, todos | Nuevo del verificador | `Localizable.strings:4432`, `:4856`; `ContentView.swift:1968` | Ninguna de esas superficies está gateada por `groupsBackendEnabled`: al encender el backend quedan falsas, y una es promesa de privacidad |
| E3N-01 | **En producción la zona CloudKit de un grupo es IRREVERSIBLE: ninguna acción de usuario libera el container** | E3, E5 | Nuevo del verificador | `GroupService.swift:325-328`, `:258-284`; `GroupSettingsView.swift:579`, `:675-687` | `deleteGroup` está deshabilitado en release y solo hay `softDelete`. Decidir si se rehabilita o si la zona se libera por otra vía |
| E1-N1 | **El freeze del grupo migrado viaja por CloudKit pero su recuperación depende de flags locales** | E1, E2 | Nuevo del verificador | `SplitGroup.swift:54-61`; `GroupFreezeLogic.swift:43-50`; `GroupsContainerView.swift:369-379`; `CloudAuthService.swift:265` | Un miembro en un build con el flag OFF queda congelado sin salida: el marcador no debe viajar antes que la capacidad de re-entrar |
| E5-09 · N1 | **Nada impide firmar la migración personal con una cuenta distinta a la de grupos** | E4, E5, E6 | CONFIRMADO: chooser de selección pura, sin preselección ni bloqueo; la ruta no pasa por `ProviderMismatchLogic` ni por el guard cross-cuenta | `StorageSignInChooserView.swift:21`; `CloudMigrationController.swift:249`, `:266`; `Localizable.strings:4889` | Personal en una cuenta y grupos en otra, contra el copy que promete lo contrario. Preseleccionar o bloquear el proveedor de la sesión viva |

### Medias

| ID(s) | Título | Escenarios | Refutación | Evidencia | Qué decidir |
|---|---|---|---|---|---|
| E6-09 · E1-14 · E4-08 | Ninguna superficie de migración informa de que iCloud sigue ocupado (0 hits de «cuota» en `es.lproj`) | E1, E4, E6 | CONFIRMADO y reforzado con 3 superficies más | `Localizable.strings:4713-4719`, `:5314`, `:5332`, `:5098`; `MigrationWorkExecutor.swift:457` | Nombrar la cuota en el consent, o aceptar que el usuario nunca lo sepa |
| E7-06 | «iCloud lleno» nunca se nombra y el copy mostrado es falso («sin conexión») | E1..E6 | PARCIAL: caen los CTAs citados (no se renderizan) y el estado (`.failed`, no `.stalled`); sobrevive el copy falso | `iCloudSyncService.swift:432`; `Localizable.strings:2649` | Es la señal más autoritativa del eje D y se tira |
| E4-02 | Todo camino a modo nube exige ocupar antes el container privado | E4 | PARCIAL: caen 3 sub-afirmaciones (sí existe `deleteZone`; `.secondaryCloudSession` monta sin mirror; la reversa borra el marcador) | `SwiftDataConfiguration.swift:241-242`; `MigrationWorkExecutor.swift:457`, `:1126` | — |
| E4-06 · N2 | Born-cloud excluido de la reversa, y `degradedNoMap` puede excluir también a un **migrado** (círculo cerrado) | E4, E6 | E4-06 PARCIAL (el excluido no puede existir); N2 nuevo del verificador | `MigrationWorkExecutor.swift:97`, `:74`, `:265`, `:864` | Un migrado en ventana sin export queda inelegible **permanente**: romper el círculo |
| E1-N4 | El guard cross-cuenta falla ABIERTO si el fetch de datos locales lanza (`try?` + `?? 0`) | E1 | Nuevo del verificador. Viola además la regla «NUNCA `try?` que silencia» | `ContentView.swift:875-885`; `CrossAccountEntryGuardLogic.swift:53` | Fail-closed |
| E3N-02 · CRIT-N4 | `.localNoMirror` monta `.automatic` (con `NSPersistentCloudKitContainer` adjunto) y el testigo se reescribe en cada arranque ⇒ **upload silencioso** al activar iCloud | E3, E7 | E3N-02 nuevo del verificador; CRIT-N4 aísla la causa mecánica y cita que el vault admite que nadie verificó `.automatic` sin cuenta | `SwiftDataConfiguration.swift:701-702`, `:663-670`, `:651-659`; `YalaApp.swift:81-82` | Declarar `cloudKitDatabase: .none` en la rama local, o aceptar el mirror y avisar |
| CRIT-N5 | La suscripción Pro sigue atada al Apple ID de App Store: la cuenta de nube lleva los datos, no el derecho a verlos | E4, E6 | Nuevo del crítico (0 `appAccountToken` en el repo) | `StoreKitManager.swift:243`; `FeatureGateService.swift:126-130`; `DataWipeService.swift:271-273` | Decidir si el entitlement viaja con la identidad propia o si el producto lo declara |
| INV-02 | El guard que impide mintear zonas/CKShare de un grupo migrado usa un testigo LOCAL-only que se pierde al reinstalar | E2, E6 | Nuevo del crítico | `SplitZoneManager.swift:28-31`, `:145-148`; `SplitGroup.swift:52`; `GroupFreezeLogic.swift:51` | Guardear por `movedToBackendAt` (que viaja), no por `isBackendGroup` |
| INV-03 | El boot crea zonas de grupos **sin acción del usuario**, sin gate por flag ni por `storageMode` | todos | Nuevo del crítico | `AppBootstrapper.swift:308`; `SplitSyncManager.swift:397-434`, `:428` | Cualquier plan de corte tiene que gatear este camino primero |
| INV-04 | El container personal también está ocupado por residuos de grupos (`CD_Split*`, zonas `SplitGroup-*`), y nada lo detecta ni lo borra | E6 | Nuevo del crítico; el propio código lo documenta como hallazgo device | `SwiftDataConfiguration.swift:729-737`; `CKIdentityCapture.swift:15-16` | Liberar el container implica conocer y borrar también esto. Estado server-side NO VERIFICADO |
| E7-N1 | El estado `.noAccount` nunca llega al banner global: se pierde el respaldo en silencio | E1..E6 | Nuevo del verificador. **ACTIVO** | `iCloudSyncService.swift:56`, `:247`; `SyncStatusBanner.swift:40-43`; `ProfileView.swift:900-909` | — |
| E7-N2 | En estado mixto el consent GDPR de Grupos nunca llega al backend | E7 | Nuevo del verificador | `GroupsConsentState.swift:35-45`; `PreferenceSyncService.swift:96-100`; `GroupBackendInviteEntryLogic.swift:38` | Un registro de la CUENTA guardado per-Apple-ID, y ese flag device-level decide saltarse el consent |
| NEW-E2-02 | Aun con el flag ON la cohorte solo-grupos legada nunca alcanza el purgado: las dos filas de salida llaman a funciones distintas | E2 | Nuevo del verificador | `CloudSessionSignOut.swift:117`; `ProfileView.swift:396`, `:1101`; `CloudSignOutFlowLogic.swift:127` | — |
| E5-08 | La migración re-lanza el sign-in interactivo aunque ya haya sesión (el gemelo que la reusa solo lo llama el Welcome) | E5, E6 | CONFIRMADO, bajado a media (prompt extra, no divergencia de datos) | `StorageSettingsView.swift:426`; `CloudMigrationController.swift:249`, `:271` | — |
| E5-N2 | `deleteGroup` deshabilitado en release: la zona de un grupo es irreversible para el usuario | E5 | Nuevo del verificador | `GroupService.swift:326`, `:335`; `GroupSettingsView.swift:661` | — |
| E1-08 | El sign-in de nube no es del todo independiente del corpus personal | E1 | PARCIAL: cae media afirmación (que migrar exija cuenta en el backend no viola la independencia) | `CrossAccountEntryGuardLogic.swift:53`; `CloudSignOutFlowLogic.swift:32` | — |
| E6-06 · E4-05 · E2-07 | El eje C está acoplado al container: Grupos exige cuenta iCloud del OS, también post-migración | E2, E4, E6 | PARCIAL: el gate **no miente** mientras los grupos vivan en CKShare | `ContentView.swift:1960`; `GroupsICloudAvailabilityGateLogic.swift:31` | Retirar el gate por `storageMode` daría un tab roto: el orden del épico manda |
| E3-09 | La identidad del miembro de grupo ES el `userRecordID` de iCloud | E3 | PARCIAL: es corolario de E3-04; el diseño lo absorbe con `member_key` | `GroupService.swift:85`, `:112`; `GroupUserIdentityService.swift:26` | — |
| E7-17 | El usuario sin cuenta iCloud vive en un tercer estado del eje A que el modelo no nombra | E7 | PARCIAL: no hay superficie ACTIVA que le mienta | `SwiftDataConfiguration.swift:236`; `CloudSyncFlags.swift:27` | Deuda de modelado |

### Bajas

| ID(s) | Título | Escenarios | Evidencia |
|---|---|---|---|
| E1-N3 | La fila iCloud de las hojas destructivas miente en un device sin cuenta iCloud — **lo único de esta tanda visible HOY** | E1 | `DestructiveScopeLogic.swift:95-98`; `Localizable.strings:5131` |
| E1-13 | `storage.errors.generic` se usa como estado «no aplica» (deuda de copy latente) | E1 | `StorageSettingsView.swift:47` |
| E6-11 · E4-06 | `storage.revert.ineligible` colapsa 3 causas; el refutador prueba que solo `degradedNoMap` es alcanzable ahí | E4, E6 | `Localizable.strings:4684`; `StorageSettingsView.swift:241` |
| E1-03 | El estado de Sync nunca se muestra en la pantalla de almacenamiento en modo iCloud (duplicidad de superficies futura) | E1 | `StorageSettingsView.swift:117`, `:252` |
| E1-05 | El copy del wipe promete una propagación a iCloud que nada verifica | E1 | `Localizable.strings:5131`; `DataWipeService.swift:33` |
| E1-12 | El consent de grupos existe pero nunca bloquea el camino vigente | E1 | `GroupsConsentState.swift:9`; `GroupCreateRoutingLogic.swift:27` |
| E2-08 | El usuario Solo Grupos no recibe ninguna señal al actualizar (What's New cerrado por diseño para esa cohorte) | E2 | `ContentView.swift:1042`, `:1025` |
| E2-10 · NEW-E2-04 | El copy de salida atribuye al usuario grupos que viven en el iCloud de otro | E2 | `Localizable.strings:5052`, `:5188`; `SplitSyncManager.swift:303` |
| E3-10 | Las zonas creadas hoy no se liberan **automáticamente** al migrar (sí hay acción manual owner-only) | E3 | `GroupFreezeLogic.swift:30`; `GroupMigrationUploader.swift:123` |
| E3-11 | El copy de onboarding no menciona iCloud (sí lo hace `iCloudSyncSettingsView`) | E3 | `OnboardingView.swift:1242`; `Localizable.strings:1823` |
| E3N-03 | El progreso de restore presenta los grupos como parte del import personal, y no vienen de ahí | E3 | `RestoreProgressView.swift:110`, `:143` |
| E4-04 | La reutilización del sign-in en Grupos está implementada y correcta, pero DARK | E4 | `GroupsSignInView.swift:112`; `CloudSyncFlags.swift:239` |
| E4-09 | La reversa borra el faro asumiendo que ya no hay cuenta nube, falso si Grupos la sigue usando | E4 | `MigrationWorkExecutor.swift:568`; `CloudBeacon.swift:75` |
| E4-10 | Reusar el sign-in no evita la segunda pantalla de consentimiento de Grupos (keys separadas a propósito) | E4 | `GroupCreateRoutingLogic.swift:31`; `PreferenceMergeLogic.swift:115` |
| E5-13 | El copy que promete la invariante de cuenta única vive en una pantalla DARK | E5 | `Localizable.strings:4889`; `GroupsSignInView.swift:88` |
| E5-N4 | «Tu cuenta de Yala» no ofrece ningún camino para llevar lo personal a la nube | E5 | `YalaAccountLogic.swift:60`; `Localizable.strings:5317` |
| E6-08 | El sign-in del Welcome (no el de la migración) está acoplado al corpus y al Apple ID | E6 | `ContentView.swift:875`; `WelcomeCloudSignInView.swift:400` |
| E6-10 | Se oculta la fila «iCloud» de Ajustes mientras Grupos sigue usando iCloud activamente | E6 | `ProfileView.swift:898`, `:901` |
| E7-13 | El wipe desde el Welcome no emite señal y su copy subestima el alcance (se auto-sana) | E7 | `ContentView.swift:240`; `Localizable.strings:4142` |
| E7-14 | Un invitado que reinstala ve «vuelve a entrar» en un grupo al que ya entró (auto-sana) | E7 | `SplitGroup.swift:52`; `GroupCardDisplayLogic.swift:41` |
| E7-N3 | El aviso de mismatch de iCloud se consume aunque no se muestre (**ACTIVO**) | E7 | `AppBootstrapper.swift:785-791` |
| E7-N4 | Los CTAs de recuperación de iCloud son código muerto (`isAutoRecoveryAvailable` es un `let false`; «Revisar y reparar» tiene el cuerpo vacío) (**ACTIVO**) | E7 | `iCloudSyncSettingsView.swift:29`, `:117-119`, `:214-218` |

### Lo que SÍ cumple (verificado con lente inversa, no depende de ningún flag apagado)

- **«Vaciar datos» borra únicamente los datos personales** — 12 entidades, cero `Split*`, exclusión
  documentada y con test (`DataWipeService.swift:44`, `:280`; `DestructiveScopeLogic.swift:109`). La hoja de
  alcance es superficie **nueva** de esta épica.
- **«Cerrar sesión» lleva al Welcome dejando los datos disponibles** — `.privateReset` no borra ninguna fila
  ni archivo (`CloudSessionSignOut.swift:130`, `:190`), con **dos** puertas de re-entrada.
- **Los datos personales de un usuario nuevo aterrizan en el iCloud privado** y en la misma rama que un
  usuario existente (`SwiftDataConfiguration.swift:695`).
- **El sign-in Apple/Google es independiente del container privado** en el mecanismo de auth
  (`CloudAuthService.swift:161-183`; `CloudAuthKeychainStorage.swift:43`).
- **Tras el alta, un Solo Grupos se comporta como tal** (`TabBarConfiguration.swift:115`;
  `ShellModeLogic.swift:32`).
- **La reversa no altera el sign-in de Grupos** (ninguno de sus 6 efectos cierra sesión).
- **Widgets, Share extension y App Intents son ciegos a los 4 ejes** y sus espejos se purgan en todas las
  fronteras, con tests **de fuente** que lo pinnean (`SignOutWipeHookTests.swift:416-420`).
- **Cobertura de entidades del motor de nube completa**: 16 de 17 modelos del `personalSchema`; el único
  ausente es `CloudMigrationMarker`, CloudKit-only por diseño.

---

## §8 · Estado de despliegue (por qué «implementado» ≠ «activo»)

| Flag / gate | Valor real HOY en producción | Línea que lo fija | Qué desbloquea |
|---|---|---|---|
| `CloudBackendConfig.isConfigured` | **false** (`supabaseURL == nil`, `anonKey == ""` en el `#else`) | `CloudBackendConfig.swift:23-30`, `:32-38`, `:42-44` | TODO el Modo Nube: auth, controller, fila «Dónde viven tus datos», migración, reversa, cuenta, borrado de cuenta, remote-config |
| `CloudSyncFlags.groupsBackendEnabled` | **false** — compilado `false` **sin ningún `#if`** (tampoco en `Yala Dev`) AND remoto, con short-circuit | `CloudSyncFlags.swift:230-236`, `:239`, `:233` | Canal Grupos→backend, migración de grupos, `.groupsOnlySignOut`, push token, batch de salida, `groups_forget_user`, retiro del gate de iCloud |
| `CloudSyncFlags.storageMode` | **`.icloud`** (key ausente, sin descriptor secundario, sin override) | `CloudSyncFlags.swift:52-57`, `:164-171` | Mirror OFF, motor propio, wipe por archivos, «Volver a iCloud» |
| `CloudRemoteFlags.absentDefault` | **false** en prod (fail-closed), `true` en `DEV_BUILD` | `CloudRemoteConfig.swift:111-117` | Default de los 3 rollouts sin snapshot cacheado |
| `CloudRemoteFlags.cloudModeEnabled` | **false**, y el fetch **nunca corre** en prod | `CloudRemoteConfig.swift:125-128`, `:236`; `AppBootstrapper.swift:273-275` | Entrada a migración, cards de sign-in nube del Welcome, entrada secundaria |
| `CloudRemoteFlags.cloudOnboardingChoiceEnabled` | **false** | `CloudRemoteConfig.swift:138-141` | Pantalla de elección born-cloud — **irrelevante: la pantalla no tiene callsite** |
| `CloudRemoteFlags.groupsBackendEnabled` (remoto) | **false**, y es **kill-switch puro**: no puede encender solo | `CloudRemoteConfig.swift:138-141`; composición en `CloudSyncFlags.swift:233` | Matar el canal de grupos sin release |
| `CloudSyncFlags.secondarySessionEnabled` | **false** en release (en `DEV_BUILD` la enciende una key del panel DEBUG) | `CloudSyncFlags.swift:187-198` | Sesión secundaria M1 (multi-cuenta por archivo) |
| `CloudSyncFlags.secondarySessionEntryAvailable` | **false** (AND con `isConfigured` + remoto) | `CloudSyncFlags.swift:209-212` | La **entrada** a la sesión secundaria |
| `CloudSyncFlags.identityCaptureEnabled` | **false** | `CloudSyncFlags.swift:142` | Asignación de `syncID` al nacer la fila (born-cloud) |
| `CloudSyncFlags.syncRuntimeEnabled` | **true**, pero inerte (`isConfigured == false` y todo device en `.icloud`) | `CloudSyncFlags.swift:153` | Wiring del runtime del motor propio |
| `CloudSyncFlags.historyPurgeEnabled` | **true**, doble-dark (exige runtime en `.cloud`) | `CloudSyncFlags.swift:259` | Purga de History tras un ciclo del runtime |
| `GroupsConsentState.isAccepted` | **false** — las keys nunca se escriben (solo `register()`, desde una pantalla DARK) | `GroupsConsentState.swift:9-11`, `:31` | Requisito de crear/unirse/migrar en el canal backend |
| `AppPreferences.Keys.groupsBetaUnlocked` | **false** por defecto, per-device, **excluido del wipe** | `GroupsBetaGateLogic.swift:22`, `:34`; `DataWipeService.swift:270` | Gate ACTIVO de entrada al tab Grupos (código `"1050"`) |
| `visibleNewOptions` / born-cloud | **sin callsite en `Yala/`** (6 hits en `YalaTests/`) | `WelcomeAccountChoiceLogic.swift:36`, `:11` | Nada: no es un flag, es código muerto |
| Borrado de zona del container privado | **no existe código** (0 hits de `deleteRecordZone`/`CKModifyRecordZones`/`purgeCloudKit`) | — | Nada |

**Semántica ratificada del kill-switch remoto**: corta solo la ENTRADA; un usuario ya `.cloud` conserva
runtime, outbox y reversa (`CloudRemoteConfig.swift:11-14`; `StorageRowGateLogic.swift:31` con el input
`isEngaged`).

---

## §9 · Lo que esta auditoría NO pudo verificar

1. **Nada se ejecutó en dispositivo ni en simulador.** No hay una sola captura, log ni run de test en esta
   auditoría: es lectura de código sobre el árbol de trabajo de la branch `2.0.5`. Todo lo etiquetado como
   comportamiento es *lo que el código dice que pasa*.
2. **El backend real no se consultó.** No se llamó a Supabase ni al gateway; el valor vivo de
   `groupsBackendRolloutPercent` y de `cloudModeEnabled` en staging es desconocido (en prod la conclusión es
   firme porque el fetch no corre y `absentDefault == false`).
3. **El estado server-side de CloudKit no se consultó.** No sabemos qué zonas ni qué record types hay hoy en
   `iCloud.com.jurgenschmidt.yala` ni en `…yala.groups`. Los residuos `CD_Split*` y las zonas
   `SplitGroup-*` en el store personal son un hallazgo **del propio código** (`CKIdentityCapture.swift:15-16`),
   no una observación nuestra.
4. **Semántica exacta de plataforma, NO VERIFICADA**: si `ubiquityIdentityToken` es nil con cuenta iCloud
   viva y Drive apagado; si el mirror `.automatic` empieza a exportar en la MISMA sesión al aparecer la
   cuenta o exige relanzamiento; si SIWA es utilizable sin Apple ID en el OS.
5. **La fuga de handover (`NEW-E2-01`) no se reprodujo.** El encadenado está verificado en código
   (store de grupos sobrevive el wipe → bridge sin comprobación de identidad → TX virtuales), pero el
   resultado visible en Panel/Inbox no se observó.
6. **Los flujos DARK no se pudieron ejercitar en ninguna polaridad real.** Migración, reversa, adopt, sesión
   secundaria, canal de grupos backend y borrado de cuenta se auditaron leyendo su código y sus tests, nunca
   corriéndolos con un backend vivo.
7. **La fiabilidad real de `waitForImportQuiescence`** sobre un container poblado en un device nuevo y lento
   no se puede determinar leyendo código; el propio doc admite el defecto de «store vacío»
   (`iCloudSyncService.swift:487-492`).
8. **No se auditó `PreferenceMergeLogic` / `PrefsSyncClient` línea a línea**, ni
   `performDeleteFrozenCopy` (la acción manual de borrado de la copia congelada de un grupo).
9. **No se midió si algún call-site recompone mal la «forma»** (Completo / Solo Grupos / personal-solo): no
   existe enum, se recompone en cada sitio, y una revisión exhaustiva de todos los call-sites quedó fuera de
   alcance.
10. **Los documentos del vault se usaron solo como pista de intención.** Cuando el código y el diseño
    discrepan, este informe reporta el código.

---

## Apéndice A · Hallazgos refutados y sub-afirmaciones caídas

### A.1 Hallazgos que cayeron por completo

| ID | Título que se afirmaba | Por qué cayó |
|---|---|---|
| E4-12 | «El grid de privacidad del onboarding describe un modo que el usuario no eligió» | El grid es fijo y **correcto hoy** (lo admite el propio auditor): toda alta acaba en iCloud privado. Su «mentira» es condicional a una feature sin callsite ⇒ cero consecuencia para cualquier usuario en cualquier build. Es una nota para el incremento born-cloud, no un hallazgo (`OnboardingView.swift:1242`) |
| E5-11 | «Un CKShare legacy se acepta sin flag ni sesión: la puerta CloudKit no se cierra sola» | Premisa invertida: la coexistencia CloudKit↔backend es explícita y **por grupo** (`isBackendGroup` + `movedToBackendAt` + `GroupFreezeLogic`). Un grupo no migrado **debe** aceptarse por CKShare y no necesita cuenta de nube; exigir sesión rompería a los legados (`SplitSyncManager.swift:701`) |
| E7-15 | «Una lista de grupos mixta (CloudKit + backend) no se distingue ni se explica» | El único comportamiento realmente distinto durante el rollout —grupo migrado no adoptado en este device— **sí** tiene su modo: `.migratedFrozen` con chip y CTA. Writes, invites y freeze se resuelven en servicio y routing sin pedirle nada al usuario: el canal es estado interno (`GroupCardDisplayLogic.swift:41`) |
| E7-01 | «Estado mixto (personal iCloud + grupos backend) diseñado pero DARK» — se presentaba como brecha | La expectativa del dueño (que se explique y sea consistente) **está cumplida en código**: `dataLocation .groupsOnly`, caption R9 en el sign-in, `.groupsOnlySignOut`. Que sea DARK es el estado esperado de una épica sin lanzar, no una brecha del escenario (`YalaAccountLogic.swift:58`; `CloudSignOutFlowLogic.swift:32`) |

### A.2 Sub-afirmaciones caídas dentro de hallazgos que sí sobrevivieron

| Hallazgo | Sub-afirmación refutada | Corrección |
|---|---|---|
| E1-09 · E2-02 · E5-10 · E6-05 | «Ni con el flag ON habría sign-in» | Con el flag ON el sign-in **sí** es obligatorio para crear grupo (`route → .needsSignIn` antes del form) y para unirse por invite backend. Lo que falta es el gate de **entrada** |
| E1-02 | «`persistLocalMode` es el único write de `.cloud`» | Hay **dos** (`MigrationWorkExecutor.swift:425` y `:1126`). La conclusión no cambia: ambos cuelgan del mismo runner |
| E1-05 | «El copy del wipe promete una propagación que nada implementa» | El export de deletes por el mirror **es** el mecanismo arquitectónico. Y el agravante citado se vuelve mitigación: el receptor de `lastWipeTimestamp` solo ofrece un alert cuya confirmación no borra nada |
| E1-08 | «Migrar exige sign-in ⇒ los ejes están acoplados» | Que migrar a un backend propio exija cuenta en ese backend es la definición del destino, no un acople de ejes |
| E2-01 · E5-01 · E4-03 | «Crear zona CloudKit con el canal apagado es un defecto» | Es el comportamiento shipped **correcto y documentado** (byte-idéntico). Lo durable y estrecho es que la migración no libere la zona |
| E2-01 · E4-02 · E7-11 | «Cero borrados de zona en `Yala/`» | `SplitZoneManager.deleteZone` existe con 2 call-sites; ambos inalcanzables en release (uno DEBUG-only, otro exige `movedToBackendAt != nil`). La afirmación correcta es «ninguno alcanzable en producción» |
| E2-03 | «Un invitado no puede migrar ninguno» | Mal encuadrado: el grupo es un objeto, lo migra su owner y el invitado re-entra con el token que viaja por CloudKit. El hueco real es que **nada fuerza** la migración |
| E2-04 | «Solo un cambio de Apple ID limpia los grupos locales» | El aislamiento por Apple ID **sí** existe y está ACTIVO (`runIdentityBootGuard`). La fuga es la variante estrecha: handover sin cambiar el Apple ID |
| E3-07 · E5-05 | «Ninguna detección de ocupación» | Excesivo: el restore responde **operativamente** si este Apple ID tiene datos (import-then-count) y `RestoreOfferGate` lee el iKV. Falta un detector **autoritativo**, no toda detección |
| E3-10 | «Las zonas nunca se liberan» | Existe una acción de usuario con copy localizado («Borrar mi copia congelada»), owner-only y post-migración. Lo que falta es que sea **automática** |
| E3-11 | «El copy nunca menciona iCloud» | `iCloudSyncSettingsView` (ACTIVO, alcanzable desde `ProfileView.swift:529`) sí lo dice |
| E4-09 | «Se pierde la red R9 y un 2º device podría sembrar una cuenta divergente» | Refutado dos veces: con la cuenta viva R9 ni se consulta, y en `.accountMissing` el código hace `signOut()` **siempre** sin crear nada server-side |
| E5-03 | «El usuario queda atascado sin iCloud» | Puede seguir como Completo; lo imposible es **ser** Solo Grupos sin iCloud |
| E5-13 | «Ninguna superficie ACTIVA dice dónde viven los datos de un Solo Grupos» | Hay varias (gate de iCloud, alert del onboarding, subtítulo de «Salir de Yala», What's New). Falta la promesa de **cuenta única**, no la de ubicación |
| E6-02 | Cita `Yala/Services/Groups/SplitSyncStartGate.swift` | El fichero vive en `Yala/App/Logic/SplitSyncStartGate.swift` |
| E1-11 · E7-04 | Cita `Yala/Services/CloudSync/RestoreOfferGate.swift` | El fichero vive en `Yala/App/Logic/RestoreOfferGate.swift` |
| E3-06 | Cita el copy del gate de iCloud en `Localizable.strings:4627` | Ese es el alert del onboarding; el copy del gate es `groups.icloud.gate.message` en `:4856` |
| E7-06 | «Los CTAs Reintentar / Revisar y reparar son inertes» y «la cuota produce `.stalled`» | Los CTAs **no se renderizan** (`isAutoRecoveryAvailable` es un `let false`) y la cuota produce `.failed`. Sobrevive: cero copy de cuota y el mensaje falso de «sin conexión» |
| E7-13 | «Otros devices vuelven a ofrecer restaurar sobre un container vaciado» | Se auto-sana: al terminar el onboarding se escribe un `lastOnboardingTimestamp` más nuevo y `hasReturningSignal` vuelve a true, que es correcto |
| E7-03 | «El detector se auto-desarma a la primera» | El flag se arma **dentro** del `if` (`AppBootstrapper.swift:785`) |
| Varias | `MigrationWorkExecutor.swift:424` como «el write de `.cloud`» | `:424` es la firma de `persistLocalMode()`; el write es `:425` |
| Varias | `GroupMigrationUploader.swift:125` como el predicado | El predicado está en `:126` (off-by-one) |

**Verificación por muestreo del crítico de completitud**: de 13 citas decisivas del dossier revisadas una a
una, **ninguna resultó falsa**; solo dos derivas de ±1 línea. La calidad de citación de la auditoría es alta.

---

## Apéndice B · Informes de trabajo

> **Actualizado 2026-07-28:** los 35 informes de trabajo ya NO viven en el scratchpad temporal (se purga). Están guardados en `$VAULT/Backlog/modo-nube/evidencia-2026-07-28/` — mapas, escenarios, refutaciones, críticos e inventarios. Las rutas `/private/tmp/...` que se citen más abajo son históricas.

Todos en `/private/tmp/claude-501/-Users-jur-Yala/8c51544b-8a11-4e85-b046-514bd8c97a4d/scratchpad/`
(directorio de sesión, efímero).

| Fichero | Contenido |
|---|---|
| `MAP-1-estado.md` | Cartografía de los 4 ejes: SSOT, keys, writes, matriz de 19 estados combinados, inventario de UserDefaults / Keychain / App Group / iCloud KV |
| `MAP-2-onboarding.md` | Cartografía del arranque: orden pre-mount, `checkInitialSyncState`, matriz de 28 blockers, Welcome/chooser/restore/sign-in nube, 7 árboles de decisión por tipo de arranque, 25 launch args de test |
| `MAP-3-grupos.md` | Cartografía de Grupos: gates del tab, creación, migración legacy→backend, unión por invitación, consent, sign-out con grupos, bridge, 13 flags, matriz ACTIVO/DARK/NO EXISTE |
| `MAP-4-settings.md` | Ajustes y ciclo de vida del dato: `StorageSettingsView` fila por fila, `YalaAccountView`, alcance real de cada borrado, 4 caminos de sign-out, migración y reversa, preferencias por identidad |
| `ESC-E1.md` … `ESC-E7.md` | Un informe por escenario, con narrativa paso a paso y tabla expectativa-vs-realidad |
| `VER-E1.md` … `VER-E7.md` | Refutación independiente de cada informe: intento activo de tumbar cada hallazgo, más hallazgos nuevos del verificador |
| `CRITICO-completitud.md` | Lo que ningún escenario miró: extensiones y App Group, cobertura de entidades, gates de quiescencia, StoreKit; verificación por muestreo de 13 citas |
| `CRITICO-invariantes.md` | Juicio de las dos invariantes y de la meta, con barrido exhaustivo de CloudKit, las 6 señales sustitutas y los 7 caminos abiertos del container de grupos |
