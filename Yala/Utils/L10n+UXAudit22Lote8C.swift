//
//  L10n+UXAudit22Lote8C.swift
//  Yala
//
//  Textos de la auditoría UX 2.2, lote 8 (buscar y filtrar registros: L8-14, L8-16 y L8-17).
//  Van en su propio fichero para no pisar `L10n.swift` con los otros lotes de la misma tanda.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es
/// `private` en su fichero. Repetirla aquí es lo que permite que este lote viva aparte.
private func l8c(_ key: String) -> String {
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
    enum UXL8C {

        // MARK: - Buscar (L8-14)

        /// Rótulo de la lista de Buscar sin texto: son los últimos registros, no resultados.
        static var searchRecent: String { l8c("search.l8.recent") }

        // MARK: - Hoja de Filtros (L8-16)

        enum Filters {
            static var discardTitle: String { l8c("filters.l8.discardTitle") }
            static var discardMessage: String { l8c("filters.l8.discardMessage") }
            static var keepChoosing: String { l8c("filters.l8.keepChoosing") }
            static var discard: String { l8c("filters.l8.discard") }

            static var switchToExcludeTitle: String { l8c("filters.l8.switchToExcludeTitle") }
            static var switchToIncludeTitle: String { l8c("filters.l8.switchToIncludeTitle") }
            static var switchMessage: String { l8c("filters.l8.switchMessage") }
            static var switchConfirm: String { l8c("filters.l8.switchConfirm") }

            /// En «Ocultar» no está la fila Tipo: dice dónde se elige.
            static var typeLivesInShowOnly: String { l8c("filters.l8.typeLivesInShowOnly") }

            static var amountTitle: String { l8c("filters.l8.amountTitle") }
            static var amountNeedsOneCurrency: String { l8c("filters.l8.amountNeedsOneCurrency") }

            // Lo que dice cada sección sin nada marcado. En «Mostrar solo» se ve todo; en «Ocultar», nada se oculta.
            static var allAccounts: String { l8c("filters.l8.allAccounts") }
            static var allCategories: String { l8c("filters.l8.allCategories") }
            static var allTags: String { l8c("filters.l8.allTags") }
            static var allNeeds: String { l8c("filters.l8.allNeeds") }
            static var allCurrencies: String { l8c("filters.l8.allCurrencies") }
            static var allTypes: String { l8c("filters.l8.allTypes") }

            static var noneHiddenAccounts: String { l8c("filters.l8.noneHidden.accounts") }
            static var noneHiddenCategories: String { l8c("filters.l8.noneHidden.categories") }
            static var noneHiddenTags: String { l8c("filters.l8.noneHidden.tags") }
            static var noneHiddenNeeds: String { l8c("filters.l8.noneHidden.needs") }
            static var noneHiddenCurrencies: String { l8c("filters.l8.noneHidden.currencies") }
        }

        // MARK: - Filtros aplicados (L8-17)

        enum Chip {
            /// «Sin Ahorros USD»: la cápsula de algo que se está ocultando.
            static func excluded(_ name: String) -> String {
                String(format: l8c("filters.l8.chipExcluded"), name)
            }
            /// Valor de VoiceOver de la cápsula de algo oculto.
            static var excludedValue: String { l8c("filters.l8.chipExcludedValue") }
            /// Pista de VoiceOver: tocar la cápsula abre Filtros.
            static var openHint: String { l8c("filters.l8.chipOpenHint") }
        }
    }
}
