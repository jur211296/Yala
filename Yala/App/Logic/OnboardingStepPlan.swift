//
//  OnboardingStepPlan.swift
//  Yala
//
//  SSOT de la planificación de pasos del onboarding: qué pasos se saltan
//  (por prefill de iCloud restore + modo de uso) y cuál es el primer paso
//  efectivo. Pure-logic, sin SwiftUI — testeable y reusado por `OnboardingView`
//  para reconciliar `currentStep` con `effectiveSteps` desde el `init` (evita el
//  bug del botón "Siguiente" muerto cuando el primer paso está saltado por prefill).
//

import Foundation

/// Pasos del flujo de onboarding. Movido fuera de `OnboardingView` (era un enum
/// privado anidado) para que la planificación sea pure-logic y testeable.
/// `OnboardingView` lo referencia vía `typealias Step = OnboardingStep`.
enum OnboardingStep: Int, CaseIterable {
    case name = 0
    case purpose = 1       // "¿Qué te gustaría hacer?" (binary)
    case accounts = 2      // "¿Cómo organizas?" (binary) — skip if expensesOnly
    case accountType = 3   // "¿Cuál es tu primera cuenta?" — skip if not fullControl
    case currencyName = 4
    case balance = 5       // skip if expensesOnly
    case categories = 6
    case confirmation = 7  // Resumen + privacidad (último paso)

    /// String estable para telemetría — desacoplado del rawValue Int.
    var trackingName: String {
        switch self {
        case .name:         return "name"
        case .purpose:      return "purpose"
        case .accounts:     return "accounts"
        case .accountType:  return "accountType"
        case .currencyName: return "currencyName"
        case .balance:      return "balance"
        case .categories:   return "categories"
        case .confirmation: return "confirmation"
        }
    }
}

/// Pure-logic de planificación de pasos. SSOT de los skips y del primer paso
/// efectivo, reusada por `OnboardingView` tanto para `effectiveSteps` como para
/// el valor inicial de `currentStep` en el `init`.
enum OnboardingStepPlan {

    /// Conjunto de pasos a saltar combinando el prefill de iCloud (rama B del
    /// Welcome Restore) con el modo de uso elegido por el usuario.
    /// `.purpose` y `.confirmation` nunca se saltan (tracking + resumen final).
    static func skippedSteps(
        prefilledUserName: String?,
        prefilledAccountsCount: Int,
        prefilledCurrencyCode: String?,
        prefilledCategoriesCount: Int,
        hasPrefill: Bool,
        expensesOnly: Bool,
        dayToDay: Bool
    ) -> Set<OnboardingStep> {
        var skip: Set<OnboardingStep> = []

        // Skips por modo de uso (decisión binaria del usuario).
        if expensesOnly {
            skip.formUnion([.accounts, .accountType, .balance])
        } else if dayToDay {
            skip.insert(.accountType)
        }

        // Skips por datos ya presentes en iCloud — no volvemos a preguntarlos.
        if hasPrefill {
            if prefilledUserName != nil { skip.insert(.name) }
            if prefilledAccountsCount > 0 {
                skip.formUnion([.accounts, .accountType, .balance])
            }
            if prefilledCurrencyCode != nil { skip.insert(.currencyName) }
            if prefilledCategoriesCount > 0 { skip.insert(.categories) }
        }

        return skip
    }

    /// Pasos visibles, en orden, tras aplicar `skipped`.
    static func effectiveSteps(skipping skipped: Set<OnboardingStep>) -> [OnboardingStep] {
        OnboardingStep.allCases.filter { !skipped.contains($0) }
    }

    /// Primer paso efectivo — el valor inicial correcto de `currentStep`.
    /// Cae a `.name` defensivamente si todo estuviera saltado (no ocurre:
    /// `.purpose`/`.confirmation` siempre visibles).
    static func firstStep(skipping skipped: Set<OnboardingStep>) -> OnboardingStep {
        effectiveSteps(skipping: skipped).first ?? .name
    }
}
