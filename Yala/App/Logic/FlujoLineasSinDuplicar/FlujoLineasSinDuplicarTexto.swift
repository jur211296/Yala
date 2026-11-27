//
//  FlujoLineasSinDuplicarTexto.swift
//  Yala
//
//  Los textos de «una línea por cosa» del flujo de caja (`flujoLineasSinDuplicar.*` en `FlujoLineasSinDuplicar.strings`,
//  los 16 idiomas), leídos con el idioma de la app (variante → padre → main → la clave), como `L10n.FlujoCrearPlan`.
//

import Foundation

extension L10n {
    enum FlujoLineasSinDuplicar {
        static let tabla = "FlujoLineasSinDuplicar"

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

        private static func s(_ key: String) -> String { string("flujoLineasSinDuplicar.\(key)") }

        /// En «Agregar línea › Desde mis gastos», la fila de lo que ya tiene línea.
        static var enTuPlan: String { s("enTuPlan") }

        /// Las claves que lee el código (la prueba de textos las compara con la tabla).
        static let claves = ["flujoLineasSinDuplicar.enTuPlan"]
    }
}
