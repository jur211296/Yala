//
//  SetupStep.swift
//  Yala
//
//  Defines the 8 setup checklist steps for new users.
//

import Foundation
import SwiftData

/// Identifies each step in the setup checklist.
/// Declaration order determines CaseIterable iteration (UI order), NOT rawValue.
/// discoverFeatures keeps rawValue=5 for backward compat with UserDefaults.
enum SetupStepID: Int, CaseIterable, Identifiable {
    case exploreSettings = 1
    case firstExpense = 2
    case firstBudget = 3
    case scheduledPayment = 4
    case tryVoiceInput = 6
    case tryImageInput = 7
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
}

/// A setup step with its current completion state.
struct SetupStep: Identifiable {
    let id: SetupStepID
    let isCompleted: Bool
    /// Whether this step requires other steps to be completed first.
    let isLocked: Bool

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

    init(stepID: SetupStepID, itemName: String, persistentID: PersistentIdentifier, kind: PracticeItemKind? = nil) {
        self.stepID = stepID
        self.itemName = itemName
        self.persistentID = persistentID
        self.kind = kind ?? PracticeItemKind.defaultKind(for: stepID)
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
