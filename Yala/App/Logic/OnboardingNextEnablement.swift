//
//  OnboardingNextEnablement.swift
//  Yala
//
//  SSOT de la habilitación del botón "Siguiente"/"Continuar" del onboarding.
//  Pure-logic (sin SwiftUI): decide si el CTA de un paso está deshabilitado a
//  partir del estado de sus campos. Reusado por `OnboardingView` vía la computed
//  `isNextDisabled`.
//
//  Nació del bug del botón "Continuar" muerto en el modo "Solo grupos" del
//  onboarding (fix 2.0.5): en ese modo el nombre de cuenta del paso `.currencyName`
//  estaba oculto por diseño, y exigirlo atascaba el flujo. Ese modo se retiró el
//  2026-09-10 (paso 7 del rediseño de sesiones: solo-grupos es una sesión que se
//  abre desde el Welcome, no un propósito del onboarding) y con él su excepción.
//  La decisión sigue en pure-logic porque es donde la alcanza un unitario.
//
//  Patrón análogo a `OnboardingStepPlan` (misma carpeta): namespace enum con
//  funciones estáticas puras sobre `OnboardingStep`.
//

import Foundation

enum OnboardingNextEnablement {

    /// Decide si el botón "Siguiente"/"Continuar" debe estar DESHABILITADO en
    /// `step`. Solo los pasos con entrada obligatoria pueden deshabilitarlo; el
    /// resto (incl. `.purpose`, `.accounts`, `.categories`, `.confirmation`)
    /// siempre habilita (`false`).
    ///
    /// - Parameters:
    ///   - step: paso actual del flujo.
    ///   - userName: nombre del usuario (paso `.name`).
    ///   - accountName: nombre de la cuenta (paso `.currencyName`).
    ///   - isAccountTypeValid: si el tipo de cuenta seleccionado es uno válido de
    ///     control total (paso `.accountType`); en el callsite es
    ///     `fullControlAccountTypes.contains(selectedAccountType)`.
    ///   - initialBalanceText: texto del saldo inicial (paso `.balance`).
    static func isNextDisabled(
        step: OnboardingStep,
        userName: String,
        accountName: String,
        isAccountTypeValid: Bool,
        initialBalanceText: String
    ) -> Bool {
        switch step {
        case .name:
            return userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .accountType:
            return !isAccountTypeValid
        case .currencyName:
            return accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .balance:
            return initialBalanceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }
}
