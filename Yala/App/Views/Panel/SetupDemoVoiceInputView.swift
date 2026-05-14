//
//  SetupDemoVoiceInputView.swift
//  Yala
//
//  Demo standalone educativa del Step 5 (tryVoiceInput) del Setup Checklist.
//  Replica visualmente el VoiceRecordingView con sub-states locales
//  (idle/recording/countdown/processing/result) sin tocar mic ni servicios reales.
//  Reusa `ProcessingProgressView(.stepped)` shared para el processing state.
//  Activa el trial Pro Setup en `onComplete` (decisión F1d).
//

import SwiftUI

struct SetupDemoVoiceInputView: View {

    enum VoicePhase {
        case idle
        case recording
        case countdown
        case processing
        case result
    }

    // MARK: - Callbacks

    let onClose: () -> Void
    let onComplete: () -> Void

    // MARK: - Environment

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme

    // MARK: - Demo state

    @State private var demoTask: Task<Void, Never>?
    @State private var phase: VoicePhase = .idle
    @State private var simulatedDuration: Double = 0
    @State private var countdownValue: Int = 3
    @State private var processingStepIndex: Int = 0

    // Completion state
    @State private var demoCompleted: Bool = false
    @State private var progress: Double = 0
    @State private var ctaPulse: Bool = false

    // Cached L10n
    @State private var savedToastText: String = ""

