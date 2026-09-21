//
//  iCloudSyncServiceTests.swift
//  YalaTests
//
//  Unit tests for the CloudKit observer core. Tests call `apply(eventType:error:endDate:)`
//  directly with flat parameters to avoid needing NSPersistentCloudKitContainer.Event
//  (which has a private initializer and cannot be mocked).
//

import CloudKit
import Foundation
import Testing

@testable import Yala

@Suite(.serialized)
struct iCloudSyncServiceTests {

    // MARK: - Helpers

    @MainActor
    private func freshService() -> iCloudSyncService {
        let service = iCloudSyncService.shared
        service._testReset()
        // Sims (y CI) no tienen cuenta iCloud → `isAccountAvailable` sería false y
        // cortocircuitaría `forceFetchAndWait` antes de su lógica post-cuenta. Estos
        // tests ejercitan esa lógica, así que asumimos cuenta disponible.
        service._testForceAccountAvailable = true
        return service
    }

    private func ckError(_ code: CKError.Code) -> CKError {
        CKError(code)
    }

    // MARK: - Success flows

    @MainActor @Test func exportSuccess_updatesLastExportDate_transitionsToIdle() {
        let service = freshService()
        let endDate = Date.now

        service.apply(eventType: .exportEvent, error: nil, endDate: endDate)

        #expect(service.lastSuccessfulExportDate == endDate)
        #expect(service.status.isIdle)
        #expect(service.consecutiveFailures == 0)
    }

    @MainActor @Test func importSuccess_updatesLastImportDate() {
        let service = freshService()
        let endDate = Date.now

        service.apply(eventType: .importEvent, error: nil, endDate: endDate)

        #expect(service.lastSuccessfulImportDate == endDate)
    }

    @MainActor @Test func setupSuccess_transitionsToSuccess() {
        let service = freshService()
        let endDate = Date.now

        service.apply(eventType: .setup, error: nil, endDate: endDate)

        #expect(service.status.isSuccess)
    }

    // MARK: - Failure flows

    @MainActor @Test func exportFailure_incrementsConsecutiveFailures() {
        let service = freshService()

        service.apply(eventType: .exportEvent, error: ckError(.networkUnavailable), endDate: nil)
        service.apply(eventType: .exportEvent, error: ckError(.networkUnavailable), endDate: nil)
        service.apply(eventType: .exportEvent, error: ckError(.networkUnavailable), endDate: nil)

        #expect(service.consecutiveFailures == 3)
        #expect(service.lastExportError?.code == .networkUnavailable)
    }

    @MainActor @Test func exportSuccess_resetsConsecutiveFailures() {
        let service = freshService()

        service.apply(eventType: .exportEvent, error: ckError(.networkUnavailable), endDate: nil)
        service.apply(eventType: .exportEvent, error: ckError(.networkUnavailable), endDate: nil)
        #expect(service.consecutiveFailures == 2)

        service.apply(eventType: .exportEvent, error: nil, endDate: Date.now)
        #expect(service.consecutiveFailures == 0)
    }

    @MainActor @Test func setupFailure_retriable_isSuppressedBelowThreshold() {
        let service = freshService()

        service.apply(eventType: .setup, error: ckError(.serviceUnavailable), endDate: nil)

        // A single transient setup failure no longer alarms — it's suppressed
        // below the threshold and the state stays benign (.idle, no banner).
        #expect(!service.status.isFailed)
        #expect(service.status.isIdle)
    }

    // MARK: - notAuthenticated → noAccount

    @MainActor @Test func notAuthenticatedError_transitionsToNoAccount() {
        let service = freshService()

        service.apply(eventType: .exportEvent, error: ckError(.notAuthenticated), endDate: nil)

        #expect(service.status.isNoAccount)
    }

    // MARK: - Debounce on failed

    @MainActor @Test func exportFailure_debouncesFailedTransition() async {
        let service = freshService()

        service.apply(eventType: .exportEvent, error: ckError(.networkUnavailable), endDate: nil)

        // Immediately after failure, status should NOT yet be .failed (debounce 3s).
        #expect(!service.status.isFailed)
    }

