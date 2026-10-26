//
//  CombinedEntityFilterTests.swift
//  YalaTests
//
//  Ticket `stats-filter-segment-tap-should-ask-include-or-exclude` (opción B de Jürgen del 2026-10-12, propuesta A del
//  2026-10-25): cada dimensión de filtro guarda incluidos («Solo X») y excluidos («Sin X») a la vez. Aquí la regla pura
//  (`EntityFilter`), el estado de sesión que la sostiene y la pregunta del toque. La paridad entre pantallas vive en
//  `CombinedFiltersScreenParityTests`, en su propio fichero porque necesita un store de test compartido y `.serialized`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - La regla

@Suite("EntityFilter · incluidos y excluidos en una dimensión")
struct EntityFilterRuleTests {

    @Test func empty_lets_everything_through_including_nil() {
        let filter = EntityFilter<String>()
        #expect(!filter.isActive)
        #expect(filter.matches("a"))
        #expect(filter.matches(nil))
    }

    @Test func included_only_keeps_the_included_and_drops_nil() {
        let filter = EntityFilter(included: ["a"], excluded: [])
        #expect(filter.matches("a"))
        #expect(!filter.matches("b"))
        #expect(!filter.matches(nil), "un movimiento sin cuenta/categoría no pasa un «Solo X»")
    }

    @Test func excluded_only_drops_the_excluded_and_keeps_nil() {
        let filter = EntityFilter(included: [], excluded: ["b"])
        #expect(filter.matches("a"))
        #expect(!filter.matches("b"))
        #expect(filter.matches(nil), "un movimiento sin categoría no está oculto por «Sin X»")
    }

    @Test func both_compose_and_excluded_wins_on_overlap() {
        let filter = EntityFilter(included: ["a", "b"], excluded: ["b", "c"])
        #expect(filter.matches("a"))
        #expect(!filter.matches("b"), "en los dos: gana excluido")
        #expect(!filter.matches("c"))
        #expect(!filter.matches("d"))
    }

    @Test func matchesAny_for_tags() {
        let filter = EntityFilter(included: ["viaje"], excluded: ["trabajo"])
        #expect(filter.matchesAny(["viaje"]))
        #expect(filter.matchesAny(["viaje", "ocio"]))
        #expect(!filter.matchesAny(["viaje", "trabajo"]), "una etiqueta oculta tira el movimiento entero")
        #expect(!filter.matchesAny(["ocio"]))
        #expect(!filter.matchesAny([]))
        #expect(EntityFilter<String>(included: [], excluded: ["trabajo"]).matchesAny([]))
    }

    @Test func membership() {
        let filter = EntityFilter(included: ["a"], excluded: ["b"])
        #expect(filter.membership(of: "a") == .included)
        #expect(filter.membership(of: "b") == .excluded)
        #expect(filter.membership(of: "c") == .none)
    }
}

// MARK: - La pregunta del toque

@Suite("Tocar un segmento · qué opciones ofrece")
struct SegmentFilterChoiceLogicTests {

    @Test func offers_by_membership() {
        #expect(SegmentFilterChoiceLogic.actions(for: .none) == [.showOnly, .hide])
        #expect(SegmentFilterChoiceLogic.actions(for: .included) == [.hide, .clear])
        #expect(SegmentFilterChoiceLogic.actions(for: .excluded) == [.showOnly, .clear])
    }
}

// MARK: - El estado de sesión

/// Sobre un `SessionState` propio: no toca el compartido.
@MainActor
@Suite("SessionState · incluidos y excluidos conviven")
struct SessionStateCombinedFiltersTests {

