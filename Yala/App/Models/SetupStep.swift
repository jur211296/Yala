//
//  SetupStep.swift
//  Yala
//
//  Defines the 8 setup checklist steps for new users.
//

import Foundation
import SwiftData

/// Identifies each step in the setup checklist.
enum SetupStepID: Int, CaseIterable, Identifiable {
    case exploreSettings = 1
    case firstExpense = 2
    case firstBudget = 3
    case scheduledPayment = 4
    case discoverFeatures = 5

    var id: Int { rawValue }

    /// SF Symbol icon for each step.
    var icon: String {
        switch self {
        case .exploreSettings: "gearshape.fill"
        case .firstExpense: "plus.circle.fill"
        case .firstBudget: "chart.pie.fill"
        case .scheduledPayment: "calendar.badge.clock"
        case .discoverFeatures: "sparkles"
        }
    }

    /// Whether this step offers "Era de prueba" cleanup after guided creation.
    var hasPracticeCleanup: Bool {
        switch self {
        case .firstExpense, .firstBudget, .scheduledPayment: true
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

/// Tracks a practice item created during guided setup for potential cleanup.
struct PracticeCleanupItem: Identifiable {
    let id = UUID()
    let stepID: SetupStepID
    let itemName: String
    let persistentID: PersistentIdentifier

    /// Localized name for the item type (gasto, presupuesto, pago planificado).
    var localizedItemType: String {
        switch stepID {
        case .firstExpense: L10n.SetupChecklist.PracticeType.expense
        case .firstBudget: L10n.SetupChecklist.PracticeType.budget
        case .scheduledPayment: L10n.SetupChecklist.PracticeType.scheduled
        default: ""
        }
    }
}
