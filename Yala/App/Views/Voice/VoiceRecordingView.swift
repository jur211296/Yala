//
//  VoiceRecordingView.swift
//  Yala
//
//  Sheet view for recording voice input and creating transaction drafts.
//

import SwiftData
import SwiftUI

struct VoiceRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(VoiceTranscriptionService.self) private var voiceTranscriptionService
    @Environment(TranscriptionParserService.self) private var transcriptionParserService

    @State private var recorder = AudioRecorderService.shared
    @State private var networkMonitor = NetworkMonitor.shared

    @AppStorage("voiceLanguage") private var voiceLanguageRaw: String = VoiceLanguage.system.rawValue
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.usd.rawValue

    @State private var errorMessage: String?
    @State private var errorType: VoiceErrorType?
    @State private var isProcessing = false
    @State private var processingStatus: String = ""
    @State private var processingStepIndex: Int = 0
    @State private var createdDraft: InboxDraft?
    @State private var createdDrafts: [InboxDraft] = []
    @State private var draftWasApproved = false

    // Preview state (after recording, before processing)
    @State private var isPreviewMode = false
    @State private var previewDuration: TimeInterval = 0
    @State private var countdownValue = 3
    @State private var countdownTimer: Timer?
    @State private var pendingAudioData: Data?

    // Processing cancellation
    @State private var processingTask: Task<Void, Never>?

    /// Callback when draft is saved but not approved (user should go to Inbox)
    var onSavedToInbox: (() -> Void)?

    /// Callback to switch to image input mode
    var onSwitchToImage: (() -> Void)?

    /// Types of errors that need special handling
    private enum VoiceErrorType {
        case noApiKey
        case noConnection
        case micPermission
        case generic
    }

    private var voiceLanguage: VoiceLanguage {
        VoiceLanguage(rawValue: voiceLanguageRaw) ?? .system
    }

    private var preferredCurrencyName: String {
        if let code = CurrencyCode(rawValue: defaultCurrencyCode) {
            return code.shortPluralName
        }
        return CurrencyCode.usd.shortPluralName
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xxl) {
                if isProcessing {
                    // Stepped progress view for voice processing
                    ProcessingProgressView(
                        mode: .stepped(
                            currentStep: processingStepIndex,
                            steps: [
                                L10n.Voice.analyzing,
                                L10n.Voice.parsing,
                                L10n.Voice.saving
                            ]
                        ),
                        accentColor: .hotPink,
                        statusText: processingStatus
                    )
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Spacer()

                    // Recording visualization
                    recordingVisualization
                        .transition(.scale.combined(with: .opacity))

                    // Status text
                    statusText
                        .transition(.opacity)

                    // Error message with action buttons
                    if let error = errorMessage {
                        errorView(message: error)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer()
                }

                // Action buttons (always shown)
                actionButtons
                    .transition(.scale.combined(with: .opacity))
            }
            .padding(DS.Spacing.xl)
            .dsAnimation(.easeInOut(duration: 0.3), value: recorder.state, reduceMotion: reduceMotion)
            .dsAnimation(.easeInOut(duration: 0.3), value: isPreviewMode, reduceMotion: reduceMotion)
            .dsAnimation(.easeInOut(duration: 0.3), value: isProcessing, reduceMotion: reduceMotion)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thBackground)
            .navigationTitle(L10n.Voice.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Only show X when idle (during recording/preview/processing, there's an X below)
                if recorder.state == .idle && !isPreviewMode && !isProcessing {
                    ToolbarItem(placement: .topBarTrailing) {
                        YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                            recorder.cancelRecording()
                            dismiss()
                        }
                    }
                }
            }
            .interactiveDismissDisabled(recorder.state != .idle || createdDraft != nil)
            .sheet(item: $createdDraft) { draft in
                InboxDraftEditSheet(draft: draft) {
                    // onApproved callback - mark as approved and dismiss voice view
                    draftWasApproved = true
                    dismiss()
                }
            }
            .onChange(of: createdDraft) { oldValue, newValue in
                // Detect when EditSheet is dismissed (draft becomes nil)
                if oldValue != nil && newValue == nil && !draftWasApproved {
                    // Draft was not approved - just dismiss back to PanelView
                    dismiss()
                }
                // Reset flag for next use
                if newValue == nil {
                    draftWasApproved = false
                }
            }
            .onDisappear {
                countdownTimer?.invalidate()
                countdownTimer = nil
                processingTask?.cancel()
                processingTask = nil
            }
        }
    }

    // MARK: - Recording Visualization

    private var recordingVisualization: some View {
        ZStack {
            // Pulsing rings when recording
            if recorder.state == .recording {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            Color.hotPink.opacity(0.3 - Double(index) * 0.1),
                            lineWidth: 2
                        )
                        .frame(width: 140 + CGFloat(index) * 30, height: 140 + CGFloat(index) * 30)
                        .scaleEffect(1.0 + sin(recorder.recordingDuration * 3 - Double(index) * 0.5) * 0.08)
                        .dsAnimation(.easeInOut(duration: 0.3), value: recorder.recordingDuration, reduceMotion: reduceMotion)
                }
            }

            // Outer glow when recording
            if recorder.state == .recording {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.hotPink.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 50,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 10)
            }

            // Progress ring when recording
            if recorder.state == .recording {
                Circle()
                    .trim(from: 0, to: CGFloat(fmod(recorder.recordingDuration / 60.0, 1.0)))
                    .stroke(Color.hotPink.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 148, height: 148)
                    .rotationEffect(.degrees(-90))
            }

            // Main circle with gradient
            Circle()
                .fill(circleGradient)
                .frame(width: 120, height: 120)
                .shadow(color: circleColor.opacity(0.4), radius: 20, x: 0, y: 8)

            // Glass overlay
            Circle()
                .fill(DS.Colors.backgroundSubtle)
                .frame(width: 120, height: 120)
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            // Icon
            Image(systemName: recorder.state == .recording ? "waveform" : "mic.fill")
                .font(DS.Typography.amountLarge)
                .foregroundStyle(.white)
                .symbolEffect(.variableColor.iterative, isActive: recorder.state == .recording)
                .accessibilityHidden(true)
        }
    }

    private var circleColor: Color {
        switch recorder.state {
        case .idle:
            return .hotPink
        case .recording:
            return .hotPink
        case .processing:
            return .hotPink
        }
    }

    private var circleGradient: LinearGradient {
        switch recorder.state {
        case .idle:
            return LinearGradient(
                colors: [Color.hotPink, Color.hotPink.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .recording:
            return LinearGradient(
                colors: [Color.hotPink, Color.hotPink.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .processing:
            return LinearGradient(
                colors: [Color.hotPink.opacity(0.8), Color.hotPink.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Status Text

    private var statusText: some View {
        VStack(spacing: DS.Spacing.sm) {
            if recorder.state == .recording {
                // Glass capsule timer
                Text(formatDuration(recorder.recordingDuration))
                    .font(DS.Typography.amountLarge)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .glassEffect()

                Text(L10n.Voice.recording)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            } else if isPreviewMode {
                // Preview mode: countdown ring inside main circle area
                ZStack {
                    // Depleting ring
                    Circle()
                        .stroke(Color.hotPink.opacity(0.2), lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(countdownValue) / 3.0)
                        .stroke(Color.hotPink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: countdownValue)

                    Text("\(countdownValue)")
                        .font(DS.Typography.amountLarge)
                        .foregroundStyle(Color.hotPink)
                        .contentTransition(.numericText())
                }

                // Glass recorded label
                Text(L10n.Voice.recorded)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .glassEffect()
            } else {
                instructionsView
            }
        }
    }

    // MARK: - Instructions View

    private var instructionsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Spacing.lg) {
                Text(L10n.Voice.tapToRecord)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                // Hints grid
                hintsSection

                // Examples
                examplesSection
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
    }

    private var hintsSection: some View {
        VStack(alignment: .center, spacing: DS.Spacing.sm) {
            Text(L10n.Voice.youCanSay)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DS.Spacing.sm) {
                hintChip(icon: "arrow.left.arrow.right", text: L10n.Voice.hintTypeExample)
                hintChip(icon: "dollarsign.circle", text: String(format: L10n.Voice.hintAmountExample, preferredCurrencyName))
                hintChip(icon: "folder", text: L10n.Voice.hintSubcategoryExample)
                hintChip(icon: "mappin", text: L10n.Voice.hintMerchantExample)
                hintChip(icon: "tag", text: L10n.Voice.hintTagExample)
                hintChip(icon: "calendar", text: L10n.Voice.hintDateExample)
            }
        }
        .padding(DS.Spacing.md)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func hintChip(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(Color.hotPink)
                .accessibilityHidden(true)

            Text(text)
                .font(DS.Typography.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hotPink.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private var examplesSection: some View {
        VStack(alignment: .center, spacing: DS.Spacing.sm) {
            Text(L10n.Voice.exampleLabel)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: DS.Spacing.xs) {
                exampleRow(text: String(format: L10n.Voice.example1, preferredCurrencyName))
                exampleRow(text: String(format: L10n.Voice.example2, preferredCurrencyName))
                exampleRow(text: String(format: L10n.Voice.example3, preferredCurrencyName))
            }
        }
        .padding(DS.Spacing.md)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func exampleRow(text: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "text.quote")
                .font(DS.Typography.caption)
                .foregroundStyle(Color.hotPink)
                .accessibilityHidden(true)

            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .italic()

            Spacer()
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .stroke(Color.hotPink.opacity(0.2), lineWidth: 1)
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Text(message)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Semantic.errorForeground)
                .multilineTextAlignment(.center)

            // Action buttons based on error type
            HStack(spacing: DS.Spacing.md) {
                switch errorType {
                case .noApiKey:
                    // No action available - feature requires build-time configuration
                    EmptyView()

                case .noConnection:
                    // Suggest using image (works offline)
                    if onSwitchToImage != nil {
                        Button {
                            dismiss()
                            onSwitchToImage?()
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "photo")
                                Text(L10n.Voice.tryImage)
                            }
                            .font(DS.Typography.label)
                            .foregroundStyle(Color.hotPink)
                        }
                    }

                case .micPermission:
                    // Open system Settings
                    Button {
                        openSystemSettings()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "gear")
                            Text(L10n.Voice.openSettings)
                        }
                        .font(DS.Typography.label)
                        .foregroundStyle(Color.hotPink)
                    }

                case .generic, .none:
                    // Show retry button if we have pending audio
                    if pendingAudioData != nil {
                        Button {
                            retryProcessing()
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "arrow.clockwise")
                                Text(L10n.Action.retry)
                            }
                            .font(DS.Typography.label)
                            .foregroundStyle(Color.hotPink)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
    }

    private func openSystemSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: DS.Spacing.xxl) {
            if recorder.state == .recording {
                // Cancel button
                Button {
                    recorder.cancelRecording()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                .accessibilityLabel(L10n.Accessibility.cancelRecording)

                // Stop and enter preview mode
                Button {
                    Task {
                        await stopAndEnterPreview()
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.title)
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(
                            LinearGradient(
                                colors: [Color.hotPink, Color.hotPink.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.hotPink.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .accessibilityLabel(L10n.Accessibility.stopRecording)
            } else if isPreviewMode {
                // Cancel button (stops countdown and returns to idle)
                Button {
                    cancelPreview()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                .accessibilityLabel(L10n.Accessibility.cancelPreview)

                // Process now button (skips countdown)
                Button {
                    processNow()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(DS.Typography.title)
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(
                            LinearGradient(
                                colors: [Color.hotPink, Color.hotPink.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.hotPink.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .accessibilityLabel(L10n.Accessibility.processAudio)
            } else if isProcessing {
                // Cancel processing button
                Button {
                    cancelProcessing()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                .accessibilityLabel(L10n.Accessibility.cancelProcessing)
            } else {
                // Start recording button
                Button {
                    Task {
                        await startRecording()
                    }
                } label: {
                    Image(systemName: "mic.fill")
                        .font(DS.Typography.title)
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(
                            LinearGradient(
                                colors: [Color.hotPink, Color.hotPink.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.hotPink.opacity(0.4), radius: 16, x: 0, y: 8)
                }
                .accessibilityLabel(L10n.Accessibility.startRecording)
            }
        }
        .padding(.bottom, DS.Spacing.xxl)
    }

    // MARK: - Recording Actions

    private func startRecording() async {
        errorMessage = nil
        errorType = nil

        // Check for API key first
        guard APIKeyService.hasOpenAIAPIKey else {
            errorType = .noApiKey
            errorMessage = L10n.Voice.errorNoApiKey
            return
        }

        // Check for network connection
        guard networkMonitor.isConnected else {
            errorType = .noConnection
            errorMessage = L10n.Voice.errorNoConnection
            return
        }

        do {
            try await recorder.startRecording()
            // Haptic feedback on start
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch let error as RecordingError {
            handleRecordingError(error)
        } catch {
            errorType = .generic
            errorMessage = error.localizedDescription
        }
    }

    private func handleRecordingError(_ error: RecordingError) {
        switch error {
        case .microphonePermissionDenied, .microphonePermissionRestricted:
            errorType = .micPermission
            errorMessage = L10n.Voice.errorMicPermission
        default:
            errorType = .generic
            errorMessage = error.localizedDescription
        }
    }

    private func stopAndEnterPreview() async {
        errorMessage = nil

        do {
            // Stop recording and get audio data
            previewDuration = recorder.recordingDuration
            let audioData = try await recorder.stopRecording()
            pendingAudioData = audioData

            // Haptic feedback on stop
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // Enter preview mode with countdown
            dsWithAnimation(reduceMotion, .easeOut(duration: 0.3)) {
                isPreviewMode = true
                countdownValue = 3
            }

            // Start countdown timer
            startCountdown()

        } catch let error as RecordingError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Haptic feedback on each tick
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()

            if countdownValue > 1 {
                dsWithAnimation(reduceMotion, .easeInOut(duration: 0.2)) {
                    countdownValue -= 1
                }
            } else {
                countdownTimer?.invalidate()
                countdownTimer = nil
                processNow()
            }
        }
    }

    private func cancelPreview() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        pendingAudioData = nil
        dsWithAnimation(reduceMotion, .easeOut(duration: 0.3)) {
            isPreviewMode = false
            previewDuration = 0
            countdownValue = 3
        }
    }

    private func processNow() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        guard let audioData = pendingAudioData else { return }

        dsWithAnimation(reduceMotion, .easeOut(duration: 0.3)) {
            isPreviewMode = false
        }

        processingTask = Task {
            await processAudio(audioData)
        }
    }

    private func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
        isProcessing = false
        pendingAudioData = nil
        errorMessage = nil
    }

    private func retryProcessing() {
        guard let audioData = pendingAudioData else { return }
        errorMessage = nil

        processingTask = Task {
            await processAudio(audioData)
        }
    }

    private func processAudio(_ audioData: Data) async {
        errorMessage = nil
        isProcessing = true

        do {
            // Step 1: Transcribe audio
            processingStepIndex = 0
            processingStatus = L10n.Voice.analyzing
            let transcription = try await voiceTranscriptionService.transcribe(
                audioData: audioData,
                language: voiceLanguage
            )

            // Check cancellation after transcription
            guard !Task.isCancelled else {
                isProcessing = false
                return
            }

            // Step 2: Parse transcription (supports multiple transactions)
            processingStepIndex = 1
            processingStatus = L10n.Voice.parsing

            // Get user's subcategories for intelligent matching
            let (expenseSubcategories, incomeSubcategories) = fetchSubcategoryNames()

            let parsedTransactions = try await transcriptionParserService.parseMultiple(
                text: transcription.text,
                expenseSubcategories: expenseSubcategories,
                incomeSubcategories: incomeSubcategories
            )

            // Check cancellation after parsing
            guard !Task.isCancelled else {
                isProcessing = false
                return
            }

            // Filter only transactions with amounts
            let validTransactions = parsedTransactions.filter { $0.amount != nil }

            // Validate: At least one transaction must have amount
            guard !validTransactions.isEmpty else {
                isProcessing = false
                errorMessage = L10n.Voice.errorNoAmount
                return
            }

            // Snapshot existing pending drafts BEFORE creating new ones
            // to avoid SwiftData auto-insert interference with deduplication
            let existingDrafts = fetchPendingDrafts()

            // Step 3: Create InboxDrafts (only if not cancelled)
            processingStepIndex = 2
            processingStatus = L10n.Voice.saving
            let newDrafts = validTransactions.map { parsed in
                createInboxDraft(from: parsed, transcription: transcription.text, insertInContext: false)
            }

            // Deduplicate against pre-existing pending drafts
            let uniqueDrafts = DraftDeduplicationService.deduplicate(
                newDrafts: newDrafts,
                existingDrafts: existingDrafts
            )

            // If all are duplicates, use originals (SwiftData may have auto-inserted them)
            let drafts = uniqueDrafts.isEmpty ? newDrafts : uniqueDrafts

            // Insert drafts (no-op if SwiftData already auto-inserted)
            for draft in drafts {
                modelContext.insert(draft)
            }

            // Save all drafts to persistent storage
            do {
                try modelContext.save()
            } catch {
                isProcessing = false
                errorType = .generic
                errorMessage = L10n.Voice.errorSaveFailed
                return
            }

            isProcessing = false
            pendingAudioData = nil

            // Navigation based on number of drafts
            if drafts.count == 1 {
                // Single draft: open edit sheet directly
                createdDraft = drafts.first
            } else {
                // Multiple drafts: save and navigate to Inbox
                createdDrafts = drafts
                onSavedToInbox?()
                dismiss()
            }

        } catch let error as TranscriptionError {
            isProcessing = false
            handleTranscriptionError(error)
        } catch let error as ParserError {
            isProcessing = false
            errorType = .generic
            errorMessage = error.localizedDescription
        } catch {
            isProcessing = false
            // Check if it's a network error
            if !networkMonitor.isConnected {
                errorType = .noConnection
                errorMessage = L10n.Voice.errorNoConnection
            } else {
                errorType = .generic
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleTranscriptionError(_ error: TranscriptionError) {
        switch error {
        case .noAPIKey:
            errorType = .noApiKey
            errorMessage = L10n.Voice.errorNoApiKey
        case .networkError:
            if !networkMonitor.isConnected {
                errorType = .noConnection
                errorMessage = L10n.Voice.errorNoConnection
            } else {
                errorType = .generic
                errorMessage = error.localizedDescription
            }
        default:
            errorType = .generic
            errorMessage = error.localizedDescription
        }
    }

    private func createInboxDraft(from parsed: ParsedTransaction, transcription: String, insertInContext: Bool = true) -> InboxDraft {
        // Convert Decimal to Double for amount, apply sign based on isExpense
        var amountDouble: Double? = nil
        if let amount = parsed.amount {
            let value = NSDecimalNumber(decimal: amount).doubleValue
            amountDouble = parsed.isExpense ? -abs(value) : abs(value)
        }

        // Try to match account by currency hint
        var matchedAccount: Account?
        var needsUserInputFields = ["account", "subcategory"]

        if let currencyHint = parsed.currencyHint, !currencyHint.isEmpty {
            matchedAccount = findAccount(byCurrency: currencyHint)
            if matchedAccount != nil {
                needsUserInputFields.removeAll { $0 == "account" }
            }
        }

        // Try to match subcategory hint with existing subcategories
        var matchedSubcategory: Subcategory?

        if let hint = parsed.subcategoryHint, !hint.isEmpty {
            matchedSubcategory = findSubcategory(matching: hint, isExpense: parsed.isExpense)
            if matchedSubcategory != nil {
                needsUserInputFields.removeAll { $0 == "subcategory" }
            }
        }

        // Merchant Memory fallback: suggest subcategory if LLM didn't match one
        if matchedSubcategory == nil && !parsed.note.trimmingCharacters(in: .whitespaces).isEmpty {
            let merchantService = MerchantMemoryService(modelContext: modelContext)
            let suggestion = merchantService.suggest(for: parsed.note)
            switch suggestion {
            case .suggest(let sub), .autoAssign(let sub):
                matchedSubcategory = sub
                needsUserInputFields.removeAll { $0 == "subcategory" }
            case .none:
                break
            }
        }

        // Try to match tag hints with existing tags
        var matchedTags: [Tag] = []
        var newlyCreatedTagNames: [String] = []
        if !parsed.tagHints.isEmpty {
            let result = findTags(matching: parsed.tagHints)
            matchedTags = result.tags
            newlyCreatedTagNames = result.newlyCreatedNames
        }

        let draft = InboxDraft(
            note: parsed.note,
            amount: amountDouble,
            date: parsed.date,
            account: matchedAccount,
            subcategory: matchedSubcategory,
            tags: matchedTags,
            sourceType: .voice,
            rawText: transcription,
            confidenceAmount: parsed.confidence.amount,
            confidenceDate: parsed.confidence.date,
            confidenceMerchant: parsed.confidence.merchant,
            confidenceSubcategory: matchedSubcategory != nil ? parsed.confidence.subcategory : nil,
            needsUserInput: needsUserInputFields,
            newlyCreatedTagNames: newlyCreatedTagNames
        )
        if insertInContext {
            modelContext.insert(draft)
        }
        return draft
    }

    // MARK: - Deduplication Helpers

    private func fetchPendingDrafts() -> [InboxDraft] {
        let descriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { draft in
                draft.statusRaw == "pending"
            }
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("VoiceRecordingView: Error fetching pending drafts: \(error)")
            #endif
            return []
        }
    }

    // MARK: - Subcategory Helpers

    /// Fetches all visible subcategory names, separated by expense/income
    private func fetchSubcategoryNames() -> (expense: [String], income: [String]) {
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate<Subcategory> { subcategory in
                subcategory.isVisible == true
            }
        )

        let subcategories: [Subcategory]
        do {
            subcategories = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("VoiceRecordingView: Error fetching subcategory names: \(error)")
            #endif
            return ([], [])
        }

        let expenseNames = subcategories
            .filter { !$0.safeCategory.isIncome }
            .map { $0.name }

        let incomeNames = subcategories
            .filter { $0.safeCategory.isIncome }
            .map { $0.name }

        return (expenseNames, incomeNames)
    }

    // MARK: - Entity Matching

    /// Normalizes a string for accent-insensitive comparison (lowercased, trimmed, diacritics removed)
    private func normalizeForMatching(_ text: String) -> String {
        text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
    }

    /// Finds a subcategory matching the hint (case-insensitive, accent-insensitive, partial match)
    /// Returns nil if multiple matches found (ambiguous) to let user choose manually
    private func findSubcategory(matching hint: String, isExpense: Bool) -> Subcategory? {
        let normalizedHint = normalizeForMatching(hint)

        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate<Subcategory> { subcategory in
                subcategory.isVisible == true
            }
        )

        let subcategories: [Subcategory]
        do {
            subcategories = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("VoiceRecordingView: Error fetching subcategories for matching: \(error)")
            #endif
            return nil
        }

        // Filter by expense type (subcategories in expense categories for expenses, income for income)
        let filtered = subcategories.filter { sub in
            let category = sub.safeCategory
            return isExpense ? !category.isIncome : category.isIncome
        }

        // Try exact match first - check for duplicates
        let exactMatches = filtered.filter { normalizeForMatching($0.name) == normalizedHint }
        if exactMatches.count == 1 {
            return exactMatches.first
        } else if exactMatches.count > 1 {
            // Ambiguous: multiple subcategories with same name in different categories
            return nil
        }

        // Try contains match - check for duplicates
        let partialMatches = filtered.filter { normalizeForMatching($0.name).contains(normalizedHint) }
        if partialMatches.count == 1 {
            return partialMatches.first
        } else if partialMatches.count > 1 {
            // Ambiguous: multiple matches
            return nil
        }

        // Try if hint contains subcategory name - check for duplicates
        let reverseMatches = filtered.filter { normalizedHint.contains(normalizeForMatching($0.name)) }
        if reverseMatches.count == 1 {
            return reverseMatches.first
        }
        // Multiple reverse matches = ambiguous, return nil

        return nil
    }

    /// Finds or creates tags matching the hints (case-insensitive, accent-insensitive)
    /// Creates new tags if they don't exist
    /// Returns tuple: (matched tags, names of newly created tags)
    private func findTags(matching hints: [String]) -> (tags: [Tag], newlyCreatedNames: [String]) {
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate<Tag> { tag in
                tag.isActive == true
            }
        )

        let allTags: [Tag]
        do {
            allTags = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("VoiceRecordingView: Error fetching tags: \(error)")
            #endif
            return ([], [])
        }

        var matched: [Tag] = []
        var newlyCreatedNames: [String] = []
        var usedColors = allTags.map { $0.colorHex }

        for hint in hints {
            let normalizedHint = normalizeForMatching(hint)
            guard !normalizedHint.isEmpty else { continue }

            // Try exact match first
            if let exact = allTags.first(where: { normalizeForMatching($0.name) == normalizedHint }) {
                if !matched.contains(where: { $0.persistentModelID == exact.persistentModelID }) {
                    matched.append(exact)
                }
                continue
            }

            // Try contains match
            if let partial = allTags.first(where: { normalizeForMatching($0.name).contains(normalizedHint) }) {
                if !matched.contains(where: { $0.persistentModelID == partial.persistentModelID }) {
                    matched.append(partial)
                }
                continue
            }

            // No match found - create new tag
            let capitalizedName = hint.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
            let nextColor = Tag.nextAvailableColor(excluding: usedColors)
            let newTag = Tag(name: capitalizedName, colorHex: nextColor)
            usedColors.append(nextColor)
            modelContext.insert(newTag)
            matched.append(newTag)
            newlyCreatedNames.append(capitalizedName)
        }

        return (matched, newlyCreatedNames)
    }

    /// Finds an account matching the currency code
    /// Returns nil if no match or multiple matches (ambiguous)
    private func findAccount(byCurrency currencyCode: String) -> Account? {
        let normalizedCode = currencyCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate<Account> { account in
                account.isArchived == false
            }
        )

        let accounts: [Account]
        do {
            accounts = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("VoiceRecordingView: Error fetching accounts: \(error)")
            #endif
            return nil
        }

        // Find accounts with matching currency
        let matches = accounts.filter { $0.currencyCode.uppercased() == normalizedCode }

        // Return only if exactly one match
        if matches.count == 1 {
            return matches.first
        }

        return nil
    }
}

#Preview {
    VoiceRecordingView()
}
