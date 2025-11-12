import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var name: String
    var colorHex: String
    var isIncome: Bool
    init(name: String, colorHex: String, isIncome: Bool) {
        self.name = name
        self.colorHex = colorHex
        self.isIncome = isIncome
    }
}

@Model
final class TransactionItem {
    var date: Date
    var amount: Decimal
    var currencyCode: String
    var note: String?
    @Relationship var category: Category?

    init(date: Date, amount: Decimal, currencyCode: String, note: String? = nil, category: Category? = nil) {
        self.date = date
        self.amount = amount
        self.currencyCode = currencyCode
        self.note = note
        self.category = category
    }
}

@Model
final class Budget {
    var month: Int
    var year: Int
    var currencyCode: String
    var limitAmount: Decimal
    @Relationship var category: Category?

    init(month: Int, year: Int, currencyCode: String, limitAmount: Decimal, category: Category? = nil) {
        self.month = month
        self.year = year
        self.currencyCode = currencyCode
        self.limitAmount = limitAmount
        self.category = category
    }
}

@Model
final class ExchangeRate {
    @Attribute(.unique) var dateKey: String   // "yyyy-MM-dd"
    var base: String                           // "EUR"
    var rates: Data                            // JSON [code: Decimal]
    init(dateKey: String, base: String, rates: Data) {
        self.dateKey = dateKey
        self.base = base
        self.rates = rates
    }
}
