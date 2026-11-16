//
//  ChatGuidedFlow.swift
//  Yala
//
//  Lo que guarda un guiado de Yala IA mientras se contesta: qué se está creando, en qué pregunta va, lo que la
//  persona ya respondió (o dijo en su frase) y cómo terminó. Viaja como adjunto del mensaje de Yala IA
//  (`ChatAttachment.guided`) y se guarda con la sesión del día, así que es `Codable`: los nombres de las claves son
//  formato persistido y no se renombran.
//
//  Sin SwiftUI ni SwiftData (salvo `PersistentIdentifier`, que ya viaja en los borradores del chat), para fijarlo con
//  tests.
//

import Foundation
import SwiftData

/// Qué crea el guiado. Un flujo nuevo empieza aquí, con su `ChatGuidedFlowSpec`.
nonisolated enum ChatGuidedKind: String, Codable, CaseIterable, Sendable {
    case budget
    case scheduledPayment
}

/// Una pregunta del guiado. Los dos flujos comparten las que se parecen (monto, moneda) y cada uno usa las suyas.
nonisolated enum ChatGuidedStep: String, Codable, Sendable {
    // Presupuesto
    case categories
    case period
    // Pago planificado
    case suggestion
    case name
    case frequency
    case when
    case account
    case subcategory
    // Los dos
    case amount
    case currency
    case confirm
    case done
}

/// Cómo va el guiado. Solo `.created` guardó algo.
nonisolated enum ChatGuidedStatus: String, Codable, Sendable {
    case inProgress
    case created
    case cancelled
}

/// El período de un presupuesto creado desde el chat. «Una vez» (con fechas) queda en el editor.
nonisolated enum ChatGuidedPeriod: String, Codable, CaseIterable, Sendable {
    case monthly
    case weekly
    case yearly

    /// El valor guardado en `Budget.periodType` (`BudgetPeriodType.rawValue`).
    var budgetPeriodRaw: String { rawValue }
}

/// La frecuencia de un pago planificado: las cuatro de Primeros pasos (`FirstScheduledPaymentFlowLogic.Frequency`).
nonisolated enum ChatGuidedFrequency: String, Codable, CaseIterable, Sendable {
    case monthly
    case weekly
    case yearly
    case once

    @MainActor var flowFrequency: FirstScheduledPaymentFlowLogic.Frequency {
        switch self {
        case .monthly: .monthly
        case .weekly: .weekly
        case .yearly: .yearly
        case .once: .once
        }
    }
}

/// Las respuestas. Un campo en `nil` es una pregunta pendiente; los campos de un flujo no los usa el otro.
nonisolated struct ChatGuidedAnswers: Codable, Equatable, Sendable {
    // MARK: Presupuesto

    /// «Todos mis gastos» (`true`) o las categorías elegidas (`false`). `nil`: sin contestar.
    var allExpenses: Bool?
    /// Las categorías elegidas, en el orden en que se marcaron.
    var categoryIDs: [PersistentIdentifier] = []
    var period: ChatGuidedPeriod?
    /// El nombre del presupuesto. `nil`: el que se propone con las categorías.
    var budgetName: String?

    // MARK: Pago planificado

    /// La propuesta de los registros que se tomó (`RecurringPaymentDetector.Proposal.key`), o «ninguna» con `""`.
    /// `nil`: no se contestó (o no había propuestas).
    var suggestionKey: String?
    var paymentName: String?
    var frequency: ChatGuidedFrequency?
    var dayOfMonth: Int?
    /// Día de la semana del calendario (1 = domingo).
    var weekday: Int?
    /// La fecha de «Cada año» y de «Una vez».
    var date: Date?
    var accountID: PersistentIdentifier?
    var subcategoryID: PersistentIdentifier?
    var isVariableAmount = false
    var isSubscription = false

    // MARK: Los dos

    var amount: Double?
    var currencyCode: String?

    init() {}
}

/// Lo que se rellenó con la frase de la persona: en la confirmación sale marcado.
nonisolated enum ChatGuidedField: String, Codable, Sendable {
    case categories
    case period
    case amount
    case currency
    case name
    case frequency
    case day
}

/// El estado entero de un guiado dentro del chat.
nonisolated struct ChatGuidedFlowState: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let kind: ChatGuidedKind
    var step: ChatGuidedStep
    /// Las preguntas ya contestadas, para «Atrás».
    var history: [ChatGuidedStep] = []
    var answers: ChatGuidedAnswers
    var prefilled: Set<ChatGuidedField> = []
    var status: ChatGuidedStatus = .inProgress
    /// Desde «Cambiar» de la confirmación: al contestar se vuelve a ella.
    var returnsToConfirm = false
    /// Lo creado: `Budget.id` o `ScheduledPayment.id`.
    var createdID: UUID?
    /// El nombre con el que se creó, para la tarjeta de éxito.
    var createdName: String?
    /// La primera fecha de pago del pago creado.
    var createdDueDate: Date?

    init(id: UUID = UUID(), kind: ChatGuidedKind, step: ChatGuidedStep, answers: ChatGuidedAnswers,
         prefilled: Set<ChatGuidedField> = []) {
        self.id = id
        self.kind = kind
        self.step = step
        self.answers = answers
        self.prefilled = prefilled
    }
}
