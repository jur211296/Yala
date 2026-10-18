//
//  ChatGreetingBubble.swift
//  Yala
//
//  Los dos saludos del chat vacío:
//  - `ChatTwoUsesGreeting`, el de siempre desde UX 2.2 · L14-4: las dos cosas que hace Yala IA, cada una en su ficha.
//  - `ChatGreetingBubble`, la burbuja sola, cuando el servicio no responde y el chat enseña su aviso debajo. Fue el
//    saludo con las sugerencias dentro (ticket ai-chat-reads-heavier-than-a-messaging-app) hasta el lote 14.
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

/// El saludo del chat vacío cuando Yala IA está disponible (UX 2.2 · L14-4, variante 3 elegida por Jürgen el
/// 2026-10-15): «Puedo hacer dos cosas por ti» y las dos, separadas y con color sólido. La rosa, apuntar un gasto, con
/// su ejemplo: nada en la pantalla decía que Yala IA también apunta gastos. La índigo, preguntar, con las sugerencias
/// como filas que se tocan (texto, flecha y la fila entera tocable), no como líneas de texto en la burbuja.
///
/// Sin degradados ni brillos (criterios de Jürgen del 2026-10-13): lo que jerarquiza es el relleno. Los rellenos son los
/// que llevan el blanco con contraste AA (`emphasisPinkFill` 5,2:1; `electricIndigo` 4,6:1).
///
/// Si el servicio no responde, el chat vuelve a `ChatGreetingBubble` con su aviso: ofrecer dos cosas que no se pueden
/// hacer sería prometer de más.
struct ChatTwoUsesGreeting: View {

    let suggestions: [ChatSuggestion]
    /// Mientras se preparan las sugerencias, la ficha de preguntar lo dice en su sitio en vez de enseñar filas vacías.
    let isPreparing: Bool
    let onSelect: (ChatSuggestion) -> Void
    /// Tocar «Apunta un gasto» abre el teclado de la caja de escribir: el gasto se escribe o se dicta ahí.
    let onLogExpense: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(L10n.UXL14.greetingTwoUses)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(.thCard)
                    .clipShape(ChatBubbleShape())
                Spacer(minLength: DS.Spacing.xxxl)
            }

            logExpenseCard
            askCard
        }
    }

    // MARK: - Apunta un gasto

    private var logExpenseCard: some View {
        Button(action: onLogExpense) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                SolidIconTile(systemName: "square.and.pencil", fill: .white.opacity(0.22))
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.UXL14.logTitle)
                        .font(DS.Typography.headline)
                    Text(L10n.UXL14.logBody)
                        .font(DS.Typography.subheadline)
                        .opacity(0.9)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            // A11Y-DM: blanco fijo sobre el relleno rosa sólido (5,2:1, AA en claro y en oscuro).
            .foregroundStyle(Color.white)
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.emphasisPinkFill, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(L10n.UXL14.logHint)
        .accessibilityIdentifier("chat_log_expense")
    }

    // MARK: - Pregunta por tus finanzas

    private var askCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            HStack(spacing: DS.Spacing.md) {
                SolidIconTile(systemName: "questionmark", fill: .white.opacity(0.22))
                Text(L10n.UXL14.askTitle)
                    .font(DS.Typography.headline)
                    // A11Y-DM: blanco fijo sobre el relleno índigo sólido (4,6:1, AA).
                    .foregroundStyle(Color.white)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.electricIndigo)

            if isPreparing {
                preparingRow
            } else {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    if index > 0 {
                        Divider()
                            .padding(.leading, DS.Spacing.lg)
                    }
                    suggestionRow(suggestion)
                }
            }
        }
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }

    private func suggestionRow(_ suggestion: ChatSuggestion) -> some View {
        Button {
            onSelect(suggestion)
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Text(suggestion.text)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.circle.fill")
                    .font(DS.Typography.title3)
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
            }
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
