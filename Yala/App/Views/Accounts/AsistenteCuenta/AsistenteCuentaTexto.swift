//
//  AsistenteCuentaTexto.swift
//  Yala
//
//  Los textos propios del asistente de «Nueva cuenta» (`asistenteCuenta.*` en `AsistenteCuenta.strings`, los 16
//  idiomas), leídos con el idioma de la app como `AsistenteCreacionTexto` (variante → padre → main → la clave). Las
//  preguntas que ya existían vienen de Primeros pasos (`L10n.PrimerosPasos23.Account`).
//

import Foundation

extension L10n {
    enum AsistenteCuenta {
        static let tabla = "AsistenteCuenta"

        static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
            let sentinel = "__YALA_MISSING__"
            let full = "asistenteCuenta.\(key)"
            var value = resolution.bundle.localizedString(forKey: full, value: sentinel, table: tabla)
            if value == sentinel, let parent = resolution.parentBundle {
                value = parent.localizedString(forKey: full, value: sentinel, table: tabla)
            }
            if value == sentinel {
                value = Bundle.main.localizedString(forKey: full, value: sentinel, table: tabla)
            }
            return value == sentinel ? full : value
        }

        private static func s(_ key: String) -> String { string(key) }

        /// Lo que se crea, encima del progreso: el mismo título que el formulario.
        static var titulo: String { L10n.Account.new }
        static var descartarTitulo: String { s("discard.title") }
        static var crear: String { s("create") }
        /// «Crear», a tamaños de accesibilidad: «Crear cuenta» puede no caber junto a Atrás en un iPhone SE.
        static var crearCorto: String { s("createShort") }
        static var tipoPregunta: String { s("kind.question") }
        static var tipoDetalle: String { s("kind.subtitle") }
        static var monedaDetalle: String { s("currency.subtitle") }
        static var monedaDetalleTarjeta: String { s("currency.subtitleCard") }
        static var otraMoneda: String { s("currency.other") }
        static var otraMonedaPista: String { s("currency.otherHint") }
        static var nombreRepetido: String { s("name.taken") }
        static var diaEtiqueta: String { s("day.label") }
        static var resumenPregunta: String { s("summary.question") }
        static var resumenDetalle: String { s("summary.detail") }
        static var resumenTipo: String { s("summary.type") }
        static var resumenMoneda: String { s("summary.currency") }
        static var resumenNombre: String { s("summary.name") }
        static var resumenSaldo: String { s("summary.balance") }
        static var resumenDeuda: String { s("summary.owe") }
        static var resumenCierre: String { s("summary.statement") }
        static var resumenPago: String { s("summary.payment") }
        static var resumenRecordatorio: String { s("summary.reminder") }

        /// «Día 15».
        static func dia(_ dia: Int) -> String {
            String(format: s("summary.day"), locale: LanguageManager.resolved.locale, dia)
        }
    }
}
