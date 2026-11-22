//
//  BandejaChipGrupoTexto.swift
//  Yala
//
//  Los textos del chip de grupo del editor de la Bandeja (`bandejaChipGrupo.*` en `BandejaChipGrupo.strings`, los 16
//  idiomas), leídos con el idioma de la app (variante → padre → main → la clave), como `L10n.LimiteTarjeta`.
//

import Foundation

extension L10n {
    enum BandejaChipGrupo {
        static let tabla = "BandejaChipGrupo"

        static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
            let sentinel = "__YALA_MISSING__"
            var value = resolution.bundle.localizedString(forKey: key, value: sentinel, table: tabla)
            if value == sentinel, let parent = resolution.parentBundle {
                value = parent.localizedString(forKey: key, value: sentinel, table: tabla)
            }
            if value == sentinel {
                value = Bundle.main.localizedString(forKey: key, value: sentinel, table: tabla)
            }
            return value == sentinel ? key : value
        }

        private static func s(_ key: String) -> String { string("bandejaChipGrupo.\(key)") }

        /// «Grupo»: el chip sin grupo elegido y su nombre para VoiceOver.
        static var chip: String { s("chip") }
        /// Lo que hace el chip, para VoiceOver.
        static var chipHint: String { s("chipHint") }
        /// «Sin grupo»: la opción del menú que vuelve a dejarlo como gasto personal.
        static var none: String { s("none") }
    }
}
