//
//  SetupStep.swift
//  Yala
//
//  Defines the 8 setup checklist steps for new users.
//

import Foundation
import SwiftData

/// Identifies each step in the setup checklist.
/// Declaration order determines CaseIterable iteration (UI order), NOT rawValue: the rawValue is the
/// UserDefaults key (`setup.step.N.completed`) and must never change.
///
/// UX 2.2 · L5-1 (decisión de Jürgen, opción A): lo primero es apuntar un gasto, después la voz y la foto,
/// y Ajustes y Yala Pro al final. Antes Ajustes iba primero y abría una guía de nueve pasos antes de apuntar nada.
enum SetupStepID: Int, CaseIterable, Identifiable {
    case firstExpense = 2
    case tryVoiceInput = 6
    case tryImageInput = 7
    case firstBudget = 3
    case scheduledPayment = 4
    case exploreSettings = 1
    case discoverFeatures = 5

    var id: Int { rawValue }

    /// SF Symbol icon for each step.
    var icon: String {
        switch self {
        case .exploreSettings: "gearshape.fill"
        case .firstExpense: "plus.circle.fill"
        case .firstBudget: "chart.pie.fill"
        case .scheduledPayment: "calendar.badge.clock"
        case .tryVoiceInput: "waveform"
        case .tryImageInput: "camera.fill"
        case .discoverFeatures: "sparkles"
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

    /// UserDefaults key for «Ahora no» (UX 2.2 · L5-2): the step was skipped, not done.
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
