//
//  CloudKitConstants.swift
//  Yala
//
//  Constants for CKSyncEngine record types, field names, and zone IDs.
//

import CloudKit
import Foundation

enum CKConstants {

    /// CloudKit container identifier for CKSyncEngine (groups only).
    static var containerID: String {
        SwiftDataConfiguration.groupsCloudKitContainerIdentifier
    }

    // MARK: - Record Types

    enum RecordType {
        static let groupMeta = "GroupMeta"
        static let splitExpense = "SplitExpense"
        static let splitMember = "SplitMember"
        static let splitShare = "SplitShare"
        static let splitSettlement = "SplitSettlement"
    }

    // MARK: - GroupMeta Fields

    enum GroupMetaField {
        // Encrypted (sensitive)
        static let name = "name"
        // G6-3: token de re-invite backend, ESTAMPADO en el marcador de migración (viaja con
        // `movedToBackendAt`). ENCRYPTED (molde `name`): legible por members de la shared zone, higiénico y
        // gratis. Field key NUEVO → exige deploy del schema a Production + .ckdb en el mismo commit.
        static let backendReInviteToken = "backendReInviteToken"
        // Plain (queryable)
        static let currencyCode = "currencyCode"
        static let createdAt = "createdAt"
        static let iconName = "iconName"
        static let colorHex = "colorHex"
        static let simplifyDebts = "simplifyDebts"
        static let showDebtsInSingleCurrency = "showDebtsInSingleCurrency"
        static let defaultSplitType = "defaultSplitType"
        static let membersCanInvite = "membersCanInvite"
        static let isArchived = "isArchived"
        static let isHiddenForAll = "isHiddenForAll"
        // G6-3: marca del CONGELAMIENTO por migración a backend (timestamp informativo, truthy-por-presencia).
        // Viaja por CloudKit para que los members deriven el estado congelado. Field key NUEVO → deploy +.ckdb.
        static let movedToBackendAt = "movedToBackendAt"
    }

    // MARK: - SplitExpense Fields

    enum ExpenseField {
        // Encrypted
        static let amount = "amount"
        static let description = "description"
        static let note = "note"
        // Plain
        static let date = "date"
        static let paidByMemberID = "paidByMemberID"
        static let splitType = "splitType"
        static let isSettled = "isSettled"
        static let isOpeningBalance = "isOpeningBalance"
        static let currencyCode = "currencyCode"
        static let subcategoryName = "subcategoryName"
        static let createdAt = "createdAt"
        // Autor del último cambio (atribución + autoexclusión del eco). Field key nuevo ⇒ requiere
        // deploy del schema a Production del container de grupos (CloudKitGroupsSchemaParityTests).
        static let lastEditedByMemberID = "lastEditedByMemberID"
    }

    // MARK: - SplitMember Fields

    enum MemberField {
        // Encrypted
        static let displayName = "displayName"
        // Plain
        static let memberID = "memberID"
        static let role = "role"
        static let status = "status"
        static let isGroupOwner = "isGroupOwner"
        static let joinedAt = "joinedAt"
        // NOTE: `isCurrentUser` no se persiste en CKRecord — es device-local,
        // reseteado por `GroupService.refreshCurrentUserFlags` basándose en
        // `cloudKitUserRecordID` matching del current iCloud user.
    }

    // MARK: - SplitShare Fields

    enum ShareField {
        // Encrypted
        static let amount = "amount"
        // Plain
        static let expenseRecordName = "expenseRecordName"
        static let memberID = "memberID"
        static let isPaid = "isPaid"
    }

    // MARK: - SplitSettlement Fields

    enum SettlementField {
        // Encrypted
        static let amount = "amount"
        static let note = "note"
        // Plain
        static let fromMemberID = "fromMemberID"
        static let toMemberID = "toMemberID"
        static let date = "date"
        static let isConfirmed = "isConfirmed"
        static let currencyCode = "currencyCode"
        // Miembro que registró la liquidación (autoexclusión del eco Caso D). Field key nuevo ⇒ requiere
        // deploy del schema a Production del container de grupos (CloudKitGroupsSchemaParityTests).
        static let recordedByMemberID = "recordedByMemberID"
    }

    // MARK: - Zone ID Helpers

    // `zonePrefix` y `zoneName(for:)` viven en `SplitGroupZone` (`Models/SplitGroupZone.swift`): el
    // literal es el `group_id` server-side del canal backend, no una constante de CloudKit, y su
    // consumidor de producción (`SplitGroup.init`) sobrevive a este fichero. Los dos helpers de abajo sí
    // son del transporte — uno devuelve `CKRecordZone.ID` y al otro solo lo llama el transporte.

    static func zoneID(for groupID: UUID) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: SplitGroupZone.zoneName(for: groupID))
    }

    static func groupID(from zoneName: String) -> UUID? {
        guard zoneName.hasPrefix(SplitGroupZone.zonePrefix) else { return nil }
        let uuidString = String(zoneName.dropFirst(SplitGroupZone.zonePrefix.count))
        return UUID(uuidString: uuidString)
    }

    // MARK: - Record ID Helpers

    static func recordID(for modelID: UUID, in zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: modelID.uuidString, zoneID: zoneID)
    }

    static func modelID(from recordID: CKRecord.ID) -> UUID? {
        UUID(uuidString: recordID.recordName)
    }
}
