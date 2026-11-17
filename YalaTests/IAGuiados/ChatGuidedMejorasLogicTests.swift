//
//  ChatGuidedMejorasLogicTests.swift
//  YalaTests
//
//  Mejoras de los guiados de Yala IA (encargo del 16-nov): montos y días dichos con palabras (español, inglés y
//  portugués), «cada N» y «una sola vez» en la frase, y el motor con las opciones avanzadas («Sí» las pregunta una a
//  una con «Saltar»; «No» crea con los valores de siempre). Lógica pura: sin almacén.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Yala IA · guiados: palabras, cada N, una sola vez y opciones avanzadas")
struct ChatGuidedMejorasLogicTests {

    private let catalog = ChatGuidedCatalog(mainCurrency: "PEN", accountCurrencies: ["PEN"])

    // MARK: - Números con palabras

    @Test(arguments: [
        ("quiero un presupuesto de trescientos", "quiero un presupuesto de 300"),
        ("mil quinientos al mes", "1500 al mes"),
        ("dos mil cincuenta soles", "2050 soles"),
        ("treinta y cinco", "35"),
        ("ciento veinte", "120"),
        ("un millon", "1000000"),
        ("three hundred a month", "300 a month"),
        ("one thousand five hundred", "1500"),
        ("a hundred and fifty dollars", "150 dollars"),
        ("twenty-five", "25"),
        ("trezentos reais", "300 reais"),
        ("mil e quinhentos", "1500"),
        ("cento e vinte", "120"),
        ("el cinco de cada mes", "el 5 de cada mes"),
        ("on the fifth of each month", "on the 5th of each month"),
        ("el primero de cada mes", "el 1 de cada mes"),
    ])
    func numberWords_becomeDigits(_ pair: (String, String)) {
        #expect(ChatGuidedNumberWords.replacingNumberWords(in: pair.0) == pair.1)
    }

    /// «un», «una», «a», «one», «um» sueltos no son 1, ni el «once» inglés es 11.
    @Test(arguments: [
        "quiero un presupuesto para comida",
        "una sola vez",
        "a budget for food",
        "one-time payment",
        "pay it just once",
        "quero um orcamento",
        "presupuesto",
    ])
    func ambiguousWords_stayAsTheyAre(_ text: String) {
        #expect(ChatGuidedNumberWords.replacingNumberWords(in: text) == text)
    }

