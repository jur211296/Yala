//
//  GroupBridgePreference.swift
//  Yala
//
//  Override per-grupo del bridge `SplitExpense ↔ TransactionItem`.
//  Vive en SwiftData private DB del current user (synced cross-device via CloudKit
//  private database) — preferencia personal NO compartida con otros miembros del grupo.
//
//  Regla del resolver (`BridgeResolverLogic`):
//    - global=false → effective=false (override ignorado, no puede activarse per-grupo)
//    - global=true  → override ?? true (default ON, override OFF excluye este grupo)
//
//  CloudKit constraints:
//    - Sin `@Attribute(.unique)` (incompat con CKSyncEngine — dedup via
//      `GroupBridgePreferenceDeduplicationService`).
//    - Todas las propiedades con defaults obligatorios.
//    - Sin `@Relationship` (FK a `SplitGroup` por `groupZoneID: String`, mismo
//      pattern que `SplitMember`/`SplitExpense`).
//

import Foundation
import SwiftData

@Model
final class GroupBridgePreference {
    var id: UUID = UUID()
    /// FK a `SplitGroup.cloudKitZoneID`. Identifica el grupo al que aplica el override.
    var groupZoneID: String = ""
    /// nil = heredar del toggle global. true/false = override explícito.
    /// Solo `false` tiene efecto cuando global=true (regla "override solo restringe").
    var bridgeOverride: Bool?
    var createdAt: Date = Date.now

    init(groupZoneID: String = "", bridgeOverride: Bool? = nil) {
        self.id = UUID()
        self.groupZoneID = groupZoneID
        self.bridgeOverride = bridgeOverride
        self.createdAt = Date.now
    }
}
