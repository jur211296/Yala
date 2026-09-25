//
//  MigrationWorkExecutor.swift
//  Yala
//
//  Ejecutor REAL del seam `MigrationWorkExecuting` (Modo Nube Fase 4, I10-wiring ciclo B). Implementa el
//  trabajo por fase que el `MigrationRunner` orquesta: claim / identidad / snapshot / verify + el faro KV,
//  reusando los componentes ya probados del motor (engine, push/pull/merkle clients, account client). w6
//  cableó el CUTOVER (§g.4): `confirmCutoverServer`/`persistLocalMode` + los efectos
//  `startParallelHistoryCapture`/`writeCloudKitMarker`/`disableMirrorAndRelaunch`/
//  `runLeaderReconcileFromFrozenCloudKit` + los testigos `isMirrorConfirmedOff`/`isMarkerExported`. El
//  BACKSTOP corre en `runLeaderReconcileFromFrozenCloudKit`. I11-2 cableó los efectos LOCALES de la
//  reversa (§h); I11-3 cableó su server-side (`performReverseClaim`/`freezeBackendForReverse`/
//  `completeReverseServer`/`reverseRollback` → acciones `reverse_*` del RPC `migration_progress`). Solo
//  `adoptBackendAccount` (§k.4) sigue `notWired` (el runner lo deja journaled, retomable).
//
//  DARK: nada de producción instancia este executor (el runner no se instancia; la UI de migración es I14,
//  el panel DEBUG w7). Solo lo ejercitan los tests del ciclo + el e2e staging.
//
//  `@MainActor`: manipula red/identidad/ModelContext (regla inviolable del repo).
//

import CloudKit
import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Error del executor cuando un efecto/paso aún no está cableado (w6/w8). El runner lo trata como un efecto
/// que lanza → lo deja journaled (retomable). `nonisolated` (lo compara la lógica pura de tests).
nonisolated enum MigrationExecutorError: Error, Equatable {
    case notWired(effect: String)
    /// Condición TRANSITORIA de un efecto YA cableado (I14, M2 del review): "reintentar en el próximo
    /// resume" (quiescencia no alcanzada, red del reconcile). Mismo tratamiento del runner que `notWired`
    /// (throw → journaled retomable), pero el log no miente diciendo que falta wiring.
    case adoptRetry(reason: String)
    /// El `fetch` de `SyncOutbox` lanzó (ticket `verify-reads-a-failed-local-fetch-as-an-empty-outbox`). No se
    /// deja escapar el error de SwiftData tal cual: que tenga un caso PROPIO es lo que permite a cada llamador
    /// distinguir «no pude leer la cola» de cualquier otro fallo, y a un test afirmarlo sin mirar un string.
    case outboxUnreadable
    /// El `fetch` de una tabla de un inventario de la migración lanzó (ticket
    /// `an-incomplete-inventory-reads-as-the-whole-corpus`): snapshot, captura de identidad, adopt o muestra de la
    /// vuelta. `entity` = nombre de clase. Hasta ese ticket esa tabla se saltaba y el inventario parcial se leía como
    /// el corpus entero.
    case inventoryUnreadable(entity: String)
    /// El reconcile de huérfanas del adopt no pudo leer o escribir la base LOCAL (ticket
    /// `adopt-effect-retries-forever-with-no-ceiling`). Esperar no lo arregla, y por eso tiene caso propio y no va dentro de
    /// `adoptRetry`: el runner lo cuenta para el techo CORTO del efecto (15 min), y la red y la quiescencia para el largo.
    case adoptLocalFailure
    /// El reconcile tenía filas que subir y este dispositivo no demuestra que su corpus descienda de la cuenta: no hay
    /// `CloudMigrationMarker` de ESA cuenta en el store local ni ninguna fila viva suya (tickets
    /// `adopt-uploads-a-foreign-corpus-without-a-lineage-check` y `adopt-after-the-cutover-needs-a-marker-the-leader-never-exported`).
    /// Caso propio por lo mismo que `adoptLocalFailure`: esperar no arregla un corpus ajeno, así que cuenta para el techo
    /// CORTO. La espera legítima —el marcador que aún se importa— la para antes la quiescencia, que es `adoptRetry`.
    case adoptLineageUnproven
}

// MARK: - AdoptReconcileOutcome (DIFERIDOS #30, mecanismo v1 DARK)

/// Resultado de `runAdoptOrphanReconcile()`. `nonisolated` (lo compara la lógica de tests). Idempotente:
/// una 2ª pasada encuentra las ex-huérfanas ya en el backend → `completed(0, 0)`.
nonisolated enum AdoptReconcileOutcome: Equatable {
    /// El diff corrió y (si había) subió las huérfanas. `uploaded` = filas aplicadas server-side;
    /// `identityAssigned` = filas sin syncID a las que el backfill acuñó identidad fresca.
    case completed(uploaded: Int, identityAssigned: Int)
    /// Guard defensivo anti mass-upload: la enumeración del backend llegó VACÍA teniendo huérfanas locales
    /// → NO se sube nada (un adopt legítimo implica backend POBLADO; enumeración vacía = página espuria/bug).
    case abortedEmptyBackend
    /// Red caída en la enumeración, el Merkle o el push, o la deriva del reloj al encolar → retomable (el re-run re-diffea;
    /// lo ya aplicado sale del diff). Esperar lo puede arreglar: techo LARGO del efecto.
    case transient
    /// La base LOCAL no se dejó leer o escribir: el inventario, el backfill, el fetch de las huérfanas, su encolado o el
    /// outbox. Retomable igual que `transient`, pero esperar NO lo arregla (ticket `adopt-effect-retries-forever-with-no-ceiling`;
    /// hasta ese ticket iba dentro de `transient` y el efecto lo reintentaba para siempre).
    case localFailure
    /// Había filas que subir y el store local no demuestra que espeje el corpus de ESTA cuenta: ni tiene su marcador
    /// (`CloudMigrationMarker` con su `accountHash`) ni ninguna de sus filas vivas (tickets
    /// `adopt-uploads-a-foreign-corpus-without-a-lineage-check` y `adopt-after-the-cutover-needs-a-marker-the-leader-never-exported`).
    /// No se toca nada: ni backfill, ni encolado, ni red.
    case lineageUnproven
}

// MARK: - ForwardLineageOutcome (ticket `migration-takeover-uploads-without-a-lineage-check`)

/// Resultado de `checkForwardLineage()`: ¿puede este dispositivo subir su corpus a una cuenta que ya recibió datos
/// personales? Es la pregunta del relevo de un líder callado —`claim_account` le da el turno (`created`) sobre lo que el
/// otro alcanzó a subir—, y la contesta el solape de identidades entre el backend y el store local. `nonisolated` (lo
/// compara la lógica de tests).
nonisolated enum ForwardLineageOutcome: Equatable {
    /// Alguna fila VIVA del backend está en el store local, con su tabla y su identidad: este corpus desciende del que
    /// ya se subió (el mismo iCloud, o el mismo teléfono). `sharedRows` = cuántas, solo para el rastro.
    case proven(sharedRows: Int)
    /// El backend no tiene filas personales vivas (fuera de `exchange_rates`): no hay nada con que mezclar.
    case noLivePersonalRows
    /// El backend tiene filas personales vivas y ninguna está aquí: el corpus es otro. No se toca nada.
    case unproven(liveRows: Int)
    /// Comparte filas con la cuenta —es el mismo iCloud—, pero a `table`, que tiene algo que subir, le faltan `missing`
    /// filas vivas del backend: las identidades que el líder callado asignó y subió no llegaron aquí por iCloud (ticket
    /// `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived`). Subir ahora acuñaría identidades
    /// frescas a esas mismas filas y el servidor, que solo deduplica por identidad, guardaría el libro dos veces. No se
    /// toca nada; esperar a que iCloud las traiga lo arregla.
    case accountRowsMissing(table: String, missing: Int)
    /// Red, sesión o una enumeración que el Merkle no da por completa: esperar lo puede arreglar.
    case transient
    /// El inventario local no se dejó leer: nunca «probado» ni «sin datos».
    case localFailure
}

// MARK: - ReverseTombstoneSource (§h.3, I11-2)

/// Fuente GENÉRICA de páginas de deltas en LECTURA PURA: NO aplica (`applyPage`), NO avanza `SyncCursor`, NO
/// toca testigos `SyncIdentity` — el apply normal BORRA el testigo al aplicar un tombstone y aquí NO queremos
/// ese side-effect. Consumida por el barrido de zombies de la reversa (§h.3 — enumera tombstones) Y por la
/// reconciliación de huérfanas del adopt (DIFERIDOS #30 — enumera TODAS las identidades que el backend
/// conoce, upserts Y tombstones). Default = wrapper del `pullClient`; los tests la fakean para el golden §h.5
/// (no se protocoliza `SyncPullClient` entero).
@MainActor
protocol ReverseTombstoneSource: AnyObject {
    /// Baja UNA página de deltas desde `since` (reusa el `PullOutcome` del pull).
    func pullPage(since: Int64, limit: Int) async -> PullOutcome
}

extension SyncPullClient: ReverseTombstoneSource {
    func pullPage(since: Int64, limit: Int) async -> PullOutcome { await pull(since: since, limit: limit) }
}

// MARK: - ReverseEligibility (guardarraíl §h.6-A1, obligación 1 del review)

/// Guardarraíl PURO que el panel (I11-5) consulta ANTES de emitir `reverseActivated`. `nonisolated`: lógica
/// pura sin `ModelContext`/red/`Date`.
///
/// `hasCKMap` = existe ≥1 `SyncIdentity` con `ckRecordName != nil`. **De qué protege, medido el 2026-09-10:**
/// de la RESURRECCIÓN de borrados. Durante la época nube el mirror está apagado, así que lo que el usuario
/// borra desaparece del SQLite local pero NO de su zona CloudKit; al remontar el mirror, esos records
/// re-importan filas muertas. El mapa es la señal de que el corpus fue capturado con el mirror vivo, o sea
/// de que esta cuenta **tuvo** copia en CloudKit.
///
/// `isBornCloud` es lo que faltaba, y es lo que separa dos poblaciones que `hasCKMap` metía en el mismo
/// saco: el **migrado sin mapa** (tiene zona CloudKit y no sabe dónde está: sigue excluido, el riesgo es
/// real) y el **born-cloud** (nunca tuvo zona, así que no hay nada que pueda resucitar). Hasta el
/// 2026-09-10 el born-cloud quedaba fuera por arrastre — y tras el fresh start de ese día eso era todo el
/// mundo, con la fila E de la matriz prometiendo un camino que nadie podía recorrer.
///
/// **La señal es POSITIVA a propósito, y ese matiz es todo el diseño.** Es
/// `StorageModePersistence.isBornCloud`, que solo escribe el alta born-cloud de este dispositivo. La
/// tentación era derivarla de la AUSENCIA del `CloudMigrationMarker` —«no hay marcador ⇒ no migró»—, y
/// **medido el 2026-09-10 eso falla ABIERTO**: el marcador falta también en un 2.º device adoptado cuyo
/// marcador no llegó por el mirror (`adoptBackendAccount` lo registra en un breadcrumb y sigue: «ausente =
/// no bloquea») y lo borra un botón del panel DEBUG pensado para limpiar marcadores stale. En los dos
/// casos, un migrado habría pasado por born-cloud y el guardarraíl se habría abierto justo para la
/// población que protege. Con la marca positiva, lo que no se sabe se comporta **como antes**: se exige el
/// mapa. El precio es un falso negativo conservador —un born-cloud que entra en un SEGUNDO dispositivo no
/// verá el botón—, con ticket propio.
///
/// El canario `cloudReverseDegradedNoMap` que este docblock prometía **no lo emite nadie** (medido: cero
/// llamadores en `Yala/`, y no es ni un caso de `MetricsCanary`); no se añade aquí para no ampliar el
/// alcance → anotado en `canarios-y-breadcrumbs-sin-emisor`.
nonisolated enum ReverseEligibility {
    enum Decision: Equatable {
        case eligible
        /// El device NO está en modo nube (`storageMode != .cloud`) → la reversa no aplica.
        case notCloudMode
        /// Modo nube, sin mapa de coordenadas CloudKit y sin constancia de haber nacido en la nube aquí →
        /// NO elegible (resurrección de borrados). Un born-cloud **de este dispositivo** no cae aquí.
        case degradedNoMap
        /// Ya en un terminal de la reversa (`icloudActive`/`reverseFailedRollback`) → nada que revertir.
        case reverseAlreadyTerminal
        /// Modo nube, sin constancia de haber nacido en la nube aquí, y los testigos del mapa no se dejaron contar
        /// (ticket `an-unreadable-migration-journal-reads-as-never-started`) → NO elegible AHORA: no se concede la vuelta
        /// con un dato que no se leyó. No es `degradedNoMap`: el mapa puede existir, y la pantalla lo vuelve a mirar.
        case mapUnreadable
    }

    /// - Parameter hasCKMap: `nil` = los testigos con `ckRecordName` no se dejaron contar.
    static func decide(
        storageMode: StorageMode,
        hasCKMap: Bool?,
        isBornCloud: Bool,
        journaledPhase: MigrationPhase
    ) -> Decision {
        guard storageMode == .cloud else { return .notCloudMode }
        switch journaledPhase {
        case .icloudActive, .reverseFailedRollback:
            return .reverseAlreadyTerminal
        default:
            break
        }
        // El mapa se exige salvo que sepamos que la cuenta nació en la nube AQUÍ. Sin zona CloudKit previa
        // no hay resurrección posible: el mirror que se monta al revertir SUBE, no baja.
        // Un born-cloud de este dispositivo no necesita el mapa, así que tampoco necesita haberlo leído.
        if isBornCloud { return .eligible }
        guard let hasCKMap else { return .mapUnreadable }
        return hasCKMap ? .eligible : .degradedNoMap
    }
}

@MainActor
final class MigrationWorkExecutor: MigrationWorkExecuting {

    private let engine: CloudSyncEngine
    private let pushClient: SyncPushClient
    private let pullClient: SyncPullClient
    private let merkleClient: SyncMerkleClient
    private let accountClient: CloudAccountClient
    private let session: CloudSyncSessionProviding
    private let context: ModelContext
    private let calendar: Calendar
    private let now: () -> Date
    private let deviceID: String
    /// Provider de la sesión, leído VIVO en cada uso (I4 sesión 3 Google Sign-In, ajuste A1 del
    /// /review-plan): el runner/executor puede nacer ANTES del sign-in (boot/intento previo) — un String
    /// congelado en el init claimearía `"apple"` con sesión Google (`profiles.provider` mal estampado en
    /// un `created`) Y estamparía el FARO con el provider equivocado (la red R9 de sesión 2 mostraría el
    /// método de sign-in incorrecto). Lectores auditados: `performClaim` (body del claim) y
    /// `execute(.writeBeacon)` (faro) — ambos invocan el closure en el momento de uso.
    private let provider: @MainActor () -> String
    private let beacon: CloudBeacon
    private let personalStoreURL: URL
    /// El registro fila → identidad que `assignIdentity` siembra y el drain lee para traducir el tombstone de una fila que el
    /// espejo re-identificó (`RelayIdentityLedger`). El motor lo lee de SU `relayIdentityLedgerURL`: en producción los dos
    /// son `RelayIdentityLedger.defaultURL`.
    private let relayIdentityLedgerURL: URL

    /// A partir de la N-ésima llamada (1-based), `liveOutboxRows()` LANZA — monta «la base local no se deja leer»
    /// sin tocar el store. `ModelContext` es una `final class` de SwiftData sin protocolo detrás, así que no hay
    /// doble que inyectar; el molde es `CloudSyncEngine._testThrowOnTokenHistoryFetch` y sus tres hermanos.
    ///
    /// **Es un contador y no un `Bool` porque `verify()` lee el outbox DOS veces** y las dos lecturas tienen
    /// desenlaces distintos que arreglar: la de antes del push se saltaba el push, y la de después devolvía
    /// `.newDeltaDetected`, que no consume reintento. Con un `Bool` la segunda es inalcanzable —la primera corta
    /// antes— y su rama quedaría sin medir. SOLO tests.
    var _testOutboxFetchThrowsFromCall: Int?
    private var _testOutboxFetchCount = 0
    /// `(paso, entidad) -> ¿lanza?` para cada `fetch` de inventario: captura de identidad, adopt, muestra de la vuelta y
    /// canario de metadata huérfana (`step` = el de `migrationInventoryReadFailed`, `entity` = nombre de clase). Es un
    /// closure y no un `Bool` ni un conjunto por lo mismo que el contador de arriba: el adopt lee su inventario DOS
    /// veces con el mismo paso —antes y después del backfill— y cada lectura tiene su desenlace; con un conjunto la
    /// primera corta y la segunda no se mide. Lanza un `CocoaError`, no el error propio, para que el test solo pase si
    /// el `catch` real lo convierte (ticket `an-incomplete-inventory-reads-as-the-whole-corpus`). SOLO tests.
    var _testInventoryFetchThrows: ((_ step: String, _ entity: String) -> Bool)?
    /// El error que lanza el encolado de las huérfanas del adopt en vez de encolarlas. Va DENTRO del `do` real, molde de
    /// `MigrationSnapshotUploader._testEnqueueError`: el test solo pasa si el `catch` separa la deriva del reloj de la base
    /// local (ticket `adopt-effect-retries-forever-with-no-ceiling`). SOLO tests.
    var _testAdoptEnqueueError: Error?
    private let uploader: MigrationSnapshotUploader
    /// Fuente de tombstones para el barrido de zombies (§h.3). Default = `pullClient`; inyectable para el
    /// golden §h.5 (enumeración PURA, sin applyPage/cursor/testigos).
    private let tombstoneSource: ReverseTombstoneSource
    /// UserDefaults para persistir `storageMode=.cloud` (paso 2) y el flag `relaunchRequested` (paso 4).
    /// Inyectable para tests (nunca `.standard` directo en tests — regla del repo).
    private let storageDefaults: UserDefaults
    /// Ventana mínima entre heartbeats del lease (I14-pre). El runner llama `sendLeaseHeartbeatIfDue()` por
    /// PROGRESO en la vuelta a iCloud (drenaje, `reverseUpload`); este throttle lo capa a 1 request/ventana. Es también lo
    /// que dura una confirmación de la puerta de la ida (`confirmMigrationLease`), que pregunta antes de cada página.
    private let heartbeatInterval: TimeInterval
    /// Señal de quiescencia del import CloudKit para el flujo de ADOPT (#30, I14). El adopt persiste `.cloud`
    /// sobre un store que se está importando → DEBE correr solo con el import asentado (contrato de
    /// `runAdoptOrphanReconcile`). Default `{ true }` (fakes/tests que no lo ejercitan); producción inyecta
    /// `{ iCloudSyncService.shared.isImportQuiescent }`.
    private let adoptQuiescenceSignal: () -> Bool
    /// C-1: ¿hay cuenta iCloud? El MISMO predicado que gobierna el montaje del store
    /// (`SwiftDataConfiguration.isICloudAvailable()`), a propósito — introducir aquí
    /// `CKContainer.accountStatus()` (0 usos en el repo) crearía una segunda verdad que podría discrepar del
    /// predicado que de verdad decide si existe un mirror por el que exportar. Inyectable para tests.
    private let icloudAccountPresent: @MainActor () -> Bool
    /// C-1: último `CKError.Code` observado por el mirror (`iCloudSyncService.lastExportError`). Post-hoc y en
    /// memoria: `nil` tras un boot fresco, por eso el tope por tiempo del paso 4 es la red de seguridad y esto
    /// solo un acelerador. Inyectable para tests (nunca el singleton en el cuerpo — regla del repo).
    private let icloudLastExportErrorCode: @MainActor () -> CKError.Code?
    /// Techo de `reverseUpload`: ¿CloudKit dijo `notAuthenticated`? (`iCloudSyncService.mirrorReportedNotAuthenticated`).
    /// Hace falta aparte de `icloudLastExportErrorCode` porque `iCloudSyncService.apply` sale antes de guardar ese
    /// código en `lastExportError`. Inyectable para tests.
    private let icloudMirrorReportedNotAuthenticated: @MainActor () -> Bool
    /// Techo de `reverseUpload`: la fecha del último error de export (`iCloudSyncService.lastExportErrorAt`) y la del
    /// último export con éxito (`lastSuccessfulExportDate`). Sin ellas un error ya resuelto seguiría mandando: el
    /// latch no se limpia con un éxito. Inyectables para tests.
    private let icloudLastExportErrorAt: @MainActor () -> Date?
    private let icloudLastSuccessfulExportAt: @MainActor () -> Date?
    /// Persistencia del `AuthAction` resuelto (P6). El `performClaim`/`runAdoptFlow` lo estampan → el gate
    /// de arranque del runtime (`LiveCloudSessionProvider.claimAction`) lo lee. Inyectable para tests.
    private let claimStore: CloudClaimActionStore
    /// El sello que había ANTES del último `performClaim`, para que `discardLastClaimStamp` lo reponga. En memoria: solo
    /// se deshace el claim de la llamada en curso. `nil` = el último claim no selló nada.
    private var lastClaimStampUndo: (userID: String, previous: AccountClaimDecision.AuthAction?)?
    /// `has_personal_writes` del último `performClaim` que contestó `created` (g16_03). `nil` = sin respuesta, otro
    /// desenlace, o un servidor que no lo manda. Lo lee el runner para journalear si la identidad tiene que comprobar el
    /// linaje (ticket `migration-takeover-uploads-without-a-lineage-check`).
    private var lastClaimPersonalWrites: Bool?
    /// Instante del último heartbeat EMITIDO (I14-pre). IN-MEMORY, NO journaled: un kill+resume lo resetea →
    /// a lo sumo UN heartbeat extra por relanzamiento (idempotente, 1 request). Se arma también en rechazo/red
    /// para no martillar el endpoint por-página cuando el server rechaza o la red está caída.
    private var lastHeartbeatAt: Date?
    /// La última confirmación del lease de la ida (`confirmMigrationLease`). La comparten la puerta —que la exige de menos
    /// de 60 s para empezar una página— y el uploader y `verify`, que la exigen de menos de `leaseInFlightBudget` antes de
    /// cada trozo del push y del pull: una página son varios trozos, y la app congelada entre dos no vuelve a pasar por la
    /// puerta.
    private let leaseWitness: MigrationLeaseWitness

    /// Lo que puede tener una confirmación del lease para que un trozo de una página ya empezada todavía salga. 30 min: la
    /// mitad del lease, así que nadie puede haber tomado el relevo, y de sobra para que una página lenta no se corte sola
    /// (los 60 s de la puerta sí la cortarían).
    static let leaseInFlightBudget: Duration = .seconds(1800)

    /// Key del flag `relaunchRequested` (§g.4 paso 4). iOS no se auto-relanza; el relaunch asistido es
    /// I14. ALIAS de `StorageModePersistence.mirrorOffArmedKey` (SERIO 1): este flag es TAMBIÉN el
    /// armado del montaje mirror-OFF — `personalStoreDecision` lo exige junto a `.cloud`; escribirlo
    /// solo tras `isMarkerExported()` (el runner lo garantiza) cierra la ventana de kill que enclavaba
    /// la migración con el marcador sin exportar.
    static let relaunchRequestedKey = StorageModePersistence.mirrorOffArmedKey

    /// `identifierForVendor` (o un UUID fresco si UIKit no está disponible / es nil). El faro/claim lo usan
    /// como `device_id` estable del dispositivo.
    static var vendorDeviceID: String {
        #if canImport(UIKit)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        return UUID().uuidString
        #endif
    }

