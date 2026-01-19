//
//  Tag.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Foundation
import SwiftData

// MARK: - Tag

@Model
final class Tag {
    var name: String
    var colorHex: String
    var iconName: String = "tag.fill"
    var isActive: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \TransactionItem.tags)
    var transactions: [TransactionItem]

    /// Relación inversa con budgets (muchos-a-muchos)
    var budgets: [Budget] = []

    /// Relación inversa con pagos favoritos (muchos-a-muchos)
    var favoritePayments: [FavoritePayment] = []

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
        name: String,
        colorHex: String = defaultColors[0],
        iconName: String = "tag.fill",
        isActive: Bool = true,
        createdAt: Date = Date(),
        transactions: [TransactionItem] = []
    ) {
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.isActive = isActive
        self.createdAt = createdAt
        self.transactions = transactions
    }
}
