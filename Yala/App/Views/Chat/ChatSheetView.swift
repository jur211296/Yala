//
//  ChatSheetView.swift
//  Yala
//
//  Main sheet for Ask Yala chat assistant.
//

import SwiftUI
import SwiftData

struct ChatSheetView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatAssistantViewModel()
    @State private var selectedDetent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.none) {
                if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    messagesView
                }

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                if viewModel.showQuestionCounter {
                    Text(L10n.Chat.questionsRemaining(viewModel.questionsRemaining))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .padding(.top, DS.Spacing.xs)
                }

                chatInputBar
            }
            .navigationTitle(L10n.Chat.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .onAppear {
            viewModel.setContext(modelContext)
            TelemetryService.track(.chatSheetOpened)
        }
        .onDisappear {
            viewModel.saveToCache()
            TelemetryService.track(.chatSheetDismissed, parameters: [
                "hadConversation": String(!viewModel.messages.isEmpty)
            ])
        }
        .onChange(of: viewModel.messages.count) { oldCount, newCount in
            if oldCount == 0 && newCount > 0 {
                selectedDetent = .large
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48)) // A11Y-DT: decorative empty state icon
                .foregroundStyle(.tertiary)

            Text(L10n.Chat.emptySubtitle)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: DS.Spacing.sm) {
                ForEach(viewModel.suggestions) { suggestion in
                    ChatSuggestionChip(suggestion: suggestion) {
                        Task { await viewModel.sendSuggestion(suggestion) }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)

            Spacer()
        }
    }

    // MARK: - Messages

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DS.Spacing.md) {
                    ForEach(viewModel.messages) { message in
                        ChatMessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isLoading {
                        ChatLoadingIndicator()
                            .id("loading")
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    if let lastID = viewModel.messages.last?.id {
                        proxy.scrollTo(viewModel.isLoading ? "loading" as AnyHashable : lastID as AnyHashable, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Semantic.errorForeground)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(DS.Semantic.errorBackgroundSubtle)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Input Bar

    private var chatInputBar: some View {
        VStack(spacing: DS.Spacing.none) {
            Divider()

            HStack(spacing: DS.Spacing.sm) {
                TextField(L10n.Chat.inputPlaceholder, text: $viewModel.inputText, axis: .vertical)
                    .font(DS.Typography.body)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)

                Button {
                    Task { await viewModel.sendQuestion(viewModel.inputText) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28)) // A11Y-DT: send button icon
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.thAccent)
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading || !viewModel.canAskMore)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
        }
    }
}
