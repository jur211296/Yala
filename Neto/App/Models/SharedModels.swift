//
//  SharedModels.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Foundation

enum TrendType: String, CaseIterable, Identifiable {
    case balance = "Saldo"
    case expense = "Gasto"

    var id: String { rawValue }
}
