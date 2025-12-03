//
//  Budget.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import Foundation
import SwiftData

// MARK: - Budget

@Model
final class Budget {
    var month: Int
    var year: Int
    var currencyCode: String
    var limitAmount: Double
    var category: Category?

    init(
        month: Int,
        year: Int,
        currencyCode: String,
        limitAmount: Double,
        category: Category? = nil
    ) {
        self.month = month
        self.year = year
        self.currencyCode = currencyCode
        self.limitAmount = limitAmount
        self.category = category
    }
}
