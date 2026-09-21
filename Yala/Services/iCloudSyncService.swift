//
//  iCloudSyncService.swift
//  Yala
//
//  Observes NSPersistentCloudKitContainer events to expose real sync state.
//  Replaces the former optimistic model that lied about sync status.
//
//  Core flow:
//  - `startObserving()` registers a NotificationCenter observer (idempotent).
//  - The observer extracts the Event from Apple's payload and delegates to
//    `apply(eventType:error:endDate:)`, which is the testable core.
//  - Tests call `apply` directly with flat parameters — no need to construct
//    the private-init NSPersistentCloudKitContainer.Event struct.
//
//  Debounce: failed transitions wait 3s before becoming UI-visible. A success
//  event within that window cancels the pending failure, avoiding flicker on
//  flaky networks.
//

import CloudKit
import CoreData
import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class iCloudSyncService {

    // MARK: - Singleton

    static let shared = iCloudSyncService()

    // MARK: - State

    enum SyncStatus: Equatable {
        case idle
        case syncing(kind: Kind)
        case success(Date)
        case failed(code: CKError.Code, endDate: Date, retriable: Bool)
        case stalled(daysSinceLastSuccess: Int, lastError: CKError.Code?)
        case noAccount

        enum Kind: Equatable { case importing, exporting, setup }

        // Helpers — associated values break `==` comparisons with bare cases.
        var isIdle: Bool { if case .idle = self { return true }; return false }
        var isSyncing: Bool { if case .syncing = self { return true }; return false }
        /// Solo el import personal (no export/setup). El crash del grafo a medio importar es por
        /// IMPORT; gatear el bridge por esto (no por `isSyncing`) evita bloquearlo durante exports.
        var isImporting: Bool { if case .syncing(.importing) = self { return true }; return false }
        var isSuccess: Bool { if case .success = self { return true }; return false }
        var isFailed: Bool { if case .failed = self { return true }; return false }
        var isStalled: Bool { if case .stalled = self { return true }; return false }
        var isNoAccount: Bool { if case .noAccount = self { return true }; return false }
        var needsAttention: Bool { isFailed || isStalled }
    }

    /// Flat event type for internal dispatch (mirrors NSPersistentCloudKitContainer.EventType
    /// but constructible in tests).
    enum RawEventType { case setup, importEvent, exportEvent }

    // MARK: - Observable State

    private(set) var status: SyncStatus = .idle
    private(set) var lastSuccessfulExportDate: Date?
    private(set) var lastSuccessfulImportDate: Date?
    private(set) var lastExportError: CKError?
    /// Cuándo se vio `lastExportError`: la fecha del evento de export que falló (`endDate`, o `startDate` si no
    /// trae fin). `lastExportError` no se limpia con un export con éxito (`icloud-export-error-latch-never-clears`),
    /// así que quien necesite saber si el error SIGUE vigente compara esta fecha con `lastSuccessfulExportDate`.
    /// Lo hace la espera de «Volver a iCloud» (`ReverseUploadBlockerLogic`); los demás lectores siguen igual.
    /// `nil` = sin error, o un evento sin fechas.
    private(set) var lastExportErrorAt: Date?
    private(set) var lastImportError: CKError?
    /// Cuándo se vio `lastImportError`. Espejo exacto de `lastExportErrorAt` y por el mismo motivo:
    /// `lastImportError` **no se limpia con un import con éxito**, así que sin fecha no se puede saber
    /// si la palabra de CloudKit sigue vigente. Lo usa el desenlace de «Restaurar desde iCloud»
    /// (`RestoreImportSettlement`), que necesita distinguir un import que TARDA de uno que FALLA:
    /// `hasObservedImportActivity` los enciende a los dos. `nil` = sin error, o un evento sin fechas.
    private(set) var lastImportErrorAt: Date?
    /// Consecutive failed sync cycles (setup/import/export) with no success in
    /// between. Resets on ANY successful event. Gates whether a *transient*
    /// error surfaces the banner, and feeds `.stalled` detection.
    private(set) var consecutiveFailures: Int = 0

    /// Flag in-memory que indica si CloudKit completó al menos un importEvent
    /// con endDate (sin error). Usado por servicios dependientes de data
    /// remota (e.g. UserSegmentService) para decidir si su estado es confiable.
    private(set) var hasCompletedFirstImport: Bool = false

    /// Flag in-memory: ¿se observó CUALQUIER `.importEvent` personal esta sesión (en curso O completado)?
    /// Distingue "hay un import en marcha/ocurrido → SÍ hay data remota" de "store vacío → ningún import
    /// llega nunca". El gate del sync de grupos lo usa para promover con seguridad un store vacío tras una
    /// ventana de gracia, sin arriesgar un `save()` sobre un grafo a medio importar (ver
    /// `BootSaveGateLogic.resolveWaitByQuiescence`). Un store vacío nunca dispara `.importEvent`, así que
    /// este flag se queda `false` para él; un restore con datos lo pone `true` apenas arranca el import.
    private(set) var hasObservedImportActivity: Bool = false

    /// **Paso 9 · el espejo contestó que no hay cuenta.** Un evento con `CKError.notAuthenticated` lo pone a
    /// `true`; cualquier evento con éxito lo apaga. Es la prueba de CloudKit —no la del token de iCloud
    /// Drive— de que no hay copia a la que subir, y la usa el cierre privado para avisar de que no la hay
    /// (`PrivateSignOutExportGateLogic.copyChannel`). `status == .noAccount` NO sirve para esto: también lo
    /// pone `checkAccountStatus()` por el token, que con Drive apagado miente.
    private(set) var mirrorReportedNotAuthenticated: Bool = false

    /// **Paso 9 · el ANCLA del export: el INICIO del último export con éxito**, persistido. Todo cambio local
    /// confirmado antes de ese instante viajó en él; lo posterior puede no haberlo hecho. Es lo que el cierre
    /// privado compara contra el historial para saber si puede borrar (`PersonalExportPendingCounter`).
    ///
    /// Persistido y no en memoria porque el cierre puede llegar en un proceso donde el espejo aún no ha
    /// exportado nada; y bajo `cloudSync.*` porque ese prefijo lo excluye a propósito el barrido de
    /// preferencias de «Vaciar datos» y del boot-wipe. Sobrevive al borrado del store y es correcto que lo
    /// haga: las escrituras del store nuevo son todas posteriores, así que cuentan como pendientes hasta que
    /// un export las confirme. `nil` = nunca se vio un export con éxito (entonces cuenta todo lo local).
    var confirmedExportStart: Date? {
        Self.readConfirmedExportStart(exportAnchorDefaults)
    }

    nonisolated static let confirmedExportStartKey = "cloudSync.confirmedExportStartedAt"

    /// Dominio del ancla. `.standard` en producción; `_testReset()` lo cambia por uno aislado para que ningún
    /// test escriba en el `UserDefaults` del simulador.
    @ObservationIgnored var exportAnchorDefaults: UserDefaults = .standard

    /// El ancla que sirve ahora: una guardada en el FUTURO se lee como ausente
    /// (`PrivateSignOutExportGateLogic.usableAnchor`: el reloj retrocedió con la app cerrada).
    nonisolated static func readConfirmedExportStart(_ defaults: UserDefaults, now: Date = .now) -> Date? {
        guard defaults.object(forKey: confirmedExportStartKey) != nil else { return nil }
        let stored = Date(timeIntervalSince1970: defaults.double(forKey: confirmedExportStartKey))
        return PrivateSignOutExportGateLogic.usableAnchor(stored, now: now)
    }

    /// MONÓTONO: un evento viejo que llegue tarde nunca retrasa el ancla. Retrasarla solo haría contar de
    /// más (lado seguro), pero adelantarla con un evento fuera de orden sería el lado peligroso, y el `max`
    /// cierra las dos direcciones. Un ancla del futuro se lee como ausente, así que el export siguiente la
    /// reemplaza en vez de quedarse por detrás de ella para siempre.
    nonisolated static func recordConfirmedExportStart(_ start: Date, _ defaults: UserDefaults, now: Date = .now) {
        if let current = readConfirmedExportStart(defaults, now: now), current >= start { return }
        defaults.set(start.timeIntervalSince1970, forKey: confirmedExportStartKey)
    }

    /// Se invalida cuando el ancla deja de probar lo que prueba: cambia la cuenta de iCloud, cambia el reloj,
    /// o CloudKit dice que no hay cuenta. No se borra en el boot-wipe del cierre, y es a propósito: las
    /// escrituras del store nuevo son todas posteriores, así que cuentan como pendientes igual.
    nonisolated static func clearConfirmedExportStart(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: confirmedExportStartKey)
    }

    /// ¿es seguro hacer `save()` del store personal AHORA? Verdadero solo si NO hay un import
    /// en curso y pasó la ventana de quietud desde el último import (quiescencia). Un `save()`
    /// sobre el coordinator del store personal mientras NSPersistentCloudKitContainer importa
    /// dispara el `_assertionFailure` interno de SwiftData (SIGTRAP). Adaptador runtime sobre
    /// `SubcategoryDedupGate.decide` (la lógica pura testeada); mismo gate que usan
    /// `retryPendingBridges` y el apply del pull de Grupos.
    var isImportQuiescent: Bool {
        SubcategoryDedupGate.decide(
            now: .now,
            lastImportDate: lastSuccessfulImportDate,
            isSyncing: status.isImporting,
            lastDedupRunAt: nil
        ) == .run
    }

    /// Whether iCloud account is available (sync is automatic when true).
    var isAccountAvailable: Bool {
        #if DEBUG
        if let forced = _testForceAccountAvailable { return forced }
        #endif
        return SwiftDataConfiguration.isICloudAvailable()
    }

    /// Assigns a new status only if it differs from the current one. Prevents
    /// redundant @Observable notifications when the same event arrives repeatedly.
    private func setStatus(_ newStatus: SyncStatus) {
        guard newStatus != status else { return }
        #if DEBUG
        print("iCloudSync: status transition \(status) → \(newStatus)")
        #endif
        status = newStatus
    }

    // MARK: - Internals

    private var observerToken: NSObjectProtocol?
    private var pendingFailedTransition: Task<Void, Never>?
    /// Watchdog para "Forzar sincronización": si el container no emite ningún
    /// evento (caso "nada que exportar"), el observer nunca apaga el
    /// `.syncing(.exporting)` que pone `forceSync` → spinner colgado. Este Task lo
    /// resetea a `.idle` tras una ventana si seguimos en `.syncing`. Se cancela en
    /// cuanto el observer emite cualquier evento (`apply`) — entonces él manda.
    private var pendingForceSyncReset: Task<Void, Never>?

    private static let stalledThresholdDays = 7

    /// Consecutive failed sync cycles (no success in between) required before a
    /// *transient/retriable* error becomes user-visible as `.failed`. A single
    /// cold-start hiccup never reaches this — only a sustained problem does.
    /// Non-retriable (actionable) errors ignore this and surface immediately
    /// (after the standard debounce). Tunable.
    private static let failureThreshold = 3

    // MARK: - Initialization

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accountDidChange),
            name: .NSUbiquityIdentityDidChange,
            object: nil
        )
        // Paso 9 · el ancla del export compara relojes de pared: si el reloj cambia, deja de probar nada.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemClockDidChange),
            name: .NSSystemClockDidChange,
            object: nil
        )
        checkAccountStatus()
    }

    deinit {
        // Singleton — never actually deinits in production. removeObserver(self)
        // handles the @objc selector observer; the block-based observerToken is
        // intentionally not cleaned up here to avoid actor-isolation issues.
        NotificationCenter.default.removeObserver(self)
    }

    /// Starts listening to NSPersistentCloudKitContainer events. Idempotent —
    /// safe to call multiple times. Should be called from YalaApp.init() right
    /// after the ModelContainer is created, so no setup events are missed.
    func startObserving() {
        guard observerToken == nil else { return }
        observerToken = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                self?.handleContainerNotification(note)
            }
        }
        #if DEBUG
        print("iCloudSync: startObserving() registered — listening for NSPersistentCloudKitContainer events")
        #endif
    }

    // MARK: - Account Status

    func checkAccountStatus() {
        if !isAccountAvailable {
            setStatus(.noAccount)
            return
        }
        // Only reset to idle if we were in noAccount — don't clobber observed state.
        if status.isNoAccount {
            setStatus(.idle)
        }
    }

    @objc private func accountDidChange() {
        // Paso 9 · otra cuenta de iCloud, otra historia de exports: lo confirmado para la anterior no dice
        // nada de la nueva. Borrarla es el lado seguro (el cierre privado pasa a «no se puede confirmar»).
        Self.clearConfirmedExportStart(exportAnchorDefaults)
        checkAccountStatus()
    }

    @objc private func systemClockDidChange() {
        Self.clearConfirmedExportStart(exportAnchorDefaults)
    }

    // MARK: - Event Handling

    private func handleContainerNotification(_ note: Notification) {
        #if DEBUG
        // Bajo paralelismo, otras suites de test inicializan ModelContainer con
        // CloudKit y disparan eventos `setup` que contaminan el singleton — los
        // tests de iCloudSyncServiceTests llaman `apply()` directamente. Cuando
        // `_testReset()` activa este flag, ignoramos eventos externos para
        // evitar transiciones espurias a `.syncing(.setup)` durante el assert.
        if _testIgnoreExternalEvents { return }
        #endif
        guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event else {
            #if DEBUG
            print("iCloudSync: handleContainerNotification — notification received but Event payload missing")
            #endif
            return
        }

        let rawType: RawEventType?
        switch event.type {
        case .setup: rawType = .setup
        case .import: rawType = .importEvent
        case .export: rawType = .exportEvent
        @unknown default: rawType = nil
        }
        guard let rawType else { return }

        #if DEBUG
        let errorDesc = (event.error as? CKError).map { "code=\($0.code.rawValue)" } ?? "no_error"
        let endDesc = event.endDate.map { "endDate=\($0)" } ?? "no_endDate"
        print("iCloudSync: event received — type=\(rawType) \(errorDesc) \(endDesc)")
        #endif

        apply(eventType: rawType, error: event.error as? CKError, endDate: event.endDate,
              startDate: event.startDate, succeeded: event.succeeded)
    }

    /// Testable core. Flat parameters — tests call this directly without
    /// constructing NSPersistentCloudKitContainer.Event (which has private init).
    ///
    /// `startDate` (paso 9) solo se usa en el export con éxito: es el ANCLA del cierre privado. `nil` en los
    /// llamadores sintéticos (`forceSync`, tests), que nunca lo fijan — y sin inicio no hay ancla que mover.
    ///
    /// `succeeded` (paso 9) es `Event.succeeded`, y hace falta porque `error` llega filtrado a `CKError`: un
    /// evento que TERMINÓ con un error de otro dominio (los `NSCocoaErrorDomain` 1344xx del espejo) llegaba
    /// con `error == nil` y fecha de fin, y caía en la rama de éxito. El ancla avanzaba sobre un export que no
    /// subió nada, y el cierre privado borraba lo que no estaba en iCloud (review adversarial del paso 9).
    /// Solo gobierna las dos piezas del paso 9 —el ancla y `mirrorReportedNotAuthenticated`—; el resto del
    /// estado sigue como estaba (ticket `icloud-sync-status-treats-non-ck-failures-as-success`).
    func apply(eventType: RawEventType, error: CKError?, endDate: Date?, startDate: Date? = nil,
               succeeded: Bool = true) {
        // Cualquier evento del container significa que el observer está vivo y
        // gobernará el status → el watchdog de force-sync ya no hace falta.
        pendingForceSyncReset?.cancel()
        // Not-authenticated overrides everything → no account.
        if let error, error.code == .notAuthenticated {
            pendingFailedTransition?.cancel()
            mirrorReportedNotAuthenticated = true
            Self.clearConfirmedExportStart(exportAnchorDefaults)
            setStatus(.noAccount)
            return
        }

        switch eventType {
        case .setup:
            if let error {
                consecutiveFailures += 1
                surfaceOrSuppress(error)
            } else if let endDate {
                consecutiveFailures = 0
                if succeeded { mirrorReportedNotAuthenticated = false }
                setStatus(.success(endDate))
            } else {
                setStatus(.syncing(kind: .setup))
            }

        case .importEvent:
            // Cualquier importEvent (en curso, completado o con error) implica que hay data remota que
            // importar → marca actividad de import para el gate de grupos (un store vacío nunca llega aquí).
            hasObservedImportActivity = true
            if let error {
                lastImportError = error
                lastImportErrorAt = endDate ?? startDate
                consecutiveFailures += 1
                surfaceOrSuppress(error)
            } else if let endDate {
                lastSuccessfulImportDate = endDate
                consecutiveFailures = 0
                if succeeded { mirrorReportedNotAuthenticated = false }
                pendingFailedTransition?.cancel()
                promoteToIdleOrStalled()
                if !hasCompletedFirstImport {
                    hasCompletedFirstImport = true
                    NotificationCenter.default.post(
                        name: .iCloudFirstImportCompleted,
                        object: nil
                    )
                }
                // M6: cada import successful dispara este event (no solo el primero).
                // Consumido por GroupBridgeRaceCleaner para autodelete drafts pendientes
                // Caso A cuando llega TX cuenta real vía sync personal.
                NotificationCenter.default.post(
                    name: .transactionsImportedFromSync,
                    object: nil
                )
            } else {
                setStatus(.syncing(kind: .importing))
            }

        case .exportEvent:
            if let error {
                lastExportError = error
                lastExportErrorAt = endDate ?? startDate
                consecutiveFailures += 1
                surfaceOrSuppress(error)
                MetricsService.canary(.cloudkitExportFailed, detail: "code=\(error.code.rawValue)|retriable=\(isRetriable(error))")
            } else if let endDate {
                let duration = lastSuccessfulExportDate.map { endDate.timeIntervalSince($0) } ?? 0
                lastSuccessfulExportDate = endDate
                consecutiveFailures = 0
                // Paso 9: solo un export que TERMINÓ BIEN confirma algo (ver `succeeded` en la firma).
                if succeeded {
                    mirrorReportedNotAuthenticated = false
                    if let startDate {
                        Self.recordConfirmedExportStart(startDate, exportAnchorDefaults)
                    }
                }
                pendingFailedTransition?.cancel()
                promoteToIdleOrStalled()
                MetricsService.canary(.cloudkitExportSucceeded, detail: durationBucket(duration))
            } else {
                setStatus(.syncing(kind: .exporting))
            }
        }
    }

    /// Duration buckets keep telemetry privacy-friendly — no exact timings.
    private func durationBucket(_ seconds: TimeInterval) -> String {
        switch seconds {
        case ..<1: return "lt_1s"
        case ..<5: return "1_5s"
        case ..<30: return "5_30s"
        default: return "gt_30s"
        }
    }

    private func daysBucket(_ days: Int) -> String {
        switch days {
        case ..<14: return "7_14"
        case ..<30: return "14_30"
        case ..<90: return "30_90"
        default: return "gt_90"
        }
    }

    // MARK: - Transitions

    /// Debounce 3s before surfacing .failed. If a success event arrives within
    /// the window, the pending task is cancelled, avoiding UI flicker.
    private func scheduleFailedTransition(code: CKError.Code, retriable: Bool) {
        pendingFailedTransition?.cancel()
        pendingFailedTransition = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            self.setStatus(.failed(code: code, endDate: .now, retriable: retriable))
        }
    }

    /// Si "Forzar sincronización" no produce cambios, el NSPersistentCloudKitContainer
    /// no emite eventos y el observer nunca apaga el `.syncing(.exporting)` que puso
    /// `forceSync` → spinner colgado (mismo razonamiento que el reset a `.idle` del
    /// `catch` Non-CKError de `forceSync`). Tras la ventana, si seguimos en `.syncing`
    /// (el observer no tomó el control), reseteamos a `.idle`. `apply` lo cancela en
    /// cuanto el observer despierta, así que un export real lento nunca se corta.
    /// Cubre el caso "el container no emite NINGÚN evento". Si emitiera un evento inicial y
    /// luego se colgara sin el terminal (raro, fallo del propio container), el watchdog ya
    /// estaría cancelado — ese caso no empeora respecto al comportamiento previo al fix.
    private func scheduleForceSyncWatchdog() {
        pendingForceSyncReset?.cancel()
        pendingForceSyncReset = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, let self, self.status.isSyncing else { return }
            #if DEBUG
            print("iCloudSync: force-sync watchdog cleared a stuck spinner (no container event)")
            #endif
            self.setStatus(.idle)
        }
    }

    /// Decides whether a sync error reaches the user-visible `.failed` banner.
    /// Non-retriable (actionable) errors surface after the debounce. Transient
    /// errors stay silent until they persist past `failureThreshold` consecutive
    /// cycles — a single cold-start hiccup never alarms the user. Assumes
    /// `consecutiveFailures` was already incremented for this error.
    private func surfaceOrSuppress(_ error: CKError) {
        let retriable = isRetriable(error)
        if Self.shouldSurfaceFailure(
            retriable: retriable,
            consecutiveFailures: consecutiveFailures,
            threshold: Self.failureThreshold
        ) {
            scheduleFailedTransition(code: error.code, retriable: retriable)
        } else {
            // Transient and not yet persistent: keep quiet. Data is safe locally
            // and will sync once conditions recover. Reset to .idle so any
            // in-progress spinner clears and the banner stays hidden.
            #if DEBUG
            print("iCloudSync: transient error suppressed (\(consecutiveFailures)/\(Self.failureThreshold)) code=\(error.code.rawValue)")
            #endif
            setStatus(.idle)
        }
    }

    /// After a successful sync, decide between .idle and .stalled based on
    /// how long since the last success AND whether we have any failure history.
    /// Without failure history, >7 days just means "user didn't create data" —
    /// not a stalled sync.
    private func promoteToIdleOrStalled() {
        guard let last = lastSuccessfulExportDate else {
            setStatus(.idle)
            return
        }
        let days = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
        let hasFailureHistory = consecutiveFailures > 0 || lastExportError != nil

        if days > Self.stalledThresholdDays && hasFailureHistory {
            let wasAlreadyStalled = status.isStalled
            setStatus(.stalled(
                daysSinceLastSuccess: days,
                lastError: lastExportError?.code
            ))
            if !wasAlreadyStalled {
                MetricsService.canary(.cloudkitStalledDetected, detail: daysBucket(days))
            }
        } else {
            setStatus(.idle)
        }
    }

    /// Pure decision: should this error reach the user-visible `.failed` banner?
    /// Non-retriable (actionable) errors always surface. Transient/retriable
    /// errors only surface once they persist past `threshold` consecutive cycles
    /// with no success in between. Exposed for tests.
    static func shouldSurfaceFailure(retriable: Bool, consecutiveFailures: Int, threshold: Int) -> Bool {
        guard retriable else { return true }
        return consecutiveFailures >= threshold
    }

    /// Classification used to decide UI copy and retry strategy.
    /// Exposed for tests.
    func isRetriable(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .requestRateLimited, .zoneBusy, .limitExceeded:
            return true
        case .quotaExceeded, .notAuthenticated, .userDeletedZone,
             .invalidArguments, .managedAccountRestricted:
            return false
        default:
            return true
        }
    }

    // MARK: - Force Sync

    /// Espera hasta que CloudKit complete su primer importEvent (o ya esté completo) hasta `timeout`.
    /// - Parameter timeout: Máximo de segundos a esperar antes de devolver `false`.
    /// - Returns: `true` si el fetch terminó OK; `false` si se agotó el tope, si la espera se CANCELÓ
    ///   o si iCloud no está disponible.
    ///
    /// Observa `Notification.Name.iCloudFirstImportCompleted` que se postea una vez
    /// tras el primer `importEvent` exitoso (ver `apply` línea ~227).
    ///
    /// **Observa cancelación desde el 2026-09-21** (`force-fetch-and-wait-ignores-cancellation`). Antes
    /// solo la resolvían la notificación y su propio tope, así que un `Task` cancelado —la persona sale
    /// de la pantalla que esperaba— seguía clavado aquí hasta agotar los 15 s del arranque o los 90 s
    /// del restore, reteniendo el observer y un `Task` de sleep. Ahora son **tres** las vías que compiten
    /// por resolver la misma continuation, y un doble `resume` es un CRASH y no un test rojo: de ahí
    /// `ForceFetchWaitBox`, que garantiza una sola resolución y suelta lo que las otras dos dejaron vivo.
    ///
    /// **Y el `Task` del tope se CANCELA al resolver.** Hasta hoy sobrevivía al desenlace feliz: la
    /// notificación llegaba a los 2 s y el sleep de 15 (o 90) seguía durmiendo hasta agotarse. Ese
    /// también era trabajo fantasma, solo que no lo veía nadie.
    func forceFetchAndWait(timeout: TimeInterval = 15) async -> Bool {
        guard isAccountAvailable else { return false }
        if hasCompletedFirstImport { return true }

        // Sin `if Task.isCancelled { return false }` de entrada A PROPÓSITO: `withTaskCancellationHandler`
        // ya corre `onCancel` de inmediato cuando el `Task` llega cancelado, así que ese término sería un
        // cinturón sin rama propia — ningún mutante podría matarlo, y un término que ningún test puede
        // matar es un término que sobra. Lo prueba `forceFetchAndWait_returnsFalseWhenAlreadyCancelled`.
        let box = ForceFetchWaitBox()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                let observer = NotificationCenter.default.addObserver(
                    forName: .iCloudFirstImportCompleted, object: nil, queue: .main
                ) { _ in box.resolve(true) }

                let timeoutTask = Task {
                    try? await Task.sleep(for: .seconds(timeout))
                    box.resolve(false)
                }

                box.arm(continuation: continuation, observer: observer, timeoutTask: timeoutTask)
            }
        } onCancel: {
            box.resolve(false)
        }
    }

    /// Espera a que el import de CloudKit se asiente: primero el primer importEvent
    /// (`hasCompletedFirstImport`), luego la ventana de quiescencia
    /// (`isImportQuiescent`). NO basta la quiescencia sola — es `true` ANTES del
    /// primer import y devolvería datos vacíos. Espejo de
    /// `BootSaveGateLogic.resolveWaitByQuiescence`.
    /// - Parameter timeout: tope total (primer import + quietud).
    /// - Returns: `true` si quedó quiescente; `false` si se agotó el timeout
    ///   (el caller procede con los datos parciales que haya).
    ///
    /// - Note: **Este método comparte el mismo defecto de "store vacío" que resolvió H-2026-07-18-8 en
    ///   `awaitPersonalImportForBootSave` — FUERA DE SCOPE de H-8.** Exige `hasCompletedFirstImport`
    ///   (paso 1) antes de considerar la quiescencia; un store que NADA importa (fresh-start wipe cuyos
    ///   datos ya están todos en el server) nunca dispara `.importEvent` → `forceFetchAndWait` agota el
    ///   tope → devuelve `false`. Lo usa el flujo de restore (`RestoreProgressView`); si en el futuro lo
    ///   consumen migraciones `.cloud`/empty-store, aplicar el escape empty-store de `BootSaveGateLogic`
    ///   (gracia + `!hasObservedImportActivity` + quiescente) aquí también.
    func waitForImportQuiescence(timeout: TimeInterval = 90) async -> Bool {
        guard isAccountAvailable else { return false }
        let deadline = Date.now.addingTimeInterval(timeout)
        // 1) Primer importEvent (con el tiempo restante del tope).
        if !hasCompletedFirstImport {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0, await forceFetchAndWait(timeout: remaining) else { return false }
        }
        // 2) Ventana de quiescencia (poll ligero hasta asentarse o agotar el tope).
        while Date.now < deadline {
            if isImportQuiescent { return true }
            if Task.isCancelled { return isImportQuiescent }
            try? await Task.sleep(for: .seconds(1))
        }
        return isImportQuiescent
    }

    /// Outcome of an explicit "Sync now" tap, used to show contextual,
    /// non-alarming feedback in the Sync Settings screen only — never the
    /// global banner. `.unreachable` means the manual attempt couldn't reach
    /// iCloud (offline / transient blip); local data stays safe.
    enum ManualSyncResult: Equatable { case ok, unreachable, failed }

    /// Pings CloudKit to wake up the sync engine, saves local changes,
    /// deduplicates seed categories, and refreshes all views.
    /// The observer reflects real progress during this call; the return value
    /// only drives the contextual offline note in Sync Settings.
    @discardableResult
    func forceSync(modelContext: ModelContext) async -> ManualSyncResult {
        guard isAccountAvailable else {
            setStatus(.noAccount)
            return .failed
        }
        guard !status.isSyncing else { return .ok }

        setStatus(.syncing(kind: .exporting))

        do {
            let container = CKContainer(identifier: SwiftDataConfiguration.cloudKitContainerIdentifier)
            _ = try await container.privateCloudDatabase.allRecordZones()
            try modelContext.save()
            CategoryDeduplicationService.runAllDeduplication(in: modelContext)
            SessionState.shared.incrementDataVersion()
            // Don't set status here — the observer will surface the real result.
            // Pero si no había nada que exportar, el container no emite ningún
            // evento y el `.syncing(.exporting)` de arriba quedaría colgado: el
            // watchdog lo resetea si el observer no responde dentro de la ventana.
            scheduleForceSyncWatchdog()
            return .ok
        } catch {
            #if DEBUG
            print("iCloudSync: Force sync error: \(error)")
            #endif
            if let ckError = error as? CKError {
                apply(eventType: .exportEvent, error: ckError, endDate: nil)
                // A retriable error just means we couldn't reach iCloud right
                // now. The user explicitly asked to sync, so surface it as a
                // contextual note (not the red banner — `apply` keeps the
                // status benign for transient errors).
                return isRetriable(ckError) ? .unreachable : .failed
            } else {
                // Non-CKError (e.g. context save / merge conflict): the
                // NSPersistentCloudKitContainer observer will never fire to
                // clear the `.syncing(.exporting)` we set above, so reset to
                // `.idle` here to avoid a stuck spinner and re-enable retries.
                setStatus(.idle)
                return .failed
            }
        }
    }

    // MARK: - Testing Hooks

    #if DEBUG
    /// Cuando `true`, `handleContainerNotification` ignora eventos externos
    /// del NSPersistentCloudKitContainer. Activado por `_testReset()` para que
    /// los tests aíslen el singleton de la concurrencia con otras suites
    /// paralelas que inicializan CloudKit. Producción nunca toca este flag.
    var _testIgnoreExternalEvents: Bool = false

    /// Forces `isAccountAvailable` to a fixed value in tests. Sims have no iCloud
    /// account → `isAccountAvailable` is false, which short-circuits
    /// `forceFetchAndWait` before its post-account logic. `nil` = use the real check.
    var _testForceAccountAvailable: Bool?

    /// Simula "cuenta iCloud disponible + primer import ya asentado" para UI testing en
    /// simulador (launch arg `-uitest-fake-icloud`, aplicado desde `AppBootstrapper`).
    /// Fuerza `isAccountAvailable` Y marca el primer import completado: sin esto último,
    /// `awaitPersonalImportForBootSave` esperaría el hard-cap (`safeToBootSave()` nunca
    /// sería `true` porque `hasCompletedFirstImport` no se pone solo sin CloudKit real).
    /// NO habilita CloudKit real (el store uitest es local, `.none`). Producción nunca lo llama.
    func _uiTestSimulateAvailableAccount() {
        _testForceAccountAvailable = true
        hasCompletedFirstImport = true
    }

    /// Sitúa el último import exitoso en un instante concreto. Lo necesita el gate de quiescencia
    /// (`SubcategoryDedupGate.decide`, que devuelve `waitQuiescence` mientras no hayan pasado 8 s desde el
    /// último import): sin este seam no hay forma determinista de ejercitar la rama en la que el bridge se
    /// DIFIERE — y esa rama es justo donde el intent durable tiene que quedar armado, porque el reintento
    /// vive en un `Task` con `sleep` en memoria que un kill de la app se lleva.
    func _testSetLastSuccessfulImportDate(_ date: Date?) {
        lastSuccessfulImportDate = date
    }

    /// Reset state between tests. Not exposed in release.
    func _testReset() {
        pendingFailedTransition?.cancel()
        pendingFailedTransition = nil
        pendingForceSyncReset?.cancel()
        pendingForceSyncReset = nil
        status = .idle
        lastSuccessfulExportDate = nil
        lastSuccessfulImportDate = nil
        lastExportError = nil
        lastExportErrorAt = nil
        lastImportError = nil
        lastImportErrorAt = nil
        consecutiveFailures = 0
        hasCompletedFirstImport = false
        hasObservedImportActivity = false
        _testIgnoreExternalEvents = true
        _testForceAccountAvailable = nil
        mirrorReportedNotAuthenticated = false
        // Ancla aislada por test: el singleton escribiría en el `UserDefaults` del simulador.
        if let isolated = UserDefaults(suiteName: "test.icloudsync.\(UUID().uuidString)") {
            exportAnchorDefaults = isolated
        }
    }

    /// Await the pending failed-transition Task so tests can assert post-debounce
    /// state without sleeping the full window. If the Task was cancelled
    /// (success arrived before window elapsed), this returns immediately.
    func _testAwaitPendingTransition() async {
        _ = await pendingFailedTransition?.value
    }

    /// QA helper: force .failed immediately (skipping the 3s debounce) and
    /// auto-reset to .idle after `visibleFor` seconds so the indicator can be
    /// verified across all tabs without waiting for a real failure.
    func _qaSimulateFailed(code: CKError.Code = .networkUnavailable, visibleFor: TimeInterval = 10) {
        pendingFailedTransition?.cancel()
        lastExportError = CKError(code)
        consecutiveFailures += 1
        setStatus(.failed(code: code, endDate: .now, retriable: isRetriable(CKError(code))))
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(visibleFor))
            self?._testReset()
        }
    }

    /// QA helper: force .stalled immediately and auto-reset.
    func _qaSimulateStalled(days: Int = 9, visibleFor: TimeInterval = 10) {
        pendingFailedTransition?.cancel()
        setStatus(.stalled(daysSinceLastSuccess: days, lastError: .quotaExceeded))
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(visibleFor))
            self?._testReset()
        }
    }
    #endif
}

