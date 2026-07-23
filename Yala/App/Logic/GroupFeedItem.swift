//
//  GroupFeedItem.swift
//  Yala
//
//  Item mixto del feed cronológico de un grupo (tab "Gastos"): gastos + liquidaciones
//  confirmadas, mergeados y ordenados para presentarse juntos. Pure-logic, testeable.
//
//  Marcado `@MainActor` porque manipula `SplitExpense`/`SplitSettlement` (@Model, aislados
//  al MainActor por SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor en este target).
//

import Foundation

@MainActor
enum GroupFeedItem {
    case expense(SplitExpense)
    case settlement(SplitSettlement)

    /// Id estable y libre de colisión entre familias: un `SplitExpense` y un `SplitSettlement`
    /// con el MISMO UUID base nunca chocan (el settlement lleva prefijo `"settlement-"`).
    var id: String {
        switch self {
        case .expense(let expense): return expense.id.uuidString
        case .settlement(let settlement): return "settlement-\(settlement.id.uuidString)"
        }
    }

    /// Fecha del item para agrupar por día (mismo criterio que el feed de gastos).
    var date: Date {
        switch self {
        case .expense(let expense): return expense.date
        case .settlement(let settlement): return settlement.date
        }
    }

    /// Instante para ordenar dentro del mismo día (desc). Los gastos usan `createdAt`
    /// (el instante real de captura); `SplitSettlement` NO tiene `createdAt`, así que usa `date`.
    /// Nota consciente: un settlement retro-fechado vía `DatePicker` date-only queda a medianoche
    /// exacta de su día → sortea al fondo de ese día. Es el instante real persistido, NO un bug:
    /// no "arreglar" añadiendo un timestamp sintético.
    var sortTimestamp: Date {
        switch self {
        case .expense(let expense): return expense.createdAt
        case .settlement(let settlement): return settlement.date
        }
    }

    /// Merge presentacional del feed: todos los `expenses` + SOLO los settlements `isConfirmed`
    /// (decisión owner — los pendientes viven en Balances con sus acciones confirmar/rechazar).
    /// El orden final lo aplica la vista (días desc, intra-día por `sortTimestamp` desc).
    static func feedItems(expenses: [SplitExpense], settlements: [SplitSettlement]) -> [GroupFeedItem] {
        let expenseItems = expenses.map { GroupFeedItem.expense($0) }
        let settlementItems = settlements
            .filter { $0.isConfirmed }
            .map { GroupFeedItem.settlement($0) }
        return expenseItems + settlementItems
    }
}
