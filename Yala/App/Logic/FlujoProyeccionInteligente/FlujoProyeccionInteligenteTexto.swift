//
//  FlujoProyeccionInteligenteTexto.swift
//  Yala
//
//  Los textos que explican en la hoja «Otros» del flujo de caja qué se proyectó como fijo y qué se dejó fuera por
//  aislado (`flujoProyeccion.*` en `FlujoProyeccionInteligente.strings`, los 16 idiomas), leídos con el idioma de la app
//  (variante → padre → main → la clave), como `L10n.FlujoDetalleLinea`.
//

import Foundation

extension L10n {
    enum FlujoProyeccion {
        static let tabla = "FlujoProyeccionInteligente"

        /// Todas las claves de la tabla (las fija `FlujoProyeccionInteligenteTextosTests`).
        static let claves = [
            "flujoProyeccion.fixed.title",
            "flujoProyeccion.fixed.desc.income",
            "flujoProyeccion.fixed.desc.expense",
            "flujoProyeccion.fixed.day",
            "flujoProyeccion.fixed.perMonth",
            "flujoProyeccion.fixed.seen",
            "flujoProyeccion.fixed.done.income",
            "flujoProyeccion.fixed.done.expense",
            "flujoProyeccion.isolated.title",
            "flujoProyeccion.isolated.desc",
            "flujoProyeccion.variable.expense",
            "flujoProyeccion.variable.income",
            "flujoProyeccion.shortHistory",
        ]

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

        private static func s(_ key: String) -> String { string("flujoProyeccion.\(key)") }
        private static func f(_ key: String, _ args: CVarArg...) -> String {
            String(format: s(key), locale: AppLocale.current, arguments: args)
        }
        private static func lado(_ esIngreso: Bool) -> String { esIngreso ? "income" : "expense" }

        /// «Lo fijo, cada mes».
        static var fijosTitulo: String { s("fixed.title") }
        /// «Ingresos que se repiten en tus registros…» / «Gastos que se repiten…».
        static func fijosDescripcion(esIngreso: Bool) -> String { s("fixed.desc.\(lado(esIngreso))") }
        /// «S/ 3,000 · día 30».
        static func fijoConDia(_ monto: String, dia: Int) -> String { f("fixed.day", monto, dia) }
        /// «S/ 400 al mes» (llega varias veces al mes).
        static func fijoAlMes(_ monto: String) -> String { f("fixed.perMonth", monto) }
        /// «En 5 de 6 meses».
        static func fijoVisto(_ vistos: Int, de total: Int) -> String { f("fixed.seen", vistos, total) }
        /// «Ya llegó este mes» / «Ya se pagó este mes».
        static func fijoYaEsta(esIngreso: Bool) -> String { s("fixed.done.\(lado(esIngreso))") }

        /// «Fuera de la proyección».
        static var aisladosTitulo: String { s("isolated.title") }
        /// «Montos grandes que no se repiten…».
        static var aisladosDescripcion: String { s("isolated.desc") }

        /// «El resto de tus gastos se proyecta por lo que gastas en un mes normal: S/ 850.»
        static func variableGastos(_ monto: String) -> String { f("variable.expense", monto) }
        /// «Los ingresos que cambian de un mes a otro no se proyectan.»
        static var variableIngresos: String { s("variable.income") }
        /// «Con menos de 3 meses de registros…».
        static func historiaCorta(meses: Int) -> String { f("shortHistory", meses) }
    }
}