// MARK: - Notifications

extension Notification.Name {
    /// Posted on the main queue tras el primer importEvent exitoso
    /// (con endDate, sin error). Se emite una sola vez por proceso.
    static let iCloudFirstImportCompleted = Notification.Name("iCloudFirstImportCompleted")

    /// M6: dispara cada vez que llegan TXs vía CKSync personal (no solo first import).
    /// Consumido por `GroupBridgeRaceCleaner` para autodelete drafts pendientes Caso A
    /// cuando la TX cuenta real ya llegó vía sync personal.
    static let transactionsImportedFromSync = Notification.Name("transactionsImportedFromSync")
}

// MARK: - iCloud Account Summary

/// Resumen de data del usuario en iCloud, usado por el Welcome Chooser rama B
/// para decidir qué steps del onboarding saltar tras restore.
///
/// EXCLUYE infraestructura A0-Bridge (cuentas sistema, TX bridgeadas, subcat sistema)
/// para reflejar data REAL del user, no derivados.
struct ICloudAccountSummary: Equatable {
    let userName: String?
    let accountsCount: Int
    let transactionsCount: Int
    let budgetsCount: Int
    let groupsCount: Int
    let primaryCurrencyCode: String?
    let categoriesCount: Int

    /// ¿Hay algo que restaurar **de iCloud**? **Cuatro cifras desde el 2026-09-21**
    /// (`restore-treats-budgets-and-groups-as-no-data`): entran los presupuestos, que faltaban.
    ///
    /// El hueco que cierra: `budgetsCount` lo transporta este mismo struct y
    /// `RestoreProgressView.liveCounts` lo pinta subiendo en vivo, así que la pantalla enseñaba llegar
    /// unos presupuestos que la siguiente negaba. CloudKit entrega por lotes y sin orden garantizado,
    /// de modo que «bajó `CD_Budget` y todavía no `CD_Subcategory`» es un estado real y observable.
    ///
    /// **`groupsCount` NO entra, y la decisión está medida — no es un olvido ni una asimetría que
    /// convenga «alinear».** El ticket pedía incluirlo y la medición lo refutó por tres sitios:
    ///
    ///  1. **Los grupos no vienen de iCloud.** `SplitGroup` vive en `groupsSchema`, cuyo store monta
    ///     `cloudKitDatabase: .none`, y sus filas llegan por el backend de Yala. Este predicado
    ///     contesta «¿trajo algo el espejo?», y un conteo que el espejo no puede mover solo puede
    ///     mentir.
    ///  2. **Contarlo TAPA cuatro estados legítimos.** `WelcomeRestoreView` decide con un
    ///     `if hasAnyData` que cortocircuita antes de mirar el veredicto del import, así que con un
    ///     solo grupo local `.importIncomplete` («tus datos siguen llegando», que es el ticket
    ///     `restore-says-no-data-when-the-icloud-import-never-settled`), `.cloudPaused`,
    ///     `.cloudUnverified` y `.notFound` dejarían de alcanzarse. En `FullModeActivationView`, que
    ///     monta esa misma pantalla y a la que **solo se llega desde una sesión solo-grupos**, serían
    ///     inalcanzables POR CONSTRUCCIÓN — y el docblock de su «Empezar desde cero» dice
    ///     explícitamente que cuenta con que ese `.notFound` ocurra.
    ///  3. **La protección que motivaba incluirlo YA EXISTE.** El argumento era que `.notFound` ofrece
    ///     «Empezar desde cero» de botón primario y ese camino purga el dominio de Grupos. Cierto, pero
    ///     no borra sin avisar: pasa por la puerta del paso 4, cuyo `deviceHasData` sale de
    ///     `ContentView.checkHasExistingData()`, que **sí cuenta `SplitGroup`** ⇒ quien solo tiene
    ///     grupos cae en `.foundDeviceData` y recibe el aviso con doble confirmación.
    ///
    /// ⇒ **son dos preguntas distintas y cada una tiene su predicado**: «¿hay algo que restaurar de
    /// iCloud?» es ésta; «¿hay datos que perder en este teléfono?» es `checkHasExistingData()`.
    /// Colapsarlas es lo que produce el error en las dos direcciones.
    ///
    /// **Ni presupuestos ni grupos los crea la app por su cuenta** —en producción un `Budget` nace de
    /// `BudgetEditorViewModel`, de `OnboardingView.createOnboardingBudget()` (si la persona lo pide al
    /// final del onboarding), del backfill de migración o del apply de Modo Nube (hoy DARK); los seeds
    /// que crean presupuestos son `#if DEBUG`—, así que el término nuevo no enciende esto en una
    /// instalación recién hecha. Los de sistema que sí existen (cuentas y subcategorías del bridge) ya
    /// los descuenta el constructor de abajo.
    var hasAnyData: Bool {
        accountsCount > 0 || transactionsCount > 0 || categoriesCount > 0 || budgetsCount > 0
    }

