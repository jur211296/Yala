//
//  GroupsOnlyIntentGate.swift
//  Yala
//
//  Apple Pay y Siri no funcionan cuando Yala solo enseña grupos (decisión de Jürgen del 2026-10-27, encargo S11e). La
//  automatización de Apple Pay y «anotar con Siri» dejaban un borrador en una Bandeja que esa shell no enseña, y las
//  preguntas de Siri contestaban con finanzas que la persona no ve. Ahora dicen que hace falta Yala completo.
//
//  Vale para los dos orígenes de la shell reducida (`ShellModeLogic`): quien eligió «Solo grupos» en Ajustes oye
//  «Vuelve a Yala completo…»; quien nunca lo activó, «Actívalo…» (`UsageModeLogic.returnEntry`).
//
//  Los intents corren en el proceso de la app, así que leen las marcas de `UserDefaults.standard` igual que la shell.
//  Los atajos que ABREN la app (nuevo registro, voz, foto) no pasan por aquí: ya ofrecen activar en esa shell
//  (`AppBootstrapper.executeAction`).
//

import Foundation

nonisolated enum GroupsOnlyIntentGate {

    enum Verdict: Equatable {
        case allowed
        case blocked(UsageModeLogic.ReturnEntry)
    }

    /// La misma decisión que la shell: `.groupsFocused` bloquea.
    static func verdict(hasPrivateSession: Bool, prefersGroupsOnlyView: Bool) -> Verdict {
        switch ShellModeLogic.effective(hasPrivateSession: hasPrivateSession,
                                        prefersGroupsOnlyView: prefersGroupsOnlyView) {
        case .full:
            return .allowed
        case .groupsFocused:
            return .blocked(UsageModeLogic.returnEntry(hasPrivateSession: hasPrivateSession))
        }
    }

    /// Lee las dos marcas. `PrivateSessionMark.hasPrivateSession` es la lectura de la shell (ausente ⇒ `true`): un
    /// teléfono recién instalado sigue pudiendo usar Siri como hasta hoy.
    static func current(_ defaults: UserDefaults = .standard) -> Verdict {
        verdict(hasPrivateSession: PrivateSessionMark.hasPrivateSession(defaults),
                prefersGroupsOnlyView: GroupsOnlyViewMark.isOn(defaults))
    }

    /// El enlace que abre la vuelta (con sesión privada) o la activación (sin ella): `ContentView`, `.presentFullModeActivation`.
    static let activationDeepLink = "activate-full"

    // MARK: - Lo que se dice

    /// Lo que Siri contesta al anotar o al preguntar.
    static func messageKey(for entry: UsageModeLogic.ReturnEntry) -> String {
        switch entry {
        case .activate: return "intent.groupsOnly.activate"
        case .comeBack: return "intent.groupsOnly.comeBack"
        }
    }

    /// El cuerpo de la notificación de Apple Pay, que corre con la pantalla bloqueada y no puede enseñar otra cosa.
    static func applePayBodyKey(for entry: UsageModeLogic.ReturnEntry) -> String {
        switch entry {
        case .activate: return "intent.groupsOnly.applePay.activate"
        case .comeBack: return "intent.groupsOnly.applePay.comeBack"
        }
    }

    static let applePayTitleKey = "intent.groupsOnly.applePay.title"

    static func message(for entry: UsageModeLogic.ReturnEntry) -> String {
        NSLocalizedString(messageKey(for: entry), comment: "")
    }
}
