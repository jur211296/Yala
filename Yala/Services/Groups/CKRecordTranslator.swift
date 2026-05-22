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
        record[F.currencyCode] = expense.currencyCode as CKRecordValue
        if let sub = expense.subcategoryName {
            record[F.subcategoryName] = sub as CKRecordValue
        }
        record[F.createdAt] = expense.createdAt as CKRecordValue
    }

    static func expense(from record: CKRecord) -> SplitExpense? {
        guard let id = CKConstants.modelID(from: record.recordID) else { return nil }
        typealias F = CKConstants.ExpenseField
        let expense = SplitExpense()
        expense.id = id
        expense.groupZoneID = record.recordID.zoneID.zoneName
        expense.amount = record.encryptedValues[F.amount] as? Double ?? 0
        expense.expenseDescription = record.encryptedValues[F.description] as? String ?? ""
        expense.note = record.encryptedValues[F.note] as? String
        expense.date = record[F.date] as? Date ?? Date.now
        expense.paidByMemberID = record[F.paidByMemberID] as? String ?? ""
        expense.splitType = record[F.splitType] as? String ?? "equal"
        expense.isSettled = readBool(record, key: F.isSettled)
        expense.currencyCode = record[F.currencyCode] as? String ?? "USD"
        expense.subcategoryName = record[F.subcategoryName] as? String
        expense.createdAt = record[F.createdAt] as? Date ?? Date.now
        expense.ckSystemFieldsData = encodeSystemFields(of: record)
        return expense
    }

    static func update(_ expense: SplitExpense, from record: CKRecord) {
        typealias F = CKConstants.ExpenseField
        expense.amount = record.encryptedValues[F.amount] as? Double ?? expense.amount
        expense.expenseDescription = record.encryptedValues[F.description] as? String ?? expense.expenseDescription
        expense.note = record.encryptedValues[F.note] as? String
        expense.date = record[F.date] as? Date ?? expense.date
        expense.paidByMemberID = record[F.paidByMemberID] as? String ?? expense.paidByMemberID
        expense.splitType = record[F.splitType] as? String ?? expense.splitType
        expense.isSettled = readBool(record, key: F.isSettled)
        expense.currencyCode = record[F.currencyCode] as? String ?? expense.currencyCode
        expense.subcategoryName = record[F.subcategoryName] as? String
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
        share.amount = record.encryptedValues[F.amount] as? Double ?? 0
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
        share.amount = record.encryptedValues[F.amount] as? Double ?? share.amount
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
    }

    static func settlement(from record: CKRecord) -> SplitSettlement? {
        guard let id = CKConstants.modelID(from: record.recordID) else { return nil }
        typealias F = CKConstants.SettlementField
        let settlement = SplitSettlement()
        settlement.id = id
        settlement.groupZoneID = record.recordID.zoneID.zoneName
        settlement.amount = record.encryptedValues[F.amount] as? Double ?? 0
        settlement.note = record.encryptedValues[F.note] as? String
        settlement.fromMemberID = record[F.fromMemberID] as? String ?? ""
        settlement.toMemberID = record[F.toMemberID] as? String ?? ""
        settlement.date = record[F.date] as? Date ?? Date.now
        settlement.isConfirmed = readBool(record, key: F.isConfirmed)
        settlement.currencyCode = record[F.currencyCode] as? String ?? "USD"
        settlement.ckSystemFieldsData = encodeSystemFields(of: record)
        return settlement
    }

    static func update(_ settlement: SplitSettlement, from record: CKRecord) {
        typealias F = CKConstants.SettlementField
        settlement.amount = record.encryptedValues[F.amount] as? Double ?? settlement.amount
        settlement.note = record.encryptedValues[F.note] as? String
        settlement.fromMemberID = record[F.fromMemberID] as? String ?? settlement.fromMemberID
        settlement.toMemberID = record[F.toMemberID] as? String ?? settlement.toMemberID
        settlement.date = record[F.date] as? Date ?? settlement.date
        settlement.isConfirmed = readBool(record, key: F.isConfirmed)
        settlement.currencyCode = record[F.currencyCode] as? String ?? settlement.currencyCode
        settlement.ckSystemFieldsData = encodeSystemFields(of: record)
    }
}
