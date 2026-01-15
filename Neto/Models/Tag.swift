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
    var iconName: String
    var isActive: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \TransactionItem.tags)
    var transactions: [TransactionItem]

    /// Relación inversa con budgets (muchos-a-muchos)
    var budgets: [Budget] = []

    init(
        name: String,
        colorHex: String = "#1C3556",
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
