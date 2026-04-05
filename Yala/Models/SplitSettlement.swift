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
    var id: UUID = UUID()
    var groupZoneID: String = ""
    var fromMemberID: String = ""
    var toMemberID: String = ""
    var amount: Double = 0
    var currencyCode: String = "USD"
    var note: String?
    var date: Date = Date.now
    var isConfirmed: Bool = false

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
