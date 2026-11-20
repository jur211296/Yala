//
//  WelcomeCarruselTexto.swift
//  Yala
//
//  Los textos propios de la vitrina como historias (encargo del 19-nov, `welcomeCarrusel.*` en
//  `WelcomeCarrusel.strings`, los 16 idiomas), leídos con el idioma de la app como `L10n.AsistenteCuenta`
//  (variante → padre → main → la clave).
//

import Foundation

enum WelcomeCarruselTexto {
    static let tabla = "WelcomeCarrusel"

    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let full = "welcomeCarrusel.\(key)"
        var value = resolution.bundle.localizedString(forKey: full, value: sentinel, table: tabla)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: full, value: sentinel, table: tabla)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: full, value: sentinel, table: tabla)
        }
        return value == sentinel ? full : value
    }

    /// La acción de VoiceOver que pasa a la siguiente función de la vitrina.
    static var next: String { string("next") }
    /// La que vuelve a la anterior.
    static var previous: String { string("previous") }
}
