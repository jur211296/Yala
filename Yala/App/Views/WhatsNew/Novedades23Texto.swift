//
//  Novedades23Texto.swift
//  Yala
//
//  Los textos de Novedades 2.3 (`novedades23.*` en `Novedades23.strings`, los 16 idiomas), leídos con el idioma de la
//  app (variante → padre → main → la clave), como `L10n.HojaCuentaTarjeta`. Las tarjetas de versiones anteriores siguen
//  en `Localizable.strings`.
//

import Foundation

extension L10n {
    enum Novedades23 {
        static let tabla = "Novedades23"

        /// Las tarjetas, en el orden en que salen. La primera anuncia el iPhone Duo (decisión 118 de Jürgen, 17-nov-2026).
        static let claves = ["duo", "cards", "groups", "records", "health", "planning", "ant", "hide"]

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

        static func titulo(_ clave: String) -> String { string("novedades23.\(clave).title") }
        static func descripcion(_ clave: String) -> String { string("novedades23.\(clave).description") }
    }
}
