//
//  GroupSplitLinesEntryLogic.swift
//  Yala
//
//  Grupos B, cards 5 y 6: cuándo una pantalla ofrece «Partir» (Bandeja) o «Partir tu parte» (pantalla de éxito y detalle
//  del registro). Versión acordada: `docs/disenos/grupos-tu-parte-en-lineas/README.md`, «Versión final acordada»: solo lo
//  ve quien tiene el puente activo, y no en una sesión solo-grupos.
//
//  La puerta tiene que coincidir con la del puente (`GroupSplitLinesBridgeLogic.decide`, `gateOpen`): una pantalla que
//  ofreciera partir donde el puente no aplica la receta guardaría unas líneas que nadie convierte en registros (D5).
//
//  Lógica pura: sin SwiftData ni singletons.
//

import Foundation

enum GroupSplitLinesEntryLogic {

    struct Input: Equatable, Sendable {
        /// El puente de este grupo está activo (`BridgeModeResolver`).
        var bridgeEnabled: Bool
        /// Hay sesión privada: es el eje que mira el puente (`!hasPrivateSession` = sesión solo-grupos).
        var hasPrivateSession: Bool
        /// La shell enseña solo Grupos (sin sesión privada, o «Solo grupos» elegido): la persona no ve sus cuentas.
        var isGroupsFocusedShell: Bool
        /// Tu parte del gasto, en su divisa.
        var share: Decimal
        /// Un saldo inicial (deuda de apertura) no es la parte de ningún gasto.
        var isOpeningBalance: Bool
        /// Una venta (pagaste tú con una categoría de ingreso, cards 7 y 8) no tiene pata real ni líneas: el puente no
        /// aplica la receta (`gateOpen` lleva `!isSale`).
        var isSale: Bool = false
    }

    /// Si la pantalla ofrece partir tu parte de este gasto.
    static func offersSplit(_ input: Input) -> Bool {
        input.bridgeEnabled
            && input.hasPrivateSession
            && !input.isGroupsFocusedShell
            && !input.isOpeningBalance
            && !input.isSale
            && input.share > 0
    }

    /// La pata guarda una receta de varias líneas (no la marca de una derivada ni una de versión posterior): su categoría
    /// la pone el puente desde las líneas en cada pasada (card 6u5f).
    static func holdsRecipe(_ raw: String?) -> Bool {
        if case let .recipe(lines) = GroupSplitLinesRecipe.parse(raw) { return !lines.isEmpty }
        return false
    }

    /// En el editor de un registro, la pastilla de categoría abre «Tu parte» en vez del selector (D8 del diseño, card 6u5f):
    /// el registro es la pata que lleva la receta y el puente la aplica. Con el puente apagado o en solo-grupos la receta no
    /// se aplica (D5) y la categoría se cambia como siempre.
    static func editorCategoryOpensSplit(holdsRecipe: Bool, isTheHolder: Bool, offersSplit: Bool) -> Bool {
        holdsRecipe && isTheHolder && offersSplit
    }

    /// Con qué líneas abre la tarjeta: las de la receta guardada si las hay (el aviso de «no cuadra» o una receta que se
    /// edita), y si no una sola línea de gasto por tu parte entera con la categoría que ya tenga (card 4, decisión 5).
    static func initialLines(
        stored: GroupSplitLinesRecipe.Stored, share: Decimal, subcategoryID: UUID?, currencyCode: String
    ) -> [GroupSplitLinesRecipe.Line] {
        if case let .recipe(lines) = stored, !lines.isEmpty { return lines }
        return GroupSplitLinesEditorLogic.initialLines(share: share, subcategoryID: subcategoryID, currencyCode: currencyCode)
    }

    /// La categoría que queda en tu parte cuando las líneas son un solo gasto (lo de hoy, sin receta). `nil` si no lo son.
    static func singleExpenseSubcategoryID(_ lines: [GroupSplitLinesRecipe.Line]) -> UUID? {
        guard GroupSplitLinesRecipe.isSingleExpense(lines) else { return nil }
        return lines[0].subcategoryID
    }

    /// La categoría de la línea ancla en el Caso A: la primera de gasto. La pata real la lleva (el puente hace lo mismo).
    static func anchorSubcategoryID(_ lines: [GroupSplitLinesRecipe.Line]) -> UUID? {
        lines.first { $0.kind == .expense }?.subcategoryID
    }
}
