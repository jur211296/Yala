//
//  ChatGuidedCreator.swift
//  Yala
//
//  Lo que guarda un guiado de Yala IA al tocar «Crear». Por los mismos ViewModels que los editores
//  (`BudgetEditorViewModel.saveBudget`, `ScheduledPaymentEditorViewModel.savePayment`), como Primeros pasos: mismos
//  datos, mismo aviso a los widgets y a la sincronización. Solo se llama desde la confirmación
//  (`ChatGuidedEngine.canCreate`).
//

import Foundation
import SwiftData

enum ChatGuidedCreationError: Error, Equatable {
    /// La confirmación no estaba completa.
    case incomplete
    /// El plan gratis ya tiene el máximo de presupuestos activos.
    case planLimitReached
    case notSaved
}

struct ChatGuidedCreation: Equatable {
    let id: UUID
    let name: String
    let dueDate: Date?
}

@MainActor
enum ChatGuidedCreator {

    static func create(_ state: ChatGuidedFlowState, data: ChatGuidedData, context: ModelContext,
                       budgetAlertsEnabled: Bool,
                       canCreateBudget: ((Int) -> Bool)? = nil)
        throws -> ChatGuidedCreation {
        let canCreateBudget = canCreateBudget ?? { FeatureGateService.shared.canCreate(.budgets, currentCount: $0) }
        guard ChatGuidedEngine.canCreate(state) else { throw ChatGuidedCreationError.incomplete }
        switch state.kind {
        case .budget:
            return try createBudget(state.answers, data: data, context: context, alertsEnabled: budgetAlertsEnabled,
                                    canCreateBudget: canCreateBudget)
        case .scheduledPayment:
            return try createPayment(state.answers, data: data, context: context)
        }
    }

    // MARK: - Presupuesto

    /// El nombre que se propone: el de la categoría, «A y B», o «Todos mis gastos».
    static func suggestedBudgetName(_ answers: ChatGuidedAnswers, data: ChatGuidedData) -> String {
        if let name = answers.budgetName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        typealias T = L10n.PrimerosPasos23.Budget
        return FirstBudgetFlowLogic.suggestedName(
            scope: answers.allExpenses == true ? .all : .categories,
            categoryNames: answers.categoryIDs.compactMap { data.category($0)?.name },
            allExpenses: T.nameAllExpenses,
            joined: { T.nameJoined($0, $1) },
            fallback: T.nameFallback
        )
    }

    private static func createBudget(_ answers: ChatGuidedAnswers, data: ChatGuidedData, context: ModelContext,
                                     alertsEnabled: Bool, canCreateBudget: (Int) -> Bool) throws -> ChatGuidedCreation {
        guard let period = answers.period, let amount = answers.amount, let currency = answers.currencyCode,
              let periodType = BudgetPeriodType(rawValue: period.budgetPeriodRaw) else {
            throw ChatGuidedCreationError.incomplete
        }
        let active: Int
        do {
            active = try context.fetchCount(FetchDescriptor<Budget>(predicate: #Predicate { $0.isActive }))
        } catch {
            #if DEBUG
            print("ChatGuidedCreator: Error: counting active budgets: \(error)")
            #endif
            // Sin recuento no se sabe si cabe: no se crea por encima de un límite que no se pudo medir.
            throw ChatGuidedCreationError.notSaved
        }
        guard canCreateBudget(active) else { throw ChatGuidedCreationError.planLimitReached }

        let viewModel = BudgetEditorViewModel()
        viewModel.setContext(context, deletionService: EntityDeletionService.shared)
        let wanted = Set(data.budgetSubcategoryIDs(answers))
        let subcategoryPIDs = Set(viewModel.allSubcategories.filter { wanted.contains($0.shortcutID) }.map(\.persistentModelID))
        let name = suggestedBudgetName(answers, data: data)
        let alert: FirstBudgetFlowLogic.Alert = alertsEnabled ? .at75And100 : .none
        let now = Date.now
        guard let savedID = viewModel.saveBudget(
            existing: nil,
            name: name,
            limitAmount: amount,
            currencyCode: currency,
            periodType: periodType,
            startDate: now,
            endDate: now,
            isActive: true,
            selectedAccounts: [],
            selectedSubcategories: subcategoryPIDs,
            selectedTags: [],
            selectedNeeds: [],
            alertEnabled: alert.isEnabled,
            alertThresholds: alert.thresholds,
            includeSharedExpenses: true
        ), let budget = context.model(for: savedID) as? Budget else {
            throw ChatGuidedCreationError.notSaved
        }
        return ChatGuidedCreation(id: budget.id, name: budget.name, dueDate: nil)
    }

    // MARK: - Pago planificado

    private static func createPayment(_ answers: ChatGuidedAnswers, data: ChatGuidedData,
                                      context: ModelContext) throws -> ChatGuidedCreation {
        guard let amount = answers.amount, let frequency = answers.frequency,
              let name = answers.paymentName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            throw ChatGuidedCreationError.incomplete
        }
        let viewModel = ScheduledPaymentEditorViewModel()
        viewModel.setContext(context, deletionService: EntityDeletionService.shared)
        let account = answers.accountID.flatMap { id in viewModel.activeAccounts.first { $0.persistentModelID == id } }
        let subcategory = answers.subcategoryID.flatMap { context.model(for: $0) as? Subcategory }
        let calendar = Calendar.current
        let flow = frequency.flowFrequency
        let date = answers.date ?? .now
        guard let id = viewModel.savePayment(
            existing: nil,
            name: name,
            amount: amount,
            note: "",
            currencyCode: answers.currencyCode ?? account?.currencyCode ?? data.mainCurrency,
            transactionType: TransactionType.expense.rawValue,
            paymentCategory: answers.isSubscription ? .subscription : .recurring,
            account: account,
            subcategory: subcategory,
            selectedTags: [],
            isRecurring: flow.isRecurring,
            recurrenceType: flow.recurrenceType,
            recurrenceInterval: 1,
            paymentDate: calendar.startOfDay(for: flow == .once ? date : .now),
            dayOfMonth: flow == .monthly ? answers.dayOfMonth : nil,
            selectedWeekdays: flow == .weekly ? Set([answers.weekday ?? 2]) : [],
            yearlyMonth: flow == .yearly ? calendar.component(.month, from: date) : nil,
            yearlyDay: flow == .yearly ? calendar.component(.day, from: date) : nil,
            endDate: nil,
            // El aviso por defecto del editor de pagos: «3 días antes» (sin pedir permisos desde el chat).
            notifyOnDueDate: FirstScheduledPaymentFlowLogic.Reminder.threeDaysBefore.notifyOnDueDate,
            notifyDaysBefore: FirstScheduledPaymentFlowLogic.Reminder.threeDaysBefore.notifyDaysBefore,
            isActive: true,
            isVariableAmount: answers.isVariableAmount
        ) else {
            throw ChatGuidedCreationError.notSaved
        }
        let descriptor = FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == id })
        guard let payment = try context.fetch(descriptor).first else { throw ChatGuidedCreationError.notSaved }
        return ChatGuidedCreation(id: payment.id, name: payment.name, dueDate: payment.nextDueDate)
    }
}
