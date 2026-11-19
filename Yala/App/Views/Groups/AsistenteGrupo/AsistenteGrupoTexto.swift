//
//  AsistenteGrupoTexto.swift
//  Yala
//
//  Los textos propios del asistente de «Nuevo grupo» (`asistenteGrupo.*` en `AsistenteGrupo.strings`, los 16 idiomas),
//  con el idioma de la app (variante → padre → main → la clave), como `AsistenteCreacionTexto`, que lee otra tabla. Los
//  del contenedor («Usar formulario», «Paso 2 de 6», descartar) siguen en `AsistenteCreacionTexto`.
//

import Foundation

extension L10n {
    enum AsistenteGrupo {
        static let tabla = "AsistenteGrupo"

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

        private static func s(_ key: String) -> String { string("asistenteGrupo.\(key)") }

        /// Lo que se crea, encima del progreso: el mismo título que el formulario.
        static var titulo: String { L10n.Groups.newGroup }
        static var descartarTitulo: String { s("discard.title") }
        static var crear: String { s("create") }
        /// «Crear», a tamaños de accesibilidad: «Crear grupo» no cabe junto a Atrás en un iPhone SE.
        static var crearCorto: String { s("createShort") }

        static var nombrePregunta: String { s("name.question") }
        static var nombreDetalle: String { s("name.detail") }
        static var ideas: String { s("name.ideas") }
        static func idea(_ idea: AsistenteGrupoLogica.Idea) -> String { s("idea.\(idea.rawValue)") }

        static var iconoPregunta: String { s("icon.question") }
        static var iconoDetalle: String { s("icon.detail") }
        static var masIconos: String { s("icon.more") }
        static func iconoOpcion(_ numero: Int) -> String {
            String(format: s("icon.option"), locale: LanguageManager.resolved.locale, numero)
        }

        static var repartoPregunta: String { s("split.question") }
        static var repartoDetalle: String { s("split.detail") }
        static func repartoPista(_ tipo: SplitType) -> String { s("split.\(tipo.rawValue).hint") }

        static var deudasPregunta: String { s("debts.question") }
        static var deudasDetalle: String { s("debts.detail") }
        static var deudasSi: String { s("debts.yes") }
        static var deudasSiPista: String { s("debts.yes.hint") }
        static var deudasNo: String { s("debts.no") }
        static var deudasNoPista: String { s("debts.no.hint") }

        static var monedaPregunta: String { s("currency.question") }
        static var monedaDetalle: String { s("currency.detail") }
        static var monedaCada: String { s("currency.each") }
        static var monedaCadaPista: String { s("currency.each.hint") }
        static var monedaUna: String { s("currency.single") }
        static var monedaUnaPista: String { s("currency.single.hint") }
        static var monedaElegir: String { s("currency.pick") }

        static var resumenPregunta: String { s("summary.question") }
        static var resumenDetalle: String { s("summary.detail") }
        static var resumenNombre: String { s("summary.name") }
        static var resumenReparto: String { s("summary.split") }
        static var resumenDeudas: String { s("summary.debts") }
        static var resumenMoneda: String { s("summary.currency") }
        static var resumenIconoPista: String { s("summary.iconHint") }
    }
}
