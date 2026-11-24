//
//  L10n+SankeySubcategorias.swift
//  Yala
//
//  El botón que despliega y repliega la columna de subcategorías del Sankey de Distribución (pedido de Jürgen del
//  23-nov-2026). Tabla propia (`SankeySubcategorias.strings`), leída con el idioma de la app como
//  `HeroEstadisticasText`, para no tocar `Localizable.strings`.
//

import Foundation

enum SankeySubcategoriasText {
    static let table = "SankeySubcategorias"

    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let fullKey = "sankeySubcategorias.\(key)"
        var value = resolution.bundle.localizedString(forKey: fullKey, value: sentinel, table: table)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        return value == sentinel ? fullKey : value
    }

    /// «Ver subcategorías»: despliega la columna.
    static var show: String { string("show") }
    /// «Ver menos»: la repliega.
    static var hide: String { string("hide") }
    /// Lo que hace el botón plegado, para VoiceOver.
    static var showHint: String { string("showHint") }
    /// Lo que hace el botón desplegado, para VoiceOver.
    static var hideHint: String { string("hideHint") }
}
