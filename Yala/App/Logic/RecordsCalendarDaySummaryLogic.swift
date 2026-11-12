//
//  RecordsCalendarDaySummaryLogic.swift
//  Yala
//
//  Qué dice el resumen del día elegido en el calendario de Registros (auditoría UX 2.2 · L8-10):
//  «Gastaste S/ 2,300 · Entró S/ 354». Sin vistas: la vista solo pone el formato de importe.
//

import Foundation

enum RecordsCalendarDaySummaryLogic {

    /// Un lado del resumen. El orden es el de la frase: primero el gasto, después lo que entró.
    enum Part: Equatable {
        case spent(Double)
        case income(Double)
    }

    /// Por debajo de medio céntimo el lado no se nombra: una suma de reembolsos en coma flotante puede dejar
    /// un residuo (1e-15) que se pintaría como «Gastaste S/ 0.00».
    static let minimumAmount = 0.005

    /// Los lados que se nombran. Si uno es 0 (o negativo: solo hubo un reembolso), no sale; si los dos lo son,
    /// no hay resumen y la vista no pinta nada.
    static func parts(_ totals: DailySpendingCalculator.DayTotals) -> [Part] {
        var parts: [Part] = []
        if totals.expense >= minimumAmount { parts.append(.spent(totals.expense)) }
        if totals.income >= minimumAmount { parts.append(.income(totals.income)) }
        return parts
    }
}
