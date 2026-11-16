//
//  ChatGuidedCreationTests.swift
//  YalaTests
//
//  Guiados de Yala IA con el almacén: la frase abre el guiado en el chat sin llamar a ningún modelo, las categorías se
//  reconocen por su nombre, el monto se propone con lo gastado de verdad, nada se crea sin la confirmación y, con ella,
//  el presupuesto y el pago se guardan por los mismos ViewModels que los editores. En su propio fichero porque pide
//  `makeTestContext()` (una suite por fichero, `.claude/rules/testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Yala IA · guiados: del chat a lo creado", .serialized)
struct ChatGuidedCreationTests {

    /// Un mes cerrado de referencia, a mitad: el «ahora» del test no es el reloj.
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12)) ?? .now

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

    // MARK: - Intención y relleno

    @Test func budgetSentence_opensTheGuidedCard_withTheNamedCategory() async throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, currencyCode: CurrencyDefaults.currentPreferred)
        let food = makeTestCategory(context: context, name: "Alimentación")
        let market = makeTestSubcategory(context: context, name: "Mercado", category: food)
        let transport = makeTestCategory(context: context, name: "Transporte")
        _ = makeTestSubcategory(context: context, name: "Taxi", category: transport)
        _ = makeTestTransaction(context: context, amount: -20, account: account, category: food, subcategory: market)
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("Quiero un presupuesto de 300 al mes para alimentación")

        #expect(viewModel.messages.count == 2, "La frase y la respuesta con la tarjeta: sin llamar al servidor.")
        let (_, state) = try guidedMessage(viewModel)
        #expect(state.kind == .budget)
        #expect(state.answers.categoryIDs == [food.persistentModelID])
        #expect(state.answers.amount == 300)
        #expect(state.answers.period == .monthly)
        #expect(state.prefilled.isSuperset(of: [.categories, .amount, .period]))
        #expect(state.step == .confirm, "Lo dijo todo: va directo a revisar.")
        #expect(viewModel.allTurns.count == 1, "El turno entra en el historial del día.")
    }

    @Test func aQuestion_doesNotOpenTheGuidedCard() async throws {
        let context = try makeTestContext()
        let viewModel = makeViewModel(context)
        #expect(!viewModel.startGuidedFlowIfAsked("¿cuánto gasté en comida este mes?", context: context))
        #expect(viewModel.messages.isEmpty)
    }

    // MARK: - Monto sugerido

    @Test func suggestedAmount_comesFromTheRealSpending_ofTheLastClosedMonths() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, currencyCode: "PEN")
        let food = makeTestCategory(context: context, name: "Alimentación")
        let market = makeTestSubcategory(context: context, name: "Mercado", category: food)
        let other = makeTestCategory(context: context, name: "Ocio")
        let cinema = makeTestSubcategory(context: context, name: "Cine", category: other)
        let calendar = Calendar.current
        func day(_ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)) ?? now
        }
        // Marzo 300, abril 500, mayo 400 en Mercado; junio (el mes en curso) no cuenta; Cine no es de esta categoría.
        for (month, amount) in [(3, 300.0), (4, 500.0), (5, 400.0), (6, 999.0)] {
            _ = makeTestTransaction(context: context, amount: -amount, date: day(month, 10), account: account,
                                    category: food, subcategory: market, currencyCode: "PEN")
        }
        _ = makeTestTransaction(context: context, amount: -1000, date: day(5, 3), account: account,
                                category: other, subcategory: cinema, currencyCode: "PEN")
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<TransactionItem>())
        let average = ChatGuidedSpending.monthlyAverage(
            subcategoryIDs: [market.shortcutID], currencyCode: "PEN", transactions: transactions, now: now)
        #expect(average == 400)
        let suggested = try #require(ChatGuidedSpending.suggestions(monthlyAverage: average, period: .monthly))
        #expect(suggested.usual == 400)
        #expect(suggested.saving == 360)
    }

    // MARK: - Confirmación obligatoria y creación

    @Test func budget_isNotCreated_beforeTheConfirmation_andIsCreatedAfterIt() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: CurrencyDefaults.currentPreferred)
        let food = makeTestCategory(context: context, name: "Alimentación")
        let market = makeTestSubcategory(context: context, name: "Mercado", category: food)
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("quiero crear un presupuesto")
        var (messageID, state) = try guidedMessage(viewModel)
        #expect(state.step == .categories)

        let data = ChatGuidedDataSource.load(.budget, context: context, mainCurrency: CurrencyDefaults.currentPreferred)
        #expect(viewModel.createGuided(messageID: messageID, data: data) != nil, "Sin confirmar no se crea.")
        #expect(try context.fetchCount(FetchDescriptor<Budget>()) == 0)

        viewModel.answerGuided(messageID: messageID) {
            $0.allExpenses = false
            $0.categoryIDs = [food.persistentModelID]
        }
        viewModel.answerGuided(messageID: messageID) { $0.period = .weekly }
        viewModel.answerGuided(messageID: messageID) { $0.amount = 150 }
        state = try guidedMessage(viewModel).state
        if state.step == .currency {
            viewModel.answerGuided(messageID: messageID) { $0.currencyCode = CurrencyDefaults.currentPreferred }
        }
        state = try guidedMessage(viewModel).state
        #expect(state.step == .confirm)

        #expect(viewModel.createGuided(messageID: messageID, data: data) == nil)
        let budget = try #require(try context.fetch(FetchDescriptor<Budget>()).first)
        #expect(budget.resolvedSubcategoryIDs() == [market.shortcutID])
        #expect(budget.periodType == BudgetPeriodType.weekly.rawValue)
        #expect(budget.limitAmount == 150)
        #expect(budget.name == "Alimentación")
        #expect(budget.isActive)

        let done = try guidedMessage(viewModel).state
        #expect(done.status == .created)
        #expect(done.createdID == budget.id)
        #expect(viewModel.createGuided(messageID: messageID, data: data) != nil, "Dos toques no crean dos.")
        #expect(try context.fetchCount(FetchDescriptor<Budget>()) == 1)
    }

    @Test func budget_respectsTheFreePlanLimit() throws {
        let context = try makeTestContext()
        var answers = ChatGuidedAnswers()
        answers.allExpenses = true
        answers.period = .monthly
        answers.amount = 100
        answers.currencyCode = "PEN"
        let state = ChatGuidedEngine.start(.budget, answers: answers)
        let data = ChatGuidedData(mainCurrency: "PEN")
        #expect(throws: ChatGuidedCreationError.planLimitReached) {
            try ChatGuidedCreator.create(state, data: data, context: context, budgetAlertsEnabled: false,
                                         canCreateBudget: { _ in false })
        }
        #expect(try context.fetchCount(FetchDescriptor<Budget>()) == 0)
    }

    @Test func payment_isCreated_withTheChosenAccountCategoryAndDay() async throws {
        let context = try makeTestContext()
        let cash = makeTestAccount(context: context, name: "Efectivo", currencyCode: "PEN")
        let card = makeTestAccount(context: context, name: "Tarjeta", currencyCode: "USD")
        let home = makeTestCategory(context: context, name: "Hogar")
        let rent = makeTestSubcategory(context: context, name: "Renta", category: home)
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("recuérdame pagar el alquiler el 5 de cada mes, son 1200 soles")
        let (messageID, start) = try guidedMessage(viewModel)
        #expect(start.kind == .scheduledPayment)
        #expect(start.answers.paymentName == "Alquiler")
        #expect(start.answers.dayOfMonth == 5)
        #expect(start.answers.suggestionKey == "", "Con el nombre dicho, no se ofrecen cobros de los registros.")
        #expect(start.step == .account, "Hay dos cuentas: es lo primero que falta.")

        viewModel.answerGuided(messageID: messageID) {
            $0.accountID = card.persistentModelID
        }
        viewModel.answerGuided(messageID: messageID) { $0.subcategoryID = rent.persistentModelID }
        let state = try guidedMessage(viewModel).state
        #expect(state.step == .confirm)

        let data = ChatGuidedDataSource.load(.scheduledPayment, context: context, mainCurrency: "PEN")
        #expect(viewModel.createGuided(messageID: messageID, data: data) == nil)
        let payment = try #require(try context.fetch(FetchDescriptor<ScheduledPayment>()).first)
        #expect(payment.name == "Alquiler")
        #expect(payment.amount == 1200)
        #expect(payment.currencyCode == "PEN", "La moneda dicha en la frase manda sobre la de la cuenta.")
        #expect(payment.account?.persistentModelID == card.persistentModelID)
        #expect(payment.account?.persistentModelID != cash.persistentModelID)
        #expect(payment.subcategory?.persistentModelID == rent.persistentModelID)
        #expect(payment.dayOfMonth == 5)
        #expect(payment.isRecurring)
        #expect(try guidedMessage(viewModel).state.status == .created)
    }

    @Test func cancel_createsNothing() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context)
        try context.save()
        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("nuevo pago fijo de 80")
        let (messageID, _) = try guidedMessage(viewModel)
        viewModel.guidedCancel(messageID: messageID)
        #expect(try guidedMessage(viewModel).state.status == .cancelled)
        let data = ChatGuidedDataSource.load(.scheduledPayment, context: context, mainCurrency: "PEN")
        #expect(viewModel.createGuided(messageID: messageID, data: data) != nil)
        #expect(try context.fetchCount(FetchDescriptor<ScheduledPayment>()) == 0)
    }
}
