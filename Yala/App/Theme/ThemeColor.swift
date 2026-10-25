//
//  ThemeColor.swift
//  Yala
//
//  ShapeStyle wrapper that resolves to the active theme's color.
//  Use `.thBackground`, `.thCard`, etc. in .foregroundStyle(), .background(), .fill(), .stroke().
//  When a raw Color is needed (variables, arrays, listRowBackground), use @Environment(\.yalaTheme).
//

import SwiftUI

// MARK: - ThemeColor

struct ThemeColor: ShapeStyle, @unchecked Sendable {
    let keyPath: KeyPath<YalaTheme, Color>

    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        environment.yalaTheme[keyPath: keyPath]
    }
}

// MARK: - Static Accessors

extension ShapeStyle where Self == ThemeColor {
    static var thBackground: ThemeColor { ThemeColor(keyPath: \.background) }
    static var thCard: ThemeColor { ThemeColor(keyPath: \.card) }
    static var thCardBorder: ThemeColor { ThemeColor(keyPath: \.cardBorder) }
    static var thPrimaryText: ThemeColor { ThemeColor(keyPath: \.primaryText) }
    static var thSecondaryText: ThemeColor { ThemeColor(keyPath: \.secondaryText) }
    static var thAccent: ThemeColor { ThemeColor(keyPath: \.accent) }
    /// El color del tema como texto o icono (card 1c9w). Para RELLENOS, `thAccent`.
    static var thAccentText: ThemeColor { ThemeColor(keyPath: \.accentText) }
    /// Texto o icono ENCIMA de un relleno `thAccent` (card lbcr). Nunca `.white` a mano sobre el acento.
    static var thOnAccent: ThemeColor { ThemeColor(keyPath: \.onAccent) }
    static var thAccentSecondary: ThemeColor { ThemeColor(keyPath: \.accentSecondary) }
    static var thIncome: ThemeColor { ThemeColor(keyPath: \.income) }
    static var thExpense: ThemeColor { ThemeColor(keyPath: \.expense) }
    static var thTagChip: ThemeColor { ThemeColor(keyPath: \.tagChip) }
    static var thTransfer: ThemeColor { ThemeColor(keyPath: \.transfer) }
    static var thToolbarIcon: ThemeColor { ThemeColor(keyPath: \.toolbarIcon) }
    static var thDestructive: ThemeColor { ThemeColor(keyPath: \.destructive) }
    static var thPriorityNeed: ThemeColor { ThemeColor(keyPath: \.priorityNeed) }
    static var thEssentialNeed: ThemeColor { ThemeColor(keyPath: \.essentialNeed) }
    static var thOptionalNeed: ThemeColor { ThemeColor(keyPath: \.optionalNeed) }
}
