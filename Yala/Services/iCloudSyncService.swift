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
    private(set) var lastImportError: CKError?
    private(set) var consecutiveExportFailures: Int = 0

    /// Whether iCloud account is available (sync is automatic when true).
    var isAccountAvailable: Bool {
        SwiftDataConfiguration.isICloudAvailable()
    }

    /// Split group sync status (from CKSyncEngine) — preserved from 2.0.
    var splitSyncStatus: SplitSyncManager.SyncStatus {
        SplitSyncManager.shared.syncStatus
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

    private static let stalledThresholdDays = 7

    // MARK: - Initialization

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accountDidChange),
            name: .NSUbiquityIdentityDidChange,
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
        checkAccountStatus()
    }

    // MARK: - Event Handling

    private func handleContainerNotification(_ note: Notification) {
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

        apply(eventType: rawType, error: event.error as? CKError, endDate: event.endDate)
    }

    /// Testable core. Flat parameters — tests call this directly without
    /// constructing NSPersistentCloudKitContainer.Event (which has private init).
    func apply(eventType: RawEventType, error: CKError?, endDate: Date?) {
        // Not-authenticated overrides everything → no account.
        if let error, error.code == .notAuthenticated {
            pendingFailedTransition?.cancel()
            setStatus(.noAccount)
            return
        }

        switch eventType {
        case .setup:
            if let error {
                // Setup failures are shown immediately (no debounce) — container
                // failed to initialize, user needs to know.
                setStatus(.failed(
                    code: error.code,
                    endDate: endDate ?? .now,
                    retriable: isRetriable(error)
                ))
            } else if let endDate {
                setStatus(.success(endDate))
            } else {
                setStatus(.syncing(kind: .setup))
            }

        case .importEvent:
            if let error {
                lastImportError = error
                scheduleFailedTransition(code: error.code, retriable: isRetriable(error))
            } else if let endDate {
                lastSuccessfulImportDate = endDate
                pendingFailedTransition?.cancel()
                promoteToIdleOrStalled()
            } else {
                setStatus(.syncing(kind: .importing))
            }

        case .exportEvent:
            if let error {
                lastExportError = error
                consecutiveExportFailures += 1
                let retriable = isRetriable(error)
                scheduleFailedTransition(code: error.code, retriable: retriable)
                TelemetryService.track(.cloudkitExportFailed, parameters: [
                    "code": String(error.code.rawValue),
                    "retriable": String(retriable),
                ])
            } else if let endDate {
                let duration = lastSuccessfulExportDate.map { endDate.timeIntervalSince($0) } ?? 0
                lastSuccessfulExportDate = endDate
                consecutiveExportFailures = 0
                pendingFailedTransition?.cancel()
                promoteToIdleOrStalled()
                TelemetryService.track(.cloudkitExportSucceeded, parameters: [
                    "duration_bucket": durationBucket(duration),
                ])
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
        let hasFailureHistory = consecutiveExportFailures > 0 || lastExportError != nil

        if days > Self.stalledThresholdDays && hasFailureHistory {
            let wasAlreadyStalled = status.isStalled
            setStatus(.stalled(
                daysSinceLastSuccess: days,
                lastError: lastExportError?.code
            ))
            if !wasAlreadyStalled {
                TelemetryService.track(.cloudkitStalledDetected, parameters: [
                    "days_bucket": daysBucket(days),
                ])
            }
        } else {
            setStatus(.idle)
        }
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

    /// Pings CloudKit to wake up the sync engine, saves local changes,
    /// deduplicates seed categories, and refreshes all views.
    /// The observer now reflects real progress during this call.
    func forceSync(modelContext: ModelContext) async {
        guard isAccountAvailable else {
            setStatus(.noAccount)
            return
        }
        guard !status.isSyncing else { return }

        setStatus(.syncing(kind: .exporting))

        do {
            let container = CKContainer(identifier: SwiftDataConfiguration.cloudKitContainerIdentifier)
            _ = try await container.privateCloudDatabase.allRecordZones()
            try modelContext.save()
            CategoryDeduplicationService.deduplicateSeedCategories(in: modelContext)
            SessionState.shared.incrementDataVersion()
            // Don't set status here — the observer will surface the real result.
        } catch {
            #if DEBUG
            print("iCloudSync: Force sync error: \(error)")
            #endif
            if let ckError = error as? CKError {
                apply(eventType: .exportEvent, error: ckError, endDate: nil)
            } else {
                // Non-CKError (e.g. context save) — keep prior state, just log.
            }
        }
    }

    // MARK: - Testing Hooks

    #if DEBUG
    /// Reset state between tests. Not exposed in release.
    func _testReset() {
        pendingFailedTransition?.cancel()
        pendingFailedTransition = nil
        status = .idle
        lastSuccessfulExportDate = nil
        lastSuccessfulImportDate = nil
        lastExportError = nil
        lastImportError = nil
        consecutiveExportFailures = 0
    }

    /// QA helper: force .failed immediately (skipping the 3s debounce) and
    /// auto-reset to .idle after `visibleFor` seconds so the indicator can be
    /// verified across all tabs without waiting for a real failure.
    func _qaSimulateFailed(code: CKError.Code = .networkUnavailable, visibleFor: TimeInterval = 10) {
        pendingFailedTransition?.cancel()
        lastExportError = CKError(code)
        consecutiveExportFailures += 1
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
