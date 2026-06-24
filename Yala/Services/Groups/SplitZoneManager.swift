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

    // MARK: - CKShare Check

    /// Checks if a CKShare already exists for the group.
    func hasShare(for group: SplitGroup) async -> Bool {
        guard group.isOwner else { return false }
        guard let engine = syncManager.privateEngine else { return false }
        let zoneID = CKConstants.zoneID(for: group.id)
        do {
            let shareRecordID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
            _ = try await engine.database.record(for: shareRecordID)
            return true
        } catch {
            // Backward compatibility: older builds created a hierarchical share attached to GroupMeta
            let recordID = CKConstants.recordID(for: group.id, in: zoneID)
            do {
                let record = try await engine.database.record(for: recordID)
                return record.share != nil
            } catch {
                return false
            }
        }
    }

    // MARK: - CKShare Deletion

    /// Deletes the existing CKShare for a group, invalidating all invite links.
    func deleteShare(for group: SplitGroup) async throws {
        guard group.isOwner else { throw SplitZoneError.notOwner }
        guard let engine = syncManager.privateEngine else {
            throw SplitZoneError.engineNotInitialized
        }

        let zoneID = CKConstants.zoneID(for: group.id)
        let database = engine.database
        let shareRecordID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)

        do {
            try await database.deleteRecord(withID: shareRecordID)
            #if DEBUG
            logger.info("Deleted zone-wide CKShare for group: \(group.name)")
            #endif
            return
        } catch let ckError as CKError where ckError.code == .unknownItem {
            // Backward compatibility: older builds created a hierarchical share attached to GroupMeta
            let recordID = CKConstants.recordID(for: group.id, in: zoneID)
            let record = try await database.record(for: recordID)
            if let shareRef = record.share {
                try await database.deleteRecord(withID: shareRef.recordID)
                #if DEBUG
                logger.info("Deleted hierarchical CKShare for group: \(group.name)")
                #endif
                return
            }

            #if DEBUG
            logger.info("No share exists for group: \(group.name)")
            #endif
            return
        }

    }

    // MARK: - CKShare Creation

    /// Creates or retrieves a CKShare for a group zone, enabling invitation by link.
    /// If a share already exists, returns it — the URL is stable until explicitly deleted.
    func createShare(for group: SplitGroup) async throws -> (CKShare, URL?) {
        guard group.isOwner else { throw SplitZoneError.notOwner }
        guard let engine = syncManager.privateEngine else {
            throw SplitZoneError.engineNotInitialized
        }

        let zoneID = CKConstants.zoneID(for: group.id)
        let database = engine.database
        let shareRecordID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)

        // Flush pending zone/GroupMeta saves so inviting immediately after creating a group works.
        // do/catch (not try?) so a real failure is logged instead of swallowed; we still continue —
        // the share create below surfaces a clear error if the zone truly didn't upload.
        do {
            try await engine.sendChanges()
        } catch {
            logger.error("createShare: flush sendChanges failed (continuing): \(error.localizedDescription, privacy: .public)")
        }

        // Return existing zone-wide share if one already exists
        if let existing = await fetchRecordIfExists(shareRecordID, from: database),
           let ckShare = existing as? CKShare
        {
            #if DEBUG
            logger.info("Returning existing zone-wide CKShare for group: \(group.name)")
            #endif
            return (ckShare, ckShare.url)
        }

        // Backward compatibility: older builds created a hierarchical share attached to GroupMeta
        let recordID = CKConstants.recordID(for: group.id, in: zoneID)
        if let record = await fetchRecordIfExists(recordID, from: database),
           let shareRef = record.share,
           let existingShare = await fetchRecordIfExists(shareRef.recordID, from: database),
           let ckShare = existingShare as? CKShare
        {
            #if DEBUG
            logger.info("Returning existing hierarchical CKShare for group: \(group.name)")
            #endif
            return (ckShare, ckShare.url)
        }

        // Create new zone-wide CKShare
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = group.name as CKRecordValue
        share.publicPermission = .readWrite // URL-based sharing — anyone with the link can join

        let modifyOperation = CKModifyRecordsOperation(recordsToSave: [share])
        modifyOperation.savePolicy = .changedKeys

        return try await withCheckedThrowingContinuation { continuation in
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

    /// Fetches a record if it exists. Returns nil for "not found" (`CKError.unknownItem`, expected
    /// during share lookup); logs and returns nil for any other error — so the caller falls through
    /// to creating a new share instead of silently swallowing a real failure with `try?`.
    private func fetchRecordIfExists(_ recordID: CKRecord.ID, from database: CKDatabase) async -> CKRecord? {
        do {
            return try await database.record(for: recordID)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            return nil
        } catch {
            logger.error("createShare lookup failed for \(recordID.recordName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Leaving a Shared Zone

    /// Leaves a shared group by deleting the share record from the shared database.
    /// This removes the current user as a participant and stops future updates for the zone.
    func leaveShare(for group: SplitGroup) async throws {
        try await leaveShareByZone(
            zoneName: group.cloudKitZoneID,
            ownerName: ownerName(for: group)
        )
    }

    /// FU-02 cleanup F5c: variante standalone que recibe directamente (zoneName, ownerName).
    /// No requiere SplitGroup vivo — usable desde retry boot-time (PendingLeaveShareTracker)
    /// y desde el observer `performRemovedSelfCleanup` después del `delete(group)` local.
    func leaveShareByZone(zoneName: String, ownerName: String) async throws {
        let container = CKContainer(identifier: CKConstants.containerID)
        let resolvedOwner = ownerName.isEmpty ? CKCurrentUserDefaultName : ownerName
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: resolvedOwner)
        let shareRecordID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)

        do {
            try await container.sharedCloudDatabase.deleteRecord(withID: shareRecordID)
            #if DEBUG
            logger.info("Left shared zone by deleting zone-wide share: \(zoneName)")
            #endif
            return
        } catch let ckError as CKError where ckError.code == .unknownItem {
            // Backward compatibility: hierarchical share — best-effort sin SplitGroup local.
            // Si modelID puede derivarse del zoneName, intentar el path hierarchical.
            guard let modelID = CKConstants.groupID(from: zoneName) else { throw ckError }
            let groupMetaID = CKConstants.recordID(for: modelID, in: zoneID)
            let groupMeta = try await container.sharedCloudDatabase.record(for: groupMetaID)
            if let shareRef = groupMeta.share {
                try await container.sharedCloudDatabase.deleteRecord(withID: shareRef.recordID)
                #if DEBUG
                logger.info("Left shared zone by deleting hierarchical share: \(zoneName)")
                #endif
                return
            }
            throw ckError
        }
    }

    /// FU-02 cleanup F5c: helper público para capturar el ownerName del SplitGroup
    /// ANTES del `delete(group)` local (usado por `leaveGroup` y `performRemovedSelfCleanup`).
    func ownerName(for group: SplitGroup) -> String {
        if !group.cloudKitZoneOwnerName.isEmpty {
            return group.cloudKitZoneOwnerName
        }
        if let data = group.ckSystemFieldsData,
           let record = CKRecordTranslator.recordFromSystemFields(data)
        {
            return record.recordID.zoneID.ownerName
        }
        return CKCurrentUserDefaultName
    }

    private func sharedZoneID(for group: SplitGroup) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: group.cloudKitZoneID, ownerName: ownerName(for: group))
    }
}

// MARK: - Errors

enum SplitZoneError: LocalizedError {
    case engineNotInitialized
    case notOwner

    var errorDescription: String? {
        switch self {
        case .engineNotInitialized:
            // Clear, actionable copy (was the opaque "CKSyncEngine not initialized"). With the
            // export-only engines this is rarely reached, but if it is, it tells the user what to do.
            return L10n.Groups.Errors.syncPreparing
        case .notOwner:
            // Defensive — a non-owner never sees the invite button; reuse the generic copy.
            return L10n.Groups.Errors.actionFailed
        }
    }
}
