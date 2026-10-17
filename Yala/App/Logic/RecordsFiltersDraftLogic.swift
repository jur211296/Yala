//
//  RecordsFiltersDraftLogic.swift
//  Yala
//
//  Lo que la hoja de Filtros necesita saber sin pintar nada (auditoría UX 2.2, lote 8, L8-16): si lo elegido cambió
//  desde que se abrió, si cambiar de modo borraría algo y qué dice cada sección cuando no hay nada marcado.
//

import Foundation
import SwiftData

/// Lo elegido en la hoja de Filtros, tal como se aplicaría con «Aplicar».
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
    var isExcludeMode: Bool = false
}

enum RecordsFiltersDraftLogic {

    /// La X y el gesto de cerrar preguntan solo si lo elegido difiere de lo que había al abrir. Abrir y cerrar sin
    /// tocar nada cierra sin preguntar.
    static func hasChanges(current: RecordsFiltersDraft, original: RecordsFiltersDraft?) -> Bool {
        guard let original else { return false }
        return current != original
    }

    /// Cambiar entre «Mostrar solo» y «Ocultar» vacía lo elegido: solo se pregunta si hay algo que se perdería.
    /// Con «solo gastos» puesto, el Tipo lo fija la app (`[.expense]`) y no cuenta como elegido por la persona.
    static func modeSwitchWouldClear(_ draft: RecordsFiltersDraft, isExpensesOnlyMode: Bool) -> Bool {
        let hasNatures = isExpensesOnlyMode ? false : !draft.transactionNatures.isEmpty
        return !draft.accounts.isEmpty
            || !draft.categories.isEmpty
            || !draft.subcategories.isEmpty
            || !draft.tags.isEmpty
            || !draft.needs.isEmpty
            || !draft.currencies.isEmpty
            || hasNatures
            || draft.amountCondition != .any
            || !draft.noteText.isEmpty
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
