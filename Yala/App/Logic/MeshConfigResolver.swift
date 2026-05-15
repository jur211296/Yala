//
//  MeshConfigResolver.swift
//  Yala
//

import SwiftUI

enum MeshConfigResolver {
    /// Distingue Liquid Glass vs Translucent (mismo accent electricIndigo)
    /// por igualdad de struct; Rosa / Teal por accent color.
    static func config(for theme: YalaTheme) -> (variant: TranslucentVariant, isLiquidGlass: Bool)? {
        guard theme.usesMaterial else { return nil }
        if theme == .liquidGlass { return (.indigo, true) }
        if theme.accent == .hotPink { return (.rosa, false) }
        if theme.accent == .priorityNeed { return (.teal, false) }
        return (.indigo, false)
    }
}
