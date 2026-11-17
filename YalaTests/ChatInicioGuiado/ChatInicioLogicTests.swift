//
//  ChatInicioLogicTests.swift
//  YalaTests
//
//  El inicio de Yala IA (encargo del 17-nov): cuándo se ven las opciones de un botón, qué se crea conversando y que la
//  vista cablea cada opción como pidió Jürgen (el ejemplo rellena sin enviar, la pregunta se envía, crear abre el
//  guiado). Sin almacén: lo que pide `makeTestContext()` va en `ChatInicioExchangeTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Yala IA · inicio: cuándo se ven las opciones")
struct ChatInicioLogicTests {

    private let reply = UUID()
    private var offer: ChatInicioOffer { ChatInicioOffer(branch: .askFinances, replyID: reply) }

    @Test func optionsShow_whileTheirReplyIsTheLastMessage() {
        #expect(ChatInicioLogic.showsOptions(offer, lastMessageID: reply, isLoading: false, isAvailable: true))
    }

    @Test func anyNewMessage_hidesTheOptions() {
        #expect(!ChatInicioLogic.showsOptions(offer, lastMessageID: UUID(), isLoading: false, isAvailable: true))
    }

    @Test func aQuestionInFlight_hidesTheOptions() {
        #expect(!ChatInicioLogic.showsOptions(offer, lastMessageID: reply, isLoading: true, isAvailable: true))
    }

    @Test func withoutYalaIA_theOptionsDoNotShow() {
        #expect(!ChatInicioLogic.showsOptions(offer, lastMessageID: reply, isLoading: false, isAvailable: false))
    }

    @Test func withoutAnOpenBranch_nothingShows() {
        #expect(!ChatInicioLogic.showsOptions(nil, lastMessageID: reply, isLoading: false, isAvailable: true))
        #expect(!ChatInicioLogic.showsOptions(nil, lastMessageID: nil, isLoading: false, isAvailable: true))
    }

    @Test func threeButtons_inTheirOrder() {
        #expect(ChatInicioBranch.allCases == [.logExpense, .askFinances, .create])
    }

    @Test func eachButton_saysItsOwnMessage_andGetsItsOwnReply() {
        let messages = ChatInicioBranch.allCases.map(\.userMessage)
        let replies = ChatInicioBranch.allCases.map(\.reply)
        #expect(Set(messages).count == 3)
        #expect(Set(replies).count == 3)
        #expect(!messages.contains { $0.isEmpty || $0.hasPrefix("yalaIAInicio.") })
        #expect(!replies.contains { $0.isEmpty || $0.hasPrefix("yalaIAInicio.") })
    }

    @Test func logExpense_offersThreeExamples() {
        let examples = YalaIAInicioText.logExamples
        #expect(examples.count == 3)
        #expect(Set(examples).count == 3)
        // Un ejemplo de apuntar lleva cifra: es lo que lo distingue de una pregunta en el chat.
        #expect(examples.allSatisfy { $0.rangeOfCharacter(from: .decimalDigits) != nil })
    }

    @Test func askFinances_offersThreeQuestions() {
        #expect(ChatInicioLogic.askOptionCount == 3)
    }

    @Test func create_offersWhatTheChatAlreadyGuides() {
        #expect(ChatInicioLogic.createKinds == [.budget, .scheduledPayment, .account, .category, .favorite, .group])
        let options = ChatInicioLogic.createOptions()
        #expect(options.map(\.kind) == ChatInicioLogic.createKinds)
        #expect(Set(options.map(\.title)).count == options.count)
        #expect(Set(options.map(\.userMessage)).count == options.count)
        #expect(Set(options.map(\.accessibilityIdentifier)).count == options.count)
        #expect(!options.contains { $0.title.hasPrefix("yalaIAInicio.") || $0.userMessage.hasPrefix("yalaIAInicio.") })
    }

    /// Presupuesto y pago conservan el pedido y el id de los atajos de antes: los XCUITest y el historial los conocen.
    @Test func budgetAndPayment_keepTheirShortcutMessageAndIdentifier() {
        let budget = ChatInicioLogic.createOption(.budget)
        #expect(budget.userMessage == L10n.IAGuiados.shortcutBudgetMessage)
        #expect(budget.accessibilityIdentifier == "chat_create_budget")
        let payment = ChatInicioLogic.createOption(.scheduledPayment)
        #expect(payment.userMessage == L10n.IAGuiados.shortcutPaymentMessage)
        #expect(payment.accessibilityIdentifier == "chat_create_payment")
    }
}

@Suite("Yala IA · inicio: cableado de la vista (source-scan)")
struct ChatInicioWiringTests {

