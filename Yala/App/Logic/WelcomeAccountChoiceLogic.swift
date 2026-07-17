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

    /// Sub-opciones de "Ya tengo cuenta". `cloudSignIn` = Apple; `googleSignIn` = Google
    /// (sesión 2 — mismo gate: ambas solo con backend configurado y fuera de uitest).
    enum ExistingOption: Equatable, CaseIterable {
        case restoreICloud
        case cloudSignIn
        case googleSignIn
    }

    /// `remoteCloudEnabled`/`remoteOnboardingChoiceEnabled` = flags remote-config (DIFERIDOS #34,
    /// §j.1): la card born-cloud exige AMBOS (el sub-flag de elección es un escalón POSTERIOR del
    /// rollout del flag padre). Kill-switch = corta la ENTRADA: sin flag remoto no hay alta nueva.
    static func visibleNewOptions(
        isConfigured: Bool,
        isUITest: Bool,
        bornCloudEnabled: Bool,
        remoteCloudEnabled: Bool,
        remoteOnboardingChoiceEnabled: Bool
    ) -> [NewOption] {
        var options: [NewOption] = [.privateAccount]
        if isConfigured && !isUITest && bornCloudEnabled
            && remoteCloudEnabled && remoteOnboardingChoiceEnabled {
            options.append(.cloudAccount)
        }
        return options
    }

    /// `remoteCloudEnabled` (DIFERIDOS #34): con el kill-switch OFF las cards de sign-in nube se
    /// ocultan (bypass a restore, = prod DARK de hoy). Residual ratificado por el owner: un usuario
    /// nube que REINSTALA bajo el kill no ve la card → no re-entra hasta re-encendido.
    static func visibleExistingOptions(
        isConfigured: Bool,
        isUITest: Bool,
        remoteCloudEnabled: Bool
    ) -> [ExistingOption] {
        var options: [ExistingOption] = [.restoreICloud]
        if isConfigured && !isUITest && remoteCloudEnabled {
            options += [.cloudSignIn, .googleSignIn]
        }
        return options
    }

    /// Bypass del sub-chooser: con una sola opción visible se navega directo a ella.
    static func bypass<Option>(_ options: [Option]) -> Option? {
        options.count == 1 ? options.first : nil
    }
}
