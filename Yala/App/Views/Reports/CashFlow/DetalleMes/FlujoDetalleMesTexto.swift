//
//  FlujoDetalleMesTexto.swift
//  Yala
//
//  Los textos nuevos del detalle del mes del flujo de caja (`flujoDetalleMes.*` en `FlujoDetalleMes.strings`, los 16
//  idiomas), leídos con el idioma de la app (variante → padre → main → la clave), como `L10n.HojaCuentaTarjeta`.
//

import Foundation

extension L10n {
    enum FlujoDetalleMes {
        static let tabla = "FlujoDetalleMes"

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

        private static func s(_ key: String) -> String { string("flujoDetalleMes.\(key)") }

        private static func sufijo(_ tiempo: FlujoDetalleMesLogica.Tiempo) -> String {
            switch tiempo {
            case .pasado: "past"
            case .enCurso: "current"
            case .futuro: "future"
            }
        }

        /// «Empezaste con» / «Empezarías con».
        static func empezaste(_ tiempo: FlujoDetalleMesLogica.Tiempo) -> String { s("started.\(sufijo(tiempo))") }
        /// «Entró» / «Entraría».
        static func entro(_ tiempo: FlujoDetalleMesLogica.Tiempo) -> String { s("in.\(sufijo(tiempo))") }
        /// «Salió» / «Saldría».
        static func salio(_ tiempo: FlujoDetalleMesLogica.Tiempo) -> String { s("out.\(sufijo(tiempo))") }
        /// «Terminaste con» / «Terminas con» / «Terminarías con».
        static func terminas(_ tiempo: FlujoDetalleMesLogica.Tiempo) -> String { s("end.\(sufijo(tiempo))") }
        /// Lo que falta entrar del mes en curso, debajo de lo que ya entró.
        static var faltaEntrar: String { s("leftIn") }
        /// Lo que falta salir del mes en curso, debajo de lo que ya salió.
        static var faltaSalir: String { s("leftOut") }
        /// La fila que hace cuadrar la suma con el saldo de tus cuentas.
        static var ajustes: String { s("adjustment") }
        /// «estimado», para VoiceOver en la cápsula de un mes que no ha cerrado.
        static var estimado: String { s("estimated") }
        /// «3 líneas», el valor de VoiceOver de la cabecera de una categoría.
        static func lineas(_ count: Int) -> String {
            String(format: s("group.lines"), locale: LanguageManager.resolved.locale, count)
        }
    }
}
