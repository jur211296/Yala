//
//  ChatGuidedMejorasCreationTests.swift
//  YalaTests
//
//  Mejoras de los guiados de Yala IA (encargo del 16-nov), con el almacén: las subcategorías se pueden quitar y la
//  frase que nombra una deja solo esa; el presupuesto de una sola vez se guarda con sus fechas; el pago «cada N» con su
//  intervalo; las opciones avanzadas se guardan si se contestan y, si no, quedan los valores de siempre; y los atajos
//  del saludo abren el guiado sin pasar por el servidor. En su propio fichero porque pide `makeTestContext()` (una suite
//  por fichero, `.claude/rules/testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Yala IA · guiados: subcategorías, una sola vez, cada N y opciones avanzadas en el almacén", .serialized)
struct ChatGuidedMejorasCreationTests {

    private func makeViewModel(_ context: ModelContext) -> ChatAssistantViewModel {
        let viewModel = ChatAssistantViewModel(
            defaults: makeIsolatedDefaults(), cloudExploreAvailable: { false }, isConnected: { true })
        viewModel.setContext(context, autoLoadSuggestions: false)
        return viewModel
    }

    private func guidedMessage(_ viewModel: ChatAssistantViewModel) throws -> (id: UUID, state: ChatGuidedFlowState) {
        let message = try #require(viewModel.messages.last)
        let state = try #require(viewModel.guidedState(messageID: message.id))
        return (message.id, state)
    }

    private func create(_ viewModel: ChatAssistantViewModel, _ messageID: UUID, _ kind: ChatGuidedKind,
                        context: ModelContext) -> String? {
        let data = ChatGuidedDataSource.load(kind, context: context, mainCurrency: CurrencyDefaults.currentPreferred)
        return viewModel.createGuided(messageID: messageID, data: data)
    }

    // MARK: - Subcategorías

