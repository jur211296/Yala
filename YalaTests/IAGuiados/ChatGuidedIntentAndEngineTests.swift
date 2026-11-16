//
//  ChatGuidedIntentAndEngineTests.swift
//  YalaTests
//
//  Guiados de Yala IA: qué frase abre qué guiado, qué rellena la frase y cómo avanza el motor (siguiente pregunta
//  pendiente, «Atrás», «Cambiar», confirmación obligatoria). Lógica pura: sin almacén.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Yala IA · guiados: intención, relleno y motor")
struct ChatGuidedIntentAndEngineTests {

    private let catalog = ChatGuidedCatalog(mainCurrency: "PEN", accountCurrencies: ["PEN"])

    // MARK: - Intención

    @Test(arguments: [
        "Quiero un presupuesto para comida",
        "Ayúdame a armar un presupuesto de 300 al mes",
        "presupuesto de 500 soles para transporte",
        "¿Me ayudas a crear un presupuesto?",
        "ayúdame a ahorrar en salidas",
        "quiero gastar menos en delivery",
        "Create a budget for groceries",
        "help me save on eating out",
        "criar um orçamento de 400 por mês",
    ])
    func budgetRequests_openTheBudgetFlow(_ text: String) {
        #expect(ChatGuidedIntentDetector.kind(of: text) == .budget)
    }

    @Test(arguments: [
        "Quiero crear un pago recurrente",
        "anota mi suscripción de Netflix de 45 al mes",
        "recuérdame pagar el alquiler el 1 de cada mes",
        "pago 120 de luz cada mes",
        "add a recurring payment for rent",
        "remind me to pay the phone bill",
        "nuevo pago fijo de 80",
    ])
    func paymentRequests_openThePaymentFlow(_ text: String) {
        #expect(ChatGuidedIntentDetector.kind(of: text) == .scheduledPayment)
    }

    /// Preguntas, mirar lo que ya hay y apuntar un gasto siguen su camino de siempre.
    @Test(arguments: [
        "¿Cuánto gasté en comida este mes?",
        "cómo voy con mis presupuestos",
        "¿mi presupuesto de compras fue suficiente?",
        "quiero ver mis presupuestos",
        "muéstrame mis suscripciones",
        "gasté 50 en mercado",
        "pagué 45 de netflix",
        "taxi 25",
        "how much did I spend on food?",
        "presupuesto",
        "",
    ])
    func otherMessages_doNotOpenAFlow(_ text: String) {
        #expect(ChatGuidedIntentDetector.kind(of: text) == nil)
    }

    // MARK: - Lo que dice la frase

