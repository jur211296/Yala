//
//  Bienvenida23PasosPlanificacionTests.swift
//  YalaTests
//
//  Lote 04 de la bienvenida 2.3 (docs/onboarding-2-3/SPEC.md): las reglas de los pasos 3, 4 y 5 — el primer presupuesto
//  (Y23-11), el primer pago planificado (Y23-12) y Grupos con el estilo del tutorial (Y23-13) — y lo que cambia en el
//  Panel al decir «Sí, mostrarlo en el Panel». Lógica pura, sin contexto.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Bienvenida 2.3 · pasos 3, 4 y 5, las reglas (Y23-11 a Y23-13)")
struct Bienvenida23PasosPlanificacionTests {

    // MARK: - Y23-11 · Primer presupuesto

    @Test func budget_allExpenses_skipsTheCategoryQuestions() {
        #expect(FirstBudgetFlowLogic.steps(scope: .all, period: .monthly)
            == [.scope, .period, .limit, .name, .alert, .panel, .done])
    }

    @Test func budget_someCategories_asksWhichAndWhatNotToCount_andOnceAsksTheDates() {
        #expect(FirstBudgetFlowLogic.steps(scope: .categories, period: .unique)
            == [.scope, .categories, .subcategories, .period, .dates, .limit, .name, .alert, .panel, .done])
        #expect(FirstBudgetFlowLogic.next(after: .period, scope: .categories, period: .unique) == .dates)
        #expect(FirstBudgetFlowLogic.next(after: .period, scope: .categories, period: .weekly) == .limit)
    }

    @Test func budget_suggestedName_followsWhatWasChosen() {
        let name = { (scope: FirstBudgetFlowLogic.Scope?, names: [String]) in
            FirstBudgetFlowLogic.suggestedName(
                scope: scope, categoryNames: names, allExpenses: "Mis gastos del mes",
                joined: { "\($0) y \($1)" }, fallback: "Mi presupuesto")
        }
        #expect(name(.all, []) == "Mis gastos del mes")
        #expect(name(.categories, ["Alimentación"]) == "Alimentación")
        #expect(name(.categories, ["Alimentación", "Transporte", "Hogar"]) == "Alimentación y Transporte")
        #expect(name(.categories, []) == "Mi presupuesto")
    }

    /// Ficha: «El presupuesto guarda las subcategorías marcadas (subcategoryIDs)». Llegan todas marcadas; se quita lo que
    /// no entra.
    @Test func budget_savesTheMarkedSubcategories_withoutTheRemovedOnes() {
        let food = [UUID(), UUID(), UUID()]
        let transport = [UUID(), UUID()]
        let removed: Set<UUID> = [food[1]]
        let ids = FirstBudgetFlowLogic.subcategoryIDs(scope: .categories, chosen: [food, transport], removed: removed)
        #expect(ids == [food[0], food[2], transport[0], transport[1]])
        #expect(FirstBudgetFlowLogic.subcategoryIDs(scope: .all, chosen: [food], removed: []) == [])
    }

    /// Quitarlas todas dejaría un presupuesto sin filtro, que cuenta TODO: no se puede seguir.
    @Test func budget_cannotContinue_withEverySubcategoryRemoved() {
        let food = [UUID(), UUID()]
        #expect(!FirstBudgetFlowLogic.canContinueSubcategories(scope: .categories, chosen: [food], removed: Set(food)))
        #expect(FirstBudgetFlowLogic.canContinueSubcategories(scope: .categories, chosen: [food], removed: [food[0]]))
    }

    /// Ficha: «75 % y 100 % propuestos por defecto». El 50 % y el 90 % quedan en Editar.
    @Test func budget_alerts_propose75And100() {
        #expect(FirstBudgetFlowLogic.proposedAlert == .at75And100)
        #expect(FirstBudgetFlowLogic.Alert.at75And100.thresholds == [75, 100])
        #expect(FirstBudgetFlowLogic.Alert.at100.thresholds == [100])
        #expect(FirstBudgetFlowLogic.Alert.none.thresholds.isEmpty)
        #expect(!FirstBudgetFlowLogic.Alert.none.isEnabled)
    }

    @Test func budget_limit_mustBePositive() {
        #expect(FirstBudgetFlowLogic.isValidLimit(600))
        #expect(!FirstBudgetFlowLogic.isValidLimit(0))
        #expect(!FirstBudgetFlowLogic.isValidLimit(nil))
        #expect(!FirstBudgetFlowLogic.isValidLimit(.infinity))
    }

    // MARK: - Y23-12 · Primer pago planificado

    @Test func payment_sixKinds_withoutBrands_andTheirDefaults() {
        #expect(FirstScheduledPaymentFlowLogic.Kind.allCases.count == 6)
        // Cada tipo se encuentra por el icono de su subcategoría del seed: tienen que ser distintos.
        #expect(Set(FirstScheduledPaymentFlowLogic.Kind.allCases.map(\.seedIcon)).count == 6)
        let subscriptions = FirstScheduledPaymentFlowLogic.Kind.allCases.filter(\.isSubscription)
        #expect(subscriptions == [.utilitySubscription, .leisureSubscription])
        #expect(FirstScheduledPaymentFlowLogic.Kind.allCases.filter(\.isVariableAmount) == [.utilities])
    }

    @Test func payment_reminder_savesOneNotice_threeDaysBeforeByDefault() {
        typealias R = FirstScheduledPaymentFlowLogic.Reminder
        #expect(FirstScheduledPaymentFlowLogic.proposedReminder == .threeDaysBefore)
        #expect(R.threeDaysBefore.notifyDaysBefore == 3 && !R.threeDaysBefore.notifyOnDueDate)
        #expect(R.oneDayBefore.notifyDaysBefore == 1 && !R.oneDayBefore.notifyOnDueDate)
        #expect(R.sameDay.notifyDaysBefore == 0 && R.sameDay.notifyOnDueDate)
        #expect(R.none.notifyDaysBefore == 0 && !R.none.notifyOnDueDate && !R.none.wantsReminder)
    }

    @Test func payment_frequency_onceDoesNotRepeat() {
        #expect(!FirstScheduledPaymentFlowLogic.Frequency.once.isRecurring)
        #expect(FirstScheduledPaymentFlowLogic.Frequency.weekly.recurrenceType == .weekly)
        #expect(FirstScheduledPaymentFlowLogic.Frequency.yearly.recurrenceType == .yearly)
        #expect(FirstScheduledPaymentFlowLogic.steps == [.kind, .details, .when, .reminder, .panel, .done])
    }

    @Test func payment_details_needNameAndAmount() {
        #expect(FirstScheduledPaymentFlowLogic.canContinueDetails(name: "Luz", amount: 80))
        #expect(!FirstScheduledPaymentFlowLogic.canContinueDetails(name: "  ", amount: 80))
        #expect(!FirstScheduledPaymentFlowLogic.canContinueDetails(name: "Luz", amount: nil))
        #expect(FirstScheduledPaymentFlowLogic.isValidMonthDay(31))
        #expect(!FirstScheduledPaymentFlowLogic.isValidMonthDay(32))
    }

    // MARK: - Y23-13 · Grupos

    /// Ficha: «Con el flag en sí, el paso se salta».
    @Test func groups_alreadySeen_skipsTheTutorial() {
        #expect(GroupsTutorialLogic.entry(hasShownGroupsOnboarding: true) == .alreadySeen)
        #expect(GroupsTutorialLogic.entry(hasShownGroupsOnboarding: false) == .showTutorial)
    }

    /// Ficha: «en no, crea o se une y queda marcado». Omitir antes del consentimiento o volver atrás no lo marca.
    @Test func groups_exit_marksTheOnboardingSeen_unlessLeftBeforeTheEnd() {
        typealias E = GroupsTutorialLogic.Exit
        #expect(!GroupsTutorialLogic.marksOnboardingSeen(E.closed))
        #expect(!GroupsTutorialLogic.marksOnboardingSeen(E.skipped))
        #expect(GroupsTutorialLogic.marksOnboardingSeen(E.seenNotNow))
        #expect(GroupsTutorialLogic.marksOnboardingSeen(E.createGroup))
        #expect(GroupsTutorialLogic.marksOnboardingSeen(E.joinWithLink))
    }

    /// El mazo pasa al 6 en toda salida menos «Atrás» desde la primera parte; la guía de la pestaña, solo al ir a crear.
    @Test func groups_exit_advancesTheDeck_andOnlyCreatingShowsTheTabGuide() {
        typealias E = GroupsTutorialLogic.Exit
        #expect(!GroupsTutorialLogic.advancesDeck(E.closed))
        #expect([E.skipped, .seenNotNow, .createGroup, .joinWithLink].allSatisfy(GroupsTutorialLogic.advancesDeck))
        #expect(GroupsTutorialLogic.showsPlaceGuide(E.createGroup))
        #expect(![E.closed, .skipped, .seenNotNow, .joinWithLink].contains(where: GroupsTutorialLogic.showsPlaceGuide))
    }

    // MARK: - «¿Lo ponemos en tu Panel?»

    /// Al terminar el paso 2 la sección Planificación está oculta: decir que sí la abre con SOLO ese widget.
    @Test func panel_hiddenPlanning_opensWithOnlyThatWidget() {
        let change = PrimerosPasosPanelWidgetLogic.show(
            .budgets,
            sectionsHidden: ["health", "tendencias", "planificacion"],
            planningHidden: [])
        #expect(change.sectionsHidden == ["health", "tendencias"])
        #expect(change.planningHidden == [WidgetType.scheduledPayments.rawValue])
    }

    /// Con la sección ya a la vista (el presupuesto ya se puso), el pago solo se suma: no oculta el presupuesto.
    @Test func panel_visiblePlanning_onlyAddsThatWidget() {
        let change = PrimerosPasosPanelWidgetLogic.show(
            .scheduledPayments,
            sectionsHidden: ["health"],
            planningHidden: [WidgetType.scheduledPayments.rawValue])
        #expect(change.sectionsHidden == ["health"])
        #expect(change.planningHidden.isEmpty)
    }
}
