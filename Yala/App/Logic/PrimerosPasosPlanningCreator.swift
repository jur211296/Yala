//
//  PrimerosPasosPlanningCreator.swift
//  Yala
//
//  Lo que guardan los pasos 3 y 4 de Primeros pasos 2.3 (Y23-11, Y23-12) y lo que cambian en el Panel. Guardan por los
//  mismos ViewModels que los editores (`BudgetEditorViewModel.saveBudget`, `ScheduledPaymentEditorViewModel.savePayment`):
//  mismos datos, mismo aviso a los widgets y a la sincronización, sin un camino de guardado propio.
//

import Foundation
import SwiftData

/// Lo que contestó la persona en el paso 3.
struct FirstBudgetDraft: Equatable {
    var scope: FirstBudgetFlowLogic.Scope?
    /// Las subcategorías que cuenta (`Subcategory.shortcutID`). Vacío con «Todos mis gastos».
    var subcategoryIDs: [UUID] = []
    var period: BudgetPeriodType?
    var startDate: Date = .now
    var endDate: Date = .now
    var limit: Double?
    var name: String = ""
    var alert: FirstBudgetFlowLogic.Alert?
    var showsInPanel: Bool?
    var currencyCode: String
}

/// Lo que contestó la persona en el paso 4.
struct FirstScheduledPaymentDraft: Equatable {
    var kind: FirstScheduledPaymentFlowLogic.Kind?
    /// La subcategoría elegida (de los seis tipos o de «Otra subcategoría»).
    var subcategoryID: PersistentIdentifier?
    var name: String = ""
    var amount: Double?
    var isVariableAmount = false
    var isSubscription = false
    var frequency: FirstScheduledPaymentFlowLogic.Frequency = .monthly
    var dayOfMonth = 1
    /// Día de la semana del calendario (1 = domingo).
    var weekday = 2
    /// La fecha de «Cada año» y de «Una vez».
    var date: Date = .now
    var reminder: FirstScheduledPaymentFlowLogic.Reminder?
    var showsInPanel: Bool?
}

enum PrimerosPasosPlanningError: Error {
    case notSaved
}

@MainActor
enum PrimerosPasosPlanningCreator {

    // MARK: - Paso 3

    /// Guarda el presupuesto. «Mostrar en el widget» si dijo que sí al Panel.
    @discardableResult
    static func createBudget(_ draft: FirstBudgetDraft, in context: ModelContext) throws -> Budget {
        guard let period = draft.period, let limit = draft.limit else { throw PrimerosPasosPlanningError.notSaved }
        let viewModel = BudgetEditorViewModel()
        viewModel.setContext(context, deletionService: EntityDeletionService.shared)
        let wanted = Set(draft.subcategoryIDs)
        let subcategoryPIDs = Set(viewModel.allSubcategories.filter { wanted.contains($0.shortcutID) }.map(\.persistentModelID))
        let alert = draft.alert ?? .none
        guard let savedID = viewModel.saveBudget(
            existing: nil,
            name: draft.name,
            limitAmount: limit,
            currencyCode: draft.currencyCode,
            periodType: period,
            startDate: draft.startDate,
            endDate: draft.endDate,
            isActive: true,
            selectedAccounts: [],
            selectedSubcategories: subcategoryPIDs,
            selectedTags: [],
            selectedNeeds: [],
            alertEnabled: alert.isEnabled,
            alertThresholds: alert.thresholds,
            includeSharedExpenses: true
        ), let budget = context.model(for: savedID) as? Budget else {
            throw PrimerosPasosPlanningError.notSaved
        }
        // El presupuesto ya está guardado: si falla lo del widget, no se devuelve error (reintentar crearía otro).
        if draft.showsInPanel == true {
            do {
                let active = try context.fetch(FetchDescriptor<Budget>(predicate: #Predicate { $0.isActive }))
                BudgetWidgetFavoriteLogic.setShownInWidget(true, for: budget, among: active)
                try context.save()
                WidgetDataCache.updateCache(context: context)
            } catch {
                #if DEBUG
                print("PrimerosPasosPlanningCreator: Error: showing the budget in the widget: \(error)")
                #endif
            }
        }
        return budget
    }

    // MARK: - Paso 4

    /// Guarda el pago planificado con la cuenta y la moneda que le tocan (las del editor: la última cuenta usada).
    @discardableResult
    static func createScheduledPayment(
        _ draft: FirstScheduledPaymentDraft,
        defaultCurrencyCode: String,
        in context: ModelContext
    ) throws -> ScheduledPayment {
        guard let amount = draft.amount else { throw PrimerosPasosPlanningError.notSaved }
        let viewModel = ScheduledPaymentEditorViewModel()
        viewModel.setContext(context, deletionService: EntityDeletionService.shared)
        let account = viewModel.lastUsedAccount() ?? viewModel.activeAccounts.first
        let subcategory = draft.subcategoryID.flatMap { context.model(for: $0) as? Subcategory }
        let calendar = Calendar.current
        let reminder = draft.reminder ?? .none
        let frequency = draft.frequency
        guard let id = viewModel.savePayment(
            existing: nil,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            note: "",
            currencyCode: account?.currencyCode ?? defaultCurrencyCode,
            transactionType: TransactionType.expense.rawValue,
            paymentCategory: draft.isSubscription ? .subscription : .recurring,
            account: account,
            subcategory: subcategory,
            selectedTags: [],
            isRecurring: frequency.isRecurring,
            recurrenceType: frequency.recurrenceType,
            recurrenceInterval: 1,
            paymentDate: calendar.startOfDay(for: frequency == .once ? draft.date : .now),
            dayOfMonth: frequency == .monthly ? draft.dayOfMonth : nil,
            selectedWeekdays: frequency == .weekly ? [draft.weekday] : [],
            yearlyMonth: frequency == .yearly ? calendar.component(.month, from: draft.date) : nil,
            yearlyDay: frequency == .yearly ? calendar.component(.day, from: draft.date) : nil,
            endDate: nil,
            notifyOnDueDate: reminder.notifyOnDueDate,
            notifyDaysBefore: reminder.notifyDaysBefore,
            isActive: true,
            isVariableAmount: draft.isVariableAmount
        ) else {
            throw PrimerosPasosPlanningError.notSaved
        }
        let descriptor = FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == id })
        guard let payment = try context.fetch(descriptor).first else { throw PrimerosPasosPlanningError.notSaved }
        return payment
    }

    // MARK: - Panel

    /// «Sí, mostrarlo en el Panel»: la sección Planificación con este widget (`PrimerosPasosPanelWidgetLogic`).
    static func showInPanel(_ widget: WidgetType, preferences: AppPreferences) {
        preferences.materializePanelDefaultsIfNeeded()
        let change = PrimerosPasosPanelWidgetLogic.show(
            widget,
            sectionsHidden: preferences.panelSectionsHidden,
            planningHidden: preferences.hidden(for: .planificacion)
        )
        preferences.setHidden(change.planningHidden, for: .planificacion)
        preferences.panelSectionsHidden = change.sectionsHidden
    }
}