    @Test func budgetSentence_fillsAmountPeriodAndCurrency() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "Quiero un presupuesto de 300 dólares al mes", catalog: catalog))
        #expect(detection.kind == .budget)
        #expect(detection.answers.amount == 300)
        #expect(detection.answers.period == .monthly)
        #expect(detection.answers.currencyCode == "USD")
        #expect(detection.prefilled == [.amount, .period, .currency])
        // Las categorías no las dijo: es lo primero que se pregunta.
        #expect(ChatGuidedEngine.start(.budget, answers: detection.answers).step == .categories)
    }

    @Test func budgetSentence_withOneCurrency_doesNotAskIt_andAllExpenses() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "crea un presupuesto semanal de 1.200,50 para todos mis gastos", catalog: catalog))
        #expect(detection.answers.allExpenses == true)
        #expect(detection.answers.period == .weekly)
        #expect(detection.answers.amount == 1200.5)
        #expect(detection.answers.currencyCode == "PEN")
        #expect(!detection.prefilled.contains(.currency))
        #expect(ChatGuidedEngine.start(.budget, answers: detection.answers).step == .confirm)
    }

    @Test func budgetSentence_withSeveralCurrencies_asksTheCurrency() throws {
        let twoCurrencies = ChatGuidedCatalog(mainCurrency: "PEN", accountCurrencies: ["PEN", "USD"])
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "quiero un presupuesto de 300 al mes para todo lo que gasto", catalog: twoCurrencies))
        #expect(detection.answers.currencyCode == nil)
        #expect(ChatGuidedEngine.start(.budget, answers: detection.answers).step == .currency)
    }

    @Test func paymentSentence_fillsNameDayAmountAndFrequency() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "recuérdame pagar el alquiler el 5 de cada mes, son 1200 soles", catalog: catalog))
        #expect(detection.kind == .scheduledPayment)
        #expect(detection.answers.paymentName == "Alquiler")
        #expect(detection.answers.frequency == .monthly)
        #expect(detection.answers.dayOfMonth == 5)
        #expect(detection.answers.amount == 1200)
        #expect(detection.answers.currencyCode == "PEN")
    }

    @Test func paymentSentence_knownService_isASubscription() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "anota mi suscripción de netflix de 45 al mes", catalog: catalog))
        #expect(detection.answers.paymentName == "Netflix")
        #expect(detection.answers.isSubscription)
        #expect(detection.answers.amount == 45)
        #expect(detection.answers.frequency == .monthly)
        #expect(detection.answers.dayOfMonth == nil)
    }

    @Test func amountParsing_readsTheUsualWritings() {
        #expect(ChatGuidedIntentDetector.amount(in: "300") == 300)
        #expect(ChatGuidedIntentDetector.amount(in: "1,200.50") == 1200.5)
        #expect(ChatGuidedIntentDetector.amount(in: "1.200,50") == 1200.5)
        #expect(ChatGuidedIntentDetector.amount(in: "12,5") == 12.5)
        #expect(ChatGuidedIntentDetector.amount(in: "2k") == 2000)
        #expect(ChatGuidedIntentDetector.amount(in: "s/ 80 o 3 veces") == 80)
        #expect(ChatGuidedIntentDetector.amount(in: "sin cifras") == nil)
        #expect(ChatGuidedIntentDetector.amount(in: "0") == nil)
    }

    // MARK: - Motor

    @Test func engine_asksOnlyWhatIsMissing_andEndsInTheConfirmation() {
        var answers = ChatGuidedAnswers()
        answers.period = .monthly
        answers.currencyCode = "PEN"
        var state = ChatGuidedEngine.start(.budget, answers: answers)
        #expect(state.step == .categories)

        answers.allExpenses = true
        state = ChatGuidedEngine.answer(state, with: answers)
        #expect(state.step == .amount, "El período ya estaba: se salta.")

        answers.amount = 500
        state = ChatGuidedEngine.answer(state, with: answers)
        #expect(state.step == .confirm)
        #expect(ChatGuidedEngine.canCreate(state))
    }

    @Test func engine_back_returnsToThePreviousQuestion() {
        var answers = ChatGuidedAnswers()
        var state = ChatGuidedEngine.start(.budget, answers: answers)
        answers.allExpenses = true
        state = ChatGuidedEngine.answer(state, with: answers)
        #expect(state.step == .period)
        state = ChatGuidedEngine.back(state)
        #expect(state.step == .categories)
        #expect(state.history.isEmpty)
        #expect(ChatGuidedEngine.back(state) == state, "En la primera, «Atrás» no hace nada.")
    }

    @Test func engine_change_fromTheConfirmation_returnsToIt() {
        var answers = ChatGuidedAnswers()
        answers.allExpenses = true
        answers.period = .monthly
        answers.amount = 300
        answers.currencyCode = "PEN"
        var state = ChatGuidedEngine.start(.budget, answers: answers, prefilled: [.amount])
        #expect(state.step == .confirm)

        state = ChatGuidedEngine.edit(state, step: .amount)
        #expect(state.step == .amount)
        #expect(state.returnsToConfirm)
        #expect(!ChatGuidedEngine.canCreate(state), "Fuera de la confirmación no se crea.")

        answers.amount = 250
        state = ChatGuidedEngine.answer(state, with: answers, clearing: [.amount])
        #expect(state.step == .confirm)
        #expect(state.answers.amount == 250)
        #expect(!state.prefilled.contains(.amount), "Cambiado a mano, ya no es «lo dijiste tú».")
    }

    @Test func engine_nothingIsCreated_withoutTheConfirmation() {
        var answers = ChatGuidedAnswers()
        answers.allExpenses = true
        let state = ChatGuidedEngine.start(.budget, answers: answers)
        #expect(!ChatGuidedEngine.canCreate(state))
        let notCreated = ChatGuidedEngine.markCreated(state, id: UUID(), name: "X")
        #expect(notCreated.status == .inProgress)
        #expect(notCreated.createdID == nil)
    }

    @Test func engine_cancel_endsTheFlow_andIgnoresLaterAnswers() {
        let state = ChatGuidedEngine.cancel(ChatGuidedEngine.start(.scheduledPayment, answers: ChatGuidedAnswers()))
        #expect(state.status == .cancelled)
        var answers = state.answers
        answers.paymentName = "Luz"
        #expect(ChatGuidedEngine.answer(state, with: answers) == state)
    }

    @Test func engine_paymentWhen_dependsOnTheFrequency() {
        var answers = ChatGuidedAnswers()
        answers.suggestionKey = ""
        answers.paymentName = "Luz"
        answers.amount = 80
        answers.frequency = .weekly
        let spec = ChatGuidedEngine.scheduledPaymentSpec
        #expect(!spec.isAnswered(.when, answers))
        answers.weekday = 2
        #expect(spec.isAnswered(.when, answers))
        answers.frequency = .monthly
        #expect(!spec.isAnswered(.when, answers), "El día de la semana no vale para «cada mes».")
        answers.dayOfMonth = 15
        #expect(spec.isAnswered(.when, answers))
    }

    /// Lo que viaja en la sesión del día: el estado entero sobrevive a guardarse y leerse.
    @Test func state_roundTripsThroughTheSavedSession() throws {
        var answers = ChatGuidedAnswers()
        answers.allExpenses = true
        answers.period = .yearly
        answers.amount = 12_000
        let state = ChatGuidedEngine.start(.budget, answers: answers, prefilled: [.period])
        let data = try JSONEncoder().encode(ChatAttachment.guided(state))
        let decoded = try JSONDecoder().decode(ChatAttachment.self, from: data)
        #expect(decoded == .guided(state))
    }

    // MARK: - Monto sugerido

    @Test func suggestions_roundAndScaleToThePeriod() throws {
        let monthly = try #require(ChatGuidedSpending.suggestions(monthlyAverage: 437, period: .monthly))
        #expect(monthly.usual == 440)
        #expect(monthly.saving == 390)
        let yearly = try #require(ChatGuidedSpending.suggestions(monthlyAverage: 437, period: .yearly))
        #expect(yearly.usual == 5250)
        #expect(ChatGuidedSpending.suggestions(monthlyAverage: 0, period: .monthly) == nil)
    }
}
