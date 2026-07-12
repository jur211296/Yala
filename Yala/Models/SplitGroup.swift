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
    var cloudKitZoneOwnerName: String = ""
    var name: String = ""
    var iconName: String = "person.2.fill"
    var colorHex: String = "#8B5CF6"
    var currencyCode: String = "PEN"
    var simplifyDebts: Bool = false
    var createdAt: Date = Date.now
    var isOwner: Bool = false
    var isArchived: Bool = false
    var isHiddenForAll: Bool = false      // FU-02: soft-delete invisible para todos (irreversible in-app)
    var defaultAccountID: UUID?           // ID ref, NO @Relationship (zonas distintas)
    var showDebtsInSingleCurrency: Bool = false
    var defaultSplitType: String = "equal" // "equal" | "percentage" | "exact" | "shares"
    var membersCanInvite: Bool = false
    var ckSystemFieldsData: Data?            // CKRecord system fields for conflict-free uploads
    /// Baseline del primer import de la zona (bug "Jür se unió al grupo"):
    /// seteado al INSERTAR el grupo vía fetch (applyGroupMeta rama NUEVO — invitado
    /// recién unido o reinstalación), limpiado cuando el engine completa el ciclo
    /// de fetch de la zona (`didFetchRecordZoneChanges`). Mientras esté vigente
    /// (< 15 min, auto-sana) se suprimen las notifs de membership de la zona.
    /// LOCAL-ONLY: no se mapea en CKRecordTranslator (store `.none`, sin deploy).
    var initialMemberImportStartedAt: Date?

    init(
        name: String = "",
        iconName: String = "person.2.fill",
        colorHex: String = "#8B5CF6",
        currencyCode: String = "PEN",
        simplifyDebts: Bool = false,
        isOwner: Bool = false,
        defaultAccountID: UUID? = nil,
        showDebtsInSingleCurrency: Bool = false,
        defaultSplitType: String = "equal",
        membersCanInvite: Bool = false
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
        self.showDebtsInSingleCurrency = showDebtsInSingleCurrency
        self.defaultSplitType = defaultSplitType
        self.membersCanInvite = membersCanInvite
    }
}
