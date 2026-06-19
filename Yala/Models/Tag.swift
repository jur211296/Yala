//
//  Tag.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation
import SwiftData

// MARK: - Tag

@Model
final class Tag {
    // CloudKit: defaults required
    // Stable UUID for CSV mirror references (TransactionItem.tagIDs, Budget.tagIDs, etc.)
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#FF9F0A"
    var iconName: String = "tag.fill"
    var isActive: Bool = true
    var createdAt: Date = Date.now

    /// CloudKit: all relationships must be optional
    @Relationship(deleteRule: .nullify, inverse: \TransactionItem.tags)
    var transactions: [TransactionItem]?

    /// Relación inversa con budgets (muchos-a-muchos) - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var budgets: [Budget]?

    /// Relación inversa con pagos favoritos (muchos-a-muchos) - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var favoritePayments: [FavoritePayment]?

    /// Relación inversa con pagos planificados (muchos-a-muchos) - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var scheduledPayments: [ScheduledPayment]?

    /// Relación inversa con borradores de bandeja (muchos-a-muchos) - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var inboxDrafts: [InboxDraft]?

    /// Paleta de 15 colores visibles en light y dark mode (evita negros/blancos)
    static let defaultColors: [String] = [
        "#FF9F0A",  // Naranja
        "#30D158",  // Verde
        "#0A84FF",  // Azul
        "#FF375F",  // Rosa
        "#5E5CE6",  // Púrpura
        "#FFD60A",  // Amarillo
        "#64D2FF",  // Cyan
        "#BF5AF2",  // Magenta
        "#32ADE6",  // Teal
        "#FF6482",  // Coral
        "#AC8E68",  // Café
        "#FF453A",  // Rojo
        "#66D4CF",  // Turquesa
        "#DA8FFF",  // Lavanda
        "#7EC8E3",  // Azul cielo
    ]

    /// Lookup `[UUID: Tag]` desde una colección de Tags. Usa `uniquingKeysWith`
    /// para tolerar duplicados de id (race CloudKit dedup documentado en
    /// CLAUDE.md 2026-05-07 — Sprint extra TODO #10).
    static func byIDLookup(_ tags: [Tag]) -> [UUID: Tag] {
        Dictionary(tags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Devuelve el siguiente color disponible que no esté en uso
    static func nextAvailableColor(excluding usedColors: [String]) -> String {
        let usedSet = Set(usedColors.map { $0.uppercased() })
        for color in defaultColors {
            if !usedSet.contains(color.uppercased()) {
                return color
            }
        }
        // Si todos están usados, vuelve al primero
        return defaultColors[0]
    }

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = defaultColors[0],
        iconName: String = "tag.fill",
        isActive: Bool = true,
        createdAt: Date = Date.now,
        transactions: [TransactionItem] = []
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.isActive = isActive
        self.createdAt = createdAt
        self.transactions = transactions
    }
}
