//
//  CuentasCategoriasLote09Logic.swift
//  Yala
//
//  Lote 09 de las mejoras necesarias 2.3 (zona 39: cuentas, categorías, etiquetas y divisas). Lo que decide qué se ve
//  va aquí, aparte de las vistas, para fijarlo con tests (`CuentasCategoriasNecesariasLote09Tests`).
//

import Foundation
import SwiftData

// MARK: - Punto 1 · Tipo de cambio sin monedas secundarias

@MainActor
enum ExchangeRatesSectionLogic {
    /// Las divisas con fila en «Tipo de cambio» de Moneda: las secundarias que la persona eligió, por nombre. Sin ninguna,
    /// ninguna fila (queda «Ver todas»): antes salían las dos primeras del catálogo, que nadie había elegido.
    static func inlineCurrencies(secondary: Set<CurrencyCode>) -> [CurrencyCode] {
        secondary.sorted { $0.localizedName < $1.localizedName }
    }
}

// MARK: - Punto 4 · El formulario de etiqueta

/// Los colores de la paleta de etiquetas (`Tag.defaultColors`), para nombrarlos: el formulario decía
/// «Seleccionado: #5E5CE6» y VoiceOver leía «Color #FF9F0A». El nombre sigue al hex, que es como pinta la etiqueta el
/// resto de la app (`Color(hex:)`). Un hex fuera de la paleta (elegido con el selector de color) es un color propio.
nonisolated enum TagPaletteColor: String, CaseIterable {
    case orange = "#FF9F0A"
    case green = "#30D158"
    case blue = "#0A84FF"
    case pink = "#FF375F"
    case indigo = "#5E5CE6"
    case yellow = "#FFD60A"
    case cyan = "#64D2FF"
    case purple = "#BF5AF2"
    case oceanBlue = "#32ADE6"
    case coral = "#FF6482"
    case brown = "#AC8E68"
    case red = "#FF453A"
    case turquoise = "#66D4CF"
    case lavender = "#DA8FFF"
    case skyBlue = "#7EC8E3"

    init?(hex: String) {
        self.init(rawValue: hex.uppercased())
    }
}

nonisolated enum TagNameLimit {
    /// El largo máximo del nombre de una etiqueta (lo corta el formulario y lo exige `TagFormViewModel.isNameValid`).
    static let maxLength = 20
    /// Desde cuántos caracteres el formulario enseña el contador: antes no hace falta.
    static let showCountFrom = 15

    enum Caption: Equatable {
        /// «17 de 20».
        case count(Int)
        /// «20 de 20: el resto no cabe».
        case limitReached
    }

    static func caption(forLength length: Int) -> Caption? {
        if length >= maxLength { return .limitReached }
        if length >= showCountFrom { return .count(length) }
        return nil
    }
}

// MARK: - Punto 3 · La categoría nueva que no se guardó

/// El «+» de Categorías inserta la categoría antes de que se escriba nada, y guardar su primera subcategoría guarda el
/// contexto entero: si la app se cierra ahí, la categoría queda guardada SIN NOMBRE (el nombre solo se escribe al
/// guardarla). Mientras el formulario de una categoría nueva está abierto, este teléfono lleva una marca; guardar o
/// descartar la retira. Si la marca sigue puesta cuando no hay ningún formulario abierto (al abrir Categorías o al
/// arrancar), el borrador quedó abandonado y se borra.
@MainActor
enum NewCategoryDraftMark {
    static let key = "categories.unsavedNewCategoryDraft"

    static func arm(defaults: UserDefaults = .standard) { defaults.set(true, forKey: key) }
    static func clear(defaults: UserDefaults = .standard) { defaults.removeObject(forKey: key) }
    static func isArmed(defaults: UserDefaults = .standard) -> Bool { defaults.bool(forKey: key) }

    /// Si una categoría es el borrador abandonado: sin nombre (nadie puede guardar una así desde la app), creada por la
    /// persona y sin nada que dependa de ella. Una con registros, presupuestos o líneas del flujo de caja se queda: lo
    /// suyo no se borra por una marca.
    nonisolated static func isAbandonedDraft(
        name: String, isSystem: Bool, isDefaultSeed: Bool, hasLinkedData: Bool
    ) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSystem && !isDefaultSeed && !hasLinkedData
    }

    /// Borra los borradores abandonados si la marca está puesta, y la retira. Devuelve cuántas categorías borró.
    /// Sin marca no mira nada.
    @discardableResult
    static func sweepIfArmed(in context: ModelContext, defaults: UserDefaults = .standard) -> Int {
        guard isArmed(defaults: defaults) else { return 0 }
        let categories: [Category]
        do {
            categories = try context.fetch(FetchDescriptor<Category>())
        } catch {
            #if DEBUG
            print("NewCategoryDraftMark: Error fetching categories: \(error)")
            #endif
            return 0
        }
        let drafts = categories.filter { category in
            let subcategories = category.subcategories ?? []
            let hasLinkedData = !(category.transactions ?? []).isEmpty
                || !(category.budgets ?? []).isEmpty
                || !(category.cashFlowLines ?? []).isEmpty
                || subcategories.contains { !($0.transactions ?? []).isEmpty }
            return isAbandonedDraft(
                name: category.name, isSystem: category.isSystem,
                isDefaultSeed: category.isDefaultSeed, hasLinkedData: hasLinkedData
            )
        }
        guard !drafts.isEmpty else {
            clear(defaults: defaults)
            return 0
        }
        for draft in drafts {
            for subcategory in draft.subcategories ?? [] {
                context.delete(subcategory)
            }
            context.delete(draft)
        }
        do {
            try context.save()
            clear(defaults: defaults)
            SessionState.shared.incrementDataVersion()
            return drafts.count
        } catch {
            #if DEBUG
            print("NewCategoryDraftMark: Error deleting abandoned drafts: \(error)")
            #endif
            context.rollback()
            return 0
        }
    }
}
