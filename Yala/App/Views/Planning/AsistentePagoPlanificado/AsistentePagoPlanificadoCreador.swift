//
//  AsistentePagoPlanificadoCreador.swift
//  Yala
//
//  Crea el pago con lo respondido en el asistente de «Nuevo pago planificado», por el mismo ViewModel que el
//  formulario. Hasta el 21-nov el asistente guardaba por el camino de Primeros pasos (`PrimerosPasosPlanningCreator`),
//  que no conoce lo compartido ni «¿Algo más?»; esto es ese mismo guardado con las dos cosas: lo que no se respondió
//  queda igual que allí (la última cuenta usada, sin nota, activo).
//

import Foundation
import SwiftData

@MainActor
enum AsistentePagoPlanificadoCreador {

    // swiftlint:disable:next function_parameter_count
    static func crear(
        _ draft: FirstScheduledPaymentDraft,
        monto: Double,
        compartido: ScheduledPaymentGroupPrefill?,
        miParte: Double,
        extras: ScheduledPaymentWizardExtras,
        defaultCurrencyCode: String,
        in context: ModelContext
    ) throws -> ScheduledPayment {
        let viewModel = ScheduledPaymentEditorViewModel()
        viewModel.setContext(context, deletionService: EntityDeletionService.shared)
        let account = cuenta(extras.accountID, moneda: compartido?.currencyCode, viewModel: viewModel, in: context)
        let subcategory = draft.subcategoryID.flatMap { context.model(for: $0) as? Subcategory }
        let calendar = Calendar.current
        let reminder = draft.reminder ?? .none
        let frequency = draft.frequency
        guard let id = viewModel.savePayment(
            existing: nil,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            // Compartido: se guarda tu parte; el total va en `splitTotalAmount` (como el formulario).
            amount: compartido == nil ? monto : miParte,
            note: extras.note.trimmingCharacters(in: .whitespacesAndNewlines),
            currencyCode: compartido?.currencyCode ?? account?.currencyCode ?? defaultCurrencyCode,
            transactionType: TransactionType.expense.rawValue,
            paymentCategory: draft.isSubscription ? .subscription : .recurring,
            account: account,
            subcategory: subcategory,
            selectedTags: compartido == nil ? extras.tagIDs : [],
            isRecurring: frequency.isRecurring,
            recurrenceType: frequency.recurrenceType,
            recurrenceInterval: 1,
            paymentDate: calendar.startOfDay(for: frequency == .once ? draft.date : .now),
            dayOfMonth: frequency == .monthly ? draft.dayOfMonth : nil,
            selectedWeekdays: frequency == .weekly ? [draft.weekday] : [],
            yearlyMonth: frequency == .yearly ? calendar.component(.month, from: draft.date) : nil,
            yearlyDay: frequency == .yearly ? calendar.component(.day, from: draft.date) : nil,
            endDate: frequency.isRecurring ? extras.endDate : nil,
            notifyOnDueDate: reminder.notifyOnDueDate,
            notifyDaysBefore: reminder.notifyDaysBefore,
            isActive: extras.isActive,
            isVariableAmount: draft.isVariableAmount,
            splitTotalAmount: compartido == nil ? nil : monto,
            groupZoneID: compartido?.groupZoneID,
            splitType: compartido?.splitType.rawValue,
            splitParticipantIDs: compartido?.participantIDs ?? [],
            splitValues: compartido?.values ?? [:]
        ) else {
            throw PrimerosPasosPlanningError.notSaved
        }
        let descriptor = FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == id })
        guard let payment = try context.fetch(descriptor).first else { throw PrimerosPasosPlanningError.notSaved }
        return payment
    }

    /// La cuenta elegida en «¿Algo más?» o, sin elegir, la última usada (la primera activa si no hay). En un pago
    /// compartido, solo una de la moneda del gasto: el formulario no deja otra.
    static func cuenta(
        _ elegida: PersistentIdentifier?, moneda: String?,
        viewModel: ScheduledPaymentEditorViewModel, in context: ModelContext
    ) -> Account? {
        if let elegida, let account = context.model(for: elegida) as? Account,
           moneda == nil || account.currencyCode == moneda {
            return account
        }
        let candidates = [viewModel.lastUsedAccount()].compactMap { $0 } + viewModel.activeAccounts
        guard let moneda else { return candidates.first }
        return candidates.first { $0.currencyCode == moneda }
    }
}