    @MainActor @Test func persistentFailureThenSuccessWithin3s_cancelsFailedTransition() async {
        let service = freshService()

        // Reach the threshold so a failed transition is actually scheduled,
        // then a success within the debounce window must cancel it.
        for _ in 0..<3 {
            service.apply(eventType: .exportEvent, error: ckError(.networkUnavailable), endDate: nil)
        }
        service.apply(eventType: .exportEvent, error: nil, endDate: Date.now)

        // Await the cancelled debounce Task to settle (returns ~immediately
        // because cancel() interrupts Task.sleep). Avoids sleeping the full 3s.
        await service._testAwaitPendingTransition()
        #expect(service.status.isIdle)
        #expect(service.consecutiveFailures == 0)
    }

    // MARK: - Transient suppression (Option B: only surface persistent/actionable)

    @MainActor @Test func shouldSurfaceFailure_table() {
        // Non-retriable (actionable) → surface even on the first failure.
        #expect(iCloudSyncService.shouldSurfaceFailure(retriable: false, consecutiveFailures: 1, threshold: 3))
        // Retriable below threshold → suppressed.
        #expect(!iCloudSyncService.shouldSurfaceFailure(retriable: true, consecutiveFailures: 1, threshold: 3))
        #expect(!iCloudSyncService.shouldSurfaceFailure(retriable: true, consecutiveFailures: 2, threshold: 3))
        // Retriable at/above threshold → surface.
        #expect(iCloudSyncService.shouldSurfaceFailure(retriable: true, consecutiveFailures: 3, threshold: 3))
        #expect(iCloudSyncService.shouldSurfaceFailure(retriable: true, consecutiveFailures: 4, threshold: 3))
    }

    @MainActor @Test func transientError_belowThreshold_suppressesToIdle_clearingSpinner() {
        let service = freshService()

        // In-progress export shows a spinner...
        service.apply(eventType: .exportEvent, error: nil, endDate: nil)
        #expect(service.status.isSyncing)

        // ...a single transient failure must NOT surface the banner, and must
        // clear the spinner (→ .idle) so "Sincronizar ahora" isn't stuck loading.
        service.apply(eventType: .exportEvent, error: ckError(.networkUnavailable), endDate: nil)
        #expect(!service.status.isFailed)
        #expect(service.status.isIdle)
    }

    @MainActor @Test func mixedFailures_incrementSameUnifiedCounter() {
        let service = freshService()

        service.apply(eventType: .setup, error: ckError(.serviceUnavailable), endDate: nil)
        service.apply(eventType: .importEvent, error: ckError(.networkUnavailable), endDate: nil)
        service.apply(eventType: .exportEvent, error: ckError(.networkFailure), endDate: nil)

        // Failures across all three event types feed one threshold counter.
        #expect(service.consecutiveFailures == 3)
    }

    @MainActor @Test func transientFailuresThenSuccess_resetsCounterAndStaysIdle() {
        let service = freshService()

        service.apply(eventType: .exportEvent, error: ckError(.networkUnavailable), endDate: nil)
        service.apply(eventType: .importEvent, error: ckError(.networkUnavailable), endDate: nil)
        #expect(service.consecutiveFailures == 2)

        // Any success resets the unified counter.
        service.apply(eventType: .importEvent, error: nil, endDate: Date.now)
        #expect(service.consecutiveFailures == 0)
        #expect(service.status.isIdle)
    }

    // MARK: - Stalled detection

    @MainActor @Test func stalledDetection_after7Days_withFailureHistory() {
        let service = freshService()

        // Simulate past success
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: .now)!
        service.apply(eventType: .exportEvent, error: nil, endDate: eightDaysAgo)

