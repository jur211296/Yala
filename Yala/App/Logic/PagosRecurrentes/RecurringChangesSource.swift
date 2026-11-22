//
//  RecurringChangesSource.swift
//  Yala
//
//  Puente entre el almacén y `RecurringPaymentChanges` (lote S2): lee los pagos planificados y los cobros recientes y
//  devuelve los avisos de precio y de baja con su pago. A diferencia de S1, cuenta también los cobros que se apuntaron
//  desde el propio pago (`scheduledPaymentID`): son justo los que dicen cuánto costó de verdad.
//
//  Fuera: ingresos, devoluciones, transferencias y ajustes, gastos y liquidaciones de grupo, importe cero, lo fechado en
//  el futuro, y los pagos de grupo o de ingreso. Nada se modifica aquí: lo hace quien contesta el aviso.
//

import Foundation
import Observation
import SwiftData

@MainActor
enum RecurringChangesSource {

    struct Item: Identifiable {
        let change: RecurringPaymentChanges.Change
        let payment: ScheduledPayment
        var id: String { change.id }

        /// El pago si sigue vivo: la lista se guarda entre recargas y pudo borrarse con la página oculta.
        var livePayment: ScheduledPayment? { payment.isDeleted || payment.modelContext == nil ? nil : payment }
    }

    static func load(context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws -> [Item] {
        let payments = try context.fetch(FetchDescriptor<ScheduledPayment>())
            .filter { $0.isActive && $0.isRecurring && !$0.isGroupPayment && $0.type == .expense }
        guard !payments.isEmpty else { return [] }

        let cutoff = calendar.date(
            byAdding: .day, value: -RecurringProposalsSource.lookbackDays, to: calendar.startOfDay(for: now)) ?? now
        let transactions = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.date >= cutoff && $0.date <= now }
        ))
        let charges = transactions.filter(isCharge).map { tx in
            RecurringPaymentChanges.Charge(
                date: tx.date, amount: abs(tx.amount), currencyCode: tx.currencyCode, name: tx.note ?? "",
                scheduledPaymentID: tx.scheduledPaymentID)
        }
        let planned = payments.map { payment in
            RecurringPaymentChanges.Planned(
                id: payment.id.uuidString, name: payment.name, storedBrandID: payment.brandLogoID,
                amount: payment.amount, currencyCode: payment.currencyCode, isVariableAmount: payment.isVariableAmount,
                recurrenceType: payment.recurrenceType, recurrenceInterval: payment.recurrenceInterval,
                isActive: payment.isActive, isRecurring: payment.isRecurring, createdAt: payment.createdAt,
                lastPaidDate: payment.lastPaidDate)
        }
        let byID = Dictionary(payments.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { first, _ in first })
        return RecurringPaymentChanges.detect(planned: planned, charges: charges, now: now, calendar: calendar)
            .compactMap { change in byID[change.paymentID].map { Item(change: change, payment: $0) } }
    }

    /// ¿Puede este registro ser un cobro de un pago fijo? Como S1, pero sin excluir lo que generó un pago planificado.
    static func isCharge(_ tx: TransactionItem) -> Bool {
        guard !tx.isDeleted, tx.amount < 0 else { return false }
        let hasName = !(tx.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasName || tx.scheduledPaymentID != nil else { return false }
        guard tx.transferPairID == nil, tx.balanceAdjustmentType == nil else { return false }
        guard tx.splitGroupZoneID == nil, tx.splitExpenseID == nil, tx.splitSettlementID == nil else { return false }
        return !TransactionClassificationLogic.isIncome(tx)
    }
}

/// Lo que la persona contestó a los avisos de S2, en ESTE dispositivo (como las propuestas de S1, decisión S3). Se
/// guarda la marca del aviso (`Change.token`): «Dejar así» calla ese precio, no los siguientes; «Sigue activo» calla esa
/// baja hasta que llegue otro cobro.
@MainActor
@Observable
final class RecurringChangePreferences {

    static let shared = RecurringChangePreferences()

    static let dismissedKey = "recurringChanges.dismissed"

    private let defaults: UserDefaults
    /// Id del pago → marca del aviso contestado.
    private(set) var dismissed: [String: String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        dismissed = (defaults.dictionary(forKey: Self.dismissedKey) as? [String: String]) ?? [:]
    }

    func isVisible(_ change: RecurringPaymentChanges.Change) -> Bool {
        dismissed[change.paymentID] != change.token
    }

    func dismiss(_ change: RecurringPaymentChanges.Change) {
        dismissed[change.paymentID] = change.token
        defaults.set(dismissed, forKey: Self.dismissedKey)
    }
}
