//
//  Bienvenida23PasosPlanificacionGuardadoTests.swift
//  YalaTests
//
//  Lote 04 de la bienvenida 2.3 (docs/onboarding-2-3/SPEC.md): lo que guardan los pasos 3 y 4 (Y23-11 y Y23-12). En su
//  propio fichero porque pide `makeTestContext()` (una suite por fichero, `.claude/rules/testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Bienvenida 2.3 · pasos 3 y 4, lo que se guarda (Y23-11, Y23-12)", .serialized)
struct Bienvenida23PasosPlanificacionGuardadoTests {

    /// Ficha Y23-11: «El presupuesto guarda las subcategorías marcadas (subcategoryIDs) y el período elegido». Con aviso
    /// al 75 % y al 100 % y en el Panel (el widget).
    @Test func budget_savesTheMarkedSubcategories_thePeriod_theAlerts_andTheWidget() throws {
        let context = try makeTestContext()
        let food = makeTestCategory(context: context, name: "Alimentación")
        let market = makeTestSubcategory(context: context, name: "Mercado", category: food)
        let delivery = makeTestSubcategory(context: context, name: "Delivery", category: food)
        try context.save()

        var draft = FirstBudgetDraft(currencyCode: "PEN")
        draft.scope = .categories
        draft.subcategoryIDs = FirstBudgetFlowLogic.subcategoryIDs(
            scope: .categories, chosen: [[market.shortcutID, delivery.shortcutID]], removed: [delivery.shortcutID])
        draft.period = .weekly
        draft.limit = 600
        draft.name = "Alimentación"
        draft.alert = .at75And100
        draft.showsInPanel = true

        let budget = try PrimerosPasosPlanningCreator.createBudget(draft, in: context)
        #expect(budget.resolvedSubcategoryIDs() == [market.shortcutID])
        #expect(budget.periodType == BudgetPeriodType.weekly.rawValue)
        #expect(budget.limitAmount == 600)
        #expect(budget.name == "Alimentación")
        #expect(budget.alertEnabled)
        #expect(budget.alertThresholds == "75,100")
        #expect(budget.isFavorite)
        #expect(budget.isActive)
    }

    /// «Todos mis gastos», sin aviso y fuera del Panel: sin subcategorías, sin umbrales y sin widget.
    @Test func budget_allExpenses_noAlert_notInPanel() throws {
        let context = try makeTestContext()
        var draft = FirstBudgetDraft(currencyCode: "PEN")
        draft.scope = .all
        draft.period = .monthly
        draft.limit = 2000
        draft.name = "Mis gastos del mes"
        draft.alert = FirstBudgetFlowLogic.Alert.none
        draft.showsInPanel = false

        let budget = try PrimerosPasosPlanningCreator.createBudget(draft, in: context)
        #expect(budget.resolvedSubcategoryIDs() == nil)
        #expect(!budget.alertEnabled)
        #expect(budget.alertThresholds == nil)
        #expect(!budget.isFavorite)
    }

    /// Ficha Y23-12: «El pago se guarda con su subcategoría, monto (estimado o no), frecuencia, día y aviso».
    @Test func payment_savesSubcategory_estimatedAmount_frequency_day_andReminder() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Mi dinero", currencyCode: "PEN")
        let housing = makeTestCategory(context: context, name: "Hogar")
        let utilities = makeTestSubcategory(context: context, name: "Servicios del hogar", category: housing)
        try context.save()

        var draft = FirstScheduledPaymentDraft()
        draft.kind = .utilities
        draft.subcategoryID = utilities.persistentModelID
        draft.name = "Luz"
        draft.amount = 80
        draft.isVariableAmount = true
        draft.frequency = .monthly
        draft.dayOfMonth = 15
        draft.reminder = .threeDaysBefore

        let payment = try PrimerosPasosPlanningCreator.createScheduledPayment(draft, defaultCurrencyCode: "PEN", in: context)
        #expect(payment.name == "Luz")
        #expect(payment.amount == 80)
        #expect(payment.isVariableAmount)
        #expect(payment.subcategory?.persistentModelID == utilities.persistentModelID)
        #expect(payment.isRecurring)
        #expect(payment.recurrenceType == RecurrenceType.monthly.rawValue)
        #expect(payment.recurrenceInterval == 1)
        #expect(payment.dayOfMonth == 15)
        #expect(payment.notifyDaysBefore == 3)
        #expect(!payment.notifyOnDueDate)
        #expect(payment.account?.persistentModelID == account.persistentModelID)
        #expect(payment.currencyCode == "PEN")
        #expect(payment.paymentCategory == PaymentCategory.recurring.rawValue)
        #expect(Calendar.current.component(.day, from: payment.nextDueDate) == 15)
    }

    /// «Una vez», suscripción y aviso el mismo día: no se repite y vence en la fecha elegida.
    @Test func payment_once_subscription_sameDay() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context)
        try context.save()
        let date = Calendar.current.date(byAdding: .day, value: 6, to: Calendar.current.startOfDay(for: .now)) ?? .now

        var draft = FirstScheduledPaymentDraft()
        draft.name = "Curso"
        draft.amount = 350
        draft.isSubscription = true
        draft.frequency = .once
        draft.date = date
        draft.reminder = .sameDay

        let payment = try PrimerosPasosPlanningCreator.createScheduledPayment(draft, defaultCurrencyCode: "PEN", in: context)
        #expect(!payment.isRecurring)
        #expect(payment.nextDueDate == date)
        #expect(payment.notifyOnDueDate)
        #expect(payment.notifyDaysBefore == 0)
        #expect(payment.paymentCategory == PaymentCategory.subscription.rawValue)
    }

    /// Los seis tipos del paso 4 existen en el seed de categorías, cada uno una sola vez entre las subcategorías de gasto:
    /// así el flujo encuentra la subcategoría de la persona por su icono.
    @Test func payment_sixKinds_matchOneSeedSubcategoryEach() throws {
        let context = try makeTestContext()
        _ = seedDefaultCategoriesOnUserRequest(in: context)
        let expense = try context.fetch(FetchDescriptor<Subcategory>()).filter { $0.category?.isIncome == false }
        for kind in FirstScheduledPaymentFlowLogic.Kind.allCases {
            #expect(expense.count(where: { $0.iconName == kind.seedIcon }) == 1, "\(kind)")
        }
    }
}
