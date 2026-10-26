//
//  ExcludedFilterChips.swift
//  Yala
//
//  Las cápsulas «Sin X» de la barra de filtros aplicados: una por cada valor oculto, con el contorno rojo de lo
//  oculto y su ✕. Conviven con las de «Solo X» de la misma barra (propuesta A de Jürgen, 2026-10-25). Las pintan
//  igual el Panel (`PanelFilterControlBar`) y Estadísticas, Registros e Informes (`FilterControlBar`): el mismo filtro
//  global no se rotula distinto en cada pantalla.
//

import SwiftData
import SwiftUI

struct ExcludedFilterChips: View {
    let sessionState: SessionState
    let accounts: [Account]
    let categories: [Category]
    let subcategories: [Subcategory]
    let tags: [Tag]
    /// Tocar la cápsula (fuera de la ✕) abre la hoja de Filtros del host. `nil`: no hace nada.
    var onOpenFilters: (() -> Void)? = nil
    /// Tras quitar un valor (Registros recalcula a mano).
    var onFilterChange: (() -> Void)? = nil
    let namespace: Namespace.ID

    var body: some View {
        // Cuentas: cada tarjeta una vez (sus líneas van con ella, como en «Solo X»).
        let hiddenAccounts = sessionState.shownAccountSelection(sessionState.excludedAccountIDs)
        ForEach(accounts.filter { hiddenAccounts.contains($0.persistentModelID) }, id: \.persistentModelID) { account in
            FilterChipView(accountName: account.name, onClear: {
                sessionState.clearFilter(.account(account.persistentModelID))
                onFilterChange?()
            })
            .filterMembership(.excluded)
            .opensFilters(onOpenFilters)
            .glassEffectID("chip.excluded.account.\(account.persistentModelID.hashValue)", in: namespace)
        }

        ForEach(categories.filter { sessionState.excludedCategoryIDs.contains($0.persistentModelID) },
                id: \.persistentModelID) { category in
            FilterChipView(
                categoryName: category.name, iconName: category.iconName, colorHex: category.colorHex,
                onClear: {
                    sessionState.clearFilter(.category(category.persistentModelID))
                    onFilterChange?()
                }
            )
            .filterMembership(.excluded)
            .opensFilters(onOpenFilters)
            .glassEffectID("chip.excluded.category.\(category.persistentModelID.hashValue)", in: namespace)
        }

        ForEach(subcategories.filter { sessionState.excludedSubcategoryIDs.contains($0.persistentModelID) },
                id: \.persistentModelID) { subcategory in
            FilterChipView(
                subcategoryName: subcategory.name,
                iconName: subcategory.iconName,
                colorHex: (subcategory.colorHex?.isEmpty == false ? subcategory.colorHex : nil)
                    ?? subcategory.safeCategory.colorHex,
                onClear: {
                    sessionState.clearFilter(.subcategory(subcategory.persistentModelID))
                    onFilterChange?()
                }
            )
            .filterMembership(.excluded)
            .opensFilters(onOpenFilters)
            .glassEffectID("chip.excluded.subcategory.\(subcategory.persistentModelID.hashValue)", in: namespace)
        }

        ForEach(tags.filter { sessionState.excludedTags.contains($0.persistentModelID) }, id: \.persistentModelID) { tag in
            FilterChipView(tagName: tag.name, iconName: tag.iconName, colorHex: tag.colorHex, onClear: {
                sessionState.clearFilter(.tag(tag.persistentModelID))
                onFilterChange?()
            })
            .filterMembership(.excluded)
            .opensFilters(onOpenFilters)
            .glassEffectID("chip.excluded.tag.\(tag.persistentModelID.hashValue)", in: namespace)
        }

        ForEach(SubcategoryNeed.allCases.filter { sessionState.excludedNeeds.contains($0) }, id: \.rawValue) { need in
            FilterChipView(need: need, onClear: {
                sessionState.clearFilter(.need(need))
                onFilterChange?()
            })
            .filterMembership(.excluded)
            .opensFilters(onOpenFilters)
            .glassEffectID("chip.excluded.need.\(need.rawValue)", in: namespace)
        }

        ForEach(sessionState.excludedCurrencies.sorted { $0.rawValue < $1.rawValue }, id: \.self) { currency in
            FilterChipView(currencyCode: currency.rawValue, onClear: {
                sessionState.clearFilter(.currency(currency))
                onFilterChange?()
            })
            .filterMembership(.excluded)
            .opensFilters(onOpenFilters)
            .glassEffectID("chip.excluded.currency.\(currency.rawValue)", in: namespace)
        }
    }
}
