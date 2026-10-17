//
//  PanelBudgetsFallbackLogic.swift
//  Yala
//
//  Qué presupuestos enseña el widget del Panel cuando ninguno es favorito (UX 2.2 · L3-13, opción A): los dos más
//  usados, del que va más gastado al que menos. Con empate, el orden de entrada (el de la lista de presupuestos).
//

import Foundation

enum PanelBudgetsFallbackLogic {
    static let limit = 2

    static func mostUsed<T>(_ items: [T], percentage: (T) -> Double, limit: Int = limit) -> [T] {
        let ranked = items.enumerated().sorted { lhs, rhs in
            let l = percentage(lhs.element), r = percentage(rhs.element)
            return l == r ? lhs.offset < rhs.offset : l > r
        }
        return Array(ranked.prefix(limit).map(\.element))
    }
}
