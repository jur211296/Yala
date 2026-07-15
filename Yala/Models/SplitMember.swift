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

    /// Auth `uid` del backend (canal Grupos → backend, incremento G3). **LOCAL-only del canal backend**:
    /// lo escribe SOLO el apply del pull de `GroupsSyncClient` (proyección del `user_id` del wire) y JAMÁS
    /// viaja en un CKRecord (el sync de Grupos vigente es CKSyncEngine y este campo no está en
    /// `CKRecordTranslator`/`CKConstants` — no forma parte del schema del container de Grupos). Sirve para
    /// derivar `isCurrentUser` contra `CloudAuthService.currentUserID` cuando el canal backend está
    /// encendido (DARK hoy); `nil` en members legacy/CloudKit → el path por `cloudKitUserRecordID` sigue
    /// siendo el fallback. Anonimización del server (`user_id` null) → este campo también se NULLea.
    /// CloudKit-safe: opcional, default `nil`, sin `.unique`.
    var userID: String?

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