    @Test func spokenSentences_fillTheAmount() throws {
        let budget = try #require(ChatGuidedIntentDetector.detect(
            "Quiero un presupuesto de trescientos al mes para todos mis gastos", catalog: catalog))
        #expect(budget.answers.amount == 300)
        #expect(budget.answers.period == .monthly)

        let soles = try #require(ChatGuidedIntentDetector.detect(
            "presupuesto de dos mil cincuenta soles para todo", catalog: catalog))
        #expect(soles.answers.amount == 2050)
        #expect(soles.answers.currencyCode == "PEN")

        let payment = try #require(ChatGuidedIntentDetector.detect(
            "Recuérdame pagar el alquiler el cinco de cada mes, son mil doscientos", catalog: catalog))
        #expect(payment.answers.paymentName == "Alquiler", "El nombre no se lleva el número.")
        #expect(payment.answers.dayOfMonth == 5)
        #expect(payment.answers.amount == 1200)

        let english = try #require(ChatGuidedIntentDetector.detect(
            "I want a budget of three hundred a month for everything", catalog: catalog))
        #expect(english.answers.amount == 300)

        let portuguese = try #require(ChatGuidedIntentDetector.detect(
            "criar um orçamento de mil e quinhentos por mês", catalog: catalog))
        #expect(portuguese.answers.amount == 1500)
    }

    /// Una palabra suelta que no es un número no abre el guiado como si lo fuera: «presupuesto» sigue sin verbo.
    @Test func numberWords_doNotInventAnAmount() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect("quiero un presupuesto", catalog: catalog))
        #expect(detection.answers.amount == nil)
        #expect(ChatGuidedIntentDetector.kind(of: "presupuesto") == nil)
    }

    // MARK: - Cada N y una sola vez

    @Test(arguments: [
        ("anota un pago fijo de 50 cada 2 semanas", ChatGuidedFrequency.weekly, 2),
        ("pago 30 cada 15 días de gimnasio", .daily, 15),
        ("quiero un pago recurrente de 200 cada tres meses", .monthly, 3),
        ("add a recurring payment of 40 every 2 weeks", .weekly, 2),
        ("nuevo pago fijo quincenal de 100", .weekly, 2),
    ])
    func everyN_isUnderstood(_ case_: (String, ChatGuidedFrequency, Int)) throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(case_.0, catalog: catalog))
        #expect(detection.kind == .scheduledPayment)
        #expect(detection.answers.frequency == case_.1)
        #expect(detection.answers.interval == case_.2)
        #expect(detection.answers.dayOfMonth == nil, "«cada 2» no es el día 2.")
        #expect(detection.prefilled.contains(.frequency))
    }

    @Test func everyN_doesNotTakeTheIntervalAsTheAmount() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "nuevo pago fijo de 80 cada 2 semanas", catalog: catalog))
        #expect(detection.answers.amount == 80)
    }

    @Test func oneTimeBudget_isUnderstood_andAsksTheDates() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "quiero un presupuesto de una sola vez de 2000 para todos mis gastos", catalog: catalog))
        #expect(detection.answers.period == .once)
        let state = ChatGuidedEngine.start(.budget, answers: detection.answers)
        #expect(state.step == .dates, "Una sola vez: lo que falta son las fechas.")
        #expect(ChatGuidedPeriod.once.budgetPeriodRaw == BudgetPeriodType.unique.rawValue)
    }

    @Test func onceAMonth_isMonthly_notOneTime() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "quiero un pago fijo de 50 una vez al mes", catalog: catalog))
        #expect(detection.answers.frequency == .monthly)
    }

    @Test func oneTimeBudget_needsBothDates_inOrder() {
        var answers = ChatGuidedAnswers()
        answers.period = .once
        let spec = ChatGuidedEngine.budgetSpec
        #expect(!spec.isAnswered(.dates, answers))
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        answers.budgetStart = start
        answers.budgetEnd = start.addingTimeInterval(-86_400)
        #expect(!spec.isAnswered(.dates, answers), "El fin no puede ir antes del inicio.")
        answers.budgetEnd = start.addingTimeInterval(86_400 * 10)
        #expect(spec.isAnswered(.dates, answers))
        answers.period = .monthly
        answers.budgetStart = nil
        #expect(spec.isAnswered(.dates, answers), "Sin «una sola vez» no hay fechas que preguntar.")
    }

    @Test func dailyPayment_asksTheStartDate() {
        var answers = ChatGuidedAnswers()
        answers.frequency = .daily
        answers.interval = 15
        #expect(!ChatGuidedEngine.scheduledPaymentSpec.isAnswered(.when, answers))
        answers.date = .now
        #expect(ChatGuidedEngine.scheduledPaymentSpec.isAnswered(.when, answers))
    }

    // MARK: - Opciones avanzadas

    private func budgetReadyForAdvanced() -> ChatGuidedFlowState {
        var answers = ChatGuidedAnswers()
        answers.allExpenses = true
        answers.period = .monthly
        answers.amount = 300
        answers.currencyCode = "PEN"
        answers.notApplicable = [.budgetTags]
        return ChatGuidedEngine.start(.budget, answers: answers)
    }

    @Test func advanced_no_goesToTheConfirmation_withTheUsualValues() {
        var state = budgetReadyForAdvanced()
        #expect(state.step == .advanced)
        state = ChatGuidedEngine.answerAdvanced(state, wants: false)
        #expect(state.step == .confirm)
        #expect(state.answers.budgetAlert == nil)
        #expect(state.answers.accountIDs == nil)
        #expect(ChatGuidedEngine.canCreate(state))
    }

    @Test func advanced_yes_asksThemOneByOne_skipKeepsTheUsualValue_andSkipsWhatDoesNotApply() {
        var state = ChatGuidedEngine.answerAdvanced(budgetReadyForAdvanced(), wants: true)
        #expect(state.step == .budgetName)
        // «Saltar» contesta sin cambiar nada.
        state = ChatGuidedEngine.answer(state, with: state.answers)
        #expect(state.step == .budgetAlerts)
        #expect(state.answers.budgetName == nil)
        var answers = state.answers
        answers.budgetAlert = .at100
        state = ChatGuidedEngine.answer(state, with: answers)
        #expect(state.step == .budgetAccounts)
        state = ChatGuidedEngine.answer(state, with: state.answers)
        #expect(state.step == .budgetShared, "Sin etiquetas, esa pregunta no sale.")
        state = ChatGuidedEngine.answer(state, with: state.answers)
        #expect(state.step == .budgetPanel)
        state = ChatGuidedEngine.answer(state, with: state.answers)
        #expect(state.step == .confirm)
        #expect(state.answers.budgetAlert == .at100)
        #expect(ChatGuidedEngine.canCreate(state))
    }

    @Test func advanced_noFromChange_resetsWhatWasChosen() {
        var state = ChatGuidedEngine.answerAdvanced(budgetReadyForAdvanced(), wants: true)
        var answers = state.answers
        answers.budgetName = "Viaje"
        state = ChatGuidedEngine.answer(state, with: answers)
        while state.step != .confirm { state = ChatGuidedEngine.answer(state, with: state.answers) }
        state = ChatGuidedEngine.edit(state, step: .advanced)
        #expect(state.step == .advanced)
        state = ChatGuidedEngine.answerAdvanced(state, wants: false)
        #expect(state.step == .confirm)
        #expect(state.answers.budgetName == nil, "«No» vuelve a los valores de siempre.")
        #expect(state.answers.notApplicable == [.budgetTags], "Lo que no toca sigue sin tocar.")
    }

    @Test func progress_countsOnlyWhatIsAsked() {
        let state = budgetReadyForAdvanced()
        let before = ChatGuidedEngine.progress(state)
        // Categorías, período, monto, moneda, avanzadas: sin subcategorías (todos los gastos) ni fechas.
        #expect(before.total == 5)
        #expect(before.answered == 4)
        let withAdvanced = ChatGuidedEngine.answerAdvanced(state, wants: true)
        // Más las cinco avanzadas que tocan (sin etiquetas).
        #expect(ChatGuidedEngine.progress(withAdvanced).total == 10)
    }

    @Test func paymentEnd_isNotAsked_forAOneTimePayment() {
        var answers = ChatGuidedAnswers()
        answers.frequency = .once
        answers.wantsAdvanced = true
        #expect(ChatGuidedEngine.scheduledPaymentSpec.isAnswered(.paymentEnd, answers))
        answers.frequency = .monthly
        #expect(!ChatGuidedEngine.scheduledPaymentSpec.isAnswered(.paymentEnd, answers))
    }

    // MARK: - Lo que cazó la revisión

    /// «2 mil» con cifra delante sigue siendo 2000: el multiplicador no empieza otro número.
    @Test func digitsBeforeMil_keepTheirValue() throws {
        #expect(ChatGuidedNumberWords.replacingNumberWords(in: "presupuesto de 2 mil soles") == "presupuesto de 2 mil soles")
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "quiero un presupuesto de 2 mil soles para todo", catalog: catalog))
        #expect(detection.answers.amount == 2000)
    }

    /// Un ordinal que no es un día no se convierte: ni «every second week» ni «my first apartment».
    @Test(arguments: [
        "add a recurring payment for rent every second week",
        "create a budget for my first apartment",
        "my budget ran out the first week",
    ])
    func ordinalsThatAreNotADay_stayAsTheyAre(_ text: String) {
        #expect(ChatGuidedNumberWords.replacingNumberWords(in: ChatGuidedIntentDetector.fold(text))
            == ChatGuidedIntentDetector.fold(text))
    }

    @Test func notAQuestion_aboutTheFirstWeek_doesNotOpenAFlow() {
        #expect(ChatGuidedIntentDetector.kind(of: "my budget ran out the first week") == nil)
    }

    /// «para los dos» son dos personas, y «dos semanas» es tiempo: ninguno es el monto.
    @Test(arguments: [
        "crear un presupuesto para los dos",
        "quiero un presupuesto para dos semanas",
        "quiero un presupuesto para 2 semanas",
    ])
    func peopleAndTime_areNotTheAmount(_ text: String) throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(text, catalog: catalog))
        #expect(detection.answers.amount == nil)
    }

    @Test func everyDay_isDaily() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "pago 10 de estacionamiento todos los días", catalog: catalog))
        #expect(detection.answers.frequency == .daily)
        #expect(detection.answers.effectiveInterval == 1)
    }

    /// «Atrás» tras decir «No» a las avanzadas no vuelve a una que ya no se pregunta, y contestarla no cambia nada.
    @Test func advancedOptions_afterNo_areNeitherReachedByBack_norAnswered() {
        var state = ChatGuidedEngine.answerAdvanced(budgetReadyForAdvanced(), wants: true)
        while state.step != .confirm { state = ChatGuidedEngine.answer(state, with: state.answers) }
        state = ChatGuidedEngine.edit(state, step: .advanced)
        state = ChatGuidedEngine.answerAdvanced(state, wants: false)
        #expect(state.step == .confirm)
        state = ChatGuidedEngine.back(state)
        #expect(state.step == .advanced || state.step == .confirm, "Ninguna opción avanzada tras el «No».")
        #expect(!state.step.isAdvancedOption)

        var reached = state
        reached.step = .budgetPanel
        var answers = reached.answers
        answers.showsInPanel = true
        let after = ChatGuidedEngine.answer(reached, with: answers)
        #expect(after.answers.showsInPanel == nil, "Sin querer revisarlas, el valor de siempre no se toca.")
    }

    /// Una sesión guardada por la versión anterior (sin los campos nuevos) se sigue leyendo.
    @Test func oldSavedAnswers_stillDecode() throws {
        let json = #"{"categoryIDs":[],"isVariableAmount":false,"isSubscription":true,"amount":45}"#
        let answers = try JSONDecoder().decode(ChatGuidedAnswers.self, from: Data(json.utf8))
        #expect(answers.amount == 45)
        #expect(answers.isSubscription)
        #expect(answers.wantsAdvanced == nil)
        #expect(answers.removedSubcategoryIDs == nil)
    }
}