        // Inject failure history
        service.apply(eventType: .exportEvent, error: ckError(.networkUnavailable), endDate: nil)
        // Then a new success to re-evaluate
        let sevenPlusDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: .now)!
        // promoteToIdleOrStalled runs on next success with endDate.
        // We emulate it by triggering success without updating lastSuccessfulExportDate
        // to a recent one — instead, we keep the 8-day-old one and inject new import success.
        service.apply(eventType: .importEvent, error: nil, endDate: Date.now)

        // With 8 days since last export success + failure history → stalled.
        #expect(service.status.isStalled)
    }

    @MainActor @Test func stalled_suppressedWhenNoFailureHistory() {
        let service = freshService()

        // Simulate past success long ago, no failures
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: .now)!
        service.apply(eventType: .exportEvent, error: nil, endDate: eightDaysAgo)

        // Trigger re-evaluation via import success
        service.apply(eventType: .importEvent, error: nil, endDate: Date.now)

        // No failure history → .idle, not .stalled.
        #expect(service.status.isIdle)
    }

    // MARK: - Retriable classification

    @MainActor @Test func retriableClassification_tableMatchesSpec() {
        let service = freshService()

        // Retriable errors
        #expect(service.isRetriable(ckError(.networkUnavailable)) == true)
        #expect(service.isRetriable(ckError(.networkFailure)) == true)
        #expect(service.isRetriable(ckError(.serviceUnavailable)) == true)
        #expect(service.isRetriable(ckError(.requestRateLimited)) == true)
        #expect(service.isRetriable(ckError(.zoneBusy)) == true)
        #expect(service.isRetriable(ckError(.limitExceeded)) == true)

        // Non-retriable errors
        #expect(service.isRetriable(ckError(.quotaExceeded)) == false)
        #expect(service.isRetriable(ckError(.notAuthenticated)) == false)
        #expect(service.isRetriable(ckError(.userDeletedZone)) == false)
        #expect(service.isRetriable(ckError(.invalidArguments)) == false)
        #expect(service.isRetriable(ckError(.managedAccountRestricted)) == false)
    }

    // MARK: - startObserving idempotency

    @MainActor @Test func startObserving_isIdempotent() {
        let service = freshService()

        service.startObserving()
        service.startObserving()
        service.startObserving()

        // No crash, no leak; this is a smoke test. Real behavior verified by the
        // guard that prevents re-registration.
        #expect(Bool(true))
    }

    // MARK: - Syncing transitions (no error, no endDate)

    @MainActor @Test func exportInProgress_transitionsToSyncingExporting() {
        let service = freshService()

        service.apply(eventType: .exportEvent, error: nil, endDate: nil)

        #expect(service.status.isSyncing)
        if case .syncing(let kind) = service.status {
            #expect(kind == .exporting)
        }
    }

    @MainActor @Test func importInProgress_transitionsToSyncingImporting() {
        let service = freshService()

        service.apply(eventType: .importEvent, error: nil, endDate: nil)

        #expect(service.status.isSyncing)
        if case .syncing(let kind) = service.status {
            #expect(kind == .importing)
        }
    }

    /// Regresión: el bridge personal (y `retryPendingBridges`) se gatea por `isImporting`, NO por
    /// `isSyncing`. Solo un IMPORT a medio aplicar crashea el save del grafo personal; un export no.
    /// Si `isImporting` se "simplificara" a aliasear `isSyncing`, el bridge se bloquearía durante los
    /// exports normales del usuario (bloqueo indefinido). Este test fija que discrimina por kind.
    @Test func isImporting_isTrueOnlyForImporting_notExportOrSetupOrIdle() {
        #expect(iCloudSyncService.SyncStatus.syncing(kind: .importing).isImporting == true)
        #expect(iCloudSyncService.SyncStatus.syncing(kind: .exporting).isImporting == false)
        #expect(iCloudSyncService.SyncStatus.syncing(kind: .setup).isImporting == false)
        #expect(iCloudSyncService.SyncStatus.idle.isImporting == false)
        #expect(iCloudSyncService.SyncStatus.success(.now).isImporting == false)
        #expect(iCloudSyncService.SyncStatus.noAccount.isImporting == false)
        // `isSyncing` sigue siendo true para los tres kinds — el gate del bridge usa `isImporting`,
        // que es estrictamente más estrecho.
        #expect(iCloudSyncService.SyncStatus.syncing(kind: .exporting).isSyncing == true)
    }

    // MARK: - forceFetchAndWait (A4 Welcome Restore)

    @MainActor @Test func forceFetchAndWait_returnsTrueImmediatelyWhenAlreadyImported() async {
        let service = freshService()
        // Simula que ya hubo primer importEvent exitoso.
        service.apply(eventType: .importEvent, error: nil, endDate: .now)
        #expect(service.hasCompletedFirstImport)

        let result = await service.forceFetchAndWait(timeout: 0.5)
        #expect(result == true)
    }

    @MainActor @Test func forceFetchAndWait_returnsTrueWhenNotificationFires() async {
        let service = freshService()
        #expect(service.hasCompletedFirstImport == false)

        // Lanza el wait + dispara el evento mid-flight.
        async let result = service.forceFetchAndWait(timeout: 2.0)
        try? await Task.sleep(for: .milliseconds(50))
        service.apply(eventType: .importEvent, error: nil, endDate: .now)

        let value = await result
        #expect(value == true)
    }

    @MainActor @Test func forceFetchAndWait_returnsFalseOnTimeout() async {
        let service = freshService()
        #expect(service.hasCompletedFirstImport == false)

        let result = await service.forceFetchAndWait(timeout: 0.3)
        #expect(result == false)
    }

    // MARK: - forceFetchAndWait · la cancelación (`force-fetch-and-wait-ignores-cancellation`)
    //
    // **Estos casos llevan tope PROPIO, no el del SUT, y eso lo decidió un mutante.** La primera versión
    // se apoyaba en el `timeout:` que se le pasa a la espera: si el arreglo regresaba, la espera se
    // resolvería por su tope y el caso fallaría por duración. **Falso para el modo de fallo que más
    // importa**: si `arm(...)` deja de cobrar el valor que `resolve(_:)` guardó, la caja queda
    // `didResolve == true` con la continuation dentro, así que ni el tope ni la notificación vuelven a
    // resolverla — la espera NO TERMINA NUNCA y el caso CUELGA en vez de ponerse rojo, que es un rojo
    // mal leído (AC nº4 del ticket). Medido con el mutante M2 el 2026-09-21.
    //
    // ⇒ la espera corre en un `Task` suelto que deja su resultado en una caja, y el caso sondea esa caja
    // con su propio tope. Sin valor al tope, FALLA.

    /// Caja de resultado para las esperas con tope propio.
    private actor ResultBox {
        private var value: Bool?
        func set(_ v: Bool) { if value == nil { value = v } }
        func get() -> Bool? { value }
    }

    /// Corre `op` con un tope propio de `topeSegundos`. Devuelve `nil` si no terminó a tiempo — un caso
    /// que cuelga no es un rojo, y por eso el tope no puede vivir dentro del SUT.
    private func conTope(_ topeSegundos: Double,
                         _ op: @escaping @Sendable () async -> Bool) async -> (valor: Bool?, segundos: TimeInterval) {
        let caja = ResultBox()
        let inicio = Date.now
        let trabajo = Task { await caja.set(await op()) }
        while await caja.get() == nil, Date.now.timeIntervalSince(inicio) < topeSegundos {
            try? await Task.sleep(for: .milliseconds(20))
        }
        let valor = await caja.get()
        if valor == nil { trabajo.cancel() }   // que no siga vivo en las suites siguientes
        return (valor, Date.now.timeIntervalSince(inicio))
    }

    /// El `Task` llega a la espera YA cancelado. Es el caso que ejercita la carrera de verdad: el
    /// `onCancel` de `withTaskCancellationHandler` corre ANTES de que `withCheckedContinuation` haya
    /// instalado nada, así que la resolución tiene que quedarse guardada y cobrarse al instalar.
    @MainActor @Test func forceFetchAndWait_returnsFalseWhenAlreadyCancelled() async {
        let service = freshService()
        #expect(service.hasCompletedFirstImport == false)

        let medida = await conTope(1.5) { @MainActor in
            // El `cancel()` llega mientras el `Task` duerme, así que la espera arranca ya cancelada.
            let espera = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(30))
                return await service.forceFetchAndWait(timeout: 10)
            }
            espera.cancel()
            return await espera.value
        }

        #expect(medida.valor == false, """
            La espera arrancó con el `Task` ya cancelado y no resolvió en \(medida.segundos) s \
            (`nil` = no resolvió NUNCA). O `withTaskCancellationHandler` dejó de envolverla, o \
            `arm(...)` dejó de cobrar el valor pendiente que `resolve(_:)` guardó antes de que \
            existiera la continuation — y ese segundo caso deja la espera colgada para siempre, \
            no solo lenta.
            """)
    }

    /// Cancelar a media espera la corta. Es el caso del usuario: sale de la pantalla que esperaba a
    /// iCloud, y hasta el 2026-09-21 la espera seguía viva hasta 15 s (arranque) o 90 s (restore).
    @MainActor @Test func forceFetchAndWait_returnsFalsePromptlyWhenCancelledMidFlight() async {
        let service = freshService()
        #expect(service.hasCompletedFirstImport == false)

        let medida = await conTope(1.5) { @MainActor in
            let espera = Task { @MainActor in await service.forceFetchAndWait(timeout: 10) }
            try? await Task.sleep(for: .milliseconds(100))
            espera.cancel()
            return await espera.value
        }

        #expect(medida.valor == false, """
            Cancelar la espera no la cortó: seguía viva a los \(medida.segundos) s con un tope \
            interno de 10. El `Task` abandonado retiene el observer de `NotificationCenter` y su \
            `Task` de sleep hasta agotar ese tope, con la pantalla ya cerrada.
            """)
    }

    /// La espera de dos pasos hereda la cancelación por su paso 1. Es lo que consumen `RestoreProgressView`
    /// (90 s), los dos borrados de `ContentView` (30 s) y la convergencia del bridge de Grupos (30 s).
    @MainActor @Test func waitForImportQuiescence_returnsFalsePromptlyWhenCancelled() async {
        let service = freshService()
        #expect(service.hasCompletedFirstImport == false)

        let medida = await conTope(1.5) { @MainActor in
            let espera = Task { @MainActor in await service.waitForImportQuiescence(timeout: 10) }
            try? await Task.sleep(for: .milliseconds(100))
            espera.cancel()
            return await espera.value
        }

        #expect(medida.valor == false, """
            La espera de quiescencia seguía viva a los \(medida.segundos) s tras cancelarla. Su \
            paso 1 es `forceFetchAndWait`: si no corta, la pantalla de restaurar sigue contando \
            filas noventa segundos después de que la persona se haya ido.
            """)
    }

    // MARK: - Paso 9 · el ancla del export y la prueba de «no hay cuenta»

    // Las anclas de estos tests van en el PASADO (2023): una del futuro se descarta por diseño
    // (`PrivateSignOutExportGateLogic.usableAnchor`), y con 2027 los tests medirían el descarte, no el ancla.

    @MainActor @Test func exportSuccess_recordsItsStartAsTheAnchor() {
        let service = freshService()
        #expect(service.confirmedExportStart == nil, "el ancla de otro test no puede colarse")
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        service.apply(eventType: .exportEvent, error: nil, endDate: start.addingTimeInterval(5), startDate: start)
        #expect(service.confirmedExportStart == start, "el ancla es el INICIO, no el fin")
    }

    /// Un evento fuera de orden no puede ADELANTAR el ancla hacia atrás… ni un inicio más viejo retrasarla:
    /// el `max` cierra las dos direcciones.
    @MainActor @Test func anchor_isMonotonic() {
        let service = freshService()
        let later = Date(timeIntervalSince1970: 1_700_000_100)
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)
        service.apply(eventType: .exportEvent, error: nil, endDate: later.addingTimeInterval(1), startDate: later)
        service.apply(eventType: .exportEvent, error: nil, endDate: earlier.addingTimeInterval(1), startDate: earlier)
        #expect(service.confirmedExportStart == later)
    }

    @MainActor @Test func anchor_ignoresFailures_inFlightEvents_andImports() {
        let service = freshService()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        service.apply(eventType: .exportEvent, error: ckError(.networkUnavailable), endDate: nil, startDate: start)
        service.apply(eventType: .exportEvent, error: nil, endDate: nil, startDate: start)   // en curso
        service.apply(eventType: .importEvent, error: nil, endDate: start.addingTimeInterval(1), startDate: start)
        #expect(service.confirmedExportStart == nil, "solo un EXPORT que TERMINÓ bien confirma nada")
    }

    @MainActor @Test func anchor_isNotMovedWithoutAStartDate() {
        let service = freshService()
        service.apply(eventType: .exportEvent, error: nil, endDate: .now)
        #expect(service.confirmedExportStart == nil, "sin inicio no hay ancla: el fin daría por subido lo que no")
    }

    /// Un export que TERMINÓ sin éxito con un error que no es de CloudKit llegaba con `error == nil` (el
    /// filtro `as? CKError`) y caía en la rama de éxito: el ancla avanzaba sobre un export que no subió nada
    /// y el cierre privado borraba lo que no estaba en iCloud. `succeeded` lo corta (review del paso 9).
    @MainActor @Test func failedExportWithForeignError_neverConfirms_norClearsNotAuthenticated() {
        let service = freshService()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        service.apply(eventType: .exportEvent, error: ckError(.notAuthenticated), endDate: nil)
        #expect(service.mirrorReportedNotAuthenticated)
        service.apply(eventType: .exportEvent, error: nil, endDate: start.addingTimeInterval(1),
                      startDate: start, succeeded: false)
        #expect(service.confirmedExportStart == nil, "un export fallido no confirma nada")
        #expect(service.mirrorReportedNotAuthenticated, "ni borra la prueba de que no hay cuenta")
        // Control: el mismo evento, con éxito, sí confirma y sí la borra.
        service.apply(eventType: .exportEvent, error: nil, endDate: start.addingTimeInterval(1),
                      startDate: start, succeeded: true)
        #expect(service.confirmedExportStart == start)
        #expect(!service.mirrorReportedNotAuthenticated)
    }

    /// El reloj retrocedió con la app cerrada: el ancla guardada queda en el futuro. Se lee como ausente, y el
    /// export siguiente la reemplaza en vez de quedarse detrás de ella para siempre (el `max` la protegía).
    @MainActor @Test func futureAnchor_readsAsAbsent_andTheNextExportReplacesIt() {
        let service = freshService()
        // Segundos enteros: el ancla viaja como `timeIntervalSince1970` en un Double, y una fecha con
        // fracción no vuelve idéntica del `UserDefaults` (el `==` fallaría por el último bit, no por el ancla).
        let now = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        service.exportAnchorDefaults.set(now.addingTimeInterval(86_400).timeIntervalSince1970,
                                         forKey: iCloudSyncService.confirmedExportStartKey)
        #expect(service.confirmedExportStart == nil)
        let start = now.addingTimeInterval(-10)
        service.apply(eventType: .exportEvent, error: nil, endDate: now, startDate: start)
        #expect(service.confirmedExportStart == start)
    }

    /// Si CloudKit dice que no hay cuenta, lo confirmado antes no prueba nada de la cuenta que venga.
    @MainActor @Test func notAuthenticated_invalidatesTheAnchor() {
        let service = freshService()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        service.apply(eventType: .exportEvent, error: nil, endDate: start.addingTimeInterval(1), startDate: start)
        #expect(service.confirmedExportStart == start)
        service.apply(eventType: .importEvent, error: ckError(.notAuthenticated), endDate: nil)
        #expect(service.confirmedExportStart == nil)
    }

    @MainActor @Test func notAuthenticated_isRemembered_untilAnyEventSucceeds() {
        let service = freshService()
        #expect(!service.mirrorReportedNotAuthenticated)
        service.apply(eventType: .exportEvent, error: ckError(.notAuthenticated), endDate: nil)
        #expect(service.mirrorReportedNotAuthenticated)
        service.apply(eventType: .setup, error: ckError(.networkUnavailable), endDate: nil)
        #expect(service.mirrorReportedNotAuthenticated, "un fallo que no es de cuenta no lo apaga")
        service.apply(eventType: .importEvent, error: nil, endDate: .now)
        #expect(!service.mirrorReportedNotAuthenticated)
    }

    /// `lastExportErrorAt` es lo que deja a la espera de «Volver a iCloud» distinguir un error VIGENTE de uno ya
    /// resuelto (ticket `reverse-upload-has-no-ceiling-and-no-exit`): `lastExportError` no se limpia con un éxito,
    /// y eso NO se cambia aquí. Tres cosas: la fecha es la del evento que falló (fin, o inicio si no trae fin), un
    /// éxito posterior deja el latch pero con una fecha de éxito POSTERIOR a la del error, y el reset la limpia.
    @MainActor @Test func exportFailure_stampsTheErrorDate_andALaterSuccessOutdatesIt() {
        let service = freshService()
        let failedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let succeededAt = failedAt.addingTimeInterval(60)

        service.apply(eventType: .exportEvent, error: ckError(.quotaExceeded), endDate: failedAt)
        #expect(service.lastExportErrorAt == failedAt)

        let startedAt = failedAt.addingTimeInterval(30)
        service.apply(eventType: .exportEvent, error: ckError(.quotaExceeded), endDate: nil, startDate: startedAt)
        #expect(service.lastExportErrorAt == startedAt, "sin fin, la fecha es el inicio del evento que falló")

        service.apply(eventType: .exportEvent, error: nil, endDate: succeededAt)
        #expect(service.lastExportError?.code == .quotaExceeded, "el latch sigue puesto: no se cambia aquí")
        #expect(service.lastSuccessfulExportDate == succeededAt)
        if let errorAt = service.lastExportErrorAt, let successAt = service.lastSuccessfulExportDate {
            #expect(successAt > errorAt, "el éxito es posterior: el error ya no es vigente")
        } else {
            Issue.record("faltan las fechas del error o del éxito")
        }

        service._testReset()
        #expect(service.lastExportErrorAt == nil)
    }
}
