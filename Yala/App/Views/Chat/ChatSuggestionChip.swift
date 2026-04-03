//
//  ChatSuggestionChip.swift
//  Yala
//
//  Tappable suggestion chip for Ask Yala empty state.
//

import SwiftUI

struct ChatSuggestionChip: View {

    let suggestion: ChatSuggestion
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: suggestion.icon)
                    .font(DS.Typography.caption)
                    .accessibilityHidden(true)

                Text(suggestion.text)
                    .font(DS.Typography.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(.thPrimaryText)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.interactive())
        }
        .buttonStyle(.plain)
    }
}
