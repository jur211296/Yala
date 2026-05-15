//
//  AIInsightCardComponents.swift
//  Yala
//
//  Helpers compartidos para AI Insight cards en Stats tabs (Insights, Trends,
//  Distribución). Extracción de 3 funciones byte-idénticas duplicadas
//  cross-file.
//

import SwiftUI

@MainActor
enum AIInsightCardComponents {

    /// Placeholder mientras el AI genera contenido. Reusa
    /// `L10n.Insights.analyzingData` con sparkles + pulse.
    @ViewBuilder
    static func loadingPlaceholder(accentColor: Color) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "sparkles")
                .foregroundStyle(accentColor)
                .symbolEffect(.pulse)
            Text(L10n.Insights.analyzingData)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .panelCard()
    }

    /// Card de error AI con icon warning + texto caption.
    @ViewBuilder
    static func errorCard(_ error: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(DS.Semantic.warningForeground)
            Text(error)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
    }

    /// Renderiza markdown con fallback al texto plano si el parse falla.
    static func markdownAttributed(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}
