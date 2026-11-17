//
//  ChatInicioLogic.swift
//  Yala
//
//  El inicio de Yala IA (encargo del 17-nov, «limpiar el chat lo más posible en cada paso»): el saludo con tres
//  botones de color y nada más. Tocar uno manda un mensaje de la persona, Yala contesta sin llamar a la IA y, debajo de
//  esa respuesta, ofrece sus opciones. Las opciones viven en la vista, no en el mensaje guardado: se ven mientras esa
//  respuesta sea lo último del hilo, y en cuanto entra otro mensaje desaparecen solas.
//
//  Sin SwiftUI, para fijarlo con tests (`YalaTests/ChatInicioGuiado/`).
//

import Foundation

/// Los tres botones del inicio.
enum ChatInicioBranch: String, CaseIterable, Sendable {
    /// Rosa: apuntar un gasto. Las opciones son ejemplos que se escriben en la caja SIN enviarse.
    case logExpense
    /// Índigo: preguntar. Las opciones son las preguntas personalizadas de hoy, y se envían solas.
    case askFinances
    /// Turquesa: crear conversando. Las opciones abren el guiado de cada cosa.
    case create

    /// Lo que la persona «dice» al tocar el botón. Sale en el hilo como cualquier mensaje suyo.
    var userMessage: String {
        switch self {
        case .logExpense: YalaIAInicioText.logUserMessage
        case .askFinances: YalaIAInicioText.askUserMessage
        case .create: YalaIAInicioText.createUserMessage
        }
    }

    /// Lo que contesta Yala, en el teléfono.
    var reply: String {
        switch self {
        case .logExpense: YalaIAInicioText.logReply
        case .askFinances: YalaIAInicioText.askReply
        case .create: YalaIAInicioText.createReply
        }
    }
}

/// Qué rama se abrió y a qué respuesta de Yala cuelgan sus opciones.
struct ChatInicioOffer: Equatable, Sendable {
    let branch: ChatInicioBranch
    let replyID: UUID
}

/// Una opción de «Quiero crear algo»: qué guiado abre, cómo se llama y qué dice la persona al tocarla.
struct ChatInicioCreateOption: Identifiable, Equatable, Sendable {
    let kind: ChatGuidedKind
    let title: String
    let userMessage: String
    let systemImage: String

    var id: String { kind.rawValue }
    /// `chat_create_budget`, `chat_create_payment`… Los dos primeros son los ids de los atajos de antes.
    var accessibilityIdentifier: String {
        switch kind {
        case .budget: "chat_create_budget"
        case .scheduledPayment: "chat_create_payment"
        default: "chat_create_\(kind.rawValue)"
        }
    }
}

enum ChatInicioLogic {

    /// Las opciones de una rama se ven mientras su respuesta sea el último mensaje del hilo, sin una pregunta en vuelo y
    /// con Yala IA disponible. Cualquier mensaje nuevo (enviar, tocar una pregunta, abrir un guiado) las retira.
    static func showsOptions(
        _ offer: ChatInicioOffer?,
        lastMessageID: UUID?,
        isLoading: Bool,
        isAvailable: Bool
    ) -> Bool {
        guard let offer, isAvailable, !isLoading else { return false }
        return lastMessageID == offer.replyID
    }

    /// Las preguntas de «Pregunta por tus finanzas»: las tres primeras sugerencias del día.
    static let askOptionCount = 3

    /// Lo que se crea conversando: lo que ya guía el chat. La deuda y el gasto de grupo se quedan en la frase: son
    /// apuntar algo dentro de un grupo, no crear.
    static let createKinds: [ChatGuidedKind] = [.budget, .scheduledPayment, .account, .category, .favorite, .group]

    static func createOptions() -> [ChatInicioCreateOption] {
        // Con cierre y no con la referencia al método: la referencia sale no aislada y avisa en Swift 6.
        createKinds.map { createOption($0) }
    }

    static func createOption(_ kind: ChatGuidedKind) -> ChatInicioCreateOption {
        switch kind {
        case .budget:
            ChatInicioCreateOption(kind: kind, title: L10n.IAGuiados.greetingCreateBudget,
                                   userMessage: L10n.IAGuiados.shortcutBudgetMessage, systemImage: "chart.pie.fill")
        case .scheduledPayment:
            ChatInicioCreateOption(kind: kind, title: L10n.IAGuiados.greetingCreatePayment,
                                   userMessage: L10n.IAGuiados.shortcutPaymentMessage,
                                   systemImage: "calendar.badge.clock")
        case .account:
            ChatInicioCreateOption(kind: kind, title: YalaIAInicioText.createAccount,
                                   userMessage: YalaIAInicioText.createAccountMessage, systemImage: "creditcard.fill")
        case .category:
            ChatInicioCreateOption(kind: kind, title: YalaIAInicioText.createCategory,
                                   userMessage: YalaIAInicioText.createCategoryMessage, systemImage: "square.grid.2x2.fill")
        case .favorite:
            ChatInicioCreateOption(kind: kind, title: YalaIAInicioText.createFavorite,
                                   userMessage: YalaIAInicioText.createFavoriteMessage, systemImage: "star.fill")
        case .group, .groupOpeningBalance, .groupExpense:
            ChatInicioCreateOption(kind: kind, title: YalaIAInicioText.createGroup,
                                   userMessage: YalaIAInicioText.createGroupMessage, systemImage: "person.2.fill")
        }
    }
}