    init(
        engine: CloudSyncEngine,
        pushClient: SyncPushClient,
        pullClient: SyncPullClient,
        merkleClient: SyncMerkleClient,
        accountClient: CloudAccountClient,
        session: CloudSyncSessionProviding,
        context: ModelContext,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { .now },
        deviceID: String? = nil,
        provider: @escaping @MainActor () -> String = { "apple" },
        beacon: CloudBeacon? = nil,
        personalStoreURL: URL? = nil,
        storageDefaults: UserDefaults = .standard,
        snapshotPageSize: Int = 200,
        heartbeatInterval: TimeInterval = 60,
        leaseClock: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now },
        reverseTombstoneSource: ReverseTombstoneSource? = nil,
        adoptQuiescenceSignal: @escaping () -> Bool = { true },
        claimStore: CloudClaimActionStore? = nil,
        icloudAccountPresent: (@MainActor () -> Bool)? = nil,
        icloudLastExportErrorCode: (@MainActor () -> CKError.Code?)? = nil,
        icloudMirrorReportedNotAuthenticated: (@MainActor () -> Bool)? = nil,
        icloudLastExportErrorAt: (@MainActor () -> Date?)? = nil,
        icloudLastSuccessfulExportAt: (@MainActor () -> Date?)? = nil,
        relayIdentityLedgerURL: URL? = nil
    ) {
        self.engine = engine
        self.pushClient = pushClient
        self.pullClient = pullClient
        self.merkleClient = merkleClient
        self.accountClient = accountClient
        self.session = session
        self.context = context
        self.calendar = calendar
        self.now = now
        // Defaults MainActor-aislados resueltos en el cuerpo (no en los default args, que son nonisolated).
        self.deviceID = deviceID ?? MigrationWorkExecutor.vendorDeviceID
        self.provider = provider
        self.beacon = beacon ?? CloudBeacon()
        self.personalStoreURL = personalStoreURL ?? SwiftDataConfiguration.personalConfiguration.url
        self.relayIdentityLedgerURL = relayIdentityLedgerURL ?? RelayIdentityLedger.defaultURL
        self.storageDefaults = storageDefaults
        self.heartbeatInterval = heartbeatInterval
        let leaseWitness = MigrationLeaseWitness(clock: leaseClock)
        self.leaseWitness = leaseWitness
        self.adoptQuiescenceSignal = adoptQuiescenceSignal
        self.claimStore = claimStore ?? .shared
        // C-1: defaults MainActor-aislados resueltos en el CUERPO (los default args son nonisolated, mismo
        // motivo que `deviceID`/`personalStoreURL`/`claimStore`).
        self.icloudAccountPresent = icloudAccountPresent ?? { SwiftDataConfiguration.isICloudAvailable() }
        self.icloudLastExportErrorCode = icloudLastExportErrorCode
            ?? { iCloudSyncService.shared.lastExportError?.code }
        self.icloudMirrorReportedNotAuthenticated = icloudMirrorReportedNotAuthenticated
            ?? { iCloudSyncService.shared.mirrorReportedNotAuthenticated }
        self.icloudLastExportErrorAt = icloudLastExportErrorAt
            ?? { iCloudSyncService.shared.lastExportErrorAt }
        self.icloudLastSuccessfulExportAt = icloudLastSuccessfulExportAt
            ?? { iCloudSyncService.shared.lastSuccessfulExportDate }
        self.uploader = MigrationSnapshotUploader(
            engine: engine, pushClient: pushClient, context: context,
            calendar: calendar, now: now, pageSize: snapshotPageSize,
            canRenewSession: { [session] in session.canRenewSession },
            leaseStillConfirmed: { leaseWitness.isConfirmed(within: MigrationWorkExecutor.leaseInFlightBudget) })
        self.tombstoneSource = reverseTombstoneSource ?? pullClient
    }

    // MARK: - Claim (§f.1)

    /// `POST /account/claim` con el JWT vigente + el `device_id` del dispositivo + `provider`. Sin JWT →
    /// `.sessionExpired` (el runner decide con `canRenewSession` si es definitivo). NUNCA lanza.
    ///
    /// El default `false` es solo para los tests del ejecutor, que lo llaman directo: el runner lo pasa SIEMPRE, por el
    /// protocolo, que no tiene default.
    func performClaim(marksMigrationAttempt: Bool = false) async -> ClaimOutcome {
        // Cada claim empieza sin nada que deshacer: `discardLastClaimStamp` solo repone lo de ESTE claim.
        lastClaimStampUndo = nil
        guard let jwt = await session.accessToken(), !jwt.isEmpty else {
            return .sessionExpired(detail: "no access token")
        }
        // La MARCA del intento, ANTES del POST (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`, decisión de
        // Jürgen del 2026-09-22). Un claim que llega al servidor y pierde la respuesta deja la cuenta `complete` sin el sello
        // de abajo, que solo se escribe con la respuesta en la mano. Hasta ese ticket no se notaba —el paso no salía nunca y
        // el reintento del mismo líder acababa sellando—, pero con techo y «Cancelar» al 22 % la puerta de «Migrar» la leía
        // como una cuenta con datos ajenos y ya no dejaba migrar a ella. La marca solo le dice a la puerta que pregunte al
        // claim, que sigue decidiendo: el mismo líder recibe `created` y una cuenta ajena se para con su aviso.
        // Se escribe solo en un claim de «Migrar», que es la única puerta que abre; se BORRA con la respuesta de cualquier
        // claim de esta cuenta, porque cualquier respuesta dice ya cómo está el servidor.
        let attemptUserID = session.currentUserID
        if marksMigrationAttempt, let attemptUserID { claimStore.recordMigrationClaimAttempt(forUserID: attemptUserID) }
        // `migration: true` ES OBLIGATORIO (bug device 2026-07-10): arma `migration_in_progress=true` en
        // el INSERT atómico → el guard de `migration_progress('cutover')` (exige mip) pasa. Sin él, el
        // claim crea la fila con mip=false y el cutover se clava en `not_in_progress` para siempre.
        let (outcome, personalWrites) = await accountClient.claimReportingPersonalWrites(
            jwt: jwt, deviceID: deviceID, provider: provider(), migration: true)
        // Se reasigna en CADA claim que llega al POST, también a `nil`. El que no llega (sin token) no puede entrar en la
        // identidad, que es lo único que lee la pista: un reseteo al empezar sobraba (lo dijo su mutante, que sobrevivía).
        lastClaimPersonalWrites = personalWrites
        // Con la respuesta en la mano el desenlace ya se sabe: `created` deja el sello (`.proceedMigration`), y cualquier
        // otro dice que la cuenta no es de este intento. La marca sobra en los dos casos; sin respuesta, se queda.
        if case .success = outcome, let attemptUserID {
            claimStore.clearMigrationClaimAttempt(forUserID: attemptUserID)
        }
        // P6: estampar el `AuthAction` resuelto en el claim-store (branch `.migration`) → el gate de
        // arranque del runtime (`LiveCloudSessionProvider.claimAction`) lo lee. El faro cloud + provider
        // no aplican a la rama migración (variante B es born-cloud/returning) → `false`/`true` neutros.
        if case .success(let claimState) = outcome {
            if let userID = session.currentUserID {
                let action = AccountClaimDecision.decide(
                    state: claimState, branch: .migration,
                    beaconSaysCloudActivated: false, providerMatchesBeacon: true)
                lastClaimStampUndo = (userID, claimStore.action(forUserID: userID))
                claimStore.record(action, forUserID: userID)
                // KPI registros/día (alta nube): SOLO `created` = fila NUEVA server-side. One-shot
                // persistido por userID dentro del servicio — el re-claim del MISMO líder colapsa a
                // `created` (AccountClaimDecision) y una migración reanudada re-emitiría (doble conteo).
                if claimState == .created {
                    MetricsService.cloudRegistrationCompletedIfFirst(userID: userID, detail: "migration")
                }
            } else {
                // M1 del review: claim exitoso con userID nil (casi imposible — el claim usó la sesión).
                // Sin estampado, el guard de identidad P6 dejaría al dueño en `.idle` post-cutover; ruido
                // explícito para diagnosticarlo (el re-claim idempotente del resume lo re-estampa).
                CloudSyncBreadcrumb.migrationEffectFailed(effect: "performClaim", reason: "claim-stamp skipped: nil userID")
            }
        }
        return outcome
    }

    /// Repone el sello de antes del último `performClaim` (ver `MigrationWorkExecuting.discardLastClaimStamp`). Un solo
    /// uso: la segunda llamada no tiene nada que deshacer.
    func discardLastClaimStamp() {
        guard let undo = lastClaimStampUndo else { return }
        lastClaimStampUndo = nil
        if let previous = undo.previous {
            claimStore.record(previous, forUserID: undo.userID)
        } else {
            claimStore.clear(forUserID: undo.userID)
        }
    }

    /// Ver `MigrationWorkExecuting.lastClaimReportedPersonalWrites`.
    func lastClaimReportedPersonalWrites() -> Bool? { lastClaimPersonalWrites }

    // MARK: - Identidad (w3)

    /// Backfill de `syncID` + testigos `SyncIdentity` (la quiescencia la GARANTIZÓ el runner a la entrada —
    /// §b.3), flip del gate PERMANENTE `identityCaptureEnabled`, y captura de las coordenadas CloudKit con el
    /// mirror VIVO sobre las 16 entidades (las 10 de UUID estable TAMBIÉN — §b.5: no se asume que el UUID de
    /// dominio sea el recordName). El save de las filas casadas + testigos va en UN `context.save()`.
    ///
    /// **Contrato del flag (doc, w6)**: encender `identityCaptureEnabled` aquí es SOLO in-memory; la
    /// derivación persistente al boot (journal ≥ `assigningIdentity` → flag ON) llega en w6 con
    /// `MigrationPhaseStore`. HOY el runner lo re-flipea en cada `assignIdentity` (idempotente/re-ejecutable).
    func assignIdentity() async throws {
        // 1. Backfill (la quiescencia ya la garantizó el runner). LANZA desde `an-incomplete-inventory-reads-as-the-whole-corpus`:
        //    tragado, dejaba filas sin identidad que el snapshot saltaba después.
        try SyncIdentityService.backfillIdentities(context: context, now: now())

        // 2. Gate PERMANENTE (§g.3): todo save nuevo acuña syncID. In-memory hoy (persistencia en w6).
        CloudSyncFlags.identityCaptureEnabled = true

        // 3. Captura CloudKit sobre las 16 entidades (mirror vivo). Una tabla ilegible LANZA: capturar sobre un
        //    inventario parcial dejaba esas filas sin coordenadas y el breadcrumb contaba `captured: 0` como si no
        //    hubiera nada (ticket `an-incomplete-inventory-reads-as-the-whole-corpus`). El runner lo convierte en
        //    `.localFailure`, con el techo corto.
        let pairs = try collectIdentityPairs()
        let report = CKIdentityCapture.capture(pairs, storeURL: personalStoreURL)

        // 4. Save (la captura escribió las coordenadas en las filas testigo; aquí se persisten).
        if context.hasChanges {
            try context.save()
        }

        // 5. El registro fila → identidad (ticket `relay-row-rekeyed-then-deleted-tombstones-the-leader-identity`): si el
        //    espejo le cambia la identidad a una de estas filas y se borra antes de que `restoreRelayIdentities` se la
        //    devuelva, el drain saca también su tombstone con la de aquí. Best-effort: sin él, como antes del ticket.
        seedRelayIdentityLedger(pairs)
        CloudSyncBreadcrumb.migrationIdentityCaptured(
            captured: report.captured, exportPending: report.exportPending,
            noMetadata: report.noMetadata, failed: report.failed)
    }

    /// Correlaciona cada fila de negocio (por su identidad de sync) con su testigo `SyncIdentity` → pares
    /// `(PersistentIdentifier, SyncIdentity)` para `CKIdentityCapture`. Las 16 entidades. LANZA si una tabla —la de
    /// testigos incluida— no se deja leer.
    private func collectIdentityPairs() throws -> [(id: PersistentIdentifier, row: SyncIdentity)] {
        var rowsBySyncID: [UUID: SyncIdentity] = [:]
        for row in try fetchInventory(SyncIdentity.self, step: "identity-capture") {
            rowsBySyncID[row.syncID] = row
        }

        var pairs: [(id: PersistentIdentifier, row: SyncIdentity)] = []
        try addPairs(TransactionItem.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(InboxDraft.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(Category.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(FavoritePayment.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(MerchantMemory.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(ExchangeRate.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(Budget.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(ScheduledPayment.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(Account.self, identity: { $0.shortcutID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(Subcategory.self, identity: { $0.shortcutID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(Tag.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(NotificationItem.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(CashFlowPlan.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(CashFlowLine.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(CashFlowOverride.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addPairs(GroupBridgePreference.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        return pairs
    }

    /// Las filas vivas de las 16 entidades para el muestreo de `reverseUpload`: TODAS, no solo las que tienen testigo.
    ///
    /// Una fila con testigo `SyncIdentity` va con él, y la captura le actualiza las coordenadas (§h.6 pto 3). Una fila
    /// SIN testigo va con un testigo SCRATCH que no se inserta, molde de `isMarkerExported`: `capture` solo le escribe
    /// al objeto en memoria. Sin esto el muestreo no veía lo creado en ESTE teléfono por una cuenta nacida en la nube
    /// —esas filas no pasan por `backfillIdentities` (solo la ida y el adopt) ni llegan nuevas por el pull, que es
    /// donde nacen los testigos—, así que `pending == 0` y la vuelta a iCloud se daba por hecha al instante sin
    /// comprobar que algo hubiera llegado (ticket `reverse-upload-has-no-ceiling-and-no-exit`, D15).
    ///
    /// NO sustituye a `collectIdentityPairs`: la ida captura coordenadas para persistirlas y ahí un testigo scratch no
    /// sirve. Si el fetch de testigos falla, todas las filas van con testigo scratch: el muestreo sigue leyendo el
    /// SQLite y lo que no haya exportado cuenta como pendiente, en vez de devolver cero pares.
    ///
    /// Una tabla de NEGOCIO que no se deja leer, en cambio, LANZA (ticket `an-incomplete-inventory-reads-as-the-whole-corpus`):
    /// sin sus filas la muestra cuenta menos pendientes, y eso es un «avance» falso para el techo o, si eran todas las
    /// pendientes, un `.drained` que cierra la vuelta sin que sus datos hayan llegado a iCloud.
    private func collectReverseUploadPairs() throws -> [(id: PersistentIdentifier, row: SyncIdentity)] {
        var rowsBySyncID: [UUID: SyncIdentity] = [:]
        do {
            for row in try context.fetch(FetchDescriptor<SyncIdentity>()) {
                rowsBySyncID[row.syncID] = row
            }
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor.collectReverseUploadPairs: fetch(SyncIdentity) falló, todo va con testigo scratch: \(error)")
            #endif
        }
        var pairs: [(id: PersistentIdentifier, row: SyncIdentity)] = []
        try addReverseUploadPairs(TransactionItem.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(InboxDraft.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(Category.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(FavoritePayment.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(MerchantMemory.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(ExchangeRate.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(Budget.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(ScheduledPayment.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(Account.self, identity: { $0.shortcutID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(Subcategory.self, identity: { $0.shortcutID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(Tag.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(NotificationItem.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(CashFlowPlan.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(CashFlowLine.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(CashFlowOverride.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        try addReverseUploadPairs(GroupBridgePreference.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        return pairs
    }

    /// Fetch CONCRETO por tipo (regla de `#Predicate`). Cada fila viva entra: con su testigo si existe, o con uno
    /// scratch sin insertar si no (incluida la que aún no tiene identidad de sync).
    private func addReverseUploadPairs<M: PersistentModel>(
        _ type: M.Type, identity: (M) -> UUID?,
        into pairs: inout [(id: PersistentIdentifier, row: SyncIdentity)],
        rowsBySyncID: [UUID: SyncIdentity]
    ) throws {
        for model in try fetchInventory(M.self, step: "reverse-sample") {
            if let sid = identity(model), let row = rowsBySyncID[sid] {
                pairs.append((model.persistentModelID, row))
            } else {
                let scratch = SyncIdentity(
                    syncID: identity(model) ?? UUID(), entityType: String(describing: M.self), localAnchor: "")
                pairs.append((model.persistentModelID, scratch))
            }
        }
    }

    /// Fetch CONCRETO por tipo (regla inviolable de `#Predicate`). Empareja cada modelo con identidad con su
    /// testigo (una fila jamás exportada/no-backfilleada sin testigo se salta — no bloquea).
    private func addPairs<M: PersistentModel>(
        _ type: M.Type, identity: (M) -> UUID?,
        into pairs: inout [(id: PersistentIdentifier, row: SyncIdentity)],
        rowsBySyncID: [UUID: SyncIdentity]
    ) throws {
        for model in try fetchInventory(M.self, step: "identity-capture") {
            guard let sid = identity(model), let row = rowsBySyncID[sid] else { continue }
            pairs.append((model.persistentModelID, row))
        }
    }

    /// El `fetch` de UNA tabla de un inventario de la migración. LANZA `inventoryUnreadable` con rastro en producción
    /// (ticket `an-incomplete-inventory-reads-as-the-whole-corpus`): hasta ese ticket cada uno de los seis inventarios
    /// saltaba la tabla bajo un `print` de `#if DEBUG` y seguía como si estuviera vacía. Lo que se comparte es la
    /// lectura y el rastro; el desenlace lo elige cada llamador. Fetch CONCRETO por tipo (regla de `#Predicate`).
    private func fetchInventory<M: PersistentModel>(_ type: M.Type, step: String) throws -> [M] {
        let entity = String(describing: M.self)
        do {
            // El seam va DENTRO del `do`: el camino que recorre el test es el `catch` real.
            if _testInventoryFetchThrows?(step, entity) == true { throw CocoaError(.fileReadCorruptFile) }
            return try context.fetch(FetchDescriptor<M>())
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor: fetch(\(entity)) del inventario \(step) falló: \(error)")
            #endif
            CloudSyncBreadcrumb.migrationInventoryReadFailed(step: step, entity: entity)
            throw MigrationExecutorError.inventoryUnreadable(entity: entity)
        }
    }

    /// Apunta en el registro la identidad de cada fila de los seis tipos acuñados, por su `Z_PK`. Se FUSIONA con lo que
    /// hubiera: una pasada repetida tras un kill no puede tirar la entrada de una fila ya borrada. Un fallo de lectura o
    /// escritura deja rastro y no para la identidad: el registro es una red para un caso raro, y parar la migración entera
    /// por él (un disco lleno, por ejemplo) sería peor que el daño que cubre.
    private func seedRelayIdentityLedger(_ pairs: [(id: PersistentIdentifier, row: SyncIdentity)]) {
        var entries: [String: UUID] = [:]
        for pair in pairs where Self.mintedIdentityTypes.contains(pair.row.entityType) {
            guard let key = RelayIdentityLedger.key(for: pair.id) else { continue }
            entries[key] = pair.row.syncID
        }
        do {
            try RelayIdentityLedger.merge(entries, into: relayIdentityLedgerURL)
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor: sembrar el registro de identidades del relevo falló: \(error)")
            #endif
            CloudSyncBreadcrumb.relayIdentityLedgerUnavailable(step: "seed", errorType: String(describing: type(of: error)))
        }
    }

    // MARK: - La identidad que el espejo cambia por debajo (ticket `displaced-leader-late-identity-export-can-rekey-the-relief-corpus`)

    /// Las coordenadas de un record de CloudKit. Son las mismas en todos los teléfonos del mismo iCloud: el record es uno.
    struct RecordCoordinates: Hashable {
        let recordName: String
        let zoneName: String
        let ownerName: String
    }

    /// Los tipos cuya identidad de sync la ACUÑA cada teléfono (`backfillIdentities`), y por eso dos teléfonos pueden darle
    /// dos distintas a la misma fila. Los otros diez usan un UUID que nace con la fila y viaja con ella.
    static let mintedIdentityTypes: [String] = [
        SyncEntityType.transactionItem, SyncEntityType.inboxDraft, SyncEntityType.category,
        SyncEntityType.favoritePayment, SyncEntityType.merchantMemory, SyncEntityType.exchangeRate,
    ]

    /// Coordenadas de las filas vivas sin leer el SQLite: los stores de test no espejan, así que no tienen metadatos de
    /// CloudKit. Sin el seam, un store de test sin esas tablas es una lectura que falla, y el test que lo mide va sin él.
    /// SOLO tests.
    var _testRecordCoordinates: ((PersistentIdentifier) -> RecordCoordinates?)?
    /// Cuántas filas se mandaron a buscar coordenadas. El camino barato —sin testigo huérfano o sin fila sin testigo— no
    /// busca ninguna, y eso es lo que el test mide. SOLO tests.
    private(set) var _testRecordCoordinateLookups = 0

    /// Si una restauración de este executor toleró unos metadatos de CloudKit ilegibles (solo el reconcile de `done`). Lo lee
    /// `markRelayIdentityLedgerRetirable`.
    private var relayIdentityRecordsTolerated = false

    /// **Devuelve a la identidad que este teléfono subió las filas que el espejo de iCloud re-identificó por debajo.**
    ///
    /// El caso: un líder de la ida se queda sin red después de su `assignIdentity`, otro teléfono toma el relevo, acuña
    /// sus identidades —las del líder no llegaron— y las sube. Cuando el líder vuelve, su espejo exporta las suyas, y si
    /// CloudKit le da la razón, el espejo del relevo (vivo hasta el remonte del cutover) cambia el `syncID` de filas que el
    /// backend ya conoce con otro. A partir de ahí la misma fila duplica: el paginado del snapshot por `afterSyncID` la
    /// vuelve a subir con la identidad nueva, y el pull del `verify` crea un born-remote con la vieja. Qué valor gana CloudKit
    /// no está medido (pide dos teléfonos): esto se diseña para el peor caso.
    ///
    /// **La identidad del relevo gana** porque es la que el backend tiene y el líder desplazado ya no sube (su puerta del
    /// lease lo saca); cuando entre en la cuenta, el linaje del adopt le re-identifica las suyas.
    ///
    /// **Cómo sabe cuál era.** El testigo `SyncIdentity` es local y `assignIdentity` le captura las coordenadas del record,
    /// que no cambian. Se restaura una fila solo si las tres cosas son ciertas:
    ///  1. su identidad actual NO tiene testigo aquí —ningún camino local cambia una identidad sin dejarlo: rebind,
    ///     curación de colisiones, re-identificación del linaje y el deduplicador escriben el testigo—;
    ///  2. su record casa con UN testigo huérfano de su tipo (ninguna fila viva lleva ya su `syncID`), y ese testigo con
    ///     ella sola;
    ///  3. el testigo tiene coordenadas. Una fila que el líder pudo re-identificar existía en CloudKit antes de que él la
    ///     identificara, y eso es antes que la identidad del relevo, así que su testigo las tiene. Sin ellas, o con dos
    ///     candidatas para un record, no se toca: acertar con otra fila sería el bug contrario.
    ///
    /// **Dónde se llama, y por qué ahí**: antes de cada página del snapshot, antes de cada drain de la verificación de la
    /// ida —los del pull también, que corren después de su `await`, cuando el import pudo aterrizar—, antes del drain del
    /// cutover y una vez en el reconcile de `done`, ya con el espejo apagado, para lo que llegó entre la última verificación
    /// y el remonte. Siempre sin `await` entre la restauración y lo que lee identidades: el import se fusiona en el contexto
    /// principal desde la cola principal, así que no cabe en medio.
    ///
    /// La restauración cambia SOLO el `syncID`: el drain la salta (la identidad no es columna) y el espejo la exporta. LANZA
    /// si una tabla, el testigo, los metadatos de CloudKit o el guardado fallan, con el trabajo deshecho: el llamador lo
    /// cuenta como avería local, nunca como «no había nada que restaurar». Devuelve cuántas restauró.
    ///
    /// **`toleratingUnreadableRecords` es solo del reconcile de `done`**, que corre con el store remontado sin espejo:
    /// que los metadatos de CloudKit sigan legibles ahí no está medido, y lanzar dejaría el efecto pendiente para siempre
    /// con el motor parado (un pendiente en `done` lo bloquea). Allí una lectura que falla deja rastro y sigue, sin
    /// restaurar lo que no puede reconocer. Con el espejo vivo esas tablas existen, y fallar es una avería.
    @discardableResult
    func restoreRelayIdentities(toleratingUnreadableRecords: Bool = false) throws -> Int {
        var witnessed: Set<UUID> = []
        var pinned: [PinKey: [SyncIdentity]] = [:]
        for witness in try fetchInventory(SyncIdentity.self, step: "identity-pin") {
            witnessed.insert(witness.syncID)
            guard Self.mintedIdentityTypes.contains(witness.entityType),
                  let recordName = witness.ckRecordName, let zoneName = witness.ckZoneName,
                  let ownerName = witness.ckOwnerName else { continue }
            let key = PinKey(entityType: witness.entityType,
                             record: RecordCoordinates(recordName: recordName, zoneName: zoneName, ownerName: ownerName))
            pinned[key, default: []].append(witness)
        }
        guard !pinned.isEmpty else { return 0 }

        var live: [String: Set<UUID>] = [:]
        var candidates: [PinCandidate] = []
        func collect<M: PersistentModel & SyncIdentifiable>(_ type: M.Type, _ entityType: String) throws {
            for model in try fetchInventory(M.self, step: "identity-pin") {
                guard let current = model.syncID else { continue }
                live[entityType, default: []].insert(current)
                if !witnessed.contains(current) {
                    candidates.append(PinCandidate(id: model.persistentModelID, entityType: entityType, current: current,
                                                   restore: { model.syncID = $0 }))
                }
            }
        }
        try collect(TransactionItem.self, SyncEntityType.transactionItem)
        try collect(InboxDraft.self, SyncEntityType.inboxDraft)
        try collect(Category.self, SyncEntityType.category)
        try collect(FavoritePayment.self, SyncEntityType.favoritePayment)
        try collect(MerchantMemory.self, SyncEntityType.merchantMemory)
        try collect(ExchangeRate.self, SyncEntityType.exchangeRate)

        // Un testigo huérfano por record: con dos, no se sabe cuál era.
        var orphanByKey: [PinKey: SyncIdentity] = [:]
        for (key, witnesses) in pinned {
            let orphans = witnesses.filter { !(live[key.entityType] ?? []).contains($0.syncID) }
            if orphans.count == 1, let orphan = orphans.first { orphanByKey[key] = orphan }
        }
        guard !orphanByKey.isEmpty, !candidates.isEmpty else { return 0 }

        guard let coordinates = recordCoordinates(for: candidates.map(\.id)) else {
            CloudSyncBreadcrumb.migrationRelayIdentityRecordsUnreadable(tolerated: toleratingUnreadableRecords)
            if toleratingUnreadableRecords {
                relayIdentityRecordsTolerated = true
                return 0
            }
            throw MigrationExecutorError.inventoryUnreadable(entity: "CloudKitRecordMetadata")
        }
        var byKey: [PinKey: [PinCandidate]] = [:]
        for candidate in candidates {
            guard let record = coordinates[candidate.id] else { continue }
            byKey[PinKey(entityType: candidate.entityType, record: record), default: []].append(candidate)
        }

        var undo: [() -> Void] = []
        var restoredByEntity: [String: Int] = [:]
        for (key, orphan) in orphanByKey {
            guard let matched = byKey[key], matched.count == 1, let candidate = matched.first else { continue }
            candidate.restore(orphan.syncID)
            let previous = candidate.current
            undo.append { candidate.restore(previous) }
            restoredByEntity[key.entityType, default: 0] += 1
        }
        guard !undo.isEmpty else { return 0 }
        do {
            try context.save()
        } catch {
            // Deshace SOLO lo suyo: el contexto es compartido y un `rollback` tiraría ediciones ajenas.
            for revert in undo.reversed() { revert() }
            #if DEBUG
            print("MigrationWorkExecutor: guardar las identidades restauradas falló: \(error)")
            #endif
            CloudSyncBreadcrumb.migrationRelayIdentityRestoreFailed(errorType: String(describing: type(of: error)))
            throw error
        }
        for (entity, count) in restoredByEntity.sorted(by: { $0.key < $1.key }) {
            CloudSyncBreadcrumb.migrationRelayIdentityRestored(entity: entity, count: count)
            MetricsService.cloudRelayIdentityRestored(entity: entity, count: count)
        }
        return undo.count
    }

    private struct PinKey: Hashable {
        let entityType: String
        let record: RecordCoordinates
    }

    private struct PinCandidate {
        let id: PersistentIdentifier
        let entityType: String
        let current: UUID
        let restore: (UUID) -> Void
    }

    /// Las coordenadas de CloudKit de cada fila, leídas de los metadatos del espejo con testigos SCRATCH que no se insertan
    /// (molde de `isMarkerExported`): `capture` solo le escribe al objeto en memoria. Una fila sin record —sin metadatos, o
    /// con el export pendiente— no sale en el mapa y no casa con nada: el espejo no pudo re-identificar lo que no tiene
    /// record. **`nil` si alguna lectura FALLÓ** (el SQLite no abre, faltan las tablas, una zona que no resuelve): eso no es
    /// «esta fila no tiene record», y leerlo así dejaba sin restaurar justo la que había que restaurar.
    private func recordCoordinates(for ids: [PersistentIdentifier]) -> [PersistentIdentifier: RecordCoordinates]? {
        _testRecordCoordinateLookups += ids.count
        if let seam = _testRecordCoordinates {
            return Dictionary(uniqueKeysWithValues: ids.compactMap { id in seam(id).map { (id, $0) } })
        }
        let pairs = ids.map { (id: $0, row: SyncIdentity(syncID: UUID(), entityType: "", localAnchor: "")) }
        guard CKIdentityCapture.capture(pairs, storeURL: personalStoreURL).failed == 0 else { return nil }
        var out: [PersistentIdentifier: RecordCoordinates] = [:]
        for pair in pairs {
            guard let recordName = pair.row.ckRecordName, let zoneName = pair.row.ckZoneName,
                  let ownerName = pair.row.ckOwnerName else { continue }
            out[pair.id] = RecordCoordinates(recordName: recordName, zoneName: zoneName, ownerName: ownerName)
        }
        return out
    }

    /// Si la última restauración de identidades lanzó. La verificación la pasa al pull como `beforeDrain`, y el pull solo
    /// sabe devolver `.transient`: con esto la verificación dice avería local y no red.
    private var relayIdentityPinUnreadable = false

    /// `restoreRelayIdentities` para el `beforeDrain` del pull: apunta el fallo antes de relanzarlo.
    private func restoreRelayIdentitiesNotingFailure() throws {
        do {
            try restoreRelayIdentities()
        } catch {
            relayIdentityPinUnreadable = true
            throw error
        }
    }

    // MARK: - Snapshot (w4)

    /// Sube el snapshot completo en batches idempotentes/resumibles (delega en `MigrationSnapshotUploader`).
    ///
    /// Antes de cada página devuelve a su identidad las filas que el espejo re-identificó (`restoreRelayIdentities`): el
    /// paginado va por `afterSyncID`, y una fila ya subida que cambia a una identidad mayor que el cursor se subiría otra
    /// vez. Entre la restauración y la lectura de la página no hay `await` —`uploadPage` es del mismo actor y lee antes de
    /// su primer push—, así que el import no cabe en medio.
    func uploadSnapshot(cursor: String?) async -> SnapshotStepOutcome {
        do {
            try restoreRelayIdentities()
        } catch {
            return .blocked(.localFailure)
        }
        return await uploader.uploadPage(cursor: cursor)
    }

    // MARK: - Verify (w5)

    /// Verifica cuenta+checksum Merkle local vs backend, con el pre-check TOCTOU (§g.3) y el `pullAndApplyOnce`
    /// OBLIGATORIO antes de `verifyIntegrity` (el guard `lastPullCycleCompleted` jamás se pone durante la
    /// migración porque el runtime no corre → sin el pull, `verifyIntegrity` skippearía SIEMPRE).
    ///
    /// **Lo comparten las dos direcciones** (`driveVerify` y `driveReverseVerify`, contados), y desde el ticket
    /// `reverse-before-mount-stays-stuck-with-an-expired-session` el `.sessionExpired` del push o del pull ya no
    /// colapsa en `.networkTimeout`: sale tipado y **cada dirección decide**. La vuelta corta sin gastar reintento; la
    /// ida lo trata como red, igual que antes de que el caso existiera. El token que no llega sin red y el 401 del
    /// attest no llegan aquí: los filtran los clientes con `canRenewSession`.
    ///
    /// **El TERCER paso también tipa desde el 2026-09-22** (`reverse-verify-network-bucket-hides-a-definitive-server-no`):
    /// el Merkle. Hasta ese día el push y el pull separaban su 401 y su 403 y el Merkle los aplanaba, así que el 403
    /// que empieza justo ENTRE el pull y el Merkle —la ventana que quedaba— salía de aquí como red y la vuelta lo
    /// esperaba 72 h. Ahora los tres pasos contestan con el mismo vocabulario.
    ///
    /// **`underMigrationLease`: la ida pasa `true`** (ticket `displaced-migration-leader-keeps-uploading-after-a-takeover`).
    /// Entonces el push corta antes de cada trozo, y el pull no se pide, si la confirmación del lease tiene más de
    /// `leaseInFlightBudget`: la puerta del runner preguntó al empezar, y la app congelada a mitad subiría o traería el
    /// corpus de quien tomó el relevo. Sale como red. La vuelta a iCloud pasa `false`: su lease lo guardan freeze y complete.
    ///
    /// **Y la ida devuelve antes de cada drain las identidades que el espejo cambió por debajo** (`restoreRelayIdentities`,
    /// ticket `displaced-leader-late-identity-export-can-rekey-the-relief-corpus`): aquí, antes del pre-check, y dentro del
    /// pull, antes del drain de cada página, que corre después del `await` en el que el import pudo aterrizar. Sin la del
    /// pull, la fila re-identificada durante esa espera recibía su propia copia del backend como born-remote. Si la restauración no se deja leer es avería local, no red. La vuelta a iCloud no la hace: allí el espejo
    /// es el que baja lo que la nube congeló, y esa pregunta es otra.
    func verify(underMigrationLease: Bool = false) async -> VerifyProbe {
        let leaseStillConfirmed: @MainActor () -> Bool = { [leaseWitness] in
            !underMigrationLease || leaseWitness.isConfirmed(within: MigrationWorkExecutor.leaseInFlightBudget)
        }
        if underMigrationLease {
            do {
                try restoreRelayIdentities()
            } catch {
                return .blocked(.localFailure)
            }
        }
        // Pre-check TOCTOU: drenar + subir si hay filas vivas ANTES de verificar. Partición poison (#26,
        // fix del review adversarial — simetría con el uploader): una fila no-construible se AÍSLA como
        // dead-letter (el mismatch que provoca consume presupuesto de MISMATCH → degrada honesto a
        // failedRollback) en vez de hacer fallar el push entero consumiendo presupuesto de RED.
        // Un drain que no terminó deja cambios fuera del outbox: con él, «no queda nada» no probaría nada (ticket
        // `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read`). Avería LOCAL, como el outbox ilegible.
        guard engine.drainOnce(context: context) else { return .blocked(.localFailure) }
        // El outbox que no se deja leer NO es un outbox vacío, y este es el sitio donde esa diferencia se paga
        // (ticket `verify-reads-a-failed-local-fetch-as-an-empty-outbox`). Hasta el 2026-09-22 el `catch` del
        // helper devolvía `[]`, así que la misma avería se leía aquí como «no hay nada que subir» —saltándose un
        // push que sí hacía falta— y veinte líneas después, en `verifyIntegrity`, como algo definitivo. Dos
        // conclusiones opuestas de una sola lectura fallida, en la misma pasada.
        let allLive: [SyncOutbox]
        do {
            allLive = try liveOutboxRows()
        } catch {
            CloudSyncBreadcrumb.outboxFetchFailed(step: "verify")
            return .blocked(.localFailure)
        }
        let (live, poison) = pushClient.partitionBuildable(allLive)
        engine.deadLetterPoison(poison, context: context, now: now())
        if !live.isEmpty {
            switch await pushClient.push(live, continueWhile: leaseStillConfirmed) {
            case .completed(let results):
                await pushClient.applyResults(results, rows: live, engine: engine, context: context)
                // Si tras el push quedan filas VIVAS → red (transient); si el outbox quedó limpio → un delta
                // aterrizó y se subió → re-run barato (NO consume retry).
                //
                // **Y si no se deja leer, no es ninguna de las dos.** Esta relectura era la peor de las cuatro:
                // `[]` daba `.newDeltaDetected`, que NO consume reintento, así que una base ilegible no solo se
                // leía como «todo subido» sino como «llegó un delta, vuelve a correr gratis» — una re-corrida sin
                // techo alimentada por la avería.
                do {
                    return try liveOutboxRows().isEmpty ? .newDeltaDetected : .networkTimeout
                } catch {
                    CloudSyncBreadcrumb.outboxFetchFailed(step: "verify-after-push")
                    return .blocked(.localFailure)
                }
            case .sessionExpired:
                return .sessionExpired
            case .accountUnavailable:
                return .blocked(.accountUnavailable)
            case .transient:
                return .networkTimeout
            }
        }

        // pullAndApplyOnce ANTES de verifyIntegrity: marca `lastPullCycleCompleted` (cuenta fresca = pull
        // vacío; re-verify = trae de vuelta nuestras propias filas, LWW no-op material). Pull transient → red.
        // Con la confirmación del lease caducada no se pide: traería a este store el corpus de quien tomó el relevo.
        guard leaseStillConfirmed() else {
            CloudSyncBreadcrumb.migrationLeaseUnconfirmed(reason: "verify-before-pull")
            return .networkTimeout
        }
        relayIdentityPinUnreadable = false
        var beforeDrain: (@MainActor () throws -> Void)?
        if underMigrationLease {
            beforeDrain = { [weak self] in try self?.restoreRelayIdentitiesNotingFailure() }
        }
        switch await engine.pullAndApplyOnce(using: pullClient, context: context, now: now(), beforeDrain: beforeDrain) {
        case .completed:
            break
        case .sessionExpired:
            return .sessionExpired
        case .accountUnavailable:
            return .blocked(.accountUnavailable)
        case .busy, .transient:
            return relayIdentityPinUnreadable ? .blocked(.localFailure) : .networkTimeout
        }

        // Y otra vez antes del árbol local del Merkle, que se calcula después de esperar el remoto (y de la última página
        // vacía del pull): un import que aterrizó ahí daba una divergencia falsa que gastaba un reintento de MISMATCH.
        let verdict = await engine.verifyIntegrity(using: merkleClient, context: context, beforeLocalTree: beforeDrain)
        if VerifyProbeMapping.isUnknownSkip(verdict) {
            if case .skipped(let reason) = verdict {
                CloudSyncBreadcrumb.migrationVerifyUnknownReason(reason: reason)
            }
        }
        return VerifyProbeMapping.map(verdict: verdict)
    }

    /// Filas de outbox VIVAS (dead-letters excluidos — nunca suben).
    ///
    /// **LANZA desde el 2026-09-22** (ticket `verify-reads-a-failed-local-fetch-as-an-empty-outbox`). Devolvía
    /// `[]`, y `[]` aquí no significa «no hay nada que subir»: significa «no sé lo que hay». Los cuatro
    /// llamadores lo leían como lo primero y se saltaban el push — el mismo fallo que veinte líneas después
    /// `verifyIntegrity` ya trataba como un desenlace propio (`.blocked(.localFailure)`). Con `throws`, cada uno
    /// contesta por su cuenta y el compilador no deja que nadie se olvide.
    private func liveOutboxRows() throws -> [SyncOutbox] {
        // El seam va DENTRO del `do`, no antes: así el camino de error que recorre un test es el `catch` REAL
        // del fetch. Puesto fuera, un mutante que reintrodujera `return []` ahí seguiría verde.
        do {
            // El contador solo corre con el seam ARMADO: en producción `from` es `nil` y esto es una
            // comparación, no una escritura.
            if let from = _testOutboxFetchThrowsFromCall {
                _testOutboxFetchCount += 1
                if _testOutboxFetchCount >= from { throw MigrationExecutorError.outboxUnreadable }
            }
            return try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor: fetch(SyncOutbox) falló: \(error)")
            #endif
            throw MigrationExecutorError.outboxUnreadable
        }
    }

    // MARK: - Cutover (w6, §g.4)

    /// ¿Conserva el SDK una sesión que renovar? (`MigrationWorkExecuting.canRenewSession`). El mismo testigo que ya usa la
    /// subida del snapshot, y por la misma razón: el SDK borra la sesión antes de lanzar, así que se lee después.
    func canRenewSession() -> Bool {
        session.canRenewSession
    }

    /// La cuenta de la sesión viva, con el hash del faro (`MigrationWorkExecuting.currentAccountHash`).
    func currentAccountHash() -> String? {
        session.currentUserID.map { CloudBeacon.hash($0) }
    }

    /// ¿Está ya persistido `.cloud`? (`MigrationWorkExecuting.hasPersistedCloudMode`). Lee los MISMOS defaults en los que
    /// escribe el paso 5 del adopt (`writeCloudArmed(defaults: storageDefaults)`).
    func hasPersistedCloudMode() -> Bool {
        StorageModePersistence.read(storageDefaults) == .cloud
    }

    /// w6 paso 1: `migration_progress('cutover')` — estampa `profiles.migrated_at` (guard líder). NUNCA lanza.
    ///
    /// Clasifica el no para el techo de `cutover(.pending)` (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`;
    /// hasta ese ticket devolvía un `Bool` y el runner cortaba sin evento en cualquier `false`):
    ///  · `other_leader` → `.blocked(.otherDevice)`: otro dispositivo tomó el relevo del lease, y desde aquí no se vuelve.
    ///    El comentario de antes decía «el runner corta retomable → follower», y no había follower: se quedaba al 80 %;
    ///  · `rejected` (`not_in_progress`, `no_profile`, `bad_action`) → `.blocked(.refused)`;
    ///  · sin JWT, o 401 → `.blocked(.sessionExpired)` solo con la sesión BORRADA por el SDK; con la sesión guardada es
    ///    `.transient` —el token que no llega sin red, el reloj atrasado—, la regla del canal personal. `/account/migration`
    ///    no exige App Attest, así que su 401 es siempre el JWT;
    ///  · red/5xx → `.transient`.
    func confirmCutoverServer() async -> CutoverServerOutcome {
        guard let jwt = await session.accessToken(), !jwt.isEmpty else {
            CloudSyncBreadcrumb.migrationCutoverRejected(reason: "sessionExpired")
            return session.canRenewSession ? .transient : .blocked(.sessionExpired)
        }
        switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "cutover") {
        case .ok:
            CloudSyncBreadcrumb.migrationCutoverConfirmed()
            return .confirmed
        case .otherLeader:
            CloudSyncBreadcrumb.migrationCutoverOtherLeader()
            return .blocked(.otherDevice)
        case .rejected(let reason):
            CloudSyncBreadcrumb.migrationCutoverRejected(reason: reason)
            return .blocked(.refused)
        case .sessionExpired:
            CloudSyncBreadcrumb.migrationCutoverRejected(reason: "sessionExpired")
            return session.canRenewSession ? .transient : .blocked(.sessionExpired)
        case .transient:
            CloudSyncBreadcrumb.migrationCutoverRejected(reason: "transient")
            return .transient
        }
    }

    /// w6 paso 2: persiste `storageMode=.cloud` (`StorageModePersistence`). El próximo relanzamiento montará
    /// el store personal con el mirror OFF (`personalConfiguration` rama `.cloud`). Devuelve `true`.
    func persistLocalMode() async -> Bool {
        StorageModePersistence.write(.cloud, defaults: storageDefaults)
        CloudSyncBreadcrumb.migrationLocalModePersisted()
        return true
    }

    // MARK: - Efectos declarativos

    /// Ejecuta un efecto declarativo. Cableados en w6: `.writeBeacon` (§g.4-faro, al claim),
    /// `.startParallelHistoryCapture`, `.writeCloudKitMarker`, `.disableMirrorAndRelaunch`,
    /// `.runLeaderReconcileFromFrozenCloudKit`; en I11-2 los efectos locales de la reversa; en I11-3
    /// `.completeReverseServer`/`.reverseRollback` (server-side, acciones `reverse_*` del RPC).
    /// `.adoptBackendAccount` → `notWired` (§k.4, fuera de este ciclo; el runner lo deja journaled retomable).
    func execute(_ effect: MigrationEffect) async throws {
        switch effect {
        case .writeBeacon:
            beacon.writeCloudAccountLinked(provider: provider(), accountSub: session.currentUserID, now: now())

        case .startParallelHistoryCapture:
            // La CAPTURA continua ES el History (token-based): cualquier write de la ventana
            // localModeSet→mirrorOff queda en History tras el token y lo drena el próximo `drainOnce`
            // (post-relaunch). Un `drainOnce` aquí ancla el baseline al momento del cutover — no hace falta
            // un loop de captura dedicado.
            //
            // Antes del drain, las identidades que el espejo —vivo hasta el remonte— cambió por debajo
            // (`restoreRelayIdentities`): este drain traduciría una edición que llegó con ellas bajo la identidad nueva, y el
            // reconcile de `done` la subiría como fila aparte. Si no se deja leer, tampoco se drena: la History sigue ahí y el
            // reconcile restaura antes de su propio drain.
            do {
                try restoreRelayIdentities()
                engine.drainOnce(context: context)
            } catch {
                CloudSyncBreadcrumb.migrationEffectFailed(effect: "startParallelHistoryCapture", reason: "relay identity pin unreadable")
            }

        case .writeCloudKitMarker:
            // Último efecto OBSERVABLE: insertar el marcador en el store PERSONAL (el mirror VIVO lo exporta).
            // `serverSeqCut` = `SyncCursor.serverSeqCursor` actual (corte para `reconcileFromFrozenCloudKit`).
            let marker = CloudMigrationMarker(
                accountHash: session.currentUserID.map { CloudBeacon.hash($0) } ?? "",
                migratedAtStamp: now(),
                serverSeqCut: currentServerSeqCut(),
                writerDeviceID: deviceID)
            context.insert(marker)
            if context.hasChanges {
                try context.save()
            }
            CloudSyncBreadcrumb.migrationMarkerWritten(serverSeqCut: marker.serverSeqCut)

        case .disableMirrorAndRelaunch:
            // iOS no puede auto-relanzarse: persistimos el flag; el relanzamiento asistido con UI es I14
            // (en DEBUG el panel indica MATAR Y RELANZAR). El proceso NO se mata solo. El forward a
            // `done` lo resuelve por OBSERVACIÓN `isMirrorConfirmedOff()` (post-relaunch).
            storageDefaults.set(true, forKey: Self.relaunchRequestedKey)
            CloudSyncBreadcrumb.migrationRelaunchRequested()

        case .runLeaderReconcileFromFrozenCloudKit:
            // w8 — CAPA DE RED del líder (§g.4 SERIO 1 v3), ANTES del 'complete'. DECISIÓN documentada
            // (invariante PRECISADO por el review adversarial): el líder solo responde por SUS PROPIOS
            // writes — y TODOS sus writes de la ventana de cutover están en su History LOCAL (durable)
            // tras el baseline → el barrido correcto para el líder es drain(History) + push del residual.
            // Una fila que el CloudKit congelado tenga y el local NO (un 2º device del mismo Apple ID,
            // aún .icloud, escribiendo a la base compartida durante la ventana — el device puede no
            // haberla importado antes del mirror-off) NO es responsabilidad de este barrido: la sube el
            // PROPIO device que la escribió por su camino de adopt. CERRADO por `runAdoptOrphanReconcile()`
            // (DIFERIDOS #30, DARK): el adoptador diffea su store local contra `/sync/pull` read-only y sube
            // fila-completa cualquier identidad ∉ backend. I14 DEBE invocarlo en el flujo de adopt tras
            // quiescencia del import + fast-forward del baseline (contrato en el doc del método). RESIDUAL v1
            // irreducible: un device que escribió post-cutover y JAMÁS adopta deja esa fila huérfana en
            // CloudKit congelado (auto-bloqueado por `secondaryDeviceCloudLogin`; la fila no se pierde
            // físicamente y una adopción tardía la rescata — el diff no caduca). También v1: borrados de
            // ventana (resurrección benigna) + import-lag (duplicado curable). Candidato v2 (device que jamás
            // adopta) = lectura directa del CloudKit congelado por el líder (opción C, descartada v1).
            //
            // La PUERTA del lease va DELANTE de todo (ticket
            // `leader-displaced-after-the-cutover-pushes-its-residual-in-the-reconcile`). El lease puede caducar esperando el
            // marcador o el relanzamiento, y `claim_account` daba el relevo sin mirar `migrated_at` (hasta g16_04): el teléfono desplazado
            // empujaba aquí su residual encima de la migración de otro y reintentaba el efecto —y el `complete`, con su
            // `other_leader`— en cada arranque, con el runtime sin arrancar para siempre. Solo sube con el lease confirmado;
            // si lo perdió, `resolvePostCutoverLease` averigua quién cerró la migración sin subir nada. Salir a iCloud, como
            // antes del cutover, no es una opción: el marcador ya se exportó y el corpus de este teléfono ya está en la cuenta.
            //
            // Y antes que nada, las identidades que el espejo cambió por debajo entre la última verificación y el remonte
            // (`restoreRelayIdentities`): es la última vez que se miran, y va delante de TODAS las salidas porque las que se
            // unen sin drenar dejan el drain y el pull al runtime. Aquí el espejo ya está apagado, así que no llega nada más,
            // y por eso unos metadatos de CloudKit ilegibles se toleran (ver `restoreRelayIdentities`).
            do {
                try restoreRelayIdentities(toleratingUnreadableRecords: true)
            } catch {
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: relayIdentityPinUnreadable")
            }
            switch await resolvePostCutoverLease() {
            case .leads:
                break
            case .finishedHere:
                // Su propio `complete` llegó y se perdió la respuesta: la migración está cerrada por ESTE teléfono.
                CloudSyncBreadcrumb.migrationPostCutoverLeaseResolved(outcome: "finishedHere")
                stampMigrationFinished()
                return
            case .finishedElsewhere:
                // Otro dispositivo cerró la migración (o la cuenta vuelve a iCloud): este teléfono se une como uno más. Su
                // residual se queda en el outbox y lo sube el sync normal, con la migración ya cerrada.
                CloudSyncBreadcrumb.migrationPostCutoverLeaseResolved(outcome: "finishedElsewhere")
                MetricsService.cloudPostCutoverLeaseLost(outcome: "joined")
                stampMigrationFinished()
                return
            case .otherLeads:
                // Sin canario: el re-kick de 30 s lo dispararía en cada vuelta mientras el otro lidera.
                CloudSyncBreadcrumb.migrationPostCutoverLeaseResolved(outcome: "otherLeads")
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: otherLeaderActive")
            case .unconfirmed:
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: leaseUnconfirmed")
            case .sessionExpired:
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: sessionExpired")
            }
            // Un drain que no terminó tampoco manda el 'complete' (mismo molde retomable que el outbox ilegible).
            guard engine.drainOnce(context: context) else {
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: drainAborted")
            }
            // Un outbox ilegible PROPAGA (ticket `verify-reads-a-failed-local-fetch-as-an-empty-outbox`): con `[]`
            // el barrido salía vacío y el `migration_progress('complete')` de abajo se mandaba igual, cerrando la
            // migración de la cuenta con filas del líder sin subir. El molde retomable es el que este bloque ya
            // usa para la red — el resume re-corre el efecto entero, que es idempotente.
            let residual: [SyncOutbox]
            do {
                residual = try liveOutboxRows()
            } catch {
                CloudSyncBreadcrumb.outboxFetchFailed(step: "leader-reconcile")
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: outboxUnreadable")
            }
            let (buildable, poison) = pushClient.partitionBuildable(residual)
            engine.deadLetterPoison(poison, context: context, now: now())
            if !buildable.isEmpty {
                // Los trozos del push cortan si la confirmación tiene más de `leaseInFlightBudget`: la app congelada a mitad
                // del barrido no puede seguir subiendo con un lease que ya pudo perder.
                let leaseStillConfirmed: @MainActor () -> Bool = { [leaseWitness] in
                    leaseWitness.isConfirmed(within: MigrationWorkExecutor.leaseInFlightBudget)
                }
                guard case .completed(let results) = await pushClient.push(
                    buildable, continueWhile: leaseStillConfirmed) else {
                    // Red → retomable: el 'complete' NO se marca; el resume re-corre este efecto entero
                    // (drain/push idempotentes por LWW + confirmUploaded).
                    throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: sweepTransient")
                }
                await pushClient.applyResults(results, rows: buildable, engine: engine, context: context)
                let rescued = results.filter { $0.status == .applied }.count
                if rescued > 0 {
                    CloudSyncBreadcrumb.migrationLeaderOrphanReconciled(count: rescued)
                    MetricsService.cloudCutoverLeaderOrphanReconciled(count: rescued)
                }
                // Un push que entregó MENOS resultados que filas cortó a mitad: un trozo falló tras otros confirmados, o la
                // confirmación del lease caducó entre dos. Lo confirmado ya se purgó; el resto espera al resume, y el
                // `complete` no sale con trozos sin enviar. (Una fila que el servidor contestó y no aplicó —un `rejected`
                // de upstream— sí cuenta como contestada y la reintenta el runtime tras el cierre, como antes.)
                guard results.count >= buildable.count else {
                    throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: sweepTransient")
                }
            }
            // `migration_progress('complete')` (líder) — SOLO tras el barrido (un kill entre ambos re-corre
            // el barrido, no-op, y reintenta el complete; idempotente).
            guard let jwt = await session.accessToken(), !jwt.isEmpty else {
                CloudSyncBreadcrumb.migrationCutoverRejected(reason: "complete: sessionExpired")
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: sessionExpired")
            }
            switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "complete") {
            case .ok:
                CloudSyncBreadcrumb.migrationReconcileDeferred()
                stampMigrationFinished()
            case .otherLeader:
                CloudSyncBreadcrumb.migrationCutoverOtherLeader()
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: otherLeader")
            case .rejected(let reason):
                CloudSyncBreadcrumb.migrationCutoverRejected(reason: "complete: \(reason)")
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: \(reason)")
            case .sessionExpired:
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: sessionExpired")
            case .transient:
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: transient")
            }

        case .rollback:
            // Pre-cutover el device YA está intacto (el mirror nunca se apagó; el runner limpia los
            // campos scoped al entrar a failedRollback). El "rollback" ES un no-op observable — dejarlo
            // notWired (bug device 2026-07-10) lo dejaba journaled-pendiente para siempre y cada resume
            // re-lanzaba. Defensivo: desarmar mirror-off (no puede estar armado pre-cutover, pero barato).
            storageDefaults.removeObject(forKey: Self.relaunchRequestedKey)
            // Antes del cutover el registro fila → identidad ya no sirve: el teléfono vuelve a iCloud y el motor no drena.
            // Best-effort: si no se borra, queda inerte hasta la siguiente siembra.
            do {
                try RelayIdentityLedger.remove(at: relayIdentityLedgerURL)
            } catch {
                CloudSyncBreadcrumb.relayIdentityLedgerUnavailable(step: "rollback", errorType: String(describing: type(of: error)))
            }
            CloudSyncBreadcrumb.migrationRollbackCompleted()

        case .adoptBackendAccount:
            // §k.4 — CABLEADO en I14 (P6): el flujo de adopt (returning-user sobre cuenta poblada, #30).
            // La máquina ya rutea `existing_stable`/`leaderCompleted` → `notStarted` + este efecto; aquí se
            // ejecuta el trabajo retomable. Ver `runAdoptFlow()`.
            try await runAdoptFlow()

        // Reversa (§h, I11-2) — efectos LOCALES cableados. mountMirrorAndRelaunch cruza el process boundary
        // (espeja disableMirrorAndRelaunch): DESARMA el flag manteniendo `.cloud` → `personalStoreDecision`
        // monta el mirror `.private` al RELANZAR; el forward a reverseMountMirror lo resuelve el runner por
        // OBSERVACIÓN (`isMirrorConfirmedOn`). NO mata el proceso (relaunch asistido = I14).
        case .mountMirrorAndRelaunch:
            storageDefaults.removeObject(forKey: Self.relaunchRequestedKey)
            CloudSyncBreadcrumb.reverseRelaunchRequested()

        case .deleteCloudKitMarker:
            // Borra el `CloudMigrationMarker` del store PERSONAL (el mirror VIVO exporta el delete). Sin él
            // un re-migrate futuro dispararía falso `secondaryDeviceCloudLogin`. Idempotente (0 si no había).
            // Save por DEFECTO (como el insert del marcador en el cutover): el marcador no es entidad de sync
            // (sin syncID) → no ecoa al backend; el mirror sí lo exporta.
            // El fetch RELANZA en fallo (review I11-2): un `try?` aquí saltaba el borrado PERMANENTEMENTE
            // (el efecto no throweaba → se removía del pending → jamás retomado). Throwear lo deja
            // journaled-pendiente y el próximo resume() lo reintenta.
            let markers = try context.fetch(FetchDescriptor<CloudMigrationMarker>())
            for marker in markers { context.delete(marker) }
            if context.hasChanges { try context.save() }
            CloudSyncBreadcrumb.reverseMarkerDeleted(count: markers.count)

        case .clearCloudBeacon:
            beacon.clearCloudAccountLinked()
            CloudSyncBreadcrumb.reverseBeaconCleared()

        case .persistICloudMode:
            // Invariante SERIO 1: `storageMode=.icloud` + `mirrorOffArmed=false` se mueven JUNTOS (dejar
            // `.cloud`+mirror ON, o `.icloud`+armado, sería dual-write). Ambos en el mismo efecto.
            StorageModePersistence.write(.icloud, defaults: storageDefaults)
            storageDefaults.removeObject(forKey: Self.relaunchRequestedKey)
            // #37 (H3 corrida I14): retirar los sentinels del drenaje iKV→outbox (TODOS los userIDs) al
            // volver a `.icloud` — sin esto, una RE-migración de la misma instalación haría skip del
            // drenaje y las keys iKV de la época intermedia (consent incluido) jamás llegarían a
            // `user_preferences`. Efecto LOCAL del cuarteto (nunca depende de red/sesión), kill-safe por
            // journal-then-execute e idempotente (segunda pasada = 0 keys).
            let sentinels = PrefsCutoverDrain.sentinelKeys(
                in: Array(storageDefaults.dictionaryRepresentation().keys))
            for key in sentinels { storageDefaults.removeObject(forKey: key) }
            CloudSyncBreadcrumb.reversePrefsDrainSentinelCleared(count: sentinels.count)
            CloudSyncBreadcrumb.reverseModePersisted()

        // D1 DIFERIDO (review I11-2): la higiene de sync-meta al entrar a `icloudActive`
        // (SyncOutbox/SyncCursor/unit-clocks/quarantine/danglers con estado de la época nube) es inerte en
        // `.icloud` (runtime gateado por `storageMode == .cloud`), pero un re-cutover futuro con
        // cursor/clocks stale podría envenenarse — el diseño de re-cutover (I14+) DEBE decidir purga-vs-reuso.
        case .completeReverseServer:
            // `reverse_complete` (§h, I11-3): `reverse_in_progress=false` + `reverted_at=now()` server-side.
            // `migrated_at` NO se toca (§h.4 — el backend queda congelado como red; `reverted_at` es la
            // señal para el diseño futuro de re-cutover). `.ok` → breadcrumb; el resto THROWEA → queda
            // journaled-pendiente retomable (patrón del complete de la ida en runLeaderReconcile).
            guard let jwt = await session.accessToken(), !jwt.isEmpty else {
                CloudSyncBreadcrumb.reverseCompleteRejected(reason: "sessionExpired")
                throw MigrationExecutorError.notWired(effect: "completeReverseServer: sessionExpired")
            }
            switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "reverse_complete") {
            case .ok:
                CloudSyncBreadcrumb.reverseCompleteConfirmed()
                // g15_01: éste es el ÚNICO punto del sistema donde una cuenta se degrada de
                // `complete` a `groups_only`, y la reversa NO cierra sesión — así que sin este
                // refresco nada invalidaría el tipo cacheado, y la app seguiría creyendo que lo
                // personal vive en la nube justo después de devolverlo a iCloud.
                await AccountKindService.shared.handleReverseCutoverCompleted()
            case .otherLeader:
                CloudSyncBreadcrumb.reverseCompleteRejected(reason: "otherLeader")
                throw MigrationExecutorError.notWired(effect: "completeReverseServer: otherLeader")
            case .rejected(let reason):
                CloudSyncBreadcrumb.reverseCompleteRejected(reason: reason)
                throw MigrationExecutorError.notWired(effect: "completeReverseServer: \(reason)")
            case .sessionExpired:
                CloudSyncBreadcrumb.reverseCompleteRejected(reason: "sessionExpired")
                throw MigrationExecutorError.notWired(effect: "completeReverseServer: sessionExpired")
            case .transient:
                CloudSyncBreadcrumb.reverseCompleteRejected(reason: "transient")
                throw MigrationExecutorError.notWired(effect: "completeReverseServer: transient")
            }

        case .rearmMirrorOff:
            // Salida de `reverseUpload` (ticket `reverse-upload-has-no-ceiling-and-no-exit`): el par ENTERO con su
            // escritor único —`.cloud` y armado—, no el flag suelto. En esta fase el modo ya es `.cloud`, pero un
            // armado con `.icloud` sería la mitad que `derive` lee como «relanza» en bucle (C-1), y escribir los
            // dos cierra esa puerta sin depender de lo que haya. No puede lanzar: `UserDefaults` puro.
            StorageModePersistence.writeCloudArmed(defaults: storageDefaults)
            CloudSyncBreadcrumb.reverseMirrorOffRearmed()

        case .reverseRollback:
            // `reverse_abort` (§h, I11-3): DES-congela el backend (`reverse_in_progress=false` +
            // `reverse_frozen_at=null`; `reverted_at` queda null — la reversa NO ocurrió). El RPC acepta
            // lease expirado (abort de emergencia post-crash largo) y es idempotente con rip ya false.
            // sessionExpired/transient → THROW (journaled, retomable — la red/el re-login lo despiertan).
            // rejected/otherLeader → NO throw perpetuo (decisión I11-3, documentada en el plan): el estado
            // local ya es TERMINAL estable (reverseFailedRollback, o la fase origen tras la salida de
            // `reverseUpload`); un abort rechazado por lease usurpado
            // dejaría el efecto journaled-pendiente PARA SIEMPRE re-lanzando en cada resume (el mismo
            // bug-class del rollback de la ida, device 2026-07-10) → breadcrumb RUIDOSO + completar. El
            // backend puede quedar rip=true: un `reverse_claim` posterior es idempotente-ok (o el nuevo
            // líder sigue su propia reversa — su estado manda).
            guard let jwt = await session.accessToken(), !jwt.isEmpty else {
                throw MigrationExecutorError.notWired(effect: "reverseRollback: sessionExpired")
            }
            switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "reverse_abort") {
            case .ok:
                CloudSyncBreadcrumb.reverseAborted()
            case .sessionExpired:
                throw MigrationExecutorError.notWired(effect: "reverseRollback: sessionExpired")
            case .transient:
                throw MigrationExecutorError.notWired(effect: "reverseRollback: transient")
            case .otherLeader:
                CloudSyncBreadcrumb.reverseAbortRejectedButCompleted(reason: "otherLeader")
            case .rejected(let reason):
                CloudSyncBreadcrumb.reverseAbortRejectedButCompleted(reason: reason)
            }
        }
    }

    /// Observación post-relaunch (§g.4): ¿ESTE proceso montó el store personal SIN mirror de CloudKit?
    /// Testigo de arranque (`SwiftDataConfiguration.personalStoreMountedDecision`), NO lo persistido: en
    /// la misma sesión, tras `persistLocalMode`, el mirror SIGUE vivo (se montó al arrancar) → esto queda
    /// `false` hasta el RELANZAMIENTO, cuando un proceso nuevo monta `.none` y captura `.cloudMirrorOff`.
    ///
    /// R1: la pregunta se hace por el EJE del mirror y no comparando el testigo con `.cloud`. `localNoMirror`
    /// sigue dando `false` —el mirror está adjunto ahí, MEDIDO— igual que antes del cambio.
    func isMirrorConfirmedOff() -> Bool {
        !SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror
    }

    /// Gate de EXPORT del marcador (§g.4 ajuste, entre paso 3 y 4): ¿el `CloudMigrationMarker` LLEGÓ a
    /// CloudKit? Reusa `CKIdentityCapture` sobre la fila del marcador (`ZCKRECORDNAME` non-NULL = exportado).
    /// El save del marcador exporta ASYNC — apagar el mirror antes lo perdería para siempre (los 2º devices
    /// jamás se auto-bloquearían = divergencia silenciosa). Señal S5-validada, necesaria-no-suficiente
    /// (residual documentado; el guion device lo re-verifica en CloudKit Console). `false` si no hay
    /// marcador o su recordName sigue NULL.
    func isMarkerExported() -> Bool {
        let markers: [CloudMigrationMarker]
        do {
            markers = try context.fetch(FetchDescriptor<CloudMigrationMarker>())
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor: fetch(CloudMigrationMarker) falló: \(error)")
            #endif
            return false
        }
        guard !markers.isEmpty else { return false }
        // Testigo SCRATCH por fila (NUNCA insertado): `capture` solo muta la fila en `.captured` y devuelve
        // el Report agregado — `captured >= 1` ⇒ al menos un marcador con recordName non-NULL (exportado).
        let pairs = markers.map {
            (id: $0.persistentModelID,
             row: SyncIdentity(syncID: UUID(), entityType: "CloudMigrationMarker", localAnchor: ""))
        }
        let report = CKIdentityCapture.capture(pairs, storeURL: personalStoreURL)
        return report.captured >= 1
    }

    /// C-1: veredicto del canal iCloud por el que el marcador TIENE que viajar. Read-only, SIN red — combina
    /// la presencia de cuenta iCloud, la huella CloudKit local del corpus y el último `CKError` que el mirror
    /// haya reportado. Decisión en `ICloudCutoverGateLogic` (pura y testeada aparte); aquí solo se recogen las
    /// tres señales.
    ///
    /// La huella se lee de `SyncIdentity.ckRecordName != nil` (mismo predicado que ya usa el panel de debug):
    /// es DURABLE — vive en el SQLite local y sobrevive a que el usuario cierre iCloud —, así que distingue
    /// "nunca hubo copia en CloudKit" de "hay copia y ahora no puedo alcanzarla", que es justo la diferencia
    /// entre poder waivear el gate del marcador y no poder.
    func probeICloudChannel() async -> ICloudChannelVerdict {
        let footprint: Bool
        do {
            let descriptor = FetchDescriptor<SyncIdentity>(
                predicate: #Predicate<SyncIdentity> { $0.ckRecordName != nil })
            footprint = try context.fetchCount(descriptor) > 0
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor: Error: huella CloudKit no legible: \(error)")
            #endif
            // CONSERVADOR: asumir que SÍ hay copia en CloudKit. Un falso `false` waivearía el gate del
            // marcador a ciegas y dejaría al parque sin aviso; un falso `true` solo bloquea la entrada.
            footprint = true
        }
        return ICloudCutoverGateLogic.decide(
            accountPresent: icloudAccountPresent(),
            hasCloudKitFootprint: footprint,
            lastExportErrorCode: icloudLastExportErrorCode())
    }

    /// `SyncCursor.serverSeqCursor` actual (corte del marcador). Sin fila aún → 0. Lectura pura (no crea).
    private func currentServerSeqCut() -> Int64 {
        do {
            var descriptor = FetchDescriptor<SyncCursor>()
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.serverSeqCursor ?? 0
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor: fetch(SyncCursor) para serverSeqCut falló: \(error)")
            #endif
            return 0
        }
    }

    // MARK: - Reversa (§h, I11-2)

    /// `reverse_claim` (§h, I11-3): reserva del liderazgo de la REVERSA server-side (RPC
    /// `migration_progress`, action `reverse_claim`). Guards server-side: `kind = 'complete'` **o**
    /// `reverted_at` no nulo (si ninguna, `rejected("not_complete")` — g15_02: born-cloud SÍ entra; la
    /// cuenta de solo grupos que nunca revirtió no, porque no tiene nada personal que devolver; y la ya
    /// revertida SÍ, porque su 2.º dispositivo necesita recorrer su propia vuelta), takeover de migración
    /// ABANDONADA o reversa ajena con lease expirado
    /// >60min, re-claim idempotente del MISMO líder sin chequear edad. Sin JWT → `.transient` si el SDK conserva la
    /// sesión, `.sessionExpired` si la borró (el runner corta SIN evento en los dos; solo el segundo deja rastro para
    /// la pantalla). NUNCA lanza — los breadcrumbs de outcome los emite el runner (`driveReverseClaim`), **salvo los
    /// dos de esta puerta**: solo aquí se sabe cuál de las dos causas dejó el token sin llegar.
    func performReverseClaim() async -> ReverseClaimOutcome {
        guard let jwt = await session.accessToken(), !jwt.isEmpty else {
            // El token que no llega tiene DOS causas y la pantalla las trata distinto: si el SDK conserva la sesión
            // guardada, la renovación no volvió (sin red, un 5xx del servidor de auth) y esperar lo arregla; solo si
            // la BORRÓ hay que volver a entrar. Molde de `SyncPushClient.push`, y el mismo falso positivo que cerró
            // `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`: sin él, quedarse sin cobertura a
            // mitad de la vuelta pediría iniciar sesión, que no es lo que falta. El SDK borra la sesión ANTES de
            // lanzar, así que se lee DESPUÉS del `await`.
            guard !session.canRenewSession else {
                CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "reverse: token unavailable, session kept")
                return .transient
            }
            CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "reverse: sessionExpired")
            return .sessionExpired
        }
        switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "reverse_claim") {
        case .ok:
            return .accepted
        case .otherLeader:
            return .otherLeader
        case .rejected(let reason):
            return .rejected(reason: reason)
        case .sessionExpired:
            return .sessionExpired
        case .transient:
            return .transient
        }
    }

    /// `reverseDrainAll` (§h): drain de la History local → outbox, push del residual, y `pullAndApplyOnce`
    /// (pull FINAL). Reusa las piezas de `verify()` (partición poison + push + apply). Red → `.transient`; una sesión
    /// que ya no vale → `.sessionExpired`, que el runner deja ver en la pantalla (ticket
    /// `reverse-before-mount-stays-stuck-with-an-expired-session`).
    ///
    /// **El token que no llega sin red NO cae aquí**: lo separan `SyncPushClient` y `SyncPullClient` con su
    /// `canRenewSession` (desde `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`), y lo mismo el 401
    /// `yala_attest_required`. Los dos llegan como `.transient`. Por eso este paso no repite esa puerta: si algún día
    /// se construyen esos clientes sin `canRenewSession`, el default `{ false }` volvería a decir aquí «vuelve a
    /// entrar» a quien solo está sin cobertura — lo fija `AttestWiringTests`.
    ///
    /// `.accountUnavailable` (403, cuenta suspendida) **sale tipado desde el 2026-09-21** (ticket
    /// `reverse-before-mount-has-no-way-to-abandon-the-return`): sigue sin ofrecer «Iniciar sesión» —no es una sesión
    /// que renovar— pero ya no se confunde con la red, porque es lo que elige el techo CORTO de esta etapa. Hasta ese
    /// día se quedaba en `.transient` y la vuelta se paraba aquí sin salida.
    func reverseDrainOnce() async -> ReverseStepOutcome {
        // Sin drain completo no se da por drenado: lo siguiente es CONGELAR el backend (mismo porqué que el outbox
        // ilegible de abajo; ticket `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read`).
        guard engine.drainOnce(context: context) else { return .blocked(.localFailure) }
        // Igual que en `verify()`, y aquí el precio es mayor: con `[]` esta fase podía devolver `.completed` sin
        // haber subido nada, y lo siguiente que hace la vuelta es CONGELAR el backend. O sea, dar por drenado un
        // outbox que nadie pudo leer y cerrar la puerta detrás (ticket
        // `verify-reads-a-failed-local-fetch-as-an-empty-outbox`).
        let allLive: [SyncOutbox]
        do {
            allLive = try liveOutboxRows()
        } catch {
            CloudSyncBreadcrumb.outboxFetchFailed(step: "reverse-drain")
            return .blocked(.localFailure)
        }
        let (live, poison) = pushClient.partitionBuildable(allLive)
        engine.deadLetterPoison(poison, context: context, now: now())
        if !live.isEmpty {
            switch await pushClient.push(live) {
            case .completed(let results):
                await pushClient.applyResults(results, rows: live, engine: engine, context: context)
            case .sessionExpired:
                return .sessionExpired
            case .accountUnavailable:
                return .blocked(.accountUnavailable)
            case .transient:
                return .transient
            }
        }
        switch await engine.pullAndApplyOnce(using: pullClient, context: context, now: now()) {
        case .completed:
            return .completed
        case .sessionExpired:
            return .sessionExpired
        case .accountUnavailable:
            return .blocked(.accountUnavailable)
        case .busy, .transient:
            return .transient
        }
    }

    /// `reverseFreezeBackend` (§h, I11-3): `reverse_freeze` server-side — estampa `reverse_frozen_at`
    /// (guard reverse-líder SIN edad de lease: el MISMO líder lento siempre puede continuar; idempotente).
    /// `.ok` → `.completed`; la red y la sesión → breadcrumb + corte retomable SIN evento; `otherLeader` y `rejected`
    /// → `.blocked`, que es lo que elige el techo CORTO de la etapa (ticket
    /// `reverse-before-mount-has-no-way-to-abandon-the-return`; hasta el 2026-09-21 los dos colapsaban en
    /// `.transient`, y este paso era el único de las cuatro fases sin ninguna salida). **Devolvía `Bool`** hasta el ticket
    /// `reverse-before-mount-stays-stuck-with-an-expired-session`: ese `false` único metía en el mismo saco la red y
    /// una sesión que solo la persona puede renovar, y la barra se quedaba muda al 62 %. El
    /// ENFORCEMENT del freeze en `/sync/push` está ACTIVO (cerrado 2026-07-11): el gateway rechaza 409
    /// `yala_account_reverting` los pushes con `reverse_frozen_at` set. NO afecta a esta reversa: todos
    /// sus pushes (`reverseDrainOnce`) ocurren ANTES de este freeze (ver qa/cloud/README.md). NUNCA lanza.
    ///
    /// `/account/migration` NO exige App Attest (ver la cabecera de `CloudAccountClient`), así que su 401 es siempre
    /// el JWT: aquí no hay que separar el segundo 401 que sí tienen `/sync/*` y `/prefs/*`.
    func freezeBackendForReverse() async -> ReverseStepOutcome {
        guard let jwt = await session.accessToken(), !jwt.isEmpty else {
            // Las dos causas del token ausente, como en `performReverseClaim`: con la sesión guardada es la renovación
            // que no volvió (sin red) y esperar la arregla; sin ella hay que volver a entrar.
            guard !session.canRenewSession else {
                CloudSyncBreadcrumb.reverseFreezeRejected(reason: "token unavailable, session kept")
                return .transient
            }
            CloudSyncBreadcrumb.reverseFreezeRejected(reason: "sessionExpired")
            return .sessionExpired
        }
        switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "reverse_freeze") {
        case .ok:
            CloudSyncBreadcrumb.reverseBackendFrozen()
            return .completed
        case .otherLeader:
            CloudSyncBreadcrumb.reverseFreezeRejected(reason: "otherLeader")
            return .blocked(.otherLeader)
        case .rejected(let reason):
            CloudSyncBreadcrumb.reverseFreezeRejected(reason: reason)
            return .blocked(.refused)
        case .sessionExpired:
            CloudSyncBreadcrumb.reverseFreezeRejected(reason: "sessionExpired")
            return .sessionExpired
        case .transient:
            CloudSyncBreadcrumb.reverseFreezeRejected(reason: "transient")
            return .transient
        }
    }

    /// Observación post-relaunch (§h): ¿ESTE proceso montó el store personal CON el mirror adjunto?
    /// Testigo de arranque (`personalStoreMountedDecision`), NO lo persistido — análogo INVERSO de
    /// `isMirrorConfirmedOff`. CONTRATO I11-2 (machine doc): el default del testigo es `.iCloudMirror` → un
    /// read real reportaría "montado SIEMPRE" = false green → los tests FAKEAN esta observación (no usan el
    /// real).
    func isMirrorConfirmedOn() -> Bool {
        SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror
    }

    /// §h.3 `deletingZombies` — EL NÚCLEO. Enumera tombstones del backend en LECTURA PURA (`pullPage`, SIN
    /// applyPage/cursor/testigos), los agrupa por TABLA, y para cada tabla afectada BORRA en UN fetch + match
    /// en memoria las filas VIVAS que los porten (nunca un fetch por tombstone; reusa `EntityApplyMap`). El
    /// `save()` va bajo `outboxSaveAuthor` (AUTOR ANTI-ECO): el barrido ES un apply de tombstones del backend
    /// → sin él un `drainOnce` futuro re-emitiría los deletes como tombstones al backend congelado. El mirror
    /// exporta el delete igual (NSPersistentCloudKitContainer no filtra por autor; solo nuestro drain).
    /// Caso normal (token vigente): 0 filas vivas tombstoneadas → no-op idempotente. Red del pull → `.transient`.
    /// Una tabla que no se deja leer (o el save) → rollback + `.transient`: nunca «0 borradas» por avería.
    func sweepZombies(sinceSeq: Int64) async -> ZombieSweepOutcome {
        var tombstonesByTable: [String: Set<UUID>] = [:]
        var cursor = sinceSeq
        pageLoop: while true {
            switch await tombstoneSource.pullPage(since: cursor, limit: 500) {
            case let .page(page):
                for delta in page.deltas where delta.op == .tombstone {
                    tombstonesByTable[delta.entityType, default: []].insert(delta.syncID)
                }
                let next = max(page.maxServerSeq, cursor)
                if page.deltas.isEmpty || next <= cursor { break pageLoop }  // agotado / sin progreso
                cursor = next
            case .sessionExpired, .accountUnavailable, .transient:
                return .transient
            }
        }
        guard !tombstonesByTable.isEmpty else { return .completed(deleted: 0) }
        var totalDeleted = 0
        do {
            try engine.saveWithAuthor(context, CloudSyncEngine.outboxSaveAuthor) {
                // Orden por tabla: determinista (si una tabla lanza, las anteriores son siempre las mismas).
                for (table, ids) in tombstonesByTable.sorted(by: { $0.key < $1.key }) {
                    totalDeleted += try EntityApplyMap.deleteLiveRows(table: table, syncIDs: ids, context: context)
                }
            }
        } catch {
            // Save fallido o tabla ilegible: nada del barrido cuenta. Rollback OBLIGATORIO — si lanzó a
            // mitad, las tablas anteriores dejaron deletes dirty que un autosave flushearía bajo autor
            // NO-motor (eco al outbox). `.transient` → el runner reintenta este sub-estado.
            context.rollback()
            CloudSyncBreadcrumb.applyPageFailed(reason: "sweepZombies:\(error)")
            #if DEBUG
            print("MigrationWorkExecutor.sweepZombies: barrido no hecho (rollback): \(error)")
            #endif
            return .transient
        }
        return .completed(deleted: totalDeleted)
    }

    /// §h.3 `rebindingUUIDs`: VERIFICACIÓN (v1, sin deletes — recordName≠UUID de dominio, S5: el rebind es un
    /// update de campo `CD_syncID` sobre el MISMO CKRecord que el replay del mirror exporta). Cuenta las
    /// identidades con `lastReboundAt != nil` cuya fila viva sigue portando su `syncID` (regla `899c1c25` ya
    /// reconstruyó los mirrors). Si una fila rebound NO existe viva, la cubre el barrido de zombies (tombstone).
    func verifyRebinds() -> Int {
        do {
            let rebound = try context.fetch(FetchDescriptor<SyncIdentity>()).filter { $0.lastReboundAt != nil }
            return rebound.reduce(0) { acc, row in
                EntityApplyMap.liveRowExists(entityTypeName: row.entityType, syncID: row.syncID, context: context)
                    ? acc + 1 : acc
            }
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor.verifyRebinds: fetch(SyncIdentity) falló: \(error)")
            #endif
            return 0
        }
    }

    /// §h.3 `dedupHealed`: AUTO-CURA (I11-4) de copias idénticas de Account/Tag por identidad de contenido —
    /// el mismo detonante que duplicó subcategorías (regeneración masiva de `shortcutID`/`id`). Fusiona cada
    /// grupo duplicado en un ganador determinista, re-apunta las referencias del perdedor y lo borra
    /// (`AccountTagMergeService`, autor DEFECTO → el tombstone del perdedor viaja al backend/mirror). Devuelve
    /// el nº total de filas PERDEDORAS curadas. La quiescencia la GARANTIZÓ el runner (`dedupHealed` corre
    /// post-`awaitingQuiescence`). Idempotente: una 2ª pasada devuelve 0. I11-2 era DETECCIÓN read-only; I11-4
    /// promueve a cura (el sub-estado ya era journaled).
    func healDuplicates() -> Int {
        // `AccountTagMergeService` EXCLUYE `isSystemAccount` (mergearlas tocaría Grupos) y no cubre
        // subcategorías → el pase de política v1 las complementa por otra vía (cuentas `Grupos [moneda]` +
        // balanceAdjustment cross-idioma; autor DEFAULT → el tombstone viaja). Ambos son idempotentes.
        let system = CloudSyncReconciler.reconcileSystemEntities(context: context)
        return AccountTagMergeService.mergeDuplicateAccounts(in: context)
            + AccountTagMergeService.mergeDuplicateTags(in: context)
            + system.accountsMerged + system.subcategoriesMerged
    }

    /// Techo de `reverseUpload`: por qué no drena la subida, con las tres señales del canal iCloud. Decisión en
    /// `ReverseUploadBlockerLogic` (pura y testeada aparte); aquí solo se recogen. Read-only y sin red.
    func reverseUploadBlocker() -> ReverseUploadBlocker {
        ReverseUploadBlockerLogic.decide(
            icloudAvailable: icloudAccountPresent(),
            lastExportErrorCode: icloudLastExportErrorCode(),
            lastExportErrorAt: icloudLastExportErrorAt(),
            lastSuccessfulExportAt: icloudLastSuccessfulExportAt(),
            mirrorReportedNotAuthenticated: icloudMirrorReportedNotAuthenticated())
    }

    /// §h `reverseUpload`: muestreo CKIdentityCapture sobre TODAS las filas vivas. `exportPending + noMetadata
    /// == 0` ⇒ `.drained` (`noMetadata` cuenta como pendiente: un insert del replay que el mirror aún no
    /// procesó); si no, `.pending(count)`. §h.6 pto 3: `capture` MUTA los testigos `.captured` con las
    /// coordenadas frescas — eso ES "los SyncIdentity se ACTUALIZAN durante reverseUpload" (una futura 2ª
    /// reversa ya es variante migrado con mapa poblado) → se PERSISTE (quiescencia garantizada por el runner).
    ///
    /// Una muestra que no pudo leer una tabla es `.unreadable`: ni cierra la vuelta ni vale como avance (ticket
    /// `an-incomplete-inventory-reads-as-the-whole-corpus`). Sale antes del canario de huérfanas, que es informativo.
    func reverseUploadStatus() -> ReverseUploadStatus {
        let pairs: [(id: PersistentIdentifier, row: SyncIdentity)]
        do {
            pairs = try collectReverseUploadPairs()
        } catch {
            return .unreadable
        }
        let report = CKIdentityCapture.capture(pairs, storeURL: personalStoreURL)
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                #if DEBUG
                print("MigrationWorkExecutor.reverseUploadStatus: save de captura falló: \(error)")
                #endif
            }
        }
        // Canario v1 SIN reparación (§h residual): scan read-only de metadata HUÉRFANA (zombie por History
        // purgada). SOLO informativo — NO altera `.drained`/`.pending`. Abre una 2ª conexión SQLite read-only
        // (aceptable en la reversa; NO se refactoriza la conexión compartida en este incremento).
        let orphanReport = CKIdentityCapture.scanOrphanMetadata(
            liveByEntityName: Self.collectLiveByEntityName(
                context: context, throwingOn: { [weak self] in self?._testInventoryFetchThrows?("reverse-live-rows", $0) == true }),
            storeURL: personalStoreURL)
        CloudSyncBreadcrumb.reverseOrphanMetadata(count: orphanReport.orphans)
        let pending = report.exportPending + report.noMetadata
        return pending == 0 ? .drained : .pending(count: pending)
    }

    /// `[entityName: Set<Z_PK vivos>]` de las 16 entidades sync para `CKIdentityCapture.scanOrphanMetadata`.
    /// CONTRATO (RP-4): las 16 keys SIEMPRE presentes (Set vacío si 0 filas vivas) — sin filas vivas de `Tag`,
    /// una metadata de Tag post-purga ES huérfana real y debe contarse; y metadata de entidades NO cableadas
    /// (p.ej. `CloudMigrationMarker`) se ignora por key AUSENTE. VIVOS = TODAS las filas vivas del store (NO se
    /// reusa `collectIdentityPairs`: ese empareja por testigo `SyncIdentity` y una fila viva sin syncID contaría
    /// como huérfana → falso positivo R6). `static` para que el panel DEBUG (I11-5) lo reuse.
    ///
    /// **Excepción al contrato, desde `an-incomplete-inventory-reads-as-the-whole-corpus`:** una tabla que no se deja
    /// leer se queda SIN key. Con el `Set` vacío de antes, toda su metadata contaba como huérfana y el canario se
    /// inflaba con una avería de lectura; sin key se ignora, que es lo honesto cuando no se sabe qué está vivo.
    /// `throwingOn` es el seam de tests del ejecutor (nombre de clase → ¿su fetch lanza?); producción no lo pasa.
    static func collectLiveByEntityName(
        context: ModelContext, throwingOn: (String) -> Bool = { _ in false }
    ) -> [String: Set<Int64>] {
        var out: [String: Set<Int64>] = [:]
        addLiveRows(TransactionItem.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(InboxDraft.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(Category.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(FavoritePayment.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(MerchantMemory.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(ExchangeRate.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(Budget.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(ScheduledPayment.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(Account.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(Subcategory.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(Tag.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(NotificationItem.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(CashFlowPlan.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(CashFlowLine.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(CashFlowOverride.self, into: &out, context: context, throwingOn: throwingOn)
        addLiveRows(GroupBridgePreference.self, into: &out, context: context, throwingOn: throwingOn)
        return out
    }

    /// Fetch CONCRETO por tipo (regla `#Predicate`). La key es el nombre de entidad Core Data (= nombre de
    /// clase `@Model`) y se inserta siempre que la tabla se leyó (Set vacío si 0 filas), por el contrato de RP-4; la
    /// tabla ilegible se queda sin key (ver `collectLiveByEntityName`). El `Z_PK`
    /// se extrae del `PersistentIdentifier` (URI → parse), consistente con el camino de captura.
    private static func addLiveRows<M: PersistentModel>(
        _ type: M.Type, into out: inout [String: Set<Int64>], context: ModelContext, throwingOn: (String) -> Bool
    ) {
        let name = String(describing: M.self)
        var set = out[name] ?? []
        do {
            // El seam va DENTRO del `do`: el camino que recorre el test es el `catch` real.
            if throwingOn(name) { throw CocoaError(.fileReadCorruptFile) }
            for model in try context.fetch(FetchDescriptor<M>()) {
                if let zpk = CKIdentityCapture.entityAndPK(for: model.persistentModelID)?.zpk {
                    set.insert(zpk)
                }
            }
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor.collectLiveByEntityName: fetch(\(M.self)) falló: \(error)")
            #endif
            CloudSyncBreadcrumb.migrationInventoryReadFailed(step: "reverse-live-rows", entity: name)
            return  // SIN key: ilegible no es «sin filas vivas» (ver el docblock de `collectLiveByEntityName`)
        }
        out[name] = set  // key presente siempre que se leyó (contrato RP-4)
    }

    // MARK: - Heartbeat del lease (I14-pre, residual pendiente #3)

    /// `migration_progress('heartbeat')` — refresca `profiles.migration_updated_at` (lease de 60 min) MIENTRAS
    /// un paso largo progresa (upload de corpus grande; drain de la reversa sobre una época nube grande) para
    /// que el líder NO quede usurpable a mitad de trabajo. Sirve a la ida Y a la reversa (una sola acción; el
    /// RPC decide por `migration_in_progress OR reverse_in_progress`, guard SIN edad de lease — el mismo líder
    /// lento siempre puede latir).
    ///
    /// BEST-EFFORT ABSOLUTO — la firma NO lanza (garantía de compilador) y NUNCA altera el outcome del paso
    /// que lo invoca: esa propiedad es lo que hace SEGURO commitear el cliente ANTES de desplegar la acción al
    /// RPC (pre-deploy el Worker devuelve 400/el RPC no la entiende → breadcrumb y sigue). Un `other_leader`
    /// aquí NO corta el paso. **En la ida ya no la llama nadie** desde el ticket
    /// `displaced-migration-leader-keeps-uploading-after-a-takeover`: la subida pasa por `confirmMigrationLease`, que late
    /// con la misma cadencia y SÍ lee la respuesta. Queda para la vuelta a iCloud (el drenaje y `reverseUpload`), donde
    /// el guard del lease sigue viviendo en freeze/complete.
    ///
    /// Throttle: el runner llama por-página, pero solo se emite a lo sumo un request por `heartbeatInterval`.
    /// El throttle se arma para CUALQUIER outcome (incluida red caída) — evita martillar el endpoint cuando el
    /// server rechaza o no responde.
    func sendLeaseHeartbeatIfDue() async {
        if let last = lastHeartbeatAt, now().timeIntervalSince(last) < heartbeatInterval { return }
        // Sin JWT → sin request (ni arma el throttle): el paso que sigue reportará sessionExpired por su
        // propio camino; un re-login despierta el heartbeat en el próximo tick.
        guard let jwt = await session.accessToken(), !jwt.isEmpty else { return }
        lastHeartbeatAt = now()
        switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "heartbeat") {
        case .ok:
            CloudSyncBreadcrumb.migrationLeaseHeartbeat()
        case .otherLeader:
            CloudSyncBreadcrumb.migrationLeaseHeartbeatRejected(reason: "otherLeader")
        case .rejected(let reason):
            CloudSyncBreadcrumb.migrationLeaseHeartbeatRejected(reason: reason)
        case .sessionExpired:
            CloudSyncBreadcrumb.migrationLeaseHeartbeatRejected(reason: "sessionExpired")
        case .transient:
            CloudSyncBreadcrumb.migrationLeaseHeartbeatRejected(reason: "transient")
        }
    }

    /// La PUERTA del lease de la ida (ticket `displaced-migration-leader-keeps-uploading-after-a-takeover`). El runner la
    /// llama antes de cada página de la subida y de cada verificación, y solo sube con `.held`.
    ///
    /// **Una confirmación vale una ventana (`heartbeatInterval`, 60 s)** contada desde que se PIDIÓ: el servidor estampa el
    /// lease después de recibir la pregunta, así que nadie puede tomar el relevo antes de 60 min desde ese instante, y 60 s
    /// dejan 59 min de margen a la página que sale detrás. Fuera de la ventana pregunta en el acto, sin throttle: el de
    /// `sendLeaseHeartbeatIfDue` se arma también con un rechazo, y aquí un rechazo no puede silenciar la pregunta siguiente.
    ///
    /// **`not_in_progress` es `.lost`**, no un rechazo cualquiera: el RPC mira «¿hay migración en curso?» antes que
    /// «¿quién lidera?», así que es lo que recibe este teléfono cuando quien tomó el relevo ya terminó. En la subida no
    /// llega por otro camino: la migración la abrió el claim de este mismo teléfono, y solo otro la cierra.
    ///
    /// La sesión se lee DESPUÉS de pedir el token, como en el resto del ejecutor: el SDK la borra dentro de la renovación.
    func confirmMigrationLease() async -> MigrationLeaseCheck {
        if leaseWitness.isConfirmed(within: .seconds(heartbeatInterval)) {
            return .held
        }
        guard let jwt = await session.accessToken(), !jwt.isEmpty else {
            let renewable = session.canRenewSession
            CloudSyncBreadcrumb.migrationLeaseUnconfirmed(reason: renewable ? "noToken" : "sessionExpired")
            return renewable ? .unconfirmed : .sessionExpired
        }
        let askedAt = leaseWitness.now()
        switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "heartbeat") {
        case .ok:
            leaseWitness.confirm(askedAt: askedAt)
            CloudSyncBreadcrumb.migrationLeaseHeartbeat()
            return .held
        case .otherLeader:
            CloudSyncBreadcrumb.migrationLeaseHeartbeatRejected(reason: "otherLeader")
            return .lost
        case .rejected(let reason):
            CloudSyncBreadcrumb.migrationLeaseHeartbeatRejected(reason: reason)
            return reason == "not_in_progress" ? .lost : .unconfirmed
        case .sessionExpired:
            let renewable = session.canRenewSession
            CloudSyncBreadcrumb.migrationLeaseUnconfirmed(reason: renewable ? "http401" : "sessionExpired")
            return renewable ? .unconfirmed : .sessionExpired
        case .transient:
            CloudSyncBreadcrumb.migrationLeaseUnconfirmed(reason: "transient")
            return .unconfirmed
        }
    }

    // MARK: - El lease después del cutover

    /// Quién lleva la migración cuando el líder vuelve al reconcile de `done` (ticket
    /// `leader-displaced-after-the-cutover-pushes-its-residual-in-the-reconcile`).
    enum PostCutoverLease: Equatable {
        /// Este teléfono sigue liderando, con el lease recién confirmado: sube su residual y manda `complete`.
        case leads
        /// La migración la cerró ESTE teléfono: su `complete` llegó y se perdió la respuesta.
        case finishedHere
        /// La migración la cerró OTRO dispositivo, o la cuenta volvió a iCloud: este teléfono se une como uno más.
        case finishedElsewhere
        /// Otro dispositivo lidera con el lease vivo: se espera sin subir nada.
        case otherLeads
        /// No se pudo saber: red, 5xx, un 401 con la sesión guardada o un rechazo que no habla del líder.
        case unconfirmed
        /// Sin token y el SDK ya no conserva una sesión que renovar.
        case sessionExpired
    }

    /// La pregunta que el reconcile de `done` hace antes de subir nada. Sin el lease confirmado, averigua quién cerró la
    /// migración SIN subir nada, en tres pasos, porque el latido no los distingue. Lo único que escribe en el servidor es lo
    /// que escribe un claim: con `existing_stable`, `personal_adopted_at` (g16_02), que es verdad —este teléfono entra en la
    /// cuenta—:
    ///  1. `heartbeat` (`confirmMigrationLease`). `ok` → `.leads`. Su `.lost` junta `other_leader` y `not_in_progress`,
    ///     y ese segundo es AMBIGUO aquí: también lo recibe este teléfono si su propio `complete` llegó y la respuesta se
    ///     perdió. Por eso no sale nada todavía;
    ///  2. `complete`: el RPC mira el líder antes que nada y es idempotente para él, así que `ok` solo lo contesta si este
    ///     teléfono sigue siendo el líder de una migración cerrada → `.finishedHere`. `other_leader` → sigue;
    ///  3. `claim` con `migration: true`, DIRECTO al cliente y no por `performClaim`, que estamparía el sello del claim:
    ///     `created` → quien tomó el relevo lo dejó caducar y este teléfono vuelve a liderar, el mismo relevo que se le dio
    ///     a él (se confirma con otro latido, que arma el testigo de los trozos del push); `claiming_in_progress` → el otro
    ///     sigue vivo → `.otherLeads`; `existing_stable` → la migración ya no está en curso: la cerró otro, o la cuenta
    ///     vuelve o volvió a iCloud (el push del runtime recibirá entonces el 409 de cuenta revirtiendo, como cualquier
    ///     otro dispositivo) → `.finishedElsewhere`. Que `complete` de quien no lidera conteste `other_leader` aunque la
    ///     migración esté cerrada está medido en el cuerpo vivo (md5 `14fc5e2c…`: la ida mira el líder antes que nada).
    /// **Desde g16_04 (2026-09-24) el servidor ya no da el relevo después del cutover** (ticket
    /// `claim-grants-a-takeover-after-the-leader-passed-the-cutover`): con `migrated_at` puesto y el lease vencido, quien
    /// llega recibe `existing_stable` y el líder no cambia. Así que este teléfono, que hizo el cutover, solo pierde el
    /// lease ante una vuelta a iCloud, y en el paso 3 solo llega `existing_stable`. `created` y `claiming_in_progress`
    /// quedan para un servidor sin g16_04 o una fila anterior a él: se conservan porque el cliente no sabe qué servidor
    /// le contesta.
    /// La sesión se lee DESPUÉS de cada petición, como en el resto del ejecutor.
    func resolvePostCutoverLease() async -> PostCutoverLease {
        switch await confirmMigrationLease() {
        case .held: return .leads
        case .unconfirmed: return .unconfirmed
        case .sessionExpired: return .sessionExpired
        case .lost: break
        }
        guard let jwt = await session.accessToken(), !jwt.isEmpty else {
            return session.canRenewSession ? .unconfirmed : .sessionExpired
        }
        switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "complete") {
        case .ok:
            return .finishedHere
        case .otherLeader:
            break
        case .rejected(let reason):
            CloudSyncBreadcrumb.migrationCutoverRejected(reason: "postCutoverComplete: \(reason)")
            return .unconfirmed
        case .sessionExpired:
            return session.canRenewSession ? .unconfirmed : .sessionExpired
        case .transient:
            return .unconfirmed
        }
        switch await accountClient.claim(jwt: jwt, deviceID: deviceID, provider: provider(), migration: true) {
        case .success(.created):
            CloudSyncBreadcrumb.migrationPostCutoverLeaseResolved(outcome: "retaken")
            MetricsService.cloudPostCutoverLeaseLost(outcome: "retaken")
            return await confirmMigrationLease() == .held ? .leads : .unconfirmed
        case .success(.claimingInProgress):
            return .otherLeads
        case .success(.existingStable):
            return .finishedElsewhere
        case .sessionExpired:
            return session.canRenewSession ? .unconfirmed : .sessionExpired
        case .accountUnavailable, .transient:
            return .unconfirmed
        }
    }

    /// La migración de esta cuenta ya no está a medias: el sello pasa a `.routeReturningUser`, el de quien ya tiene la
    /// cuenta. `.proceedMigration` es lo que deja a «Migrar a la nube» reintentar un intento que falló
    /// (`StorageMigrationIdentityGateLogic.check`), y con una migración TERMINADA dejaba pasar la comprobación hasta el
    /// claim, que la paraba igual pero tras el consentimiento. El runtime arranca con los dos.
    private func stampMigrationFinished() {
        if let userID = session.currentUserID {
            claimStore.record(.routeReturningUser, forUserID: userID)
        }
        markRelayIdentityLedgerRetirable()
    }

    /// Con la migración cerrada, el registro fila → identidad ya no hace falta en cuanto el motor drene lo que quede: la marca
    /// le deja borrarlo tras su siguiente drain completo (`RelayIdentityLedger`). **Salvo si la restauración de este reconcile
    /// no pudo leer los metadatos de CloudKit** (`relayIdentityRecordsTolerated`): entonces pudo quedar alguna fila VIVA con la
    /// identidad del líder, y el registro es lo único que traduciría su borrado. Se queda, inerte para el resto.
    private func markRelayIdentityLedgerRetirable() {
        guard !relayIdentityRecordsTolerated else { return }
        do {
            try RelayIdentityLedger.markRetirable(relayIdentityLedgerURL)
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor: marcar el registro de identidades del relevo como retirable falló: \(error)")
            #endif
            CloudSyncBreadcrumb.relayIdentityLedgerUnavailable(step: "mark", errorType: String(describing: type(of: error)))
        }
    }

    // MARK: - Adopt-reconcile (DIFERIDOS #30, mecanismo v1 DARK)

    /// Rescata al backend las filas HUÉRFANAS de la ventana de cutover (identidad local ∉ backend) cuando un
    /// 2º device del mismo Apple ID adopta (`.icloud`→`.cloud`). Cierra el hueco multi-device de §g.4 que
    /// `runLeaderReconcileFromFrozenCloudKit` dejaba explícito: el device que ESCRIBIÓ la fila la ve barato
    /// (está en su store local) y la sube por `/sync/push`; sin ella, TODO adopt con writes de ventana termina
    /// en divergencia Merkle local-ahead PERPETUA (autoridad backend→local en el pull).
    ///
    /// **Que el corpus local sea del mismo Apple ID no lo supone: lo comprueba** (ticket
    /// `adopt-uploads-a-foreign-corpus-without-a-lineage-check`). Con algo que subir, exige el marcador de ESA cuenta en el
    /// store local o una fila viva suya (`adoptLineageGate`) y sin ninguna devuelve `.lineageUnproven` sin tocar nada. Hasta ese ticket subía como
    /// huérfano cualquier corpus que llegara aquí —el de un seguidor con otro iCloud, por ejemplo— y lo mezclaba con el de
    /// la cuenta.
    ///
    /// **CONTRATO I14** (el flujo de adopt COMPLETO — §k.4 — es I14; este método es su seam): I14 DEBE
    /// (i) correr este método tras la QUIESCENCIA del import CloudKit y ANTES de arrancar el runtime de sync,
    /// (ii) hacer FAST-FORWARD del History baseline (molde `fastForwardHistoryBaseline` de w4) ANTES de
    /// habilitar el drain del runtime — sin (ii), el primer drain del adoptador re-emitiría el corpus ENTERO
    /// importado de CloudKit como deltas. Este método NO drena la History (emite las huérfanas por el seam
    /// `enqueueSnapshotRows` full-row, no por captura) → es SEGURO respecto al eco del corpus por construcción;
    /// el punto (ii) protege al RUNTIME posterior, no a este método. Y (iii) tras el reconcile, garantizar un
    /// pull con `runPostPullReconcilers` (`SystemEntityMergePolicy`): una ENTIDAD DE SISTEMA huérfana que este
    /// diff suba legítimamente puede duplicar server-side la acuñada por el líder (identidad distinta,
    /// contenido lógico idéntico) — el merge determinista-global del pull la cura (residual (c) de abajo).
    ///
    /// **Completitud de la enumeración VERIFICADA POSITIVAMENTE (SERIO 1 del review):** el set del backend se
    /// cruza contra los counts de filas VIVAS por tabla de `/sync/merkle` (cero endpoints nuevos). Una
    /// enumeración PARCIAL sin error (página vacía prematura / `maxServerSeq` no-monótono con 200 OK) haría
    /// lucir huérfanas filas que el backend SÍ tiene → su re-upload con HLC fresco PISARÍA contenido más nuevo
    /// (riesgo INVERTIDO respecto a `sweepZombies`, donde un set parcial solo encoge el barrido = benigno).
    /// merkle.count > enumerado → `.transient` retomable (sesgo a abortar, jamás a proceder; un push
    /// concurrente entre enumeración y merkle da un spurious-abort conservador — mismo espíritu que
    /// `newDeltaDetected` del verify). El sentido inverso (enumerado > merkle) PASA: deletes concurrentes
    /// solo encogen el diff.
    ///
    /// **Residuales v1** (documentados, DIFERIDOS #30): (a) un device que JAMÁS adopta deja su fila huérfana en
    /// el CloudKit congelado (auto-bloqueado por `secondaryDeviceCloudLogin`; sin pérdida física, rescatable por
    /// una adopción tardía — el diff no caduca; candidato v2 = opción C, lectura directa del CloudKit congelado);
    /// (b) los BORRADOS de la ventana no se propagan (el pull del adopt re-materializa la fila = resurrección
    /// benigna; el diff inverso backend∉local tombstonearía filas reales bajo import-lag → asimetría de riesgo
    /// inaceptable); (c) import-lag = una fila PRE-cutover cuyo `CD_syncID` aún no llegó luce nil → identidad
    /// fresca → DUPLICADO content-idéntico curable (clase I11-4; para system entities cura `SystemEntityMergePolicy`);
    /// mitigado por la PRECONDICIÓN (i) de correr solo tras quiescencia del import.
    ///
    /// Idempotente/retomable: red → `.transient` sin marcar nada; una 2ª pasada re-diffea (lo aplicado sale
    /// del diff → `completed(0, 0)`).
    func runAdoptOrphanReconcile() async -> AdoptReconcileOutcome {
        // Paso 0: una lectura del inventario local ANTES de tocar la red (ticket `adopt-effect-retries-forever-with-no-ceiling`).
        // Una tabla que no se deja leer corta aquí con `.localFailure` sin pagar la enumeración entera del backend y el
        // Merkle en cada reintento —el re-kick de Almacenamiento llega cada 30 s—. Solo es la puerta: el plan preliminar
        // se vuelve a leer DESPUÉS de la enumeración, porque el guard de abajo compara el backend con lo que hay ahora, y
        // lo creado o importado mientras se enumeraba también cuenta (hallazgo de la review).
        do {
            _ = try collectAdoptInventory()
        } catch {
            return .localFailure
        }
        // Paso 1: enumerar el set de identidades del backend (upserts + tombstones) — read-only, idiom
        // `sweepZombies` (SIN applyPage, SIN avance de `SyncCursor`, SIN tocar testigos). Red → `.transient`.
        guard let enumeration = await enumerateBackendSyncIDs() else { return .transient }
        // Verificación POSITIVA de completitud contra los counts del Merkle (SERIO 1 — ver doc del método).
        // El merkle se consulta DESPUÉS de la enumeración: sesgo a abortar, jamás a proceder.
        guard await verifyEnumerationComplete(enumeration) else { return .transient }
        let backendSyncIDs = enumeration.known

        // Guard anti mass-upload ANTES de toda mutación (MENOR 2 del review): diff PRELIMINAR pre-backfill.
        // Backend enumerado VACÍO + (huérfanas ∨ filas sin identidad) = página espuria/bug/cuenta equivocada;
        // el costo del falso positivo sería subir el corpus entero → `abortedEmptyBackend` SIN mutar nada
        // (el backfill de abajo NO corre). NOTA: un backend REALMENTE vacío (merkle en 0s pasa la completitud)
        // sigue abortando A PROPÓSITO — un adopt legítimo (`existing_stable`) implica backend poblado; mergear
        // un local poblado contra una cuenta nube VACÍA es decisión de producto de I14, no de esta pieza.
        // Residual documentado: un líder con corpus 0 filas + huérfana real del 2º device queda excluido de la
        // auto-cura (sin datos en riesgo).
        //
        // Un inventario que no pudo leer una tabla corta con `.localFailure` retomable (tickets
        // `an-incomplete-inventory-reads-as-the-whole-corpus` y `adopt-effect-retries-forever-with-no-ceiling`): sin sus
        // filas `uploadCount` podía salir 0 y apagar justo este guard, el que existe para no fusionar dos corpus.
        let preInventory: [(table: String, syncID: UUID?)]
        do {
            preInventory = try collectAdoptInventory()
        } catch {
            return .localFailure
        }
        let prePlan = AdoptOrphanDiff.compute(inventory: preInventory, backendSyncIDs: backendSyncIDs)
        let pendingUploads = prePlan.uploadCount + prePlan.identityCount

        // Guarda de LINAJE (ticket `adopt-uploads-a-foreign-corpus-without-a-lineage-check`): lo que el backend no conoce
        // solo sube si este dispositivo demuestra que su corpus desciende de ESTA cuenta: el marcador que su líder escribió
        // en CloudKit está en el store local, o alguna fila viva de la cuenta lo está (ticket
        // `adopt-after-the-cutover-needs-a-marker-the-leader-never-exported`). El diff solo sabe «el backend no la
        // conoce», y eso es igual de cierto para la huérfana de la ventana del cutover que para el corpus entero de otra
        // persona o de otro iCloud.
        //
        // Solo con algo que subir: el 2.º dispositivo de una cuenta NACIDA en la nube entra por este mismo adopt y no
        // puede tener marcador nunca (no hay corpus de esa cuenta en CloudKit); sin filas que subir, no hay nada que mezclar.
        // Y ANTES del guard de backend vacío: ese guard sigue el adopt —cambia el modo— y con un corpus ajeno en local eso
        // lo deja dentro de una cuenta que no es suya, listo para subir en la primera edición.
        var reboundWithoutIdentity = 0
        if let blocked = adoptLineageGate(prePlan, inventory: preInventory, enumeration: enumeration,
                                          reboundWithoutIdentity: &reboundWithoutIdentity) { return blocked }

        if backendSyncIDs.isEmpty && pendingUploads > 0 {
            CloudSyncBreadcrumb.adoptReconcileAbortedEmptyBackend(orphans: pendingUploads)
            return .abortedEmptyBackend
        }

        // Paso 2 (identityAssigned): en el adoptador la tabla de testigos arranca vacía → cada fila SIN
        // identidad recibe UUID FRESCO (rebind no-op) y CAE a huérfana (un UUID fresco jamás está en el
        // backend). El conteo sale del plan preliminar; el backfill las materializa (syncID + testigo
        // SyncIdentity). El eco del drain lo previene el contrato de baseline de I14 (punto ii) — igual que
        // en el líder.
        // Menos las que la guarda de linaje acaba de casar con una fila de la cuenta: esas no las acuña el backfill.
        let identityAssigned = prePlan.identityCount - reboundWithoutIdentity
        // Un backfill que no termina deja filas SIN identidad, y el diff las cuenta como `needsIdentity`, no como
        // huérfanas: el adopt podía cerrarse sin subirlas. `.localFailure`, como el inventario ilegible.
        do {
            try SyncIdentityService.backfillIdentities(context: context, now: now())
        } catch {
            return .localFailure
        }

        // Pasos 3-4: inventario local POST-backfill (sin nils) → diff definitivo. Ilegible → `.localFailure`, por lo
        // mismo que arriba y con más precio: el guard de abajo declaraba el adopt COMPLETO sin huérfanas, y el adopt
        // no vuelve a pasar por aquí. Lo que el backfill ya escribió se queda en el contexto: la pasada siguiente lo
        // encuentra y no lo repite, así que su `identityAssigned` sale más bajo (solo el rastro; las filas cuentan
        // como huérfanas igual).
        let inventory: [(table: String, syncID: UUID?)]
        do {
            inventory = try collectAdoptInventory()
        } catch {
            return .localFailure
        }
        let plan = AdoptOrphanDiff.compute(inventory: inventory, backendSyncIDs: backendSyncIDs)
        // Y otra vez sobre el plan DEFINITIVO, que es el que sube (hallazgo de la review): una fila que el import confirme
        // entre las dos lecturas no estaba en el preliminar, y con un preliminar sin nada que subir la guarda no había
        // pedido prueba. El backfill ya corrió, pero solo acuña identidades locales: no sube nada.
        if let blocked = adoptLineageGate(plan, inventory: inventory, enumeration: enumeration,
                                          reboundWithoutIdentity: &reboundWithoutIdentity) { return blocked }
        guard !plan.orphans.isEmpty else { return .completed(uploaded: 0, identityAssigned: identityAssigned) }

        // Paso 6: fetch dirigido de EXACTAMENTE las huérfanas del plan → emisión fila-COMPLETA por el seam del
        // snapshot (reusa `MigrationSnapshotUploader.makeSnapshotRowInput` — misma emisión DeltaEmitter→codec).
        // Ilegible → `.localFailure`: saltar la tabla subía las demás y cerraba el adopt con las suyas fuera.
        let inputs: [SnapshotRowInput]
        do {
            inputs = try buildOrphanRowInputs(plan.orphans)
        } catch {
            return .localFailure
        }
        // Dos familias de fallo, la regla de la subida del snapshot (`MigrationSnapshotUploader`): la DERIVA del reloj
        // (HLC) es `.transient` —el reloj puede corregirse solo—; cualquier otro error es un `fetch`/`save` LOCAL.
        do {
            if let error = _testAdoptEnqueueError { throw error }
            try engine.enqueueSnapshotRows(inputs, context: context, now: now())
        } catch let error where error is ClockDriftError || error is CanonicalTimeError {
            #if DEBUG
            print("MigrationWorkExecutor.runAdoptOrphanReconcile: enqueueSnapshotRows lanzó (drift): \(error)")
            #endif
            return .transient
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor.runAdoptOrphanReconcile: enqueueSnapshotRows lanzó (local): \(error)")
            #endif
            return .localFailure
        }
        // Push con el idiom EXACTO del leader-reconcile: liveOutboxRows + partitionBuildable + deadLetterPoison
        // + push + applyResults. NO se drena la History (las huérfanas ya están en el outbox por el enqueue;
        // drenar re-emitiría el corpus importado — ver contrato).
        // Ilegible → `.localFailure` (tickets `verify-reads-a-failed-local-fetch-as-an-empty-outbox` y
        // `adopt-effect-retries-forever-with-no-ceiling`). Con `[]` el guard de abajo devolvía `.completed(uploaded: 0)`,
        // o sea «no había huérfanas», y el adopt no vuelve a pasar por aquí: las filas que acababan de encolarse se
        // quedaban fuera del backend para siempre.
        let residual: [SyncOutbox]
        do {
            residual = try liveOutboxRows()
        } catch {
            CloudSyncBreadcrumb.outboxFetchFailed(step: "adopt-orphan-reconcile")
            return .localFailure
        }
        let (buildable, poison) = pushClient.partitionBuildable(residual)
        engine.deadLetterPoison(poison, context: context, now: now())
        guard !buildable.isEmpty else { return .completed(uploaded: 0, identityAssigned: identityAssigned) }
        guard case .completed(let results) = await pushClient.push(buildable) else { return .transient }
        await pushClient.applyResults(results, rows: buildable, engine: engine, context: context)
        let uploaded = results.filter { $0.status == .applied }.count

        // Paso 7: canario (espejo del par del líder). `identityAssigned` viaja en el breadcrumb (sin PII).
        if uploaded > 0 {
            CloudSyncBreadcrumb.adoptOrphanReconciled(count: uploaded, identityAssigned: identityAssigned)
            MetricsService.cloudAdoptOrphanReconciled(count: uploaded)
        }
        return .completed(uploaded: uploaded, identityAssigned: identityAssigned)
    }

    /// Flujo de ADOPT (§k.4, #30 — I14 P6), retomable/idempotente. Invocado por `execute(.adoptBackendAccount)`
    /// cuando la máquina rutea `existing_stable`/`leaderCompleted` → `notStarted` + adopt. ORDEN EXACTO
    /// (contrato de `runAdoptOrphanReconcile`): quiescencia del import → reconcile de huérfanas de ventana →
    /// fast-forward del History baseline (sin él el primer drain del runtime re-emitiría el corpus importado)
    /// → verificación del marcador local (belt) → persistir el PAR `.cloud`+`mirrorOffArmed` + estampar el
    /// claim-store (`routeReturningUser`) → re-persistir las 2 keys de consent al outbox de prefs
    /// (trazabilidad backend del adoptador — el drenaje iKV es LÍDER-only y jamás las llevaría). El
    /// relaunch asistido NO se hace aquí: la UI lo deriva del par persistido (`mirrorOffArmed` + mount
    /// `.icloud` → `needsRelaunch(.toCloud)`). Post-relaunch el runtime arranca en `.cloud`+`notStarted`.
    ///
    /// Todo fallo (quiescencia no alcanzada / red o base local ilegible en el reconcile) → THROW → el runner lo deja journaled
    /// pendiente y el próximo `resume()` lo reintenta (tras su propia espera de quiescencia). Idempotente:
    /// una 2ª pasada re-diffea (lo aplicado sale del diff) y re-persiste (LWW/no-op).
    func runAdoptFlow() async throws {
        // 1) Quiescencia del import (el adopt persiste `.cloud` sobre un store en importación — DEBE
        //    asentarse antes). El runner ya gatea sus entradas por quiescencia; esta es la red específica
        //    del contrato por si el drive alcanzó el efecto lejos de la entrada.
        guard adoptQuiescenceSignal() else {
            CloudSyncBreadcrumb.migrationEffectFailed(effect: "adoptBackendAccount", reason: "import not quiescent")
            throw MigrationExecutorError.adoptRetry(reason: "quiescence")
        }

        // 2) Reconcile de huérfanas de la ventana de cutover (identidad local ∉ backend). `.transient` →
        //    retomable; `.completed`/`.abortedEmptyBackend` → continuar (best-effort; el guard vacío es
        //    benigno para el switch de modo).
        switch await runAdoptOrphanReconcile() {
        case .transient:
            throw MigrationExecutorError.adoptRetry(reason: "reconcileTransient")
        case .localFailure:
            // Caso propio y no `adoptRetry`: el runner lo cuenta para el techo CORTO del efecto (ticket
            // `adopt-effect-retries-forever-with-no-ceiling`).
            throw MigrationExecutorError.adoptLocalFailure
        case .lineageUnproven:
            // Tampoco `adoptRetry`: un corpus ajeno no se arregla esperando (ticket
            // `adopt-uploads-a-foreign-corpus-without-a-lineage-check`). El techo CORTO y su salida los pone el runner.
            throw MigrationExecutorError.adoptLineageUnproven
        case .completed, .abortedEmptyBackend:
            break
        }

        // 3) Fast-forward del History baseline: sin él el primer drain del runtime post-relaunch re-emitiría
        //    el corpus ENTERO importado de CloudKit como deltas (contrato (ii)).
        engine.fastForwardHistoryBaseline(context: context)

        // 4) Belt: el marcador del líder debe haber llegado por el mirror. Ausente = no bloquea (solo diagnóstico): con
        //    algo que subir, la guarda de linaje del paso 2 ya exigió el marcador o filas de la cuenta en local (el líder
        //    puede haber pasado el cutover del servidor sin exportarlo aún); sin nada que subir el adopt es legítimo sin
        //    marcador (el 2.º dispositivo de una cuenta nacida en la nube no lo tiene nunca).
        let markerCount = (try? context.fetchCount(FetchDescriptor<CloudMigrationMarker>())) ?? 0
        if markerCount == 0 {
            CloudSyncBreadcrumb.migrationEffectFailed(effect: "adoptBackendAccount", reason: "marker absent (belt)")
        }

        // 5) Persistir el PAR `.cloud` + `mirrorOffArmed` JUNTOS (invariante SERIO 1). El marcador ya está
        //    exportado por el LÍDER → la razón del par en la IDA (el gate de export) no aplica igual aquí,
        //    pero se conserva el par para que `personalStoreDecision` monte mirror-OFF al relanzar. Estampa
        //    el claim-store (`routeReturningUser`) → el gate de arranque del runtime deja arrancar el sync.
        // C-1: un solo escritor del par (`StorageModePersistence.writeCloudArmed`) en vez de dos `set`
        // sueltos. No da atomicidad —`UserDefaults` no la tiene— pero elimina la posibilidad de que un
        // camino futuro escriba solo una mitad por descuido; el kill-window lo cubre el gate del motor.
        StorageModePersistence.writeCloudArmed(defaults: storageDefaults)
        if let userID = session.currentUserID {
            claimStore.record(.routeReturningUser, forUserID: userID)
        } else {
            // M1 del review: sin userID no hay estampado → el guard de identidad dejaría al DUEÑO en
            // `.idle` post-relaunch sin auto-cura. Improbable (el claim que trajo aquí usó la sesión);
            // ruido explícito para diagnosticarlo si ocurre.
            CloudSyncBreadcrumb.migrationEffectFailed(effect: "adoptBackendAccount", reason: "claim-stamp skipped: nil userID")
        }

        // 5-bis) Re-persistir las 2 keys de consent (AJUSTE review #4): ya en `.cloud` van al outbox de
        //    prefs → trazabilidad backend del adoptador (el drenaje iKV es LÍDER-only). Idempotente (LWW).
        //    S1 del review: se re-emite el timestamp PERSISTIDO por `CloudConsentView` (T0, la hora de
        //    aceptación real) — jamás `now()` (falsearía la traza GDPR con la hora de FIN del adopt).
        //    `PreferenceSyncService.set` espeja en el mismo `UserDefaults.standard` que `storageDefaults`
        //    en producción; el fallback `now()` es defensivo (consent ausente = camino anómalo, ruidoso).
        let persistedConsentAt = storageDefaults.object(forKey: PrefSyncKey.cloudConsentAcceptedAt.rawValue) as? Int
        if persistedConsentAt == nil {
            CloudSyncBreadcrumb.migrationEffectFailed(effect: "adoptBackendAccount", reason: "consent timestamp absent — fallback now()")
        }
        PreferenceSyncService.shared.set(
            int: persistedConsentAt ?? Int(now().timeIntervalSince1970),
            forKey: PrefSyncKey.cloudConsentAcceptedAt.rawValue)
        PreferenceSyncService.shared.set(
            int: CloudConsentText.version,
            forKey: PrefSyncKey.cloudConsentTextVersion.rawValue)

        CloudSyncBreadcrumb.migrationLocalModePersisted()
    }

    /// Las tablas que NO piden prueba de linaje aunque tengan filas que subir: caché que cualquier teléfono genera solo, no
    /// corpus de nadie. `ExchangeRate` es la de los tipos de cambio que el arranque siembra ANTES del Welcome
    /// (`AppBootstrapper.loadExchangeRates`, sin identidad en iCloud): sin esta excepción el 2.º dispositivo de una cuenta
    /// nacida en la nube —que nunca tiene marcador— no llegaba jamás con «nada que subir» (lo cazó la review). Siguen
    /// subiendo como antes; lo que no hacen es exigir el marcador.
    static let adoptLineageExemptTables: Set<String> = [EntityEmissionMap.exchangeRate.table]

    /// Cuántas filas del plan piden prueba de linaje: huérfanas y filas sin identidad, fuera de las tablas exentas.
    static func adoptLineageRelevantCount(_ plan: AdoptOrphanDiff.Plan) -> Int {
        let orphans = plan.orphans.filter { !adoptLineageExemptTables.contains($0.key) }.values.reduce(0) { $0 + $1.count }
        let needsIdentity = plan.needsIdentity.filter { !adoptLineageExemptTables.contains($0.key) }.values.reduce(0, +)
        return orphans + needsIdentity
    }

    /// La guarda de linaje sobre un plan: `nil` = puede seguir. Con filas que la piden, vale una de dos pruebas: el marcador
    /// de la cuenta (`adoptLineageProven`) o las filas de la cuenta en el `inventory` del que sale ese plan
    /// (`adoptSharedRowsProof`). Sin ninguna, `.lineageUnproven`. El marcador se mira primero: con su tabla ilegible,
    /// `.localFailure` —nunca «probado»—.
    ///
    /// **Por qué la segunda prueba** (ticket `adopt-after-the-cutover-needs-a-marker-the-leader-never-exported`): desde g16_04
    /// el claim da `existing_stable` a quien llega después del cutover del SERVIDOR, y el líder estampa `migrated_at` ANTES de
    /// escribir y exportar el marcador. Un líder dormido en `cutover(.markerWritten)`, o que agotó el tope del marcador y lo
    /// borró al volver a iCloud, dejaba fuera para siempre al 2.º teléfono del mismo iCloud con algo que subir. Una fila de
    /// la cuenta solo llega a este store por su CloudKit o por un pull de esa cuenta, y ninguna tabla personal tiene
    /// identidades fijas entre teléfonos, así que un corpus de otro iCloud no la tiene. La enumeración ya viene verificada
    /// contra el Merkle, así que «no comparte ninguna» es una respuesta completa.
    ///
    /// **Y una fila compartida no basta: tienen que haber llegado TODAS las de las tablas que suben** (review adversarial del
    /// mismo ticket). El marcador se exporta DESPUÉS de las identidades que el líder asignó (`assignIdentity`), así que traerlo
    /// implicaba traerlas. Sin él, la exportación del líder puede estar parada —es justo por qué el marcador no llegó—: la
    /// cuenta (`Account.shortcutID`, que nace con la fila) se comparte, pero los movimientos y categorías del líder siguen aquí
    /// sin `syncID`, el backfill les acuñaría una identidad fresca y el adopt SUBIRÍA EL LIBRO ENTERO DUPLICADO. Por eso,
    /// en cada tabla con algo que subir, ninguna fila viva del backend que falte aquí puede tener gemela en lo que sube: las
    /// que casan por una clave de linaje única toman su identidad, y una que falta sin gemela posible —borrada aquí, con lo
    /// que sube creado aquí después— ya no bloquea (`adoptSharedRowsProof`).
    /// `reboundWithoutIdentity` suma las filas SIN `syncID` que la prueba casó con una de la cuenta: ya no las acuña el
    /// backfill, y el rastro `identityAssigned` no las cuenta.
    private func adoptLineageGate(_ plan: AdoptOrphanDiff.Plan,
                                  inventory: [(table: String, syncID: UUID?)],
                                  enumeration: BackendEnumeration,
                                  reboundWithoutIdentity: inout Int) -> AdoptReconcileOutcome? {
        let relevant = Self.adoptLineageRelevantCount(plan)
        guard relevant > 0 else { return nil }
        do {
            if try adoptLineageProven() { return nil }
        } catch {
            return .localFailure
        }
        let proof: AdoptSharedRowsProof
        do {
            let resolved = try resolveLineageCoverage(plan: plan, inventory: inventory, enumeration: enumeration)
            proof = resolved.proof
            reboundWithoutIdentity += resolved.reboundWithoutIdentity
        } catch {
            return .localFailure
        }
        switch proof {
        case .proven(let shared, _):
            CloudSyncBreadcrumb.adoptReconcileLineageProvenBySharedRows(sharedRows: shared, pending: relevant)
            return nil
        case .noSharedRows:
            CloudSyncBreadcrumb.adoptReconcileLineageUnproven(pending: relevant)
            return .lineageUnproven
        case .accountRowsMissing(let table, let missing):
            CloudSyncBreadcrumb.adoptReconcileAccountRowsMissing(table: table, missing: missing, pending: relevant)
            return .lineageUnproven
        }
    }

    /// Veredicto de la prueba del adopt por filas de la cuenta (sin marcador). `nonisolated`: la compara la lógica de tests.
    nonisolated enum AdoptSharedRowsProof: Equatable {
        /// Comparte filas vivas con la cuenta y ninguna fila de la cuenta que falta aquí puede tener gemela en lo que sube.
        /// `rebinds` = las filas locales sin identidad del backend que casan, por una clave de linaje ÚNICA, con una fila de
        /// la cuenta que aquí falta: toman esa identidad en vez de acuñar otra (ticket
        /// `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait`).
        case proven(sharedRows: Int, rebinds: [LineageRebind] = [])
        /// No comparte ninguna fila viva: el corpus no es de esta cuenta (o aún no llegó nada).
        case noSharedRows
        /// Comparte, pero a `table` —que tiene algo que subir— le faltan `missing` filas vivas de la cuenta y le queda alguna
        /// fila que podría ser una de ellas con otra identidad: lo que sube podría duplicarla. Primera tabla en orden alfabético.
        case accountRowsMissing(table: String, missing: Int)
    }

    /// Una fila local SIN identidad del backend (sin `syncID`, o con una que el backend no conoce ni viva ni borrada): lo
    /// que va a subir, y por eso la única que podría ser la gemela de una fila de la cuenta que aquí falta. `ref` la
    /// identifica ante el llamador. `key` = su clave de linaje, solo en tablas sintéticas. `provenNew` = consta en el
    /// historial de este teléfono que se CREÓ aquí después de la última escritura que conoce el backend: el líder no pudo
    /// subirla. `fusionKey` = su clave de fusión si es una semilla que un deduplicador funde (`LineageTwinKey.fusion`).
    nonisolated struct LineageCandidate: Equatable {
        let table: String
        let key: String?
        let ref: Int
        var provenNew: Bool = false
        var fusionKey: String?
    }

    /// La candidata `ref` es la fila `syncID` de la cuenta: toma esa identidad.
    nonisolated struct LineageRebind: Equatable {
        let ref: Int
        let syncID: UUID
    }

    /// Las filas VIVAS del backend que faltan en local, por tabla, en las tablas del `plan` con algo que subir (huérfanas o
    /// filas sin identidad, fuera de las exentas). Solo ahí una fila que falta puede duplicarse.
    static func lineageMissingRows(plan: AdoptOrphanDiff.Plan,
                                   inventory: [(table: String, syncID: UUID?)],
                                   liveByTable: [String: Set<UUID>]) -> [String: Set<UUID>] {
        let local = Dictionary(grouping: inventory, by: \.table).mapValues { Set($0.compactMap(\.syncID)) }
        let uploading = Set(plan.orphans.filter { !$0.value.isEmpty }.keys)
            .union(plan.needsIdentity.filter { $0.value > 0 }.keys)
            .subtracting(adoptLineageExemptTables)
        var out: [String: Set<UUID>] = [:]
        for table in uploading {
            let missing = (liveByTable[table] ?? []).subtracting(local[table] ?? [])
            if !missing.isEmpty { out[table] = missing }
        }
        return out
    }

    /// La prueba del adopt SIN marcador (ver `adoptLineageGate`), y la de la ida (`checkForwardLineage`): alguna fila VIVA
    /// del backend en local (`lineageSharedLiveRows`) Y, en cada tabla del `plan` con algo que subir, o no falta ninguna fila
    /// viva de la cuenta, o ninguna de las filas que suben puede ser una de las que faltan.
    ///
    /// **Por qué no «están todas»** (ticket `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait`). Una fila
    /// que el líder subió y este teléfono BORRÓ durante la espera no llega nunca, y el único que la tombstonea en el backend
    /// es el motor del líder, callado: relevo y adopt esperaban para siempre. El duplicado que la cobertura evita (ticket
    /// `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived`) necesita que la MISMA fila esté aquí
    /// con otra identidad, así que la pregunta es por las candidatas (`candidates`, las filas sin identidad del backend), y
    /// **falla cerrado**: una candidata es sospechosa salvo prueba.
    ///
    /// Por tabla, en orden:
    /// 1. **Casado por clave de linaje, solo si es ÚNICA** (tablas sintéticas): una fila que falta y una candidata con la
    ///    misma clave (`LineageTwinKey`), cuando la clave sale UNA vez entre todas las vivas de esa tabla en el backend y UNA
    ///    vez entre las candidatas. La candidata toma la identidad del backend (`rebinds`) y los dos salen de la cuenta. Una
    ///    clave repetida no casa nada: importaciones, recurrentes o el `createdAt` por defecto de la migración ligera repiten
    ///    el milisegundo, y casar dentro de un grupo cruzaría identidades.
    /// 2. Si no queda ninguna fila por explicar, la tabla pasa.
    /// 3. Si quedan, la tabla bloquea mientras quede alguna candidata **sospechosa**: ni probada nueva (`provenNew`) ni
    ///    semilla cuya clave de fusión es la de alguna fila sin explicar (`fusionKey`, `liveFusionKeys`: si sube duplicada,
    ///    el deduplicador del arranque la funde con esa). Una clave de linaje que no casa NO prueba nada: el `createdAt` de
    ///    las filas anteriores a su columna lo rellenó cada teléfono por su cuenta.
    ///
    /// Una fila del backend SIN clave legible en una tabla sintética apaga el casado de toda la tabla: puede ser la gemela
    /// verdadera de cualquier candidata, así que ninguna clave es «única».
    ///
    /// Así una fila borrada aquí deja de bloquear cuando lo que sube es de este teléfono (lo creado durante la espera) o ya
    /// casó; y sigue bloqueando mientras quede aquí una fila del líder sin su identidad que no se pueda casar.
    static func adoptSharedRowsProof(plan: AdoptOrphanDiff.Plan,
                                     inventory: [(table: String, syncID: UUID?)],
                                     liveByTable: [String: Set<UUID>],
                                     liveKeys: [UUID: String] = [:],
                                     liveFusionKeys: [UUID: String] = [:],
                                     candidates: [LineageCandidate] = []) -> AdoptSharedRowsProof {
        let shared = lineageSharedLiveRows(inventory: inventory, liveByTable: liveByTable)
        guard shared > 0 else { return .noSharedRows }
        let missingByTable = lineageMissingRows(plan: plan, inventory: inventory, liveByTable: liveByTable)
        var rebinds: [LineageRebind] = []
        for table in missingByTable.keys.sorted() {
            var unexplained = missingByTable[table] ?? []
            let tableCandidates = candidates.filter { $0.table == table }
            var rebound: Set<Int> = []
            let tableLive = liveByTable[table] ?? []
            if LineageTwinKey.syntheticTables.contains(table), tableLive.allSatisfy({ liveKeys[$0] != nil }) {
                let backendKeyCount = Dictionary(grouping: (liveByTable[table] ?? []).compactMap { liveKeys[$0] }, by: { $0 })
                    .mapValues(\.count)
                let candidatesByKey = Dictionary(grouping: tableCandidates.filter { $0.key != nil }, by: { $0.key ?? "" })
                for id in unexplained.sorted(by: { $0.uuidString < $1.uuidString }) {
                    guard let key = liveKeys[id], backendKeyCount[key] == 1,
                          let twins = candidatesByKey[key], twins.count == 1, let twin = twins.first else { continue }
                    rebinds.append(LineageRebind(ref: twin.ref, syncID: id))
                    rebound.insert(twin.ref)
                    unexplained.remove(id)
                }
            }
            guard !unexplained.isEmpty else { continue }
            let unexplainedFusion = Set(unexplained.compactMap { liveFusionKeys[$0] })
            let suspects = tableCandidates.filter { candidate in
                guard !rebound.contains(candidate.ref), !candidate.provenNew else { return false }
                if let fusion = candidate.fusionKey, unexplainedFusion.contains(fusion) { return false }
                return true
            }
            if !suspects.isEmpty { return .accountRowsMissing(table: table, missing: unexplained.count) }
        }
        return .proven(sharedRows: shared, rebinds: rebinds)
    }

    /// Margen sobre la última escritura del backend para dar una fila local por nacida DESPUÉS: cubre relojes de dos
    /// teléfonos algo desfasados. Hacia arriba es el lado seguro (menos filas probadas nuevas, más espera).
    static let lineageBornAfterMargin: TimeInterval = 10 * 60

    /// La prueba de cobertura con lo que pide de la base local, y sus re-identificaciones APLICADAS y guardadas. Solo lee
    /// candidatas e historial si falta alguna fila (el camino feliz no paga nada). LANZA si la base local no se deja leer o
    /// el guardado falla —y entonces deshace lo suyo—: el llamador lo cuenta como `localFailure`, nunca como «probado».
    ///
    /// Re-identificar antes de probar nada es idempotente: la pasada siguiente encuentra esas filas ya cubiertas.
    private func resolveLineageCoverage(plan: AdoptOrphanDiff.Plan,
                                        inventory: [(table: String, syncID: UUID?)],
                                        enumeration: BackendEnumeration)
        throws -> (proof: AdoptSharedRowsProof, reboundWithoutIdentity: Int) {
        let missing = Self.lineageMissingRows(plan: plan, inventory: inventory, liveByTable: enumeration.liveByTable)
        var collected = LineageCandidates()
        if Self.lineageSharedLiveRows(inventory: inventory, liveByTable: enumeration.liveByTable) > 0, !missing.isEmpty {
            let bornAfter: Set<PersistentIdentifier>
            if let lastWriteMs = enumeration.lastWriteMs {
                let cutoff = Date(timeIntervalSince1970: Double(lastWriteMs) / 1000).addingTimeInterval(Self.lineageBornAfterMargin)
                bornAfter = try lineageRowsBornHere(after: cutoff)
            } else {
                bornAfter = []
            }
            collected = try collectLineageCandidates(tables: Set(missing.keys), backendKnown: enumeration.known,
                                                     bornAfter: bornAfter)
        }
        let proof = Self.adoptSharedRowsProof(plan: plan, inventory: inventory, liveByTable: enumeration.liveByTable,
                                              liveKeys: enumeration.liveKeys, liveFusionKeys: enumeration.liveFusionKeys,
                                              candidates: collected.candidates)
        var reboundWithoutIdentity = 0
        if case .proven(_, let rebinds) = proof, !rebinds.isEmpty {
            reboundWithoutIdentity = rebinds.filter { collected.withoutIdentity.contains($0.ref) }.count
            var undo: [() -> Void] = []
            do {
                for rebind in rebinds {
                    guard let rebinder = collected.rebinders[rebind.ref] else { continue }
                    undo.append(try rebinder(rebind.syncID))
                }
                try context.save()
            } catch {
                // Deshace SOLO lo suyo, en orden inverso: el contexto es compartido y un `rollback` tiraría ediciones ajenas.
                for revert in undo.reversed() { revert() }
                #if DEBUG
                print("MigrationWorkExecutor: re-identificación del linaje falló: \(error)")
                #endif
                throw error
            }
            CloudSyncBreadcrumb.lineageRowsRebound(count: rebinds.count)
        }
        return (proof, reboundWithoutIdentity)
    }

    /// Lo que la prueba necesita de las candidatas locales: el veredicto puro solo ve `candidates`; `rebinders` sabe dar
    /// otra identidad a las de tablas sintéticas (y devuelve cómo deshacerlo); `withoutIdentity` marca las que no tenían.
    private struct LineageCandidates {
        var candidates: [LineageCandidate] = []
        var rebinders: [Int: (UUID) throws -> () -> Void] = [:]
        var withoutIdentity: Set<Int> = []
    }

    /// Las filas de `tables` sin identidad del backend (sin identidad, o con una que el backend no conoce ni viva ni borrada),
    /// con su clave de linaje en las sintéticas, si consta que nacieron aquí después de la última escritura del backend
    /// (`bornAfter`) y si son semillas que el deduplicador funde solo. Fetch por el inventario (mismo `catch`, rastro y seam).
    private func collectLineageCandidates(tables: Set<String>, backendKnown: Set<UUID>,
                                          bornAfter: Set<PersistentIdentifier>) throws -> LineageCandidates {
        var out = LineageCandidates()
        func add<M: PersistentModel>(_ type: M.Type, table: String, identity: (M) -> UUID?,
                                     key: ((M) -> String?)? = nil, fusion: (M) -> String? = { _ in nil },
                                     rebind: ((M, UUID?, UUID) throws -> () -> Void)? = nil) throws {
            guard tables.contains(table) else { return }
            for model in try fetchInventory(M.self, step: "lineage-candidates") {
                let current = identity(model)
                if let current, backendKnown.contains(current) { continue }
                let ref = out.candidates.count
                if current == nil { out.withoutIdentity.insert(ref) }
                out.candidates.append(LineageCandidate(table: table, key: key?(model) ?? nil, ref: ref,
                                                       provenNew: bornAfter.contains(model.persistentModelID),
                                                       fusionKey: fusion(model)))
                if let rebind { out.rebinders[ref] = { newID in try rebind(model, current, newID) } }
            }
        }
        func synthetic<M: PersistentModel & SyncIdentifiable>(_ className: String) -> (M, UUID?, UUID) throws -> () -> Void {
            { [weak self] model, current, newID in
                // El testigo primero: si su lectura lanza, la fila no se ha tocado y no queda nada que deshacer a medias.
                let witnessUndo = try current.map { try self?.rekeyLineageWitness(entityType: className, from: $0, to: newID) }
                model.syncID = newID
                return {
                    model.syncID = current
                    witnessUndo??()
                }
            }
        }
        try add(TransactionItem.self, table: EntityEmissionMap.transactionItem.table, identity: { $0.syncID },
                key: { LineageTwinKey.created($0.createdAt) }, rebind: synthetic(SyncEntityType.transactionItem))
        try add(InboxDraft.self, table: EntityEmissionMap.inboxDraft.table, identity: { $0.syncID },
                key: { LineageTwinKey.created($0.createdAt) }, rebind: synthetic(SyncEntityType.inboxDraft))
        try add(Category.self, table: EntityEmissionMap.category.table, identity: { $0.syncID }, key: {
            LineageTwinKey.category(isDefaultSeed: $0.isDefaultSeed, iconName: $0.iconName, colorHex: $0.colorHex,
                                    isIncome: $0.isIncome)
        }, fusion: {
            LineageTwinKey.category(isDefaultSeed: $0.isDefaultSeed, iconName: $0.iconName, colorHex: $0.colorHex,
                                    isIncome: $0.isIncome)
        }, rebind: synthetic(SyncEntityType.category))
        try add(FavoritePayment.self, table: EntityEmissionMap.favoritePayment.table, identity: { $0.syncID },
                key: { LineageTwinKey.created($0.createdAt) }, rebind: synthetic(SyncEntityType.favoritePayment))
        try add(MerchantMemory.self, table: EntityEmissionMap.merchantMemory.table, identity: { $0.syncID },
                key: { LineageTwinKey.merchant($0.merchantCanonical) }, rebind: synthetic(SyncEntityType.merchantMemory))
        try add(Budget.self, table: EntityEmissionMap.budget.table, identity: { $0.id })
        try add(ScheduledPayment.self, table: EntityEmissionMap.scheduledPayment.table, identity: { $0.id })
        try add(Account.self, table: EntityEmissionMap.account.table, identity: { $0.shortcutID })
        try add(Subcategory.self, table: EntityEmissionMap.subcategory.table, identity: { $0.shortcutID },
                fusion: { $0.isDefaultSeed ? LineageTwinKey.subcategorySeedFusion(iconName: $0.iconName) : nil })
        try add(Tag.self, table: EntityEmissionMap.tag.table, identity: { $0.id })
        try add(NotificationItem.self, table: EntityEmissionMap.notificationItem.table, identity: { $0.id },
                fusion: { LineageTwinKey.notificationFusion(typeRaw: $0.typeRaw) })
        try add(CashFlowPlan.self, table: EntityEmissionMap.cashFlowPlan.table, identity: { $0.id })
        try add(CashFlowLine.self, table: EntityEmissionMap.cashFlowLine.table, identity: { $0.id })
        try add(CashFlowOverride.self, table: EntityEmissionMap.cashFlowOverride.table, identity: { $0.id })
        try add(GroupBridgePreference.self, table: EntityEmissionMap.groupBridgePreference.table, identity: { $0.id })
        return out
    }

    /// El testigo `SyncIdentity` de una huérfana re-identificada pasa a la identidad de la cuenta, con su ancla de contenido
    /// y sus coordenadas de CloudKit (es la misma fila) y `lastReboundAt` estampado. Si ya hay un testigo de la identidad
    /// nueva —este teléfono tuvo esa fila y la borró—, no se toca ninguno: dos testigos de un `syncID` no caben, y el viejo
    /// solo deja de resolverse (un tombstone de su identidad no llegará nunca). Sin testigo viejo no hay nada que hacer: el
    /// backfill materializa el de la identidad nueva. Sin `save`: lo hace el llamador. Devuelve cómo deshacerlo.
    private func rekeyLineageWitness(entityType: String, from oldID: UUID, to newID: UUID) throws -> () -> Void {
        let existingNew = try context.fetch(FetchDescriptor<SyncIdentity>(
            predicate: #Predicate<SyncIdentity> { $0.syncID == newID }))
        guard existingNew.isEmpty else { return {} }
        let old = try context.fetch(FetchDescriptor<SyncIdentity>(
            predicate: #Predicate<SyncIdentity> { $0.syncID == oldID && $0.entityType == entityType }))
        let previous = old.map { ($0, $0.lastReboundAt) }
        for witness in old {
            witness.syncID = newID
            witness.lastReboundAt = now()
        }
        return {
            for (witness, rebound) in previous {
                witness.syncID = oldID
                witness.lastReboundAt = rebound
            }
        }
    }

    /// Las filas que consta en el historial de SwiftData que se CREARON en este teléfono —transacción sin el autor del
    /// espejo de CloudKit, que firma lo que BAJÓ— después de `cutoff`. Un líder cuya última escritura en el backend es
    /// anterior no pudo subirlas, así que no son gemelas de nada suyo. Solo lee desde `cutoff`. LANZA si el historial no se
    /// deja leer: el llamador lo cuenta como avería local.
    private func lineageRowsBornHere(after cutoff: Date) throws -> Set<PersistentIdentifier> {
        let transactions: [DefaultHistoryTransaction]
        do {
            if _testInventoryFetchThrows?("lineage-born-here", "History") == true { throw CocoaError(.fileReadCorruptFile) }
            transactions = try context.fetchHistory(
                HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.timestamp > cutoff }))
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor: fetchHistory del linaje falló: \(error)")
            #endif
            CloudSyncBreadcrumb.migrationInventoryReadFailed(step: "lineage-born-here", entity: "History")
            throw MigrationExecutorError.inventoryUnreadable(entity: "History")
        }
        var born: Set<PersistentIdentifier> = []
        for transaction in transactions {
            if let author = transaction.author, author.hasPrefix(PrivateSignOutExportGateLogic.mirrorAuthorPrefix) { continue }
            for change in transaction.changes {
                if case .insert(let insert) = change { born.insert(insert.changedPersistentIdentifier) }
            }
        }
        return born
    }

    /// Cuántas filas VIVAS del backend están en el inventario local, cada una en su tabla y fuera de `adoptLineageExemptTables`.
    /// Es la prueba de linaje por identidad compartida, la misma para la ida (`checkForwardLineage`) y para el adopt
    /// (`adoptLineageGate`). Un tombstone no cuenta: dice que la fila existió, no que el corpus la siga teniendo.
    static func lineageSharedLiveRows(inventory: [(table: String, syncID: UUID?)],
                                      liveByTable: [String: Set<UUID>]) -> Int {
        let local = Dictionary(grouping: inventory, by: \.table).mapValues { Set($0.compactMap(\.syncID)) }
        return liveByTable
            .filter { !adoptLineageExemptTables.contains($0.key) }
            .reduce(0) { $0 + $1.value.intersection(local[$1.key] ?? []).count }
    }

    /// ¿Demuestra el MARCADOR que este corpus desciende de la cuenta de la sesión? Sí si hay una fila
    /// `CloudMigrationMarker` cuyo `accountHash` es el de esa cuenta (ticket
    /// `adopt-uploads-a-foreign-corpus-without-a-lineage-check`). El marcador lo escribe el líder en SU CloudKit en el
    /// cutover, así que solo está aquí si este dispositivo espeja ese corpus. Vale cualquier fila que case: un marcador
    /// de OTRA cuenta —una migración anterior de este iCloud— no prueba nada, y uno con el hash vacío (el líder sin sesión)
    /// tampoco, porque `CloudBeacon.hash` nunca lo es. Sin sesión, no: no hay cuenta con la que comparar.
    /// LANZA si el fetch falla: el llamador lo cuenta como base local ilegible, nunca como «probado».
    private func adoptLineageProven() throws -> Bool {
        guard let userID = session.currentUserID else { return false }
        let expected = CloudBeacon.hash(userID)
        // Por `fetchInventory`: el mismo `catch`, el mismo rastro y el mismo seam de tests que las tablas del inventario.
        return try fetchInventory(CloudMigrationMarker.self, step: "adopt-lineage").contains { $0.accountHash == expected }
    }

    // MARK: - Linaje de la IDA (ticket `migration-takeover-uploads-without-a-lineage-check`)

    /// ¿Comparte este corpus linaje con lo que la cuenta ya tiene? Lo pregunta el runner en la identidad (35 %), ANTES de
    /// tocar nada, cuando el claim que dio el turno dijo que la cuenta ya recibió datos personales —o no lo dijo—: el caso es
    /// el relevo de un líder callado (`claim_account` da `created` a otro dispositivo cuando el líder lleva más de 60 min sin
    /// latir), que hasta este ticket subía su corpus encima de lo que el otro alcanzó a subir fuera o no el mismo.
    ///
    /// **La prueba es una identidad compartida**: alguna fila VIVA del backend está en el inventario local, en su tabla. Una
    /// identidad aleatoria solo llega a este store por el CloudKit del mismo iCloud (o por un pull de esa cuenta), y la
    /// subida del líder empieza por `accounts`, cuya identidad (`Account.shortcutID`) nace con la fila y viaja por CloudKit
    /// sin esperar a que el líder asigne nada. `exchange_rates` no cuenta en ningún lado: es caché que cualquier teléfono
    /// siembra solo (`adoptLineageExemptTables`, la misma excepción que el adopt).
    ///
    /// **Y una fila compartida no basta: tienen que haber llegado TODAS las de las tablas que suben** (ticket
    /// `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived`, la misma condición que el adopt,
    /// `adoptSharedRowsProof`). La cuenta del líder llega enseguida porque su identidad nace con la fila; los movimientos,
    /// categorías, borradores, favoritos y comercios, en cambio, llevan una identidad SINTÉTICA que el líder asignó en su
    /// 35 % y que viaja con su exportación a iCloud —que puede ser justo lo que se paró—. Sin ella, el backfill de aquí
    /// acuña otra —los testigos del rebind son locales de cada teléfono: aquí no hay ninguno del líder—, el servidor solo deduplica por `(user_id, sync_id)` y el
    /// `verify` baja las copias del líder ANTES de contar: el Merkle cuadra con el libro doble. Por eso, en cada tabla con
    /// algo que subir, ninguna fila viva del backend que falte aquí puede tener gemela en lo que sube (`.accountRowsMissing` si puede).
    ///
    /// Orden, y es el del reconcile del adopt: el inventario local primero (una avería local no paga la enumeración), luego
    /// la enumeración, y el Merkle tiene que darla por completa ANTES de cualquier veredicto: para decir «no hay nada» o
    /// «no comparte nada», y también para decir «llegó todo», porque una página que faltó escondería justo las filas que no
    /// están aquí (sesgo a esperar, jamás a proceder ni a bloquear por una página que faltó).
    ///
    /// **Una fila que falta solo bloquea si aquí puede tener gemela** (ticket
    /// `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait`, ver `adoptSharedRowsProof`): una fila que este
    /// teléfono borró durante la espera ya no deja el relevo esperando para siempre cuando lo que sube lo creó este teléfono
    /// después. Lo único que muta es eso: las filas del líder que casan por una clave de linaje única toman su identidad (y
    /// se guardan) antes de devolver `proven`. Nada más: ni backfill, ni encolado, ni red.
    func checkForwardLineage() async -> ForwardLineageOutcome {
        let inventory: [(table: String, syncID: UUID?)]
        do {
            inventory = try collectAdoptInventory()
        } catch {
            return .localFailure
        }
        guard let enumeration = await enumerateBackendSyncIDs() else { return .transient }
        guard await verifyEnumerationComplete(enumeration) else { return .transient }
        let live = enumeration.liveByTable.filter { !Self.adoptLineageExemptTables.contains($0.key) }
        let shared = Self.lineageSharedLiveRows(inventory: inventory, liveByTable: enumeration.liveByTable)
        if shared > 0 {
            let liveRows = live.values.reduce(0) { $0 + $1.count }
            let plan = AdoptOrphanDiff.compute(inventory: inventory, backendSyncIDs: enumeration.known)
            let proof: AdoptSharedRowsProof
            do {
                    proof = try resolveLineageCoverage(plan: plan, inventory: inventory, enumeration: enumeration).proof
            } catch {
                return .localFailure
            }
            switch proof {
            case .proven(let sharedRows, _):
                CloudSyncBreadcrumb.forwardLineageChecked(verdict: "proven", liveRows: liveRows, sharedRows: sharedRows)
                return .proven(sharedRows: sharedRows)
            case .accountRowsMissing(let table, let missing):
                CloudSyncBreadcrumb.forwardLineageAccountRowsMissing(table: table, missing: missing, sharedRows: shared)
                return .accountRowsMissing(table: table, missing: missing)
            case .noSharedRows:
                // Inalcanzable: `adoptSharedRowsProof` cuenta las compartidas con la misma función que acaba de dar `shared > 0`.
                // Si alguien las separa, el lado seguro es no subir.
                CloudSyncBreadcrumb.forwardLineageChecked(verdict: "unproven", liveRows: liveRows, sharedRows: 0)
                return .unproven(liveRows: liveRows)
            }
        }
        let liveRows = live.values.reduce(0) { $0 + $1.count }
        guard liveRows > 0 else {
            CloudSyncBreadcrumb.forwardLineageChecked(verdict: "noLiveRows", liveRows: 0, sharedRows: 0)
            return .noLivePersonalRows
        }
        CloudSyncBreadcrumb.forwardLineageChecked(verdict: "unproven", liveRows: liveRows, sharedRows: 0)
        return .unproven(liveRows: liveRows)
    }

    /// DRY-RUN read-only (panel DEBUG, §3.4): pasos 1,3,4 SIN backfill (paso 2) NI upload (paso 6). Enumera el
    /// backend (MISMO camino verificado contra merkle que el reconcile — SERIO 1), inventario local (con nils
    /// visibles — sin backfill materializa `needsIdentity` por tabla) y diffea. NO muta nada (molde
    /// `scanOrphanMetadata`/`computeDryRun`). `nil` = red (transient) al enumerar, enumeración incompleta O inventario
    /// local ilegible.
    func adoptOrphanDryRun() async -> AdoptOrphanDiff.Plan? {
        guard let enumeration = await enumerateBackendSyncIDs() else { return nil }
        guard await verifyEnumerationComplete(enumeration) else { return nil }
        do {
            return AdoptOrphanDiff.compute(inventory: try collectAdoptInventory(), backendSyncIDs: enumeration.known)
        } catch {
            return nil  // inventario ilegible: un diff parcial mentiría en el panel igual que en el reconcile
        }
    }

    /// Enumeración del backend: `known` = TODAS las identidades (upserts Y tombstones — para el diff);
    /// `liveByTable` = solo las VIVAS por tabla (para cruzar contra los counts del Merkle, SERIO 1).
    private struct BackendEnumeration {
        let known: Set<UUID>
        let liveByTable: [String: Set<UUID>]
        /// La clave de linaje (`LineageTwinKey.backend`) de cada fila VIVA de una tabla sintética cuyos campos la dejan leer.
        /// Sin entrada = clave ilegible, que la prueba de cobertura trata como «puede ser cualquiera».
        var liveKeys: [UUID: String] = [:]
        /// La clave de fusión (`LineageTwinKey.fusion`) de cada fila VIVA que la tiene: semillas que un deduplicador funde.
        var liveFusionKeys: [UUID: String] = [:]
        /// El instante (ms, componente físico del HLC) de la última escritura que conoce el backend, upserts y tombstones.
        /// `nil` si alguna no se deja leer o no hay ninguna: entonces ninguna fila local se da por nacida después.
        var lastWriteMs: Int64?
    }

    /// Enumera TODAS las identidades que el backend conoce (upserts Y tombstones) por páginas read-only (idiom
    /// `sweepZombies`). `nil` = red (transient). El loop copia el shape de `sweepZombies`: cursor, high-water,
    /// break si página vacía o sin progreso.
    private func enumerateBackendSyncIDs() async -> BackendEnumeration? {
        var known: Set<UUID> = []
        var liveByTable: [String: Set<UUID>] = [:]
        var liveKeys: [UUID: String] = [:]
        var liveFusionKeys: [UUID: String] = [:]
        var lastWriteMs: Int64?
        var lastWriteReadable = true
        var cursor: Int64 = 0
        while true {
            switch await tombstoneSource.pullPage(since: cursor, limit: 500) {
            case let .page(page):
                for delta in page.deltas {
                    known.insert(delta.syncID)
                    do {
                        let physical = try HLC.parse(delta.hlc).physicalMs
                        lastWriteMs = max(lastWriteMs ?? physical, physical)
                    } catch {
                        lastWriteReadable = false
                    }
                    if delta.op == .tombstone {
                        // El wire es materialized-rows (cada fila aparece con su ESTADO final), pero el
                        // remove es defensivo por si un upsert previo de la misma identidad ya la contó viva.
                        liveByTable[delta.entityType]?.remove(delta.syncID)
                        liveKeys[delta.syncID] = nil
                        liveFusionKeys[delta.syncID] = nil
                    } else {
                        liveByTable[delta.entityType, default: []].insert(delta.syncID)
                        liveKeys[delta.syncID] = LineageTwinKey.backend(table: delta.entityType, fields: delta.fields)
                        liveFusionKeys[delta.syncID] = LineageTwinKey.fusion(table: delta.entityType, fields: delta.fields)
                    }
                }
                let next = max(page.maxServerSeq, cursor)
                if page.deltas.isEmpty || next <= cursor {   // agotado / sin progreso
                    return BackendEnumeration(known: known, liveByTable: liveByTable, liveKeys: liveKeys,
                                              liveFusionKeys: liveFusionKeys,
                                              lastWriteMs: lastWriteReadable ? lastWriteMs : nil)
                }
                cursor = next
            case .sessionExpired, .accountUnavailable, .transient:
                return nil
            }
        }
    }

    /// SERIO 1 del review: verificación POSITIVA de completitud de la enumeración contra los counts de filas
    /// VIVAS por tabla de `/sync/merkle` (cero endpoints nuevos — `RemoteMerkle.entities` ya los trae). Para
    /// cada tabla del merkle: `count > enumerado` → enumeración INCOMPLETA (página vacía prematura /
    /// paginación no-monótona con 200 OK) → breadcrumb + `false` (el llamador devuelve `.transient`
    /// retomable). El sentido inverso (enumerado > merkle) PASA: deletes concurrentes solo encogen el diff =
    /// conservador. Cualquier outcome no-snapshot del fetch → `false` (transient).
    private func verifyEnumerationComplete(_ enumeration: BackendEnumeration) async -> Bool {
        guard case .snapshot(let merkle) = await merkleClient.fetchMerkle() else { return false }
        for (table, entity) in merkle.entities {
            let got = enumeration.liveByTable[table]?.count ?? 0
            if entity.count > got {
                CloudSyncBreadcrumb.adoptReconcileEnumerationIncomplete(
                    table: table, expected: entity.count, got: got)
                return false
            }
        }
        return true
    }

    /// Inventario `(table, syncID?)` de TODAS las filas VIVAS de las 16 entidades (manifest I12), por los
    /// accessors de identidad existentes. La `table` es el nombre Postgres (`EntityEmission.table`), la clave
    /// del diff contra `PulledDelta.entityType`. Fetch CONCRETO por tipo (regla `#Predicate`). LANZA si una tabla no
    /// se deja leer.
    private func collectAdoptInventory() throws -> [(table: String, syncID: UUID?)] {
        var out: [(table: String, syncID: UUID?)] = []
        try addAdoptInventory(TransactionItem.self, emission: EntityEmissionMap.transactionItem, identity: { $0.syncID }, into: &out)
        try addAdoptInventory(InboxDraft.self, emission: EntityEmissionMap.inboxDraft, identity: { $0.syncID }, into: &out)
        try addAdoptInventory(Category.self, emission: EntityEmissionMap.category, identity: { $0.syncID }, into: &out)
        try addAdoptInventory(FavoritePayment.self, emission: EntityEmissionMap.favoritePayment, identity: { $0.syncID }, into: &out)
        try addAdoptInventory(MerchantMemory.self, emission: EntityEmissionMap.merchantMemory, identity: { $0.syncID }, into: &out)
        try addAdoptInventory(ExchangeRate.self, emission: EntityEmissionMap.exchangeRate, identity: { $0.syncID }, into: &out)
        try addAdoptInventory(Budget.self, emission: EntityEmissionMap.budget, identity: { $0.id }, into: &out)
        try addAdoptInventory(ScheduledPayment.self, emission: EntityEmissionMap.scheduledPayment, identity: { $0.id }, into: &out)
        try addAdoptInventory(Account.self, emission: EntityEmissionMap.account, identity: { $0.shortcutID }, into: &out)
        try addAdoptInventory(Subcategory.self, emission: EntityEmissionMap.subcategory, identity: { $0.shortcutID }, into: &out)
        try addAdoptInventory(Tag.self, emission: EntityEmissionMap.tag, identity: { $0.id }, into: &out)
        try addAdoptInventory(NotificationItem.self, emission: EntityEmissionMap.notificationItem, identity: { $0.id }, into: &out)
        try addAdoptInventory(CashFlowPlan.self, emission: EntityEmissionMap.cashFlowPlan, identity: { $0.id }, into: &out)
        try addAdoptInventory(CashFlowLine.self, emission: EntityEmissionMap.cashFlowLine, identity: { $0.id }, into: &out)
        try addAdoptInventory(CashFlowOverride.self, emission: EntityEmissionMap.cashFlowOverride, identity: { $0.id }, into: &out)
        try addAdoptInventory(GroupBridgePreference.self, emission: EntityEmissionMap.groupBridgePreference, identity: { $0.id }, into: &out)
        return out
    }

    private func addAdoptInventory<M: PersistentModel>(
        _ type: M.Type, emission: EntityEmission<M>, identity: (M) -> UUID?,
        into out: inout [(table: String, syncID: UUID?)]
    ) throws {
        for model in try fetchInventory(M.self, step: "adopt-inventory") {
            out.append((emission.table, identity(model)))
        }
    }

    /// Construye los `SnapshotRowInput` full-row de EXACTAMENTE las filas huérfanas del plan (fetch dirigido +
    /// filtro por el set de identidades objetivo, por tabla). Reusa el builder per-row del uploader (misma
    /// emisión). Fetch CONCRETO por tipo (regla `#Predicate`). LANZA si una tabla con huérfanas no se deja leer.
    private func buildOrphanRowInputs(_ orphans: [String: [UUID]]) throws -> [SnapshotRowInput] {
        var inputs: [SnapshotRowInput] = []
        try addOrphanInputs(TransactionItem.self, emission: EntityEmissionMap.transactionItem, className: SyncEntityType.transactionItem, identity: { $0.syncID }, orphans: orphans, into: &inputs)
        try addOrphanInputs(InboxDraft.self, emission: EntityEmissionMap.inboxDraft, className: SyncEntityType.inboxDraft, identity: { $0.syncID }, orphans: orphans, into: &inputs)
        try addOrphanInputs(Category.self, emission: EntityEmissionMap.category, className: SyncEntityType.category, identity: { $0.syncID }, orphans: orphans, into: &inputs)
        try addOrphanInputs(FavoritePayment.self, emission: EntityEmissionMap.favoritePayment, className: SyncEntityType.favoritePayment, identity: { $0.syncID }, orphans: orphans, into: &inputs)
        try addOrphanInputs(MerchantMemory.self, emission: EntityEmissionMap.merchantMemory, className: SyncEntityType.merchantMemory, identity: { $0.syncID }, orphans: orphans, into: &inputs)
        try addOrphanInputs(ExchangeRate.self, emission: EntityEmissionMap.exchangeRate, className: SyncEntityType.exchangeRate, identity: { $0.syncID }, orphans: orphans, into: &inputs)
        try addOrphanInputs(Budget.self, emission: EntityEmissionMap.budget, className: SyncEntityType.budget, identity: { $0.id }, orphans: orphans, into: &inputs)
        try addOrphanInputs(ScheduledPayment.self, emission: EntityEmissionMap.scheduledPayment, className: SyncEntityType.scheduledPayment, identity: { $0.id }, orphans: orphans, into: &inputs)
        try addOrphanInputs(Account.self, emission: EntityEmissionMap.account, className: SyncEntityType.account, identity: { $0.shortcutID }, orphans: orphans, into: &inputs)
        try addOrphanInputs(Subcategory.self, emission: EntityEmissionMap.subcategory, className: SyncEntityType.subcategory, identity: { $0.shortcutID }, orphans: orphans, into: &inputs)
        try addOrphanInputs(Tag.self, emission: EntityEmissionMap.tag, className: SyncEntityType.tag, identity: { $0.id }, orphans: orphans, into: &inputs)
        try addOrphanInputs(NotificationItem.self, emission: EntityEmissionMap.notificationItem, className: SyncEntityType.notificationItem, identity: { $0.id }, orphans: orphans, into: &inputs)
        try addOrphanInputs(CashFlowPlan.self, emission: EntityEmissionMap.cashFlowPlan, className: SyncEntityType.cashFlowPlan, identity: { $0.id }, orphans: orphans, into: &inputs)
        try addOrphanInputs(CashFlowLine.self, emission: EntityEmissionMap.cashFlowLine, className: SyncEntityType.cashFlowLine, identity: { $0.id }, orphans: orphans, into: &inputs)
        try addOrphanInputs(CashFlowOverride.self, emission: EntityEmissionMap.cashFlowOverride, className: SyncEntityType.cashFlowOverride, identity: { $0.id }, orphans: orphans, into: &inputs)
        try addOrphanInputs(GroupBridgePreference.self, emission: EntityEmissionMap.groupBridgePreference, className: SyncEntityType.groupBridgePreference, identity: { $0.id }, orphans: orphans, into: &inputs)
        return inputs
    }

    private func addOrphanInputs<M: PersistentModel>(
        _ type: M.Type, emission: EntityEmission<M>, className: String, identity: (M) -> UUID?,
        orphans: [String: [UUID]], into inputs: inout [SnapshotRowInput]
    ) throws {
        guard let ids = orphans[emission.table], !ids.isEmpty else { return }
        let targetSet = Set(ids)
        for model in try fetchInventory(M.self, step: "adopt-orphan-inputs") {
            guard let sid = identity(model), targetSet.contains(sid) else { continue }
            inputs.append(MigrationSnapshotUploader.makeSnapshotRowInput(
                model: model, syncID: sid, emission: emission, className: className, calendar: calendar))
        }
    }
}

/// La última confirmación del lease de la ida, por REFERENCIA: la escribe la puerta (`confirmMigrationLease`) y la leen el
/// uploader y `verify` antes de cada trozo (ticket `displaced-migration-leader-keeps-uploading-after-a-takeover`). Guarda el
/// instante en que se PREGUNTÓ —el servidor estampa el lease después de recibir la pregunta— con `ContinuousClock`, que
/// sigue contando con el teléfono en reposo y no se mueve si cambian la hora. IN-MEMORY: tras relanzar, la primera página
/// vuelve a preguntar. Solo la escribe un `ok`; una confirmación vieja deja de valer por el reloj, sin borrarla.
final class MigrationLeaseWitness {
    private let clock: () -> ContinuousClock.Instant
    private var confirmedAt: ContinuousClock.Instant?

    init(clock: @escaping () -> ContinuousClock.Instant) {
        self.clock = clock
    }

    func now() -> ContinuousClock.Instant { clock() }

    func confirm(askedAt: ContinuousClock.Instant) { confirmedAt = askedAt }

    /// `false` sin confirmación: nadie ha preguntado todavía.
    func isConfirmed(within window: Duration) -> Bool {
        guard let confirmedAt else { return false }
        return clock() - confirmedAt < window
    }
}