    /// El user puede saltar el onboarding completo si tiene nombre + cuentas + categorías.
    /// (`primaryCurrencyCode` no se chequea: siempre viene poblado desde `defaultCurrencyCode.rawValue`.)
    var isFullyPrefilled: Bool {
        userName != nil && accountsCount > 0 && categoriesCount > 0
    }
}

@MainActor
extension ModelContext {
    /// Construye un resumen de la data del user excluyendo infraestructura A0-Bridge.
    /// - Parameter appPreferences: Fuente del `userName` y `defaultCurrencyCode` (synced via iCloud KV).
    func iCloudAccountSummary(appPreferences: AppPreferences) throws -> ICloudAccountSummary {
        // B-10 defense-in-depth: doble check `isSystemAccount` + `type != "system"` (siempre
        // setean juntos en GroupBridgeSystemEntities). Infra de grupos NUNCA dispara el
        // alert "Detectamos tu cuenta".
        let accounts = try fetchCount(FetchDescriptor<Account>(
            predicate: #Predicate { !$0.isArchived && !$0.isSystemAccount && $0.type != "system" }
        ))
        // Excluye TX bridgeadas (M5 Caso A/B + M6 Caso A/B + settlements). El bridge setea
        // `splitExpenseID`, `splitSettlementID` y `splitGroupZoneID` siempre juntos
        // (GroupTransactionBridge.swift:229,271,302,353,393,560,578,617), por lo que filtrar
        // los 2 IDs es suficiente — añadir un 3er check sobre `splitGroupZoneID` no aporta
        // defensa real (no hay path donde solo el zone ID quede poblado).
        let txs = try fetchCount(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == nil && $0.splitSettlementID == nil }
        ))
        let budgets = try fetchCount(FetchDescriptor<Budget>())
        let groups = try fetchCount(FetchDescriptor<SplitGroup>(
            predicate: #Predicate { !$0.isArchived }
        ))
        let categories = try fetchCount(FetchDescriptor<Subcategory>(
            predicate: #Predicate { !$0.isSystem }
        ))
        let trimmedName = appPreferences.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let userName: String? = (trimmedName.isEmpty || trimmedName == "Usuario") ? nil : trimmedName
        return ICloudAccountSummary(
            userName: userName,
            accountsCount: accounts,
            transactionsCount: txs,
            budgetsCount: budgets,
            groupsCount: groups,
            primaryCurrencyCode: appPreferences.defaultCurrencyCode.rawValue,
            categoriesCount: categories
        )
    }
}

