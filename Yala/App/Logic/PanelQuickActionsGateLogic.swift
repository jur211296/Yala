//
//  PanelQuickActionsGateLogic.swift
//  Yala
//
//  Qué enseña la fila de acciones del Panel bajo el hero (card omw5, 2026-10-27). Registrar pide una cuenta activa
//  y una subcategoría visible; cuando falta algo, la fila no se queda gris en silencio: dice qué falta y ofrece la
//  salida. Sin cuentas, «Crea tu primera cuenta» (UX 2.2 · L3-10). Con cuentas y sin categorías usables,
//  «Crear categorías». La cuenta va primero: sin ella, crear categorías tampoco deja registrar.
//

import Foundation

enum PanelQuickActionsGateLogic {

    enum State: Equatable {
        /// Se puede registrar: la fila de siempre.
        case ready
        /// Ninguna cuenta activa.
        case needsAccount
        /// Hay cuenta, pero ninguna subcategoría visible que elegir al registrar.
        case needsCategories
    }

    /// ¿Hay alguna subcategoría que se pueda elegir al registrar? La misma regla que el selector
    /// (`ManualSubcategoryPickerLogic`), en gasto o en ingreso. Las de sistema —las del puente de Grupos, que se
    /// siembran visibles al crear o unirse a un grupo— no cuentan: el selector no las ofrece, y contarlas dejaba la fila
    /// en `.ready` con «Nuevo registro» sin nada que elegir y sin el «Crear categorías» (S12h, 2026-10-27).
    static func hasPickableSubcategory(_ subcategories: [Subcategory]) -> Bool {
        subcategories.contains {
            ManualSubcategoryPickerLogic.isPickable($0, for: .expense)
                || ManualSubcategoryPickerLogic.isPickable($0, for: .income)
        }
    }

    static func state(hasActiveAccount: Bool, hasVisibleSubcategory: Bool) -> State {
        guard hasActiveAccount else { return .needsAccount }
        guard hasVisibleSubcategory else { return .needsCategories }
        return .ready
    }

    /// Qué hace «Crear categorías».
    enum CreateCategoriesAction: Equatable {
        /// Sin ninguna categoría propia: crear las de siempre, como el «Sí» del onboarding.
        case seedDefaults
        /// Hay categorías propias, pero ninguna subcategoría visible (las ocultó, o no tienen subcategorías):
        /// sembrar no añadiría nada, así que se abre Ajustes › Categorías, donde se muestran o se crean.
        case openCategoriesSettings
    }

    static func createCategoriesAction(userCategoryCount: Int) -> CreateCategoriesAction {
        userCategoryCount == 0 ? .seedDefaults : .openCategoriesSettings
    }
}
