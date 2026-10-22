//
//  SplitSettlement.swift
//  Yala
//
//  Liquidación entre dos miembros de un grupo.
//  Vinculado a SplitGroup via groupZoneID (no @Relationship).
//

import Foundation
import SwiftData

@Model
final class SplitSettlement {
    // `.preserveValueOnDeletion`: G2 usa `id` como sync_id y `groupZoneID` como `group_id` del wire → el
    // history tombstone debe conservarlos para emitir el borrado (metadata local; groups store `.none`).
    @Attribute(.preserveValueOnDeletion) var id: UUID = UUID()
    @Attribute(.preserveValueOnDeletion) var groupZoneID: String = ""
    var fromMemberID: String = ""
    var toMemberID: String = ""
    var amount: Double = 0
    var currencyCode: String = "USD"
    var note: String?
    var date: Date = Date.now
    var isConfirmed: Bool = false
    // Miembro que REGISTRÓ la liquidación = SplitMember.id.uuidString. Lo escribe el path LOCAL
    // (GroupExpenseService.createSettlement); los applies remotos lo copian del record. Usado por
    // GroupNotificationService para autoexcluir el eco Caso D ("registro que X me pagó" → no me llega
    // "X te pagó" por algo que registré yo). La atribución "X te pagó" sigue siendo fromMemberID (correcta).
    // nil = liquidación pre-campo o registrada por app vieja ⇒ fallback al comportamiento legado.
    // TODO(wire backend): CloudKit-only, igual que SplitExpense.lastEditedByMemberID.
    var recordedByMemberID: String?
    var ckSystemFieldsData: Data?            // CKRecord system fields for conflict-free uploads

    init(
        groupZoneID: String = "",
        fromMemberID: String = "",
        toMemberID: String = "",
        amount: Double = 0,
        currencyCode: String = "USD",
        note: String? = nil,
        date: Date = Date.now
    ) {
        self.id = UUID()
        self.groupZoneID = groupZoneID
        self.fromMemberID = fromMemberID
        self.toMemberID = toMemberID
        self.amount = amount
        self.currencyCode = currencyCode
        self.note = note
        self.date = date
    }
}
