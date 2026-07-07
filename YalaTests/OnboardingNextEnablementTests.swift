//
//  OnboardingNextEnablementTests.swift
//  YalaTests
//
//  Habilitación del botón "Siguiente"/"Continuar" del onboarding
//  (`OnboardingNextEnablement.isNextDisabled`). Pure-logic, sin contexto ni
//  singletons → no requiere `@Suite(.serialized)`.
//
//  Regresión del bug del botón "Continuar" muerto en modo "Solo grupos": el paso
//  `.currencyName` es combinado (moneda + nombre de cuenta), pero en Solo Grupos
//  el campo de nombre está oculto y nunca se autosugiere → `accountName` queda ""
//  por diseño → exigirlo deshabilitaba el botón permanentemente. Solo reproducía
//  en device con iCloud (en sim el guard de iCloud bloquea antes de llegar al paso
//  de moneda), por eso no lo cubría ni device-qa ni XCUI.
//

import Foundation
import Testing

@testable import Yala

struct OnboardingNextEnablementTests {

    /// Helper: valores por defecto "todo vacío / tipo inválido" para aislar el
    /// campo bajo prueba en cada caso.
    private func disabled(
        step: OnboardingStep,
        groupsOnly: Bool = false,
        userName: String = "",
        accountName: String = "",
        isAccountTypeValid: Bool = false,
        initialBalanceText: String = ""
    ) -> Bool {
        OnboardingNextEnablement.isNextDisabled(
            step: step,
            groupsOnly: groupsOnly,
            userName: userName,
            accountName: accountName,
            isAccountTypeValid: isAccountTypeValid,
            initialBalanceText: initialBalanceText
        )
    }

    // MARK: - .currencyName — corazón del fix

    @Test func currencyName_groupsOnly_emptyAccountName_isEnabled() {
        // EL BUG: Solo Grupos → nombre de cuenta oculto (queda "") → debe habilitar.
        #expect(disabled(step: .currencyName, groupsOnly: true, accountName: "") == false)
    }

    @Test func currencyName_normal_emptyAccountName_isDisabled() {
        // Modo normal: sin nombre de cuenta → botón deshabilitado (comportamiento previo).
        #expect(disabled(step: .currencyName, groupsOnly: false, accountName: "") == true)
    }

    @Test func currencyName_normal_withAccountName_isEnabled() {
        #expect(disabled(step: .currencyName, groupsOnly: false, accountName: "Mi Cuenta") == false)
    }

    @Test func currencyName_groupsOnly_withAccountName_isEnabled() {
        // En Solo Grupos el nombre es irrelevante: habilitado tenga o no valor.
        #expect(disabled(step: .currencyName, groupsOnly: true, accountName: "Ignorado") == false)
    }

    @Test func currencyName_normal_whitespaceAccountName_isDisabled() {
        // Solo espacios/newlines → cuenta como vacío en modo normal.
        #expect(disabled(step: .currencyName, groupsOnly: false, accountName: "   \n\t ") == true)
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

    @Test func name_groupsOnly_stillRequiresUserName() {
        // El nombre SÍ se pide en Solo Grupos (`.name` no se salta): sigue exigido.
        #expect(disabled(step: .name, groupsOnly: true, userName: "") == true)
        #expect(disabled(step: .name, groupsOnly: true, userName: "Pia") == false)
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
            // También en Solo Grupos.
            #expect(disabled(step: step, groupsOnly: true) == false)
        }
    }
}
