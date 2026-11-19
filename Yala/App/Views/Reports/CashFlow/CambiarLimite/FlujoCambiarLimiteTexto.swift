//
//  FlujoCambiarLimiteTexto.swift
//  Yala
//
//  Los textos de «Cambiar límite» del flujo de caja (`flujoCambiarLimite.*` en `FlujoCambiarLimite.strings`, los 16
//  idiomas), leídos con el idioma de la app (variante → padre → main → la clave), como `L10n.FlujoDetalleMes`.
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
        private static func lado(_ esIngreso: Bool) -> String { esIngreso ? "income" : "expense" }

        /// «Cambiar límite» (gastos) / «Cambiar monto esperado» (ingresos).
        static func titulo(esIngreso: Bool) -> String { s("title.\(lado(esIngreso))") }
        /// «¿Qué meses cambian?»
        static var alcanceTitulo: String { s("scope.header") }

        /// El nombre de cada alcance, con el mes elegido.
        static func alcance(_ alcance: FlujoCambiarLimiteLogica.Alcance, mes: String) -> String {
            switch alcance {
            case .soloEsteMes: f("scope.only", mes)
            case .desdeEsteMes: f("scope.from", mes)
            case .todos: s("scope.all")
            }
        }

        static var descripcionSolo: String { s("desc.only") }
        static var descripcionDesde: String { s("desc.from") }
        /// «Conservan su ajuste propio: diciembre, enero.»
        static func conservan(_ meses: String) -> String { f("desc.from.keeps", meses) }
        static var descripcionTodos: String { s("desc.all") }

        /// El rótulo del campo del monto, según el alcance y el lado.
        static func montoRotulo(_ alcance: FlujoCambiarLimiteLogica.Alcance, mes: String, esIngreso: Bool) -> String {
            switch alcance {
            case .soloEsteMes: f("amount.only.\(lado(esIngreso))", mes)
            case .desdeEsteMes: f("amount.from.\(lado(esIngreso))", mes)
            case .todos: s("amount.all.\(lado(esIngreso))")
            }
        }

        /// «Ahora: S/ 900».
        static func ahora(_ monto: String) -> String { f("current", monto) }
        /// Qué significa un 0.
        static func cero(esIngreso: Bool) -> String { s("zero.\(lado(esIngreso))") }
        /// El mes elegido ya cerró.
        static func pasado(_ mes: String) -> String { f("past", mes) }
        /// «Así quedan».
        static var vistaPrevia: String { s("preview.header") }
        static var sinCambio: String { s("row.unchanged") }
        static var ajustePropio: String { s("row.keeps") }
        /// VoiceOver de una fila que cambia: «diciembre: de S/ 900 a S/ 1,000».
        static func filaCambia(mes: String, antes: String, despues: String) -> String {
            f("row.a11y", mes, antes, despues)
        }
        static var montoInvalido: String { s("invalid") }
        static var guardar: String { s("save") }

        /// Las claves que la hoja usa, para la prueba de que existen en los 16 idiomas.
        static let claves: [String] = [
            "title.expense", "title.income", "scope.header", "scope.only", "scope.from", "scope.all",
            "desc.only", "desc.from", "desc.from.keeps", "desc.all",
            "amount.only.expense", "amount.from.expense", "amount.all.expense",
            "amount.only.income", "amount.from.income", "amount.all.income",
            "current", "zero.expense", "zero.income", "past",
            "preview.header", "row.unchanged", "row.keeps", "row.a11y", "invalid", "save",
        ].map { "flujoCambiarLimite.\($0)" }
    }
}
