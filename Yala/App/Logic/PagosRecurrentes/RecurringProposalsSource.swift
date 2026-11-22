//
//  RecurringProposalsSource.swift
//  Yala
//
//  Puente entre el almacén y `RecurringPaymentDetector` (lote S1): lee los registros recientes y los pagos
//  planificados, deja solo los gastos que pueden ser un cobro fijo y devuelve las propuestas con el registro de donde
//  sale cada una (para la cuenta y la categoría del pago que se cree).
//
//  Fuera: ingresos, devoluciones, transferencias y ajustes de saldo, gastos y liquidaciones de grupo, importe cero, lo
//  fechado en el futuro y lo que generó un pago planificado que todavía existe. Los registros no se modifican (decisión S4).
//

import Foundation
import SwiftData

@MainActor
enum RecurringProposalsSource {

    /// Ventana hacia atrás: basta para una serie mensual (tres cobros y los 45 días desde el último) con margen, sin leer
    /// el historial entero. «Cobros encontrados» cuenta dentro de ella.
    static let lookbackDays = 200

    /// Una propuesta con lo que el pago planificado hereda de su último cobro.
    struct Item: Identifiable {
        let proposal: RecurringPaymentDetector.Proposal
        let account: Account?
        let subcategory: Subcategory?
        var id: String { proposal.key }

        /// La cuenta y la categoría si siguen vivas: la lista se guarda entre recargas y pueden haberse borrado
        /// mientras la página estaba oculta. Leer un modelo borrado aborta en el iPhone (`swiftui-ds.md`).
        var liveAccount: Account? { account.flatMap { $0.isDeleted || $0.modelContext == nil ? nil : $0 } }
        var liveSubcategory: Subcategory? { subcategory.flatMap { $0.isDeleted || $0.modelContext == nil ? nil : $0 } }
    }

    static func load(context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws -> [Item] {
        let cutoff = calendar.date(byAdding: .day, value: -lookbackDays, to: calendar.startOfDay(for: now)) ?? now
        let transactions = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.date >= cutoff && $0.date <= now }
        ))
        let payments = try context.fetch(FetchDescriptor<ScheduledPayment>())

        let paymentIDs = Set(payments.map { $0.id.uuidString })
        let eligible = transactions.filter { isCandidate($0, existingPaymentIDs: paymentIDs) }
        let charges = eligible.enumerated().map { index, tx in
            RecurringPaymentDetector.Charge(
                ref: index, date: tx.date, amount: abs(tx.amount), currencyCode: tx.currencyCode, name: tx.note ?? ""
            )
        }
        let planned = payments.map {
            RecurringPaymentDetector.PlannedPayment(name: $0.name, storedBrandID: $0.brandLogoID, amount: $0.amount)
        }

        return RecurringPaymentDetector.detect(charges: charges, plannedPayments: planned, now: now, calendar: calendar)
            .map { proposal in
                // Del cobro más reciente de la serie que la tenga: el último puede venir sin categoría o de una cuenta
                // ya archivada.
                let newestFirst = proposal.chargeRefs.reversed().map { eligible[$0] }
                let account = newestFirst.lazy.compactMap(\.account)
                    .first { !$0.isArchived && !$0.isSystemAccount }
                let subcategory = newestFirst.lazy.compactMap(\.subcategory).first
                return Item(proposal: proposal, account: account, subcategory: subcategory)
            }
    }

    /// ¿Puede este registro ser el cobro de un pago fijo?
    static func isCandidate(_ tx: TransactionItem, existingPaymentIDs: Set<String>) -> Bool {
        // Un gasto es negativo; uno positivo en una categoría de gasto es una devolución, no un cobro.
        guard !tx.isDeleted, tx.amount < 0 else { return false }
        guard let note = tx.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard tx.transferPairID == nil, tx.balanceAdjustmentType == nil else { return false }
        guard tx.splitGroupZoneID == nil, tx.splitExpenseID == nil, tx.splitSettlementID == nil else { return false }
        if let paymentID = tx.scheduledPaymentID, existingPaymentIDs.contains(paymentID) { return false }
        return !TransactionClassificationLogic.isIncome(tx)
    }
}
