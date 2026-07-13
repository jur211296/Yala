//
//  WelcomeAccountChoiceLogic.swift
//  Yala
//
//  Pure-logic del Welcome Chooser de 2 niveles (decisión owner 2026-07-12):
//  qué opciones muestra cada sub-chooser y cuándo hacer bypass (una sola opción
//  visible → no se muestra pantalla intermedia).
//
//  El botón de nube se oculta con backend no configurado (prod DARK hoy) y bajo
//  UITest (SIWA no funciona en sim; determinismo de los XCUITests existentes).
//  Born-cloud ("Soy nuevo" → crear cuenta nube) está DIFERIDO a su propio
//  incremento post-I14 → `bornCloudEnabled` queda cableado a `false` en el callsite.
//

import Foundation

nonisolated enum WelcomeAccountChoiceLogic {

    /// Sub-opciones de "Soy nuevo".
    enum NewOption: Equatable, CaseIterable {
        case privateAccount
        case cloudAccount
    }

    /// Sub-opciones de "Ya tengo cuenta".
    enum ExistingOption: Equatable, CaseIterable {
        case restoreICloud
        case cloudSignIn
    }

    static func visibleNewOptions(
        isConfigured: Bool,
        isUITest: Bool,
        bornCloudEnabled: Bool
    ) -> [NewOption] {
        var options: [NewOption] = [.privateAccount]
        if isConfigured && !isUITest && bornCloudEnabled {
            options.append(.cloudAccount)
        }
        return options
    }

    static func visibleExistingOptions(isConfigured: Bool, isUITest: Bool) -> [ExistingOption] {
        var options: [ExistingOption] = [.restoreICloud]
        if isConfigured && !isUITest {
            options.append(.cloudSignIn)
        }
        return options
    }

    /// Bypass del sub-chooser: con una sola opción visible se navega directo a ella.
    static func bypass<Option>(_ options: [Option]) -> Option? {
        options.count == 1 ? options.first : nil
    }
}
