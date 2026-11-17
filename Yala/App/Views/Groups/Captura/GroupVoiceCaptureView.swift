//
//  GroupVoiceCaptureView.swift
//  Yala
//
//  Voz dentro de un grupo, igual que la voz de personal (`VoiceRecordingView`, propuesta C de Jürgen del 2026-10-04):
//  la hoja a media altura que ya escucha al abrirse, la onda que sigue la voz, el tiempo, la frase que va entendiendo el
//  iPhone, Cancelar / Listo, y el orbe mientras transcribe y entiende. Lo único distinto es «lo entendido»: el reparto
//  del gasto entre la gente del grupo, que lleva a Nuevo gasto relleno (encargo del 2026-11-16).
//

import SwiftUI

struct GroupVoiceCaptureView: View {
    @State private var model: GroupCaptureModel
    let onUse: (GroupExpensePrefillTemplate) -> Void
    let onManualEntry: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.usesLargeSheets) private var usesLargeSheets
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @State private var recorder = AudioRecorderService.shared
    @State private var networkMonitor = NetworkMonitor.shared
    /// La frase en vivo. Solo se pinta: lo que se transcribe y se lee sigue siendo el audio grabado.
    @State private var livePreview = LiveSpeechPreviewService()
    @State private var waveLevels: [Double] = []
    /// Seam `-uitest-voice-live`: el tiempo, el nivel y la frase de mentira mientras escucha.
    @State private var demoDuration: TimeInterval = 0
    @State private var demoText = ""
    @State private var demoTask: Task<Void, Never>?

    @State private var selectedDetent: PresentationDetent = .medium
    @State private var showUpgrade = false
    @State private var showAIConsentAlert = false
    @State private var pendingAIInput: PendingAIInput = .voice
    @State private var showRecordAgainConfirmation = false

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

    private var isReview: Bool { model.phase == .review }

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            GroupCaptureHeader(showsClose: isReview || isFailure, closeIdentifier: "receipt_split_close") { dismiss() }
            content
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .dsAnimation(.easeInOut(duration: 0.25), value: model.phase, reduceMotion: reduceMotion)
        .yalaScreenBackground(
            SelectorSheetSizing.mediumFirst.background(
                selectedDetent: selectedDetent,
                usesLargeSheets: usesLargeSheets,
                dynamicTypeSize: dynamicTypeSize
            )
        )
        .selectorSheetSizing(.mediumFirst, selectedDetent: $selectedDetent)
        // El reparto no cabe a media altura: la hoja sube sola a grande, como la foto de personal con varios registros.
        .onChange(of: isReview) { _, review in if review { selectedDetent = .large } }
        .growsSheetToLarge(when: isReview)
        .interactiveDismissDisabled(model.isBusy)
        .announcesEntryPhase(phaseAnnouncement)
        .asksBeforeDiscardingEntry(
            title: L10n.EntryDiscard.voiceTitle,
            message: L10n.GruposCaptura.discardSplitMessage,
            isPresented: $showRecordAgainConfirmation,
            onDiscard: recordAgain
        )
        .aiConsentAlert(isPresented: $showAIConsentAlert, pendingInput: $pendingAIInput) { _ in
            Task { await startListening() }
        }
        .proUpgradeSheet(
            isPresented: $showUpgrade, feature: .voiceInput, context: .proFeature,
            onManualEntry: { manualEntry() }
        ) {
            recordAgain()
        }
        .task { await requestListening() }
        .onDisappear(perform: tearDown)
    }

    private var isFailure: Bool {
        if case .failure = model.phase { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle, .starting, .listening:
            listeningContent
        case .processing:
            processingContent
        case .review:
            GroupReceiptReviewContent(
                model: model,
                againTitle: L10n.Voice.recordAgain,
                againIdentifier: "receipt_split_record_again",
                onAgain: { showRecordAgainConfirmation = true },
                onUse: use
            )
        case .failure(let failure):
            GroupCaptureFailureView(
                failure: failure,
                source: model.source,
                actions: GroupCaptureFailureActions(
                    tryAgainTitle: L10n.Voice.recordAgain,
                    onTryAgain: recordAgain,
                    onClose: { dismiss() },
                    onManualEntry: manualEntry,
                    onSeePro: { showUpgrade = true },
                    onOpenSettings: GroupCaptureSystemSettings.open
                )
            )
        }
    }

    // MARK: - Escuchando

    private var listeningContent: some View {
        VStack(spacing: DS.Spacing.md) {
            VStack(spacing: DS.Spacing.xs) {
                Text(L10n.Chat.listening)
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thPrimaryText)
                Text(L10n.ReceiptSplit.voiceHint)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: DS.Spacing.sm) {
                VoiceWaveform(levels: waveLevels, accent: theme.accent, reduceMotion: reduceMotion)
                VoiceRecordingTimeLabel(duration: listeningDuration, reduceMotion: reduceMotion)
            }
            .padding(.top, DS.Spacing.sm)

            VoiceLiveTranscriptText(text: liveText)

            Spacer(minLength: DS.Spacing.lg)

            HStack(spacing: DS.Spacing.md) {
                GroupCaptureSecondaryButton(title: L10n.Action.cancel, identifier: "group_voice_cancel", action: cancelListening)
                    .accessibilityLabel(L10n.Accessibility.discardRecording)
                GroupCapturePrimaryButton(
                    title: L10n.Action.done, isEnabled: model.phase == .listening, identifier: "group_voice_done"
                ) {
                    finishListening()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("group_voice_listening")
        .onChange(of: recorder.recordingDuration) { _, _ in recordWaveLevel() }
    }

    private var listeningDuration: TimeInterval {
        demoTask != nil ? demoDuration : recorder.recordingDuration
    }

    private var liveText: String {
        demoTask != nil ? demoText : livePreview.text
    }

    private func recordWaveLevel() {
        guard model.phase == .listening, recorder.state == .recording else { return }
        waveLevels = VoiceLiveListeningLogic.appending(recorder.audioLevel, to: waveLevels)
    }

    // MARK: - Procesando

    private var processingContent: some View {
        VStack(spacing: DS.Spacing.md) {
            Text(processingTitle)
                .font(DS.Typography.title3)
                .foregroundStyle(.thPrimaryText)
                .contentTransition(.opacity)

            VoiceListeningOrb(
                isTranscribing: true,
                duration: model.recordedDuration,
                level: 0,
                accent: theme.accent,
                reduceMotion: reduceMotion
            )
            .padding(.top, DS.Spacing.sm)

            Spacer(minLength: DS.Spacing.lg)

            Button(L10n.Action.cancel) {
                model.cancel()
                dismiss()
            }
            .font(DS.Typography.body)
            .foregroundStyle(.secondary)
            .frame(minHeight: 48) // A11Y-DT: tap target de los botones de la hoja
            .accessibilityLabel(L10n.Accessibility.cancelProcessing)
            .accessibilityIdentifier("group_voice_cancel_processing")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("group_voice_processing")
    }

    private var processingTitle: String {
        switch model.processingStep {
        case 0: L10n.Chat.transcribing
        case 1: L10n.Voice.understanding
        default: L10n.Voice.preparing
        }
    }

    private var phaseAnnouncement: String {
        switch model.phase {
        case .idle, .starting:
            return ""
        case .listening:
            return EntryPhaseFeedbackLogic.announcement(title: L10n.Chat.listening)
        case .processing:
            return EntryPhaseFeedbackLogic.announcement(title: processingTitle)
        case .review:
            return EntryPhaseFeedbackLogic.announcement(title: L10n.ReceiptSplit.reviewTitle)
        case .failure(let failure):
            return GroupCaptureFailureText.announcement(failure, source: model.source)
        }
    }

    // MARK: - Acciones

    /// El consentimiento de datos de IA es el mismo de foto y voz: sin él, se pide antes de abrir el micrófono.
    private func requestListening() async {
        guard appPreferences.aiDataConsentAccepted else {
            pendingAIInput = .voice
            showAIConsentAlert = true
            return
        }
        await startListening()
    }

    private func startListening() async {
        waveLevels = []
        await model.startListening(isConnected: networkMonitor.isConnected)
        guard model.phase == .listening else { return }
        #if DEBUG
        if UITestHooks.receiptSplitProfile != nil {
            if UITestHooks.voiceLivePreview { startDemoLivePreview() }
            return
        }
        #endif
        livePreview.start(languageCode: appPreferences.voiceLanguage.isoCode)
    }

    private func finishListening() {
        let duration = listeningDuration
        stopLivePreview()
        model.finishListening(duration: duration, language: appPreferences.voiceLanguage)
    }

    /// Cancelar mientras escucha descarta sin transcribir y cierra, como personal.
    private func cancelListening() {
        stopLivePreview()
        model.cancelListening()
        dismiss()
    }

    private func recordAgain() {
        model.reset()
        Task { await startListening() }
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

    /// La frase en vivo y la onda se apagan ANTES de parar la grabación: el motor del reconocedor suelta la entrada
    /// antes de que el grabador desactive la sesión de audio.
    private func stopLivePreview() {
        livePreview.stop()
        demoTask?.cancel()
        demoTask = nil
    }

    private func tearDown() {
        stopLivePreview()
        model.cancel()
    }

    #if DEBUG
    /// Seam `-uitest-voice-live`: nivel y frase de mentira, palabra a palabra, para ver la hoja sin micro.
    private func startDemoLivePreview() {
        demoTask?.cancel()
        demoDuration = 0
        demoText = ""
        let words = GroupCaptureModel.uiTestHeard.split(whereSeparator: \.isWhitespace).map(String.init)
        demoTask = Task { @MainActor in
            let start = Date.now
            while !Task.isCancelled {
                let elapsed = Date.now.timeIntervalSince(start)
                demoDuration = elapsed
                waveLevels = VoiceLiveListeningLogic.appending(VoiceLiveListeningLogic.demoLevel(elapsed: elapsed), to: waveLevels)
                let shown = VoiceLiveListeningLogic.demoWordCount(elapsed: elapsed, totalWords: words.count)
                demoText = words.prefix(shown).joined(separator: " ")
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch {
                    return
                }
            }
        }
    }
    #endif
}

/// Abre los Ajustes de iOS de Yala (permisos de micrófono y cámara).
enum GroupCaptureSystemSettings {
    @MainActor
    static func open() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
