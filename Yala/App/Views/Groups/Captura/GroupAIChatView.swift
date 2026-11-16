//
//  GroupAIChatView.swift
//  Yala
//
//  Yala IA dentro de un grupo, igual que el chat de personal (`ChatSheetView`): la hoja grande con «Yala IA» arriba y la
//  X a la izquierda, el hilo de burbujas (la tuya en el acento a la derecha, la de Yala IA en blanco a la izquierda), los
//  tres puntos mientras piensa y la barra de mensajería abajo con el micro que pasa a enviar en cuanto escribes. Lo propio
//  del grupo: Yala IA contesta con el reparto entre la gente del grupo y «Usar este reparto» abre Nuevo gasto relleno
//  (encargo del 2026-11-16). Antes era un formulario de texto con un botón «Repartir».
//
//  Un gasto por conversación: cada mensaje nuevo vuelve a repartir desde cero y la respuesta anterior queda en el hilo.
//

import SwiftUI

/// Una entrada del hilo del chat de grupo.
enum GroupChatEntry: Identifiable, Equatable {
    case user(id: UUID, text: String)
    case reply(id: UUID, text: String)
    /// Un reparto. El último se ve vivo (lo que se ajuste en «Ajustar» cambia sus cifras); los anteriores, congelados.
    case split(id: UUID, frozen: GroupChatSplitSnapshot)
    case failure(id: UUID, GroupCaptureFailure)

    var id: UUID {
        switch self {
        case .user(let id, _), .reply(let id, _), .split(let id, _), .failure(let id, _): id
        }
    }
}

/// Las cifras de un reparto tal como salieron, para que el hilo no cambie al llegar el siguiente.
struct GroupChatSplitSnapshot: Equatable {
    struct Row: Equatable {
        let name: String
        let amount: String
    }
    var rows: [Row]
    var total: String
}

struct GroupAIChatView: View {
    @State private var model: GroupCaptureModel
    let onUse: (GroupExpensePrefillTemplate) -> Void
    let onManualEntry: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @State private var recorder = AudioRecorderService.shared
    @State private var entries: [GroupChatEntry] = []
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var showsReview = false
    @State private var showUpgrade = false
    @State private var showAIConsentAlert = false
    @State private var pendingAIInput: PendingAIInput = .voice
    /// Lo que se manda en cuanto se acepte el consentimiento: un texto, o `nil` para abrir el micro.
    @State private var awaitingConsentText: String?

    /// Lado del micro y de enviar dentro de la píldora (`ChatSheetView`).
    private let inputControlSize: CGFloat = 36 // A11Y-DT: control circular de la barra de escribir

    init(
        members: [SplitMember],
        currentMemberID: String?,
        currencyCode: String,
        onUse: @escaping (GroupExpensePrefillTemplate) -> Void,
        onManualEntry: (() -> Void)?
    ) {
        _model = State(initialValue: GroupCaptureModel(
            members: members, currentMemberID: currentMemberID, currencyCode: currencyCode))
        self.onUse = onUse
        self.onManualEntry = onManualEntry
    }

