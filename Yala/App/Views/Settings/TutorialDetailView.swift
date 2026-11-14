//
//  TutorialDetailView.swift
//  Yala
//
//  Created by Yala.
//

import AVKit
import SwiftUI

struct TutorialDetailView: View {
    let tutorial: Tutorial

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var introIconSize: CGFloat = 60 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .largeTitle) private var placeholderIconSize: CGFloat = 40 // A11Y-DT: @ScaledMetric
    @State private var currentPage = 0
    @State private var isVideoPlaying = false

    private var steps: [TutorialStep] { tutorial.steps }
    /// Total pages: intro (1) + video steps (N) + completion (1)
    private var totalPages: Int { 1 + steps.count + 1 }
    private var isIntroPage: Bool { currentPage == 0 }
    private var isCompletionPage: Bool { currentPage == totalPages - 1 }
    /// The step index for pages 1...N
    private var currentStepIndex: Int? {
        let idx = currentPage - 1
        return idx >= 0 && idx < steps.count ? idx : nil
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
                progressIndicator
                    .padding(.top, DS.Spacing.md)

                TabView(selection: $currentPage) {
                    // Page 0: Intro
                    introView
                        .tag(0)

                    // Pages 1...N: Steps with video
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        stepView(step, stepNumber: index + 1)
                            .tag(index + 1)
                    }

                    // Last page: Completion
                    TutorialCompletionView(
                        tutorial: tutorial,
                        onDismiss: { dismiss() },
                        onNextTutorial: nil
                    )
                    .tag(totalPages - 1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .dsAnimation(.easeInOut(duration: 0.3), value: currentPage, reduceMotion: reduceMotion)

                if !isCompletionPage {
                    navigationButtons
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.bottom, DS.Spacing.xxxl)
                }
            }
        .yalaScreenBackground(.subtle)
        .onChange(of: currentPage) {
            isVideoPlaying = false
            if currentPage == totalPages - 1 {
                UserDefaults.standard.set(true, forKey: tutorial.completionKey)
            }
        }
        // Tope con motivo: cada paso es una página de un `TabView` paginado, sin scroll propio, con el vídeo
        // y los botones de navegación compartiendo el alto de la pantalla. Pasado AX1 el texto de un paso no
        // cabe en su página y se cortaría sin forma de leerlo. Quitarlo pide dar scroll a cada página.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .navigationTitle(tutorial.title)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Progress Indicator

    /// Un punto por PASO, los mismos que dice la lista («4 pasos»). E14 del recorrido del 13-nov: la Bandeja decía «4
    /// pasos» y enseñaba 6 puntos, porque la portada y el final también llevaban el suyo. En la portada todos vacíos; en
    /// el final, todos llenos.
    private var progressIndicator: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(0..<TutorialProgressDots.count(steps: steps.count), id: \.self) { dot in
                let state = TutorialProgressDots.state(dot: dot, page: currentPage, steps: steps.count)

                Capsule()
                    .fill(state == .upcoming ? theme.secondaryText.opacity(0.2) : theme.accent)
                    .frame(width: state == .current ? 24 : 8, height: 8)
                    .dsAnimation(.spring(response: 0.3), value: currentPage, reduceMotion: reduceMotion)
            }
        }
    }

    // MARK: - Intro View

    private var introView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()

            // Large icon
            Image(systemName: tutorial.icon)
                .font(.system(size: introIconSize))
                .foregroundStyle(tutorial.color)
                .padding(DS.Spacing.xl)
                .background(
                    Circle()
                        .fill(tutorial.color.opacity(0.1))
                )

            VStack(spacing: DS.Spacing.sm) {
                Text(tutorial.introTitle)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)

                Text(tutorial.introDescription)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.xl)

            Spacer()
            Spacer()
        }
        .padding(.top, DS.Spacing.md)
    }

    // MARK: - Step View

    @ViewBuilder
    private func stepView(_ step: TutorialStep, stepNumber: Int) -> some View {
        VStack(spacing: DS.Spacing.md) {
            // Step number + instruction
            VStack(spacing: DS.Spacing.xs) {
                Text(L10n.Tutorials.stepLabel(stepNumber))
                    .font(DS.Typography.headline)
                    .foregroundStyle(theme.accentText)

                Text(step.title)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let desc = step.description, !desc.isEmpty {
                    Text(desc)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)

            // Video, screenshot, or placeholder
            mediaView(step)

            Spacer(minLength: 0)
        }
        .padding(.top, DS.Spacing.md)
    }

    // MARK: - Media (Video / Screenshot / Placeholder)

    @ViewBuilder
    private func mediaView(_ step: TutorialStep) -> some View {
        if step.videoURL != nil {
            LoopingVideoView(step: step, isPlaying: $isVideoPlaying, loopEnabled: !reduceMotion)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay {
                    if !isVideoPlaying {
                        Button {
                            isVideoPlaying = true
                        } label: {
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .fill(.black.opacity(0.15))
                                .overlay {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                                }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .transition(.opacity)
                    }
                }
                .dsAnimation(.easeInOut(duration: 0.2), value: isVideoPlaying, reduceMotion: reduceMotion)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .padding(.horizontal, DS.Spacing.md)
        } else if let name = step.screenshotName, let image = UIImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .padding(.horizontal, DS.Spacing.md)
        } else {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(.thCard)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: tutorial.icon)
                            .font(.system(size: placeholderIconSize))
                            .foregroundStyle(tutorial.color.opacity(0.4))
                        Text(tutorial.title)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.thSecondaryText.opacity(0.6))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .padding(.horizontal, DS.Spacing.lg)
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: DS.Spacing.md) {
            if !isIntroPage {
                Button {
                    dsWithAnimation(reduceMotion) {
                        currentPage -= 1
                    }
                } label: {
                    Text(L10n.Tutorials.previous)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.thPrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(.thCard)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
            }

            Button {
                dsWithAnimation(reduceMotion) {
                    currentPage += 1
                }
            } label: {
                Text(isIntroPage ? L10n.Tutorials.start : L10n.Tutorials.next)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.thOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            }
        }
    }
}

