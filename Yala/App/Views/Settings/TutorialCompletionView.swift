//
//  TutorialCompletionView.swift
//  Yala
//
//  Celebration screen shown after completing a tutorial.
//

import SwiftUI

struct TutorialCompletionView: View {
    let tutorial: Tutorial
    let onDismiss: () -> Void
    let onNextTutorial: ((Tutorial) -> Void)?

    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 36 // A11Y-DT: @ScaledMetric
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showHero = false
    @State private var showCheckmark = false
    @State private var showTitle = false
    @State private var showDescription = false
    @State private var showActions = false

    var body: some View {
        ZStack {
            // Background glow
            RadialGradient(
                colors: [tutorial.color.opacity(0.06), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 200
            )
            .frame(height: 300)
            .blur(radius: 40)
            .offset(y: -60)

            VStack(spacing: DS.Spacing.none) {
                Spacer()

                // Hero area
                VStack(spacing: DS.Spacing.lg) {
                    // Layered circle
                    ZStack {
                        // Radiant glow
                        RadialGradient(
                            colors: [tutorial.color.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 90
                        )
                        .frame(width: 180, height: 180)
                        .blur(radius: 12)
                        .opacity(showHero ? 1.0 : 0.0)

                        // Main gradient circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [tutorial.color, tutorial.color.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: tutorial.color.opacity(0.4), radius: 20, y: 8)
                            .scaleEffect(showHero ? 1.0 : 0.3)
                            .opacity(showHero ? 1.0 : 0.0)

                        // Glass overlay
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 100, height: 100)
                            .mask(
                                LinearGradient(
                                    colors: [.white, .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .opacity(showHero ? 1.0 : 0.0)

                        // White checkmark
                        Image(systemName: "checkmark")
                            .font(.system(size: heroIconSize, weight: .semibold))
                            .foregroundStyle(.white)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .scaleEffect(showCheckmark ? 1.0 : 0.0)
                            .opacity(showCheckmark ? 1.0 : 0.0)
                    }

                    // Completion title
                    Text(tutorial.completionTitle)
                        .font(DS.Typography.largeTitle)
                        .foregroundStyle(.thPrimaryText)
                        .multilineTextAlignment(.center)
                        .opacity(showTitle ? 1.0 : 0.0)
                        .offset(y: showTitle ? 0 : 10)

                    // Tips / description
                    Text(tutorial.completionDescription)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thSecondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.Spacing.xl)
                        .opacity(showDescription ? 1.0 : 0.0)
                        .offset(y: showDescription ? 0 : 10)
                }
                .padding(.bottom, DS.Spacing.xxxl)

                Spacer()

                // Action buttons
                VStack(spacing: DS.Spacing.md) {
                    Button(action: onDismiss) {
                        Text(L10n.Tutorials.understood)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    .controlSize(.large)

                    if let next = tutorial.nextTutorial, let onNext = onNextTutorial {
                        Button {
                            onNext(next)
                        } label: {
                            Text(L10n.Tutorials.nextTutorial)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        .controlSize(.large)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxxl)
                .opacity(showActions ? 1.0 : 0.0)
                .offset(y: showActions ? 0 : 10)
            }

            // Confetti overlay
            if showCheckmark {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            DS.Haptic.success()
            if reduceMotion {
                showHero = true
                showCheckmark = true
                showTitle = true
                showDescription = true
                showActions = true
            } else {
                Task {
                    // 0ms — hero circle
                    withAnimation(.spring(response: 0.5, dampingFraction: DS.Animation.springBouncy)) {
                        showHero = true
                    }

                    // 150ms — checkmark
                    try? await Task.sleep(for: .milliseconds(150))
                    withAnimation(.spring(response: 0.4, dampingFraction: DS.Animation.springBouncy)) {
                        showCheckmark = true
                    }

                    // 300ms — title
                    try? await Task.sleep(for: .milliseconds(150))
                    withAnimation(.easeOut(duration: 0.35)) {
                        showTitle = true
                    }

                    // 500ms — description
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation(.easeOut(duration: 0.35)) {
                        showDescription = true
                    }

                    // 700ms — actions
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation(.easeOut(duration: 0.3)) {
                        showActions = true
                    }
                }
            }
        }
    }
}
