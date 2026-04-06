//
//  SplitGroup.swift
//  Yala
//
//  Cache local del GroupMeta de CloudKit shared zone.
//  Fuente de verdad: CKRecord en zona compartida (CKSyncEngine).
//

import Foundation
import SwiftData

@Model
final class SplitGroup {
    // CloudKit: all properties must have defaults, no @Attribute(.unique)
    var id: UUID = UUID()
    var cloudKitZoneID: String = ""       // "SplitGroup-{uuid}"
    var name: String = ""
    var iconName: String = "person.2.fill"
    var colorHex: String = "#8B5CF6"
    var currencyCode: String = "PEN"
    var simplifyDebts: Bool = false
    var createdAt: Date = Date.now
    var isOwner: Bool = false
    var isArchived: Bool = false
    var defaultAccountID: UUID?           // ID ref, NO @Relationship (zonas distintas)
    var autoCreateTransaction: Bool = true // true = TransactionItem directo, false = Draft
    var showDebtsInSingleCurrency: Bool = false
    var defaultSplitType: String = "equal" // "equal" | "percentage" | "exact" | "shares"
    var membersCanInvite: Bool = true

    init(
        name: String = "",
        iconName: String = "person.2.fill",
        colorHex: String = "#8B5CF6",
        currencyCode: String = "PEN",
        simplifyDebts: Bool = false,
        isOwner: Bool = false,
        defaultAccountID: UUID? = nil,
        autoCreateTransaction: Bool = true,
        showDebtsInSingleCurrency: Bool = false,
        defaultSplitType: String = "equal",
        membersCanInvite: Bool = true
    ) {
        self.id = UUID()
        self.cloudKitZoneID = "\(CKConstants.zonePrefix)\(self.id.uuidString)"
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.currencyCode = currencyCode
        self.simplifyDebts = simplifyDebts
        self.createdAt = Date.now
        self.isOwner = isOwner
        self.defaultAccountID = defaultAccountID
        self.autoCreateTransaction = autoCreateTransaction
        self.showDebtsInSingleCurrency = showDebtsInSingleCurrency
        self.defaultSplitType = defaultSplitType
        self.membersCanInvite = membersCanInvite
    }
}
