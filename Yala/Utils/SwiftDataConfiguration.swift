//
//  SwiftDataConfiguration.swift
//  Yala
//
//  Configuración centralizada de SwiftData para aislamiento entre builds.
//  CloudKit sync siempre activo si hay cuenta iCloud.
//

import CloudKit
import Foundation
import SwiftData

enum SwiftDataConfiguration {
    // MARK: - CloudKit

    /// CloudKit container for SwiftData auto-sync (personal data).
    static var cloudKitContainerIdentifier: String {
        if let appGroup = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String,
           appGroup.hasSuffix(".dev") {
            return "iCloud.com.jurgenschmidt.yala.dev"
        }
        return "iCloud.com.jurgenschmidt.yala"
    }

    /// CloudKit container dedicated to CKSyncEngine (groups).
    /// Separated from SwiftData auto-sync to prevent NSCloudKitMirroringDelegate interference.
    static var groupsCloudKitContainerIdentifier: String {
        if let appGroup = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String,
           appGroup.hasSuffix(".dev") {
            return "iCloud.com.jurgenschmidt.yala.groups.dev"
        }
        return "iCloud.com.jurgenschmidt.yala.groups"
    }

    /// Check if iCloud account is available
    static func isICloudAvailable() -> Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Database

    /// Database name diferenciado por build.
    /// Usa APP_GROUP_IDENTIFIER de Info.plist (consistente con SharedContainerService).
    static var databaseName: String {
        if let appGroup = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String,
           appGroup.hasSuffix(".dev") {
            return "YalaModel-Dev"
        }
        return "YalaModel"
    }

    // MARK: - Schemas

    /// Schema completo (24 modelos) — usado por ModelContainer.
    static var schema: Schema {
        Schema([
            Category.self,
            Subcategory.self,
            Tag.self,
            Account.self,
            TransactionItem.self,
            Budget.self,
            ExchangeRate.self,
            FavoritePayment.self,
            ScheduledPayment.self,
            InboxDraft.self,
            MerchantMemory.self,
            NotificationItem.self,
            CashFlowPlan.self,
            CashFlowLine.self,
            CashFlowOverride.self,
            GroupBridgePreference.self,
            CloudMigrationMarker.self,
            SplitGroup.self,
            SplitMember.self,
            SplitExpense.self,
            SplitShare.self,
            SplitSettlement.self,
            SyncIdentity.self,
            SyncOutbox.self,
            SyncCursor.self,
            SyncQuarantine.self,
            SyncDanglingRef.self,
            SyncUnitClock.self,
            MigrationState.self,
            GroupSyncOutbox.self,
            GroupSyncCursor.self,
        ])
    }

    /// Sub-schema: 16 modelos personales (CloudKit synced via private DB).
    /// `GroupBridgePreference` vive aquí porque es preferencia personal por-user
    /// (synced cross-device del mismo Apple ID, NO compartida con otros miembros
    /// del grupo). Distinto de los Split* que viven en `groupsSchema` (CKSyncEngine).
    static var personalSchema: Schema {
        Schema([
            Category.self,
            Subcategory.self,
            Tag.self,
            Account.self,
            TransactionItem.self,
            Budget.self,
            ExchangeRate.self,
            FavoritePayment.self,
            ScheduledPayment.self,
            InboxDraft.self,
            MerchantMemory.self,
            NotificationItem.self,
            CashFlowPlan.self,
            CashFlowLine.self,
            CashFlowOverride.self,
            GroupBridgePreference.self,
            CloudMigrationMarker.self,
        ])
    }

    /// Sub-schema: 5 modelos de grupos (local only — CKSyncEngine maneja sync).
    static var groupsSchema: Schema {
        Schema([
            SplitGroup.self,
            SplitMember.self,
            SplitExpense.self,
            SplitShare.self,
            SplitSettlement.self,
        ])
    }

    /// Sub-schema: metadata de sync del Modo Nube (I2/I3), en su propio store con
    /// `cloudKitDatabase: .none` — metadata LOCAL por dispositivo que NUNCA se espeja a CloudKit.
    /// `SyncIdentity` (I2), `SyncOutbox` + `SyncCursor` (I3, pipeline de captura), `SyncQuarantine`
    /// + `SyncDanglingRef` (I8f-1, deltas no materializables aún + refs singulares colgadas),
    /// `SyncUnitClock` (I8f-2, HLC por-unidad por fila — señal de los reconciliadores).
    /// `MigrationState` (I10-wiring, journal durable de la máquina de migración — single-row).
    static var syncMetaSchema: Schema {
        Schema([
            SyncIdentity.self,
            SyncOutbox.self,
            SyncCursor.self,
            SyncQuarantine.self,
            SyncDanglingRef.self,
            SyncUnitClock.self,
            MigrationState.self,
            // G2: cola + cursor del canal de sync de Grupos → backend (DARK; store `.none`, sin deploy).
            GroupSyncOutbox.self,
            GroupSyncCursor.self,
        ])
    }

    // MARK: - Configurations

    /// Detect if running inside a test host. Cubre XCTest legacy y Swift Testing.
    /// Sin esta detección, el host (Yala.app) bootea con CloudKit durante el test
    /// runner y crashea repetidamente con `CKAccountStatusNoAccount` → process
    /// restarts en `/test-ios` completos.
    ///
    /// Cacheado en `let` para que sea estable durante el ciclo del proceso (evita
    /// que la decisión cambie entre boot temprano y boot tardío del host).
    nonisolated static let isRunningTests: Bool = {
        let env = ProcessInfo.processInfo.environment
        // SEÑAL CANÓNICA: el TestAction de los schemes (Yala / Yala Dev) inyecta
        // `YALA_TEST_MODE=1` en el host. Es la ÚNICA señal disponible de forma
        // determinista en `@main` (cuando YalaApp crea sharedModelContainer), porque
        // ahí XCTest/Testing.framework aún NO están cargados ni `XCTestConfigurationFilePath`
        // está seteado para suites Swift Testing puras. Sin esto el host arrancaba con
        // CloudKit en sims sin cuenta iCloud (CI) → crash loop de NSCloudKitMirroringDelegate
        // (CKAccountStatusNoAccount) aunque las aserciones pasaran. Ver TESTING-STRATEGY.md.
        if env["YALA_TEST_MODE"] == "1" {
            return true
        }
        // XCTest legacy — variables de entorno que setea el runner (fallback si se
        // corre fuera del scheme, p.ej. un `xcodebuild test` con scheme custom).
        if env["XCTestConfigurationFilePath"] != nil
            || env["XCTestBundlePath"] != nil
            || env["XCTestSessionIdentifier"] != nil {
            return true
        }
        // Swift Testing y XCTest cargan el framework XCTest.framework en el process.
        // `XCTestObservationCenter` es la clase pública del framework — si está
        // disponible, estamos en un test runner.
        if NSClassFromString("XCTestObservationCenter") != nil {
            return true
        }
        // Swift Testing puro (sin XCTest) — detectar la clase del framework Testing.
        if NSClassFromString("Testing.Test") != nil {
            return true
        }
        // Fallback: scan loaded bundles
        if Bundle.allBundles.contains(where: { $0.bundlePath.hasSuffix(".xctest") }) {
            return true
        }
        return false
    }()

