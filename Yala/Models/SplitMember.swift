//
//  SplitMember.swift
//  Yala
//
//  Cache local de miembros de un grupo compartido.
//  Vinculado a SplitGroup via groupZoneID (no @Relationship).
//

import Foundation
import SwiftData

enum SplitMemberStatus: String, CaseIterable, Sendable {
    case active
    case pendingApproval
    case rejected
    case left
    case removed
}

@Model
final class SplitMember {
    var id: UUID = UUID()
    var groupZoneID: String = ""
    var displayName: String = ""
    var cloudKitUserRecordID: String = ""  // CKRecord.ID del usuario
    var role: String = "member"            // "admin" | "member"
    var status: String = SplitMemberStatus.active.rawValue
    var isGroupOwner: Bool = false
    var isCurrentUser: Bool = false
    var joinedAt: Date = Date.now
    var ckSystemFieldsData: Data?            // CKRecord system fields for conflict-free uploads

    var memberStatus: SplitMemberStatus {
        get { SplitMemberStatus(rawValue: status) ?? .active }
        set { status = newValue.rawValue }
    }

    var isActive: Bool {
        memberStatus == .active
    }

    var isPendingApproval: Bool {
        memberStatus == .pendingApproval
    }

    var isRejected: Bool {
        memberStatus == .rejected
    }

    var canWrite: Bool {
        isActive
    }

    /// Member que aparece en listas activas de UI: activos + pending approval.
    /// Excluye estados terminales (left/removed/rejected) que son ruido sin acción posible.
    var isVisible: Bool {
        isActive || isPendingApproval
    }

    var isAdmin: Bool {
        isGroupOwner || role == "admin"
    }

    init(
        groupZoneID: String = "",
        displayName: String = "",
        cloudKitUserRecordID: String = "",
        role: String = "member",
        status: SplitMemberStatus = .active,
        isGroupOwner: Bool = false,
        isCurrentUser: Bool = false
    ) {
        self.id = UUID()
        self.groupZoneID = groupZoneID
        self.displayName = displayName
        self.cloudKitUserRecordID = cloudKitUserRecordID
        self.role = role
        self.status = status.rawValue
        self.isGroupOwner = isGroupOwner
        self.isCurrentUser = isCurrentUser
        self.joinedAt = Date.now
    }
}
