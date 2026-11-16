//
//  BudgetStatusCounter.swift
//  Yala
//
//  Pure-logic helper para clasificar presupuestos por estado (al día / al límite /
//  superado) y agregar contadores. Sin SwiftData ni UI — el callsite construye los
//  inputs `[Double]` desde `[BudgetSummary]`.
//
//  Un estado, una palabra, un color (decisión 23 de la revisión 2.3, Jürgen 2026-11-09). Umbrales:
//    - gastado  < 80 %        → .onTrack       (sin palabra, color del presupuesto)
//    - gastado  80 – 99 %     → .atLimit       («En el límite», naranja)
//    - gastado  100 % justo   → .reachedLimit  («Llegaste al límite», naranja)
//    - gastado  > 100 %       → .overLimit     («Te pasaste», rosa; sección «Excedidos»)
//
//  «Justo» y «pasado» los decide `BudgetRemainingLogic.remaining` (medio céntimo de holgura): la misma regla de «Te
//  quedan / Te pasaste por». Barra, palabra, sección e historial leen de aquí; antes la sección y la barra rosa
//  empezaban en el 100 % justo y la cifra por encima, y al 100 % la fila decía «Te quedan S/ 0.00» en «Excedidos».
//

import Foundation

enum BudgetCounterStatus: Equatable {
    case onTrack
    case atLimit
    /// Gastado justo el límite: no se pasó.
    case reachedLimit
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
    /// Clasifica un presupuesto por lo gastado contra su límite.
    /// `limit <= 0` defensive → `.onTrack` (no rompe en datos inválidos).
    static func classify(spent: Double, limit: Double) -> BudgetCounterStatus {
        guard limit > 0 else { return .onTrack }
        let remaining = BudgetRemainingLogic.remaining(limit: limit, spent: spent)
        if remaining < 0 { return .overLimit }
        if remaining == 0 { return .reachedLimit }
        return spent / limit * 100 >= atLimitPercent ? .atLimit : .onTrack
    }

    /// La barra se pinta de aviso (naranja) en «en el límite» y «llegaste al límite»; el rosa es de «te pasaste».
    static func isWarning(_ status: BudgetCounterStatus) -> Bool {
        status == .atLimit || status == .reachedLimit
    }

    /// Para la barra, que recibe el porcentaje y aparte si se pasó: desde el 80 % es aviso. El rosa lo decide quien
    /// sabe si se pasó (`isExceeded`, `classify == .overLimit`), así que al 100 % justo la barra queda naranja.
    static func isAtOrPastLimit(percent: Double) -> Bool {
        percent >= atLimitPercent
    }

    /// Agrega contadores a partir de pares `(spent, limit)` ya filtrados por
    /// `isActive` en el callsite (este helper no conoce SwiftData).
    static func counters(for items: [(spent: Double, limit: Double)]) -> BudgetCounters {
        var ot = 0, al = 0, ol = 0
        for item in items {
            switch classify(spent: item.spent, limit: item.limit) {
            case .onTrack:   ot += 1
            // Llegar justo al límite no es pasarse: cuenta con «en el límite».
            case .atLimit, .reachedLimit: al += 1
            case .overLimit: ol += 1
            }
        }
        return BudgetCounters(onTrack: ot, atLimit: al, overLimit: ol)
    }
}
