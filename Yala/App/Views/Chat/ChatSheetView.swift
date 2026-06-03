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
    @Environment(SessionState.self) private var sessionState
    @State private var viewModel = ChatAssistantViewModel()
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

                disclaimerFooter
            }
            .dismissKeyboardOnTap()
            .yalaScreenBackground(.panel)
            .navigationTitle(L10n.Chat.assistantName)
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
            .sheet(isPresented: $showTopicsSheet) {
                ChatTopicsSheet(
                    suggestions: viewModel.suggestions,
                    isLoading: viewModel.suggestionsLoading,
                    onSelect: { suggestion in
                        Task { await viewModel.sendSuggestion(suggestion) }
                    }
                )
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            viewModel.setContext(modelContext)
            TelemetryService.track(.chatSheetOpened)
            // setContext ya consume el signal persistido en UserDefaults; aquí
            // cubrimos el caso del signal in-memory llegado mientras el sheet
            // estaba abierto pero antes del primer .onChange.
            consumeChatDraftSavedSignal()
        }
        .onDisappear {
            viewModel.persistSession()
            TelemetryService.track(.chatSheetDismissed, parameters: [
                "hadConversation": String(!viewModel.messages.isEmpty)
            ])
        }
        .onChange(of: sessionState.chatDraftSavedSignal) { _, _ in
            consumeChatDraftSavedSignal()
        }
    }

    private func consumeChatDraftSavedSignal() {
        guard let signal = sessionState.chatDraftSavedSignal else { return }
        viewModel.markDraftSaved(
            messageID: signal.messageID,
            draftID: signal.draftID,
            transactionID: signal.transactionID
        )
        sessionState.chatDraftSavedSignal = nil
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                Text(daySeparatorText)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .padding(.top, DS.Spacing.md)

                // Bubble del assistant con saludo (mismo styling que ChatMessageBubble)
                HStack {
                    Text(L10n.Chat.greeting)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thPrimaryText)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(.thCard)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    Spacer(minLength: DS.Spacing.xxl)
                }
                .padding(.horizontal, DS.Spacing.lg)

                Text(L10n.Chat.dailyResetSubtitle)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.lg)

                chipsOrSkeleton
                    .padding(.horizontal, DS.Spacing.lg)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private static let timeOfDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private var daySeparatorText: String {
        "\(L10n.Chat.daySeparatorToday), \(Self.timeOfDayFormatter.string(from: Date.now))"
    }

    private var isVoiceActive: Bool {
        viewModel.isRecording || viewModel.isTranscribing
    }

    private var disclaimerFooter: some View {
        Text(L10n.Chat.disclaimer)
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.secondary)
            .padding(.bottom, DS.Spacing.xs)
    }

    /// Bloque centrado al final del último mensaje del assistant — botón clicable
    /// "Reiniciar contexto" + caption con contador de mensajes recordados.
    private var resetContextRow: some View {
        VStack(spacing: DS.Spacing.xs) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.resetConversationContext()
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "arrow.counterclockwise")
                    Text(L10n.Chat.resetContext)
                }
                .font(DS.Typography.caption)
                .foregroundStyle(.thPrimaryText)
            }
            .buttonStyle(.plain)

            Text(L10n.Chat.contextMemory(viewModel.messages.count))
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.md)
    }

    @ViewBuilder
    private var chipsOrSkeleton: some View {
        if viewModel.suggestionsFailed {
            unavailableState
        } else if viewModel.suggestions.isEmpty && viewModel.suggestionsLoading {
            preparingAIState
        } else {
            VStack(spacing: DS.Spacing.sm) {
                ForEach(viewModel.suggestions.prefix(3)) { suggestion in
                    ChatSuggestionChip(suggestion: suggestion) {
                        Task { await viewModel.sendSuggestion(suggestion) }
                    }
                }
            }
        }
    }

    private var preparingAIState: some View {
        HStack(spacing: DS.Spacing.sm) {
            ProgressView()
                .controlSize(.small)
            Text(L10n.Chat.preparingAI)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
    }

    private var unavailableState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32)) // A11Y-DT: error icon
                .foregroundStyle(.secondary)

            Text(L10n.Chat.unavailable)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.loadSuggestions() }
            } label: {
                Text(L10n.Chat.retry)
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(Color.contrastingText(for: theme.accent))
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(Capsule().fill(theme.accent))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Messages

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DS.Spacing.md) {
                    Text(daySeparatorText)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, DS.Spacing.xs)

                    ForEach(viewModel.messages) { message in
                        ChatMessageBubble(message: message, viewModel: viewModel)
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

                    // Reset contexto: aparece cuando hay turnos guardados y no está cargando.
                    // Tiene id propio para que el scrollTo lo deje visible bajo el último mensaje.
                    if !viewModel.isLoading, viewModel.turnCount > 0 {
                        resetContextRow
                            .id("resetContext")
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    // Si hay turnos completos, scroll hasta el botón de reset (último elemento del stack).
                    // Si está cargando, al indicador. Sino, al último mensaje.
                    let target: AnyHashable
                    if viewModel.isLoading {
                        target = "loading" as AnyHashable
                    } else if viewModel.turnCount > 0 {
                        target = "resetContext" as AnyHashable
                    } else if let lastID = viewModel.messages.last?.id {
                        target = lastID as AnyHashable
                    } else {
                        return
                    }
                    proxy.scrollTo(target, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                } else if viewModel.turnCount > 0 {
                    withAnimation { proxy.scrollTo("resetContext", anchor: .bottom) }
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
        Group {
            if viewModel.isRecording {
                recordingInputBar
            } else if viewModel.isTranscribing {
                transcribingInputBar
            } else {
                idleInputBar
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isTranscribing)
    }

    private var idleInputBar: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            TextField(L10n.Chat.inputPlaceholder, text: $viewModel.inputText, axis: .vertical)
                .font(DS.Typography.body)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .disabled(!viewModel.isAIAvailable)

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
        .opacity(viewModel.isAIAvailable ? 1 : 0.5)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }

    private var recordingInputBar: some View {
        HStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "waveform")
                    .font(.system(size: 20)) // A11Y-DT: dictation indicator
                    .foregroundStyle(DS.Semantic.errorForeground)
                    .symbolEffect(.variableColor.iterative, isActive: true)

                Text(L10n.Chat.listening)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await viewModel.stopVoiceInput() }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 18, weight: .bold)) // A11Y-DT: stop icon
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44) // A11Y-DT: tap target grande
                    .background(Circle().fill(DS.Semantic.errorForeground))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Accessibility.stopRecording)
        }
        .padding(DS.Spacing.md)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }

    private var transcribingInputBar: some View {
        HStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.Chat.transcribing)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        }
        .buttonStyle(.plain)
        .disabled(isVoiceActive || !viewModel.isAIAvailable)
    }

    private var micButton: some View {
        Button {
            Task { await toggleVoiceInput() }
        } label: {
            Image(systemName: viewModel.isRecording ? "mic.circle.fill" : "mic")
                .font(.system(size: 24)) // A11Y-DT: input bar control
                .foregroundStyle(viewModel.isRecording ? AnyShapeStyle(DS.Semantic.errorForeground) : AnyShapeStyle(.thPrimaryText))
                .symbolEffect(.pulse, isActive: viewModel.isRecording)
        }
        .disabled(viewModel.isTranscribing || viewModel.isLoading || !viewModel.isAIAvailable)
        .accessibilityLabel(viewModel.isRecording ? L10n.Accessibility.stopRecording : L10n.Accessibility.startRecording)
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
        .accessibilityLabel(L10n.Chat.send)
        .disabled(
            viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || viewModel.isLoading
            || viewModel.isRecording
            || viewModel.isTranscribing
            || !viewModel.canAskMore
            || !viewModel.isAIAvailable
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
