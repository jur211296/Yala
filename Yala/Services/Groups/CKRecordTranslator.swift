//
//  CKRecordTranslator.swift
//  Yala
//
//  Bidirectional translation between CKRecord and SwiftData models.
//  Encryption is built in: sensitive fields use record.encryptedValues.
//

import CloudKit
import Foundation

enum CKRecordTranslator {

    // MARK: - CKRecord System Fields (conflict-free uploads)

    /// Encode CKRecord system fields (changeTag, modificationDate, etc.) into Data for local storage.
    static func encodeSystemFields(of record: CKRecord) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    /// Restore a CKRecord from stored system fields, preserving the server's changeTag.
    static func recordFromSystemFields(_ data: Data) -> CKRecord? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        let record = CKRecord(coder: unarchiver)
        unarchiver.finishDecoding()
        return record
    }

    // MARK: - Bool ↔ Int64 Helpers (CloudKit stores Bool as Int64)

    private static func ckBool(_ value: Bool) -> CKRecordValue {
        (value ? 1 : 0) as CKRecordValue
    }

    private static func readBool(_ record: CKRecord, key: String) -> Bool {
        (record[key] as? Int64 ?? 0) != 0
    }

    private static func readBool(_ record: CKRecord, key: String, default defaultValue: Bool) -> Bool {
        guard let val = record[key] as? Int64 else { return defaultValue }
        return val != 0
    }

    // MARK: - Amount Sanitization (untrusted remote ingestion)

    /// Tope de magnitud razonable para un monto de dinero entrante.
    /// La zona CKShare es `.readWrite`, así que un miembro con un cliente modificado puede
    /// escribir Doubles arbitrarios (NaN, Infinity, negativos, magnitudes absurdas). El path
    /// de escritura local valida `amount > 0`; esto es el guard equivalente para la ingestión
    /// remota, que de otro modo entra cruda a los cálculos de balance y al bridge personal.
    static let maxRemoteAmount: Double = 1_000_000_000_000  // 1e12

    /// Sanea un monto deserializado de un CKRecord no confiable.
    /// - `nil` o no-finito (NaN/Inf) → `fallback` (en insert es 0; en update preserva el valor local válido).
    /// - finito → clamp a `[0, maxRemoteAmount]` (los montos de expense/share/settlement son positivos por diseño).
    static func sanitizeAmount(_ raw: Double?, fallback: Double = 0) -> Double {
        guard let value = raw, value.isFinite else { return fallback }
        return min(max(value, 0), maxRemoteAmount)
    }

    // MARK: - SplitGroup ↔ GroupMeta

    static func record(from group: SplitGroup, in zoneID: CKRecordZone.ID) -> CKRecord {
        let record: CKRecord
        if let data = group.ckSystemFieldsData, let restored = recordFromSystemFields(data) {
            record = restored
        } else {
            let recordID = CKConstants.recordID(for: group.id, in: zoneID)
            record = CKRecord(recordType: CKConstants.RecordType.groupMeta, recordID: recordID)
        }
        applyGroupFields(from: group, to: record)
        return record
    }

    static func applyGroupFields(from group: SplitGroup, to record: CKRecord) {
        typealias F = CKConstants.GroupMetaField
        // Encrypted
        record.encryptedValues[F.name] = group.name as CKRecordValue
        // Plain
        record[F.currencyCode] = group.currencyCode as CKRecordValue
        record[F.createdAt] = group.createdAt as CKRecordValue
        record[F.iconName] = group.iconName as CKRecordValue
        record[F.colorHex] = group.colorHex as CKRecordValue
        record[F.simplifyDebts] = ckBool(group.simplifyDebts)
        record[F.showDebtsInSingleCurrency] = ckBool(group.showDebtsInSingleCurrency)
        record[F.defaultSplitType] = group.defaultSplitType as CKRecordValue
        record[F.membersCanInvite] = ckBool(group.membersCanInvite)
        // Lifecycle flags vía record (no solo CKShare custom key) para que invitados con
        // app abierta reciban el flip vía sync normal.
        record[F.isArchived] = ckBool(group.isArchived)
        record[F.isHiddenForAll] = ckBool(group.isHiddenForAll)
        // G6-3: campos del MARCADOR de migración — OPCIONALES (molde `note`/`subcategoryName`: `if let`,
        // NUNCA `as CKRecordValue` directo sobre el opcional). `backendReInviteToken` ENCRYPTED (molde `name`);
        // `movedToBackendAt` plano. Solo se escriben cuando el owner estampa el marcador (paso 6 del uploader).
        if let movedAt = group.movedToBackendAt {
            record[F.movedToBackendAt] = movedAt as CKRecordValue
        }
        if let token = group.backendReInviteToken {
            record.encryptedValues[F.backendReInviteToken] = token as CKRecordValue
        }
    }

    static func group(from record: CKRecord) -> SplitGroup? {
        guard let id = CKConstants.modelID(from: record.recordID) else { return nil }
        typealias F = CKConstants.GroupMetaField
        let group = SplitGroup()
        group.id = id
        group.cloudKitZoneID = record.recordID.zoneID.zoneName
        group.cloudKitZoneOwnerName = record.recordID.zoneID.ownerName
        group.name = record.encryptedValues[F.name] as? String ?? ""
        group.currencyCode = record[F.currencyCode] as? String ?? "PEN"
        group.createdAt = record[F.createdAt] as? Date ?? Date.now
        group.iconName = record[F.iconName] as? String ?? "person.2.fill"
        group.colorHex = record[F.colorHex] as? String ?? "#8B5CF6"
        group.simplifyDebts = readBool(record, key: F.simplifyDebts)
        group.showDebtsInSingleCurrency = readBool(record, key: F.showDebtsInSingleCurrency)
        group.defaultSplitType = record[F.defaultSplitType] as? String ?? "equal"
        group.membersCanInvite = readBool(record, key: F.membersCanInvite, default: false)
        // Default false si el record viejo en CloudKit no tenía el field (race-tolerant).
        group.isArchived = readBool(record, key: F.isArchived, default: false)
        group.isHiddenForAll = readBool(record, key: F.isHiddenForAll, default: false)
        // G6-3: campos del marcador — nil-safe (`as? T`): un record viejo sin ellos → nil (grupo no migrado).
        group.movedToBackendAt = record[F.movedToBackendAt] as? Date
        group.backendReInviteToken = record.encryptedValues[F.backendReInviteToken] as? String
        group.ckSystemFieldsData = encodeSystemFields(of: record)
        return group
    }

    static func update(_ group: SplitGroup, from record: CKRecord) {
        typealias F = CKConstants.GroupMetaField
        group.cloudKitZoneID = record.recordID.zoneID.zoneName
        group.cloudKitZoneOwnerName = record.recordID.zoneID.ownerName
        group.name = record.encryptedValues[F.name] as? String ?? group.name
        group.currencyCode = record[F.currencyCode] as? String ?? group.currencyCode
        group.createdAt = record[F.createdAt] as? Date ?? group.createdAt
        group.iconName = record[F.iconName] as? String ?? group.iconName
        group.colorHex = record[F.colorHex] as? String ?? group.colorHex
        group.simplifyDebts = readBool(record, key: F.simplifyDebts)
        group.showDebtsInSingleCurrency = readBool(record, key: F.showDebtsInSingleCurrency)
        group.defaultSplitType = record[F.defaultSplitType] as? String ?? group.defaultSplitType
        group.membersCanInvite = readBool(record, key: F.membersCanInvite, default: group.membersCanInvite)
        // Default a local si el record viejo no tenía el field (race-tolerant).
        group.isArchived = readBool(record, key: F.isArchived, default: group.isArchived)
        group.isHiddenForAll = readBool(record, key: F.isHiddenForAll, default: group.isHiddenForAll)
        // G6-3: campos del marcador — fallback al valor LOCAL si el record no los trae (race-tolerant, molde
        // `isArchived`): un member que YA supo que el grupo se congeló no lo des-congela por un record stale.
        group.movedToBackendAt = record[F.movedToBackendAt] as? Date ?? group.movedToBackendAt
        // C-3: un grupo cuya identidad de nube fue REVOCADA en este device (cambio/cierre del Apple ID con
        // sus filas backend RETENIDAS, D1) NO re-hidrata su token de re-invite. Sin este guard el strip es
        // local y efímero: el token vive ENCRYPTED en el GroupMeta del owner, así que el siguiente fetch de
        // la zona lo devuelve — y D2 (reset de los change tokens en `.signOut`) GARANTIZA ese fetch.
        // `rejoinRevokedAt` es LOCAL-only: no viaja, así que la revocación es de ESTE device.
        if group.rejoinRevokedAt == nil {
            group.backendReInviteToken = record.encryptedValues[F.backendReInviteToken] as? String ?? group.backendReInviteToken
        }
        group.ckSystemFieldsData = encodeSystemFields(of: record)
    }

    // MARK: - SplitExpense ↔ SplitExpense CKRecord

    static func record(from expense: SplitExpense, in zoneID: CKRecordZone.ID) -> CKRecord {
        let record: CKRecord
        if let data = expense.ckSystemFieldsData, let restored = recordFromSystemFields(data) {
            record = restored
        } else {
            let recordID = CKConstants.recordID(for: expense.id, in: zoneID)
            record = CKRecord(recordType: CKConstants.RecordType.splitExpense, recordID: recordID)
        }
        applyExpenseFields(from: expense, to: record)
        return record
    }

    static func applyExpenseFields(from expense: SplitExpense, to record: CKRecord) {
        typealias F = CKConstants.ExpenseField
        // Encrypted
        record.encryptedValues[F.amount] = expense.amount as CKRecordValue
        record.encryptedValues[F.description] = expense.expenseDescription as CKRecordValue
        if let note = expense.note {
            record.encryptedValues[F.note] = note as CKRecordValue
        }
        // Plain
        record[F.date] = expense.date as CKRecordValue
        record[F.paidByMemberID] = expense.paidByMemberID as CKRecordValue
        record[F.splitType] = expense.splitType as CKRecordValue
        record[F.isSettled] = ckBool(expense.isSettled)
        record[F.isOpeningBalance] = ckBool(expense.isOpeningBalance)
        record[F.currencyCode] = expense.currencyCode as CKRecordValue
        if let sub = expense.subcategoryName {
            record[F.subcategoryName] = sub as CKRecordValue
        }
        if let editor = expense.lastEditedByMemberID {
            record[F.lastEditedByMemberID] = editor as CKRecordValue
        }
        record[F.createdAt] = expense.createdAt as CKRecordValue
    }

    static func expense(from record: CKRecord) -> SplitExpense? {
        guard let id = CKConstants.modelID(from: record.recordID) else { return nil }
        typealias F = CKConstants.ExpenseField
        let expense = SplitExpense()
        expense.id = id
        expense.groupZoneID = record.recordID.zoneID.zoneName
        expense.amount = sanitizeAmount(record.encryptedValues[F.amount] as? Double)
        expense.expenseDescription = record.encryptedValues[F.description] as? String ?? ""
        expense.note = record.encryptedValues[F.note] as? String
        expense.date = record[F.date] as? Date ?? Date.now
        expense.paidByMemberID = record[F.paidByMemberID] as? String ?? ""
        expense.splitType = record[F.splitType] as? String ?? "equal"
        expense.isSettled = readBool(record, key: F.isSettled)
        expense.isOpeningBalance = readBool(record, key: F.isOpeningBalance, default: false)
        expense.currencyCode = record[F.currencyCode] as? String ?? "USD"
        expense.subcategoryName = record[F.subcategoryName] as? String
        expense.lastEditedByMemberID = record[F.lastEditedByMemberID] as? String
        expense.createdAt = record[F.createdAt] as? Date ?? Date.now
        expense.ckSystemFieldsData = encodeSystemFields(of: record)
        return expense
    }

    static func update(_ expense: SplitExpense, from record: CKRecord) {
        typealias F = CKConstants.ExpenseField
        expense.amount = sanitizeAmount(record.encryptedValues[F.amount] as? Double, fallback: expense.amount)
        expense.expenseDescription = record.encryptedValues[F.description] as? String ?? expense.expenseDescription
        expense.note = record.encryptedValues[F.note] as? String
        expense.date = record[F.date] as? Date ?? expense.date
        expense.paidByMemberID = record[F.paidByMemberID] as? String ?? expense.paidByMemberID
        expense.splitType = record[F.splitType] as? String ?? expense.splitType
        expense.isSettled = readBool(record, key: F.isSettled)
        expense.isOpeningBalance = readBool(record, key: F.isOpeningBalance)
        expense.currencyCode = record[F.currencyCode] as? String ?? expense.currencyCode
        expense.subcategoryName = record[F.subcategoryName] as? String
        expense.lastEditedByMemberID = record[F.lastEditedByMemberID] as? String
        expense.createdAt = record[F.createdAt] as? Date ?? expense.createdAt
        expense.ckSystemFieldsData = encodeSystemFields(of: record)
    }

    // MARK: - SplitMember ↔ SplitMember CKRecord

    static func record(from member: SplitMember, in zoneID: CKRecordZone.ID) -> CKRecord {
        let record: CKRecord
        if let data = member.ckSystemFieldsData, let restored = recordFromSystemFields(data) {
            record = restored
        } else {
            let recordID = CKConstants.recordID(for: member.id, in: zoneID)
            record = CKRecord(recordType: CKConstants.RecordType.splitMember, recordID: recordID)
        }
        applyMemberFields(from: member, to: record)
        return record
    }

    static func applyMemberFields(from member: SplitMember, to record: CKRecord) {
        typealias F = CKConstants.MemberField
        // Encrypted
        record.encryptedValues[F.displayName] = member.displayName as CKRecordValue
        // Plain
        record[F.memberID] = member.cloudKitUserRecordID as CKRecordValue
        record[F.role] = member.role as CKRecordValue
        record[F.status] = member.status as CKRecordValue
        record[F.isGroupOwner] = ckBool(member.isGroupOwner)
        record[F.joinedAt] = member.joinedAt as CKRecordValue
        // C-10 (beacon): DIRECCIONAL — un device solo declara SU PROPIA capacidad. Escribir el beacon de
        // otro member sería afirmar algo que no se puede saber, y con LWW podría "capacitar" a un device
        // incapaz y desbloquear una migración que lo va a congelar.
        if member.isCurrentUser {
            if let capability = member.clientCapability {
                record[F.clientCapability] = capability as CKRecordValue
            }
            if let capabilityAt = member.clientCapabilityAt {
                record[F.clientCapabilityAt] = capabilityAt as CKRecordValue
            }
        }
    }

    static func member(from record: CKRecord) -> SplitMember? {
        guard let id = CKConstants.modelID(from: record.recordID) else { return nil }
        typealias F = CKConstants.MemberField
        let member = SplitMember()
        member.id = id
        member.groupZoneID = record.recordID.zoneID.zoneName
        member.displayName = record.encryptedValues[F.displayName] as? String ?? ""
        member.cloudKitUserRecordID = record[F.memberID] as? String ?? ""
        member.role = record[F.role] as? String ?? "member"
        member.status = record[F.status] as? String ?? SplitMemberStatus.active.rawValue
        member.isGroupOwner = readBool(record, key: F.isGroupOwner)
        if !member.cloudKitUserRecordID.isEmpty && record.recordID.zoneID.ownerName == member.cloudKitUserRecordID {
            member.isGroupOwner = true
            member.role = "admin"
        }
        member.joinedAt = record[F.joinedAt] as? Date ?? Date.now
        // C-10: nil-safe. Un record de un build viejo no trae estos campos → `nil` → ese member cuenta
        // como incapaz, que es exactamente la lectura correcta.
        member.clientCapability = record[F.clientCapability] as? String
        member.clientCapabilityAt = record[F.clientCapabilityAt] as? Date
        member.ckSystemFieldsData = encodeSystemFields(of: record)
        return member
    }

    static func update(_ member: SplitMember, from record: CKRecord) {
        typealias F = CKConstants.MemberField
        member.displayName = record.encryptedValues[F.displayName] as? String ?? member.displayName
        member.cloudKitUserRecordID = record[F.memberID] as? String ?? member.cloudKitUserRecordID
        member.role = record[F.role] as? String ?? member.role
        member.status = record[F.status] as? String ?? member.status
        member.isGroupOwner = readBool(record, key: F.isGroupOwner)
        if !member.cloudKitUserRecordID.isEmpty && record.recordID.zoneID.ownerName == member.cloudKitUserRecordID {
            member.isGroupOwner = true
            member.role = "admin"
        }
        member.joinedAt = record[F.joinedAt] as? Date ?? member.joinedAt
        // C-10 (beacon): en la fila PROPIA gana SIEMPRE el valor local — este device es la SSOT de su
        // propia capacidad y un record stale del server no puede bajársela (molde race-tolerant de
        // `isArchived`). En las filas de los DEMÁS se acepta lo que llega, que es todo lo que sabemos.
        if !member.isCurrentUser {
            member.clientCapability = record[F.clientCapability] as? String
            member.clientCapabilityAt = record[F.clientCapabilityAt] as? Date
        }
        member.ckSystemFieldsData = encodeSystemFields(of: record)
    }

    // MARK: - SplitShare ↔ SplitShare CKRecord

    static func record(from share: SplitShare, in zoneID: CKRecordZone.ID) -> CKRecord {
        let record: CKRecord
        if let data = share.ckSystemFieldsData, let restored = recordFromSystemFields(data) {
            record = restored
        } else {
            let recordID = CKConstants.recordID(for: share.id, in: zoneID)
            record = CKRecord(recordType: CKConstants.RecordType.splitShare, recordID: recordID)
        }
        applyShareFields(from: share, to: record)
        return record
    }

    static func applyShareFields(from share: SplitShare, to record: CKRecord) {
        typealias F = CKConstants.ShareField
        // Encrypted
        record.encryptedValues[F.amount] = share.amount as CKRecordValue
        // Plain
        record[F.expenseRecordName] = share.expenseID.uuidString as CKRecordValue
        record[F.memberID] = share.memberID as CKRecordValue
        record[F.isPaid] = ckBool(share.isPaid)
    }

    static func share(from record: CKRecord) -> SplitShare? {
        guard let id = CKConstants.modelID(from: record.recordID) else { return nil }
        typealias F = CKConstants.ShareField
        let share = SplitShare()
        share.id = id
        share.amount = sanitizeAmount(record.encryptedValues[F.amount] as? Double)
        if let expenseStr = record[F.expenseRecordName] as? String, let expID = UUID(uuidString: expenseStr) {
            share.expenseID = expID
        }
        share.memberID = record[F.memberID] as? String ?? ""
        share.isPaid = readBool(record, key: F.isPaid)
        share.groupZoneID = record.recordID.zoneID.zoneName
        share.ckSystemFieldsData = encodeSystemFields(of: record)
        return share
    }

    static func update(_ share: SplitShare, from record: CKRecord) {
        typealias F = CKConstants.ShareField
        share.amount = sanitizeAmount(record.encryptedValues[F.amount] as? Double, fallback: share.amount)
        if let expenseStr = record[F.expenseRecordName] as? String, let expID = UUID(uuidString: expenseStr) {
            share.expenseID = expID
        }
        share.memberID = record[F.memberID] as? String ?? share.memberID
        share.isPaid = readBool(record, key: F.isPaid)
        share.groupZoneID = record.recordID.zoneID.zoneName
        share.ckSystemFieldsData = encodeSystemFields(of: record)
    }

    // MARK: - SplitSettlement ↔ SplitSettlement CKRecord

    static func record(from settlement: SplitSettlement, in zoneID: CKRecordZone.ID) -> CKRecord {
        let record: CKRecord
        if let data = settlement.ckSystemFieldsData, let restored = recordFromSystemFields(data) {
            record = restored
        } else {
            let recordID = CKConstants.recordID(for: settlement.id, in: zoneID)
            record = CKRecord(recordType: CKConstants.RecordType.splitSettlement, recordID: recordID)
        }
        applySettlementFields(from: settlement, to: record)
        return record
    }

    static func applySettlementFields(from settlement: SplitSettlement, to record: CKRecord) {
        typealias F = CKConstants.SettlementField
        // Encrypted
        record.encryptedValues[F.amount] = settlement.amount as CKRecordValue
        if let note = settlement.note {
            record.encryptedValues[F.note] = note as CKRecordValue
        }
        // Plain
        record[F.fromMemberID] = settlement.fromMemberID as CKRecordValue
        record[F.toMemberID] = settlement.toMemberID as CKRecordValue
        record[F.date] = settlement.date as CKRecordValue
        record[F.isConfirmed] = ckBool(settlement.isConfirmed)
        record[F.currencyCode] = settlement.currencyCode as CKRecordValue
        if let recorder = settlement.recordedByMemberID {
            record[F.recordedByMemberID] = recorder as CKRecordValue
        }
    }

    static func settlement(from record: CKRecord) -> SplitSettlement? {
        guard let id = CKConstants.modelID(from: record.recordID) else { return nil }
        typealias F = CKConstants.SettlementField
        let settlement = SplitSettlement()
        settlement.id = id
        settlement.groupZoneID = record.recordID.zoneID.zoneName
        settlement.amount = sanitizeAmount(record.encryptedValues[F.amount] as? Double)
        settlement.note = record.encryptedValues[F.note] as? String
        settlement.fromMemberID = record[F.fromMemberID] as? String ?? ""
        settlement.toMemberID = record[F.toMemberID] as? String ?? ""
        settlement.date = record[F.date] as? Date ?? Date.now
        settlement.isConfirmed = readBool(record, key: F.isConfirmed)
        settlement.currencyCode = record[F.currencyCode] as? String ?? "USD"
        settlement.recordedByMemberID = record[F.recordedByMemberID] as? String
        settlement.ckSystemFieldsData = encodeSystemFields(of: record)
        return settlement
    }

    static func update(_ settlement: SplitSettlement, from record: CKRecord) {
        typealias F = CKConstants.SettlementField
        settlement.amount = sanitizeAmount(record.encryptedValues[F.amount] as? Double, fallback: settlement.amount)
        settlement.note = record.encryptedValues[F.note] as? String
        settlement.fromMemberID = record[F.fromMemberID] as? String ?? settlement.fromMemberID
        settlement.toMemberID = record[F.toMemberID] as? String ?? settlement.toMemberID
        settlement.date = record[F.date] as? Date ?? settlement.date
        settlement.isConfirmed = readBool(record, key: F.isConfirmed)
        settlement.currencyCode = record[F.currencyCode] as? String ?? settlement.currencyCode
        settlement.recordedByMemberID = record[F.recordedByMemberID] as? String
        settlement.ckSystemFieldsData = encodeSystemFields(of: record)
    }
}
