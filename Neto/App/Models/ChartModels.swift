//
//  ChartModels.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Foundation

enum TrendGrouping {
    case day
    case week
    case month
}

struct ChartTransaction: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let income: Double
    let expense: Double
    let balance: Double
}

enum BalanceStatus {
    case normal
    case good
    case critical
    case unknown
}
