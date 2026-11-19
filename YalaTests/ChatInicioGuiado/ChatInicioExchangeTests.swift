//
//  ChatInicioExchangeTests.swift
//  YalaTests
//
//  El inicio de Yala IA con el ViewModel de verdad (encargo del 17-nov): un botón deja en el hilo el mensaje de la
//  persona y la respuesta de Yala sin llamar a ningún modelo, las opciones cuelgan de esa respuesta hasta el mensaje
//  siguiente, y cada opción de crear abre su guiado con las mismas puertas que la frase. En su propio fichero porque
//  pide `makeTestContext()` (una suite por fichero, `.claude/rules/testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Yala IA · inicio: el turno local y lo que se crea", .serialized)
struct ChatInicioExchangeTests {

    private func makeViewModel(_ context: ModelContext) -> ChatAssistantViewModel {
        let viewModel = ChatAssistantViewModel(
            defaults: makeIsolatedDefaults(), cloudExploreAvailable: { false }, isConnected: { true })
        viewModel.setContext(context, autoLoadSuggestions: false)
        return viewModel
    }

    private func guidedState(_ viewModel: ChatAssistantViewModel) -> ChatGuidedFlowState? {
        guard let last = viewModel.messages.last else { return nil }
        return viewModel.guidedState(messageID: last.id)
    }

    @Test func aStartButton_leavesTheTwoMessages_withoutCallingAnyModel() throws {
        let context = try makeTestContext()
        let viewModel = makeViewModel(context)

        let replyID = try #require(viewModel.appendLocalExchange(
            userText: ChatInicioBranch.logExpense.userMessage, reply: ChatInicioBranch.logExpense.reply))

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages.first?.role == .user)
        #expect(viewModel.messages.first?.text == ChatInicioBranch.logExpense.userMessage)
        #expect(viewModel.messages.last?.role == .assistant)
        #expect(viewModel.messages.last?.text == ChatInicioBranch.logExpense.reply)
        #expect(viewModel.messages.last?.id == replyID)
        // Entra al historial del día como cualquier turno, y no gasta pregunta del cupo.
        #expect(viewModel.turnCount == 1)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func theOptions_hangFromTheReply_untilTheNextMessage() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: CurrencyDefaults.currentPreferred)
        try context.save()
        let viewModel = makeViewModel(context)

        let replyID = try #require(viewModel.appendLocalExchange(
            userText: ChatInicioBranch.create.userMessage, reply: ChatInicioBranch.create.reply))
        let offer = ChatInicioOffer(branch: .create, replyID: replyID)
        #expect(ChatInicioLogic.showsOptions(offer, lastMessageID: viewModel.messages.last?.id,
                                             isLoading: viewModel.isLoading, isAvailable: true))

        // Tocar una opción abre el guiado: entra el pedido y la tarjeta, y las opciones se van.
        let budget = ChatInicioLogic.createOption(.budget)
        viewModel.startGuidedFlow(budget.kind, question: budget.userMessage)
        #expect(viewModel.messages.count == 4)
        #expect(viewModel.messages[2].text == L10n.IAGuiados.shortcutBudgetMessage)
        #expect(guidedState(viewModel)?.kind == .budget)
        #expect(!ChatInicioLogic.showsOptions(offer, lastMessageID: viewModel.messages.last?.id,
                                              isLoading: viewModel.isLoading, isAvailable: true))
    }

    /// Cuenta, categoría y favorito abren su guiado con su pedido, sin pasar por la frase.
    @Test(arguments: [ChatGuidedKind.account, .category, .favorite, .scheduledPayment])
    func eachCreateOption_opensItsGuidedFlow(_ kind: ChatGuidedKind) throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: CurrencyDefaults.currentPreferred)
        try context.save()
        let viewModel = makeViewModel(context)
        let option = ChatInicioLogic.createOption(kind)

        viewModel.startGuidedFlow(option.kind, question: option.userMessage)

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages.first?.text == option.userMessage)
        #expect(guidedState(viewModel)?.kind == kind)
        #expect(viewModel.messages.last?.text == ChatAssistantViewModel.guidedIntro(kind))
    }

    /// Crear un grupo sin la cuenta de Yala no abre la tarjeta: lo dice en una frase, como con la frase escrita.
    @Test func createGroup_withoutAYalaAccount_saysSoInsteadOfOpeningTheCard() throws {
        let context = try makeTestContext()
        let viewModel = makeViewModel(context)
        let option = ChatInicioLogic.createOption(.group)
        // Control: en los tests no hay sesión de la nube, así que la ruta no es la del backend.
        #expect(ChatAssistantViewModel.groupRoute() != .backend)

        viewModel.startGuidedFlow(option.kind, question: option.userMessage)

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages.first?.text == option.userMessage)
        #expect(guidedState(viewModel) == nil, "Sin cuenta de Yala no hay tarjeta del guiado.")
        let reply = try #require(viewModel.messages.last?.text)
        #expect(reply != ChatAssistantViewModel.guidedIntro(.group))
        #expect(!reply.isEmpty)
    }

    /// El atajo de antes, sin pedido propio, sigue diciendo el de presupuesto o el de pago.
    @Test func withoutAQuestion_theShortcutMessageIsTheUsualOne() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, currencyCode: CurrencyDefaults.currentPreferred)
        try context.save()
        let viewModel = makeViewModel(context)

        viewModel.startGuidedFlow(.scheduledPayment)
        #expect(viewModel.messages.first?.text == L10n.IAGuiados.shortcutPaymentMessage)
        #expect(guidedState(viewModel)?.kind == .scheduledPayment)
    }
}
