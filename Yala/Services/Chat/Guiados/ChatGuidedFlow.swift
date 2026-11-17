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
    case account
    case category
    case favorite
}

/// Una pregunta del guiado. Los dos flujos comparten las que se parecen (monto, moneda) y cada uno usa las suyas.
nonisolated enum ChatGuidedStep: String, Codable, Sendable {
    // Presupuesto
    case categories
    /// «¿Algo que no quieras contar?»: las subcategorías de lo elegido, todas marcadas, que se pueden quitar.
    case subcategories
    case period
    /// Las fechas de un presupuesto de «Una sola vez».
    case dates
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
    /// «¿Quieres revisar las opciones avanzadas?». Lo que sigue solo se pregunta con un «Sí».
    case advanced
    // Opciones avanzadas del presupuesto
    case budgetName
    case budgetAlerts
    case budgetAccounts
    case budgetTags
    case budgetShared
    case budgetPanel
    // Opciones avanzadas del pago
    case paymentSubscription
    case paymentReminder
    case paymentEnd
    case paymentNote
    case paymentTags
    case paymentPanel
    // Cuenta
    case accountKind
    case accountCurrencies
    case accountName
    /// El saldo de cada moneda de la cuenta, en una sola pregunta.
    case accountBalance
    case accountStatementDay
    case accountPaymentDay
    case accountReminder
    // Opciones avanzadas de la cuenta
    case accountNumber
    case accountStats
    // Categoría
    /// «¿Una categoría nueva o subcategorías dentro de una que ya tienes?».
    case categoryMode
    case categoryParent
    case categoryName
    /// Ícono y color.
    case categoryLook
    case categorySubcategories
    // Opciones avanzadas de la categoría
    case categoryNeeds
    // Favorito
    case favoriteType
    case favoriteSubcategory
    case favoriteAccount
    case favoriteDestination
    case favoriteAmount
    case favoriteName
    // Opciones avanzadas del favorito
    case favoriteNeed
    case favoriteTags
    case favoriteNote
    case confirm
    case done

    /// Las preguntas que solo salen tras «Sí, revisarlas».
    static let advancedOptions: [ChatGuidedStep] = [
        .budgetName, .budgetAlerts, .budgetAccounts, .budgetTags, .budgetShared, .budgetPanel,
        .paymentSubscription, .paymentReminder, .paymentEnd, .paymentNote, .paymentTags, .paymentPanel,
        .accountNumber, .accountStats, .categoryNeeds, .favoriteNeed, .favoriteTags, .favoriteNote,
    ]

    var isAdvancedOption: Bool { Self.advancedOptions.contains(self) }
}

/// Cómo va el guiado. Solo `.created` guardó algo.
nonisolated enum ChatGuidedStatus: String, Codable, Sendable {
    case inProgress
    case created
    case cancelled
}

/// El período de un presupuesto creado desde el chat. «Una sola vez» lleva fechas (`ChatGuidedStep.dates`).
nonisolated enum ChatGuidedPeriod: String, Codable, CaseIterable, Sendable {
    case monthly
    case weekly
    case yearly
    case once

    /// El valor guardado en `Budget.periodType` (`BudgetPeriodType.rawValue`).
    var budgetPeriodRaw: String { self == .once ? "unique" : rawValue }
}

/// La frecuencia de un pago planificado: las cuatro de Primeros pasos y «cada N días» (`interval` dice cada cuántos).
nonisolated enum ChatGuidedFrequency: String, Codable, CaseIterable, Sendable {
    case monthly
    case weekly
    case yearly
    case once
    case daily

    var isRecurring: Bool { self != .once }

    /// El tipo de repetición del pago (`ScheduledPayment.recurrenceType`).
    @MainActor var recurrenceType: RecurrenceType {
        switch self {
        case .monthly, .once: .monthly
        case .weekly: .weekly
        case .yearly: .yearly
        case .daily: .daily
        }
    }
}

/// Qué crea el guiado de categorías: una categoría con sus subcategorías, o subcategorías dentro de una que ya existe.
nonisolated enum ChatGuidedCategoryMode: String, Codable, Sendable {
    case newCategory
    case subcategories
}

/// El tipo de un favorito. Los valores son los de `TransactionType.rawValue`, que es lo que guarda `FavoritePayment`.
nonisolated enum ChatGuidedFavoriteType: String, Codable, CaseIterable, Sendable {
    case expense
    case income
    case transfer
}

/// «¿Te avisamos cuando vayas llegando al tope?» (los tres de Primeros pasos, `FirstBudgetFlowLogic.Alert`).
nonisolated enum ChatGuidedBudgetAlert: String, Codable, CaseIterable, Sendable {
    case at75And100
    case at100
    case none

    var flowAlert: FirstBudgetFlowLogic.Alert {
        switch self {
        case .at75And100: .at75And100
        case .at100: .at100
        case .none: .none
        }
    }
}

/// «¿Te avisamos antes de que toque pagar?» (los cuatro de Primeros pasos, `FirstScheduledPaymentFlowLogic.Reminder`).
nonisolated enum ChatGuidedReminder: String, Codable, CaseIterable, Sendable {
    case threeDaysBefore
    case oneDayBefore
    case sameDay
    case none

    var flowReminder: FirstScheduledPaymentFlowLogic.Reminder {
        switch self {
        case .threeDaysBefore: .threeDaysBefore
        case .oneDayBefore: .oneDayBefore
        case .sameDay: .sameDay
        case .none: .none
        }
    }
}

