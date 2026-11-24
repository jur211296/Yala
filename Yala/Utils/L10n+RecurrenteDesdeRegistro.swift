//
//  L10n+RecurrenteDesdeRegistro.swift
//  Yala
//
//  Textos de «Hacer recurrente» a partir de un registro (encargo del 15-nov): menú y detalle del registro, Bandeja y
//  Planificación › Pagos. En su propio fichero para no pisar `L10n.swift` con otros lotes de 2.3.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su fichero.
private func rfr(_ key: String) -> String {
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"
    let variantValue = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: "")
    if variantValue != sentinel { return variantValue }
    if let parent = resolution.parentBundle {
        let parentValue = NSLocalizedString(key, bundle: parent, value: sentinel, comment: "")
        if parentValue != sentinel { return parentValue }
    }
    let mainValue = NSLocalizedString(key, bundle: .main, value: sentinel, comment: "")
    if mainValue != sentinel { return mainValue }
    return key
}

extension L10n {
    enum RecurringFromRecord {
        /// «Hacer recurrente»: la acción del menú del registro y el nombre del botón del detalle para VoiceOver.
        static var makeRecurring: String { rfr("rfr.action.makeRecurring") }
        /// «Guardar y hacer recurrente», bajo «Guardar» (aprobar) en el borrador de la Bandeja.
        static var approveAndMakeRecurring: String { rfr("rfr.inbox.approveAndMakeRecurring") }
        /// «Desde un registro», junto a «Nuevo pago planificado».
        static var fromRecord: String { rfr("rfr.planning.fromRecord") }

        // MARK: Selector de registros

        static var pickerTitle: String { rfr("rfr.picker.title") }
        static var pickerSearchPrompt: String { rfr("rfr.picker.searchPrompt") }
        static var pickerEmpty: String { rfr("rfr.picker.empty") }
        /// «Ningún registro coincide con «x»». %@ = lo escrito en el buscador.
        static func pickerNoResults(_ query: String) -> String { String(format: rfr("rfr.picker.noResults"), query) }
        static var pickerFooter: String { rfr("rfr.picker.footer") }

        // MARK: Ya hay uno parecido

        static var choiceHeadline: String { rfr("rfr.choice.headline") }
        static var choiceBody: String { rfr("rfr.choice.body") }
        /// «Vincular a «Cloudflare»». %@ = el nombre del recurrente.
        static func choiceLink(_ name: String) -> String { String(format: rfr("rfr.choice.link"), name) }
        static var choiceCreateNew: String { rfr("rfr.choice.createNew") }
        /// «Próximo cobro: 3 dic 2026». %@ = la fecha.
        static func choiceNextDue(_ date: String) -> String { String(format: rfr("rfr.choice.nextDue"), date) }

        // MARK: Hoja corta de Nuevo registro (rediseño del 23-nov)

        /// Bajo «Más opciones…»: lo que trae el editor completo y la opción rápida no («Fecha de fin, avisos y monto variable»).
        static var quickMoreOptionsDetail: String { rfr("rfr.quick.moreOptionsDetail") }

        // MARK: Avisos

        /// «Vinculado a «Cloudflare»». %@ = el nombre del recurrente.
        static func noticeLinked(_ name: String) -> String { String(format: rfr("rfr.notice.linked"), name) }
        static var noticeCreated: String { rfr("rfr.notice.created") }
    }
}
