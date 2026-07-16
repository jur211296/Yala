//
//  GroupMigrationPayloadBuilder.swift
//  Yala
//
//  Construye los payloads `p_meta` / `p_members` (jsonb) del RPC `migrate_group` (G6-1) desde el snapshot
//  local del grupo migrado (G6-3, C3 paso 1). Pure-logic (value types, sin @Model/ModelContext) → testeable
//  sin SwiftData. `member_key = cloudKitUserRecordID` (recordName CloudKit-era) para que las FKs deterministas
//  del historial (SplitMember.id = deterministicUUID("SplitMember", "{groupID}:{recordName}")) matcheen en un
//  device fresco tras la migración (R10). Los timestamps viajan como ISO8601 (PostgREST castea a timestamptz).
//

import Foundation

/// Snapshot de valores del `SplitGroup` (leído en el MainActor por el uploader, pasado por valor al builder).
struct GroupMigrationMetaSnapshot: Equatable {
    let name: String
    let currencyCode: String
    let iconName: String
    let colorHex: String
    let defaultSplitType: String
    let simplifyDebts: Bool
    let showDebtsInSingleCurrency: Bool
    let membersCanInvite: Bool
    let createdAt: Date
}

/// Snapshot de valores de un `SplitMember`.
struct GroupMigrationMemberSnapshot: Equatable {
    /// = `cloudKitUserRecordID` (recordName CloudKit-era). Vacío → el member se SALTA (residual documentado).
    let memberKey: String
    let displayName: String
    let role: String     // "admin" | "member"
    let status: String   // rawValue de SplitMemberStatus
    let isOwner: Bool
    let joinedAt: Date
}

enum GroupMigrationPayloadBuilder {

    /// Estados que el RPC `migrate_group` ACEPTA (DDL: `v_status not in (...)` → yala_bad_input permanente).
    /// `rejected` NO está: un member rechazado (join denegado) no tiene historial financiero → se SALTA.
    static let acceptedStatuses: Set<String> = ["active", "pendingApproval", "left", "removed"]

    /// ISO8601 con zona (PostgREST `::timestamptz`). `.withInternetDateTime` → "2026-07-16T02:44:11Z".
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Construye `(meta, members)` para `migrate_group`. `nil` si el payload sería PERMANENTEMENTE inválido
    /// (evita el retry-storm del uploader): nombre vacío, moneda no-3-letras, o ≠ 1 owner con member_key no
    /// vacío tras filtrar. Los members con `member_key` vacío o status no aceptado se SALTAN (dedupe por
    /// member_key: gana el primero). El caller registra breadcrumbs por los skips.
    static func build(
        groupID: String,
        meta: GroupMigrationMetaSnapshot,
        members: [GroupMigrationMemberSnapshot]
    ) -> (meta: [String: Any], members: [[String: Any]])? {
        let trimmedName = meta.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName.count <= 120 else { return nil }
        guard meta.currencyCode.count == 3 else { return nil }

        var seenKeys: Set<String> = []
        var payloadMembers: [[String: Any]] = []
        var ownerCount = 0
        for m in members {
            let key = m.memberKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }                       // sin recordName → skip
            guard acceptedStatuses.contains(m.status) else { continue } // rejected/desconocido → skip
            let role = (m.role == "admin" || m.role == "member") ? m.role : "member"
            let display = m.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !display.isEmpty, display.count <= 80 else { continue }
            guard !seenKeys.contains(key) else { continue }            // dedupe member_key
            seenKeys.insert(key)
            if m.isOwner { ownerCount += 1 }
            payloadMembers.append([
                "member_key": key,
                "display_name": display,
                "role": role,
                "status": m.status,
                "is_owner": m.isOwner,
                "joined_at": iso8601.string(from: m.joinedAt),
            ])
        }

        // El RPC exige EXACTAMENTE 1 owner (yala_bad_input si no) → validar aquí para no llamar el RPC en vano.
        guard ownerCount == 1, !payloadMembers.isEmpty else { return nil }

        let metaDict: [String: Any] = [
            "name": trimmedName,
            "currency_code": meta.currencyCode,
            "icon_name": meta.iconName,
            "color_hex": meta.colorHex,
            "default_split_type": meta.defaultSplitType,
            "simplify_debts": meta.simplifyDebts,
            "show_debts_in_single_currency": meta.showDebtsInSingleCurrency,
            "members_can_invite": meta.membersCanInvite,
            "created_at": iso8601.string(from: meta.createdAt),
        ]
        return (metaDict, payloadMembers)
    }
}
