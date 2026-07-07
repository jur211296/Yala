//
//  OnboardingNextEnablement.swift
//  Yala
//
//  SSOT de la habilitación del botón "Siguiente"/"Continuar" del onboarding.
//  Pure-logic (sin SwiftUI): decide si el CTA de un paso está deshabilitado a
//  partir del estado de los campos + el modo de uso. Reusado por `OnboardingView`
//  vía la computed `isNextDisabled`.
//
//  Nace del bug del botón "Continuar" muerto en modo "Solo grupos": el paso
//  `.currencyName` es combinado (moneda + nombre de cuenta), pero en Solo Grupos
//  el campo de nombre de cuenta está OCULTO y NUNCA se autosugiere (no hay cuenta
//  personal, solo se elige la moneda) → `accountName` queda "" por diseño →
//  exigirlo dejaba el botón deshabilitado permanentemente, atascando el onboarding.
//  Solo reproduce en device con iCloud (en simulador el guard de iCloud del paso
//  Propósito bloquea ANTES de llegar a moneda), por eso escapó al QA — de ahí que
//  la decisión viva ahora en pure-logic testeable en vez de una computed de View.
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
    ///   - groupsOnly: modo "Solo grupos" (`UsageMode.groupsOnly`). En este modo
    ///     el paso `.currencyName` NO muestra campo de nombre de cuenta (no hay
    ///     cuenta personal, solo se elige la moneda) → no exigirlo.
    ///   - userName: nombre del usuario (paso `.name`).
    ///   - accountName: nombre de la cuenta (paso `.currencyName`, modo normal).
    ///   - isAccountTypeValid: si el tipo de cuenta seleccionado es uno válido de
    ///     control total (paso `.accountType`); en el callsite es
    ///     `fullControlAccountTypes.contains(selectedAccountType)`.
    ///   - initialBalanceText: texto del saldo inicial (paso `.balance`).
    static func isNextDisabled(
        step: OnboardingStep,
        groupsOnly: Bool,
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
            // Solo grupos: no hay cuenta personal, solo se elige la moneda → el
            // campo de nombre está oculto y nunca se autosugiere. Exigirlo dejaba
            // el botón "Continuar" muerto (bug 2.0.4, fix 2.0.5).
            if groupsOnly { return false }
            return accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .balance:
            return initialBalanceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }
}
