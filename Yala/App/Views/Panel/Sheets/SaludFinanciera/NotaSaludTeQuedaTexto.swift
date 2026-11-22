//
//  NotaSaludTeQuedaTexto.swift
//  Yala
//
//  Los textos de la cuarta parte de la nota de salud, «Lo que te queda» (`teQueda.*` en `NotaSaludTeQueda.strings`, los
//  16 idiomas), leídos con el idioma de la app (variante → padre → main → la clave), como `L10n.SaludFinancieraDetalle`.
//

import Foundation

extension L10n {
    enum NotaSaludTeQueda {
        static let tabla = "NotaSaludTeQueda"

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

        private static func s(_ key: String) -> String { string("teQueda.\(key)") }
        /// Con el «%» pegado a su número: «40 %» no puede partirse en dos líneas.
        private static func f(_ key: String, _ args: CVarArg...) -> String {
            String(format: s(key), locale: LanguageManager.resolved.locale, arguments: args)
                .replacingOccurrences(of: " %", with: "\u{00A0}%")
        }

        /// «Lo que te queda»: el nombre de la parte.
        static var nombre: String { s("name") }
        /// Una línea para «¿Cómo se calcula?».
        static var detalleParte: String { f("partDetail") }
        /// La explicación de la hoja de la parte.
        static var explicacion: String { f("sheetExplanation") }
        static var titularAlto: String { s("headline.high") }
        static var titularMedio: String { f("headline.mid") }
        static var titularBajo: String { s("headline.low") }
        static var titularVacio: String { s("headline.empty") }
        /// El botón de la hoja: lleva a Estadísticas, donde se ve en qué se va el dinero.
        static var boton: String { s("cta") }
        /// El mensaje breve de la tarjeta del Panel cuando esta es la parte que más sube la nota.
        static var pasoTarjeta: String { s("cardStep") }
        /// «Entró S/ 5,000 y salió S/ 4,000: te queda S/ 1,000, el 20 % de lo que entró.»
        static func fraseQueda(entro: String, salio: String, queda: String, porcentaje: Int) -> String {
            f("lead.left", entro, salio, queda, porcentaje)
        }
        /// «Entró S/ 3,000 y salió S/ 3,300: este período salió S/ 300 más de lo que entró.»
        static func fraseSePasa(entro: String, salio: String, deMas: String) -> String {
            f("lead.over", entro, salio, deMas)
        }
        /// Sin ingresos en el período.
        static var fraseSinIngresos: String { s("lead.empty") }
        /// Lo que dice la cápsula sin número.
        static var capsulaSinIngresos: String { s("capsule.empty") }
    }
}