    private static func source(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// El cuerpo del cierre que empieza en `marker`, hasta su llave de cierre.
    private static func closure(after marker: String, in code: String) throws -> String {
        let start = try #require(code.range(of: marker))
        var depth = 0
        var body = ""
        for character in code[start.upperBound...] {
            if character == "{" { depth += 1 }
            if character == "}" {
                if depth == 0 { break }
                depth -= 1
            }
            body.append(character)
        }
        return body
    }

    @Test func emptyChat_showsTheThreeButtons() throws {
        let sheet = try Self.source("Yala/App/Views/Chat/ChatSheetView.swift")
        #expect(sheet.contains("ChatInicioGreeting("))
        #expect(!sheet.contains("ChatTwoUsesGreeting("), "El saludo de fichas con listas se fue.")
        // Sin «Crea conversando» solo en la prueba de cortesía de Primeros pasos.
        #expect(sheet.contains("? ChatInicioBranch.allCases : [.logExpense, .askFinances]"))
    }

    /// Jürgen: tocar un ejemplo rellena el campo, pero no lo envía.
    @Test func anExample_fillsTheBox_withoutSending() throws {
        let sheet = try Self.source("Yala/App/Views/Chat/ChatSheetView.swift")
        let body = try Self.closure(after: "onExample: { example in", in: sheet)
        #expect(body.contains("viewModel.inputText = example"))
        #expect(body.contains("isInputFocused = true"))
        #expect(!body.contains("send"), "Un ejemplo no se envía solo.")
    }

    /// Una pregunta de hoy se envía sola; una opción de crear abre su guiado con su pedido.
    @Test func aQuestionSends_andACreateOptionOpensItsGuidedFlow() throws {
        let sheet = try Self.source("Yala/App/Views/Chat/ChatSheetView.swift")
        #expect(sheet.contains("onSuggestion: sendSuggestion,"))
        #expect(sheet.contains("viewModel.startGuidedFlow(option.kind, question: option.userMessage)"))
    }

    /// Un botón del inicio contesta en el teléfono: el turno local, nunca `sendQuestion` (que llamaría a la IA).
    @Test func aStartButton_answersLocally() throws {
        let sheet = try Self.source("Yala/App/Views/Chat/ChatSheetView.swift")
        let body = try Self.closure(after: "private func startInicioBranch(_ branch: ChatInicioBranch) {", in: sheet)
        #expect(body.contains("viewModel.appendLocalExchange(userText: branch.userMessage, reply: branch.reply)"))
        #expect(!body.contains("sendQuestion"))
    }

    /// Las opciones se ven con la regla de `ChatInicioLogic`, debajo de los mensajes, y salen sin duplicar el árbol.
    @Test func theOptions_followTheRule_andLeaveWithoutDuplicates() throws {
        let sheet = try Self.source("Yala/App/Views/Chat/ChatSheetView.swift")
        #expect(sheet.contains("guard ChatInicioLogic.showsOptions("))
        #expect(sheet.contains("lastMessageID: viewModel.messages.last?.id,"))
        let options = try #require(sheet.range(of: "if let offer = visibleInicioOffer {"))
        let messages = try #require(sheet.range(of: "ForEach(viewModel.messages) { message in"))
        #expect(messages.lowerBound < options.lowerBound, "Las opciones van bajo la respuesta, no encima.")
        #expect(sheet[options.upperBound...].prefix(200).contains(".transition(.stateSwap)"))
    }

    /// Reducir movimiento: sin animación al irse los botones ni al llegar las preguntas.
    @Test func animations_respectReduceMotion() throws {
        let sheet = try Self.source("Yala/App/Views/Chat/ChatSheetView.swift")
        #expect(sheet.contains(
            ".dsAnimation(DS.Animation.appear, value: viewModel.messages.isEmpty, reduceMotion: reduceMotion)"))
        let options = try Self.source("Yala/App/Views/Chat/Inicio/ChatInicioOptionsView.swift")
        #expect(options.contains(".animation(reduceMotion ? nil : DS.Animation.appear, value: isPreparing)"))
    }

    /// Los tres botones, sin subtextos ni listas: un icono y un título cada uno.
    @Test func theButtons_haveNoSubtitlesOrLists() throws {
        let greeting = try Self.source("Yala/App/Views/Chat/Inicio/ChatInicioGreeting.swift")
        #expect(!greeting.contains("logBody"))
        #expect(!greeting.contains("greetingCreateSubtitle"))
        #expect(!greeting.contains("ForEach(suggestions"))
        #expect(greeting.contains("coachMarkAnchor(ChatCourtesyTrial.logExpenseAnchor)"),
                "La guía de foco de la prueba sigue señalando «Apunta un gasto».")
    }
}
