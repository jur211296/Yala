//
//  BudgetStatusCounter.swift
//  Yala
//
//  Pure-logic helper para clasificar presupuestos por estado (al día / al límite /
//  superado) y agregar contadores. Sin SwiftData ni UI — el callsite construye los
//  inputs `[Double]` desde `[BudgetSummary]`.
//
//  Thresholds:
//    - spentPercent  < 80%   → .onTrack
//    - spentPercent  80-99%  → .atLimit
//    - spentPercent >= 100%  → .overLimit
//

import Foundation

enum BudgetCounterStatus: Equatable {
    case onTrack
    case atLimit
    case overLimit
}

struct BudgetCounters: Equatable {
    let onTrack: Int
    let atLimit: Int
    let overLimit: Int

    static let zero = BudgetCounters(onTrack: 0, atLimit: 0, overLimit: 0)
}

enum BudgetStatusCounter {
    /// Clasifica un presupuesto individual por `spent / limitAmount`.
    /// `limit <= 0` defensive → `.onTrack` (no rompe en datos inválidos).
    static func classify(spent: Double, limit: Double) -> BudgetCounterStatus {
        guard limit > 0 else { return .onTrack }
        let pct = spent / limit * 100
        if pct >= 100 { return .overLimit }
        if pct >= 80  { return .atLimit }
        return .onTrack
    }

    /// Agrega contadores a partir de pares `(spent, limit)` ya filtrados por
    /// `isActive` en el callsite (este helper no conoce SwiftData).
    static func counters(for items: [(spent: Double, limit: Double)]) -> BudgetCounters {
        var ot = 0, al = 0, ol = 0
        for item in items {
            switch classify(spent: item.spent, limit: item.limit) {
            case .onTrack:   ot += 1
            case .atLimit:   al += 1
            case .overLimit: ol += 1
            }
        }
        return BudgetCounters(onTrack: ot, atLimit: al, overLimit: ol)
    }
}
