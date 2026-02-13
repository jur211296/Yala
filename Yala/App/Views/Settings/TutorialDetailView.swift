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
    @State private var currentPage = 0

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
        ZStack {
            PanelBackgroundView()

            VStack(spacing: DS.Spacing.lg) {
                progressIndicator
                    .padding(.top, DS.Spacing.md)

                TabView(selection: $currentPage) {
                    // Page 0: Intro
                    introView
                        .tag(0)

                    // Pages 1...N: Steps with video
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        stepView(step)
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
        }
        .navigationTitle(tutorial.title)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: "Atrás") {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(0..<totalPages, id: \.self) { page in
                let isCurrent = page == currentPage
                let isPast = page < currentPage
                let isEdge = page == 0 || page == totalPages - 1

                Capsule()
                    .fill(isPast || isCurrent ? Color.electricIndigo : Color.yalaSecondaryText.opacity(0.2))
                    .frame(
                        width: isCurrent ? 24 : (isEdge ? 6 : 8),
                        height: isEdge ? 6 : 8
                    )
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
                .font(.system(size: 60))
                .foregroundStyle(tutorial.color)
                .padding(DS.Spacing.xl)
                .background(
                    Circle()
                        .fill(tutorial.color.opacity(0.1))
                )

            VStack(spacing: DS.Spacing.sm) {
                Text(tutorial.introTitle)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(Color.yalaPrimaryText)
                    .multilineTextAlignment(.center)

                Text(tutorial.introDescription)
                    .font(DS.Typography.body)
                    .foregroundStyle(Color.yalaSecondaryText)
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
    private func stepView(_ step: TutorialStep) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            // Text content
            VStack(spacing: DS.Spacing.xs) {
                Text(step.title)
                    .font(.title3.bold())
                    .foregroundStyle(Color.yalaPrimaryText)
                    .multilineTextAlignment(.center)

                Text(step.description)
                    .font(DS.Typography.body)
                    .foregroundStyle(Color.yalaSecondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.xl)

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
            LoopingVideoView(step: step)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .padding(.horizontal, DS.Spacing.lg)
        } else if let name = step.screenshotName, let image = UIImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .padding(.horizontal, DS.Spacing.lg)
        } else {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.yalaCard)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: tutorial.icon)
                            .font(.system(size: 40))
                            .foregroundStyle(tutorial.color.opacity(0.4))
                        Text(tutorial.title)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(Color.yalaSecondaryText.opacity(0.6))
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
                        .foregroundStyle(Color.yalaPrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(Color.yalaCard)
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
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(Color.electricIndigo)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            }
        }
    }
}

// MARK: - Looping Video Player

private struct LoopingVideoView: UIViewRepresentable {
    let step: TutorialStep

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(url: step.videoURL)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.updateURL(step.videoURL)
    }
}

private final class LoopingPlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

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
        player?.pause()
        looper = nil
        player = nil
        currentURL = url

        guard let url else {
            playerLayer.player = nil
            return
        }

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        queuePlayer.isMuted = true
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        playerLayer.player = queuePlayer
        queuePlayer.play()
    }
}
