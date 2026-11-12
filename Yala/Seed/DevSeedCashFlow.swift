//
//  DevSeedCashFlow.swift
//  Yala
//
//  Un plan de flujo de caja para el perfil `rendimiento`: sin plan, Flujo de caja enseña la pantalla de crearlo y no
//  hay proyección que medir.
//

#if DEBUG
import Foundation
import SwiftData

@MainActor
enum DevSeedCashFlow {

    /// Crea el plan con las líneas que propone la pantalla de crear plan (`CashFlowSetupView`), por el mismo camino:
    /// `CashFlowPlanViewModel.generateSuggestions` y `createPlan`. No inventa líneas propias.
    static func create(in context: ModelContext, currencyCode: String) {
        do {
            let transactions = try context.fetch(FetchDescriptor<TransactionItem>())
            let payments = try context.fetch(FetchDescriptor<ScheduledPayment>())
            let categories = try context.fetch(FetchDescriptor<Category>())
            let viewModel = CashFlowPlanViewModel()
            viewModel.setContext(context)
            viewModel.generateSuggestions(
                transactions: transactions,
                scheduledPayments: payments,
                categories: categories,
                currencyCode: currencyCode
            )
            viewModel.createPlan(startingBalance: 0)
        } catch {
            print("DevSeedCashFlow: Error: \(error)")
        }
    }
}
#endif
