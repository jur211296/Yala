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
    nonisolated(unsafe) private var _privateEngineRef: CKSyncEngine?

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private var container: CKContainer?
    private let logger = Logger(subsystem: "com.yala", category: "SplitSync")

    // Delegate must be kept alive
    private var delegate: SplitSyncDelegate?

    // Pending record IDs — internal tracking, not observed by views
    private var pendingRecordSaves: Set<CKRecord.ID> = []

    // MARK: - State Persistence

    // nonisolated-safe: file I/O only, no model access
    private nonisolated let stateDirectory: URL = {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return FileManager.default.temporaryDirectory.appendingPathComponent("SplitSync", isDirectory: true)
        }
        let dir = appSupport.appendingPathComponent("SplitSync", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Initialization

    private init() {}

    /// Call from AppBootstrapper after services with context are set up.
    func initialize() {
        let containerID = CKConstants.containerID
        let ckContainer = CKContainer(identifier: containerID)
        self.container = ckContainer

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
        let url = stateDirectory.appendingPathComponent("\(name).json")
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
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
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

    // MARK: - Share Acceptance

    /// Accept a CKShare invitation (called from AppDelegate).
    func acceptShare(metadata: CKShare.Metadata) async {
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

            // Navigate to Groups tab
            SessionState.shared.deepLinkDestination = .groups
        } catch {
            #if DEBUG
            logger.error("Share acceptance failed: \(error)")
            #endif
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
            #if DEBUG
            logger.info("[\(name)] fetchedDatabaseChanges: \(fetched.modifications.count) mods, \(fetched.deletions.count) dels")
            #endif

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

    private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) {
        switch change.changeType {
        case .signIn:
            syncStatus = .idle
            #if DEBUG
            logger.info("iCloud account signed in")
            #endif
        case .signOut:
            syncStatus = .noAccount
            #if DEBUG
            logger.info("iCloud account signed out")
            #endif
        case .switchAccounts:
            syncStatus = .idle
            #if DEBUG
            logger.info("iCloud account switched — should clear local group cache")
            #endif
        @unknown default:
            break
        }
    }

    private func handleFetchedRecordZoneChanges(_ fetched: CKSyncEngine.Event.FetchedRecordZoneChanges, engineName: String) {
        guard let modelContext else { return }

        var processedExpenseIDs: Set<UUID> = []

        for modification in fetched.modifications {
            let record = modification.record
            applyRemoteRecord(record, context: modelContext)

            // Track expense IDs for bridge hook
            if record.recordType == CKConstants.RecordType.splitExpense,
               let modelID = CKConstants.modelID(from: record.recordID) {
                processedExpenseIDs.insert(modelID)
            }
        }

        for deletion in fetched.deletions {
            applyRemoteDeletion(recordID: deletion.recordID, recordType: deletion.recordType, context: modelContext)
        }

        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            logger.error("[\(engineName)] Failed to save after remote changes: \(error)")
            #endif
        }

        // GC-03: Bridge remote expenses to personal TransactionItem/InboxDraft
        if !processedExpenseIDs.isEmpty, GroupTransactionBridge.shared.isReady {
            do {
                // Set.contains not supported in #Predicate — filter in memory
                let allExpenses = try modelContext.fetch(FetchDescriptor<SplitExpense>())
                let matched = allExpenses.filter { processedExpenseIDs.contains($0.id) }
                if !matched.isEmpty {
                    try GroupTransactionBridge.shared.bridgeRemoteExpenses(matched)
                }
            } catch {
                #if DEBUG
                logger.error("[\(engineName)] Failed to bridge remote expenses: \(error)")
                #endif
            }
        }

        // Trigger UI refresh via existing pattern
        SessionState.shared.markRemoteChangePending()
    }

    private func handleSentDatabaseChanges(_ sent: CKSyncEngine.Event.SentDatabaseChanges, engineName: String) {
        for failure in sent.failedZoneSaves {
            #if DEBUG
            logger.error("[\(engineName)] Zone save failed: \(failure.zone.zoneID.zoneName) — \(failure.error.localizedDescription)")
            #endif
        }
    }

    private func handleSentRecordZoneChanges(_ sent: CKSyncEngine.Event.SentRecordZoneChanges, engineName: String) {
        for record in sent.savedRecords {
            pendingRecordSaves.remove(record.recordID)
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
                #if DEBUG
                logger.error("[\(engineName)] Quota exceeded")
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

        // Delete group
        let groupDesc = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.id == groupID })
        if let group = try? context.fetch(groupDesc).first {
            context.delete(group)
        }

        // Delete members, expenses, shares, settlements by zone
        let memberDesc = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zoneName })
        for member in (try? context.fetch(memberDesc)) ?? [] { context.delete(member) }

        let expenseDesc = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneName })
        let expenses = (try? context.fetch(expenseDesc)) ?? []

        // Delete SplitShares linked to these expenses (no groupZoneID on SplitShare)
        let expenseIDs = Set(expenses.map(\.id))
        if !expenseIDs.isEmpty {
            let allShares = (try? context.fetch(FetchDescriptor<SplitShare>())) ?? []
            for share in allShares where expenseIDs.contains(share.expenseID) {
                context.delete(share)
            }
        }

        for expense in expenses { context.delete(expense) }

        let settlementDesc = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zoneName })
        for settlement in (try? context.fetch(settlementDesc)) ?? [] { context.delete(settlement) }
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
        return try? context.fetch(descriptor).first
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

    private weak var manager: SplitSyncManager?

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
