//
//  LimiteTarjetaTexto.swift
//  Yala
//
//  Los textos del límite de la tarjeta en Editar cuenta (`limiteTarjeta.*` en `LimiteTarjeta.strings`, los 16 idiomas),
//  leídos con el idioma de la app (variante → padre → main → la clave), como `L10n.HojaCuentaTarjeta`.
//

import Foundation

extension L10n {
    enum LimiteTarjeta {
        static let tabla = "LimiteTarjeta"

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

        private static func s(_ key: String) -> String { string("limiteTarjeta.\(key)") }

        /// «Límite de la tarjeta»: el rótulo de la fila y el nombre del campo para VoiceOver.
        static var campo: String { s("field") }
        /// «Opcional»: lo que enseña el campo vacío.
        static var opcional: String { s("placeholder") }
        /// Lo que gana la persona al ponerlo.
        static var pie: String { s("footer") }
        /// «Aprox.: incluye lo que debes en USD, al último tipo de cambio.» Bajo el uso de línea de una tarjeta con dos
        /// monedas. El hueco llega ya formateado («USD» o «USD y EUR»).
        static func notaConversion(divisas: String) -> String {
            String(format: s("lineUsage.converted"), locale: LanguageManager.resolved.locale, divisas)
        }
    }
}