    @Test func budget_removedSubcategories_areNotCounted() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: CurrencyDefaults.currentPreferred)
        let food = makeTestCategory(context: context, name: "Alimentación")
        let market = makeTestSubcategory(context: context, name: "Mercado", category: food)
        let restaurants = makeTestSubcategory(context: context, name: "Restaurantes", category: food)
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("Quiero un presupuesto de 400 al mes para alimentación")
        var (messageID, state) = try guidedMessage(viewModel)
        #expect(state.step == .subcategories, "Nombró la categoría: se ofrece quitar subcategorías.")

        viewModel.answerGuided(messageID: messageID, clearing: [.subcategories]) {
            $0.removedSubcategoryIDs = [restaurants.shortcutID]
        }
        state = try guidedMessage(viewModel).state
        if state.step == .currency {
            viewModel.answerGuided(messageID: messageID) { $0.currencyCode = CurrencyDefaults.currentPreferred }
        }
        viewModel.guidedAdvanced(messageID: messageID, wants: false)
        #expect(try guidedMessage(viewModel).state.step == .confirm)
        #expect(create(viewModel, messageID, .budget, context: context) == nil)

        let budget = try #require(try context.fetch(FetchDescriptor<Budget>()).first)
        #expect(budget.resolvedSubcategoryIDs() == [market.shortcutID], "Restaurantes se quitó: no cuenta.")
    }

    @Test func budget_namingASubcategory_keepsOnlyThatOne_andDoesNotAsk() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: CurrencyDefaults.currentPreferred)
        let transport = makeTestCategory(context: context, name: "Movilidad")
        let taxi = makeTestSubcategory(context: context, name: "Taxi", category: transport)
        let bus = makeTestSubcategory(context: context, name: "Bus", category: transport)
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("quiero un presupuesto de 200 al mes para taxi")
        let (_, state) = try guidedMessage(viewModel)
        #expect(state.answers.categoryIDs == [transport.persistentModelID])
        #expect(state.answers.removedSubcategoryIDs == [bus.shortcutID])
        #expect(state.prefilled.contains(.subcategories), "Sale en la confirmación como «Lo dijiste tú».")
        #expect(state.step != .subcategories, "No se vuelve a preguntar.")
        #expect(!(state.answers.removedSubcategoryIDs ?? []).contains(taxi.shortcutID))
    }

    @Test func payment_namingASubcategory_fillsTheCategory() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: "PEN")
        let home = makeTestCategory(context: context, name: "Hogar")
        let light = makeTestSubcategory(context: context, name: "Luz", category: home)
        _ = makeTestSubcategory(context: context, name: "Agua", category: home)
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("recuérdame pagar la luz el 10 de cada mes, son 90")
        let (_, state) = try guidedMessage(viewModel)
        #expect(state.kind == .scheduledPayment)
        #expect(state.answers.subcategoryID == light.persistentModelID)
        #expect(state.prefilled.contains(.subcategories))
    }

    // MARK: - Una sola vez y cada N

    @Test func oneTimeBudget_isSaved_withItsDates() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: CurrencyDefaults.currentPreferred)
        try context.save()
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 12, day: 20)) ?? .now
        let end = calendar.date(from: DateComponents(year: 2027, month: 1, day: 5)) ?? .now

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("quiero un presupuesto de una sola vez de 3000 para todos mis gastos")
        var (messageID, state) = try guidedMessage(viewModel)
        #expect(state.step == .dates)
        viewModel.answerGuided(messageID: messageID) {
            $0.budgetStart = start
            $0.budgetEnd = end
        }
        state = try guidedMessage(viewModel).state
        if state.step == .currency {
            viewModel.answerGuided(messageID: messageID) { $0.currencyCode = CurrencyDefaults.currentPreferred }
        }
        viewModel.guidedAdvanced(messageID: messageID, wants: false)
        #expect(create(viewModel, messageID, .budget, context: context) == nil)

        let budget = try #require(try context.fetch(FetchDescriptor<Budget>()).first)
        #expect(budget.periodType == BudgetPeriodType.unique.rawValue)
        #expect(budget.startDate.map { calendar.isDate($0, inSameDayAs: start) } == true)
        #expect(budget.endDate.map { calendar.isDate($0, inSameDayAs: end) } == true)
        #expect(budget.limitAmount == 3000)
    }

    @Test func everyTwoWeeks_isSaved_withItsInterval() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: "PEN")
        let home = makeTestCategory(context: context, name: "Hogar")
        let cleaning = makeTestSubcategory(context: context, name: "Limpieza", category: home)
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("nuevo pago fijo de ochenta cada dos semanas")
        var (messageID, state) = try guidedMessage(viewModel)
        #expect(state.answers.amount == 80)
        #expect(state.answers.frequency == .weekly)
        #expect(state.answers.interval == 2)
        viewModel.answerGuided(messageID: messageID) { $0.paymentName = "Limpieza" }
        viewModel.answerGuided(messageID: messageID) { $0.weekday = 6 }
        viewModel.answerGuided(messageID: messageID) { $0.subcategoryID = cleaning.persistentModelID }
        state = try guidedMessage(viewModel).state
        if state.step == .currency {
            viewModel.answerGuided(messageID: messageID) { $0.currencyCode = "PEN" }
        }
        viewModel.guidedAdvanced(messageID: messageID, wants: false)
        #expect(try guidedMessage(viewModel).state.step == .confirm)
        #expect(create(viewModel, messageID, .scheduledPayment, context: context) == nil)

        let payment = try #require(try context.fetch(FetchDescriptor<ScheduledPayment>()).first)
        #expect(payment.recurrenceType == RecurrenceType.weekly.rawValue)
        #expect(payment.recurrenceInterval == 2)
        #expect(payment.selectedWeekdays == "6")
        #expect(payment.amount == 80)
    }

    @Test func everyFifteenDays_isSaved_asDaily_fromTheStartDate() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: "PEN")
        let home = makeTestCategory(context: context, name: "Hogar")
        let water = makeTestSubcategory(context: context, name: "Agua", category: home)
        try context.save()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 3, to: .now) ?? .now)

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("anota un pago fijo de 25 cada 15 días")
        let (messageID, state) = try guidedMessage(viewModel)
        #expect(state.answers.frequency == .daily)
        #expect(state.answers.interval == 15)
        viewModel.answerGuided(messageID: messageID) { $0.paymentName = "Bidones" }
        viewModel.answerGuided(messageID: messageID) { $0.date = start }
        viewModel.answerGuided(messageID: messageID) { $0.subcategoryID = water.persistentModelID }
        if try guidedMessage(viewModel).state.step == .currency {
            viewModel.answerGuided(messageID: messageID) { $0.currencyCode = "PEN" }
        }
        viewModel.guidedAdvanced(messageID: messageID, wants: false)
        #expect(create(viewModel, messageID, .scheduledPayment, context: context) == nil)

        let payment = try #require(try context.fetch(FetchDescriptor<ScheduledPayment>()).first)
        #expect(payment.recurrenceType == RecurrenceType.daily.rawValue)
        #expect(payment.recurrenceInterval == 15)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: start), "Empieza el día elegido.")
    }

    // MARK: - Opciones avanzadas

    @Test func budget_advancedAnswers_areSaved() async throws {
        let context = try makeTestContext()
        let cash = makeTestAccount(context: context, name: "Efectivo", currencyCode: CurrencyDefaults.currentPreferred)
        _ = makeTestAccount(context: context, name: "Banco", currencyCode: CurrencyDefaults.currentPreferred)
        let trip = makeTestTag(context: context, name: "Viaje")
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("quiero un presupuesto de 500 al mes para todos mis gastos")
        let (messageID, _) = try guidedMessage(viewModel)
        if try guidedMessage(viewModel).state.step == .currency {
            viewModel.answerGuided(messageID: messageID) { $0.currencyCode = CurrencyDefaults.currentPreferred }
        }
        viewModel.guidedAdvanced(messageID: messageID, wants: true)
        #expect(try guidedMessage(viewModel).state.step == .budgetName)
        viewModel.answerGuided(messageID: messageID) { $0.budgetName = "Mi mes" }
        viewModel.answerGuided(messageID: messageID) { $0.budgetAlert = .at100 }
        viewModel.answerGuided(messageID: messageID) { $0.accountIDs = [cash.persistentModelID] }
        #expect(try guidedMessage(viewModel).state.step == .budgetTags, "Hay etiquetas: se pregunta.")
        viewModel.answerGuided(messageID: messageID) { $0.tagIDs = [trip.persistentModelID] }
        // Sin grupos no se pregunta por los gastos de grupo: lo siguiente es el Panel.
        #expect(try guidedMessage(viewModel).state.step == .budgetPanel)
        viewModel.answerGuided(messageID: messageID) { _ in }
        #expect(try guidedMessage(viewModel).state.step == .confirm)
        #expect(create(viewModel, messageID, .budget, context: context) == nil)

        let budget = try #require(try context.fetch(FetchDescriptor<Budget>()).first)
        #expect(budget.name == "Mi mes")
        #expect(budget.alertEnabled)
        #expect(budget.alertThresholds == "100")
        #expect(budget.accounts?.map(\.persistentModelID) == [cash.persistentModelID])
        #expect(budget.tags?.map(\.persistentModelID) == [trip.persistentModelID])
        #expect(budget.includeSharedExpenses, "Lo que no se preguntó queda como siempre.")
    }

    @Test func budget_withoutAdvanced_keepsTheUsualValues() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: CurrencyDefaults.currentPreferred)
        _ = makeTestTag(context: context, name: "Viaje")
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("quiero un presupuesto de 500 al mes para todos mis gastos")
        let (messageID, _) = try guidedMessage(viewModel)
        if try guidedMessage(viewModel).state.step == .currency {
            viewModel.answerGuided(messageID: messageID) { $0.currencyCode = CurrencyDefaults.currentPreferred }
        }
        viewModel.guidedAdvanced(messageID: messageID, wants: false)
        #expect(create(viewModel, messageID, .budget, context: context) == nil)

        let budget = try #require(try context.fetch(FetchDescriptor<Budget>()).first)
        #expect((budget.accounts ?? []).isEmpty)
        #expect((budget.tags ?? []).isEmpty)
        #expect(budget.includeSharedExpenses)
        #expect(!budget.alertEnabled, "Con las alertas apagadas, sin avisos: el valor de siempre.")
    }

    @Test func payment_advancedAnswers_areSaved() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: "PEN")
        let home = makeTestCategory(context: context, name: "Hogar")
        let rent = makeTestSubcategory(context: context, name: "Renta", category: home)
        let fixed = makeTestTag(context: context, name: "Fijos")
        try context.save()
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: calendar.date(byAdding: .month, value: 10, to: .now) ?? .now)

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("recuérdame pagar el depa el 1 de cada mes, son 1500")
        let (messageID, _) = try guidedMessage(viewModel)
        viewModel.answerGuided(messageID: messageID) { $0.subcategoryID = rent.persistentModelID }
        if try guidedMessage(viewModel).state.step == .currency {
            viewModel.answerGuided(messageID: messageID) { $0.currencyCode = "PEN" }
        }
        viewModel.guidedAdvanced(messageID: messageID, wants: true)
        #expect(try guidedMessage(viewModel).state.step == .paymentSubscription)
        viewModel.answerGuided(messageID: messageID) { $0.isSubscription = false }
        viewModel.answerGuided(messageID: messageID) { $0.reminder = .oneDayBefore }
        viewModel.answerGuided(messageID: messageID) { $0.endDate = end }
        viewModel.answerGuided(messageID: messageID) { $0.note = "Contrato 42" }
        viewModel.answerGuided(messageID: messageID) { $0.tagIDs = [fixed.persistentModelID] }
        viewModel.answerGuided(messageID: messageID) { _ in }
        #expect(try guidedMessage(viewModel).state.step == .confirm)
        #expect(create(viewModel, messageID, .scheduledPayment, context: context) == nil)

        let payment = try #require(try context.fetch(FetchDescriptor<ScheduledPayment>()).first)
        #expect(payment.notifyDaysBefore == 1)
        #expect(payment.endDate.map { calendar.isDate($0, inSameDayAs: end) } == true)
        #expect(payment.note == "Contrato 42")
        #expect(payment.tags?.map(\.persistentModelID) == [fixed.persistentModelID])
        #expect(payment.paymentCategory == PaymentCategory.recurring.rawValue)
    }

    @Test func payment_withoutAdvanced_remindsThreeDaysBefore() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: "PEN")
        let home = makeTestCategory(context: context, name: "Hogar")
        let rent = makeTestSubcategory(context: context, name: "Renta", category: home)
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("recuérdame pagar el depa el 1 de cada mes, son 1500")
        let (messageID, _) = try guidedMessage(viewModel)
        viewModel.answerGuided(messageID: messageID) { $0.subcategoryID = rent.persistentModelID }
        if try guidedMessage(viewModel).state.step == .currency {
            viewModel.answerGuided(messageID: messageID) { $0.currencyCode = "PEN" }
        }
        viewModel.guidedAdvanced(messageID: messageID, wants: false)
        #expect(create(viewModel, messageID, .scheduledPayment, context: context) == nil)
        let payment = try #require(try context.fetch(FetchDescriptor<ScheduledPayment>()).first)
        #expect(payment.notifyDaysBefore == 3)
        #expect(payment.endDate == nil)
        #expect((payment.note ?? "").isEmpty)
    }

    // MARK: - Permiso de la nube

    /// Con el camino ampliado de la nube disponible y sin su permiso, un pedido de guiado abre la tarjeta y no el permiso:
    /// el guiado no manda nada al servidor. Una pregunta normal sí lo pide (control).
    @Test func guidedRequest_doesNotAskTheCloudExploreConsent() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: CurrencyDefaults.currentPreferred)
        try context.save()
        let viewModel = ChatAssistantViewModel(
            defaults: makeIsolatedDefaults(), cloudExploreAvailable: { true }, isConnected: { true })
        viewModel.setContext(context, autoLoadSuggestions: false)

        await viewModel.sendQuestion("quiero crear un presupuesto")
        #expect(!viewModel.showsCloudExploreConsent)
        #expect(try guidedMessage(viewModel).state.kind == .budget)

        await viewModel.sendQuestion("¿cuánto gasté este mes?")
        #expect(viewModel.showsCloudExploreConsent, "Control: una pregunta sí pide el permiso de la nube.")
    }

    // MARK: - Saludo

    @Test func greetingShortcuts_openTheGuidedCard_withoutTheServer() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: CurrencyDefaults.currentPreferred)
        try context.save()
        let viewModel = makeViewModel(context)

        viewModel.startGuidedFlow(.budget)
        #expect(viewModel.messages.count == 2, "El pedido y la tarjeta, sin llamar a ningún modelo.")
        #expect(viewModel.messages.first?.role == .user)
        #expect(viewModel.messages.first?.text == L10n.IAGuiados.shortcutBudgetMessage)
        let budget = try guidedMessage(viewModel).state
        #expect(budget.kind == .budget)
        #expect(budget.step == .categories)
        #expect(budget.prefilled.isEmpty)

        viewModel.startGuidedFlow(.scheduledPayment)
        #expect(viewModel.messages.count == 4)
        #expect(try guidedMessage(viewModel).state.kind == .scheduledPayment)
    }

    @Test func greeting_saysItCreatesConversing() {
        #expect(L10n.IAGuiados.greeting != L10n.UXL14.greetingTwoUses)
        #expect(!L10n.IAGuiados.greeting.isEmpty)
        #expect(!L10n.IAGuiados.greetingCreateBudget.isEmpty)
        #expect(!L10n.IAGuiados.greetingCreatePayment.isEmpty)
    }
}
