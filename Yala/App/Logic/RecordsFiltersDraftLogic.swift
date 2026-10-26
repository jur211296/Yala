//
//  RecordsFiltersDraftLogic.swift
//  Yala
//
//  Lo que la hoja de Filtros necesita saber sin pintar nada (auditoría UX 2.2, lote 8, L8-16): si lo elegido cambió
//  desde que se abrió y qué dice cada sección cuando no hay nada marcado. Desde el 2026-10-25 «Mostrar solo» y
//  «Ocultar» conviven: cambiar de pestaña ya no vacía nada, solo decide qué lista editas.
//

import Foundation
import SwiftData

/// Lo elegido en la hoja de Filtros, tal como se aplicaría con «Aplicar»: lo de «Mostrar solo» y lo de «Ocultar». La
/// pestaña que está a la vista no es parte de lo elegido: cambiarla no cuenta como cambio.
struct RecordsFiltersDraft: Equatable {
    var accounts: Set<PersistentIdentifier> = []
    var categories: Set<PersistentIdentifier> = []
    var subcategories: Set<PersistentIdentifier> = []
    var tags: Set<PersistentIdentifier> = []
    var needs: Set<SubcategoryNeed> = []
    var transactionNatures: Set<TransactionNature> = []
    var currencies: Set<CurrencyCode> = []
    var amountCondition: AmountFilterCondition = .any
    var noteText: String = ""
    var excludedAccounts: Set<PersistentIdentifier> = []
    var excludedCategories: Set<PersistentIdentifier> = []
    var excludedSubcategories: Set<PersistentIdentifier> = []
    var excludedTags: Set<PersistentIdentifier> = []
    var excludedNeeds: Set<SubcategoryNeed> = []
    var excludedCurrencies: Set<CurrencyCode> = []
}

enum RecordsFiltersDraftLogic {

    /// La X y el gesto de cerrar preguntan solo si lo elegido difiere de lo que había al abrir. Abrir y cerrar sin
    /// tocar nada cierra sin preguntar.
    static func hasChanges(current: RecordsFiltersDraft, original: RecordsFiltersDraft?) -> Bool {
        guard let original else { return false }
        return current != original
    }
}

/// Las secciones de la hoja de Filtros que dicen su estado junto al título.
enum RecordsFiltersSection {
    case accounts, categories, tags, needs, currencies, types

    /// Lo que dice la sección sin nada marcado, o con todo marcado en «Mostrar solo»: en ese modo se ve todo; en
    /// «Ocultar», nada se oculta. Antes era «(Todos)» y «(Nada)» en todas las secciones (L8-16).
    func emptyStatus(isExcludeMode: Bool) -> String {
        typealias Copy = L10n.UXL8C.Filters
        if isExcludeMode {
            switch self {
            case .accounts: return Copy.noneHiddenAccounts
            case .categories: return Copy.noneHiddenCategories
            case .tags: return Copy.noneHiddenTags
            case .needs: return Copy.noneHiddenNeeds
            case .currencies: return Copy.noneHiddenCurrencies
            // Tipo no se pinta en «Ocultar» (no se puede ocultar un tipo); si algún día se pinta, dice lo que filtra.
            case .types: return Copy.allTypes
            }
        }
        switch self {
        case .accounts: return Copy.allAccounts
        case .categories: return Copy.allCategories
        case .tags: return Copy.allTags
        case .needs: return Copy.allNeeds
        case .currencies: return Copy.allCurrencies
        case .types: return Copy.allTypes
        }
    }
}
