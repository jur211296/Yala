//
//  L10n+ExitoGruposBandeja.swift
//  Yala
//
//  Los textos nuevos de las pantallas de éxito de Grupos y de la Bandeja con el diseño minimalista de Nuevo registro
//  (encargo del 2026-11-24). En su propia tabla (`ExitoGruposBandeja.strings`), leída con el idioma de la app como
//  `HeroEstadisticasText`. Lo que ya existía («Agregar otro gasto», «Te deben», «Gasto guardado»…) se lee de su clave.
//

import Foundation

enum ExitoGruposBandejaText {
    static let table = "ExitoGruposBandeja"

    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let fullKey = "exitoGB.\(key)"
        var value = resolution.bundle.localizedString(forKey: fullKey, value: sentinel, table: table)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        return value == sentinel ? fullKey : value
    }

    /// El título junto al check, sin signos de exclamación, como «Gasto guardado» en la personal.
    enum GroupTitle {
        static var expenseCreated: String { string("group.title.expenseCreated") }
        static var expenseUpdated: String { string("group.title.expenseUpdated") }
        static var saleCreated: String { string("group.title.saleCreated") }
        static var saleUpdated: String { string("group.title.saleUpdated") }
    }

    /// «Pagaste tú» / «Pagó Ana»: la fila de quién pagó, sin rótulo.
    static var paidByMe: String { string("group.paidByMe") }
    static func paidBy(_ name: String) -> String { String(format: string("group.paidBy"), name) }

    /// «1 registro guardado» / «3 registros guardados»: el título del éxito de guardar varios.
    static func bulkTitle(_ count: Int) -> String {
        count == 1 ? string("bulk.title.one") : String(format: string("bulk.title.many"), count)
    }
}