    private var demoAccent: Color { Color.electricIndigo }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                mainContent
            }
            .navigationTitle(L10n.Voice.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        onClose()
                    }
                }
            }
        }
        .task {
            cacheL10n()
            startDemoScript()
        }
        .onDisappear {
            demoTask?.cancel()
            demoTask = nil
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: DS.Spacing.xxl) {
            if phase == .processing {
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
                    statusText: L10n.Voice.analyzing
                )
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            } else if phase == .result {
                resultView
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            } else {
                Spacer()
                recordingVisualizationMock
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                statusTextMock
                    .transition(.opacity)
                Spacer()
            }
        }
        .padding(DS.Spacing.xl)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: phase)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DS.Spacing.sm) {
                progressBar
                ctaFooter
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
            .background(
                Rectangle()
                    .fill(.thBackground)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    // MARK: - Recording visualization mock (replica VoiceRecordingView.recordingVisualization)

    private var recordingVisualizationMock: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: phase != .recording)) { context in
            let elapsed = phase == .recording ? simulatedDuration : 0
            ZStack {
                // Pulsing rings cuando recording
                if phase == .recording && !reduceMotion {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                Color.hotPink.opacity(0.3 - Double(index) * 0.1),
                                lineWidth: 2
                            )
                            .frame(width: 140 + CGFloat(index) * 30, height: 140 + CGFloat(index) * 30)
                            .scaleEffect(1.0 + sin(elapsed * 3 - Double(index) * 0.5) * 0.08)
                    }
                }

                // Outer glow
                if phase == .recording {
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

                // Progress ring
                if phase == .recording {
                    Circle()
                        .trim(from: 0, to: CGFloat(fmod(elapsed / 60.0, 1.0)))
                        .stroke(Color.hotPink.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 148, height: 148)
                        .rotationEffect(.degrees(-90))
                }

                // Main circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.hotPink, Color.hotPink.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.hotPink.opacity(0.4), radius: 20, x: 0, y: 8)

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
                Image(systemName: phase == .recording ? "waveform" : "mic.fill")
                    .font(DS.Typography.amountLarge)
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative, isActive: phase == .recording)
            }
        }
    }

    // MARK: - Status text mock

    @ViewBuilder
    private var statusTextMock: some View {
        VStack(spacing: DS.Spacing.sm) {
            switch phase {
            case .recording:
                Text(formatDuration(simulatedDuration))
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

            case .countdown:
                ZStack {
                    Circle()
                        .stroke(Color.hotPink.opacity(0.2), lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(countdownValue) / 3.0)
                        .stroke(Color.hotPink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: countdownValue)

                    Text("\(countdownValue)")
                        .font(DS.Typography.amountLarge)
                        .foregroundStyle(Color.hotPink)
                        .contentTransition(.numericText())
                }

                Text(L10n.Voice.recorded)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .glassEffect()

            default:
                // .idle — instrucción simple
                Text(L10n.Voice.tapToRecord)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let totalMs = Int(seconds * 1000)
        let mins = totalMs / 60000
        let secs = (totalMs / 1000) % 60
        let tenths = (totalMs / 100) % 10
        return String(format: "%02d:%02d.%01d", mins, secs, tenths)
    }

    // MARK: - Result mock

    private var resultView: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.priorityNeed.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 8)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.priorityNeed, Color.priorityNeed.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.priorityNeed.opacity(0.4), radius: 20, x: 0, y: 8)

                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(L10n.SetupChecklist.Demo.voiceTranscriptionDetected)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)
                .multilineTextAlignment(.center)

            successToast

            restartButton

            Spacer()
        }
    }

    // MARK: - Toast + Restart

    private var successToast: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(demoAccent)
            Text(savedToastText)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(Capsule().fill(.thCard))
        .overlay(Capsule().stroke(demoAccent.opacity(0.5), lineWidth: 1.5))
    }

    private var restartButton: some View {
        Button {
            restartDemo()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "arrow.counterclockwise")
                    .font(DS.Typography.label.weight(.semibold))
                Text(L10n.SetupChecklist.Demo.restart)
                    .font(DS.Typography.label.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.SetupChecklist.Demo.restart)
    }

    // MARK: - Progress bar + CTA

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 4)
                Capsule()
                    .fill(demoAccent)
                    .frame(width: max(0, min(geo.size.width, geo.size.width * progress)), height: 4)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private var ctaFooter: some View {
        VStack(spacing: DS.Spacing.xs) {
            Button {
                guard demoCompleted else { return }
                // F1d: activar trial Pro Setup al completar demo voice
                FeatureGateService.shared.enableSetupTrial(for: .voiceInput)
                onComplete()
            } label: {
                Text(L10n.SetupChecklist.Demo.gotIt)
                    .font(DS.Typography.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(demoCompleted ? demoAccent : DS.Semantic.disabledForeground.opacity(0.4))
            .controlSize(.large)
            .disabled(!demoCompleted)
            .scaleEffect(ctaPulse ? 1.03 : 1.0)
            .accessibilityHint(demoCompleted ? "" : L10n.SetupChecklist.Demo.waitForCompletion)

            if !demoCompleted {
                Text(L10n.SetupChecklist.Demo.waitForCompletion)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: demoCompleted)
    }

    // MARK: - Script

    @MainActor
    private func cacheL10n() {
        savedToastText = L10n.SetupChecklist.Demo.voiceSavedToast
    }

    @MainActor
    private func startDemoScript() {
        demoTask?.cancel()

        if voiceOverEnabled {
            applyFinalState()
            demoCompleted = true
            progress = 1.0
            return
        }

        demoTask = Task { @MainActor in
            await runOneIteration()
            guard !Task.isCancelled else { return }
            demoCompleted = true
            pulseCTA()
        }
    }

    @MainActor
    private func restartDemo() {
        demoTask?.cancel()
        resetState(keepCompleted: true)
        startDemoScript()
    }

    @MainActor
    private func runOneIteration() async {
        // Stage 0: idle
        phase = .idle
        await advance(to: 0.05)
        try? await Task.sleep(for: .milliseconds(1000))

        // Stage 1: recording (~2500ms con ticks de simulatedDuration)
        guard !Task.isCancelled else { return }
        phase = .recording
        await advance(to: 0.15)
        let recordingStart = Date()
        let recordingDuration: Double = 2.5
        while !Task.isCancelled {
            let elapsed = Date().timeIntervalSince(recordingStart)
            if elapsed >= recordingDuration { break }
            simulatedDuration = elapsed
            try? await Task.sleep(for: .milliseconds(50))
        }
        simulatedDuration = recordingDuration
        await advance(to: 0.32)

        // Stage 2: countdown 3 → 2 → 1
        guard !Task.isCancelled else { return }
        phase = .countdown
        countdownValue = 3
        for value in [3, 2, 1] {
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) {
                countdownValue = value
            }
            try? await Task.sleep(for: .milliseconds(500))
            await advance(to: 0.32 + 0.12 * Double([3, 2, 1].firstIndex(of: value)! + 1) / 3.0)
        }

        // Stage 3: processing — 3 steps
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
            phase = .processing
            processingStepIndex = 0
        }
        try? await Task.sleep(for: .milliseconds(900))
        for step in 1..<3 {
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                processingStepIndex = step
            }
            try? await Task.sleep(for: .milliseconds(900))
            await advance(to: 0.55 + 0.25 * Double(step + 1) / 3.0)
        }

        try? await Task.sleep(for: .milliseconds(500))

        // Stage 4: result
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
            phase = .result
        }
        await advance(to: 1.0)
        try? await Task.sleep(for: .milliseconds(1200))
    }

    @MainActor
    private func advance(to target: Double) async {
        withAnimation(reduceMotion ? nil : .linear(duration: 0.2)) {
            progress = min(target, 1.0)
        }
    }

    @MainActor
    private func applyFinalState() {
        phase = .result
        simulatedDuration = 2.5
        processingStepIndex = 2
    }

    @MainActor
    private func resetState(keepCompleted: Bool) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
            phase = .idle
        }
        simulatedDuration = 0
        countdownValue = 3
        processingStepIndex = 0
        if !keepCompleted {
            demoCompleted = false
            progress = 0
        }
    }

    @MainActor
    private func pulseCTA() {
        guard !reduceMotion else { return }
        withAnimation(.smooth(duration: 0.25).repeatCount(2, autoreverses: true)) {
            ctaPulse.toggle()
        }
    }
}
