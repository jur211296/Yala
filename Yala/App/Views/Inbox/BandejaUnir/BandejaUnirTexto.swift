//
//  BandejaUnirTexto.swift
//  Yala
//
//  Los textos de «Separar» en el borrador unido (`bandejaUnir.*` en `BandejaUnir.strings`, los 16 idiomas), leídos con el
//  idioma de la app (variante → padre → main → la clave), como `L10n.LimiteTarjeta`. Tabla propia para no chocar con el
//  catálogo general.
//

import Foundation

extension L10n {
    enum BandejaUnir {
        static let tabla = "BandejaUnir"

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

        private static func s(_ key: String) -> String { string("bandejaUnir.\(key)") }

        /// «Juntamos el mismo gasto: Apple Pay · Correo del banco». El hueco llega con las fuentes ya unidas.
        static func resumen(fuentes: String) -> String {
            String(format: s("joined.summary"), locale: LanguageManager.resolved.locale, fuentes)
        }
        /// «Separar».
        static var separar: String { s("separate") }
        /// Lo que pasa al separar, para VoiceOver.
        static var separarPista: String { s("separate.hint") }

        /// El nombre de cada fuente en el resumen.
        static func fuente(_ source: InboxMatchLogic.Source) -> String {
            switch source {
            case .applePay: s("source.applePay")
            case .bankNotice: s("source.bankNotice")
            case .bankEmail: s("source.bankEmail")
            case .web: s("source.web")
            case .aiConnector: s("source.ai")
            case .manual: s("source.manual")
            }
        }
    }
}