// MARK: - La resolución única de `forceFetchAndWait`

/// Una sola resolución para la espera del primer import, entre las TRES vías que compiten por ella: la
/// notificación de CloudKit, el tope y la cancelación del `Task` que espera.
///
/// **Existe porque un doble `resume` de una `CheckedContinuation` es un CRASH**, no un test rojo, y
/// porque la carrera que lo produce no es teórica: `withTaskCancellationHandler` ejecuta su `onCancel`
/// **antes** de `operation` cuando el `Task` ya venía cancelado, o sea antes de que
/// `withCheckedContinuation` haya instalado nada. Por eso `resolve(_:)` guarda el valor pendiente
/// cuando todavía no hay continuation, y `arm(...)` lo cobra en cuanto la hay — el modo de fallo de no
/// hacerlo es el contrario y peor: una espera que no resuelve NUNCA.
///
/// Y se queda con lo que hay que **soltar** al resolver: el observer de `NotificationCenter` y el
/// `Task` del tope. Cancelar el segundo es lo que impide que un desenlace feliz a los 2 s deje un sleep
/// de 90 s durmiendo detrás.
///
/// **`nonisolated` explícito y `@unchecked Sendable`**: el proyecto compila con
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, así que sin la anotación esta clase nace aislada al
/// MainActor y el `onCancel` —que es un closure `@Sendable` nonisolated— la llamaría desde fuera. El
/// `NSLock` es quien serializa el estado; el actor no pinta nada aquí.
/// **No es `private`, y eso es una decisión medida.** Sus tres pasos —retirar el observer, cancelar el
/// `Task` del tope y resolver una sola vez— son invisibles desde `forceFetchAndWait`: un mutante que
/// quitase el `guard` de resolución única SOBREVIVÍA a la suite entera (medido el 2026-09-21), porque el
/// doble `resume` lo tapa el `continuation = nil` de la línea de al lado. Con la caja alcanzable, esos
/// pasos tienen red de COMPORTAMIENTO (`ForceFetchWaitBoxTests`) en vez de un source-scan.
nonisolated final class ForceFetchWaitBox: @unchecked Sendable {

    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?
    private var observer: NSObjectProtocol?
    private var timeoutTask: Task<Void, Never>?
    private var didResolve = false
    /// El valor con el que resolver en cuanto exista continuation. Solo se llena si alguien resolvió
    /// ANTES de que la hubiera — en la práctica, el `onCancel` de un `Task` que llegó ya cancelado.
    private var pendingValue: Bool?

    /// Entrega la continuation y lo que hay que soltar con ella. Si ya se resolvió antes de existir,
    /// resuelve aquí mismo y suelta en el acto.
    func arm(continuation: CheckedContinuation<Bool, Never>,
             observer: NSObjectProtocol,
             timeoutTask: Task<Void, Never>) {
        lock.lock()
        if let pendingValue {
            lock.unlock()
            NotificationCenter.default.removeObserver(observer)
            timeoutTask.cancel()
            continuation.resume(returning: pendingValue)
            return
        }
        self.continuation = continuation
        self.observer = observer
        self.timeoutTask = timeoutTask
        lock.unlock()
    }

    /// Resuelve la espera con `value`, una sola vez, y suelta observer y `Task` del tope.
    func resolve(_ value: Bool) {
        lock.lock()
        guard !didResolve else { lock.unlock(); return }
        didResolve = true
        let continuation = self.continuation
        let observer = self.observer
        let timeoutTask = self.timeoutTask
        self.continuation = nil
        self.observer = nil
        self.timeoutTask = nil
        if continuation == nil { pendingValue = value }
        lock.unlock()

        if let observer { NotificationCenter.default.removeObserver(observer) }
        timeoutTask?.cancel()
        continuation?.resume(returning: value)
    }
}
