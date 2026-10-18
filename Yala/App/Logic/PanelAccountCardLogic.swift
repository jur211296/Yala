//
//  PanelAccountCardLogic.swift
//  Yala
//
//  Lo que decide la tarjeta de cuenta del Panel sin pintar nada: su estilo según el filtro, la línea de tipo y
//  moneda, y el ancho de cada tarjeta en el carrusel. Diseño elegido por Jürgen el 2026-10-03
//  (`panel-accounts-redesign`): carrusel de tarjetas grandes, blancas con el color en el icono, y teñidas del color
//  de la cuenta cuando esa cuenta está dentro del filtro.
//

import CoreGraphics

nonisolated enum PanelAccountCardLogic {

    /// Cómo se pinta una tarjeta según el filtro de cuentas del Panel.
    enum Style: Equatable {
        /// Sin filtro sobre ella: tarjeta de siempre, el color de la cuenta solo en el icono.
        case plain
        /// La cuenta está dentro del filtro (modo incluir): rellena de su color y con «Filtrando» (UX 2.2 · L3-16).
        case tinted
        /// La cuenta está excluida (modo excluir): atenuada, con el signo menos.
        case excluded
    }

    static func style(isSelected: Bool, isExcludeMode: Bool) -> Style {
        guard isSelected else { return .plain }
        return isExcludeMode ? .excluded : .tinted
    }

    // MARK: - Qué dice el número

    /// Qué representa el importe grande de la tarjeta. Sin etiqueta el mismo sitio significaba dos cosas: en modo
    /// «solo gastos» la tarjeta enseña lo gastado en el período, no el saldo, y una tarjeta de crédito con deuda
    /// se leía como «−S/ 1,284.30» en vez de lo que es, lo que hay que pagar.
    enum AmountKind: Equatable {
        case balance
        case toPay
        case spent
    }

    static func amountKind(isExpensesOnlyMode: Bool, isCreditCard: Bool, value: Double) -> AmountKind {
        if isExpensesOnlyMode { return .spent }
        if isCreditCard && value < 0 { return .toPay }
        return .balance
    }

    /// «Por pagar» va en positivo: la etiqueta ya dice que es deuda.
    static func displayedValue(_ value: Double, kind: AmountKind) -> Double {
        kind == .toPay ? abs(value) : value
    }

    /// El equivalente en la moneda principal solo tiene sentido para un saldo (o deuda) en otra moneda: lo gastado
    /// en el período ya lo resumen las secciones de abajo.
    static func showsConversion(kind: AmountKind, accountCurrency: String, defaultCurrency: String) -> Bool {
        kind != .spent && accountCurrency != defaultCurrency
    }

    /// «Tipo · MONEDA», o solo la moneda cuando el tipo no se reconoce: mejor nada que el valor crudo guardado.
    static func subtitle(typeName: String?, currencyCode: String) -> String {
        guard let typeName, !typeName.isEmpty else { return currencyCode }
        return "\(typeName) · \(currencyCode)"
    }

    // MARK: - Tarjeta con varias divisas

    /// «Tipo · PEN · USD»: las divisas de la tarjeta en el orden de sus líneas (la principal primero).
    static func subtitle(typeName: String?, currencyCodes: [String]) -> String {
        subtitle(typeName: typeName, currencyCode: currencyCodes.joined(separator: " · "))
    }

    /// El rótulo de una línea de la tarjeta. `nil` con saldo 0: no es deuda ni saldo a favor, y una línea recién
    /// creada no puede quitarle el «Por pagar» a la tarjeta. Lo de «tarjeta de crédito» lo decide la principal, igual en
    /// todas sus líneas. En «solo gastos» el rótulo es siempre el de lo gastado.
    static func lineKind(isExpensesOnlyMode: Bool, isCreditCard: Bool, value: Double) -> AmountKind? {
        guard isExpensesOnlyMode || value != 0 else { return nil }
        return amountKind(isExpensesOnlyMode: isExpensesOnlyMode, isCreditCard: isCreditCard, value: value)
    }

    /// El rótulo de una tarjeta con varias líneas. «Por pagar» se evalúa por línea: si todas las que tienen saldo dicen
    /// lo mismo, la tarjeta lo dice una vez; si no, «Saldo» arriba y cada línea que difiere lleva el suyo.
    static func cardAmountKind(lineKinds: [AmountKind?]) -> AmountKind {
        let decided = lineKinds.compactMap { $0 }
        guard let first = decided.first, decided.allSatisfy({ $0 == first }) else { return .balance }
        return first
    }

    /// Una línea enseña su propio rótulo solo cuando no es el de la tarjeta (una en 0 nunca).
    static func showsLineLabel(lineKind: AmountKind?, cardKind: AmountKind) -> Bool {
        guard let lineKind else { return false }
        return lineKind != cardKind
    }

    /// Ancho de cada tarjeta: el 80 % del carrusel, con techo, para que siempre asome la siguiente y se vea que hay
    /// más. Lo decide el ancho del carrusel, nunca el aparato: en la columna de la cabecera del iPad sale media más.
    static let maxCardWidth: CGFloat = 320
    static let visibleFraction: CGFloat = 0.8

    static func cardWidth(containerWidth: CGFloat) -> CGFloat {
        guard containerWidth > 0 else { return maxCardWidth }
        return min(containerWidth * visibleFraction, maxCardWidth)
    }

    // MARK: - Ficha de cuenta

    /// «Filtrar por esta cuenta» en la ficha: la misma regla que el menú contextual de la tarjeta. Con la cuenta ya
    /// filtrada no hay nada que hacer, y en modo excluir «filtrar» significaría lo contrario; quitar o excluir se hace
    /// desde el chip o desde la hoja de filtros de la toolbar.
    static func showsFilterAction(isSelected: Bool, isExcludeMode: Bool) -> Bool {
        !isSelected && !isExcludeMode
    }

    /// Las cuentas de sistema (`Grupos [moneda]`) no se editan: la ficha no ofrece «Editar».
    static func canEdit(isSystemAccount: Bool) -> Bool {
        !isSystemAccount
    }

    /// La ficha se cierra sola cuando su cuenta deja de estar en el carrusel: borrada desde el formulario, o
    /// archivada al guardarlo. Leer un `@Model` borrado tumba la app, así que esto se mira antes de pintar, y por eso
    /// `isArchived` llega diferido: solo se lee cuando ya se sabe que la cuenta sigue viva.
    static func detailIsStale(isDeleted: Bool, hasContext: Bool, isArchived: @autoclosure () -> Bool) -> Bool {
        isDeleted || !hasContext || isArchived()
    }
}
