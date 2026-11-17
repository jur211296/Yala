//
//  ChatGuidedCreateStoreTests.swift
//  YalaTests
//
//  Guiados de cuenta, categoría y favorito (encargo del 16-nov), con el almacén: la frase abre la tarjeta, lo que falta se
//  contesta, y «Crear» guarda por las mismas piezas que los formularios (Primeros pasos para la cuenta, el editor de
//  favoritos para el favorito). En su propio fichero porque pide `makeTestContext()` (una suite por fichero).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Yala IA · guiados de cuenta, categoría y favorito en el almacén", .serialized)
struct ChatGuidedCreateStoreTests {

    private func makeViewModel(_ context: ModelContext) -> ChatAssistantViewModel {
        let viewModel = ChatAssistantViewModel(
            defaults: makeIsolatedDefaults(), cloudExploreAvailable: { false }, isConnected: { true })
        viewModel.setContext(context, autoLoadSuggestions: false)
        return viewModel
    }

    private func guided(_ viewModel: ChatAssistantViewModel) throws -> (id: UUID, state: ChatGuidedFlowState) {
        let message = try #require(viewModel.messages.last)
        let state = try #require(viewModel.guidedState(messageID: message.id))
        return (message.id, state)
    }

    private func create(_ viewModel: ChatAssistantViewModel, _ messageID: UUID, _ kind: ChatGuidedKind,
                        context: ModelContext) -> String? {
        let data = ChatGuidedDataSource.load(kind, context: context, mainCurrency: CurrencyDefaults.currentPreferred)
        return viewModel.createGuided(messageID: messageID, data: data)
    }

    // MARK: - Cuenta

