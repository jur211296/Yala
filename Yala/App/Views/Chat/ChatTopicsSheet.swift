//
//  ChatTopicsSheet.swift
//  Yala
//
//  Sheet con 10 sugerencias de conversación en lista vertical scrolleable.
//  Tap en una pregunta cierra el sheet y la envía al chat.
//

import SwiftUI

struct ChatTopicsSheet: View {

    let suggestions: [ChatSuggestion]
    let isLoading: Bool
    let onSelect: (ChatSuggestion) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.sm) {
                    if suggestions.isEmpty && isLoading {
                        ForEach(0..<5, id: \.self) { _ in
                            SkeletonPlaceholder(height: 56)
                        }
                    } else {
                        ForEach(suggestions) { suggestion in
                            topicChip(suggestion)
                        }
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .navigationTitle(L10n.Chat.Topics.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
            }
            .onAppear { TelemetryService.track(.chatTopicsSheetOpened) }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private func topicChip(_ suggestion: ChatSuggestion) -> some View {
        Button {
            onSelect(suggestion)
            dismiss()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text(suggestion.text)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(DS.Spacing.md)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
