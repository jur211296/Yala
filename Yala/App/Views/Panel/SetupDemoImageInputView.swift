//
//  SetupDemoImageInputView.swift
//  Yala
//
//  Demo standalone educativa del Step 6 (tryImageInput) del Setup Checklist.
//  Replica visualmente el ImageSelectionView con sub-states locales
//  (selection/preview/countdown/processing/result) sin tocar PhotosPicker ni
//  ImageVisionService. Reusa `ProcessingProgressView(.determinate)` shared y
//  `ExampleImagesLoader.load()` para los 3 example cards bundled.
//  Activa el trial Pro Setup en `onComplete` (decisión F1d).
//

import SwiftUI

struct SetupDemoImageInputView: View {

    enum ImagePhase {
        case selection
        case preview
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
    @State private var phase: ImagePhase = .selection
    @State private var exampleImages: [UIImage] = []
    @State private var selectedImage: UIImage? = nil
    @State private var highlightedExampleIndex: Int? = nil
    @State private var countdownValue: Int = 3
    @State private var processingProgress: (current: Int, total: Int) = (0, 3)

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
            .navigationTitle(L10n.Image.title)
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
            loadExamples()
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
        VStack(spacing: DS.Spacing.xl) {
            switch phase {
            case .selection:
                selectionMock
            case .preview:
                previewMock
            case .countdown:
                countdownMock
            case .processing:
                processingMock
            case .result:
                resultMock
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

    // MARK: - Selection mock

    private var selectionMock: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            // Hero Circle (replica selectionView del real)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DS.Semantic.imageAccent, DS.Semantic.imageAccent.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: DS.Semantic.imageAccent.opacity(0.4), radius: 20, x: 0, y: 8)

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

                Image(systemName: "photo.on.rectangle.angled")
                    .font(DS.Typography.amountLarge)
                    .foregroundStyle(.white)
            }

            Spacer()

            // Example gallery (3 cards horizontales)
            exampleGalleryMock

            Spacer().frame(height: DS.Spacing.xl)
        }
    }

    private var exampleGalleryMock: some View {
        VStack(spacing: DS.Spacing.md) {
            Text(L10n.SetupChecklist.ImageTrial.pickExample)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)

            let labels = [
                L10n.SetupChecklist.ImageTrial.exampleReceipt,
                L10n.SetupChecklist.ImageTrial.exampleBankAlert,
                L10n.SetupChecklist.ImageTrial.exampleTransactionList
            ]

            HStack(spacing: DS.Spacing.md) {
                ForEach(0..<3, id: \.self) { index in
                    exampleCard(label: labels[index], image: exampleImages[safe: index], isHighlighted: highlightedExampleIndex == index)
                }
            }
        }
    }

    private func exampleCard(label: String, image: UIImage?, isHighlighted: Bool) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            ZStack {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                } else {
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(.thCard)
                        .frame(width: 100, height: 130)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isHighlighted ? DS.Semantic.imageAccent : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isHighlighted ? 1.05 : 1.0)
            .shadow(color: .black.opacity(0.1), radius: isHighlighted ? 8 : 4, x: 0, y: 2)
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: isHighlighted)

            Text(label)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Preview mock

    private var previewMock: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            if let img = selectedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, DS.Spacing.lg)
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(.thCard)
                    .frame(maxHeight: 280)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary))
                    .padding(.horizontal, DS.Spacing.lg)
            }
            Text(L10n.SetupChecklist.ImageTrial.exampleReceipt)
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Countdown mock

    private var countdownMock: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            if let img = selectedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .stroke(.ultraThinMaterial, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            }

            VStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .stroke(DS.Semantic.imageAccent.opacity(0.2), lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(countdownValue) / 3.0)
                        .stroke(DS.Semantic.imageAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: countdownValue)

                    Text("\(countdownValue)")
                        .font(DS.Typography.amountLarge)
                        .foregroundStyle(DS.Semantic.imageAccent)
                        .contentTransition(.numericText())
                }

                Text(L10n.Image.analyzingIn(countdownValue))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .glassEffect()
            }

            Spacer()
        }
    }

    // MARK: - Processing mock

    private var processingMock: some View {
        ProcessingProgressView(
            mode: .determinate(
                current: processingProgress.current,
                total: processingProgress.total
            ),
            accentColor: DS.Semantic.imageAccent,
            statusText: L10n.Image.processing
        )
    }

    // MARK: - Result mock

    private var resultMock: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: DS.Gradients.success,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: DS.Semantic.successForeground.opacity(0.4), radius: 16, x: 0, y: 8)

                Circle()
                    .fill(DS.Colors.backgroundSubtle)
                    .frame(width: 100, height: 100)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )

                Image(systemName: "checkmark")
                    .font(DS.Typography.amountLarge)
                    .foregroundStyle(.white)
            }

            VStack(spacing: DS.Spacing.sm) {
                Text("1")
                    .font(DS.Typography.amountLarge)
                    .foregroundStyle(.thAccent)
                Text(L10n.SetupChecklist.Demo.voiceTranscriptionDetected)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)
            }

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
                FeatureGateService.shared.enableSetupTrial(for: .imageInput)
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

    // MARK: - Setup

    @MainActor
    private func cacheL10n() {
        savedToastText = L10n.SetupChecklist.Demo.imageProcessedToast
    }

    @MainActor
    private func loadExamples() {
        exampleImages = ExampleImagesLoader.load() ?? []
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
        // Stage 0: selection idle
        phase = .selection
        await advance(to: 0.05)
        try? await Task.sleep(for: .milliseconds(1000))

        // Stage 1: highlight "Recibo" card
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) {
            highlightedExampleIndex = 0
        }
        try? await Task.sleep(for: .milliseconds(600))

        // Stage 2: preview
        guard !Task.isCancelled else { return }
        selectedImage = exampleImages.first
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
            phase = .preview
        }
        await advance(to: 0.25)
        try? await Task.sleep(for: .milliseconds(1200))

        // Stage 3: countdown 3 → 2 → 1
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
            phase = .countdown
        }
        countdownValue = 3
        for value in [3, 2, 1] {
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) {
                countdownValue = value
            }
            try? await Task.sleep(for: .milliseconds(500))
            await advance(to: 0.30 + 0.10 * Double([3, 2, 1].firstIndex(of: value)! + 1) / 3.0)
        }

        // Stage 4: processing — determinate 0/3 → 3/3
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
            phase = .processing
            processingProgress = (0, 3)
        }
        try? await Task.sleep(for: .milliseconds(400))
        for step in 1...3 {
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
                processingProgress = (step, 3)
            }
            try? await Task.sleep(for: .milliseconds(800))
            await advance(to: 0.55 + 0.30 * Double(step) / 3.0)
        }
        try? await Task.sleep(for: .milliseconds(400))

        // Stage 5: result
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
        selectedImage = exampleImages.first
        processingProgress = (3, 3)
    }

    @MainActor
    private func resetState(keepCompleted: Bool) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
            phase = .selection
        }
        selectedImage = nil
        highlightedExampleIndex = nil
        countdownValue = 3
        processingProgress = (0, 3)
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

// MARK: - Safe Array subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