    /// UI-testing seam (mirror de `isRunningTests`). En release siempre false.
    /// Fuerza store local dedicado sin CloudKit para aislar los XCUITests del
    /// CloudKit del Apple ID (espejo del bypass de tests unitarios).
    nonisolated static let isUITesting: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uitest")
        #else
        return false
        #endif
    }()

    // MARK: - Personal store mount witness (I10-wiring w6)

    /// Decisión PURA de qué store personal montar según el `StorageMode`, el flag "mirror-off ARMADO" y
    /// la disponibilidad de iCloud (extraída para testear la rama SIN construir el config —
    /// `isRunningTests` fuerza in-memory y ocultaría la rama real). `.cloud` ARMADO gana ANTES del check
    /// de iCloud: tener cuenta iCloud NO importa (Grupos la usa, pero el store personal ya NO lo espeja
    /// el mirror).
    /// `nonisolated` como lo era el `StorageMode` al que sustituye como testigo: sus consumidores incluyen
    /// dos `enum nonisolated` de lógica pura (`MigrationRuntimeGate`, `CloudMigrationUIStateDeriver`), y sin
    /// esto `allCases`, `rawValue` y las conformances derivadas quedarían aisladas al MainActor por el
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` del target.
    nonisolated enum PersonalStoreDecision: String, Equatable, CaseIterable {
        /// `.cloud` + mirror-off ARMADO → `cloudKitDatabase: .none` sobre el MISMO archivo (mirror OFF).
        case cloudMirrorOff
        /// iCloud disponible → mirror `NSPersistentCloudKitContainer` (`.private`) — comportamiento de HOY.
        case iCloudMirror
        /// Sin iCloud → store local **con `cloudKitDatabase` por DEFECTO** (`.automatic`). El nombre dice
        /// "sin mirror" y es engañoso: ver `attachesCloudKitMirror`.
        case localNoMirror
        /// **R2 · el mount NEUTRO del relanzamiento cero.** Primer arranque de una instalación sin archivo
        /// de store, sin par persistido y sin chooser visto (`isFreshInstallForNeutralMount`)
        /// → `cloudKitDatabase: .none` **EXPLÍCITO** sobre el archivo personal.
        ///
        /// Es byte-idéntico a `.cloudMirrorOff` como `ModelConfiguration` (mismo archivo, mismo schema,
        /// mismo `.none`) y esa identidad ES la razón de ser del chip: elegir la nube en un alta fresh deja
        /// de exigir un remonte, porque el store montado **ya es** el que el par `.cloud` + `mirrorOffArmed`
        /// pide. Se mantiene como caso APARTE y no se reusa `.cloudMirrorOff` porque son dos hechos
        /// distintos —aquí el device todavía no ha elegido nada— y los tres ejes de abajo los separan:
        /// el neutro NO es un mount de modo nube (eje C), así que el aviso de iCloud SÍ le habla.
        ///
        /// El `.none` es explícito y no heredado: la auditoría R1(c) MIDIÓ que `.automatic` adjunta el
        /// mirror igual sin cuenta iCloud, así que "no pasar `cloudKitDatabase:`" no es un atajo, es el
        /// mount contrario.
        case neutralNoMirror
    }

    /// **R2 · el predicado PURO de «instalación fresca» que habilita el mount neutro.** Tres términos, y
    /// los tres son señales PRE-MOUNT (se pueden leer antes de construir un solo `ModelContainer`):
    ///
    ///  1. **No existe el archivo del store personal.** Es el término estructural del chip: todo device del
    ///     parque actual tiene archivo ⇒ **el camino nuevo le es inalcanzable por construcción**, y con él
    ///     la promesa de no-regresión de 2.1. La URL se deriva de una `ModelConfiguration` efímera (patrón
    ///     de `deleteStoreFiles`) para no capturar el testigo antes de tiempo.
    ///  2. **El par de storage está en su estado virgen** (`.icloud` sin armar). Un par a medias o `.cloud`
    ///     ya escrito significa que este device YA eligió, y quien decide entonces es la rama del par.
    ///  3. **El chooser del Welcome no se ha visto.** Es lo que hace que el neutro dure UN solo arranque:
    ///     en cuanto el usuario elige, el flag queda `true` y el arranque siguiente vuelve a la tabla
    ///     normal. Sin este término, un kill a mitad del Welcome con el archivo aún sin crear podría
    ///     re-montar neutro indefinidamente.
    ///
    /// **Un device que acaba de ejecutar el wipe de cierre de sesión pasa este predicado, y es CORRECTO:**
    /// `performSignOutWipeIfArmed` borra los archivos, repone el par a `.icloud` y devuelve el device a
    /// "recién instalado" (su propio docblock lo dice), así que a esta altura es INDISTINGUIBLE de una
    /// reinstalación — y tratarlo igual es lo que R4 querrá. Este chip no toca el sign-out; solo declara
    /// que no hay nada que distinguir.
    static func isFreshInstallForNeutralMount(
        personalStoreFileExists: Bool,
        persistedMode: StorageMode,
        mirrorOffArmed: Bool,
        hasShownWelcomeChooser: Bool
    ) -> Bool {
        !personalStoreFileExists
            && persistedMode == .icloud && !mirrorOffArmed
            && !hasShownWelcomeChooser
    }

    /// **R4 · el predicado PURO del NEUTRO DURABLE.** Dos términos, y el segundo no es una precaución: es
    /// lo que impide el bucle.
    ///
    ///  1. **El neutro está ARMADO** (`StorageModePersistence.neutralMountArmedKey`). Lo arma el wipe de
    ///     cierre de sesión, en sus dos caminos. Es un estado EXPLÍCITO — la ausencia de la key de storage
    ///     significa `.icloud` por contrato, así que "neutro" no se puede decir borrando nada.
    ///  2. **El chooser del Welcome no se ha visto.** En cuanto el usuario elige, la key queda INERTE y la
    ///     tabla de mounts vuelve a la normal. Sin este término, un destino que necesita el mirror
    ///     —restaurar de iCloud, onboarding privado— pediría reabrir la app y el arranque siguiente
    ///     volvería a montar neutro: relanzamiento en bucle y una cuenta que nunca se restaura.
    ///
    /// **Se separa de `isFreshInstallForNeutralMount` en vez de ensancharlo** porque son dos hechos
    /// distintos con dos evidencias distintas: allí la protección estructural es que el archivo del store
    /// NO existe (por eso el parque actual no puede alcanzar el camino nuevo); aquí el archivo SÍ existe
    /// —lo acaba de crear el remonte del swap— y lo que autoriza el neutro es que este device escribió la
    /// marca al vaciarse. Colapsarlos obligaría a soltar el primer término y con él la promesa de
    /// no-regresión de R2.
    ///
    /// **R5 · el TERCER término, y no lleva la caducidad de los otros dos** (paso 5 del rediseño de
    /// sesiones). Una sesión SOLO-GRUPOS no tiene sesión privada (ADR §2), así que su store personal monta
    /// neutro en TODOS los arranques hasta que el usuario elija lo personal — no un arranque, como los dos
    /// términos de arriba. Va en `||` y no como cuarto parámetro de la conjunción por eso mismo: es un
    /// hecho distinto con su propia evidencia y su propia vida.
    ///
    /// **Por qué `hasShownWelcomeChooser` no puede gatearlo.** `onSelectPrivateAccount` marca ese flag en
    /// el acto, antes de escribir nada, y desde ahí se alcanzaba el alta solo-grupos sin volver al
    /// Welcome: el onboarding privado ofrecía la card «Solo grupos», que entraba a la misma cadena del
    /// organizador. Ese recorrido llegaba a `writePreferences` con el flag ya en `true`, y gatear aquí
    /// dejaba su neutro inerte y el bug del ticket vivo. (Ese recorrido desapareció el 2026-09-10 con la
    /// card, ADR 2026-09-09 §7; el término no se re-evaluó con eso.) El anti-bucle que la
    /// caducidad daba se sustituye por el desarme explícito en `onNeedsMirrorRelaunch` — ver el docblock
    /// de `StorageModePersistence.groupsOnlyNeutralMountKey`, que lo desarrolla entero.
    /// **El término nuevo va CONFINADO a `.icloud` sin armar, igual que sus dos hermanos, y no es
    /// simetría cosmética: sin ese confinamiento abre dos daños medidos.**
    ///
    ///  · **La ventana SERIO-1 del cutover.** `.cloud && !mirrorOffArmed` es un estado legítimo y
    ///    transitorio (el par no se puede escribir atómico), y el contrato dice que ahí el mirror tiene
    ///    que REMONTAR para que el `CloudMigrationMarker` llegue a exportar. Un término que devuelve
    ///    `true` incondicional lo impide: saldría `.neutralNoMirror`, el marcador no exportaría jamás y
    ///    la migración quedaría enclavada.
    ///  · **La reversa.** «Volver a iCloud» repone `.icloud` y quita `mirrorOffArmed`; sin confinar, una
    ///    marca superviviente de una etapa solo-grupos anterior reviviría ahí y apagaría el espejo **para
    ///    siempre**, en un device donde ya no queda Welcome ni activación que lo desarme.
    ///
    /// Confinado, la marca es INERTE en cuanto el device sale de `.icloud` virgen, que es exactamente
    /// cuando deja de ser «no ha elegido nada».
    static func shouldMountNeutralDurable(
        neutralMountArmed: Bool,
        hasShownWelcomeChooser: Bool,
        groupsOnlySessionArmed: Bool,
        persistedMode: StorageMode,
        mirrorOffArmed: Bool
    ) -> Bool {
        if groupsOnlySessionArmed && persistedMode == .icloud && !mirrorOffArmed { return true }
        return neutralMountArmed && !hasShownWelcomeChooser
    }

    /// SERIO 1 del review adversarial (ciclo C): `storageMode == .cloud` por sí solo NO basta para
    /// apagar el mirror — `.cloud` se persiste en el paso 2 del cutover (§g.4) y el marcador CloudKit
    /// exporta ASYNC en el paso 3; un kill involuntario en esa ventana relanzaría con el mirror OFF y el
    /// marcador JAMÁS exportaría (migración enclavada en `markerWritten`, irrecuperable sin la reversa).
    /// El montaje mirror-OFF exige el par COMPLETO: `.cloud` Y `mirrorOffArmed` (que el executor arma
    /// SOLO tras `isMarkerExported()`). Un kill pre-armado → mirror remonta ON → el marcador exporta en
    /// el resume → recién el relaunch posterior apaga el mirror. R9: JAMÁS caer a `.automatic`.
    ///
    /// **R9 está INCUMPLIDO hoy por `.localNoMirror`, y su consecuencia está MEDIDA (auditoría R1(c),
    /// 2026-08-10): `.automatic` adjunta el mirror igual, sin cuenta iCloud.** La medición y por qué el fix
    /// —explicitar `.none`— es una decisión APARTE y no de este chip (cambiaría el comportamiento del parque
    /// sin iCloud) están en `PersonalStoreDecision.attachesCloudKitMirror`.
    ///
    /// **R2 — `freshInstall` va SIN default a propósito** (molde del tercer término de
    /// `MigrationRuntimeGate.canRun`): la tabla de mounts es el sitio donde un descuido cuesta un store
    /// montado del revés, así que todo llamador está obligado por el compilador a pronunciarse sobre si
    /// este device es una instalación fresca. Su posición en la cadena tampoco es cosmética: va **DESPUÉS**
    /// del par `.cloud`+armado —que protege un invariante duro (SERIO-1)— aunque
    /// `isFreshInstallForNeutralMount` ya lo excluya. Las dos ramas son mutuamente excluyentes hoy; el
    /// orden es lo que mantiene inofensivo un ensanchamiento futuro del predicado.
    ///
    /// **R4 — `neutralDurable` va SIN default por el mismo motivo que `freshInstall`**, y comparte rama con
    /// él: las dos son «este device todavía no ha elegido», con evidencias distintas (R2 lo prueba porque no
    /// hay archivo de store; R4 porque el wipe del cierre de sesión dejó la marca). Su posición tampoco es
    /// cosmética: va DESPUÉS del par `.cloud`+armado, así que un device a mitad del cutover jamás cae aquí
    /// aunque alguien dejara la marca puesta por descuido.
    static func personalStoreDecision(
        storageMode: StorageMode, mirrorOffArmed: Bool, iCloudAvailable: Bool,
        freshInstall: Bool,
        neutralDurable: Bool
    ) -> PersonalStoreDecision {
        if storageMode == .cloud && mirrorOffArmed { return .cloudMirrorOff }
        if freshInstall || neutralDurable { return .neutralNoMirror }
        return iCloudAvailable ? .iCloudMirror : .localNoMirror
    }
}

// MARK: - Los dos EJES derivados de la decisión de mount (R1 · relanzamiento cero)

/// Las dos preguntas que los consumidores del testigo de mount hacen de verdad, y que hasta R1 estaban
/// COLAPSADAS en un `StorageMode` de dos valores. Son EJES DISTINTOS y por eso hacen falta las dos: un
/// mount puede llevar el mirror ADJUNTO y aun así no espejar nada.
///
/// El colapso viejo (`decision == .cloudMirrorOff ? .cloud : .icloud`)
/// no era solo impreciso: hacía imposible expresar un mount SIN mirror que no fuera ninguna de esas dos
/// decisiones — que es exactamente el mount neutro que el relanzamiento cero necesita. Este chip NO lo
/// introduce (R1 es DARK): solo deja el testigo capaz de decirlo.
extension SwiftDataConfiguration.PersonalStoreDecision {

    /// EJE A — ¿este mount ADJUNTA `NSPersistentCloudKitContainer` al store personal? Es la pregunta de los
    /// cuatro consumidores del testigo de mount: lo que les importa es si hay un mirror escribiendo el
    /// MISMO store (la doble escritura que el relanzamiento asistido existe para evitar), no si ese mirror
    /// llega a subir algo.
    ///
    /// **`localNoMirror` es `true`, y está MEDIDO (2026-08-10, iPhone 17 Pro / iOS 26.5, sim SIN cuenta
    /// iCloud, auditoría R1(c) del chip).** Esa rama no pasa `cloudKitDatabase:` (`personalConfiguration`,
    /// abajo) ⇒ cae en el default `.automatic`, y `.automatic` **adjunta el mirror igual**: emite los mismos
    /// 2 eventos de `NSPersistentCloudKitContainer.eventChangedNotification` que `.private` explícito, con
    /// el mismo `NSCocoaErrorDomain/134400 (CKAccountStatusNoAccount)` y el mismo
    /// `NSCloudKitMirroringDelegate` vivo, mientras `.none` explícito emite CERO. Lo que la falta de cuenta
    /// cambia es que el mirror no puede SINCRONIZAR, no que no esté ahí.
    ///
    /// ⇒ dos consecuencias que hay que tener presentes antes de "arreglar" nada:
    ///  - el valor viejo del testigo para `localNoMirror` (`.icloud` = mirror vivo) **era correcto**; lo que
    ///    mentía era el colapso de cuatro decisiones en dos valores, no esta celda;
    ///  - la violación de «R9: JAMÁS caer a `.automatic`» (docblock de `personalStoreDecision`) es REAL,
    ///    pero explicitarla a `.none` sería un CAMBIO DE COMPORTAMIENTO para el parque sin iCloud, y esa
    ///    decisión es del punto de control — **no de este chip**, que solo la mide y la documenta.
    nonisolated var attachesCloudKitMirror: Bool {
        switch self {
        case .iCloudMirror:
            return true   // `.private(container)` explícito
        case .localNoMirror:
            return true   // `.automatic` — MEDIDO: adjunta aunque no haya cuenta
        case .cloudMirrorOff, .neutralNoMirror:
            return false  // `.none` explícito
        }
    }

    /// EJE B — ¿este mount montó el store personal CON el mirror de CloudKit espejando de verdad? Es la
    /// pregunta del testigo DURABLE (`containerCreatedWithCloudKit`) y de su único lector, el aviso
    /// «monté sin CloudKit y ahora hay iCloud» (`AppBootstrapper.checkForICloudMismatch`).
    ///
    /// Se separa del eje A justo por `localNoMirror`: ahí el mirror está adjunto (eje A `true`) pero no
    /// espeja nada, y es EL caso que el aviso existe para atender — el usuario acaba de iniciar sesión en
    /// iCloud y hay que remontar con `.private` explícito. Colapsar los dos ejes en un booleano dejaría el
    /// aviso mudo para ese device.
    ///
    /// **R2 · `neutralNoMirror` es `false`, y es la celda que da sentido al eje.** Un mount neutro se hace
    /// muchas veces CON cuenta iCloud disponible (es un fresh install cualquiera): si el testigo durable
    /// guardara la disponibilidad —lo que hacía antes de R1— registraría `true` y el aviso «monté sin
    /// CloudKit y ahora hay iCloud» quedaría MUDO para siempre, dejando al device sin mirror y sin forma de
    /// enterarse. Registrando el eje B queda `false` y el aviso funciona.
    nonisolated var mirrorsToICloud: Bool {
        switch self {
        case .iCloudMirror:
            return true
        case .localNoMirror, .cloudMirrorOff, .neutralNoMirror:
            return false
        }
    }

    /// EJE C — ¿este mount se quedó sin mirror **por decisión de modo nube**? Es el término R9 del aviso de
    /// iCloud, y va por el MOUNT y no por el modo de AHORA: lo que hace que «tener cuenta iCloud no sea un
    /// mismatch» no es lo que diga la key en el instante de preguntar, sino que ESTE proceso montara el
    /// store personal en modo nube a propósito.
    ///
    /// La distinción muerde en una ventana real: la reversa persiste `.icloud` EN CALIENTE
    /// (`persistICloudMode`) sobre un proceso montado en `.cloudMirrorOff`, y el lector del aviso corre en
    /// CADA vuelta a primer plano (`AppBootstrapper.handleBecameActive` → `checkForICloudMismatch`, y no
    /// solo desde el observer de `NSUbiquityIdentityDidChange`). Leyendo el modo de ahora, esa ventana
    /// pasaría el término R9 y el device recibiría un «reinicia la app» redundante encima del que la propia
    /// tarjeta de reversa ya está pidiendo. Leyendo el mount, no.
    ///
    /// Y sigue vivo lo que R1 existe para proteger: un mount SIN mirror que NO sea de modo nube —el
    /// `localNoMirror` de hoy, el neutro de R2— sí avisa.
    ///
    /// **R2 · `neutralNoMirror` es `false`, y esa decisión la heredó este chip ya tomada de R1.** El neutro
    /// no es una elección de modo nube: es la ausencia de elección. Un device que arranca neutro con cuenta
    /// iCloud disponible está exactamente en el estado que §1.3 describe —montado sin espejo, con iCloud a
    /// mano— y tiene que poder oír el aviso. Ponerlo del lado `true` "porque no lleva mirror" colapsaría el
    /// eje C con el eje A y dejaría al mount neutro sin ninguna superficie que lo delate.
    nonisolated var isCloudModeMount: Bool {
        switch self {
        case .cloudMirrorOff:
            return true
        case .iCloudMirror, .localNoMirror, .neutralNoMirror:
            return false
        }
    }
}

extension SwiftDataConfiguration {

    /// Testigo de QUÉ DECISIÓN de mount ejecutó realmente ESTE proceso sobre el store personal (NO lo
    /// persistido). Lo captura UNA sola vez, en la PRIMERA evaluación de `personalConfiguration` en el path
    /// de producción (= el build de `sharedModelContainer` al arrancar). Es el árbitro de
    /// `isMirrorConfirmedOff()`: en-sesión, tras `persistLocalMode` escribir `.cloud`, el mirror SIGUE
    /// montado (se montó al arrancar) → este testigo permanece en su valor de arranque hasta el
    /// RELANZAMIENTO, cuando un proceso nuevo captura `.cloudMirrorOff`.
    ///
    /// **R1 (relanzamiento cero): guarda la DECISIÓN, no un `StorageMode` de dos valores.** Antes se
    /// capturaba `.cloud`/`.icloud` colapsando las cuatro decisiones en dos, y ningún consumidor podía
    /// distinguir un mount sin mirror de otro. Los consumidores no leen esta propiedad a pelo: preguntan por
    /// el eje que les toca (`attachesCloudKitMirror` / `mirrorsToICloud`), que es donde vive la única
    /// definición de qué mount lleva mirror.
    ///
    /// Default `.iCloudMirror` — los paths test/uitest/spike no lo capturan ⇒ mirror asumido vivo, que es
    /// el valor conservador y el mismo default (`.icloud`) que tenía el testigo viejo.
    nonisolated(unsafe) static private(set) var personalStoreMountedDecision: PersonalStoreDecision = .iCloudMirror
    nonisolated(unsafe) private static var personalStoreMountedDecisionCaptured = false

    /// Solo tests: fuerza el testigo del mount PERSONAL. El host de tests nunca evalúa la rama de
    /// producción de `personalConfiguration` (corta antes en `isRunningTests`) ⇒ el testigo se queda en su
    /// default `.iCloudMirror` SIEMPRE, así que un test que quiera ejercitar un device ya relanzado en modo
    /// nube (el estado post-relanzamiento del born-cloud o del adopt) tiene que declararlo — es el mismo
    /// contrato I11-2 que hace fake-able `isMirrorConfirmedOff`. Restaurar en `defer` bajo
    /// `@Suite(.serialized)`: esto es estado GLOBAL DE PROCESO y dejarlo puesto contamina a las demás suites.
    static func _testSetPersonalStoreMountedDecision(_ value: PersonalStoreDecision) {
        personalStoreMountedDecision = value
    }

    private static func capturePersonalStoreMountedDecisionOnce(_ decision: PersonalStoreDecision) {
        guard !personalStoreMountedDecisionCaptured else { return }
        personalStoreMountedDecisionCaptured = true
        personalStoreMountedDecision = decision
    }

    /// **R4: reabre la captura del testigo para el REMONTE in-process.** "Una sola vez" era exacto mientras
    /// el único mount de un proceso fuera el del arranque; el swap de persona monta un segundo container
    /// vivo el proceso, y dejar el testigo en su valor de arranque lo convertiría en una MENTIRA con
    /// consecuencias inmediatas — `WelcomeMirrorRelaunchLogic.shouldRelaunch` compara contra
    /// `.neutralNoMirror`, así que un testigo congelado en `.cloudMirrorOff` haría que "Restaurar de
    /// iCloud" NO pidiera reabrir la app y el usuario se quedara esperando un import que nadie va a
    /// arrancar, sobre un store sin mirror.
    ///
    /// Lo llama ÚNICAMENTE el orquestador del swap, y justo antes de evaluar `personalConfiguration` para
    /// el container nuevo. No relaja la garantía de una-sola-vez del arranque: la re-arma un camino
    /// explícito, que es lo contrario de un default permisivo.
    static func reopenPersonalStoreMountedDecisionCaptureForSwap() {
        personalStoreMountedDecisionCaptured = false
    }

    // MARK: - Sign-out wipe (H4 — "Cerrar sesión" en `.cloud`)

    /// BOOT-CLEANUP del cierre de sesión en `.cloud`. DEBE correr ANTES de construir el
    /// ModelContainer (pre-mount): borra los ARCHIVOS de los stores personal y sync-meta y deja el
    /// device como recién instalado. Se borran ARCHIVOS y no FILAS a propósito — los deletes de
    /// filas quedan en la SwiftData History y el remount mirror-ON los REPLAYARÍA hacia iCloud
    /// destruyendo el backup congelado pre-migración (qa/cloud/README HALLAZGO 3). Un archivo
    /// nuevo no tiene History: el remount hace fresh import de iCloud = semántica de reinstalación.
    ///
    /// Precondiciones: el coordinador de sign-out ya subió TODO el outbox (verificado), cerró la
    /// sesión y armó `signOutWipeArmed`. El store de GRUPOS legacy (CKSyncEngine, atado al iCloud del
    /// OS) NO se toca por defecto; SOLO si el sign-out marcó `signOutWipeIncludesGroups` (G5-B: el store
    /// de grupos es re-descargable desde el backend y debe olvidarse junto a la sesión). El claim-store
    /// (UserDefaults keyed por userID) sobrevive → la misma cuenta re-entra por adopt sin migración.
    ///
    /// **D-R1 paso 2 (2026-07-30): quién escribe ese marker cambió, y con él las garantías de este hook.**
    /// Antes lo escribía el getter compuesto y este docblock podía afirmar «con el flag OFF el marker
    /// jamás existe ⇒ este hook es byte-idéntico»; hoy lo escribe la capacidad COMPILADA
    /// (`CloudSessionSignOut`), que es constante en el binario, así que el marker existe siempre que el
    /// sign-out venga de un device con sesión de grupos. Dos consecuencias que hay que tener presentes:
    ///  - Un device `.cloud` que NUNCA adoptó el canal backend pierde igualmente su store de grupos. El
    ///    predicado correcto sería de PRESENCIA (¿hubo alguna vez estado del canal en este device?) o una
    ///    purga POR FILAS del subconjunto backend, no un marker todo-o-nada por archivo.
    ///  - **RESIDUAL CONOCIDO, anotado en `MODO-NUBE-ROLLBACK` §2 y a decidir antes del TestFlight de dos
    ///    dispositivos:** borrar los archivos del store NO resetea los change tokens de CKSyncEngine, que
    ///    viven fuera (`Application Support/SplitSync/{private,shared}.json`). Por el invariante de
    ///    `SplitSyncManager.resetLocalGroupsSyncState` («borrar filas sin resetear los tokens deja a
    ///    CloudKit convencido de que este dispositivo está al día»), los grupos del canal CloudKit que
    ///    convivan en ese store NO vuelven nunca. El flip vuelve ese camino alcanzable por primera vez.
    ///    El emparejamiento no es gratis: resetear los tokens re-hidrataría también las zonas CloudKit
    ///    congeladas de los grupos ya migrados, lo que tras un borrado GDPR resucitaría parte del corpus
    ///    desde el iCloud del propio Apple ID. Por eso está diferido a decisión del owner, no aplicado.
    ///
    /// Orden IDEMPOTENTE ante kill a mitad (el arm se limpia AL FINAL; re-entrada re-ejecuta:
    /// archivos ya ausentes = no-op, escrituras de flags idempotentes):
    /// 1) archivos personal + sync-meta → 2) par storageMode/mirrorOffArmed a `.icloud` fresh
    /// (invariante SERIO-1: juntos) → 3) consent de grupos + prefs/caches/onboarding a estado recién
    /// instalada + notificaciones locales + colas del App Group → 4) desarmar.
    static func performSignOutWipeIfArmed() {
        guard !isRunningTests, !isUITesting else { return }
        performSignOutWipeIfArmed(
            defaults: .standard,
            deleteFiles: { deleteStoreFiles(named: $0, schema: $1) },
            resetPrefs: { DataWipeService.resetForSignOutWipe() },
            cancelNotifications: {
                NotificationService.shared.cancelAllNotifications()
                NotificationService.shared.clearDeliveredNotifications()
            },
            purgeInboundSurfaces: { AppGroupInboundPurge.purgeInboundSurfaces() },
            clearGroupsConsent: { GroupsConsentState.clear() },
            restoreDeferredInvite: { GroupInviteResumeStore.restoreIntoPendingJoins() },
            clearDeferredInvite: { GroupInviteResumeStore.clearAfterRestore() })
    }

    /// Variante inyectable (tests del ORDEN/idempotencia sin archivos reales, sin `UserDefaults.standard`
    /// y sin `UNUserNotificationCenter`; el wrapper de producción mantiene los guards de test/uitest).
    ///
    /// `resetPrefs` es un seam OBLIGATORIO, no cosmético: `DataWipeService.resetForSignOutWipe()` toca
    /// `ProfileImageStorage`/`AppRouter`/`ProTourManager`/`SetupChecklistManager`/`WidgetDataCache`/
    /// `Tips` y barre `UserDefaults.standard` — ejecutarlo bajo el runner destrozaría el estado del host.
    /// `clearGroupsConsent` lo es por lo mismo: `PreferenceSyncService` cablea `UserDefaults.standard` y
    /// `NSUbiquitousKeyValueStore.default` e ignoraría el `defaults` inyectado.
    static func performSignOutWipeIfArmed(
        defaults: UserDefaults,
        deleteFiles: (String, Schema) -> Bool,
        resetPrefs: () -> Void,
        cancelNotifications: () -> Void,
        purgeInboundSurfaces: () -> Void = {},
        clearGroupsConsent: () -> Void = {},
        restoreDeferredInvite: () -> Void = {},
        clearDeferredInvite: () -> Void = {}
    ) {
        guard StorageModePersistence.isSignOutWipeArmed(defaults) else { return }

        // S3 del review: si el borrado del archivo BASE falla (≠ no-existe), ABORTAR sin
        // escribir `.icloud` ni desarmar — continuar remontaría el mirror SOBRE el archivo
        // de la época `.cloud` y el replay de su History destruiría el backup de iCloud
        // (exactamente el fallo que el borrado-por-archivos existe para impedir). El arm
        // persiste → el próximo boot reintenta; mientras tanto el par SERIO-1 sigue
        // consistente (`.cloud`+mirrorOffArmed → mount mirror-OFF, sin riesgo).
        // La cancelación de notificaciones va DESPUÉS de este guard a propósito: si el store
        // sobrevive, sus recordatorios siguen siendo válidos (y el reconciler los reprogramaría).
        guard deleteFiles(databaseName, personalSchema),
              deleteFiles(syncMetaDatabaseName, syncMetaSchema) else {
            // **Paso 9 · con el modo `.icloud` el abort DESARMA.** El argumento de arriba («el par sigue
            // montando mirror-OFF, sin riesgo») es del camino `.cloud`. Desde el paso 9 también arman este wipe
            // los cierres de sesión PRIVADA y solo-grupos, y ahí el arranque monta el ESPEJO: la app entraría
            // normal con el arm colgando, la persona seguiría escribiendo, y un reintento que saliera bien
            // más tarde se llevaría cambios que nadie esperó a exportar. Desarmado, el cierre simplemente no
            // ocurrió: los datos siguen aquí y en iCloud, y volver a «Cerrar sesión» vuelve a esperar al export.
            if StorageModePersistence.read(defaults) == .icloud {
                StorageModePersistence.clearSignOutWipeIncludesGroups(defaults)
                StorageModePersistence.clearSignOutWipeArm(defaults)
                // El sobre de la invitación se va con el arm, por lo mismo: el cierre no ocurrió, así que
                // no hay nada que reponer. Dejarlo lo convertía en un residuo SIN dueño y sin nadie que lo
                // retirara —su único consumidor es este hook—, y el siguiente cierre de sesión, que puede
                // ser de otra persona, lo repondría con el tap armado: una solicitud de entrada a un grupo
                // viejo bajo una cuenta que nunca la pidió. Aquí el arm se retira, luego el par también.
                clearDeferredInvite()
                CloudSyncBreadcrumb.signOutWipeAborted(reason: "store file deletion failed — icloud, disarmed")
            } else {
                CloudSyncBreadcrumb.signOutWipeAborted(reason: "store file deletion failed")
            }
            return
        }

        // G5-B: si el sign-out marcó incluir grupos (canal grupos→backend, flag ON), borrar TAMBIÉN el
        // trío de archivos del store de grupos. Un fallo aquí NO aborta el wipe personal (ya consumado);
        // el trío -wal/-shm huérfano es inerte y el store se recrea vacío al montar. El marker se limpia
        // JUNTO al arm (AL FINAL, orden kill-safe existente).
        if StorageModePersistence.signOutWipeIncludesGroups(defaults) {
            _ = deleteFiles(groupsDatabaseName, groupsSchema)
            // Paso 9 · el latch «este dispositivo tuvo sesión de Grupos» se va con los grupos. Decide si el
            // empty state dice «vuelve a tu cuenta» o «crea una cuenta», y tras este borrado el dispositivo es
            // «recién instalado»: la persona siguiente no tiene grupos esperándola en ninguna cuenta.
            // `removeUserPreferenceKeys` no lo nombra (es del dominio Grupos), así que sin esto sobrevivía.
            defaults.removeObject(forKey: GroupsSessionHistoryMarker.key)
            // Paso 10 · el espejo local de la cuenta de grupos asociada se va con ellos, y por lo mismo:
            // tras este borrado el dispositivo es «recién instalado», y quien re-onboardee aquí leería en
            // Ajustes el CORREO de quien cerró la sesión. La copia del iCloud-KV SÍ se queda a propósito
            // —es del Apple ID, y quien restaure quiere su cuenta de grupos de vuelta—, así que este
            // borrado no es un desasociar: es olvidar lo que este teléfono sabía.
            defaults.removeObject(forKey: GroupsAccountAssociation.localKey)
            defaults.removeObject(forKey: GroupsDetachedBridgeLedger.userDefaultsKey)
            // Y la marca de un desasociar a medias, por lo mismo que su vecina: el teléfono se va con
            // otra persona y lo que quedó pendiente era de la anterior. Esta lista es de keys NOMBRADAS
            // —no hay barrido por prefijo— así que el `groups.*` del nombre no la borra solo.
            defaults.removeObject(forKey: GroupsDetachPendingPurge.userDefaultsKey)
        }

        StorageModePersistence.write(.icloud, defaults: defaults)
        defaults.removeObject(forKey: StorageModePersistence.mirrorOffArmedKey)

        // **R4 · el NEUTRO DURABLE, y vive AQUÍ por una razón que conviene no perder.** Este hook es el
        // único código que devuelve el device a "recién instalado", y desde R4 tiene DOS caminos: el boot
        // (cuando el swap in-process no fue posible) y el propio swap, que lo invoca con el proceso vivo.
        // Armar la marca dentro del hook es lo que hace que los dos terminen en el MISMO estado — si la
        // armara el coordinador de sign-out, el camino degradado dependería de que el arm y el wipe no se
        // separaran nunca, y el kill entre ambos es justo lo que este orden kill-safe existe para tolerar.
        //
        // Va PEGADO al `write(.icloud)` porque son la misma decisión vista dos veces: el par vuelve a su
        // estado virgen y el mount se declara sin elección hecha. Y va ANTES de `resetPrefs()` a propósito,
        // aunque `removeUserPreferenceKeys` excluya `cloudSync.*`: depender de esa exclusión sería apoyar
        // un invariante de mount en la lista de exclusiones de un barrido de preferencias.
        //
        // Sin esto, un device que acabara de remontar in-process y muriera antes de que el usuario eligiera
        // volvería a `.iCloudMirror` en el arranque siguiente —el archivo del store YA existe, así que el
        // predicado de R2 no lo cubre— adjuntando el mirror al store vaciado del humano que se fue.
        StorageModePersistence.armNeutralMount(defaults)
        // El neutro de SOLO-GRUPOS se retira aquí, y no es redundante con la línea de arriba: son dos
        // marcas con vidas distintas. Ésta no caduca con el chooser, así que sobrevivir a un wipe que
        // devuelve el device a «recién instalado» la dejaría decidiendo el mount de la vida siguiente —
        // un estado que sobrevive a su motivo. `removeUserPreferenceKeys` excluye `cloudSync.*` a
        // propósito, así que este es el único sitio donde puede irse.
        StorageModePersistence.clearGroupsOnlyNeutralMount(defaults)
        // Paso 9 · el testigo «eligió privado sin iCloud» (la validación aplazada del paso 4) es de la vida
        // que se cierra. `cloudSync.*` lo excluye el barrido de preferencias, así que sin esto la persona
        // siguiente heredaría un aviso de espejo tardío sobre un corpus que no es suyo.
        StorageModePersistence.clearPrivateChoseWithoutICloud(defaults)
        // EL EJE 1 muere aquí, y por la misma razón que sus dos vecinas de arriba: describe la vida
        // que se cierra. `removeUserPreferenceKeys` excluye `cloudSync.*` a propósito —y para la
        // marca esa exclusión es deliberada, porque tiene que SOBREVIVIR a «Vaciar datos»— así que
        // éste es el único sitio donde puede irse. Sin esto, la persona siguiente heredaría el eje
        // del humano anterior: un solo-grupos que se va dejaría a quien restaure su iCloud con la
        // marca en `false`, y su «Cerrar sesión» borraría sin esperar al export.
        PrivateSessionMark.clear(defaults)

        // El consent de GRUPOS (§C5) es un registro de la CUENTA y `removeUserPreferenceKeys` no lo
        // nombra (ni en su lista ni en sus exclusiones deliberadas): sin esto sobrevive al wipe y la
        // cuenta SIGUIENTE en este device NO ve la pantalla de consent (`GroupBackendInviteEntryLogic
        // .nextStep`, `GroupCreateRoutingLogic`, `GroupJoinReconciler`) — y el canal de Grupos, gateado
        // POR consent, subiría sus grupos, gastos y liquidaciones bajo un `user_id` que jamás
        // consintió. Era el ÚNICO superviviente del
        // trío de superficies de Grupos: `PendingJoinStore`/`GroupJoinIntentTracker` mueren en el
        // `resetPrefs()` de abajo (vía `AppRouter.resetAll`).
        //
        // AQUÍ y no in-session en `CloudSessionSignOut` — POR QUÉ SIGUE SIENDO CIERTO, con otra razón desde
        // C1. La original era el reparto de `PreferenceSyncService.remove`: el consent viajaba por el canal
        // de prefs, así que en el coordinador (modo persistido aún `.cloud`) el clear encolaba un `.int(0)`
        // que, sin tombstone en el wire, pisaba por LWW el registro GDPR de una cuenta VIVA. **Ese riesgo
        // MURIÓ en C1**: el consent ya no es una `PrefSyncKey`, `GroupsConsentState.clear()` es local puro
        // en las tres ramas, y el grant de `groups_consents` no tiene `delete` ⇒ ningún camino del cliente
        // puede alcanzar el registro de la cuenta. Lo que NO ha cambiado es la razón de producto: el device
        // olvida y la CUENTA recuerda, así que al re-entrar el propio dueño no vuelve a ver la pantalla
        // (ahora lo devuelve `groups_consent_state()` en vez del pull de prefs). La posición entre
        // `write(.icloud)` y `resetPrefs()` se conserva —`modeAtClear` en `SignOutWipeHookTests` la pinnea
        // desde DENTRO de la closure— porque sigue siendo la que hace el camino byte-idéntico y no cuesta
        // nada; simplemente ya no es lo que impide el daño.
        //
        // ANTES de `resetPrefs()` y no después, aunque el consent sea local: el gate de abajo LEE lo que
        // ese reset podría barrer. Hoy `removeUserPreferenceKeys` no lo nombra, pero añadirlo allí es el
        // movimiento "natural" para quien quiera que el device olvide — y con el clear detrás el gate
        // dejaría de dispararse en silencio. Delante, ambas capas son correctas y el barrido posterior
        // sería un no-op redundante.
        //
        // Gate por PRESENCIA del consent local y no por `signOutWipeIncludesGroups`: sin canal nunca se
        // escribe ⇒ la closure JAMÁS se invoca ⇒ byte-identidad literal. Cubre las DOS formas —el snapshot
        // sellado de C1 y las dos keys del formato anterior, que un device que no haya vuelto a aceptar
        // desde la actualización sigue teniendo— porque comprobar solo la nueva dejaría fuera exactamente a
        // quien lleva más tiempo con el consent puesto.
        //
        // DESPUÉS del guard abort-S3 por el mismo racional que las notificaciones y las colas: si el
        // store sobrevive, el consent de esa sesión sigue siendo legítimo.
        if GroupsConsentState.hasLocalRecord(in: defaults) {
            clearGroupsConsent()
        }

        resetPrefs()

        // **La invitación que este borrado acaba de matar, repuesta.** Va PEGADA a `resetPrefs()` y
        // DESPUÉS, porque es ése quien la mata: `resetForSignOutWipe` → `resetAllUserPreferences` →
        // `AppRouter.resetAll()` → `PendingJoinStore.clearAll()`. Delante sería un no-op silencioso.
        //
        // **Qué vuelve y qué no.** Solo el par `{groupID, token}` que la puerta del invitado guardó en su
        // key one-shot antes de armar el cierre — sin PII, sin el nombre tecleado y sin la credencial de
        // re-bind. Y **solo si esa key existe**, que la escribe una única pantalla: para todos los demás
        // cierres de sesión esta línea es un no-op, así que el camino de la nube y el de solo-grupos
        // siguen siendo byte-idénticos.
        //
        // Sin esto el invitado reabre la app SIN su invitación: el camino muerto, movido un paso más
        // adelante — le habríamos pedido que borrara el teléfono para unirse a un grupo al que ya no
        // puede unirse.
        restoreDeferredInvite()

        // §5.2.1: las notificaciones locales de la cuenta saliente quedan HUÉRFANAS al morir sus filas
        // `NotificationItem` con el archivo del store — y nadie las mata después: el reconciler de boot
        // (`AppBootstrapper.ensureNotificationsScheduled`) solo REPROGRAMA, y su guard exige
        // `!activeItems.isEmpty`, que post-wipe es falso ⇒ los requests repetitivos sonarían PARA SIEMPRE
        // con datos de la cuenta anterior.
        //
        // Barrido TOTAL (pending + delivered), no selectivo. Las PROGRAMADAS son todas de ámbito cuenta:
        // el único emisor de la app es `NotificationService` y los únicos requests con vida larga derivan
        // de filas `NotificationItem` del store personal que este wipe destruye (los de grupos son
        // one-shots de 1 s). Las ENTREGADAS incluyen también banners del dominio Grupos, cuyo store
        // SOBREVIVE mientras `signOutWipeIncludesGroups` sea falso — se retiran igualmente A PROPÓSITO:
        // este camino devuelve el device a "recién instalado" (Welcome, prefs y onboarding reseteados
        // arriba), y dejar banners con montos de grupos de la sesión cerrada contradiría esa semántica.
        cancelNotifications()
        CloudSyncBreadcrumb.signOutNotificationsCleared()

        // Colas de ENTRADA del App Group (Apple Pay / Siri / imágenes compartidas) + el snapshot de
        // contexto de Siri. El App Group NO muere con los archivos del store: sobrevive al wipe y la
        // cuenta SIGUIENTE drenaría esas colas contra su store recién montado
        // (`ApplePayDraftService`/`SiriDraftService` no distinguen owner) creando borradores con los
        // montos y comercios de la cuenta que acaba de cerrar sesión. Corre PRE-MOUNT: nadie ha
        // drenado nada todavía en este lanzamiento.
        //
        // DESPUÉS del guard abort-S3 por el mismo racional que la cancelación de notificaciones: si el
        // archivo BASE no se pudo borrar, el store sobrevive y esas colas siguen siendo SUYAS.
        purgeInboundSurfaces()

        // #37 (A3 del review): retirar los sentinels del drenaje iKV→outbox — `removeUserPreferenceKeys`
        // EXCLUYE `cloudSync.*` a propósito (los gestiona este boot-hook en el orden kill-safe). Sin
        // esto, un migrar → sign-out `.cloud` → borrado de cuenta → RE-migración como líder haría skip
        // del drenaje (la misma clase de H3/reversa). Idempotente; el arm se desarma DESPUÉS.
        for key in PrefsCutoverDrain.sentinelKeys(
            in: Array(defaults.dictionaryRepresentation().keys)
        ) {
            defaults.removeObject(forKey: key)
        }

        StorageModePersistence.clearSignOutWipeIncludesGroups(defaults)
        // El sobre ya repuesto se retira AQUÍ, con el resto de lo one-shot, y no en la reposición de
        // arriba. Consumirlo allí rompía el orden kill-safe que este hook declara: un kill entre la
        // reposición y esta línea deja el arm puesto, el arranque siguiente re-ejecuta el borrado ENTERO
        // —`resetPrefs()` incluido, que vuelve a vaciar `PendingJoinStore`— y la reposición ya no tendría
        // nada que reponer. El destructor se re-ejecuta; el reparador tiene que poder re-ejecutarse
        // también.
        clearDeferredInvite()
        StorageModePersistence.clearSignOutWipeArm(defaults)
        CloudSyncBreadcrumb.signOutWipeExecuted()
    }

    // MARK: - Sign-out solo-grupos (G5-B) — hook de frontera pre-mount

    /// BOOT-CLEANUP de la salida de una sesión SOLO-GRUPOS (personal `.icloud`, sesión backend viva,
    /// flag `groupsBackendEnabled` ON). Borra SOLO los archivos del store de GRUPOS — NUNCA `YalaModel`
    /// ni `YalaSyncMeta`, NO resetea onboarding ni prefs personales, NO escribe `storageMode` (el device
    /// sigue en `.icloud`). El store de grupos→backend es re-descargable: un archivo nuevo sin History
    /// re-importa del backend al re-iniciar sesión (semántica de reinstalación del canal de grupos).
    ///
    /// Idempotente / kill-safe: el arm se limpia AL FINAL; una re-entrada tras kill re-ejecuta (archivos
    /// ya ausentes = no-op). Un fallo del borrado del archivo BASE conserva el arm → reintento en el
    /// próximo boot; el personal jamás corre riesgo (solo se tocan archivos de grupos).
    ///
    /// NOTIFICACIONES — asimetría DELIBERADA con `performSignOutWipeIfArmed`, NO "arreglar" por simetría:
    /// aquí el store PERSONAL sobrevive y es el dueño de TODAS las notificaciones programadas
    /// (`NotificationItem`), así que un `cancelAllNotifications()` borraría los recordatorios VIVOS del
    /// usuario que no se fue — el bug inverso. Solo se retiran las ENTREGADAS del dominio grupos
    /// (selectivas por deep link), que sí quedan apuntando a un store recién borrado. Las pendientes de
    /// grupos no existen en la práctica: `GroupNotificationService` emite one-shots con trigger de 1 s.
    static func performGroupsOnlySignOutWipeIfArmed() {
        guard !isRunningTests, !isUITesting else { return }
        performGroupsOnlySignOutWipeIfArmed(
            defaults: .standard,
            deleteFiles: { deleteStoreFiles(named: $0, schema: $1) },
            clearDeliveredGroupNotifications: {
                // Best-effort y desacoplado: la lectura de entregadas es async y el boot no debe
                // esperarla. No toca SwiftData — solo el centro de notificaciones del sistema.
                Task { await NotificationService.shared.clearDeliveredGroupNotifications() }
            })
    }

    /// Variante inyectable (tests del ORDEN/idempotencia sin archivos reales; el wrapper de producción
    /// mantiene los guards de test/uitest).
    static func performGroupsOnlySignOutWipeIfArmed(
        defaults: UserDefaults,
        deleteFiles: (String, Schema) -> Bool,
        clearDeliveredGroupNotifications: () -> Void = {}
    ) {
        guard StorageModePersistence.isGroupsOnlyWipeArmed(defaults) else { return }

        guard deleteFiles(groupsDatabaseName, groupsSchema) else {
            CloudSyncBreadcrumb.signOutGroupsOnlyWipeAborted(reason: "groups store file deletion failed")
            return
        }

        clearDeliveredGroupNotifications()

        StorageModePersistence.clearGroupsOnlyWipeArm(defaults)
        CloudSyncBreadcrumb.signOutGroupsOnlyWipeExecuted()
    }

    // MARK: - Retirada de la sesión secundaria (ADR 2026-09-09)

    /// Borra el trío SQLite de un store LEGACY por nombre. Lo consume `SecondarySessionRetirement`, que
    /// es quien sabe qué nombres quedaron en disco: aquí ya no existe ningún tipo que los nombre.
    ///
    /// Usa el schema personal como PORTADOR y no porque los archivos lo tengan: la URL de una
    /// `ModelConfiguration` se compone del nombre, no del schema —lo pinnea
    /// `SecondarySessionRetirementTests.laURLNoDependeDelSchema`— y estos stores ya no tienen un schema
    /// propio al que referirse.
    /// Devuelve `false` **solo** si el archivo base existía y no se pudo borrar: que no exista es éxito,
    /// y es el caso normal. Ese booleano es lo que impide que la retirada se dé por hecha sobre un disco
    /// que todavía guarda el corpus de otra persona.
    @discardableResult
    static func deleteLegacyStoreFiles(named name: String) -> Bool {
        deleteStoreFiles(named: name, schema: personalSchema)
    }

    /// Borra el trío de archivos SQLite de un store (base + -wal + -shm). La URL se deriva de una
    /// ModelConfiguration efímera (misma name+schema ⇒ misma URL) SIN pasar por `personalConfiguration`
    /// para no capturar el testigo `personalStoreMountedDecision` antes del wipe.
    /// Devuelve `false` solo si el archivo BASE no pudo borrarse (≠ no-existe) — los sidecars
    /// -wal/-shm huérfanos sin base son inertes (SQLite los descarta al recrear el store).
    private static func deleteStoreFiles(named name: String, schema: Schema) -> Bool {
        let url = ModelConfiguration(name, schema: schema, cloudKitDatabase: .none).url
        var baseDeleted = true
        for (index, path) in [url.path, url.path + "-wal", url.path + "-shm"].enumerated() {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch let error as NSError
                where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
                // Ya ausente (re-entrada idempotente tras kill a mitad) — no-op.
            } catch {
                #if DEBUG
                print("SwiftDataConfiguration: Error borrando store \(name): \(error)")
                #endif
                if index == 0 { baseDeleted = false }
            }
        }
        return baseDeleted
    }

    // MARK: - Instalación fresca (R2 · el mount neutro)

    /// ¿Existe el archivo BASE del store personal? La URL se deriva de una `ModelConfiguration` efímera
    /// (misma name+schema ⇒ misma URL) SIN pasar por `personalConfiguration`, exactamente por el mismo
    /// motivo que `deleteStoreFiles`: preguntarlo no puede capturar el testigo del mount.
    ///
    /// Se mira SOLO el archivo base. Un `-wal`/`-shm` huérfano sin base es inerte (SQLite los descarta al
    /// recrear el store), así que tratarlo como "hay datos" bloquearía el mount neutro por un residuo.
    private static func personalStoreFileExists() -> Bool {
        let url = ModelConfiguration(databaseName, schema: personalSchema, cloudKitDatabase: .none).url
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Adaptador de producción del predicado puro: lee las cuatro señales del mundo real. Corre PRE-MOUNT,
    /// dentro de `personalConfiguration` y antes de capturar el testigo.
    ///
    /// `hasShownWelcomeChooser` se lee con el literal de la key —igual que hacen los dos wipes de este
    /// mismo fichero— y no vía `AppPreferences`: esto corre en `@main`, antes de que exista ningún
    /// `AppBootstrapper`.
    static func isFreshInstallForNeutralMount(_ defaults: UserDefaults = .standard) -> Bool {
        isFreshInstallForNeutralMount(
            personalStoreFileExists: personalStoreFileExists(),
            persistedMode: StorageModePersistence.read(defaults),
            mirrorOffArmed: StorageModePersistence.isMirrorOffArmed(defaults),
            hasShownWelcomeChooser: defaults.bool(forKey: "hasShownWelcomeChooser"))
    }

    /// R4 · adaptador de producción del NEUTRO DURABLE. Mismo contrato que su hermano: corre PRE-MOUNT y
    /// lee `hasShownWelcomeChooser` con el literal de la key porque esto se evalúa en `@main`, antes de que
    /// exista ningún `AppBootstrapper`.
    static func shouldMountNeutralDurable(_ defaults: UserDefaults = .standard) -> Bool {
        shouldMountNeutralDurable(
            neutralMountArmed: StorageModePersistence.isNeutralMountArmed(defaults),
            hasShownWelcomeChooser: defaults.bool(forKey: "hasShownWelcomeChooser"),
            groupsOnlySessionArmed: StorageModePersistence.isGroupsOnlyNeutralMountArmed(defaults),
            persistedMode: StorageModePersistence.read(defaults),
            mirrorOffArmed: StorageModePersistence.isMirrorOffArmed(defaults))
    }

    // MARK: - Container CloudKit State

    private static let containerCloudKitKey = "containerCreatedWithCloudKit"

    /// Registra si ESTE proceso montó el store personal con el mirror de CloudKit espejando (eje B).
    ///
    /// **R1: recibe la DECISIÓN de mount, no la disponibilidad de iCloud.** Antes se le pasaba
    /// `isICloudAvailable()`, que es una pregunta distinta: dice si HAY cuenta, no qué se montó. Para las
    /// decisiones de hoy las dos formulaciones coinciden en las únicas celdas que su lector puede
    /// alcanzar (`checkForICloudMismatch` corta en `storageMode == .cloud`, así que `cloudMirrorOff` es
    /// inerte), y por eso el cambio es DARK. Deja de coincidir en cuanto exista
    /// un mount SIN mirror con cuenta iCloud disponible —el mount neutro del relanzamiento cero—: ahí la
    /// disponibilidad diría `true` y el aviso quedaría MUDO para siempre, dejando al device sin mirror y sin
    /// forma de enterarse.
    ///
    /// En los hosts de TEST y de UITEST `personalConfiguration` retorna ANTES de capturar el testigo, así
    /// que aquí se registra su default (`.iCloudMirror` ⇒ `true`) donde antes se registraba la
    /// disponibilidad del simulador (`false`). Es inocuo y se auto-cura: el único lector exige además
    /// `isICloudAvailable()`, que en el simulador es `false` en los dos casos, y el primer arranque REAL de
    /// esa app re-escribe la key con su decisión de verdad. Se anota porque los dos hosts del scheme
    /// comparten `UserDefaults.standard` (ver `.claude/rules/testing.md`) y una key que cambia de valor
    /// entre corridas merece estar dicha.
    ///
    /// La ventana que este cambio SÍ abría —montar `.cloudMirrorOff` y persistir `.icloud` en caliente, que
    /// es lo que hace la reversa— queda CERRADA por el término R9 del aviso, que decide por el MOUNT y no
    /// por el modo de ahora: ver `PersonalStoreDecision.isCloudModeMount`. No se documentó como residual
    /// aceptable porque la acotación que lo habría justificado era falsa: el lector no depende de
    /// `NSUbiquityIdentityDidChange`, corre en cada vuelta a primer plano.
    static func markContainerCloudKitState(decision: PersonalStoreDecision,
                                           defaults: UserDefaults = .standard) {
        defaults.set(decision.mirrorsToICloud, forKey: containerCloudKitKey)
    }

    static func containerWasCreatedWithCloudKit(_ defaults: UserDefaults = .standard) -> Bool {
        // Si la key nunca fue escrita, asumir true (usuario existente pre-update)
        guard defaults.object(forKey: containerCloudKitKey) != nil else { return true }
        return defaults.bool(forKey: containerCloudKitKey)
    }

    /// El predicado PURO del aviso «monté sin CloudKit y ahora hay iCloud» (§1.3 del spec del relanzamiento
    /// cero), consumido por `AppBootstrapper.checkForICloudMismatch`. Extraído para poder pinnearlo: hasta
    /// R1 este aviso no tenía ni un test, y es el único lector del testigo durable.
    ///
    /// **Los DOS inputs son testigos de mount, y ninguno es el modo de ahora.** El término R9 (I10-wiring
    /// w6) —en modo nube el store personal ya NO lo espeja el mirror, así que tener cuenta iCloud, que
    /// Grupos usa, no es un mismatch— se decide por `mountedDecision.isCloudModeMount` y no por
    /// `CloudSyncFlags.storageMode`, que es lo que leía el guard antes de R1. Los dos coinciden salvo
    /// mientras el modo cambia EN CALIENTE sin remontar, que es exactamente lo que hace la reversa; ahí el
    /// modo de ahora dice `.icloud` sobre un proceso montado en modo nube y el aviso saldría de más. Ver
    /// el docblock de `isCloudModeMount`.
    /// **Y un TERCER término desde el paso 5 del rediseño: una sesión solo-grupos no está «sin iCloud por
    /// accidente», lo está a propósito.** El aviso nace de asumir que un mount sin espejo dura UN arranque
    /// (el neutro de R2/R4 caduca), así que ofrecer «reabre la app» tenía sentido: al reabrir se arregla.
    /// El neutro de solo-grupos no caduca —esa es su razón de ser— de modo que sin este término la persona
    /// recibe el aviso **en cada arranque en frío** y reabrir no cambia nada: un nag perpetuo que además le
    /// propone justamente lo que el ADR §2-3 dice que no debe pasarle (bajar el iCloud del Apple ID).
    /// Se pregunta por la MARCA y no por el mount, porque `.neutralNoMirror` también lo produce una
    /// instalación fresca, donde el aviso sí es correcto.
    static func shouldOfferICloudRestart(mountedDecision: PersonalStoreDecision,
                                         mountedWithMirroring: Bool,
                                         iCloudAvailableNow: Bool,
                                         groupsOnlySessionArmed: Bool) -> Bool {
        guard !mountedDecision.isCloudModeMount else { return false }
        guard !groupsOnlySessionArmed else { return false }
        return !mountedWithMirroring && iCloudAvailableNow
    }

    /// Personal data — CloudKit synced (same databaseName = same SQLite file).
    static var personalConfiguration: ModelConfiguration {
        if isRunningTests {
            // `cloudKitDatabase: .none` es CRÍTICO: por default ModelConfiguration usa
            // `.automatic`, que hace que SwiftData adjunte NSPersistentCloudKitContainer
            // incluso a stores in-memory (la app tiene entitlement CloudKit + schema con
            // relaciones). En sims SIN cuenta iCloud (CI) ese mirror entra en loop de
            // recoverFromError (CKAccountStatusNoAccount / "store removed from coordinator")
            // que desestabiliza el proceso de test → 0 tests + restart loop, aunque las
            // aserciones pasen. `.none` lo desactiva de raíz. Ver TESTING-STRATEGY.md.
            return ModelConfiguration("YalaPersonal", schema: personalSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        if isUITesting {
            return ModelConfiguration("YalaModel-UITest", schema: personalSchema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        }
        // I10-wiring w6: rama `.cloud` ANTES del check de iCloud (mirror OFF sobre el MISMO archivo de
        // store, patrón device-validado por el spike S6 — harness retirado al cerrar I11), gateada
        // ADEMÁS por el flag mirror-off-ARMADO (SERIO 1 — ver doc de
        // `personalStoreDecision`). DARK: nadie escribe `storageMode=.cloud` ni arma el flag en
        // producción hasta que el cutover de una migración real ejecute sus pasos.
        // R2: el término `freshInstall`. Se evalúa ANTES de capturar el testigo y sin construir ningún
        // container (la URL sale de una `ModelConfiguration` efímera, patrón `deleteStoreFiles`).
        let decision = personalStoreDecision(
            storageMode: CloudSyncFlags.storageMode,
            mirrorOffArmed: StorageModePersistence.isMirrorOffArmed(),
            iCloudAvailable: isICloudAvailable(),
            freshInstall: isFreshInstallForNeutralMount(),
            neutralDurable: shouldMountNeutralDurable())
        capturePersonalStoreMountedDecisionOnce(decision)
        switch decision {
        case .cloudMirrorOff:
            return ModelConfiguration(databaseName, schema: personalSchema, cloudKitDatabase: .none)
        case .neutralNoMirror:
            // R2 · `.none` EXPLÍCITO. Omitirlo cae en `.automatic`, que la auditoría R1(c) MIDIÓ que
            // adjunta el mirror igual (mismos eventos de `NSPersistentCloudKitContainer` que `.private`,
            // mientras `.none` emite cero) ⇒ sería el mount CONTRARIO al que este caso declara, y el alta
            // nube volvería a necesitar el relanzamiento que el chip existe para quitar.
            return ModelConfiguration(databaseName, schema: personalSchema, cloudKitDatabase: .none)
        case .iCloudMirror:
            return ModelConfiguration(
                databaseName,
                schema: personalSchema,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        case .localNoMirror:
            return ModelConfiguration(databaseName, schema: personalSchema)
        }
    }

    /// Group data — local only (CKSyncEngine syncs via groups container).
    static var groupsConfiguration: ModelConfiguration {
        if isRunningTests {
            // Ver nota en personalConfiguration: `.none` evita el mirror CloudKit en
            // el store in-memory (crash loop en sims sin cuenta iCloud / CI).
            return ModelConfiguration("YalaGroups", schema: groupsSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        if isUITesting {
            return ModelConfiguration("YalaGroups-UITest", schema: groupsSchema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        }
        // `cloudKitDatabase: .none` es CRÍTICO en producción. El default de
        // ModelConfiguration es `.automatic`, que adjunta NSPersistentCloudKitContainer
        // al container PRIMARIO del entitlement (`iCloud.com.jurgenschmidt.yala`, el
        // personal) — NO al container de grupos. Sin `.none` se crea un segundo canal de
        // sync redundante (record types `CD_Split*` en la private DB personal) que duplica
        // los datos del grupo y compite con el CKSyncEngine manual (filas SplitGroup
        // duplicadas por mismo `cloudKitZoneID`, resurrección de borrados, doble cuota).
        // Grupos sincroniza SOLO vía CKSyncEngine en `iCloud.com.jurgenschmidt.yala.groups`
        // (ver Services/Groups/). Espeja la decisión de las ramas de test/UITest de arriba.
        return ModelConfiguration(groupsDatabaseName, schema: groupsSchema, cloudKitDatabase: .none)
    }

    /// Database name for groups store, derived from personal databaseName.
    static var groupsDatabaseName: String {
        databaseName.replacing("YalaModel", with: "YalaGroups")
    }

    /// Sync-meta store (Modo Nube, I2) — `SyncIdentity` local, NUNCA CloudKit.
    /// `cloudKitDatabase: .none` SIEMPRE: es metadata por-dispositivo (mapping identidad↔ancla↔
    /// record) que se reconstruye localmente y no debe espejarse. Store propio (URL separada, mismo
    /// directorio que personal/grupos), espejando el patrón de `groupsConfiguration`.
    static var syncMetaConfiguration: ModelConfiguration {
        if isRunningTests {
            return ModelConfiguration("YalaSyncMeta", schema: syncMetaSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        if isUITesting {
            return ModelConfiguration("YalaSyncMeta-UITest", schema: syncMetaSchema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        }
        return ModelConfiguration(syncMetaDatabaseName, schema: syncMetaSchema, cloudKitDatabase: .none)
    }

    /// Database name for the sync-meta store, derived from personal databaseName.
    static var syncMetaDatabaseName: String {
        databaseName.replacing("YalaModel", with: "YalaSyncMeta")
    }
}
