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
    static var thAccentSecondary: ThemeColor { ThemeColor(keyPath: \.accentSecondary) }
    static var thIncome: ThemeColor { ThemeColor(keyPath: \.income) }
    static var thExpense: ThemeColor { ThemeColor(keyPath: \.expense) }
    static var thTagChip: ThemeColor { ThemeColor(keyPath: \.tagChip) }
    static var thTransfer: ThemeColor { ThemeColor(keyPath: \.transfer) }
    static var thToolbarIcon: ThemeColor { ThemeColor(keyPath: \.toolbarIcon) }
    static var thDestructive: ThemeColor { ThemeColor(keyPath: \.destructive) }
    static var thPriorityNature: ThemeColor { ThemeColor(keyPath: \.priorityNature) }
    static var thEssentialNature: ThemeColor { ThemeColor(keyPath: \.essentialNature) }
    static var thOptionalNature: ThemeColor { ThemeColor(keyPath: \.optionalNature) }
}
