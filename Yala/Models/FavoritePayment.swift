//
//  FavoritePayment.swift
//  Yala
//
//  SwiftData model for favorite transaction templates.
//

import Foundation
import SwiftData

// MARK: - FavoritePayment

/// Template for quickly creating recurring transactions
@Model
final class FavoritePayment {
    /// Display name for the favorite (required) - CloudKit: default required
    var name: String = ""

    /// Transaction type: "income" or "expense" (no transfers) - CloudKit: default required
    var transactionType: String = "expense"

    /// Optional pre-filled amount
    var amount: Double?

    /// Optional description/note
    var note: String?

    /// Optional linked account
    @Relationship(deleteRule: .nullify, inverse: \Account.favoritePayments)
    var account: Account?

    /// Optional linked subcategory
    @Relationship(deleteRule: .nullify, inverse: \Subcategory.favoritePayments)
    var subcategory: Subcategory?

    /// Optional linked tags (many-to-many) - CloudKit: must be optional
    @Relationship(deleteRule: .nullify, inverse: \Tag.favoritePayments)
    var tags: [Tag]?

    /// Optional nature override (nil = use subcategory's nature)
    var natureOverride: String?

    /// Optional currency code
    var currencyCode: String?

    /// Creation date for sorting - CloudKit: default required
    var createdAt: Date = Date()

    /// Display order for manual reordering - CloudKit: default required
    var displayOrder: Int = 0

    init(
        name: String,
        transactionType: String = "expense",
        amount: Double? = nil,
        note: String? = nil,
        account: Account? = nil,
        subcategory: Subcategory? = nil,
        tags: [Tag] = [],
        natureOverride: String? = nil,
        currencyCode: String? = nil,
        displayOrder: Int = 0
    ) {
        self.name = name
        self.transactionType = transactionType
        self.amount = amount
        self.note = note
        self.account = account
        self.subcategory = subcategory
        self.tags = tags
        self.natureOverride = natureOverride
        self.currencyCode = currencyCode
        self.createdAt = Date()
        self.displayOrder = displayOrder
    }

    // MARK: - Computed Properties

    /// Transaction type as enum
    var type: TransactionType {
        TransactionType(rawValue: transactionType) ?? .expense
    }

    /// Effective nature (override or subcategory's nature)
    var effectiveNature: SubcategoryNature? {
        if let override = natureOverride {
            return SubcategoryNature(rawValue: override)
        }
        return subcategory?.nature
    }
}
