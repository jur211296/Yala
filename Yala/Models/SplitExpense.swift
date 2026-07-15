//
//  SplitExpense.swift
//  Yala
//
//  Cache local de un gasto compartido.
//  Vinculado a SplitGroup via groupZoneID (no @Relationship).
//

import Foundation
import SwiftData

@Model
final class SplitExpense {
    // `.preserveValueOnDeletion`: el canal de sync de Grupos (G2) usa `id` como sync_id y `groupZoneID`
    // como `group_id` del wire → el history tombstone debe conservarlos para emitir el borrado. Metadata
    // de History local; el groups store es `.none` (CKSyncEngine usa CKRecordTranslator, no History) → sin
    // efecto en CloudKit ni deploy.
    @Attribute(.preserveValueOnDeletion) var id: UUID = UUID()
    @Attribute(.preserveValueOnDeletion) var groupZoneID: String = ""
    var amount: Double = 0
    var currencyCode: String = "USD"
    var expenseDescription: String = ""    // "description" colisiona con CustomStringConvertible
    var note: String?
    var date: Date = Date.now
    var paidByMemberID: String = ""
    var splitType: String = "equal"        // "equal" | "exact" | "percentage" | "shares"
    var isSettled: Bool = false
    var isOpeningBalance: Bool = false     // Saldo inicial / deuda de apertura (migración Splitwise). Bridge virtual-only, excluido de stats de gasto.
    var subcategoryName: String?           // Nombre subcategoría del creador (para matching)
    var createdAt: Date = Date.now
    var ckSystemFieldsData: Data?            // CKRecord system fields for conflict-free uploads

    // bridgePending / bridgeAttempts: device-local retry state for the personal-TX/Draft bridge.
    // Must stay out of CKRecordTranslator.applyExpenseFields so CloudKit never sees them.
    var bridgePending: Bool = false
    var bridgeAttempts: Int = 0

    init(
        groupZoneID: String = "",
        amount: Double = 0,
        currencyCode: String = "USD",
        expenseDescription: String = "",
        note: String? = nil,
        date: Date = Date.now,
        paidByMemberID: String = "",
        splitType: String = "equal",
        subcategoryName: String? = nil,
        isOpeningBalance: Bool = false
    ) {
        self.id = UUID()
        self.groupZoneID = groupZoneID
        self.amount = amount
        self.currencyCode = currencyCode
        self.expenseDescription = expenseDescription
        self.note = note
        self.date = date
        self.paidByMemberID = paidByMemberID
        self.splitType = splitType
        self.subcategoryName = subcategoryName
        self.isOpeningBalance = isOpeningBalance
        self.createdAt = Date.now
    }
}
