//
//  ChatGuidedCreateLogicTests.swift
//  YalaTests
//
//  Guiados de cuenta, categoría y favorito (encargo del 16-nov), sin almacén: qué frase abre cada uno y cuál sigue siendo
//  un registro, lo que la frase ya dice, qué preguntas se saltan según lo contestado y las piezas puras (ícono propuesto,
//  nombres sin repetir, el monto como lo lee el editor).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Yala IA · guiados de cuenta, categoría y favorito: frases y preguntas")
struct ChatGuidedCreateLogicTests {

    private let catalog = ChatGuidedCatalog(mainCurrency: "PEN", accountCurrencies: ["PEN", "USD"])

    // MARK: - ¿Qué frase abre qué?

    @Test(arguments: [
        ("Crea una cuenta de ahorros", ChatGuidedKind.account),
        ("quiero una nueva tarjeta de crédito", .account),
        ("Agrega otra cuenta en dólares", .account),
        ("create a new account", .account),
        ("crie uma conta poupança", .account),
        ("Nueva categoría Mascotas", .category),
        ("crea las subcategorías Veterinario y Peluquería en Mascotas", .category),
        ("add a category for pets", .category),
        ("Crea un favorito para el café de la mañana", .favorite),
        ("agrega un nuevo favorito de 12 soles", .favorite),
        ("save a favorite for my coffee", .favorite),
    ])
    func phrasesThatAskToCreate_openTheirFlow(_ phrase: String, _ kind: ChatGuidedKind) {
        #expect(ChatGuidedIntentDetector.kind(of: phrase) == kind, "«\(phrase)» debía abrir \(kind).")
    }

    /// Lo que se registra o se pregunta sigue su camino: el verbo y la cosa tienen que ir juntos.
    @Test(arguments: [
        "Agrega 20 soles a la cuenta BCP",
        "añade a mi cuenta 50",
        "registra un gasto de 30 en la categoría Comida",
        "¿cuánto tengo en mi cuenta de ahorros?",
        "muéstrame mis favoritos",
        "pagué la cuenta de luz",
        "crea una cuenta de Yala",
        "agrega un gasto de 15 como favorito",
    ])
    func phrasesThatDoNotAskToCreate_openNothing(_ phrase: String) {
        let kind = ChatGuidedIntentDetector.kind(of: phrase)
        #expect(kind != .account && kind != .category && kind != .favorite, "«\(phrase)» no pide crear: salió \(String(describing: kind)).")
    }

    /// El presupuesto sigue ganando cuando se nombra.
    @Test func aBudgetForACategory_isStillABudget() {
        #expect(ChatGuidedIntentDetector.kind(of: "crea un presupuesto para la categoría comida") == .budget)
    }

    // MARK: - Lo que dice la frase

