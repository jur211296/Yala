//
//  SplitSyncManager.swift
//  Yala
//
//  Core sync service for shared group data via CKSyncEngine.
//  Two engines: private (zones I own) + shared (zones I was invited to).
//  Coexists with SwiftData auto-sync for private database.
//

import CloudKit
import Foundation
import os.log
import Observation
import SwiftData

@MainActor @Observable
final class SplitSyncManager {

    // MARK: - Singleton

    static let shared = SplitSyncManager()

    // MARK: - Observable State

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case error(String)
        case noAccount
    }

    private(set) var syncStatus: SyncStatus = .idle

    // MARK: - Engines

    private(set) var privateEngine: CKSyncEngine?
    private(set) var sharedEngine: CKSyncEngine?

    // nonisolated references for identity check from delegate. Updated whenever an engine is
    // created OR recreated (promotion to auto-sync). The delegate discards events from an engine
    // that is neither — a stale callback from a recreated engine must not persist state nor route.
    @ObservationIgnored nonisolated(unsafe) private var _privateEngineRef: CKSyncEngine?
    @ObservationIgnored nonisolated(unsafe) private var _sharedEngineRef: CKSyncEngine?

    // MARK: - Dependencies

    /// The shared `mainContext` (set via `setContext`). Kept for the bridge / GroupService calls
    /// and to propagate the dedicated context's changes back to the UI (see `groupSyncContext`).
    private var modelContext: ModelContext?
    /// Dedicated context for the group-sync delegate. Its `save()` persists only group-store models
    /// (`YalaGroups`), so it never carries the half-imported personal graph (`YalaModel`) that
    /// crashes `mainContext` saves during an iCloud restore. Used from `@MainActor` only (like the
    /// rest of the delegate). Derived from the same `ModelContainer` as the mainContext.
    private var groupSyncContext: ModelContext?
    private var container: CKContainer?
    private let logger = Logger(subsystem: "com.yala", category: "SplitSync")

    // Delegate must be kept alive
    private var delegate: SplitSyncDelegate?

    // MARK: - Start Gate (crash-loop fix on iCloud restore)
    // The engines are deferred until the personal first import settles, so the group
    // `save()` never lands on a half-imported personal graph in the shared mainContext.
    // See `SplitSyncStartGate`.
    private var enginesStarted = false
    /// `true` once the engines run with `automaticallySync = true` (personal import settled, or
    /// no iCloud, or hard cap). While `false` the engines are in "export-only" mode: they exist
    /// (so create/invite/enqueue work) but never fetch automatically, and the delegate defers
    /// every `modelContext.save()` so it can't persist the half-imported personal graph.
    private(set) var autoSyncActive = false
    private var firstImportObserver: NSObjectProtocol?
    private var gateWaitTask: Task<Void, Never>?
    private static let hardCapSeconds: TimeInterval = 300  // absolute last-resort cap
    private static let pollInterval: TimeInterval = 15

    // Pending record IDs — internal tracking, not observed by views
    private var pendingRecordSaves: Set<CKRecord.ID> = []

    // P1: observes the dedicated context's saves to signal a UI refresh (see `setContext`).
    private var groupSyncSaveObserver: NSObjectProtocol?

    // Coalescing task for deferred bridge/notifications after remote changes
    private var deferredBridgeTask: Task<Void, Never>?
    private var pendingBridgeExpenseIDs: Set<UUID> = []
    /// Settlement IDs pending bridge. Tracked separately from `pendingBridgeChangeSet` so the bridge
    /// (which writes personal models) can be deferred by import quiescence WITHOUT re-sending the
    /// notifications, which are processed + cleared every pass.
    private var pendingBridgeSettlementIDs: Set<UUID> = []
    private var pendingBridgeChangeSet = RemoteChangeSet()

    // Cleanup observers: acumulan zoneIDs durante el batch de remote records,
    // procesados post-save junto al deferredBridgeTask.
    /// Zones donde el SplitGroup remoto flipped a `isHiddenForAll=true` → dispara `freezeForSoftDelete`.
    private var pendingFreezeZoneIDs: Set<String> = []
    /// Zones donde el current user pasó de `.active → .removed` vía admin remoto → dispara full cleanup.
    private var pendingRemovedSelfZoneNames: Set<String> = []

    // Records that failed due to quota exceeded — retried on foreground
    private var quotaFailedRecordIDs: Set<CKRecord.ID> = []

    // MARK: - State Persistence

    // nonisolated-safe: file I/O only, no model access
    private nonisolated let stateDirectory: URL = {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to Documents (not /tmp/ which OS can purge)
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fallback = docs.appendingPathComponent("SplitSync", isDirectory: true)
            try? fm.createDirectory(at: fallback, withIntermediateDirectories: true)
            return fallback
        }
        let dir = appSupport.appendingPathComponent("SplitSync", isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            #if DEBUG
            print("SplitSyncManager: Failed to create state directory: \(error)")
            #endif
        }
        return dir
    }()

    // MARK: - Initialization

    private init() {}

    /// Call from AppBootstrapper after services with context are set up.
    ///
    /// Sets up the container + delegate, then either starts the engines now or defers
    /// their creation until the personal CloudKit first import settles. Deferring avoids
    /// a `save()` on the half-imported personal graph (shared mainContext) that crashes
    /// SwiftData with an internal `_assertionFailure` on an iCloud-restored device.
    /// Called once per cold launch (warm resume does not re-initialize).
    func initialize() {
        setupContainerAndDelegate()

        let decision = SplitSyncStartGate.decideStart(
            isAccountAvailable: iCloudSyncService.shared.isAccountAvailable,
            hasCompletedFirstImport: iCloudSyncService.shared.hasCompletedFirstImport
        )
        // Diagnóstico INTENCIONALMENTE fuera de `#if DEBUG`: este crash solo reproduce en
        // CloudKit Production (device restaurado de iCloud), verificable solo vía TestFlight
        // Release en Console.app. Sin PII — solo bools de estado, counts y "private"/"shared".
        // Eventos puntuales (1× por cold launch), no hot path.
        logger.notice("SplitSync gate: decision=\(String(describing: decision), privacy: .public) account=\(iCloudSyncService.shared.isAccountAvailable, privacy: .public) firstImport=\(iCloudSyncService.shared.hasCompletedFirstImport, privacy: .public)")

        switch decision {
        case .startNow:
            startEngines(autoSync: true)
        case .deferUntilImport:
            // Create the engines in export-only mode (so create/invite/enqueue work) and observe
            // the personal import to promote them to auto-sync once the graph is safe to save on.
            startEngines(autoSync: false)
            observeFirstImportThenStart()
        }
    }

    /// Cheap, no-network setup: CKContainer, one-time state migration, delegate.
    /// Kept separate from engine creation so `container`/`delegate` exist while the
    /// engines are deferred (e.g. `acceptShare` needs `container`).
    private func setupContainerAndDelegate() {
        let containerID = CKConstants.containerID
        self.container = CKContainer(identifier: containerID)

        // One-time: clear stale state from old container after migration
        let migrationKey = "SplitSync_ContainerMigrated_v1"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            clearState(name: "private")
            clearState(name: "shared")
            UserDefaults.standard.set(true, forKey: migrationKey)
            #if DEBUG
            logger.info("Cleared old sync state for container migration")
            #endif
        }

        delegate = SplitSyncDelegate(manager: self)
    }

    /// Builds one CKSyncEngine from a loaded state serialization. Shared by `startEngines` (initial,
    /// either mode) and `enableAutoSync` (recreate in auto mode) so engine config lives in one place.
    private func makeEngine(database: CKDatabase, state: CKSyncEngine.State.Serialization?, autoSync: Bool, delegate: SplitSyncDelegate) -> CKSyncEngine {
        var config = CKSyncEngine.Configuration(database: database, stateSerialization: state, delegate: delegate)
        config.automaticallySync = autoSync
        return CKSyncEngine(config)
    }

    /// Creates both CKSyncEngines. Idempotent — single-flight via `enginesStarted`.
    ///
    /// `autoSync = true` → normal mode (the engine fetches/sends automatically; safe when the
    /// personal import has settled or there's no iCloud). `autoSync = false` → "export-only" mode:
    /// the engines exist (so create/invite/enqueue work) but never fetch on their own, and the
    /// delegate defers every `save()`. `enableAutoSync()` later recreates them with `autoSync = true`.
    private func startEngines(autoSync: Bool) {
        guard !enginesStarted else { return }
        guard let container, let delegate else { return }
        enginesStarted = true
        autoSyncActive = autoSync
        // Only cancel the gate when starting in auto mode. In export-only mode the gate
        // (observer + poll) must stay alive to drive `enableAutoSync()` once the import settles.
        if autoSync { cancelGate() }

        let privateState = loadState(name: "private")
        privateEngine = makeEngine(database: container.privateCloudDatabase, state: privateState, autoSync: autoSync, delegate: delegate)
        _privateEngineRef = privateEngine

        let sharedState = loadState(name: "shared")
        sharedEngine = makeEngine(database: container.sharedCloudDatabase, state: sharedState, autoSync: autoSync, delegate: delegate)
        _sharedEngineRef = sharedEngine

        // Export-only window: surface `.syncing` so the indicator doesn't read as "up to date"
        // while the engines are still waiting to fetch.
        syncStatus = autoSync ? .idle : .syncing

        logger.notice("SplitSync engines created — autoSync=\(autoSync, privacy: .public), firstImport=\(iCloudSyncService.shared.hasCompletedFirstImport, privacy: .public), private=\(privateState != nil ? "resumed" : "fresh", privacy: .public), shared=\(sharedState != nil ? "resumed" : "fresh", privacy: .public)")

        // Recover owned groups whose zone never reached CloudKit (created while a previous launch's
        // engines were deferred → createZone no-op'd). Idempotent; gated by the heuristic.
        recoverOwnedGroupZonesIfNeeded()
    }

    /// Promotes the engines from export-only to auto-sync once the personal import has settled
    /// (or the hard cap fired). Recreates both engines with `automaticallySync = true` from the
    /// persisted state (which already holds anything enqueued during the export-only window), so
    /// the proven automatic mode — push, coalescing, retry — resumes. Idempotent.
    private func enableAutoSync() {
        guard !autoSyncActive else { return }
        guard let container, let delegate else { return }

        let importSettled = iCloudSyncService.shared.hasCompletedFirstImport
        autoSyncActive = true
        cancelGate()

        // Capture the OLD engines' in-memory pending changes BEFORE rebuilding. `state.add(...)`
        // persists to disk asynchronously (via the `.stateUpdate` delegate callback), so an enqueue
        // made moments ago during the export-only window (zone recovery, or a user create/invite)
        // may not be in `loadState(...)` yet. Transferring them directly makes the promotion
        // independent of that flush — nothing enqueued is lost on the fast path.
        let oldPrivateRecordChanges = privateEngine?.state.pendingRecordZoneChanges ?? []
        let oldPrivateDBChanges = privateEngine?.state.pendingDatabaseChanges ?? []
        let oldSharedRecordChanges = sharedEngine?.state.pendingRecordZoneChanges ?? []
        let oldSharedDBChanges = sharedEngine?.state.pendingDatabaseChanges ?? []

        // Recreate both engines in auto mode. The persisted stateSerialization carries the change
        // tokens (same mechanism as resume between cold launches).
        let newPrivate = makeEngine(database: container.privateCloudDatabase, state: loadState(name: "private"), autoSync: true, delegate: delegate)
        let newShared = makeEngine(database: container.sharedCloudDatabase, state: loadState(name: "shared"), autoSync: true, delegate: delegate)

        // Assign engines + identity refs together to minimise the window where an old-engine
        // callback could be misrouted. Refs first so events from the new engines route correctly.
        _privateEngineRef = newPrivate
        _sharedEngineRef = newShared
        privateEngine = newPrivate
        sharedEngine = newShared

        // Re-enqueue the captured pending changes onto the new engines (idempotent — duplicates of
        // changes already in the loaded state are coalesced). Now safe to send (auto-sync on).
        if !oldPrivateDBChanges.isEmpty { newPrivate.state.add(pendingDatabaseChanges: oldPrivateDBChanges) }
        if !oldPrivateRecordChanges.isEmpty { newPrivate.state.add(pendingRecordZoneChanges: oldPrivateRecordChanges) }
        if !oldSharedDBChanges.isEmpty { newShared.state.add(pendingDatabaseChanges: oldSharedDBChanges) }
        if !oldSharedRecordChanges.isEmpty { newShared.state.add(pendingRecordZoneChanges: oldSharedRecordChanges) }
        syncStatus = .idle

        logger.notice("SplitSync promoted to auto-sync — importSettled=\(importSettled, privacy: .public)")
        TelemetryService.track(.cloudkitGroupSyncPromotedToAuto, parameters: [
            "importSettled": String(importSettled)
        ])
    }

    // MARK: - Owned Zone Recovery

    /// Re-enqueues the zone + records of owned groups whose GroupMeta never reached CloudKit
    /// (created while a previous launch's engines were deferred → `createZone` no-op'd, leaving the
    /// group un-invitable — e.g. the owner's "Jurpi"). **Read-only on the mainContext** (fetch +
    /// `engine.state.add`); never saves, so it's safe during the export-only window. Idempotent —
    /// `.saveZone`/`.saveRecord` are ignored by CloudKit's change tag if already present. Gated by
    /// `needsZoneRecovery` (owner + no system fields) so synced groups are skipped (no sync storm).
    private func recoverOwnedGroupZonesIfNeeded() {
        guard let groupSyncContext, privateEngine != nil else { return }
        // Fetch owned groups; the recovery heuristic (no uploaded GroupMeta) lives in the tested
        // pure-logic `needsZoneRecovery`, applied as the in-memory filter (single source of truth).
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.isOwner == true }
        )
        let toRecover: [SplitGroup]
        do {
            toRecover = try groupSyncContext.fetch(descriptor).filter {
                SplitSyncStartGate.needsZoneRecovery(isOwner: $0.isOwner, hasSystemFields: $0.ckSystemFieldsData != nil)
            }
        } catch {
            logger.error("SplitSync zone recovery fetch failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard !toRecover.isEmpty else { return }

        let zoneManager = SplitZoneManager(syncManager: self)
        for group in toRecover {
            zoneManager.createZone(for: group)  // re-enqueue zone + GroupMeta (no mainContext save)
            reEnqueueOwnedGroupRecords(group: group, context: groupSyncContext)
        }

        logger.notice("SplitSync recovered \(toRecover.count, privacy: .public) owned group zone(s) with no uploaded GroupMeta")
        TelemetryService.track(.cloudkitGroupZoneRecovered, parameters: ["count": String(toRecover.count)])
    }

    /// Re-enqueues a group's member/expense/share/settlement records to the private engine WITHOUT
    /// touching the mainContext (fetch + `engine.state.add` via `enqueueSave`). Used by zone
    /// recovery so the recovered group syncs complete (incl. the admin member) once changes flush.
    private func reEnqueueOwnedGroupRecords(group: SplitGroup, context: ModelContext) {
        let zoneName = group.cloudKitZoneID
        do {
            for m in try context.fetch(FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zoneName })) {
                enqueueSave(modelID: m.id, group: group)
            }
            for e in try context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneName })) {
                enqueueSave(modelID: e.id, group: group)
            }
            for s in try context.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneName })) {
                enqueueSave(modelID: s.id, group: group)
            }
            for st in try context.fetch(FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zoneName })) {
                enqueueSave(modelID: st.id, group: group)
            }
        } catch {
            logger.error("SplitSync re-enqueue records failed for \(zoneName, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Waits for the personal first import to settle, then PROMOTES the export-only engines to
    /// auto-sync (`enableAutoSync()`). The engines already exist (created in export-only mode by
    /// `startEngines(autoSync: false)`); this only flips them to automatic once the graph is safe.
    /// Fast path: the `.iCloudFirstImportCompleted` observer. Safety net: a periodic poll that
    /// promotes at the absolute hard cap (so group sync never stays export-only forever).
    private func observeFirstImportThenStart() {
        // Defensive: the import may have already settled+quieted between decideStart and here.
        if evaluateQuiescentPromotion(reachedHardCap: false) { return }

        logger.notice("SplitSync export-only — awaiting personal import QUIESCENCE before enabling auto-sync")

        // Fast re-eval when the first import completes — but promotion still needs the quiet window,
        // so this usually just hands off to the poll (which fires once the store goes quiescent).
        firstImportObserver = NotificationCenter.default.addObserver(
            forName: .iCloudFirstImportCompleted, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in _ = self.evaluateQuiescentPromotion(reachedHardCap: false) }
        }

        gateWaitTask = Task { @MainActor [weak self] in
            var elapsed: TimeInterval = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.pollInterval))
                guard !Task.isCancelled, let self, !self.autoSyncActive else { return }
                elapsed += Self.pollInterval
                if self.evaluateQuiescentPromotion(reachedHardCap: elapsed >= Self.hardCapSeconds) { return }
            }
        }
    }

    /// Promote the engines to auto-sync IFF the personal import has settled AND gone quiet
    /// (or the hard cap fired). Shared by the `.iCloudFirstImportCompleted` observer and the poll.
    /// Returns `true` once promoted (or already promoted) so the poll loop can exit.
    @discardableResult
    private func evaluateQuiescentPromotion(reachedHardCap: Bool) -> Bool {
        guard !autoSyncActive else { return true }
        let firstImport = iCloudSyncService.shared.hasCompletedFirstImport
        let isQuiescent = iCloudSyncService.shared.isImportQuiescent
        let resolution = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: firstImport,
            isQuiescent: isQuiescent,
            reachedHardCap: reachedHardCap
        )
        guard resolution == .start else { return false }
        if SplitSyncStartGate.promotedWhileNotQuiescent(hasCompletedFirstImport: firstImport, isQuiescent: isQuiescent) {
            logger.warning("SplitSync gate HARD CAP \(Int(Self.hardCapSeconds))s — promoting to auto-sync while NOT quiescent (firstImport=\(firstImport, privacy: .public), isSyncing=\(iCloudSyncService.shared.status.isSyncing, privacy: .public))")
            TelemetryService.track(.cloudkitGroupSyncGateHardCap, parameters: [
                "isSyncing": String(iCloudSyncService.shared.status.isSyncing)
            ])
        }
        enableAutoSync()
        return true
    }

    /// Removes the gate observer + cancels the poll task. Called by whichever start path wins.
    private func cancelGate() {
        if let firstImportObserver {
            NotificationCenter.default.removeObserver(firstImportObserver)
            self.firstImportObserver = nil
        }
        gateWaitTask?.cancel()
        gateWaitTask = nil
    }

    func setContext(_ ctx: ModelContext) {
        modelContext = ctx
        // Dedicated context for the delegate, on the SAME container/coordinator as the mainContext
        // but a separate context → its save() carries only group-store models, not the personal
        // graph being imported. autosaveEnabled=false: all delegate saves are explicit `try save()`.
        let dedicated = ModelContext(ctx.container)
        dedicated.autosaveEnabled = false
        groupSyncContext = dedicated

        // P1: the dedicated context's saves don't auto-merge into the mainContext (same coordinator,
        // not parent-child). Signal a UI refresh on every dedicated save so the group ViewModels
        // re-fetch (their `loadData` reads fresh from the store). Covers the saves that don't go
        // through `processPendingRemoteChanges` (system fields, conflict, zone recovery).
        if let observer = groupSyncSaveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        groupSyncSaveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: dedicated, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                SessionState.shared.markRemoteChangePending()
            }
        }
    }

    // MARK: - Engine Identity

    // nonisolated: Called from CKSyncEngine delegate (off MainActor)
    nonisolated func isPrivateEngine(_ engine: CKSyncEngine) -> Bool {
        engine === _privateEngineRef
    }

    /// `true` if `engine` is one of the live engines. After `enableAutoSync()` recreates the
    /// engines, a stale callback from a discarded engine must be ignored — otherwise its
    /// `.stateUpdate` would be saved under the wrong file name (corrupting the other engine's
    /// state) and its events would route incorrectly.
    nonisolated func isCurrentEngine(_ engine: CKSyncEngine) -> Bool {
        engine === _privateEngineRef || engine === _sharedEngineRef
    }

    nonisolated func engineName(for engine: CKSyncEngine) -> String {
        isPrivateEngine(engine) ? "private" : "shared"
    }

    // MARK: - State Persistence

    // nonisolated: Called synchronously from CKSyncEngine delegate (not on MainActor)
    nonisolated func saveState(_ serialization: CKSyncEngine.State.Serialization, name: String) {
        let fm = FileManager.default
        let dir = stateDirectory
        // Defensive: re-create directory if purged by OS (disk pressure cleanup)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        let url = dir.appendingPathComponent("\(name).json")
        do {
            let data = try JSONEncoder().encode(serialization)
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            logger.error("Failed to save sync state '\(name)': \(error)")
            #endif
        }
    }

    nonisolated func loadState(name: String) -> CKSyncEngine.State.Serialization? {
        let url = stateDirectory.appendingPathComponent("\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            #if DEBUG
            logger.info("No saved sync state for '\(name)' — starting fresh")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
        } catch {
            #if DEBUG
            logger.error("Failed to load sync state '\(name)': \(error)")
            #endif
            return nil
        }
    }

    private nonisolated func clearState(name: String) {
        let url = stateDirectory.appendingPathComponent("\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            #if DEBUG
            print("SplitSyncManager: clearState('\(name)') failed: \(error)")
            #endif
        }
    }

    // MARK: - Share Acceptance

    /// Accept a CKShare invitation (called from AppDelegate).
    /// - Parameter skipNavigation: When true, accepts share but does NOT navigate (used for invite onboarding).
    func acceptShare(metadata: CKShare.Metadata, skipNavigation: Bool = false) async {
        guard let container else {
            #if DEBUG
            logger.error("Cannot accept share: container not initialized")
            #endif
            return
        }

        do {
            _ = try await container.accept(metadata)
            #if DEBUG
            logger.info("Share accepted — shared engine will fetch zone data automatically")
            #endif

            // Force immediate fetch so the group appears quickly — but only once auto-sync is on.
            // During the export-only window a fetch would run the fetch handler (a save on the
            // half-imported personal graph). The shared engine recreated by enableAutoSync()
            // auto-fetches the joined zone, so the group still appears, just slightly later.
            if autoSyncActive, let sharedEngine {
                do {
                    try await sharedEngine.fetchChanges()
                } catch {
                    logger.error("acceptShare: immediate fetch failed (engine will retry on auto-sync): \(error.localizedDescription, privacy: .public)")
                }
            }

            // Ensure the current iCloud user has a member record in the joined group.
            let zoneName = metadata.share.recordID.zoneID.zoneName
            if let group = group(for: zoneName) {
                do {
                    _ = try await GroupService.shared.ensureCurrentUserMemberExists(in: group, context: groupSyncContext)
                } catch {
                    logger.error("Failed to ensure current user member after share acceptance: \(error.localizedDescription, privacy: .public)")
                    RouterEntryGate.shared.submit(.showGroupSyncError(
                        String(localized: "groups.sync.errorMemberSetup")
                    ))
                }
            }

            // Recompute local isCurrentUser flags (device-specific; not synced).
            await GroupService.shared.refreshCurrentUserFlags(context: groupSyncContext)

            await MainActor.run { TelemetryService.track(.groupInviteAccepted) }

            // Navigate to Groups tab (unless routing is handled by invite/reconnect flow)
            if !skipNavigation {
                await MainActor.run { RouterEntryGate.shared.submit(.navigate(.groups)) }
            }
        } catch {
            logger.error("Share acceptance failed: \(error.localizedDescription, privacy: .public)")
            RouterEntryGate.shared.submit(.showGroupSyncError(
                String(localized: "groups.sync.errorAcceptShare")
            ))
        }
    }

    /// Query the local SplitGroup name for a given zone ID (resolved after sync).
    func groupName(for zoneID: String) -> String? {
        guard let context = groupSyncContext else { return nil }
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.cloudKitZoneID == zoneID }
        )
        do {
            return try context.fetch(descriptor).first?.name
        } catch {
            logger.error("groupName(for:) fetch failed for zone \(zoneID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Fetch the local SplitGroup for a given zone ID (resolved after sync).
    /// Sorted by `createdAt asc` so the canonical (oldest) group wins consistently
    /// if a CloudKit sync race produced duplicates sharing the same `cloudKitZoneID`.
    func group(for zoneID: String) -> SplitGroup? {
        guard let context = groupSyncContext else { return nil }
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.cloudKitZoneID == zoneID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let results: [SplitGroup]
        do {
            results = try context.fetch(descriptor)
        } catch {
            logger.error("group(for:) fetch failed for zone \(zoneID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
        if results.count > 1 {
            #if DEBUG
            logger.error("SplitSyncManager.group(for:): \(results.count) duplicate SplitGroups for zone \(zoneID)")
            #endif
            TelemetryService.cloudkitDuplicateDetected(
                model: "SplitGroup",
                count: results.count,
                context: .runtimeFetch,
                keySuffix: zoneID
            )
        }
        return results.first
    }

    /// Current user's `SplitMember` en una zone (canonical: oldest `joinedAt` si hubiera duplicados).
    /// Reusado por `currentMemberStatus(zoneName:)` y por callsites del bridge.
    func currentUserMember(zoneID: String) -> SplitMember? {
        guard let context = groupSyncContext else { return nil }
        var descriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.isCurrentUser == true },
            sortBy: [SortDescriptor(\.joinedAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            logger.error("currentUserMember(zoneID:) fetch failed for \(zoneID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Estado local del current user en una zone. Nil si no soy miembro local.
    /// Usado para detectar `.alreadyMember` / `.pendingDuplicate` / `.rejectedRetry` /
    /// `.leftRetry` / `.removedRetry` antes de aceptar el share.
    func currentMemberStatus(zoneName: String) -> SplitMemberStatus? {
        currentUserMember(zoneID: zoneName)?.memberStatus
    }

    /// Find the most recently synced group (useful after accepting a share).
    func mostRecentGroup() -> SplitGroup? {
        guard let context = groupSyncContext else { return nil }
        var descriptor = FetchDescriptor<SplitGroup>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            logger.error("mostRecentGroup() fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Access Requests (iOS 26)

    /// Request access to a group share without a direct invitation.
    /// The share owner will be notified and can approve/deny.
    func requestAccess(shareURL: URL) async throws {
        guard let container else {
            throw SplitZoneError.engineNotInitialized
        }

        let operation = CKShareRequestAccessOperation(shareURLs: [shareURL])

        return try await withCheckedThrowingContinuation { continuation in
            operation.perShareAccessRequestResultBlock = { _, _ in
                // Individual results logged only if needed for debugging
            }
            operation.shareAccessRequestResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }

    // MARK: - Pending Changes (Low-Level)

    func markPendingChange(for recordID: CKRecord.ID, in engine: CKSyncEngine?) {
        guard let engine else { return }
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        pendingRecordSaves.insert(recordID)
    }

    func markPendingDeletion(for recordID: CKRecord.ID, in engine: CKSyncEngine?) {
        guard let engine else { return }
        engine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
        pendingRecordSaves.remove(recordID)
    }

    // MARK: - Pending Changes (High-Level — for GC-03 services)

    /// Enqueue a model save for a group I own (private engine).
    func enqueueSave(modelID: UUID, groupID: UUID) {
        let zoneID = CKConstants.zoneID(for: groupID)
        let recordID = CKConstants.recordID(for: modelID, in: zoneID)
        markPendingChange(for: recordID, in: privateEngine)
    }

    /// Enqueue a model deletion for a group I own (private engine).
    func enqueueDeletion(modelID: UUID, groupID: UUID) {
        let zoneID = CKConstants.zoneID(for: groupID)
        let recordID = CKConstants.recordID(for: modelID, in: zoneID)
        markPendingDeletion(for: recordID, in: privateEngine)
    }

    /// Enqueue a save for a group I was invited to (shared engine).
    func enqueueSharedSave(modelID: UUID, groupZoneID: String, groupZoneOwnerName: String) {
        let ownerName = groupZoneOwnerName.isEmpty ? CKCurrentUserDefaultName : groupZoneOwnerName
        let zoneID = CKRecordZone.ID(zoneName: groupZoneID, ownerName: ownerName)
        let recordID = CKConstants.recordID(for: modelID, in: zoneID)
        markPendingChange(for: recordID, in: sharedEngine)
    }

    /// Enqueue a deletion for a group I was invited to (shared engine).
    func enqueueSharedDeletion(modelID: UUID, groupZoneID: String, groupZoneOwnerName: String) {
        let ownerName = groupZoneOwnerName.isEmpty ? CKCurrentUserDefaultName : groupZoneOwnerName
        let zoneID = CKRecordZone.ID(zoneName: groupZoneID, ownerName: ownerName)
        let recordID = CKConstants.recordID(for: modelID, in: zoneID)
        markPendingDeletion(for: recordID, in: sharedEngine)
    }

    /// Enqueue a save, auto-routing to the correct engine based on group ownership.
    func enqueueSave(modelID: UUID, group: SplitGroup) {
        if group.isOwner {
            enqueueSave(modelID: modelID, groupID: group.id)
        } else {
            enqueueSharedSave(modelID: modelID, groupZoneID: group.cloudKitZoneID, groupZoneOwnerName: resolvedOwnerName(for: group))
        }
    }

    /// Enqueue a deletion, auto-routing to the correct engine based on group ownership.
    func enqueueDeletion(modelID: UUID, group: SplitGroup) {
        if group.isOwner {
            enqueueDeletion(modelID: modelID, groupID: group.id)
        } else {
            enqueueSharedDeletion(modelID: modelID, groupZoneID: group.cloudKitZoneID, groupZoneOwnerName: resolvedOwnerName(for: group))
        }
    }

    private func resolvedOwnerName(for group: SplitGroup) -> String {
        if !group.cloudKitZoneOwnerName.isEmpty { return group.cloudKitZoneOwnerName }
        if let data = group.ckSystemFieldsData,
           let record = CKRecordTranslator.recordFromSystemFields(data)
        {
            return record.recordID.zoneID.ownerName
        }
        return CKCurrentUserDefaultName
    }

    func sendPendingChanges(for group: SplitGroup) async throws {
        let engine = group.isOwner ? privateEngine : sharedEngine
        guard let engine else { throw SplitSyncError.engineNotInitialized }
        try await engine.sendChanges()
    }

    // MARK: - Event Processing (called from delegate)

    func processEvent(_ event: CKSyncEngine.Event, engine: CKSyncEngine) {
        let name = engineName(for: engine)

        switch event {
        case .stateUpdate:
            break // Handled synchronously in delegate (not dispatched)

        case .accountChange(let change):
            handleAccountChange(change)

        case .fetchedDatabaseChanges(let fetched):
            handleFetchedDatabaseChanges(fetched, engineName: name, engine: engine)

        case .fetchedRecordZoneChanges(let fetched):
            handleFetchedRecordZoneChanges(fetched, engineName: name)

        case .sentDatabaseChanges(let sent):
            handleSentDatabaseChanges(sent, engineName: name)

        case .sentRecordZoneChanges(let sent):
            handleSentRecordZoneChanges(sent, engineName: name)

        case .willFetchChanges:
            syncStatus = .syncing

        case .didFetchChanges:
            syncStatus = .idle

        case .willFetchRecordZoneChanges, .didFetchRecordZoneChanges:
            break

        case .willSendChanges:
            syncStatus = .syncing

        case .didSendChanges:
            syncStatus = .idle

        @unknown default:
            break
        }
    }

    // MARK: - Delegate save gate

    /// Guard for every delegate handler that would touch the shared `mainContext`. During the
    /// export-only window (`autoSyncActive == false`, personal import not settled) persisting the
    /// half-imported personal graph can trip SwiftData's internal `_assertionFailure`. Returns
    /// `true` (and logs) when the handler must defer; the fetch after `enableAutoSync()` reconciles
    /// anything skipped. With `automaticallySync = false` the fetch handlers don't run on their own
    /// — this is defence-in-depth plus the real gate for the sent/conflict handlers (export path).
    private func deferMainContextWork(_ reason: String) -> Bool {
        guard SplitSyncStartGate.shouldDeferDelegateSave(autoSyncActive: autoSyncActive) else { return false }
        logger.notice("SplitSync deferring delegate work [\(reason, privacy: .public)] — export-only window, reconciled after auto-sync")
        return true
    }

    // MARK: - Event Handlers

    private func handleFetchedDatabaseChanges(_ fetched: CKSyncEngine.Event.FetchedDatabaseChanges, engineName: String, engine: CKSyncEngine) {
        #if DEBUG
        logger.info("[\(engineName)] fetchedDatabaseChanges: \(fetched.modifications.count) mods, \(fetched.deletions.count) dels")
        #endif

        if deferMainContextWork("fetchedDatabaseChanges") { return }
        guard !fetched.deletions.isEmpty, let groupSyncContext else { return }

        for deletion in fetched.deletions {
            let zoneName = deletion.zoneID.zoneName
            guard let groupID = CKConstants.groupID(from: zoneName) else { continue }

            switch deletion.reason {
            case .deleted:
                #if DEBUG
                logger.info("[\(engineName)] Zone deleted: \(zoneName) — cleaning up local data")
                #endif
                deleteGroupCache(groupID: groupID, context: groupSyncContext)
                purgePendingChanges(for: deletion.zoneID, engine: engine)

            case .purged:
                #if DEBUG
                logger.info("[\(engineName)] Zone purged: \(zoneName) — clearing data + state")
                #endif
                deleteGroupCache(groupID: groupID, context: groupSyncContext)
                purgePendingChanges(for: deletion.zoneID, engine: engine)
                clearState(name: engineName)

            case .encryptedDataReset:
                #if DEBUG
                logger.info("[\(engineName)] Encrypted data reset: \(zoneName) — clearing system fields + re-uploading")
                #endif
                clearState(name: engineName)
                reuploadGroupRecords(groupID: groupID, zoneID: deletion.zoneID, engine: engine, context: groupSyncContext)

            @unknown default:
                deleteGroupCache(groupID: groupID, context: groupSyncContext)
                purgePendingChanges(for: deletion.zoneID, engine: engine)
            }
        }

        do {
            SaveBreadcrumb.willSave("SplitSync.fetchedDatabaseChanges")
            try groupSyncContext.save()
            SaveBreadcrumb.didSave("SplitSync.fetchedDatabaseChanges")
            SessionState.shared.markRemoteChangePending()
        } catch {
            #if DEBUG
            logger.error("[\(engineName)] Failed to save after zone deletion cleanup: \(error)")
            #endif
        }
    }

    private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) {
        switch change.changeType {
        case .signIn:
            syncStatus = .idle
            #if DEBUG
            logger.info("iCloud account signed in")
            #endif

        case .signOut:
            syncStatus = .noAccount
            clearAllLocalGroupData()
            GroupUserIdentityService.shared.clearCache()
            #if DEBUG
            logger.info("iCloud account signed out — cleared local group data")
            #endif

        case .switchAccounts:
            syncStatus = .idle
            clearAllLocalGroupData()
            clearState(name: "private")
            clearState(name: "shared")
            GroupUserIdentityService.shared.clearCache()
            #if DEBUG
            logger.info("iCloud account switched — cleared data + state for re-fetch")
            #endif

        @unknown default:
            break
        }
    }

    /// Delete all local group data (used on sign-out and account switch for privacy).
    private func clearAllLocalGroupData() {
        // Edge case only: a sign-out/switch during the initial restore window (the user just signed
        // in) is near-impossible. Defer the save to stay crash-safe; a normal sign-out (after the
        // import settled, autoSyncActive == true) clears immediately.
        if deferMainContextWork("clearAllLocalGroupData") { return }
        guard let groupSyncContext else { return }

        do {
            let groups = try groupSyncContext.fetch(FetchDescriptor<SplitGroup>())
            for group in groups {
                deleteGroupCache(groupID: group.id, context: groupSyncContext)
            }
            SaveBreadcrumb.willSave("SplitSync.clearAllLocalGroupData")
            try groupSyncContext.save()
            SaveBreadcrumb.didSave("SplitSync.clearAllLocalGroupData")
            SessionState.shared.markRemoteChangePending()
        } catch {
            #if DEBUG
            logger.error("clearAllLocalGroupData: Failed: \(error)")
            #endif
        }
    }

    /// Retry records that previously failed due to iCloud quota exceeded.
    /// Call from sceneDidBecomeActive or when quota status may have changed.
    func retryQuotaFailedRecords() {
        guard !quotaFailedRecordIDs.isEmpty else { return }
        let toRetry = quotaFailedRecordIDs
        quotaFailedRecordIDs.removeAll()

        // Re-enqueue to private engine (shared records go through the same path)
        if let engine = privateEngine {
            engine.state.add(pendingRecordZoneChanges: toRetry.map { .saveRecord($0) })
        }
        if let engine = sharedEngine {
            engine.state.add(pendingRecordZoneChanges: toRetry.map { .saveRecord($0) })
        }

        syncStatus = .idle
        #if DEBUG
        logger.info("Retrying \(toRetry.count) quota-failed records")
        #endif
    }

    private func handleFetchedRecordZoneChanges(_ fetched: CKSyncEngine.Event.FetchedRecordZoneChanges, engineName: String) {
        if deferMainContextWork("fetchedRecordZoneChanges") { return }
        guard let groupSyncContext else { return }

        var changeSet = RemoteChangeSet()

        // Pre-fetch existing IDs scoped to affected zones (GC-06)
        let batchZoneNames = Set(fetched.modifications.map { $0.record.recordID.zoneID.zoneName })
        var existingExpenseIDs: Set<UUID> = []
        var existingSettlementIDs: Set<UUID> = []
        var existingMemberIDs: Set<UUID> = []
        do {
            for zoneName in batchZoneNames {
                let zName = zoneName
                let expDesc = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zName })
                existingExpenseIDs.formUnion(try groupSyncContext.fetch(expDesc).map(\.id))
                let setDesc = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zName })
                existingSettlementIDs.formUnion(try groupSyncContext.fetch(setDesc).map(\.id))
                let memDesc = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zName })
                existingMemberIDs.formUnion(try groupSyncContext.fetch(memDesc).map(\.id))
            }
        } catch {
            #if DEBUG
            logger.error("[\(engineName)] Pre-fetch for change classification failed: \(error)")
            #endif
        }

        // cache `isCurrentUserAdmin` por zoneID dentro del batch — evita fetch repetido.
        var adminCache: [String: Bool] = [:]

        for modification in fetched.modifications {
            let record = modification.record

            // GC-06: Classify changes for notifications
            if let modelID = CKConstants.modelID(from: record.recordID),
               let groupID = CKConstants.groupID(from: record.recordID.zoneID.zoneName) {
                switch record.recordType {
                case CKConstants.RecordType.splitExpense:
                    if existingExpenseIDs.contains(modelID) {
                        changeSet.modifiedExpenses.append((modelID, groupID))
                    } else {
                        changeSet.newExpenses.append((modelID, groupID))
                    }
                case CKConstants.RecordType.splitSettlement:
                    if !existingSettlementIDs.contains(modelID) {
                        changeSet.newSettlements.append((modelID, groupID))
                    }
                case CKConstants.RecordType.splitMember:
                    if !existingMemberIDs.contains(modelID) {
                        // Clasifica el member nuevo. Solo `active` notifica "se unió";
                        // pending solo notifica al admin; un pending recibido por un
                        // no-admin (o un estado terminal) NO dispara notif espuria.
                        let zoneName = record.recordID.zoneID.zoneName
                        let rawStatus = record[CKConstants.MemberField.status] as? String
                        // admin solo importa para pending — compútalo lazy para no fetchear de más.
                        let isPending = rawStatus == SplitMemberStatus.pendingApproval.rawValue
                        let isAdmin = isPending && isCurrentUserAdminOfGroup(zoneName: zoneName, context: groupSyncContext, cache: &adminCache)
                        #if DEBUG
                        print("SplitSync[#16-debug]: splitMember zone=\(zoneName) modelID=\(modelID) status=\(rawStatus ?? "nil") isPending=\(isPending) isAdmin=\(isAdmin)")
                        #endif
                        switch MemberChangeNotificationLogic.classifyNewMember(rawStatus: rawStatus, isCurrentUserAdmin: isAdmin) {
                        case .pendingRequestForAdmin:
                            changeSet.newPendingMembers.append((modelID, groupID))
                        case .joined:
                            changeSet.newMembers.append((modelID, groupID))
                        case .ignore:
                            break
                        }
                    }
                default: break
                }
            }

            applyRemoteRecord(record, context: groupSyncContext, engineName: engineName)
        }

        for deletion in fetched.deletions {
            applyRemoteDeletion(recordID: deletion.recordID, recordType: deletion.recordType, context: groupSyncContext)
        }

        do {
            // Persist remote records before deferred bridge. Auto-sync overhead is
            // mitigated by state persistence limiting CKSyncEngine to incremental fetches.
            SaveBreadcrumb.willSave("SplitSync.fetchedRecordZoneChanges")
            try groupSyncContext.save()
            SaveBreadcrumb.didSave("SplitSync.fetchedRecordZoneChanges")
        } catch {
            #if DEBUG
            logger.error("[\(engineName)] Failed to save after remote changes: \(error)")
            #endif
        }

        // Procesar pending freeze (soft-delete flip) + removed-self cleanup post-save.
        // Idempotente — freezeForSoftDelete + performRemovedSelfCleanup no-op si ya está limpio.
        let freezeZones = pendingFreezeZoneIDs
        let removedSelfZones = pendingRemovedSelfZoneNames
        pendingFreezeZoneIDs.removeAll()
        pendingRemovedSelfZoneNames.removeAll()

        for zoneID in freezeZones {
            guard let group = self.group(for: zoneID) else { continue }
            do {
                try GroupTransactionBridge.shared.freezeForSoftDelete(group: group)
            } catch {
                #if DEBUG
                logger.error("[\(engineName)] freezeForSoftDelete failed for \(zoneID): \(error.localizedDescription, privacy: .public)")
                #endif
            }
        }

        let removedSelfCtx = groupSyncContext
        for zoneName in removedSelfZones {
            Task { @MainActor in
                await GroupService.shared.performRemovedSelfCleanup(zoneName: zoneName, context: removedSelfCtx)
            }
        }

        // Accumulate IDs and changeSets, then coalesce into a single deferred Task.
        // Avoids spawning N independent Tasks if N fetch events arrive in rapid succession.
        pendingBridgeExpenseIDs.formUnion(changeSet.newExpenses.map(\.id) + changeSet.modifiedExpenses.map(\.id))
        pendingBridgeSettlementIDs.formUnion(changeSet.newSettlements.map(\.id))
        pendingBridgeChangeSet.newExpenses.append(contentsOf: changeSet.newExpenses)
        pendingBridgeChangeSet.modifiedExpenses.append(contentsOf: changeSet.modifiedExpenses)
        pendingBridgeChangeSet.newSettlements.append(contentsOf: changeSet.newSettlements)
        pendingBridgeChangeSet.newMembers.append(contentsOf: changeSet.newMembers)
        pendingBridgeChangeSet.newPendingMembers.append(contentsOf: changeSet.newPendingMembers)

        // Cancel previous deferred task and restart — coalescing rapid events
        deferredBridgeTask?.cancel()
        deferredBridgeTask = Task { @MainActor [weak self] in
            // Let CKSyncEngine finish its current event batch before triggering more saves
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled, let self else { return }
            await self.processPendingRemoteChanges()
        }
    }

    /// Runs the coalesced post-fetch work: refresh membership flags (group store — always safe),
    /// process notifications, and bridge remote expenses/settlements to PERSONAL models.
    /// The bridge writes to the personal store (`YalaModel`, the one being imported), so it's gated
    /// by import QUIESCENCE (not the first importEvent, which is premature): if the import isn't
    /// quiescent the bridge is deferred (pending IDs kept) and retried after the quiet window.
    private func processPendingRemoteChanges() async {
        guard let groupSyncContext else { return }

        // Membership flags + notifications: group store / no personal save → always safe; process & clear.
        await GroupService.shared.refreshCurrentUserFlags(context: groupSyncContext)
        let accumulated = pendingBridgeChangeSet
        pendingBridgeChangeSet = RemoteChangeSet()
        if !accumulated.isEmpty {
            GroupNotificationService.shared.processRemoteChanges(accumulated)
        }
        SessionState.shared.markRemoteChangePending()

        // Bridge (personal models): gate by import quiescence.
        let expenseIDs = pendingBridgeExpenseIDs
        let settlementIDs = pendingBridgeSettlementIDs
        guard (!expenseIDs.isEmpty || !settlementIDs.isEmpty), GroupTransactionBridge.shared.isReady else { return }

        // Gate by `isImporting` (not `isSyncing`): only a half-applied IMPORT crashes the personal
        // save; exports don't, so don't block the bridge during the user's normal exports.
        let decision = SubcategoryDedupGate.decide(
            now: .now,
            lastImportDate: iCloudSyncService.shared.lastSuccessfulImportDate,
            isSyncing: iCloudSyncService.shared.status.isImporting,
            lastDedupRunAt: nil
        )
        guard decision == .run else {
            // Import not quiescent → defer the bridge. Mark the expenses `bridgePending` (group store,
            // safe save) so `retryPendingBridges` recovers them if the app is killed before the retry;
            // also schedule an in-session retry after the quiet window. (Settlements have no pending
            // flag — covered only by the in-session retry; documented residual.)
            markExpensesPendingBridge(expenseIDs)
            let retryAfter: TimeInterval
            if case .waitQuiescence(let t) = decision { retryAfter = max(t, 1) } else { retryAfter = 8 }
            logger.notice("SplitSync bridge deferred (import not quiescent: \(String(describing: decision), privacy: .public)) — retry in \(Int(retryAfter), privacy: .public)s")
            scheduleBridgeRetry(after: retryAfter)
            return
        }

        pendingBridgeExpenseIDs.removeAll()
        pendingBridgeSettlementIDs.removeAll()
        if !expenseIDs.isEmpty {
            do { try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: Array(expenseIDs)) }
            catch {
                #if DEBUG
                logger.error("Failed to bridge remote expenses: \(error)")
                #endif
            }
        }
        if !settlementIDs.isEmpty {
            do { try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: Array(settlementIDs)) }
            catch {
                #if DEBUG
                logger.error("Failed to bridge remote settlements: \(error)")
                #endif
            }
        }
    }

    /// Marks remote expenses `bridgePending` in the GROUP store (safe save on `groupSyncContext`) so
    /// `retryPendingBridges` recovers them on next launch if the app is killed while the bridge is
    /// deferred for import quiescence — otherwise the in-memory pending set is lost and the expense
    /// never bridges to a personal TransactionItem.
    private func markExpensesPendingBridge(_ ids: Set<UUID>) {
        guard let groupSyncContext, !ids.isEmpty else { return }
        do {
            let expenses = try groupSyncContext.fetch(FetchDescriptor<SplitExpense>()).filter { ids.contains($0.id) }
            var changed = false
            for expense in expenses where !expense.bridgePending {
                expense.bridgePending = true
                changed = true
            }
            if changed {
                SaveBreadcrumb.willSave("SplitSync.markExpensesPendingBridge")
                try groupSyncContext.save()
                SaveBreadcrumb.didSave("SplitSync.markExpensesPendingBridge")
            }
        } catch {
            logger.error("markExpensesPendingBridge failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Re-runs the deferred bridge after the import quiet window (reuses `deferredBridgeTask` so a
    /// new fetch coalesces/cancels it). Single-flight via the task slot.
    private func scheduleBridgeRetry(after seconds: TimeInterval) {
        deferredBridgeTask?.cancel()
        deferredBridgeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            await self.processPendingRemoteChanges()
        }
    }

    /// ¿el current user es admin del grupo (o owner) en la zona? Cacheado por batch
    /// para evitar fetch repetido cuando llegan múltiples members de un mismo grupo.
    private func isCurrentUserAdminOfGroup(zoneName: String, context: ModelContext, cache: inout [String: Bool]) -> Bool {
        if let cached = cache[zoneName] { return cached }
        let descriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneName && $0.isCurrentUser == true }
        )
        let result: Bool
        do {
            result = try context.fetch(descriptor).first?.isAdmin ?? false
        } catch {
            logger.error("isCurrentUserAdminOfGroup fetch failed for \(zoneName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            result = false
        }
        cache[zoneName] = result
        return result
    }

    private func handleSentDatabaseChanges(_ sent: CKSyncEngine.Event.SentDatabaseChanges, engineName: String) {
        for failure in sent.failedZoneSaves {
            #if DEBUG
            logger.error("[\(engineName)] Zone save failed: \(failure.zone.zoneID.zoneName) — \(failure.error.localizedDescription)")
            #endif
        }
    }

    private func handleSentRecordZoneChanges(_ sent: CKSyncEngine.Event.SentRecordZoneChanges, engineName: String) {
        // Always clean up pending tracking regardless of context availability
        for record in sent.savedRecords {
            pendingRecordSaves.remove(record.recordID)
        }

        // Store system fields from successfully saved records (for conflict-free future uploads).
        // Deferred during the export-only window: don't mutate/save the mainContext (the early
        // return is BEFORE storeSystemFields so the context isn't left dirty). System fields are a
        // conflict-resolution cache — a later upload re-captures them via serverRecordChanged. No
        // data loss; this is what lets the user invite/create during the window without crashing.
        if !sent.savedRecords.isEmpty, let groupSyncContext, !deferMainContextWork("sentRecordZoneChanges.systemFields") {
            for record in sent.savedRecords {
                storeSystemFields(of: record, context: groupSyncContext)
            }
            do {
                SaveBreadcrumb.willSave("SplitSync.sentRecordZoneChanges.systemFields")
                try groupSyncContext.save()
                SaveBreadcrumb.didSave("SplitSync.sentRecordZoneChanges.systemFields")
            } catch {
                #if DEBUG
                logger.error("[\(engineName)] Failed to save system fields after successful upload: \(error)")
                #endif
            }
        }

        for failure in sent.failedRecordSaves {
            let ckError = failure.error as CKError

            switch ckError.code {
            case .serverRecordChanged:
                // Conflict: server wins — accept server version and update local model
                handleConflict(failure: failure, engineName: engineName)

            case .zoneNotFound:
                // Group was deleted by owner — clean up local cache
                handleZoneNotFound(recordID: failure.record.recordID, engineName: engineName)

            case .unknownItem:
                // Record was deleted on server — remove local pending
                pendingRecordSaves.remove(failure.record.recordID)

            case .quotaExceeded:
                syncStatus = .error("iCloud storage full")
                quotaFailedRecordIDs.insert(failure.record.recordID)
                #if DEBUG
                logger.error("[\(engineName)] Quota exceeded — \(failure.record.recordID.recordName) queued for retry")
                #endif

            default:
                // Transient errors (network, rate limit) are retried automatically by CKSyncEngine
                #if DEBUG
                logger.error("[\(engineName)] Record save failed: \(failure.record.recordID.recordName) — \(ckError.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - Conflict Resolution (Server Wins)

    private func handleConflict(failure: CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave, engineName: String) {
        // Defer during the export-only window — the fetch after promotion re-applies the server
        // record (handleFetchedRecordZoneChanges) and reconciles the conflict safely.
        if deferMainContextWork("conflict") { return }
        guard let groupSyncContext,
              let serverRecord = failure.error.serverRecord else {
            #if DEBUG
            logger.error("[\(engineName)] Conflict but no server record available")
            #endif
            return
        }

        // Race fix para serverRecordChanged en SplitGroup. Si el local tenía
        // isHiddenForAll/isArchived=true y server retorna stale false (otro device editó
        // metadata simultáneo), el server-wins default revertiría el flag. Mitigación:
        // capturar pre-state, dejar que apply pise, y re-aplicar la transición true.
        var preIsHiddenForAll: Bool = false
        var preIsArchived: Bool = false
        var splitGroupZoneID: String? = nil
        if serverRecord.recordType == CKConstants.RecordType.groupMeta,
           let modelID = CKConstants.modelID(from: serverRecord.recordID) {
            let descriptor = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.id == modelID })
            let existingGroup: SplitGroup?
            do {
                existingGroup = try groupSyncContext.fetch(descriptor).first
            } catch {
                logger.error("handleConflict: pre-state fetch failed: \(error.localizedDescription, privacy: .public)")
                existingGroup = nil
            }
            if let existing = existingGroup {
                preIsHiddenForAll = existing.isHiddenForAll
                preIsArchived = existing.isArchived
                splitGroupZoneID = existing.cloudKitZoneID
            }
        }

        // Accept server version: update local model from server record
        applyRemoteRecord(serverRecord, context: groupSyncContext, engineName: engineName)
        do {
            SaveBreadcrumb.willSave("SplitSync.conflict")
            try groupSyncContext.save()
            SaveBreadcrumb.didSave("SplitSync.conflict")
        } catch {
            #if DEBUG
            logger.error("[\(engineName)] Failed to save after conflict resolution: \(error)")
            #endif
        }

        // Re-aplicar transición si server stale revirtió flag local.
        if let zoneID = splitGroupZoneID,
           let group = self.group(for: zoneID) {
            var needsReSave = false
            if preIsHiddenForAll && !group.isHiddenForAll {
                group.isHiddenForAll = true
                needsReSave = true
                enqueueSave(modelID: group.id, group: group)
                Task { await GroupService.propagateBoolCustomKey(zoneID: zoneID, key: CKShareCustomKey.isHiddenForAll, value: true) }
            }
            if preIsArchived && !group.isArchived {
                group.isArchived = true
                needsReSave = true
                enqueueSave(modelID: group.id, group: group)
                Task { await GroupService.propagateBoolCustomKey(zoneID: zoneID, key: CKShareCustomKey.isArchived, value: true) }
            }
            if needsReSave {
                do {
                    SaveBreadcrumb.willSave("SplitSync.conflict.raceReapply")
                    try groupSyncContext.save()
                    SaveBreadcrumb.didSave("SplitSync.conflict.raceReapply")
                    #if DEBUG
                    logger.info("[\(engineName)] Conflict race fix: re-applied transition for zone \(zoneID, privacy: .public)")
                    #endif
                } catch {
                    #if DEBUG
                    logger.error("[\(engineName)] Failed to save after race fix re-apply: \(error)")
                    #endif
                }
            }
        }

        // Remove from pending — server version is now authoritative
        pendingRecordSaves.remove(failure.record.recordID)

        #if DEBUG
        logger.info("[\(engineName)] Conflict resolved (server wins): \(failure.record.recordID.recordName)")
        #endif
    }

    // MARK: - Zone Not Found Handling

    private func handleZoneNotFound(recordID: CKRecord.ID, engineName: String) {
        // Defer during the export-only window — the fetched database change (zone deletion) after
        // promotion cleans up the local cache safely.
        if deferMainContextWork("zoneNotFound") { return }
        guard let groupSyncContext else { return }

        let zoneName = recordID.zoneID.zoneName
        guard let groupID = CKConstants.groupID(from: zoneName) else { return }

        // Delete all local data for this group
        deleteGroupCache(groupID: groupID, context: groupSyncContext)
        do {
            SaveBreadcrumb.willSave("SplitSync.zoneNotFound")
            try groupSyncContext.save()
            SaveBreadcrumb.didSave("SplitSync.zoneNotFound")
        } catch {
            #if DEBUG
            logger.error("[\(engineName)] Failed to clean up group \(groupID) after zone not found: \(error)")
            #endif
        }

        pendingRecordSaves.remove(recordID)

        #if DEBUG
        logger.info("[\(engineName)] Zone not found — cleaned up group: \(zoneName)")
        #endif
    }

    /// Remove all local models for a group (zone deleted or participant removed).
    private func deleteGroupCache(groupID: UUID, context: ModelContext) {
        let zoneName = CKConstants.zoneName(for: groupID)

        do {
            // Delete group
            let groupDesc = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.id == groupID })
            if let group = try context.fetch(groupDesc).first {
                context.delete(group)
            }

            // Delete members by zone
            let memberDesc = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zoneName })
            for member in try context.fetch(memberDesc) { context.delete(member) }

            let shareDesc = FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneName })
            for share in try context.fetch(shareDesc) { context.delete(share) }

            // Delete expenses by zone
            let expenseDesc = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneName })
            for expense in try context.fetch(expenseDesc) { context.delete(expense) }

            // Delete settlements by zone
            let settlementDesc = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zoneName })
            for settlement in try context.fetch(settlementDesc) { context.delete(settlement) }
        } catch {
            #if DEBUG
            logger.error("deleteGroupCache: Failed for group \(groupID): \(error)")
            #endif
        }
    }

    // MARK: - Pending Changes Purge

    private func purgePendingChanges(for zoneID: CKRecordZone.ID, engine: CKSyncEngine) {
        let pendingToRemove = engine.state.pendingRecordZoneChanges.filter { change in
            switch change {
            case .saveRecord(let recordID):
                return recordID.zoneID == zoneID
            case .deleteRecord(let recordID):
                return recordID.zoneID == zoneID
            @unknown default:
                return false
            }
        }
        if !pendingToRemove.isEmpty {
            engine.state.remove(pendingRecordZoneChanges: pendingToRemove)
        }

        let pendingDBChanges = engine.state.pendingDatabaseChanges.filter {
            if case .deleteZone(let id) = $0 { return id == zoneID }
            if case .saveZone(let zone) = $0 { return zone.zoneID == zoneID }
            return false
        }
        if !pendingDBChanges.isEmpty {
            engine.state.remove(pendingDatabaseChanges: pendingDBChanges)
        }
    }

    /// Clear system fields and re-enqueue all records for a group (used after encryptedDataReset).
    private func reuploadGroupRecords(groupID: UUID, zoneID: CKRecordZone.ID, engine: CKSyncEngine, context: ModelContext) {
        let zoneName = CKConstants.zoneName(for: groupID)

        do {
            // Clear system fields and re-enqueue each model type
            let groups = try context.fetch(FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.id == groupID }))
            for group in groups {
                group.ckSystemFieldsData = nil
                let recordID = CKConstants.recordID(for: group.id, in: zoneID)
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            }

            let members = try context.fetch(FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zoneName }))
            for member in members {
                member.ckSystemFieldsData = nil
                let recordID = CKConstants.recordID(for: member.id, in: zoneID)
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            }

            let expenses = try context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneName }))
            for expense in expenses {
                expense.ckSystemFieldsData = nil
                let recordID = CKConstants.recordID(for: expense.id, in: zoneID)
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            }

            let shares = try context.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneName }))
            for share in shares {
                share.ckSystemFieldsData = nil
                let recordID = CKConstants.recordID(for: share.id, in: zoneID)
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            }

            let settlements = try context.fetch(FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zoneName }))
            for settlement in settlements {
                settlement.ckSystemFieldsData = nil
                let recordID = CKConstants.recordID(for: settlement.id, in: zoneID)
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            }

            SaveBreadcrumb.willSave("SplitSync.reuploadGroupRecords")
            try context.save()
            SaveBreadcrumb.didSave("SplitSync.reuploadGroupRecords")
        } catch {
            #if DEBUG
            logger.error("reuploadGroupRecords: Failed for group \(groupID): \(error)")
            #endif
        }
    }

    // MARK: - Remote Record Application

    private func applyRemoteRecord(_ record: CKRecord, context: ModelContext, engineName: String) {
        guard let modelID = CKConstants.modelID(from: record.recordID) else { return }

        switch record.recordType {
        case CKConstants.RecordType.groupMeta:
            applyGroupMeta(record, modelID: modelID, context: context, engineName: engineName)
        case CKConstants.RecordType.splitExpense:
            applyExpense(record, modelID: modelID, context: context)
        case CKConstants.RecordType.splitMember:
            applyMember(record, modelID: modelID, context: context)
        case CKConstants.RecordType.splitShare:
            applyShare(record, modelID: modelID, context: context)
        case CKConstants.RecordType.splitSettlement:
            applySettlement(record, modelID: modelID, context: context)
        default:
            break
        }
    }

    private func applyGroupMeta(_ record: CKRecord, modelID: UUID, context: ModelContext, engineName: String) {
        do {
            let descriptor = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.id == modelID })
            if let existing = try context.fetch(descriptor).first {
                // Capturar previo antes del update para detectar flip a hidden.
                let wasHidden = existing.isHiddenForAll
                CKRecordTranslator.update(existing, from: record)
                existing.isOwner = (engineName == "private")
                if !wasHidden && existing.isHiddenForAll {
                    pendingFreezeZoneIDs.insert(existing.cloudKitZoneID)
                }
            } else if let newGroup = CKRecordTranslator.group(from: record) {
                newGroup.isOwner = (engineName == "private")
                context.insert(newGroup)
                // Initial-fetch del invitado fresh-install POST soft-delete: el SplitGroup llega
                // ya con isHiddenForAll=true → encolar (idempotente, no-op si no hay TX).
                if newGroup.isHiddenForAll {
                    pendingFreezeZoneIDs.insert(newGroup.cloudKitZoneID)
                }
            }
        } catch {
            #if DEBUG
            logger.error("SplitGroup fetch failed for \(modelID): \(error)")
            #endif
        }
    }

    private func applyExpense(_ record: CKRecord, modelID: UUID, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == modelID })
            if let existing = try context.fetch(descriptor).first {
                CKRecordTranslator.update(existing, from: record)
            } else if let newExpense = CKRecordTranslator.expense(from: record) {
                context.insert(newExpense)
            }
        } catch {
            #if DEBUG
            logger.error("SplitExpense fetch failed for \(modelID): \(error)")
            #endif
        }
    }

    private func applyMember(_ record: CKRecord, modelID: UUID, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.id == modelID })
            if let existing = try context.fetch(descriptor).first {
                // Snapshot (active && currentUser) ANTES del update — necesario para detectar
                // que el admin remoto pasó a este device de active a removed.
                let wasActiveAndCurrent = existing.isActive && existing.isCurrentUser
                CKRecordTranslator.update(existing, from: record)
                if SoftDeleteObserverLogic.shouldTriggerRemovedSelfCleanup(
                    wasActiveAndCurrentUser: wasActiveAndCurrent,
                    newStatus: existing.memberStatus
                ) {
                    pendingRemovedSelfZoneNames.insert(existing.groupZoneID)
                }
            } else if let newMember = CKRecordTranslator.member(from: record) {
                context.insert(newMember)
                // Edge case conocido: invitado fresh-install + admin ya lo removió previamente
                // → newMember entra con isCurrentUser=false (default init) y el observer no
                // dispara. `refreshCurrentUserFlags` setea isCurrentUser=true después pero el
                // grupo queda visible hasta retap link. Bug latente documentado (no fix aquí).
            }
        } catch {
            #if DEBUG
            logger.error("SplitMember fetch failed for \(modelID): \(error)")
            #endif
        }
    }

    private func applyShare(_ record: CKRecord, modelID: UUID, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<SplitShare>(predicate: #Predicate { $0.id == modelID })
            if let existing = try context.fetch(descriptor).first {
                CKRecordTranslator.update(existing, from: record)
            } else if let newShare = CKRecordTranslator.share(from: record) {
                context.insert(newShare)
            }
        } catch {
            #if DEBUG
            logger.error("SplitShare fetch failed for \(modelID): \(error)")
            #endif
        }
    }

    private func applySettlement(_ record: CKRecord, modelID: UUID, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.id == modelID })
            if let existing = try context.fetch(descriptor).first {
                CKRecordTranslator.update(existing, from: record)
            } else if let newSettlement = CKRecordTranslator.settlement(from: record) {
                context.insert(newSettlement)
            }
        } catch {
            #if DEBUG
            logger.error("SplitSettlement fetch failed for \(modelID): \(error)")
            #endif
        }
    }

    // MARK: - Remote Deletion

    private func applyRemoteDeletion(recordID: CKRecord.ID, recordType: CKRecord.RecordType, context: ModelContext) {
        guard let modelID = CKConstants.modelID(from: recordID) else { return }

        switch recordType {
        case CKConstants.RecordType.groupMeta:
            deleteModel(SplitGroup.self, id: modelID, context: context)
        case CKConstants.RecordType.splitExpense:
            deleteModel(SplitExpense.self, id: modelID, context: context)
        case CKConstants.RecordType.splitMember:
            deleteModel(SplitMember.self, id: modelID, context: context)
        case CKConstants.RecordType.splitShare:
            deleteModel(SplitShare.self, id: modelID, context: context)
        case CKConstants.RecordType.splitSettlement:
            deleteModel(SplitSettlement.self, id: modelID, context: context)
        default:
            break
        }
    }

    private func deleteModel<T: PersistentModel>(_ type: T.Type, id: UUID, context: ModelContext) where T: HasUUID {
        do {
            let descriptor = FetchDescriptor<T>(predicate: #Predicate { $0.id == id })
            if let model = try context.fetch(descriptor).first {
                context.delete(model)
            }
        } catch {
            #if DEBUG
            logger.error("Delete fetch failed for \(String(describing: T.self)) \(id): \(error)")
            #endif
        }
    }

    // MARK: - System Fields Persistence

    /// Store CKRecord system fields on the matching local model so future uploads include the changeTag.
    private func storeSystemFields(of record: CKRecord, context: ModelContext) {
        guard let modelID = CKConstants.modelID(from: record.recordID) else { return }
        let data = CKRecordTranslator.encodeSystemFields(of: record)

        switch record.recordType {
        case CKConstants.RecordType.groupMeta:
            if let model = fetchByID(SplitGroup.self, id: modelID, context: context) {
                model.ckSystemFieldsData = data
            }
        case CKConstants.RecordType.splitExpense:
            if let model = fetchByID(SplitExpense.self, id: modelID, context: context) {
                model.ckSystemFieldsData = data
            }
        case CKConstants.RecordType.splitMember:
            if let model = fetchByID(SplitMember.self, id: modelID, context: context) {
                model.ckSystemFieldsData = data
            }
        case CKConstants.RecordType.splitShare:
            if let model = fetchByID(SplitShare.self, id: modelID, context: context) {
                model.ckSystemFieldsData = data
            }
        case CKConstants.RecordType.splitSettlement:
            if let model = fetchByID(SplitSettlement.self, id: modelID, context: context) {
                model.ckSystemFieldsData = data
            }
        default:
            break
        }
    }

    // MARK: - Record Building (for nextRecordZoneChangeBatch)

    func buildRecord(for recordID: CKRecord.ID) -> CKRecord? {
        guard let groupSyncContext,
              let modelID = CKConstants.modelID(from: recordID) else { return nil }

        let zoneID = recordID.zoneID

        // Try each model type to find the one matching this recordID
        if let group = fetchByID(SplitGroup.self, id: modelID, context: groupSyncContext) {
            return CKRecordTranslator.record(from: group, in: zoneID)
        }
        if let expense = fetchByID(SplitExpense.self, id: modelID, context: groupSyncContext) {
            return CKRecordTranslator.record(from: expense, in: zoneID)
        }
        if let member = fetchByID(SplitMember.self, id: modelID, context: groupSyncContext) {
            return CKRecordTranslator.record(from: member, in: zoneID)
        }
        if let share = fetchByID(SplitShare.self, id: modelID, context: groupSyncContext) {
            return CKRecordTranslator.record(from: share, in: zoneID)
        }
        if let settlement = fetchByID(SplitSettlement.self, id: modelID, context: groupSyncContext) {
            return CKRecordTranslator.record(from: settlement, in: zoneID)
        }

        return nil
    }

    private func fetchByID<T: PersistentModel>(_ type: T.Type, id: UUID, context: ModelContext) -> T? where T: HasUUID {
        let descriptor = FetchDescriptor<T>(predicate: #Predicate { $0.id == id })
        do {
            return try context.fetch(descriptor).first
        } catch {
            #if DEBUG
            logger.error("fetchByID(\(String(describing: T.self)), \(id)) failed: \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - HasUUID Protocol

/// Enables generic fetch by UUID across Split models.
protocol HasUUID: PersistentModel {
    var id: UUID { get }
}

extension SplitGroup: HasUUID {}
extension SplitMember: HasUUID {}
extension SplitExpense: HasUUID {}
extension SplitShare: HasUUID {}
extension SplitSettlement: HasUUID {}

enum SplitSyncError: LocalizedError {
    case engineNotInitialized

    var errorDescription: String? {
        switch self {
        case .engineNotInitialized:
            // Clear, actionable copy (was the opaque "CKSyncEngine not initialized").
            return L10n.Groups.Errors.syncPreparing
        }
    }
}

// MARK: - CKSyncEngine Delegate

/// Routes CKSyncEngine events to SplitSyncManager.
/// State persistence is handled synchronously (nonisolated).
/// Model updates are dispatched to @MainActor.
private final class SplitSyncDelegate: CKSyncEngineDelegate {

    nonisolated(unsafe) private weak var manager: SplitSyncManager?

    init(manager: SplitSyncManager) {
        self.manager = manager
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        // Discard callbacks from an engine that was recreated by `enableAutoSync()`. Crucial for
        // the `.stateUpdate` path below: a stale event would be saved under the wrong file name
        // (its identity no longer matches) and corrupt the live engine's serialized state.
        guard manager?.isCurrentEngine(syncEngine) == true else { return }

        // State updates: persist synchronously (file I/O, nonisolated-safe)
        if case .stateUpdate(let update) = event {
            let name = manager?.isPrivateEngine(syncEngine) == true ? "private" : "shared"
            manager?.saveState(update.stateSerialization, name: name)
            return
        }

        // All other events: await MainActor for model access (proper ordering)
        await MainActor.run {
            self.manager?.processEvent(event, engine: syncEngine)
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges
        guard !pendingChanges.isEmpty else { return nil }

        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pendingChanges) { recordID in
            await MainActor.run {
                self.manager?.buildRecord(for: recordID)
            }
        }
    }
}
