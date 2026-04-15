//
//  ScrollViewGlassEdges.swift
//  Yala
//
//  Helpers para modernizar ScrollViews a las APIs iOS 26:
//  - `.contentMargins(for: .scrollContent)` mueve scroll indicators al borde físico
//    en vez del borde del contenido con `.padding(.horizontal)`.
//  - `.scrollEdgeEffectStyle(_:for:)` aplica transición glass (o borde nítido) al
//    colapsar la nav bar large → inline.
//
//  Uso:
//      ScrollView {
//          // contenido sin .padding(.horizontal)
//      }
//      .scrollViewGlassEdges()                              // soft .top, DS.Spacing.lg
//      .scrollViewGlassEdges(horizontalMargin: DS.Spacing.xxl)
//      .scrollViewHardEdges()                               // tablas Comparativa / Reports
//
//  Complemento: aplicar `.scrollClipDisabled()` manualmente DESPUÉS de este helper cuando
//  el ScrollView contenga elementos glass que overflow del viewport (chips con morphing,
//  carousels con sombras). Ver UI-PATTERNS.md sección "iOS 26 Glass".
//

import SwiftUI

extension View {
    /// Aplica al ScrollView: márgenes modernos `scrollContent` + transición glass soft
    /// al colapsar nav bar.
    ///
    /// Reemplaza el patrón legacy de `.padding(.horizontal, DS.Spacing.lg)` al VStack
    /// interno. Los scroll indicators quedan al borde físico del ScrollView, no al
    /// borde del contenido.
    ///
    /// - Parameters:
    ///   - horizontalMargin: Margen horizontal del contenido. Default `DS.Spacing.lg`.
    ///   - verticalMargin: Margen vertical del contenido. Default `0` (el ScrollView
    ///     usa el safe area top/bottom del sistema).
    ///   - edges: Bordes a los que aplicar el edge effect. Default `.top`.
    ///   - style: Estilo del edge effect. Default `.soft`.
    func scrollViewGlassEdges(
        horizontalMargin: CGFloat = DS.Spacing.lg,
        verticalMargin: CGFloat = 0,
        edges: Edge.Set = .top,
        style: ScrollEdgeEffectStyle = .soft
    ) -> some View {
        self
            .contentMargins(.horizontal, horizontalMargin, for: .scrollContent)
            .contentMargins(.vertical, verticalMargin, for: .scrollContent)
            .scrollEdgeEffectStyle(style, for: edges)
    }

    /// Variante de `scrollViewGlassEdges` con borde nítido (`.hard`) — recomendado para
    /// tablas de datos densas (Comparativa de FinancialReportView, tablas de CashFlow)
    /// donde el soft gradient difumina números que deben ser precisos.
    ///
    /// - Parameter horizontalMargin: Margen horizontal del contenido. Default `DS.Spacing.lg`.
    func scrollViewHardEdges(
        horizontalMargin: CGFloat = DS.Spacing.lg
    ) -> some View {
        let edges: Edge.Set = .top
        return self
            .contentMargins(.horizontal, horizontalMargin, for: .scrollContent)
            .scrollEdgeEffectStyle(.hard, for: edges)
    }
}
