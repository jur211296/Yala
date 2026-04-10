//
//  SplitMember.swift
//  Yala
//
//  Cache local de miembros de un grupo compartido.
//  Vinculado a SplitGroup via groupZoneID (no @Relationship).
//

import Foundation
import SwiftData

@Model
final class SplitMember {
    var id: UUID = UUID()
    var groupZoneID: String = ""
    var displayName: String = ""
    var cloudKitUserRecordID: String = ""  // CKRecord.ID del usuario
    var role: String = "member"            // "admin" | "member"
    var isCurrentUser: Bool = false
    var joinedAt: Date = Date.now
    var ckSystemFieldsData: Data?            // CKRecord system fields for conflict-free uploads

    init(
        groupZoneID: String = "",
        displayName: String = "",
        cloudKitUserRecordID: String = "",
        role: String = "member",
        isCurrentUser: Bool = false
    ) {
        self.id = UUID()
        self.groupZoneID = groupZoneID
        self.displayName = displayName
        self.cloudKitUserRecordID = cloudKitUserRecordID
        self.role = role
        self.isCurrentUser = isCurrentUser
        self.joinedAt = Date.now
    }
}
