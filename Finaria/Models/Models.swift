//
//  Models.swift
//  Finaria
//
//  Modelos base SwiftData para Finaria.
//

import Foundation
import SwiftData

// MARK: - Category

@Model
final class Category {
    var name: String
    var colorHex: String
    var isIncome: Bool
    var subcategories: [Subcategory]
    
    init(
        name: String,
        colorHex: String,
        isIncome: Bool,
        subcategories: [Subcategory] = []
    ) {
        self.name = name
        self.colorHex = colorHex
        self.isIncome = isIncome
        self.subcategories = subcategories
    }
}

// MARK: - Subcategory

@Model
final class Subcategory {
    var name: String
    var colorHex: String?
    var category: Category
    
    init(
        name: String,
        colorHex: String? = nil,
        category: Category
    ) {
        self.name = name
        self.colorHex = colorHex
        self.category = category
    }
}

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

// MARK: - Account

@Model
final class Account {
    var name: String
    var currencyCode: String
    var colorHex: String
    var iconName: String
    
    var type: String
    var accountNumber: String?
    var initialBalance: Double
    var adjustmentMode: String
    var excludeFromStatistics: Bool
    var isArchived: Bool
    
    init(
        name: String,
        currencyCode: String,
        colorHex: String,
        iconName: String,
        type: String,
        accountNumber: String? = nil,
        initialBalance: Double = 0,
        adjustmentMode: String = "Ajustar por registro",
        excludeFromStatistics: Bool = false,
        isArchived: Bool = false
    ) {
        self.name = name
        self.currencyCode = currencyCode
        self.colorHex = colorHex
        self.iconName = iconName
        self.type = type
        self.accountNumber = accountNumber
        self.initialBalance = initialBalance
        self.adjustmentMode = adjustmentMode
        self.excludeFromStatistics = excludeFromStatistics
        self.isArchived = isArchived
    }
}

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

// MARK: - ExchangeRate

@Model
final class ExchangeRate {
    var dateKey: String
    var base: String
    var rates: Data
    
    init(
        dateKey: String,
        base: String,
        rates: Data
    ) {
        self.dateKey = dateKey
        self.base = base
        self.rates = rates
    }
    
    convenience init(
        dateKey: String,
        base: String,
        ratesDictionary: [String: Double]
    ) throws {
        let data = try JSONEncoder().encode(ratesDictionary)
        self.init(dateKey: dateKey, base: base, rates: data)
    }
    
    func decodedRates() -> [String: Double] {
        (try? JSONDecoder().decode([String: Double].self, from: rates)) ?? [:]
    }
}
