//
//  OnboardingNextEnablementTests.swift
//  YalaTests
//
//  Habilitación del botón "Siguiente"/"Continuar" del onboarding
//  (`OnboardingNextEnablement.isNextDisabled`). Pure-logic, sin contexto ni
//  singletons → no requiere `@Suite(.serialized)`.
//
//  Nació como regresión del botón "Continuar" muerto en el modo "Solo grupos"
//  (fix 2.0.5). Ese modo se retiró del onboarding el 2026-09-10 (ADR 2026-09-09 §7)
//  y sus casos se fueron con él; lo que queda fija qué pasos exigen entrada.
//

import Foundation
import Testing

@testable import Yala

struct OnboardingNextEnablementTests {

    /// Helper: valores por defecto "todo vacío / tipo inválido" para aislar el
    /// campo bajo prueba en cada caso.
    private func disabled(
        step: OnboardingStep,
        userName: String = "",
        accountName: String = "",
        isAccountTypeValid: Bool = false,
        initialBalanceText: String = ""
    ) -> Bool {
        OnboardingNextEnablement.isNextDisabled(
            step: step,
            userName: userName,
            accountName: accountName,
            isAccountTypeValid: isAccountTypeValid,
            initialBalanceText: initialBalanceText
        )
    }

    // MARK: - .currencyName

    @Test func currencyName_emptyAccountName_isDisabled() {
        // Sin nombre de cuenta → botón deshabilitado.
        #expect(disabled(step: .currencyName, accountName: "") == true)
    }

    @Test func currencyName_withAccountName_isEnabled() {
        #expect(disabled(step: .currencyName, accountName: "Mi Cuenta") == false)
    }

    @Test func currencyName_whitespaceAccountName_isDisabled() {
        // Solo espacios/newlines → cuenta como vacío.
        #expect(disabled(step: .currencyName, accountName: "   \n\t ") == true)
    }

    // MARK: - .name

    @Test func name_emptyUserName_isDisabled() {
        #expect(disabled(step: .name, userName: "") == true)
    }

    @Test func name_withUserName_isEnabled() {
        #expect(disabled(step: .name, userName: "Pia") == false)
    }

    @Test func name_whitespaceUserName_isDisabled() {
        #expect(disabled(step: .name, userName: "   ") == true)
    }

    // MARK: - .accountType

    @Test func accountType_invalid_isDisabled() {
        #expect(disabled(step: .accountType, isAccountTypeValid: false) == true)
    }

    @Test func accountType_valid_isEnabled() {
        #expect(disabled(step: .accountType, isAccountTypeValid: true) == false)
    }

    // MARK: - .balance

    @Test func balance_emptyText_isDisabled() {
        #expect(disabled(step: .balance, initialBalanceText: "") == true)
    }

    @Test func balance_withText_isEnabled() {
        #expect(disabled(step: .balance, initialBalanceText: "100") == false)
    }

    @Test func balance_whitespaceText_isDisabled() {
        #expect(disabled(step: .balance, initialBalanceText: "  ") == true)
    }

    // MARK: - Pasos sin entrada obligatoria → siempre habilitados

    @Test func nonInputSteps_alwaysEnabled() {
        for step in [OnboardingStep.purpose, .accounts, .categories, .confirmation] {
            #expect(disabled(step: step) == false, "El paso \(step.trackingName) no debe deshabilitar el botón")
        }
    }
}
