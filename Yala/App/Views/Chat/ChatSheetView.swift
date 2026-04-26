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
    @Environment(\.yalaTheme) private var theme
    @State private var viewModel = ChatAssistantViewModel()
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var showAISettingsSheet = false
    @State private var showTopicsSheet = false

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
            .dismissKeyboardOnTap()
            .background(.thBackground.opacity(selectedDetent == .large ? 1 : 0))
            .navigationTitle(L10n.Chat.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "slider.horizontal.3", label: L10n.AISettings.title) {
                        showAISettingsSheet = true
                    }
                }
            }
            .sheet(isPresented: $showAISettingsSheet) {
                AIPersonalizationSheet()
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .onAppear {
            viewModel.setContext(modelContext)
            TelemetryService.track(.chatSheetOpened)
        }
        .onDisappear {
            viewModel.persistSession()
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

                    if viewModel.showContextHint {
                        Text(L10n.Chat.contextHint)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, DS.Spacing.xs)
                            .onAppear { viewModel.dismissContextHint() }
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

    // MARK: - Input Bar (Claude-style: TextField arriba, fila botones abajo)

    private var chatInputBar: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            TextField(L10n.Chat.inputPlaceholder, text: $viewModel.inputText, axis: .vertical)
                .font(DS.Typography.body)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .disabled(viewModel.isRecording || viewModel.isTranscribing)

            HStack(spacing: DS.Spacing.sm) {
                topicsButton

                Spacer()

                micButton

                sendButton
            }
        }
        .padding(DS.Spacing.md)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }

    private var topicsButton: some View {
        Button {
            showTopicsSheet = true
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "plus")
                Text(L10n.Chat.topicsButton)
            }
            .font(DS.Typography.label)
            .foregroundStyle(.thPrimaryText)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(.thBackground.opacity(0.4))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRecording || viewModel.isTranscribing)
    }

    private var micButton: some View {
        Button {
            Task { await toggleVoiceInput() }
        } label: {
            Image(systemName: viewModel.isRecording ? "mic.circle.fill" : "mic.fill")
                .font(.system(size: 24)) // A11Y-DT: input bar control
                .foregroundStyle(viewModel.isRecording ? AnyShapeStyle(DS.Semantic.errorForeground) : AnyShapeStyle(.secondary))
                .symbolEffect(.pulse, isActive: viewModel.isRecording)
        }
        .disabled(viewModel.isTranscribing || viewModel.isLoading)
    }

    private var sendButton: some View {
        Button {
            Task { await viewModel.sendQuestion(viewModel.inputText) }
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .bold)) // A11Y-DT: send icon
                .foregroundStyle(Color.contrastingText(for: theme.accent))
                .frame(width: 32, height: 32) // A11Y-DT: tap target circular
                .background(Circle().fill(theme.accent))
        }
        .disabled(
            viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || viewModel.isLoading
            || viewModel.isRecording
            || viewModel.isTranscribing
            || !viewModel.canAskMore
        )
    }

    private func toggleVoiceInput() async {
        if viewModel.isRecording {
            await viewModel.stopVoiceInput()
        } else {
            await viewModel.startVoiceInput()
        }
    }
}