    @Test func account_readsKindCurrencyNameAndBalance() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "Crea una cuenta de ahorros en dólares llamada Colchón con 500", catalog: catalog))
        #expect(detection.kind == .account)
        #expect(detection.answers.accountKind == FirstAccountFlowLogic.Kind.savings.rawValue)
        #expect(detection.answers.accountCurrencies == ["USD"])
        #expect(detection.answers.accountName == "Colchón")
        #expect(detection.answers.accountBalances == ["USD": 500])
        #expect(detection.prefilled.isSuperset(of: [.accountKind, .currency, .name, .balance]))
    }

    /// «Visa con límite de 5000» no es lo que se debe: en tarjeta el saldo no se toma de la frase.
    @Test func creditCard_doesNotTakeAFigureAsTheDebt() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "nueva tarjeta de crédito con límite de 5000", catalog: catalog))
        #expect(detection.answers.accountKind == FirstAccountFlowLogic.Kind.creditCard.rawValue)
        #expect(detection.answers.accountBalances == nil)
    }

    /// Con una sola moneda en Yala no se pregunta.
    @Test func account_withOneCurrency_doesNotAskIt() throws {
        let single = ChatGuidedCatalog(mainCurrency: "PEN", accountCurrencies: ["PEN"])
        let detection = try #require(ChatGuidedIntentDetector.detect("crea una cuenta", catalog: single))
        #expect(detection.answers.accountCurrencies == ["PEN"])
        #expect(!detection.prefilled.contains(.currency), "No lo dijo: no sale «Lo dijiste tú».")
    }

    @Test func newCategory_readsItsNameAndSubcategories() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "crea una categoría Mascotas con veterinario y comida", catalog: catalog))
        #expect(detection.answers.categoryMode == .newCategory)
        #expect(detection.answers.categoryName == "Mascotas")
        #expect(detection.answers.subcategoryNames == ["Veterinario", "Comida"])
    }

    @Test func subcategories_areTheMode_whenThePhraseSaysSo() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "crea las subcategorías Veterinario y Peluquería", catalog: catalog))
        #expect(detection.answers.categoryMode == .subcategories)
        #expect(detection.answers.subcategoryNames == ["Veterinario", "Peluquería"])
        #expect(detection.answers.parentCategoryID == nil, "Sin «en …» que case con una categoría, se pregunta en cuál.")
    }

    @Test func favorite_readsTypeAmountAndName() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "crea un favorito de gasto de 12.50 llamado Café", catalog: catalog))
        #expect(detection.answers.favoriteType == ChatGuidedFavoriteType.expense.rawValue)
        #expect(detection.answers.amount == 12.5)
        #expect(detection.answers.favoriteName == "Café")
    }

    @Test func favorite_transfer() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect(
            "agrega un favorito de transferencia a mis ahorros", catalog: catalog))
        #expect(detection.answers.favoriteType == ChatGuidedFavoriteType.transfer.rawValue)
    }

    // MARK: - Qué se pregunta

    @Test func cash_skipsTheCardQuestionsAndTheNumber() {
        var answers = ChatGuidedAnswers()
        answers.accountKind = FirstAccountFlowLogic.Kind.cash.rawValue
        answers.wantsAdvanced = true
        let asked = ChatGuidedEngine.askedSteps(.account, answers: answers)
        #expect(!asked.contains(.accountStatementDay))
        #expect(!asked.contains(.accountPaymentDay))
        #expect(!asked.contains(.accountReminder))
        #expect(!asked.contains(.accountNumber), "El efectivo no tiene número.")
        #expect(asked.contains(.accountStats))
    }

    @Test func card_asksTheDays_andSkipsTheReminderWithoutAPaymentDay() {
        var answers = ChatGuidedAnswers()
        answers.accountKind = FirstAccountFlowLogic.Kind.creditCard.rawValue
        #expect(ChatGuidedEngine.askedSteps(.account, answers: answers).contains(.accountReminder))
        answers.accountPaymentDay = 0
        #expect(!ChatGuidedEngine.askedSteps(.account, answers: answers).contains(.accountReminder),
                "Con «No lo sé» al día de pago no hay qué recordar.")
    }

    @Test func account_walksToTheConfirmation_inOrder() {
        var state = ChatGuidedEngine.start(.account, answers: ChatGuidedAnswers())
        #expect(state.step == .accountKind)
        var answers = state.answers
        answers.accountKind = FirstAccountFlowLogic.Kind.creditCard.rawValue
        state = ChatGuidedEngine.answer(state, with: answers)
        #expect(state.step == .accountCurrencies)
        answers.accountCurrencies = ["PEN", "USD"]
        state = ChatGuidedEngine.answer(state, with: answers)
        #expect(state.step == .accountName)
        answers.accountName = "Visa"
        state = ChatGuidedEngine.answer(state, with: answers)
        #expect(state.step == .accountBalance)
        answers.accountBalances = ["PEN": -300]
        state = ChatGuidedEngine.answer(state, with: answers)
        #expect(state.step == .accountBalance, "Falta el saldo en dólares: la misma pregunta sigue.")
        answers.accountBalances = ["PEN": -300, "USD": 0]
        state = ChatGuidedEngine.answer(state, with: answers)
        #expect(state.step == .accountStatementDay)
        answers.accountStatementDay = 25
        state = ChatGuidedEngine.answer(state, with: answers)
        answers.accountPaymentDay = 10
        state = ChatGuidedEngine.answer(state, with: answers)
        #expect(state.step == .accountReminder)
        answers.accountReminderLead = 3
        state = ChatGuidedEngine.answer(state, with: answers)
        #expect(state.step == .advanced)
        #expect(!ChatGuidedEngine.canCreate(state), "Nada se crea sin pasar por «Revisa antes de crear».")
        state = ChatGuidedEngine.answerAdvanced(state, wants: false)
        #expect(state.step == .confirm)
        #expect(ChatGuidedEngine.canCreate(state))
    }

    @Test func subcategoriesMode_skipsNameAndLook_newCategory_skipsTheParent() {
        var answers = ChatGuidedAnswers()
        answers.categoryMode = .subcategories
        var asked = ChatGuidedEngine.askedSteps(.category, answers: answers)
        #expect(asked.contains(.categoryParent))
        #expect(!asked.contains(.categoryName) && !asked.contains(.categoryLook))
        answers.categoryMode = .newCategory
        asked = ChatGuidedEngine.askedSteps(.category, answers: answers)
        #expect(!asked.contains(.categoryParent))
        #expect(asked.contains(.categoryName) && asked.contains(.categoryLook))
    }

    @Test func category_needsAtLeastOneSubcategory() {
        var answers = ChatGuidedAnswers()
        answers.categoryMode = .newCategory
        answers.categoryName = "Mascotas"
        answers.categoryIcon = "pawprint.fill"
        answers.categoryColorHex = "#6366F1"
        answers.subcategoryNames = ["  "]
        #expect(ChatGuidedEngine.firstPending(.category, answers: answers) == .categorySubcategories)
        answers.subcategoryNames = ["Veterinario"]
        #expect(ChatGuidedEngine.firstPending(.category, answers: answers) == .advanced)
    }

    @Test func transferFavorite_skipsSubcategoryNeedAndTags_andAsksTheDestination() {
        var answers = ChatGuidedAnswers()
        answers.favoriteType = ChatGuidedFavoriteType.transfer.rawValue
        answers.wantsAdvanced = true
        let asked = ChatGuidedEngine.askedSteps(.favorite, answers: answers)
        #expect(!asked.contains(.favoriteSubcategory))
        #expect(!asked.contains(.favoriteNeed))
        #expect(!asked.contains(.favoriteTags))
        #expect(asked.contains(.favoriteDestination))
    }

    @Test func incomeFavorite_doesNotAskTheNeed() {
        var answers = ChatGuidedAnswers()
        answers.favoriteType = ChatGuidedFavoriteType.income.rawValue
        answers.wantsAdvanced = true
        let asked = ChatGuidedEngine.askedSteps(.favorite, answers: answers)
        #expect(asked.contains(.favoriteSubcategory), "Subcategorías siempre.")
        #expect(!asked.contains(.favoriteNeed))
    }

    @Test func favoriteAmount_isAnswered_byAFigureOrByChangesEachTime() {
        var answers = ChatGuidedAnswers()
        #expect(!ChatGuidedEngine.favoriteSpec.isAnswered(.favoriteAmount, answers))
        answers.favoriteWithoutAmount = true
        #expect(ChatGuidedEngine.favoriteSpec.isAnswered(.favoriteAmount, answers))
        answers.favoriteWithoutAmount = nil
        answers.amount = 0
        #expect(!ChatGuidedEngine.favoriteSpec.isAnswered(.favoriteAmount, answers))
        answers.amount = 12
        #expect(ChatGuidedEngine.favoriteSpec.isAnswered(.favoriteAmount, answers))
    }

    /// «No» a las opciones avanzadas devuelve las de la cuenta, la categoría y el favorito a lo de siempre.
    @Test func noToAdvanced_resetsTheNewOptions() {
        var answers = ChatGuidedAnswers()
        answers.accountNumber = "1234"
        answers.accountCountsInReports = false
        answers.subcategoryNeeds = ["Veterinario": SubcategoryNeed.essential.rawValue]
        answers.favoriteNeed = SubcategoryNeed.optional.rawValue
        answers.resetAdvancedOptions()
        #expect(answers.accountNumber == nil)
        #expect(answers.accountCountsInReports == nil)
        #expect(answers.subcategoryNeeds == nil)
        #expect(answers.favoriteNeed == nil)
    }

    // MARK: - Piezas

    @Test func suggestedIcon_readsTheName() {
        #expect(ChatGuidedCategoryLook.suggestedIcon(for: "Mascotas") == "pawprint.fill")
        #expect(ChatGuidedCategoryLook.suggestedIcon(for: "Viajes") == "airplane")
        #expect(ChatGuidedCategoryLook.suggestedIcon(for: "Educación") == "graduationcap.fill",
                "«Educación» no puede caer en mascotas por contener «cat».")
        #expect(ChatGuidedCategoryLook.suggestedIcon(for: "Cosas raras") == "tag.fill")
    }

    @Test func cleanNames_dropEmptiesAndRepeats() {
        #expect(ChatGuidedCreator.cleanNames([" Veterinario ", "", "veterinário", "Comida"]) == ["Veterinario", "Comida"])
    }

    /// El editor lee el monto con la coma o el punto de la región: lo que se le pasa tiene que volver igual.
    @Test(arguments: ["es_PE", "de_DE", "en_US", "fr_FR"])
    func editorAmountText_roundTrips(_ identifier: String) {
        let locale = Locale(identifier: identifier)
        for amount in [12.5, 1234.0, 0.99] {
            let text = ChatGuidedCreator.editorAmountText(amount, locale: locale)
            #expect(AmountInputHelper.parseDecimal(text, locale: locale) == amount, "\(identifier): \(text)")
        }
    }
}