/// Las respuestas. Un campo en `nil` es una pregunta pendiente; los campos de un flujo no los usa el otro.
///
/// Todo campo nuevo es opcional: una sesión del día guardada con la versión anterior se sigue leyendo (el `Codable`
/// sintetizado exige las claves de los campos no opcionales).
nonisolated struct ChatGuidedAnswers: Codable, Equatable, Sendable {
    // MARK: Presupuesto

    /// «Todos mis gastos» (`true`) o las categorías elegidas (`false`). `nil`: sin contestar.
    var allExpenses: Bool?
    /// Las categorías elegidas, en el orden en que se marcaron.
    var categoryIDs: [PersistentIdentifier] = []
    var period: ChatGuidedPeriod?
    /// El nombre del presupuesto. `nil`: el que se propone con las categorías.
    var budgetName: String?
    /// Las subcategorías (`Subcategory.shortcutID`) que la persona quitó de lo elegido. `nil`: no se revisaron todavía.
    var removedSubcategoryIDs: [UUID]?
    /// Las fechas de un presupuesto de «Una sola vez».
    var budgetStart: Date?
    var budgetEnd: Date?

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
    /// Cada cuántos días, semanas o meses. `nil` = 1.
    var interval: Int?

    // MARK: Los dos

    var amount: Double?
    var currencyCode: String?

    // MARK: Opciones avanzadas (las dos)

    /// «¿Quieres revisar las opciones avanzadas?». `false`: se crea con los valores de siempre.
    var wantsAdvanced: Bool?
    /// Las opciones avanzadas ya contestadas o saltadas.
    var advancedDone: [ChatGuidedStep]?
    /// Las que no tocan a esta persona (sin etiquetas, sin grupos): no se preguntan.
    var notApplicable: [ChatGuidedStep]?
    var budgetAlert: ChatGuidedBudgetAlert?
    /// Solo los gastos de estas cuentas. Vacío o `nil`: todas.
    var accountIDs: [PersistentIdentifier]?
    var tagIDs: [PersistentIdentifier]?
    /// Tu parte de los gastos de grupo. `nil`: sí (el valor del editor).
    var includeSharedExpenses: Bool?
    /// «¿Lo ponemos en tu Panel?». `nil`: no.
    var showsInPanel: Bool?
    var reminder: ChatGuidedReminder?
    /// La última fecha del pago. `nil`: sin fecha de fin.
    var endDate: Date?
    var note: String?
    /// Lo que iOS contestó al pedir el permiso de avisos por una opción avanzada. `nil`: no se pidió.
    var notificationsAllowed: Bool?

    // MARK: Cuenta

    /// `FirstAccountFlowLogic.Kind.rawValue`.
    var accountKind: String?
    /// Las monedas de la cuenta, la principal primero.
    var accountCurrencies: [String]?
    var accountName: String?
    /// El saldo de cada moneda, ya con su signo (en tarjeta, lo que se debe en negativo).
    var accountBalances: [String: Double]?
    /// Día de cierre y de pago de una tarjeta: 1…31, o `0` = «No lo sé». `nil`: sin contestar.
    var accountStatementDay: Int?
    var accountPaymentDay: Int?
    /// Días antes del pago para recordarlo, o `-1` = «No me lo recuerdes». `nil`: sin contestar.
    var accountReminderLead: Int?
    /// Los últimos números de la cuenta. Vacío: sin número.
    var accountNumber: String?
    /// «¿Lo que pasa en esta cuenta cuenta en tus reportes?». `nil`: sí.
    var accountCountsInReports: Bool?

    // MARK: Categoría

    var categoryMode: ChatGuidedCategoryMode?
    /// La categoría donde van las subcategorías nuevas.
    var parentCategoryID: PersistentIdentifier?
    var categoryName: String?
    var categoryIcon: String?
    var categoryColorHex: String?
    /// Las subcategorías nuevas, en el orden en que se añadieron.
    var subcategoryNames: [String]?
    /// La necesidad de cada subcategoría nueva (`SubcategoryNeed.rawValue`), por su nombre. Sin entrada: sin clasificar.
    var subcategoryNeeds: [String: String]?

    // MARK: Favorito

    /// `TransactionType.rawValue`.
    var favoriteType: String?
    var destinationAccountID: PersistentIdentifier?
    /// «Cambia cada vez»: el favorito no lleva monto.
    var favoriteWithoutAmount: Bool?
    var favoriteName: String?
    /// `SubcategoryNeed.rawValue`. `nil`: la de la subcategoría.
    var favoriteNeed: String?

    init() {}

    var effectiveInterval: Int { max(1, interval ?? 1) }

    func isDone(_ step: ChatGuidedStep) -> Bool { advancedDone?.contains(step) ?? false }

    func isNotApplicable(_ step: ChatGuidedStep) -> Bool { notApplicable?.contains(step) ?? false }

    /// Vuelve las opciones avanzadas a los valores de siempre («No» a la pregunta, o «No» desde «Cambiar»).
    mutating func resetAdvancedOptions() {
        advancedDone = nil
        budgetName = nil
        budgetAlert = nil
        accountIDs = nil
        tagIDs = nil
        includeSharedExpenses = nil
        showsInPanel = nil
        reminder = nil
        endDate = nil
        note = nil
        notificationsAllowed = nil
        accountNumber = nil
        accountCountsInReports = nil
        subcategoryNeeds = nil
        favoriteNeed = nil
    }
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
    case subcategories
    case accountKind
    case balance
    case categoryMode
    case parentCategory
    case favoriteType
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
