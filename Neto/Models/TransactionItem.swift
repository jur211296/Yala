//
//  TransactionItem.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Foundation
import SwiftData

// MARK: - TransactionItem

@Model
final class TransactionItem {
    var date: Date
    var amount: Double
    var currencyCode: String
    var note: String?

    var category: Category?
    var subcategory: Subcategory?
    var account: Account?
    var tags: [Tag]

    init(
        date: Date,
        amount: Double,
        currencyCode: String,
        note: String? = nil,
        category: Category? = nil,
        subcategory: Subcategory? = nil,
        account: Account? = nil,
        tags: [Tag] = []
    ) {
        self.date = date
        self.amount = amount
        self.currencyCode = currencyCode
        self.note = note
        self.category = category
        self.subcategory = subcategory
        self.account = account
        self.tags = tags
    }
}
