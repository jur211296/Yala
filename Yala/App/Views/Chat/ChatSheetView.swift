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

    /// Cómo está montado el chat. `.sheet`: la hoja de siempre, con su barra de navegación (iPhone, ventana
    /// compacta). `.column`: la columna de Yala IA junto a los datos en una ventana ancha (`yalaAIChat`). Con
    /// `insideNavigationStack` (Estadísticas, donde la columna vive dentro de otra pila) pinta su cabecera y no abre
    /// otra pila, porque dos anidadas se pisan la barra; fuera de una pila (Panel, Registros) lleva la suya, o su
    /// cabecera quedaría debajo de las pestañas de arriba del iPad (medido 2026-09-29).
    enum Presentation {
        case sheet
        case column(onClose: () -> Void, insideNavigationStack: Bool)
    }
    var presentation: Presentation = .sheet

    var body: some View {
        Group {
            switch presentation {
            case .sheet:
                navigationWrapped(close: { dismiss() }, closesFromTrailingEdge: false)
            case .column(let onClose, insideNavigationStack: false):
                navigationWrapped(close: onClose, closesFromTrailingEdge: true)
            case .column(let onClose, insideNavigationStack: true):
                VStack(spacing: DS.Spacing.none) {
                    columnHeader(onClose: onClose)
                    chatContent
                }
                .yalaScreenBackground(.subtle)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            viewModel.setContext(modelContext)
            // setContext ya consume el signal persistido en UserDefaults; aquí
            // cubrimos el caso del signal in-memory llegado mientras el sheet
            // estaba abierto pero antes del primer .onChange.
            consumeChatDraftSavedSignal()
        }
        .onDisappear {
            viewModel.persistSession()
        }
        .onChange(of: sessionState.chatDraftSavedSignal) { _, _ in
            consumeChatDraftSavedSignal()
        }
    }

    /// El chat con su propia barra: la X, el nombre y los ajustes de IA. En la hoja la X va a la izquierda, como
    /// siempre. En la columna va a la derecha, junto a los ajustes: en un iPad en vertical las pestañas comparten fila
    /// con la barra y su cápsula tapa el borde izquierdo de la columna (medido 2026-09-29, Panel en el iPad Pro 13).
    private func navigationWrapped(close: @escaping () -> Void, closesFromTrailingEdge: Bool) -> some View {
        NavigationStack {
            chatContent
                .navigationTitle(L10n.Chat.assistantName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: closesFromTrailingEdge ? .topBarTrailing : .cancellationAction) {
                        YalaToolbarButton(systemName: "xmark", label: L10n.Action.close, action: close)
                            .accessibilityIdentifier("chat_close")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        aiSettingsButton
                    }
                }
        }
    }

    /// La conversación, la barra de escribir y sus hojas: lo mismo en la hoja y en la columna.
    private var chatContent: some View {
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
        .yalaScreenBackground(.subtle)
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

    private var aiSettingsButton: some View {
        YalaToolbarButton(systemName: "slider.horizontal.3", label: L10n.AISettings.title) {
            showAISettingsSheet = true
        }
    }

    /// La cabecera de la columna dentro de otra pila: el nombre y, a la derecha como en la otra columna, los ajustes
    /// de IA y la X.
    private func columnHeader(onClose: @escaping () -> Void) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(L10n.Chat.assistantName)
                .font(DS.Typography.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: DS.Spacing.none)
            aiSettingsButton
                .buttonStyle(.glass)
            YalaToolbarButton(systemName: "xmark", label: L10n.Action.close, action: onClose)
                .buttonStyle(.glass)
                .accessibilityIdentifier("chat_close")
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
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
                threadHeader
                    .padding(.top, DS.Spacing.md)

                if viewModel.suggestionsFailed {
                    ChatGreetingBubble(suggestions: [], isPreparing: false, onSelect: sendSuggestion)
                    unavailableState
                } else {
                    ChatGreetingBubble(
                        suggestions: Array(viewModel.suggestions.prefix(3)),
                        isPreparing: viewModel.suggestions.isEmpty && viewModel.suggestionsLoading,
                        onSelect: sendSuggestion
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .readableChatWidth()
        }
    }

    private func sendSuggestion(_ suggestion: ChatSuggestion) {
        Task { await viewModel.sendSuggestion(suggestion) }
    }

    /// Lo único que interrumpe el hilo: la fecha y, debajo, los dos avisos de la conversación en el mismo gris pequeño.
    /// Va arriba del hilo y se va con el scroll; debajo de la caja de escribir no queda nada.
    private var threadHeader: some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(daySeparatorText)
            Text(L10n.Chat.dailyResetSubtitle)
            Text(L10n.Chat.disclaimer)
        }
        .font(DS.Typography.captionSmall)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("chat_thread_header")
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

    /// Una sola línea centrada al final del hilo: «Reiniciar contexto». Sin contador debajo, para que entre respuesta y
    /// respuesta no haya más interrupciones grises que la fecha de arriba.
    private var resetContextRow: some View {
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
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.sm)
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
                    threadHeader
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
                .readableChatWidth()
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

    // MARK: - Input Bar (mensajería: «+» fuera, píldora con el texto y un solo botón dentro)

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
        .readableChatWidth()
    }

    /// Lado del micro y de enviar dentro de la píldora; con su margen, la píldora mide lo mismo que el «+».
    private let inputControlSize: CGFloat = 36 // A11Y-DT: control circular de la barra de escribir
    private let topicsButtonSize: CGFloat = 44 // A11Y-DT: tap target del «+»

    private var hasTypedText: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// El «+» de Temas fuera, a la izquierda; dentro de la píldora, el texto y UN botón: el micro mientras no hay nada
    /// escrito y enviar en cuanto lo hay, como en una app de mensajería.
    private var idleInputBar: some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
            topicsButton

            HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
                TextField(L10n.Chat.inputPlaceholder, text: $viewModel.inputText, axis: .vertical)
                    .font(DS.Typography.body)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .frame(minHeight: inputControlSize)
                    .disabled(!viewModel.isAIAvailable)
                    .accessibilityIdentifier("chat_input")

                if hasTypedText {
                    sendButton
                        .transition(.scale.combined(with: .opacity))
                } else {
                    micButton
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.15), value: hasTypedText)
            .padding(.leading, DS.Spacing.lg)
            .padding(.trailing, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xs)
            .background(.thCard)
            .clipShape(ChatBubbleShape())
        }
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
        .clipShape(ChatBubbleShape())
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
        .clipShape(ChatBubbleShape())
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }

    private var topicsButton: some View {
        Button {
            showTopicsSheet = true
        } label: {
            Image(systemName: "plus")
                .font(DS.Typography.iconMedium)
                .foregroundStyle(.thPrimaryText)
                .frame(width: topicsButtonSize, height: topicsButtonSize)
                .background(Circle().fill(.thCard))
        }
        .buttonStyle(.plain)
        .disabled(isVoiceActive || !viewModel.isAIAvailable)
        .accessibilityLabel(L10n.Chat.topicsButton)
        .accessibilityIdentifier("chat_topics")
    }

    private var micButton: some View {
        Button {
            Task { await toggleVoiceInput() }
        } label: {
            Image(systemName: "mic")
                .font(.system(size: 18, weight: .medium)) // A11Y-DT: input bar control
                .foregroundStyle(.thPrimaryText)
                .frame(width: inputControlSize, height: inputControlSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isTranscribing || viewModel.isLoading || !viewModel.isAIAvailable)
        .accessibilityLabel(L10n.Accessibility.startRecording)
        .accessibilityIdentifier("chat_mic")
    }

    private var sendButton: some View {
        Button {
            Task { await viewModel.sendQuestion(viewModel.inputText) }
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .bold)) // A11Y-DT: send icon
                .foregroundStyle(Color.contrastingText(for: theme.accent))
                .frame(width: inputControlSize, height: inputControlSize)
                .background(Circle().fill(theme.accent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Chat.send)
        .accessibilityIdentifier("chat_send")
        .disabled(
            !hasTypedText
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

private extension View {
    /// El hilo y la barra de escribir no pasan del ancho legible y van centrados cuando el contenedor es ancho (una
    /// hoja grande, una ventana ancha). En la hoja del iPhone y en la columna del iPad no cambia nada: son más
    /// estrechas que el tope.
    func readableChatWidth() -> some View {
        frame(maxWidth: DS.Adaptive.readableWidth)
            .frame(maxWidth: .infinity)
    }
}