    private var isThinking: Bool { model.phase == .processing && !isTranscribing }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.none) {
                thread
                inputBar
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Chat.assistantName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                        .accessibilityIdentifier("receipt_split_close")
                }
            }
            .navigationDestination(isPresented: $showsReview) { reviewPage }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(model.isBusy || isRecording)
        .announcesEntryPhase(isThinking ? EntryPhaseFeedbackLogic.announcement(title: L10n.Voice.understanding) : "")
        .aiConsentAlert(isPresented: $showAIConsentAlert, pendingInput: $pendingAIInput) { _ in
            if let text = awaitingConsentText {
                awaitingConsentText = nil
                send(text)
            } else {
                Task { await startRecording() }
            }
        }
        .proUpgradeSheet(
            isPresented: $showUpgrade, feature: .voiceInput, context: .proFeature,
            onManualEntry: { manualEntry() }
        ) {}
        .onChange(of: model.phase) { _, phase in phaseChanged(phase) }
        .onDisappear(perform: tearDown)
    }

    // MARK: - Hilo

    private var thread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DS.Spacing.md) {
                    ChatMessageBubble(message: ChatMessage(
                        role: .assistant, text: L10n.GruposCaptura.chatGreeting, timestamp: .now))
                        .accessibilityIdentifier("group_chat_greeting")

                    ForEach(entries) { entry in
                        entryView(entry)
                            .id(entry.id)
                            // Cada mensaje entra subiendo y fundido, como en personal (card pjum).
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if isThinking {
                        ChatLoadingIndicator()
                            .id("loading")
                            .transition(.opacity)
                            .accessibilityIdentifier("group_chat_thinking")
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .dsAnimation(DS.Animation.appear, value: entries.count, reduceMotion: reduceMotion)
                .dsAnimation(DS.Animation.appear, value: isThinking, reduceMotion: reduceMotion)
                .frame(maxWidth: DS.Adaptive.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: entries.count) { _, _ in scrollToEnd(proxy) }
            .onChange(of: isThinking) { _, _ in scrollToEnd(proxy) }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .default) {
            if isThinking {
                proxy.scrollTo("loading", anchor: .bottom)
            } else if let last = entries.last?.id {
                proxy.scrollTo(last, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func entryView(_ entry: GroupChatEntry) -> some View {
        switch entry {
        case .user(_, let text):
            ChatMessageBubble(message: ChatMessage(role: .user, text: text, timestamp: .now))
        case .reply(_, let text):
            ChatMessageBubble(message: ChatMessage(role: .assistant, text: text, timestamp: .now))
        case .split(let id, let frozen):
            splitCard(id == latestSplitID ? liveSnapshot : frozen, isCurrent: id == latestSplitID)
        case .failure(_, let failure):
            failureBubble(failure)
        }
    }

    private var latestSplitID: UUID? {
        entries.last { if case .split = $0 { return true } else { return false } }?.id
    }

    /// El reparto del motor ahora mismo, con sus importes ya escritos.
    private var liveSnapshot: GroupChatSplitSnapshot {
        let shares = ReceiptSplitLogic.shares(model.lines, memberIDs: model.memberIDs)
        return GroupChatSplitSnapshot(
            rows: shares.map { .init(name: memberName($0.memberID), amount: money($0.amount)) },
            total: money(ReceiptSplitLogic.total(model.lines))
        )
    }

    /// El reparto dentro del hilo, en una burbuja de Yala IA: lo que toca a cada uno, el total y los dos botones. Solo el
    /// último se puede usar; los anteriores quedan como historia.
    private func splitCard(_ snapshot: GroupChatSplitSnapshot, isCurrent: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ForEach(snapshot.rows, id: \.name) { row in
                    HStack {
                        Text(row.name)
                            .font(DS.Typography.body)
                        Spacer(minLength: DS.Spacing.sm)
                        Text(row.amount)
                            .font(DS.Typography.body.monospacedDigit())
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(isCurrent ? "receipt_split_share_\(row.name)" : "")
                }
                Divider()
                HStack {
                    Text(L10n.ReceiptSplit.total)
                        .font(DS.Typography.headline)
                    Spacer(minLength: DS.Spacing.sm)
                    Text(snapshot.total)
                        .font(DS.Typography.headline.monospacedDigit())
                        .accessibilityIdentifier(isCurrent ? "receipt_split_total" : "")
                }
                if isCurrent {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: DS.Spacing.sm) { splitButtons }
                        VStack(spacing: DS.Spacing.sm) { splitButtons }
                    }
                    .padding(.top, DS.Spacing.xs)
                }
            }
            .foregroundStyle(.thPrimaryText)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(.thCard)
            .clipShape(ChatBubbleShape())
            .opacity(isCurrent ? 1 : 0.6)

            Spacer(minLength: DS.Spacing.xl)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("group_chat_split")
    }

    @ViewBuilder
    private var splitButtons: some View {
        GroupCaptureSecondaryButton(title: L10n.GruposCaptura.chatAdjust, identifier: "group_chat_adjust") {
            showsReview = true
        }
        GroupCapturePrimaryButton(
            title: L10n.ReceiptSplit.useSplit,
            isEnabled: GroupReceiptSplitReview.canUse(model),
            identifier: "receipt_split_use",
            action: use
        )
    }

    private func failureBubble(_ failure: GroupCaptureFailure) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(GroupCaptureFailureText.title(failure))
                    .font(DS.Typography.bodyBold)
                    .accessibilityIdentifier("receipt_split_failure")
                Text(GroupCaptureFailureText.message(failure, source: model.source))
                    .font(DS.Typography.body)
                switch failure {
                case .trialPhotos, .trialVoice, .dailyLimitFree:
                    GroupCapturePrimaryButton(title: L10n.Voice.trialSeePro, identifier: "receipt_split_see_pro") {
                        showUpgrade = true
                    }
                case .dailyLimit:
                    GroupCaptureSecondaryButton(title: L10n.Voice.enterManually, identifier: "receipt_split_enter_manually",
                                                action: manualEntry)
                case .microphone:
                    GroupCaptureSecondaryButton(title: L10n.Voice.openSettings, identifier: "receipt_split_open_settings",
                                                action: GroupCaptureSystemSettings.open)
                default:
                    EmptyView()
                }
            }
            .foregroundStyle(.thPrimaryText)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(.thCard)
            .clipShape(ChatBubbleShape())

            Spacer(minLength: DS.Spacing.xxxl)
        }
    }

    // MARK: - Ajustar el reparto

    private var reviewPage: some View {
        VStack(spacing: DS.Spacing.md) {
            GroupReceiptSplitReview(model: model)
            if let reason = GroupReceiptSplitReview.blockedReason(model) {
                Text(reason)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            GroupCapturePrimaryButton(
                title: L10n.ReceiptSplit.useSplit,
                isEnabled: GroupReceiptSplitReview.canUse(model),
                identifier: "receipt_split_use",
                action: use
            )
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.lg)
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.ReceiptSplit.reviewTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Barra de escribir (mensajería, como personal)

    private var hasTypedText: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var inputBar: some View {
        Group {
            if isRecording || isTranscribing {
                VoiceListeningPanel(
                    isTranscribing: isTranscribing,
                    duration: isTranscribing ? model.recordedDuration : recorder.recordingDuration,
                    level: recorder.audioLevel,
                    accent: theme.accent,
                    reduceMotion: reduceMotion,
                    onCancel: cancelRecording,
                    onDone: {
                        DS.Haptic.light()
                        finishRecording()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                idleInputBar
            }
        }
        .animation(reduceMotion ? nil : DS.Animation.appear, value: isRecording)
        .animation(reduceMotion ? nil : DS.Animation.appear, value: isTranscribing)
        .frame(maxWidth: DS.Adaptive.readableWidth)
        .frame(maxWidth: .infinity)
    }

    private var idleInputBar: some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
            TextField(L10n.GruposCaptura.chatPlaceholder, text: $inputText, axis: .vertical)
                .font(DS.Typography.body)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .frame(minHeight: inputControlSize)
                .focused($isInputFocused)
                .accessibilityIdentifier("group_chat_input")

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
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }

    private var micButton: some View {
        Button {
            requestRecording()
        } label: {
            Image(systemName: "mic")
                .font(.system(size: 18, weight: .medium)) // A11Y-DT: input bar control
                .foregroundStyle(.thPrimaryText)
                .frame(width: inputControlSize, height: inputControlSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(model.isBusy)
        .accessibilityLabel(L10n.Accessibility.startRecording)
        .accessibilityIdentifier("group_chat_mic")
    }

    private var sendButton: some View {
        Button {
            DS.Haptic.light()
            requestSend(inputText)
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .bold)) // A11Y-DT: send icon
                .foregroundStyle(theme.onAccent)
                .frame(width: inputControlSize, height: inputControlSize)
                .background(Circle().fill(theme.accent))
        }
        .buttonStyle(.plain)
        .disabled(!hasTypedText || model.isBusy)
        .accessibilityLabel(L10n.Chat.send)
        .accessibilityIdentifier("group_chat_send")
    }

    // MARK: - Acciones

    private func requestSend(_ text: String) {
        guard appPreferences.aiDataConsentAccepted else {
            awaitingConsentText = text
            pendingAIInput = .voice
            showAIConsentAlert = true
            return
        }
        send(text)
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        entries.append(.user(id: UUID(), text: trimmed))
        model.readText(trimmed)
    }

    private func requestRecording() {
        guard appPreferences.aiDataConsentAccepted else {
            awaitingConsentText = nil
            pendingAIInput = .voice
            showAIConsentAlert = true
            return
        }
        Task { await startRecording() }
    }

    private func startRecording() async {
        isInputFocused = false
        #if DEBUG
        if UITestHooks.receiptSplitProfile != nil {
            isRecording = true
            return
        }
        #endif
        guard await recorder.requestMicrophonePermission() else {
            entries.append(.failure(id: UUID(), .microphone))
            return
        }
        do {
            try await recorder.startRecording()
            isRecording = true
            DS.Haptic.medium()
        } catch {
            #if DEBUG
            print("GroupAIChatView: Error starting recording: \(error)")
            #endif
            entries.append(.failure(id: UUID(), .microphone))
        }
    }

    private func finishRecording() {
        isRecording = false
        isTranscribing = true
        let language = appPreferences.voiceLanguage
        #if DEBUG
        if UITestHooks.receiptSplitProfile != nil {
            model.transcribeAndRead(Data(), language: language, onHeard: heard)
            return
        }
        #endif
        Task {
            do {
                let audio = try await recorder.stopRecording()
                model.transcribeAndRead(audio, language: language, onHeard: heard)
            } catch {
                #if DEBUG
                print("GroupAIChatView: Error stopping recording: \(error)")
                #endif
                isTranscribing = false
                entries.append(.failure(id: UUID(), .noVoice))
            }
        }
    }

    /// Lo dictado sale en el hilo como si lo hubieras escrito, igual que en personal.
    private func heard(_ text: String) {
        isTranscribing = false
        entries.append(.user(id: UUID(), text: text))
    }

    private func cancelRecording() {
        if recorder.state == .recording { recorder.cancelRecording() }
        isRecording = false
    }

    private func phaseChanged(_ phase: GroupCapturePhase) {
        switch phase {
        case .review:
            isTranscribing = false
            entries.append(.reply(id: UUID(), text: L10n.GruposCaptura.chatReply))
            entries.append(.split(id: UUID(), frozen: liveSnapshot))
        case .failure(let failure):
            isTranscribing = false
            entries.append(.failure(id: UUID(), failure))
        default:
            break
        }
    }

    private func use() {
        guard let template = model.template() else { return }
        DS.Haptic.success()
        onUse(template)
        dismiss()
    }

    private func manualEntry() {
        onManualEntry?()
        dismiss()
    }

    private func tearDown() {
        cancelRecording()
        model.cancel()
    }

    private func money(_ value: Double) -> String {
        appPreferences.currency(value, currencyCode: model.effectiveCurrency, forceFullPrecision: true)
    }

    private func memberName(_ id: String) -> String {
        model.members.first { $0.id.uuidString == id }?.displayName ?? ""
    }
}
