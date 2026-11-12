//
//  SetupStep.swift
//  Yala
//
//  Defines the setup checklist («Primeros pasos») steps for new users.
//

import Foundation
import SwiftData

/// Identifies each step in the setup checklist.
/// The rawValue is the UserDefaults key (`setup.step.N.completed`) and must never change.
///
/// Y23-05 (bienvenida 2.3, docs/onboarding-2-3/SPEC.md): «Primeros pasos» es un MAZO de siete pasos, en este orden:
/// cuenta, registrar, presupuesto, pagos fijos, grupo, a dónde va el dinero y la pantalla de inicio (`deck`). Los tres
/// que ya existían conservan su clave (2, 3 y 4), así que lo avanzado antes cuenta. «Conoce todo lo que puedes
/// personalizar» (1) y «Conoce Yala Pro» (5) salieron del mazo; sus claves quedan sin leer.
///
/// Voz y foto (6 y 7) ya no son pasos: son prácticas DENTRO de «Aprender a registrar» (Y23-09 las rehace) y siguen aquí
/// porque su «¿era de prueba?» (`PracticeCleanupItem`) y su «Ahora no» se apuntan con estos ids. No cuentan para el mazo.
enum SetupStepID: Int, CaseIterable, Identifiable {
    /// 1 · Crea tu primera cuenta.
    case firstAccount = 8
    /// 2 · Aprender a registrar. Se llama así por la clave de 2.2 («Registra tu primer gasto»), que se conserva.
    case firstExpense = 2
    /// 3 · Crea tu primer presupuesto.
    case firstBudget = 3
    /// 4 · Anota tus pagos fijos.
    case scheduledPayment = 4
    /// 5 · Divide gastos con tu grupo.
    case groups = 9
    /// 6 · Mira a dónde va tu dinero.
    case whereMoneyGoes = 10
    /// 7 · Yala en tu pantalla de inicio.
    case homeScreen = 11
    /// Práctica de voz dentro del paso 2 (no es un paso del mazo).
    case tryVoiceInput = 6
    /// Práctica de foto dentro del paso 2 (no es un paso del mazo).
    case tryImageInput = 7

    var id: Int { rawValue }

    /// Los siete pasos del mazo, en el orden de la ficha.
    static let deck: [SetupStepID] = [
        .firstAccount, .firstExpense, .firstBudget, .scheduledPayment, .groups, .whereMoneyGoes, .homeScreen,
    ]

    /// Si es un paso del mazo (y no una práctica de dentro de un paso).
    var isDeckStep: Bool { Self.deck.contains(self) }

    /// SF Symbol icon for each step.
    var icon: String {
        switch self {
        case .firstAccount: "creditcard.fill"
        case .firstExpense: "plus.circle.fill"
        case .firstBudget: "chart.pie.fill"
        case .scheduledPayment: "calendar.badge.clock"
        case .groups: "person.2.fill"
        case .whereMoneyGoes: "chart.bar.fill"
        case .homeScreen: "apps.iphone"
        case .tryVoiceInput: "waveform"
        case .tryImageInput: "camera.fill"
        }
    }

    /// Whether this step offers "Era de prueba" cleanup after guided creation.
    var hasPracticeCleanup: Bool {
        switch self {
        case .firstExpense, .firstBudget, .scheduledPayment,
             .tryVoiceInput, .tryImageInput: true
        default: false
        }
    }

    /// UserDefaults key for this step's completion state.
    var storageKey: String {
        "setup.step.\(rawValue).completed"
    }

    /// UserDefaults key for «Ahora no» / «Omitir» (UX 2.2 · L5-2): the step was skipped, not done.
    var skippedStorageKey: String {
        "setup.step.\(rawValue).skipped"
    }
}

/// A setup step with its current completion state.
///
/// Ningún paso lleva candado (UX 2.2 · L5-1): cualquiera se puede tocar, y el que toca solo va destacado.
struct SetupStep: Identifiable {
    let id: SetupStepID
    let isCompleted: Bool
    /// «Ahora no» en la práctica (UX 2.2 · L5-2): no cuenta como hecho y se puede volver a probar.
    var isSkipped: Bool = false

    var icon: String { id.icon }
    var hasPracticeCleanup: Bool { id.hasPracticeCleanup }
}

/// Which SwiftData model a practice cleanup item should delete.
enum PracticeItemKind {
    case transaction
    case draft
    case budget
    case scheduledPayment

    /// Infer default kind from the step that created the item.
    static func defaultKind(for step: SetupStepID) -> PracticeItemKind {
        switch step {
        case .firstExpense, .tryVoiceInput, .tryImageInput: .transaction
        case .firstBudget: .budget
        case .scheduledPayment: .scheduledPayment
        default: .transaction
        }
    }
}

/// Tracks a practice item created during guided setup for potential cleanup.
struct PracticeCleanupItem: Identifiable {
    let id = UUID()
    let stepID: SetupStepID
    let itemName: String
    let persistentID: PersistentIdentifier
    let kind: PracticeItemKind
    let additionalIDs: [PersistentIdentifier]

    init(stepID: SetupStepID, itemName: String, persistentID: PersistentIdentifier,
         kind: PracticeItemKind? = nil, additionalIDs: [PersistentIdentifier] = []) {
        self.stepID = stepID
        self.itemName = itemName
        self.persistentID = persistentID
        self.kind = kind ?? PracticeItemKind.defaultKind(for: stepID)
        self.additionalIDs = additionalIDs
    }

    var allPersistentIDs: [PersistentIdentifier] {
        [persistentID] + additionalIDs
    }

    /// Localized name for the item type (gasto, presupuesto, pago planificado).
    var localizedItemType: String {
        switch stepID {
        case .firstExpense: L10n.SetupChecklist.PracticeType.expense
        case .firstBudget: L10n.SetupChecklist.PracticeType.budget
        case .scheduledPayment: L10n.SetupChecklist.PracticeType.scheduled
        case .tryVoiceInput: L10n.SetupChecklist.PracticeType.voiceTrial
        case .tryImageInput: L10n.SetupChecklist.PracticeType.imageTrial
        default: ""
        }
    }
}
