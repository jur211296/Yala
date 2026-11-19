//
//  FlujoDetalleLineaTexto.swift
//  Yala
//
//  Los textos del detalle de una línea del flujo de caja (`flujoDetalleLinea.*` en `FlujoDetalleLinea.strings`, los 16
//  idiomas), leídos con el idioma de la app (variante → padre → main → la clave), como `L10n.FlujoCambiarLimite`.
//

import Foundation

extension L10n {
    enum FlujoDetalleLinea {
        static let tabla = "FlujoDetalleLinea"

        /// Todas las claves de la tabla (las fija `FlujoDetalleLineaTextosTests`).
        static let claves = [
            "flujoDetalleLinea.limit.expense",
            "flujoDetalleLinea.limit.income",
            "flujoDetalleLinea.change",
            "flujoDetalleLinea.change.a11y.expense",
            "flujoDetalleLinea.change.a11y.income",
            "flujoDetalleLinea.soFar.expense",
            "flujoDetalleLinea.soFar.income",
            "flujoDetalleLinea.ofLimit",
            "flujoDetalleLinea.left.expense",
            "flujoDetalleLinea.left.income",
            "flujoDetalleLinea.exceeded",
            "flujoDetalleLinea.pace",
            "flujoDetalleLinea.pace.over",
            "flujoDetalleLinea.scheduled",
            "flujoDetalleLinea.closed.expense",
            "flujoDetalleLinea.closed.income",
            "flujoDetalleLinea.diff.more",
            "flujoDetalleLinea.diff.less",
            "flujoDetalleLinea.parent.notice",
            "flujoDetalleLinea.month.previous",
            "flujoDetalleLinea.month.next",
            "flujoDetalleLinea.history.title",
            "flujoDetalleLinea.history.real.expense",
            "flujoDetalleLinea.history.real.income",
            "flujoDetalleLinea.history.limit.expense",
            "flujoDetalleLinea.history.limit.income",
            "flujoDetalleLinea.history.summary.expense",
            "flujoDetalleLinea.history.summary.income",
            "flujoDetalleLinea.history.month",
            "flujoDetalleLinea.records.title",
            "flujoDetalleLinea.records.seeInRecords",
            "flujoDetalleLinea.records.empty",
            "flujoDetalleLinea.records.scheduledDay",
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

        private static func s(_ key: String) -> String { string("flujoDetalleLinea.\(key)") }
        private static func f(_ key: String, _ args: CVarArg...) -> String {
            String(format: s(key), locale: AppLocale.current, arguments: args)
        }
        private static func lado(_ esIngreso: Bool) -> String { esIngreso ? "income" : "expense" }

        /// «Límite de noviembre» (gastos) / «Esperado en noviembre» (ingresos).
        static func limite(mes: String, esIngreso: Bool) -> String { f("limit.\(lado(esIngreso))", mes) }
        /// «Cambiar».
        static var cambiar: String { s("change") }
        /// «Cambiar el límite» / «Cambiar el monto esperado», para VoiceOver.
        static func cambiarAccesible(esIngreso: Bool) -> String { s("change.a11y.\(lado(esIngreso))") }
        /// «Llevas» / «Recibiste».
        static func llevas(esIngreso: Bool) -> String { s("soFar.\(lado(esIngreso))") }
        /// «de S/ 900».
        static func deLimite(_ limite: String) -> String { f("ofLimit", limite) }
        /// «Te quedan S/ 300» / «Falta recibir S/ 300».
        static func quedan(_ monto: String, esIngreso: Bool) -> String { f("left.\(lado(esIngreso))", monto) }
        /// «Te pasaste por S/ 120. No se proyecta más.»
        static func excedida(_ monto: String) -> String { f("exceeded", monto) }
        /// «Al ritmo de este mes llegarías a ~S/ 1,100.»
        static func ritmo(_ monto: String) -> String { f("pace", monto) }
        /// «Al ritmo de este mes llegarías a ~S/ 1,100: S/ 200 más que el límite.»
        static func ritmoSePasa(_ monto: String, exceso: String) -> String { f("pace.over", monto, exceso) }
        /// «Ya programado: S/ 150».
        static func programado(_ monto: String) -> String { f("scheduled", monto) }
        /// «Gastaste S/ 820 de S/ 900» / «Recibiste S/ 820 de S/ 900».
        static func cerrado(_ real: String, de limite: String, esIngreso: Bool) -> String {
            f("closed.\(lado(esIngreso))", real, limite)
        }
        /// «S/ 80 menos que el límite» / «S/ 80 más que el límite».
        static func diferencia(_ monto: String, esMas: Bool) -> String { f(esMas ? "diff.more" : "diff.less", monto) }

        /// «Hay S/ 500 en Comida sin subcategoría. Cuentan en el mes, no en esta línea.»
        static func anotadoEnLaMadre(_ monto: String, categoria: String) -> String { f("parent.notice", monto, categoria) }

        /// «Mes anterior» / «Mes siguiente».
        static var mesAnterior: String { s("month.previous") }
        static var mesSiguiente: String { s("month.next") }

        /// «Últimos 6 meses».
        static var seisMesesTitulo: String { s("history.title") }
        /// «Gastado» / «Recibido» y «Límite» / «Esperado», la leyenda.
        static func seisMesesReal(esIngreso: Bool) -> String { s("history.real.\(lado(esIngreso))") }
        static func seisMesesLimite(esIngreso: Bool) -> String { s("history.limit.\(lado(esIngreso))") }
        /// «En 4 de 6 meses gastaste menos que el límite.» / «… recibiste lo esperado o más.»
        static func seisMesesResumen(dentro: Int, de total: Int, esIngreso: Bool) -> String {
            f("history.summary.\(lado(esIngreso))", dentro, total)
        }
        /// «junio: S/ 820 de S/ 900», lo que VoiceOver lee de cada mes.
        static func seisMesesMes(_ mes: String, real: String, limite: String) -> String { f("history.month", mes, real, limite) }

        /// «Registros de noviembre».
        static func registrosTitulo(mes: String) -> String { f("records.title", mes) }
        /// «Ver en Registros».
        static var verEnRegistros: String { s("records.seeInRecords") }
        /// «Sin registros en noviembre.»
        static func sinRegistros(mes: String) -> String { f("records.empty", mes) }
        /// «Programado», la marca de un día de mañana en adelante.
        static var programadoDia: String { s("records.scheduledDay") }
    }
}
