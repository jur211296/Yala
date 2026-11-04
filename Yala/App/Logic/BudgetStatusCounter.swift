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
//  Es la fuente única del umbral «en el límite» (card bj9n, 2026-11-04): la barra de un presupuesto se pone naranja
//  con `isAtOrPastLimit(percent:)`. Antes la barra lo hacía al 75 % y el estado empezaba al 80 %.
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
    /// Desde qué porcentaje gastado un presupuesto está «en el límite». Decidido el 2026-11-04: 80 %.
    static let atLimitPercent: Double = 80
    /// Desde qué porcentaje está superado.
    static let overLimitPercent: Double = 100

    /// Clasifica un presupuesto individual por `spent / limitAmount`.
    /// `limit <= 0` defensive → `.onTrack` (no rompe en datos inválidos).
    static func classify(spent: Double, limit: Double) -> BudgetCounterStatus {
        guard limit > 0 else { return .onTrack }
        return classify(percent: spent / limit * 100)
    }

    /// Clasifica por el porcentaje gastado (0-100+), el que reciben las barras.
    static func classify(percent: Double) -> BudgetCounterStatus {
        if percent >= overLimitPercent { return .overLimit }
        if percent >= atLimitPercent { return .atLimit }
        return .onTrack
    }

    /// La barra se pinta de aviso desde aquí: «en el límite» o más.
    static func isAtOrPastLimit(percent: Double) -> Bool {
        classify(percent: percent) != .onTrack
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