    @Test func account_fromAPhrase_createsItWithItsBalance() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "Efectivo", currencyCode: "PEN")
        _ = makeTestAccount(context: context, name: "Dólares", currencyCode: "USD")
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("Crea una cuenta de ahorros en soles llamada Colchón con 500")
        let (messageID, state) = try guided(viewModel)
        #expect(state.kind == .account)
        #expect(state.step == .advanced, "Tipo, moneda, nombre y saldo los dijo: solo quedan las opciones avanzadas.")
        viewModel.guidedAdvanced(messageID: messageID, wants: false)
        #expect(try guided(viewModel).state.step == .confirm)
        #expect(create(viewModel, messageID, .account, context: context) == nil)

        let account = try #require(try context.fetch(FetchDescriptor<Account>()).first { $0.name == "Colchón" })
        #expect(account.type == AccountType.savings.rawValue)
        #expect(account.currencyCode == "PEN")
        let balance = AccountBalanceCalculator.currentBalance(
            for: account, allTransactions: try context.fetch(FetchDescriptor<TransactionItem>()))
        #expect(balance == 500)
        #expect(try guided(viewModel).state.status == .created)
    }

    @Test func creditCard_keepsItsDaysReminderAndAdvancedOptions() async throws {
        let context = try makeTestContext()
        // La cuenta va en la moneda principal del entorno: con PEN fijo, en un runner en_US (USD) había dos monedas y
        // el guiado preguntaba cuál antes del nombre (rojo del CI del 17-nov).
        let main = CurrencyDefaults.currentPreferred.uppercased()
        _ = makeTestAccount(context: context, name: "Efectivo", currencyCode: main)
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("quiero una nueva tarjeta de crédito")
        var (messageID, state) = try guided(viewModel)
        #expect(state.kind == .account)
        #expect(state.step == .accountName, "El tipo lo dijo y con una sola moneda no se pregunta.")
        viewModel.answerGuided(messageID: messageID) { $0.accountName = "Visa Oro" }
        viewModel.answerGuided(messageID: messageID) { $0.accountBalances = [main: -320] }
        state = try guided(viewModel).state
        #expect(state.step == .accountStatementDay)
        viewModel.answerGuided(messageID: messageID) { $0.accountStatementDay = 25 }
        viewModel.answerGuided(messageID: messageID) { $0.accountPaymentDay = 10 }
        viewModel.answerGuided(messageID: messageID) { $0.accountReminderLead = 3 }
        viewModel.guidedAdvanced(messageID: messageID, wants: true)
        viewModel.answerGuided(messageID: messageID) { $0.accountNumber = "4321" }
        viewModel.answerGuided(messageID: messageID) { $0.accountCountsInReports = false }
        #expect(try guided(viewModel).state.step == .confirm)
        #expect(create(viewModel, messageID, .account, context: context) == nil)

        let card = try #require(try context.fetch(FetchDescriptor<Account>()).first { $0.name == "Visa Oro" })
        #expect(card.type == AccountType.creditCard.rawValue)
        #expect(card.creditCardStatementDay == 25)
        #expect(card.creditCardPaymentDay == 10)
        #expect(card.creditCardPaymentReminder)
        #expect(card.creditCardReminderDaysBefore == 3)
        #expect(card.accountNumber == "4321")
        #expect(card.excludeFromStatistics)
    }

    @Test func account_withATakenName_isNotCreated() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "Ahorros", currencyCode: "PEN")
        try context.save()
        var answers = ChatGuidedAnswers()
        answers.accountKind = FirstAccountFlowLogic.Kind.savings.rawValue
        answers.accountCurrencies = ["PEN"]
        answers.accountName = "ahorros "
        answers.accountBalances = ["PEN": 0]
        answers.wantsAdvanced = false
        let state = ChatGuidedEngine.start(.account, answers: answers)
        #expect(state.step == .confirm)
        let data = ChatGuidedDataSource.load(.account, context: context, mainCurrency: "PEN")
        #expect(throws: ChatGuidedCreationError.duplicateName) {
            try ChatGuidedCreator.create(state, data: data, context: context, budgetAlertsEnabled: false,
                                         canCreateAccount: { _ in true })
        }
        #expect(try context.fetch(FetchDescriptor<Account>()).count == 1)
    }

    /// El límite del plan gratis: no se crea por encima.
    @Test func account_overThePlanLimit_isNotCreated() throws {
        let context = try makeTestContext()
        var answers = ChatGuidedAnswers()
        answers.accountKind = FirstAccountFlowLogic.Kind.cash.rawValue
        answers.accountCurrencies = ["PEN"]
        answers.accountName = "Billetera"
        answers.accountBalances = ["PEN": 0]
        answers.wantsAdvanced = false
        let state = ChatGuidedEngine.start(.account, answers: answers)
        let data = ChatGuidedDataSource.load(.account, context: context, mainCurrency: "PEN")
        #expect(throws: ChatGuidedCreationError.planLimitReached) {
            try ChatGuidedCreator.create(state, data: data, context: context, budgetAlertsEnabled: false,
                                         canCreateAccount: { _ in false })
        }
        #expect(try context.fetch(FetchDescriptor<Account>()).isEmpty)
    }

    // MARK: - Categoría

    @Test func newCategory_withItsSubcategoriesAndNeeds() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context)
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("crea una categoría Mascotas con veterinario y comida")
        let (messageID, state) = try guided(viewModel)
        #expect(state.kind == .category)
        #expect(state.step == .categoryLook, "Nombre y subcategorías los dijo: falta el ícono y el color.")
        viewModel.answerGuided(messageID: messageID) {
            $0.categoryIcon = "pawprint.fill"
            $0.categoryColorHex = "#22C55E"
        }
        viewModel.guidedAdvanced(messageID: messageID, wants: true)
        viewModel.answerGuided(messageID: messageID) {
            $0.subcategoryNeeds = ["Veterinario": SubcategoryNeed.essential.rawValue]
        }
        #expect(try guided(viewModel).state.step == .confirm)
        #expect(create(viewModel, messageID, .category, context: context) == nil)

        let category = try #require(try context.fetch(FetchDescriptor<YalaCategory>()).first { $0.name == "Mascotas" })
        #expect(category.iconName == "pawprint.fill")
        #expect(category.colorHex == "#22C55E")
        #expect(!category.isIncome)
        let subcategories = (category.subcategories ?? []).sorted { $0.sortOrder < $1.sortOrder }
        #expect(subcategories.map(\.name) == ["Veterinario", "Comida"])
        #expect(subcategories.allSatisfy { $0.colorHex == "#22C55E" }, "Heredan el color, como en el formulario.")
        #expect(subcategories.first?.need == .essential)
        #expect(subcategories.last?.need == .unclassified)
    }

    @Test func subcategories_inAnExistingCategory_skipTheOnesItHas() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context)
        let pets = makeTestCategory(context: context, name: "Mascotas")
        _ = makeTestSubcategory(context: context, name: "Veterinario", category: pets)
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("crea las subcategorías Veterinario y Peluquería en Mascotas")
        let (messageID, state) = try guided(viewModel)
        #expect(state.answers.categoryMode == .subcategories)
        #expect(state.answers.parentCategoryID == pets.persistentModelID, "«en Mascotas» la nombra.")
        viewModel.guidedAdvanced(messageID: messageID, wants: false)
        #expect(try guided(viewModel).state.step == .confirm)
        #expect(create(viewModel, messageID, .category, context: context) == nil)

        let names = (pets.subcategories ?? []).map(\.name).sorted()
        #expect(names == ["Peluquería", "Veterinario"], "Veterinario ya estaba: no se repite.")
    }

    @Test func newCategory_withATakenName_isNotCreated() throws {
        let context = try makeTestContext()
        _ = makeTestCategory(context: context, name: "Viajes")
        try context.save()
        var answers = ChatGuidedAnswers()
        answers.categoryMode = .newCategory
        answers.categoryName = "viajes"
        answers.categoryIcon = "airplane"
        answers.categoryColorHex = "#6366F1"
        answers.subcategoryNames = ["Vuelos"]
        answers.wantsAdvanced = false
        let state = ChatGuidedEngine.start(.category, answers: answers)
        let data = ChatGuidedDataSource.load(.category, context: context, mainCurrency: "PEN")
        #expect(throws: ChatGuidedCreationError.duplicateName) {
            try ChatGuidedCreator.create(state, data: data, context: context, budgetAlertsEnabled: false)
        }
        #expect(try context.fetch(FetchDescriptor<YalaCategory>()).count == 1)
    }

    // MARK: - Favorito

    @Test func expenseFavorite_isSavedWithItsSubcategoryAccountAndAmount() async throws {
        let context = try makeTestContext()
        let wallet = makeTestAccount(context: context, name: "Billetera", currencyCode: "PEN")
        let food = makeTestCategory(context: context, name: "Comida")
        let coffee = makeTestSubcategory(context: context, name: "Cafeterías", category: food)
        try context.save()

        let viewModel = makeViewModel(context)
        await viewModel.sendQuestion("crea un favorito de gasto de 12.50 llamado Café de la mañana")
        var (messageID, state) = try guided(viewModel)
        #expect(state.kind == .favorite)
        #expect(state.answers.accountID == wallet.persistentModelID, "Con una sola cuenta no se pregunta.")
        #expect(state.step == .favoriteSubcategory)
        viewModel.answerGuided(messageID: messageID) { $0.subcategoryID = coffee.persistentModelID }
        state = try guided(viewModel).state
        #expect(state.step == .advanced)
        viewModel.guidedAdvanced(messageID: messageID, wants: false)
        #expect(create(viewModel, messageID, .favorite, context: context) == nil)

        let favorite = try #require(try context.fetch(FetchDescriptor<FavoritePayment>()).first)
        #expect(favorite.name == "Café de la mañana")
        #expect(favorite.transactionType == TransactionType.expense.rawValue)
        #expect(favorite.amount == 12.5)
        #expect(favorite.subcategory?.persistentModelID == coffee.persistentModelID)
        #expect(favorite.account?.persistentModelID == wallet.persistentModelID)
        #expect(favorite.currencyCode == "PEN")
        _ = messageID
    }

    @Test func transferFavorite_withoutAmount_goesToItsDestination() throws {
        let context = try makeTestContext()
        let from = makeTestAccount(context: context, name: "Sueldo", currencyCode: "PEN")
        let to = makeTestAccount(context: context, name: "Ahorros", currencyCode: "PEN")
        try context.save()
        var answers = ChatGuidedAnswers()
        answers.favoriteType = ChatGuidedFavoriteType.transfer.rawValue
        answers.accountID = from.persistentModelID
        answers.destinationAccountID = to.persistentModelID
        answers.favoriteWithoutAmount = true
        answers.favoriteName = "A mis ahorros"
        answers.wantsAdvanced = false
        let state = ChatGuidedEngine.start(.favorite, answers: answers)
        #expect(state.step == .confirm)
        let data = ChatGuidedDataSource.load(.favorite, context: context, mainCurrency: "PEN")
        _ = try ChatGuidedCreator.create(state, data: data, context: context, budgetAlertsEnabled: false)

        let favorite = try #require(try context.fetch(FetchDescriptor<FavoritePayment>()).first)
        #expect(favorite.transactionType == TransactionType.transfer.rawValue)
        #expect(favorite.amount == nil, "«Cambia cada vez»: sin monto.")
        #expect(favorite.subcategory == nil)
        #expect(favorite.destinationAccount?.persistentModelID == to.persistentModelID)
    }

    /// La misma cuenta como origen y destino no responde la pregunta del destino.
    @Test func transferToTheSameAccount_staysOnTheDestination() throws {
        let context = try makeTestContext()
        let only = makeTestAccount(context: context, name: "Sueldo", currencyCode: "PEN")
        try context.save()
        var answers = ChatGuidedAnswers()
        answers.favoriteType = ChatGuidedFavoriteType.transfer.rawValue
        answers.accountID = only.persistentModelID
        answers.destinationAccountID = only.persistentModelID
        #expect(ChatGuidedEngine.firstPending(.favorite, answers: answers) == .favoriteDestination)
    }
}
