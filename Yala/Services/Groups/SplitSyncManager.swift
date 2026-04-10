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

    // nonisolated reference for identity check from delegate (set once during init)
    @ObservationIgnored nonisolated(unsafe) private var _privateEngineRef: CKSyncEngine?

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private var container: CKContainer?
    private let logger = Logger(subsystem: "com.yala", category: "SplitSync")

    // Delegate must be kept alive
    private var delegate: SplitSyncDelegate?

    // Pending record IDs — internal tracking, not observed by views
    private var pendingRecordSaves: Set<CKRecord.ID> = []

    // Coalescing task for deferred bridge/notifications after remote changes
    private var deferredBridgeTask: Task<Void, Never>?
    private var pendingBridgeExpenseIDs: Set<UUID> = []
    private var pendingBridgeChangeSet = RemoteChangeSet()

    // Records that failed due to quota exceeded — retried on foreground
    private var quotaFailedRecordIDs: Set<CKRecord.ID> = []

    // MARK: - State Persistence

    // nonisolated-safe: file I/O only, no model access
    private nonisolated let stateDirectory: URL = {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            let fallback = fm.temporaryDirectory.appendingPathComponent("SplitSync", isDirectory: true)
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
    func initialize() {
        let containerID = CKConstants.containerID
        let ckContainer = CKContainer(identifier: containerID)
        self.container = ckContainer

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
        guard let delegate else { return }

        // Private engine — zones for groups I created
        let privateState = loadState(name: "private")
        var privateConfig = CKSyncEngine.Configuration(
            database: ckContainer.privateCloudDatabase,
            stateSerialization: privateState,
            delegate: delegate
        )
        privateConfig.automaticallySync = true
        privateEngine = CKSyncEngine(privateConfig)
        _privateEngineRef = privateEngine

        // Shared engine — zones for groups I was invited to
        let sharedState = loadState(name: "shared")
        var sharedConfig = CKSyncEngine.Configuration(
            database: ckContainer.sharedCloudDatabase,
            stateSerialization: sharedState,
            delegate: delegate
        )
        sharedConfig.automaticallySync = true
        sharedEngine = CKSyncEngine(sharedConfig)

        #if DEBUG
        logger.info("SplitSyncManager initialized — private: \(privateState != nil ? "resumed" : "fresh"), shared: \(sharedState != nil ? "resumed" : "fresh")")
        #endif
    }

    func setContext(_ ctx: ModelContext) {
        modelContext = ctx
    }

    // MARK: - Engine Identity

    // nonisolated: Called from CKSyncEngine delegate (off MainActor)
    nonisolated func isPrivateEngine(_ engine: CKSyncEngine) -> Bool {
        engine === _privateEngineRef
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
            try await container.accept(metadata)
            #if DEBUG
            logger.info("Share accepted — shared engine will fetch zone data automatically")
            #endif

            // Force immediate fetch so the group appears quickly
            if let sharedEngine {
                try? await sharedEngine.fetchChanges()
            }

            // Navigate to Groups tab (unless routing is handled by invite/reconnect flow)
            if !skipNavigation {
                SessionState.shared.deepLinkDestination = .groups
            }
        } catch {
            #if DEBUG
            logger.error("Share acceptance failed: \(error)")
            #endif
        }
    }

    /// Query the local SplitGroup name for a given zone ID (resolved after sync).
    func groupName(for zoneID: String) -> String? {
        guard let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.cloudKitZoneID == zoneID }
        )
        return (try? context.fetch(descriptor))?.first?.name
    }

    /// Find the most recently synced group (useful after accepting a share).
    func mostRecentGroup() -> SplitGroup? {
        guard let context = modelContext else { return nil }
        var descriptor = FetchDescriptor<SplitGroup>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
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
    func enqueueSharedSave(modelID: UUID, groupZoneID: String) {
        let zoneID = CKRecordZone.ID(zoneName: groupZoneID)
        let recordID = CKConstants.recordID(for: modelID, in: zoneID)
        markPendingChange(for: recordID, in: sharedEngine)
    }

    /// Enqueue a deletion for a group I was invited to (shared engine).
    func enqueueSharedDeletion(modelID: UUID, groupZoneID: String) {
        let zoneID = CKRecordZone.ID(zoneName: groupZoneID)
        let recordID = CKConstants.recordID(for: modelID, in: zoneID)
        markPendingDeletion(for: recordID, in: sharedEngine)
    }

    /// Enqueue a save, auto-routing to the correct engine based on group ownership.
    func enqueueSave(modelID: UUID, group: SplitGroup) {
        if group.isOwner {
            enqueueSave(modelID: modelID, groupID: group.id)
        } else {
            enqueueSharedSave(modelID: modelID, groupZoneID: group.cloudKitZoneID)
        }
    }

    /// Enqueue a deletion, auto-routing to the correct engine based on group ownership.
    func enqueueDeletion(modelID: UUID, group: SplitGroup) {
        if group.isOwner {
            enqueueDeletion(modelID: modelID, groupID: group.id)
        } else {
            enqueueSharedDeletion(modelID: modelID, groupZoneID: group.cloudKitZoneID)
        }
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

    // MARK: - Event Handlers

    private func handleFetchedDatabaseChanges(_ fetched: CKSyncEngine.Event.FetchedDatabaseChanges, engineName: String, engine: CKSyncEngine) {
        #if DEBUG
        logger.info("[\(engineName)] fetchedDatabaseChanges: \(fetched.modifications.count) mods, \(fetched.deletions.count) dels")
        #endif

        guard !fetched.deletions.isEmpty, let modelContext else { return }

        for deletion in fetched.deletions {
            let zoneName = deletion.zoneID.zoneName
            guard let groupID = CKConstants.groupID(from: zoneName) else { continue }

            switch deletion.reason {
            case .deleted:
                #if DEBUG
                logger.info("[\(engineName)] Zone deleted: \(zoneName) — cleaning up local data")
                #endif
                deleteGroupCache(groupID: groupID, context: modelContext)
                purgePendingChanges(for: deletion.zoneID, engine: engine)

            case .purged:
                #if DEBUG
                logger.info("[\(engineName)] Zone purged: \(zoneName) — clearing data + state")
                #endif
                deleteGroupCache(groupID: groupID, context: modelContext)
                purgePendingChanges(for: deletion.zoneID, engine: engine)
                clearState(name: engineName)

            case .encryptedDataReset:
                #if DEBUG
                logger.info("[\(engineName)] Encrypted data reset: \(zoneName) — clearing system fields + re-uploading")
                #endif
                clearState(name: engineName)
                reuploadGroupRecords(groupID: groupID, zoneID: deletion.zoneID, engine: engine, context: modelContext)

            @unknown default:
                deleteGroupCache(groupID: groupID, context: modelContext)
                purgePendingChanges(for: deletion.zoneID, engine: engine)
            }
        }

        do {
            try modelContext.save()
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
            #if DEBUG
            logger.info("iCloud account signed out — cleared local group data")
            #endif

        case .switchAccounts:
            syncStatus = .idle
            clearAllLocalGroupData()
            clearState(name: "private")
            clearState(name: "shared")
            #if DEBUG
            logger.info("iCloud account switched — cleared data + state for re-fetch")
            #endif

        @unknown default:
            break
        }
    }

    /// Delete all local group data (used on sign-out and account switch for privacy).
    private func clearAllLocalGroupData() {
        guard let modelContext else { return }

        do {
            let groups = try modelContext.fetch(FetchDescriptor<SplitGroup>())
            for group in groups {
                deleteGroupCache(groupID: group.id, context: modelContext)
            }
            try modelContext.save()
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
        guard let modelContext else { return }

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
                existingExpenseIDs.formUnion(try modelContext.fetch(expDesc).map(\.id))
                let setDesc = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zName })
                existingSettlementIDs.formUnion(try modelContext.fetch(setDesc).map(\.id))
                let memDesc = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zName })
                existingMemberIDs.formUnion(try modelContext.fetch(memDesc).map(\.id))
            }
        } catch {
            #if DEBUG
            logger.error("[\(engineName)] Pre-fetch for change classification failed: \(error)")
            #endif
        }

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
                        changeSet.newMembers.append((modelID, groupID))
                    }
                default: break
                }
            }

            applyRemoteRecord(record, context: modelContext)
        }

        for deletion in fetched.deletions {
            applyRemoteDeletion(recordID: deletion.recordID, recordType: deletion.recordType, context: modelContext)
        }

        do {
            // Persist remote records before deferred bridge. Auto-sync overhead is
            // mitigated by state persistence limiting CKSyncEngine to incremental fetches.
            try modelContext.save()
        } catch {
            #if DEBUG
            logger.error("[\(engineName)] Failed to save after remote changes: \(error)")
            #endif
        }

        // Accumulate IDs and changeSets, then coalesce into a single deferred Task.
        // Avoids spawning N independent Tasks if N fetch events arrive in rapid succession.
        pendingBridgeExpenseIDs.formUnion(changeSet.newExpenses.map(\.id) + changeSet.modifiedExpenses.map(\.id))
        pendingBridgeChangeSet.newExpenses.append(contentsOf: changeSet.newExpenses)
        pendingBridgeChangeSet.modifiedExpenses.append(contentsOf: changeSet.modifiedExpenses)
        pendingBridgeChangeSet.newSettlements.append(contentsOf: changeSet.newSettlements)
        pendingBridgeChangeSet.newMembers.append(contentsOf: changeSet.newMembers)

        // Cancel previous deferred task and restart — coalescing rapid events
        deferredBridgeTask?.cancel()
        deferredBridgeTask = Task { @MainActor [weak self] in
            // Let CKSyncEngine finish its current event batch before triggering more saves
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            guard let self, let modelContext = self.modelContext else { return }

            let expenseIDs = self.pendingBridgeExpenseIDs
            let accumulated = self.pendingBridgeChangeSet
            self.pendingBridgeExpenseIDs.removeAll()
            self.pendingBridgeChangeSet = RemoteChangeSet()

            // GC-03: Bridge remote expenses to personal TransactionItem/InboxDraft
            if !expenseIDs.isEmpty, GroupTransactionBridge.shared.isReady {
                do {
                    // Set.contains not supported in #Predicate — filter in memory
                    let allExpenses = try modelContext.fetch(FetchDescriptor<SplitExpense>())
                    let matched = allExpenses.filter { expenseIDs.contains($0.id) }
                    if !matched.isEmpty {
                        try GroupTransactionBridge.shared.bridgeRemoteExpenses(matched)
                    }
                } catch {
                    #if DEBUG
                    self.logger.error("Failed to bridge remote expenses: \(error)")
                    #endif
                }
            }

            // GC-06: Notify user about remote group changes
            if !accumulated.isEmpty {
                GroupNotificationService.shared.processRemoteChanges(accumulated)
            }

            // Trigger UI refresh — single notification after everything settles
            SessionState.shared.markRemoteChangePending()
        }
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

        // Store system fields from successfully saved records (for conflict-free future uploads)
        if !sent.savedRecords.isEmpty, let modelContext {
            for record in sent.savedRecords {
                storeSystemFields(of: record, context: modelContext)
            }
            do {
                try modelContext.save()
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
        guard let modelContext,
              let serverRecord = failure.error.serverRecord else {
            #if DEBUG
            logger.error("[\(engineName)] Conflict but no server record available")
            #endif
            return
        }

        // Accept server version: update local model from server record
        applyRemoteRecord(serverRecord, context: modelContext)
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            logger.error("[\(engineName)] Failed to save after conflict resolution: \(error)")
            #endif
        }

        // Remove from pending — server version is now authoritative
        pendingRecordSaves.remove(failure.record.recordID)

        #if DEBUG
        logger.info("[\(engineName)] Conflict resolved (server wins): \(failure.record.recordID.recordName)")
        #endif
    }

    // MARK: - Zone Not Found Handling

    private func handleZoneNotFound(recordID: CKRecord.ID, engineName: String) {
        guard let modelContext else { return }

        let zoneName = recordID.zoneID.zoneName
        guard let groupID = CKConstants.groupID(from: zoneName) else { return }

        // Delete all local data for this group
        deleteGroupCache(groupID: groupID, context: modelContext)
        do {
            try modelContext.save()
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

            try context.save()
        } catch {
            #if DEBUG
            logger.error("reuploadGroupRecords: Failed for group \(groupID): \(error)")
            #endif
        }
    }

    // MARK: - Remote Record Application

    private func applyRemoteRecord(_ record: CKRecord, context: ModelContext) {
        guard let modelID = CKConstants.modelID(from: record.recordID) else { return }

        switch record.recordType {
        case CKConstants.RecordType.groupMeta:
            applyGroupMeta(record, modelID: modelID, context: context)
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

    private func applyGroupMeta(_ record: CKRecord, modelID: UUID, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.id == modelID })
            if let existing = try context.fetch(descriptor).first {
                CKRecordTranslator.update(existing, from: record)
            } else if let newGroup = CKRecordTranslator.group(from: record) {
                context.insert(newGroup)
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
                CKRecordTranslator.update(existing, from: record)
            } else if let newMember = CKRecordTranslator.member(from: record) {
                context.insert(newMember)
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
        guard let modelContext,
              let modelID = CKConstants.modelID(from: recordID) else { return nil }

        let zoneID = recordID.zoneID

        // Try each model type to find the one matching this recordID
        if let group = fetchByID(SplitGroup.self, id: modelID, context: modelContext) {
            return CKRecordTranslator.record(from: group, in: zoneID)
        }
        if let expense = fetchByID(SplitExpense.self, id: modelID, context: modelContext) {
            return CKRecordTranslator.record(from: expense, in: zoneID)
        }
        if let member = fetchByID(SplitMember.self, id: modelID, context: modelContext) {
            return CKRecordTranslator.record(from: member, in: zoneID)
        }
        if let share = fetchByID(SplitShare.self, id: modelID, context: modelContext) {
            return CKRecordTranslator.record(from: share, in: zoneID)
        }
        if let settlement = fetchByID(SplitSettlement.self, id: modelID, context: modelContext) {
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
