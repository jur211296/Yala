//
//  AccountTagDuplicateCountLogic.swift
//  Yala
//
//  Pure-logic de DETECCIÓN (no borra) de copias idénticas de Account y Tag.
//  El mismo detonante que duplicó subcategorías —la regeneración masiva de
//  `Account.shortcutID` y `Tag.id` en la migración V3 + re-sync de CloudKit—
//  pudo materializar copias de cuentas y tags. Aún no hay dedup de Account/Tag;
//  esto solo CUENTA por identidad de contenido para telemetría, de modo que
//  confirmemos con datos reales si el problema existe antes de decidir un fix.
//
//  Testeable sin `ModelContext` (R8).
//

import Foundation
import SwiftData

enum AccountTagDuplicateCountLogic {

    struct DuplicateGroup: Equatable {
        let identity: String
        let count: Int
    }

    /// Identidad de contenido de una cuenta: las copias del mismo registro lógico
    /// comparten estos campos (difieren solo en el `shortcutID` regenerado / recordName).
    /// Incluye `isSystemAccount` para no mezclar la cuenta virtual de grupos con las del usuario.
    static func accountIdentity(_ account: Account) -> String {
        "\(account.name)|\(account.type)|\(account.currencyCode)|\(account.isSystemAccount)"
    }

    /// Identidad de contenido de un tag.
    static func tagIdentity(_ tag: Tag) -> String {
        "\(tag.name)|\(tag.colorHex)|\(tag.iconName)"
    }

    /// Grupos con >1 elemento por identidad (posibles copias). Genérico sobre la
    /// función de identidad → testeable con modelos o con strings directamente.
    static func duplicateGroups<T>(_ items: [T], identity: (T) -> String) -> [DuplicateGroup] {
        Dictionary(grouping: items, by: identity)
            .filter { $0.value.count > 1 }
            .map { DuplicateGroup(identity: $0.key, count: $0.value.count) }
            .sorted { $0.identity < $1.identity }
    }

    /// Igual que `duplicateGroups` pero devuelve las INSTANCIAS de cada grupo con >1 elemento
    /// (el merge de I11-4 necesita reparentar+borrar, no solo contar). Orden determinista por
    /// identity (reproducibilidad del merge). La variante de conteo `duplicateGroups` NO se toca
    /// (la telemetría read-only de boot y la detección de I11-2 dependen de ella).
    static func duplicateGroupItems<T>(_ items: [T], identity: (T) -> String) -> [[T]] {
        Dictionary(grouping: items, by: identity)
            .filter { $0.value.count > 1 }
            .sorted { $0.key < $1.key }
            .map { $0.value }
    }
}
