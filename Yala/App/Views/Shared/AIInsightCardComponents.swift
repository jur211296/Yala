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
    ///
    /// `onRetry` pone el botón «Reintentar» cuando el fallo se arregla volviendo a pedir. Sin él, la tarjeta decía «Intenta
    /// de nuevo» y en Resumen y Distribución no había con qué: el botón de generar ya no estaba y solo un cambio de período
    /// lo devolvía (auditoría UX 2.2 · lote 11 · B10).
    static func errorCard(_ failure: AIInsightFailure, onRetry: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(DS.Semantic.warningForeground)
                    .accessibilityHidden(true)
                Text(message(for: failure))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            // Debajo y a la izquierda: a la derecha lo tapaba el botón flotante de Yala IA.
            if let onRetry, isRetryable(failure) {
                RetryChip(action: onRetry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
    }

    /// Si volver a pedir puede salir bien. El cupo del día no: vuelve mañana.
    static func isRetryable(_ failure: AIInsightFailure) -> Bool {
        failure != .dailyLimit
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

/// El «Reintentar» de la tarjeta de error, con la forma del «Regenerar» de Tendencias.
private struct RetryChip: View {
    let action: () -> Void
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "arrow.clockwise")
                    .font(DS.Typography.caption)
                    .accessibilityHidden(true)
                Text(L10n.Action.retry)
                    .font(DS.Typography.caption)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(theme.accent.opacity(0.12))
            .foregroundStyle(theme.accent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityIdentifier("ai_insight_retry")
    }
}
