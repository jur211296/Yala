//
//  MeshConfigResolver.swift
//  Yala
//
//  Pure-logic helper que mapea YalaTheme a la configuración de
//  AnimatedMeshBackground. Reactiva los mesh gradients animados para los 4
//  themes translucent (Liquid Glass free + Indigo/Rosa/Teal Pro) y permite
//  testeo determinista sin Bundle/Environment lookup.
//
//  Patrón alineado con RecordsMotivationalLogic, FilterControlBarLogic,
//  TrendInsightLogic (Yala/App/Logic/ + tests pure-logic en YalaTests/Logic/).
//

import SwiftUI

enum MeshConfigResolver {
    /// Configuración mesh derivada del theme. Retorna `nil` para themes no
    /// translucent — esos caen a la rama `hasGradient` (Light finance gradient)
    /// o solid `theme.background` en `PanelBackgroundView`.
    ///
    /// - Distinción Liquid Glass vs Translucent (ambos con accent
    ///   electricIndigo): por igualdad de struct via `theme == .liquidGlass`.
    /// - Distinción Rosa / Teal: por accent color.
    static func config(for theme: YalaTheme) -> (variant: TranslucentVariant, isLiquidGlass: Bool)? {
        guard theme.usesMaterial else { return nil }
        if theme == .liquidGlass { return (.indigo, true) }
        if theme.accent == .hotPink { return (.rosa, false) }
        if theme.accent == .priorityNeed { return (.teal, false) }
        return (.indigo, false)
    }
}
