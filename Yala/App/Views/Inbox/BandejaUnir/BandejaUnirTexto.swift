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

        // MARK: Lote 3: la fila con sus fuentes, «¿Es el mismo gasto?» y «Ya registrado»

        /// «Llegó por Apple Pay, Correo»: las fuentes de un pendiente unido, para VoiceOver.
        static func llegoPor(fuentes: String) -> String {
            String(format: s("row.sources.a11y"), locale: LanguageManager.resolved.locale, fuentes)
        }
        /// «¿Es el mismo gasto?».
        static var preguntaTitulo: String { s("ask.title") }
        /// «Es el mismo».
        static var esElMismo: String { s("ask.same") }
        static var esElMismoPista: String { s("ask.same.hint") }
        /// «Son distintos».
        static var sonDistintos: String { s("ask.distinct") }
        static var sonDistintosPista: String { s("ask.distinct.hint") }
        /// «Ya registrado el 15 oct».
        static func yaRegistrado(fecha: String) -> String {
            String(format: s("recorded.title"), locale: LanguageManager.resolved.locale, fecha)
        }
        /// «Ya registrado: Wong · S/ 89.90 · 15 oct», para VoiceOver.
        static func yaRegistradoDetalle(_ resumen: String) -> String {
            String(format: s("recorded.a11y"), locale: LanguageManager.resolved.locale, resumen)
        }
        /// «Descartar».
        static var descartar: String { s("recorded.discard") }
        /// «Guardar igual».
        static var guardarIgual: String { s("recorded.saveAnyway") }
        static var guardarIgualPista: String { s("recorded.saveAnyway.hint") }

        // MARK: Lote 4: casar con un pago planificado

        /// «¿Es tu pago «Luz del Sur»?».
        static func planificadoTitulo(_ nombre: String) -> String {
            String(format: s("planned.ask.title"), locale: LanguageManager.resolved.locale, nombre)
        }
        /// «Sí, es ese pago».
        static var planificadoSi: String { s("planned.ask.yes") }
        static var planificadoSiPista: String { s("planned.ask.yes.hint") }
        /// «No es ese pago».
        static var planificadoNo: String { s("planned.ask.no") }
        static var planificadoNoPista: String { s("planned.ask.no.hint") }
        /// «Planificado: S/ 120.00 estimado · vence el 15 nov».
        static func planificadoDetalle(importe: String, fecha: String) -> String {
            String(format: s("planned.ask.detail"), locale: LanguageManager.resolved.locale, importe, fecha)
        }
        /// «S/ 120.00 estimado».
        static func importeEstimado(_ importe: String) -> String {
            String(format: s("planned.amount.estimate"), locale: LanguageManager.resolved.locale, importe)
        }
        /// «Antes S/ 120.00 estimado».
        static func antesEstimado(_ importe: String) -> String {
            String(format: s("planned.before.estimate"), locale: LanguageManager.resolved.locale, importe)
        }

        /// El nombre de cada fuente en el resumen.
        static func fuente(_ source: InboxMatchLogic.Source) -> String {
            switch source {
            case .applePay: s("source.applePay")
            case .bankNotice: s("source.bankNotice")
            case .bankEmail: s("source.bankEmail")
            case .web: s("source.web")
            case .aiConnector: s("source.ai")
            case .manual: s("source.manual")
            case .planned: L10n.Inbox.sourceScheduledPayment
            }
        }
    }
}
