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
    @State private var currentStep = 0

    private var steps: [TutorialStep] { tutorial.steps }
    private var isLastStep: Bool { currentStep == steps.count - 1 }
    private var isFirstStep: Bool { currentStep == 0 }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: DS.Spacing.lg) {
                progressIndicator
                    .padding(.top, DS.Spacing.md)

                TabView(selection: $currentStep) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        stepView(step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .dsAnimation(.easeInOut(duration: 0.3), value: currentStep, reduceMotion: reduceMotion)

                navigationButtons
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xxxl)
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
            ForEach(0..<steps.count, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? tutorial.color : Color.yalaSecondaryText.opacity(0.2))
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
                    .dsAnimation(.spring(response: 0.3), value: currentStep, reduceMotion: reduceMotion)
            }
        }
    }

    // MARK: - Step View

    @ViewBuilder
    private func stepView(_ step: TutorialStep) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            // Text content
            VStack(spacing: DS.Spacing.xs) {
                Text("\(step.id + 1)/\(steps.count)")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(tutorial.color)

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
            if !isFirstStep {
                Button {
                    dsWithAnimation(reduceMotion) {
                        currentStep -= 1
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
                if isLastStep {
                    dismiss()
                } else {
                    dsWithAnimation(reduceMotion) {
                        currentStep += 1
                    }
                }
            } label: {
                Text(isLastStep ? L10n.Tutorials.done : L10n.Tutorials.next)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(tutorial.color)
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
