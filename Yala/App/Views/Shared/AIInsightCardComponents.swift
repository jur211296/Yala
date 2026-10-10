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

    /// Card de error AI con icon warning + texto caption. Recibe el MOTIVO, no un texto: un `String` aquí dejaba
    /// pasar `error.localizedDescription`, en inglés con la app en cualquier idioma.
    @ViewBuilder
    static func errorCard(_ failure: AIInsightFailure) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(DS.Semantic.warningForeground)
            Text(message(for: failure))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
    }

    /// Lo que dice la tarjeta para cada motivo de fallo, en el idioma de la app. Lo comparten Resumen, Distribución
    /// y Tendencias.
    static func message(for failure: AIInsightFailure) -> String {
        switch failure {
        case .offline: L10n.Insights.aiErrorOffline
        case .timeout: L10n.Chat.errorTimeout
        case .dailyLimit: L10n.Insights.aiErrorDailyLimit
        case .tooManyRequests: L10n.Insights.aiErrorTooManyRequests
        case .proRequired: L10n.Insights.aiErrorProRequired
        case .generic: L10n.Chat.errorGeneric
        }
    }

    /// Renderiza markdown con fallback al texto plano si el parse falla.
    static func markdownAttributed(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}
