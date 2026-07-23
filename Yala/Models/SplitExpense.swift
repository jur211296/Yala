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
    // Autor del último cambio (crear/editar) = SplitMember.id.uuidString del editor. Lo escribe el
    // path LOCAL (GroupExpenseService); los applies remotos lo copian del record vía CKRecordTranslator.
    // Usado por GroupNotificationService para atribuir "X actualizó" al editor real y autoexcluir el eco
    // de la propia edición (mismo device y 2º device mismo iCloud). nil ⇒ fallback al proxy paidByMemberID.
    // Residual de rollout mixto (limitación de plataforma): un editor en app VIEJA (pre-campo) no escribe
    // esta key; CloudKit hace merge por-campo ⇒ el server RETIENE el autor previo (no lo pone nil) ⇒ esa
    // edición puede atribuirse al autor previo / auto-suprimir el eco por un autor que ya no corresponde.
    // Transitorio, sin pérdida de datos; auto-sana cuando todos los clientes actualizan.
    // TODO(wire backend): CloudKit-only. Cuando las notificaciones migren al canal backend (DARK hoy),
    // cablear al wire: columna en split_expenses + emisión en GroupEntityEmissionMap + manifest + Merkle
    // projection + regenerar goldens. Hoy es invisible al wire (no declarado), como bridgePending.
    var lastEditedByMemberID: String?
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
