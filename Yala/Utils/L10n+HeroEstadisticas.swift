//
//  L10n+HeroEstadisticas.swift
//  Yala
//
//  Hero de Estadísticas limpio (decisión de Jürgen del 20-nov-2026): «Tu dinero al cierre», la hoja del «?» de «Tu
//  dinero hoy» y la palabra que sustituye a «Te queda» en el Sankey y en el resumen en voz alta. En su propia tabla
//  (`HeroEstadisticas.strings`), leída con el idioma de la app como `OfertaProBeneficiosText`. «Tu dinero hoy» se lee
//  de `L10n.SaldoPanel.moneyToday`: es el mismo rótulo que el Panel.
//

import Foundation

enum HeroEstadisticasText {
    static let table = "HeroEstadisticas"

    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let fullKey = "heroEstadisticas.\(key)"
        var value = resolution.bundle.localizedString(forKey: fullKey, value: sentinel, table: table)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        return value == sentinel ? fullKey : value
    }

    /// «Tu dinero al cierre»: el rótulo de la cifra con un período que ya terminó.
    static var moneyAtClose: String { string("moneyAtClose") }

    /// La hoja del «?» de «Tu dinero hoy».
    enum Info {
        static var title: String { string("info.title") }
        static var body: String { string("info.body") }
        static var closedNote: String { string("info.closedNote") }
    }

    /// «En efectivo»: una fila del ejemplo de la hoja.
    static var exampleCash: String { string("example.cash") }

    /// «Diferencia»: lo que entró menos lo que salió, en el Sankey y en el resumen en voz alta. No es dinero que tengas.
    static var difference: String { string("flow.difference") }
}
