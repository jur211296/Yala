//
//  SplitZoneManager.swift
//  Yala
//
//  Manages CKRecordZone lifecycle and CKShare creation for groups.
//  Separated from SplitSyncManager to keep responsibilities focused.
//

import CloudKit
import Foundation
import os.log

@MainActor
final class SplitZoneManager {

    private let syncManager: SplitSyncManager
    private let logger = Logger(subsystem: "com.yala", category: "SplitZone")

    init(syncManager: SplitSyncManager) {
        self.syncManager = syncManager
    }

    // MARK: - Zone Creation

    /// Creates a CKRecordZone for a new group and enqueues a GroupMeta root record.
    func createZone(for group: SplitGroup) {
        guard let engine = syncManager.privateEngine else {
            #if DEBUG
            logger.error("Cannot create zone: private engine not initialized")
            #endif
            return
        }

        let zoneID = CKConstants.zoneID(for: group.id)
        let zone = CKRecordZone(zoneID: zoneID)

        // Enqueue zone creation
        engine.state.add(pendingDatabaseChanges: [.saveZone(zone)])

        // Enqueue GroupMeta root record (required for CKShare attachment)
        let recordID = CKConstants.recordID(for: group.id, in: zoneID)
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])

        #if DEBUG
        logger.info("Enqueued zone + GroupMeta: \(zoneID.zoneName)")
        #endif
    }

    // MARK: - Zone Deletion

    /// Deletes a group's CKRecordZone (cascade deletes all records in the zone).
    func deleteZone(for group: SplitGroup) {
        guard let engine = syncManager.privateEngine else {
            #if DEBUG
            logger.error("Cannot delete zone: private engine not initialized")
            #endif
            return
        }

        let zoneID = CKConstants.zoneID(for: group.id)
        engine.state.add(pendingDatabaseChanges: [.deleteZone(zoneID)])

        #if DEBUG
        logger.info("Enqueued zone deletion: \(zoneID.zoneName)")
        #endif
    }

    // MARK: - CKShare Creation

    /// Creates a CKShare for a group zone, enabling invitation by link.
    /// Returns the share URL for the share sheet.
    func createShare(for group: SplitGroup) async throws -> (CKShare, URL?) {
        guard let engine = syncManager.privateEngine else {
            throw SplitZoneError.engineNotInitialized
        }

        let zoneID = CKConstants.zoneID(for: group.id)
        let recordID = CKConstants.recordID(for: group.id, in: zoneID)

        // Fetch the existing GroupMeta record to attach the share
        let database = engine.database
        let record = try await database.record(for: recordID)

        // Create CKShare attached to the root record
        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = group.name as CKRecordValue
        share.publicPermission = .none // No public access — invite only

        // Save both the share and the updated root record
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: [record, share])
        modifyOperation.savePolicy = .changedKeys

        return try await withCheckedThrowingContinuation { continuation in
            modifyOperation.perRecordSaveBlock = { [self] _, result in
                if case .failure(let error) = result {
                    #if DEBUG
                    self.logger.error("Record save error during share: \(error)")
                    #endif
                }
            }
            modifyOperation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: (share, share.url))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(modifyOperation)
        }
    }
}

// MARK: - Errors

enum SplitZoneError: LocalizedError {
    case engineNotInitialized

    var errorDescription: String? {
        switch self {
        case .engineNotInitialized:
            return "CKSyncEngine not initialized. Ensure iCloud is available."
        }
    }
}
