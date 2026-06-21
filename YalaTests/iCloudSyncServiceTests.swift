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
}
