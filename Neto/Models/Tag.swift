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
    var isActive: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \TransactionItem.tags)
    var transactions: [TransactionItem]

    init(
        name: String,
        colorHex: String = "#1C3556",
        isActive: Bool = true,
        createdAt: Date = Date(),
        transactions: [TransactionItem] = []
    ) {
        self.name = name
        self.colorHex = colorHex
        self.isActive = isActive
        self.createdAt = createdAt
        self.transactions = transactions
    }
}