// MARK: - Looping Video Player

// Sin `private`: la guía por pasos de Apple Pay (`ApplePayAutomationGuideView`) enseña el vídeo del paso activo como
// «Lo que vas a ver».
struct LoopingVideoView: UIViewRepresentable {
    let step: TutorialStep
    @Binding var isPlaying: Bool
    var loopEnabled: Bool = true

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        let view = LoopingPlayerUIView(url: step.videoURL)
        view.loopEnabled = loopEnabled
        return view
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.loopEnabled = loopEnabled
        // Only reinit player if URL actually changed (prevents mid-play reset)
        uiView.updateURL(step.videoURL)
        if isPlaying {
            uiView.play()
        } else {
            uiView.pause()
        }
    }

    static func dismantleUIView(_ uiView: LoopingPlayerUIView, coordinator: ()) {
        uiView.stop()
    }
}

final class LoopingPlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var player: AVPlayer?
    private var currentURL: URL?
    private var endObserver: Any?
    private var restartTask: Task<Void, Never>?
    var loopEnabled: Bool = true

    /// Seconds to freeze on the last frame before restarting
    private let freezeDuration: TimeInterval = 2.0

    init(url: URL?) {
        super.init(frame: .zero)
        backgroundColor = .clear
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
        setupPlayer(url: url)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func updateURL(_ url: URL?) {
        guard url != currentURL else { return }
        setupPlayer(url: url)
    }

    private func setupPlayer(url: URL?) {
        cleanUp()
        currentURL = url

        guard let url else {
            playerLayer.player = nil
            return
        }

        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.isMuted = true
        player = avPlayer
        playerLayer.player = avPlayer

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRestart()
        }

        // Start paused — show true first frame as thumbnail
        avPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func play() {
        player?.play()
    }

    func pause() {
        restartTask?.cancel()
        restartTask = nil
        player?.pause()
    }

    func stop() {
        cleanUp()
    }

    private func scheduleRestart() {
        guard loopEnabled else { return }
        let freeze = freezeDuration
        restartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(freeze))
            guard !Task.isCancelled else { return }
            guard let self, let player = self.player else { return }
            await player.seek(to: .zero)
            player.play()
        }
    }

    private func cleanUp() {
        restartTask?.cancel()
        restartTask = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player?.pause()
        player = nil
    }

    deinit {
        cleanUp()
    }
}

/// Los puntos de progreso de un tutorial de la biblioteca: uno por paso, sin la portada ni el final (E14, 13-nov).
nonisolated enum TutorialProgressDots {
    enum State: Equatable { case done, current, upcoming }

    /// Tantos puntos como pasos: lo que dice la fila de la lista.
    static func count(steps: Int) -> Int { steps }

    /// La página 0 es la portada, de la 1 a la N los pasos y la N + 1 el final.
    static func state(dot: Int, page: Int, steps: Int) -> State {
        let stepPage = dot + 1
        if page > stepPage { return .done }
        if page == stepPage { return .current }
        return .upcoming
    }
}
