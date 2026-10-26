//
//  L10n+SegmentFilter.swift
//  Yala
//
//  Textos de «tocar un segmento pregunta Ver solo / Ocultar» y de los filtros que combinan las dos cosas (ticket
//  `stats-filter-segment-tap-should-ask-include-or-exclude`, propuesta A de Jürgen del 2026-10-25). En su propio
//  fichero, como los de cada lote, para no pisar `L10n.swift`.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func lsf(_ key: String) -> String {
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
    enum SegmentFilter {
        /// «Ver solo Comida».
        static func showOnly(_ name: String) -> String { String(format: lsf("filters.segment.showOnly"), name) }
        /// «Ocultar Comida».
        static func hide(_ name: String) -> String { String(format: lsf("filters.segment.hide"), name) }
        /// «Quitar el filtro»: el segmento ya estaba filtrado (visto solo u oculto).
        static var clear: String { lsf("filters.segment.clear") }
        /// «Solo Comida»: la cápsula de un filtro de «ver solo» en la barra de filtros aplicados.
        static func chipIncluded(_ name: String) -> String { String(format: lsf("filters.segment.chipIncluded"), name) }
        /// Valor de VoiceOver de esa cápsula.
        static var chipIncludedValue: String { lsf("filters.segment.chipIncludedValue") }
        /// Hoja de Filtros: «Mostrar solo» y «Ocultar» se combinan.
        static var combineHint: String { lsf("filters.segment.combineHint") }
    }
}
