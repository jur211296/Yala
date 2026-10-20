//
//  ChatTopicAreasLogic.swift
//  Yala
//
//  «Temas» del chat por áreas (UX 2.2 · L14-6, opción B elegida por Jürgen el 2026-10-18): Gastos, Presupuestos,
//  Pagos planificados y Apuntar, con dos o tres ejemplos en cada una sacados de los datos del usuario. Antes la hoja
//  repetía las sugerencias del saludo, en el mismo orden.
//
//  Se arma EN LOCAL, sin pedir nada al modelo: los nombres salen de lo que el usuario tiene (sus categorías del mes,
//  sus presupuestos, sus pagos planificados) y las preguntas son plantillas en su idioma. Así la hoja nunca repite el
//  saludo, no espera a la red y no gasta cuota.
//

import Foundation
import SwiftData

/// Los nombres con los que se rellenan los ejemplos. Las categorías van de mayor a menor gasto del mes; las
/// subcategorías de Apuntar, de la más apuntada a la menos: «Gasté 20 en Alquiler» no es lo que alguien apunta a diario.
nonisolated struct ChatTopicAreasInput: Equatable {
    var topExpenseCategories: [String] = []
    var frequentExpenseSubcategories: [String] = []
    var activeBudgets: [String] = []
    var activeScheduledPayments: [String] = []
}

nonisolated enum ChatTopicArea: String, CaseIterable, Identifiable {
    case spending
    case budgets
    case payments
    case log

    var id: String { rawValue }
}

/// Un ejemplo que se toca. Los de Apuntar no se envían: se escriben en la caja para que el usuario ponga su importe
/// (enviarlo tal cual apuntaría un gasto inventado).
nonisolated struct ChatTopicExample: Identifiable, Equatable {
    let text: String
    let sends: Bool

    var id: String { text }
}

nonisolated struct ChatTopicAreaContent: Identifiable, Equatable {
    let area: ChatTopicArea
    let examples: [ChatTopicExample]

    var id: String { area.rawValue }
}

enum ChatTopicAreasLogic {

    /// Las áreas en el orden de la decisión. Gastos y Apuntar salen siempre; Presupuestos y Pagos planificados, solo
    /// si el usuario tiene alguno activo: preguntar por un presupuesto que no existe no lleva a nada.
    static func areas(for input: ChatTopicAreasInput) -> [ChatTopicAreaContent] {
        var result: [ChatTopicAreaContent] = []

        var spending = [L10n.UXL14D.spendingTop]
        if let category = input.topExpenseCategories.first {
            spending.append(L10n.UXL14D.spendingCategory(category))
        }
        spending.append(L10n.UXL14D.spendingVsLastMonth)
        result.append(content(.spending, spending))

        if let first = input.activeBudgets.first {
            let second = input.activeBudgets.count > 1
                ? L10n.UXL14D.budgetWorst
                : L10n.UXL14D.budgetOnTrack(first)
            result.append(content(.budgets, [L10n.UXL14D.budgetLeft(first), second]))
        }

        if let payment = input.activeScheduledPayments.first {
            result.append(content(.payments, [L10n.UXL14D.paymentsThisWeek, L10n.UXL14D.paymentWhen(payment)]))
        }

        var log = input.frequentExpenseSubcategories.prefix(2).map { L10n.UXL14D.logExample($0) }
        if log.count < 2 { log.append(L10n.UXL14D.logExampleDefault) }
        result.append(ChatTopicAreaContent(area: .log, examples: log.map { ChatTopicExample(text: $0, sends: false) }))

        return result
    }

    private static func content(_ area: ChatTopicArea, _ texts: [String]) -> ChatTopicAreaContent {
        ChatTopicAreaContent(area: area, examples: texts.map { ChatTopicExample(text: $0, sends: true) })
    }

    // MARK: - Datos del usuario

    /// Lee del store lo que nombran los ejemplos. El gasto del mes se suma con la misma regla que las sugerencias del
    /// chat (`ChatSuggestionsLLMService.monthSums`: gastos de grupo como «mi parte», ajustes de saldo y cuentas fuera
    /// de estadísticas fuera). Un fallo de lectura deja esa área sin nombres, no la hoja vacía.
    @MainActor
    static func input(from context: ModelContext, now: Date = .now) -> ChatTopicAreasInput {
        var input = ChatTopicAreasInput()
        let monthStart = Calendar.current.dateInterval(of: .month, for: now)?.start ?? now

        do {
            let monthTxs = try context.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> { $0.date >= monthStart }
            ))
            let adjustment = GroupBridgeStatsAdjustment.build(from: monthTxs, context: context)
            let txs = monthTxs.filter {
                $0.balanceAdjustmentType == nil && $0.account?.excludeFromStatistics != true
            }
            let sums = ChatSuggestionsLLMService.monthSums(
                txs,
                tagCatalog: [:],
                currencyCode: CurrencyDefaults.currentPreferred,
                adjustment: adjustment,
                includeGroupTransactions: (UserDefaults.standard.object(
                    forKey: AppPreferences.Keys.includeGroupTransactionsInStats
                ) as? Bool) ?? true,
                converter: CurrencyConverter.shared
            )
            input.topExpenseCategories = ranked(sums.categories)
            // Para Apuntar cuenta cuántas veces se apuntó cada subcategoría, no cuánto sumó. Solo lo apuntado a mano:
            // las patas de un gasto de grupo no son algo que el usuario escriba en el chat.
            var counts: [String: Double] = [:]
            for tx in txs where tx.category?.isIncome == false && tx.splitExpenseID == nil && tx.splitSettlementID == nil {
                if let name = tx.subcategory?.name { counts[name, default: 0] += 1 }
            }
            input.frequentExpenseSubcategories = ranked(counts)
        } catch {
            #if DEBUG
            print("ChatTopicAreasLogic: Error: \(error)")
            #endif
        }

        do {
            input.activeBudgets = try context.fetch(FetchDescriptor<Budget>(sortBy: [SortDescriptor(\.name)]))
                .filter(\.isActive)
                .map(\.name)
        } catch {
            #if DEBUG
            print("ChatTopicAreasLogic: Error: \(error)")
            #endif
        }

        do {
            input.activeScheduledPayments = try context.fetch(FetchDescriptor<ScheduledPayment>(sortBy: [SortDescriptor(\.name)]))
                .filter(\.isActive)
                .map(\.name)
        } catch {
            #if DEBUG
            print("ChatTopicAreasLogic: Error: \(error)")
            #endif
        }

        return input
    }

    /// Nombres de mayor a menor importe; a igual importe, por nombre, para que la hoja no cambie de un render a otro.
    nonisolated static func ranked(_ totals: [String: Double]) -> [String] {
        totals
            .filter { $0.value > 0 && !$0.key.isEmpty }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map(\.key)
    }
}