    private func ids(_ count: Int) -> [PersistentIdentifier] {
        (0..<count).map { _ in
            Account(name: "A", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
                .persistentModelID
        }
    }

    @Test func hiding_one_dimension_keeps_the_other_dimensions() {
        let session = SessionState()
        let ids = ids(2)
        session.selectedCategoryIDs = [ids[0]]
        session.hide(.subcategory(ids[1]))
        #expect(session.selectedCategoryIDs == [ids[0]], "ocultar una subcategoría vació la categoría vista sola")
        #expect(session.excludedSubcategoryIDs == [ids[1]])
        #expect(session.hasActiveFilters)
        #expect(session.hasExcludedFilters)
    }

    @Test func the_same_value_cannot_be_in_both_lists_last_write_wins() {
        let session = SessionState()
        let ids = ids(2)
        session.selectedCategoryIDs = [ids[0], ids[1]]
        session.hide(.category(ids[1]))
        #expect(session.selectedCategoryIDs == [ids[0]])
        #expect(session.excludedCategoryIDs == [ids[1]])
        // Y al revés: verlo solo lo saca de lo oculto.
        session.selectedCategoryIDs = [ids[1]]
        #expect(session.excludedCategoryIDs.isEmpty)
        #expect(session.membership(of: .category(ids[1])) == .included)
    }

    @Test func every_dimension_hides_and_clears() {
        let session = SessionState()
        let ids = ids(4)
        let targets: [SegmentFilterTarget] = [
            .account(ids[0]), .category(ids[1]), .subcategory(ids[2]), .tag(ids[3]), .need(.optional), .currency(.usd),
        ]
        for target in targets {
            #expect(session.membership(of: target) == .none)
            session.hide(target)
            #expect(session.membership(of: target) == .excluded, "\(target)")
        }
        for target in targets {
            session.clearFilter(target)
            #expect(session.membership(of: target) == .none, "\(target)")
        }
        #expect(!session.hasExcludedFilters)
    }

    @Test func clearFilters_clears_the_hidden_too() {
        let session = SessionState()
        session.hide(.need(.essential))
        session.hide(.currency(.usd))
        session.selectedTags = Set(ids(1))
        session.clearFilters()
        #expect(!session.hasActiveFilters)
        #expect(session.excludedFilterSets == .none)
    }

    /// La hoja de Registros vuelca las dos listas ya disjuntas: en bloque, ninguna recorta a la otra con un valor
    /// intermedio.
    @Test func batch_update_does_not_trim_with_intermediate_values() {
        let session = SessionState()
        let ids = ids(2)
        session.selectedTags = [ids[0]]
        session.performBatchFilterUpdate {
            session.excludedTags = [ids[0]]   // intermedio: el mismo valor en las dos
            session.selectedTags = [ids[1]]
        }
        #expect(session.selectedTags == [ids[1]])
        #expect(session.excludedTags == [ids[0]])
    }

    @Test func forgetting_a_deleted_account_removes_it_from_the_hidden() {
        let session = SessionState()
        let ids = ids(1)
        session.hide(.account(ids[0]))
        session.forgetDeletedAccount(ids[0])
        #expect(session.excludedAccountIDs.isEmpty)
    }

    @Test func applyEntityFilters_copies_both_lists() {
        let session = SessionState()
        let ids = ids(2)
        session.selectedAccountIDs = [ids[0]]
        session.hide(.tag(ids[1]))
        session.hide(.need(.optional))
        var criteria = FilterCriteria()
        session.applyEntityFilters(to: &criteria)
        #expect(criteria.selectedAccounts == [ids[0]])
        #expect(criteria.excludedTags == [ids[1]])
        #expect(criteria.excludedNeeds == [.optional])
    }

    /// El estado que guardan y restauran los tests: lo oculto entero, de una vez.
    @Test func excludedFilterSets_roundTrips() {
        let session = SessionState()
        let ids = ids(1)
        session.hide(.account(ids[0]))
        session.hide(.currency(.eur))
        let saved = session.excludedFilterSets
        session.clearFilters()
        session.excludedFilterSets = saved
        #expect(session.excludedAccountIDs == [ids[0]])
        #expect(session.excludedCurrencies == [.eur])
    }
}
