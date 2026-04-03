//
//  ChatMessageBubble.swift
//  Yala
//
//  Chat bubble for user and assistant messages.
//

import SwiftUI

struct ChatMessageBubble: View {

    let message: ChatMessage

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: DS.Spacing.xxl) }

            Text(LocalizedStringKey(message.text))
                .font(DS.Typography.body)
                .foregroundStyle(message.role == .user ? AnyShapeStyle(Color.contrastingText(for: theme.accent)) : AnyShapeStyle(.thPrimaryText))
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(message.role == .user ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.thCard))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))

            if message.role == .assistant { Spacer(minLength: DS.Spacing.xxl) }
        }
    }
}
