//
//  ChatGreetingBubble.swift
//  Yala
//
//  La burbuja del saludo sola, cuando el servicio no responde y el chat enseña su aviso debajo. Fue el saludo con las
//  sugerencias dentro (ticket ai-chat-reads-heavier-than-a-messaging-app) hasta el lote 14. Con Yala IA disponible, el
//  chat vacío es `ChatInicioGreeting` (el saludo y tres botones, encargo del 17-nov); hasta ese día lo era
//  `ChatTwoUsesGreeting`, con cada cosa en su ficha.
//

import SwiftUI

struct ChatGreetingBubble: View {

    let suggestions: [ChatSuggestion]
    /// Mientras se preparan las sugerencias, la burbuja lo dice en su sitio en vez de enseñar líneas vacías.
    let isPreparing: Bool
    let onSelect: (ChatSuggestion) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.none) {
                Text(L10n.Chat.greeting)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)

                if isPreparing {
                    Divider()
                        .padding(.leading, DS.Spacing.lg)
                    preparingRow
                } else {
                    ForEach(suggestions) { suggestion in
                        Divider()
                            .padding(.leading, DS.Spacing.lg)
                        suggestionLine(suggestion)
                    }
                }
            }
            .background(.thCard)
            .clipShape(ChatBubbleShape())

            Spacer(minLength: DS.Spacing.xxxl)
        }
    }

    private func suggestionLine(_ suggestion: ChatSuggestion) -> some View {
        Button {
            onSelect(suggestion)
        } label: {
            Text(suggestion.text)
                .font(DS.Typography.bodyBold)
                .foregroundStyle(.thPrimaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat_suggestion")
    }

    private var preparingRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            ProgressView()
                .controlSize(.small)
            Text(L10n.Chat.preparingAI)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
}
