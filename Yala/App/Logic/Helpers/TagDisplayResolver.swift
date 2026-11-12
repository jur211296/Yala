//
//  TagDisplayResolver.swift
//  Yala
//
//  Static helper that resolves display Tag objects for a record using the
//  CSV-mirror SSOT + an injected `[UUID: Tag]` catalog.
//
//  Flow per call:
//  1. `record.resolvedTagIDs(scheduleBackfill: true)` → CSV first, M2M fallback
//     with async auto-heal.
//  2. `compactMap { catalog[$0] }` resolves UUIDs to Tag objects, silently
//     dropping orphan UUIDs (Tag deleted but CSV not yet re-encoded).
//  3. Orden ESTABLE (card z3by, decidido por Jürgen el 21-oct): el del catálogo de Ajustes › Etiquetas si la persona
//     lo ordenó (`AppPreferences.tagsSortOrderNames`), y si no, alfabético. Antes salía en el orden de recorrido de un
//     `Set`, distinto en cada arranque: las etiquetas cambiaban de sitio y, con más de tres, cambiaban las que se veían.
//  4. Optional `prefix(limit)` for display chips (typically 3 in Rows), aplicado DESPUÉS de ordenar.
//

import Foundation

enum TagDisplayResolver {

    static func tags(
        for transaction: TransactionItem,
        catalog: [UUID: Tag],
        order: [String] = [],
        limit: Int? = nil
    ) -> [Tag] {
        resolve(
            ids: transaction.resolvedTagIDs(scheduleBackfill: true) ?? [],
            catalog: catalog,
            order: order,
            limit: limit
        )
    }

    static func tags(
        for draft: InboxDraft,
        catalog: [UUID: Tag],
        order: [String] = [],
        limit: Int? = nil
    ) -> [Tag] {
        resolve(
            ids: draft.resolvedTagIDs(scheduleBackfill: true) ?? [],
            catalog: catalog,
            order: order,
            limit: limit
        )
    }

    static func tags(
        for favorite: FavoritePayment,
        catalog: [UUID: Tag],
        order: [String] = [],
        limit: Int? = nil
    ) -> [Tag] {
        resolve(
            ids: favorite.resolvedTagIDs(scheduleBackfill: true) ?? [],
            catalog: catalog,
            order: order,
            limit: limit
        )
    }

    static func tags(
        for payment: ScheduledPayment,
        catalog: [UUID: Tag],
        order: [String] = [],
        limit: Int? = nil
    ) -> [Tag] {
        resolve(
            ids: payment.resolvedTagIDs(scheduleBackfill: true) ?? [],
            catalog: catalog,
            order: order,
            limit: limit
        )
    }

    // MARK: - Pure helper (testable without SwiftData)

    /// Pure resolution: ids → Tags via catalog, drop orphans, stable order, optional limit.
    /// `order` = los nombres en el orden de Ajustes › Etiquetas (`tagsSortOrderNames`); vacío = alfabético.
    static func resolve(
        ids: Set<UUID>,
        catalog: [UUID: Tag],
        order: [String] = [],
        limit: Int? = nil
    ) -> [Tag] {
        let resolved = sorted(ids.compactMap { catalog[$0] }, order: order)
        if let limit, resolved.count > limit {
            return Array(resolved.prefix(limit))
        }
        return resolved
    }

    /// Las del orden propio primero, en ese orden; las demás después, alfabéticas (`localizedStandardCompare`). Dos con
    /// el mismo nombre se desempatan por `id`, para que ni eso dependa del recorrido.
    static func sorted(_ tags: [Tag], order: [String]) -> [Tag] {
        let index = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return tags.sorted { a, b in
            switch (index[a.name], index[b.name]) {
            case let (x?, y?) where x != y:
                return x < y
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                let byName = a.name.localizedStandardCompare(b.name)
                if byName != .orderedSame { return byName == .orderedAscending }
                return a.id.uuidString < b.id.uuidString
            }
        }
    }
}
