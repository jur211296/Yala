//
//  FlujoCambiarLimiteTexto.swift
//  Yala
//
//  Los textos del alcance de «Monto fijo» en «Cálculo del monto» (`flujoCambiarLimite.*` en `FlujoCambiarLimite.strings`,
//  los 16 idiomas), leídos con el idioma de la app (variante → padre → main → la clave), como `L10n.FlujoDetalleMes`.
//  Nacieron con la hoja «Cambiar límite», retirada el 19-nov-2026: quedan los que «Cálculo del monto» usa.
//

import Foundation

extension L10n {
    enum FlujoCambiarLimite {
        static let tabla = "FlujoCambiarLimite"

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

        private static func s(_ key: String) -> String { string("flujoCambiarLimite.\(key)") }
        private static func f(_ key: String, _ args: CVarArg...) -> String {
            String(format: s(key), locale: AppLocale.current, arguments: args)
        }

        /// El nombre de cada alcance, con el mes elegido.
        static func alcance(_ alcance: FlujoCambiarLimiteLogica.Alcance, mes: String) -> String {
            switch alcance {
            case .soloEsteMes: f("scope.only", mes)
            case .desdeEsteMes: f("scope.from", mes)
            case .todos: s("scope.all")
            }
        }

        static var montoInvalido: String { s("invalid") }
        static var guardar: String { s("save") }

        /// Las claves que «Cálculo del monto» usa, para la prueba de que existen en los 16 idiomas.
        static let claves: [String] = ["scope.only", "scope.from", "scope.all", "invalid", "save"]
            .map { "flujoCambiarLimite.\($0)" }
    }
}
