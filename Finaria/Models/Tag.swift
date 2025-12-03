//
//  Tag.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import Foundation
import SwiftData

// MARK: - Tag

@Model
final class Tag {
    var name: String
    var colorHex: String?
    var transactions: [TransactionItem]

    init(
        name: String,
        colorHex: String? = nil,
        transactions: [TransactionItem] = []
    ) {
        self.name = name
        self.colorHex = colorHex
        self.transactions = transactions
    }
}
