//
//  HojaCuentaTarjetaTexto.swift
//  Yala
//
//  Los textos nuevos de la hoja de una cuenta (`hojaCuenta.*` en `HojaCuentaTarjeta.strings`, los 16 idiomas), leídos
//  con el idioma de la app (variante → padre → main → la clave), como `L10n.SaludFinancieraDetalle`. Los que ya
//  existían (Facturado, Por facturar, «Paga antes del…») siguen en `Localizable.strings`.
//

import Foundation

extension L10n {
    enum HojaCuentaTarjeta {
        static let tabla = "HojaCuentaTarjeta"

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

        private static func s(_ key: String) -> String { string("hojaCuenta.\(key)") }
        private static func f(_ key: String, _ args: CVarArg...) -> String {
            String(format: s(key), locale: LanguageManager.resolved.locale, arguments: args)
        }

        /// «Próximo corte: 15 dic».
        static func proximoCorte(_ fecha: String) -> String { f("nextStatement", fecha) }
        /// Título del aviso de una tarjeta sin fechas.
        static var sinFechasTitulo: String { s("noDates.title") }
        /// Detalle del aviso de una tarjeta sin fechas.
        static var sinFechasDetalle: String { s("noDates.detail") }
        /// El botón que abre Editar para ponerlas.
        static var anadirFechas: String { s("noDates.action") }
        /// «16 % usado · 6.752,50 disponible de 8.000,00». Los tres huecos llegan ya formateados.
        static func usoDeLinea(porcentaje: String, disponible: String, limite: String) -> String {
            f("lineUsage", porcentaje, disponible, limite)
        }
    }
}
