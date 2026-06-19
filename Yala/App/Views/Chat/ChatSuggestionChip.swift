//
//  ChatSuggestionChip.swift
//  Yala
//
//  Tappable suggestion chip for Ask Yala empty state.
//  Estilo prominente: icono circular + texto subheadline + arrow.up der.
//

import SwiftUI

struct ChatSuggestionChip: View {

    let suggestion: ChatSuggestion
    let action: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 16, weight: .semibold)) // A11Y-DT: chip leading icon
                    .foregroundStyle(theme.accent)
                    .frame(width: 36, height: 36) // A11Y-DT: tap target del icono
                    .background(Circle().fill(theme.accent.opacity(0.15)))
                    .accessibilityHidden(true)

                Text(suggestion.text)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thPrimaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.up")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.md)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
        .buttonStyle(.plain)
    }
}
