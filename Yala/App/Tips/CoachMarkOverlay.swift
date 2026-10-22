//
//  CoachMarkOverlay.swift
//  Yala
//
//  Custom coach mark overlay with spotlight dimming and guided navigation.
//  Replaces TipKit popoverTip for guided tours (Groups A and B).
//

import SwiftUI

// MARK: - CoachMarkStep

struct CoachMarkStep: Identifiable {
    let id: String
    let title: String
    let message: String
    let spotlightPadding: CGFloat

    init(id: String, title: String, message: String, spotlightPadding: CGFloat = DS.Spacing.sm) {
        self.id = id
        self.title = title
        self.message = message
        self.spotlightPadding = spotlightPadding
    }
}

// MARK: - Anchor Preference Key

struct CoachMarkAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Anchor Modifier

extension View {
    /// Registers this view as a coach mark anchor with the given ID.
    /// Sets `.id()` for ScrollViewReader and uses `transformAnchorPreference`
    /// so multiple anchors on the same view don't overwrite each other.
    func coachMarkAnchor(_ id: String) -> some View {
        self
            .id(id)
            .transformAnchorPreference(key: CoachMarkAnchorKey.self, value: .bounds) { dict, anchor in
                dict[id] = anchor
            }
    }
}

// MARK: - Animatable Spotlight Rect

/// Wrapper around CGRect that conforms to Animatable without polluting the global CGRect type.
private struct AnimatableRect: Animatable {
    var x, y, width, height: CGFloat

    init(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }

    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { .init(.init(x, y), .init(width, height)) }
        set {
            x = newValue.first.first
            y = newValue.first.second
            width = newValue.second.first
            height = newValue.second.second
        }
    }
}

// MARK: - Animatable Spotlight Shape

/// A shape that fills everything EXCEPT a rounded rect hole (the spotlight).
/// Because it's a Shape, SwiftUI can animate changes to the hole's position and size.
private struct SpotlightCutoutShape: Shape {
    var spotlight: AnimatableRect
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<AnimatableRect.AnimatableData, CGFloat> {
        get { .init(spotlight.animatableData, cornerRadius) }
        set {
            spotlight.animatableData = newValue.first
            cornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(
            in: spotlight.rect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return path
    }
}

// MARK: - Animatable Spotlight Border

/// Draws just the rounded rect border of the spotlight, sharing the same
/// AnimatableRect mechanism so the glow stays in sync with the cutout.
private struct SpotlightBorderShape: Shape {
    var spotlight: AnimatableRect
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<AnimatableRect.AnimatableData, CGFloat> {
        get { .init(spotlight.animatableData, cornerRadius) }
        set {
            spotlight.animatableData = newValue.first
            cornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        Path(roundedRect: spotlight.rect, cornerRadius: cornerRadius)
    }
}

// MARK: - Layout Constants

private enum CoachMarkLayout {
    static let dimOpacity: Double = 0.65
    static let darkDimOpacity: Double = 0.75
    static let tooltipGap: CGFloat = 80
    static let visibilityMargin: CGFloat = 100
    static let spotlightBorderWidth: CGFloat = 2
    static let spotlightGlowRadius: CGFloat = 12
}

// MARK: - Coach Mark Overlay

struct CoachMarkOverlay: View {
    let steps: [CoachMarkStep]
    let anchors: [String: Anchor<CGRect>]
    let proxy: GeometryProxy
    let scrollProxy: ScrollViewProxy?
    @Binding var currentIndex: Int
    @Binding var isPresented: Bool
    let onComplete: () -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var showTooltip = false
    /// Prevents interaction during transitions and initial appearance
    @State private var isTransitioning = false
    /// Bumped after programmatic scroll to force re-evaluation of anchor frames
    @State private var scrollSettleToken = 0
    /// Incremented on each transition; stale asyncAfter closures bail out when their
    /// captured generation no longer matches.
    @State private var transitionGeneration: UInt = 0

    private var currentStep: CoachMarkStep? {
        guard currentIndex < steps.count else { return nil }
        return steps[currentIndex]
    }

    /// Resolves the current anchor frame, returning nil if off-screen
    private func resolveFrame(for step: CoachMarkStep) -> CGRect? {
        guard let anchor = anchors[step.id] else { return nil }
        let frame = proxy[anchor]
        let visibleBounds = CGRect(origin: .zero, size: proxy.size)
        let expandedBounds = visibleBounds.insetBy(dx: 0, dy: -CoachMarkLayout.visibilityMargin)
        guard expandedBounds.intersects(frame) else { return nil }
        return frame
    }

    /// Padded spotlight rect for the given step and frame
    private func spotlightRect(for step: CoachMarkStep, frame: CGRect) -> CGRect {
        let padding = step.spotlightPadding
        return CGRect(
            x: frame.minX - padding,
            y: frame.minY - padding,
            width: frame.width + padding * 2,
            height: frame.height + padding * 2
        )
    }

    var body: some View {
        // scrollSettleToken dependency forces re-evaluation after programmatic scroll
        let _ = scrollSettleToken
        ZStack {
            if let step = currentStep, let frame = resolveFrame(for: step) {
                let rect = spotlightRect(for: step, frame: frame)
                let cornerRadius = min(DS.Radius.lg, rect.height / 2)

                let isDarkTheme = theme.baseColorScheme == .dark
                let dimOpacity = isDarkTheme ? CoachMarkLayout.darkDimOpacity : CoachMarkLayout.dimOpacity

                // Dimmed background with animated spotlight cutout
                SpotlightCutoutShape(spotlight: AnimatableRect(rect), cornerRadius: cornerRadius)
                    .fill(.black.opacity(dimOpacity), style: FillStyle(eoFill: true))
                    .ignoresSafeArea()
                    .opacity(isVisible ? 1 : 0)
                    .allowsHitTesting(true)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isTransitioning else { return }
                        advance()
                    }

                // Bright border around spotlight for dark themes
                if isDarkTheme {
                    SpotlightBorderShape(spotlight: AnimatableRect(rect), cornerRadius: cornerRadius)
                        .stroke(theme.accent.opacity(0.8), lineWidth: CoachMarkLayout.spotlightBorderWidth)
                        .shadow(color: theme.accent.opacity(0.5), radius: CoachMarkLayout.spotlightGlowRadius)
                        .ignoresSafeArea()
                        .opacity(isVisible ? 1 : 0)
                        .allowsHitTesting(false)
                }

                // Tooltip card
                tooltipCard(step: step, targetFrame: frame)
                    .opacity(showTooltip ? 1 : 0)
                    .offset(y: showTooltip ? 0 : 8)
            } else if isTransitioning {
                // Full-screen tap blocker while scrolling to a target that is not yet visible.
                // Prevents touch leakage to underlying content during programmatic scroll.
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                    .contentShape(Rectangle())
                    .onTapGesture { }
            }
        }
        .onAppear {
            handleStepTransition(initial: true)
        }
        .onChange(of: currentIndex) { _, _ in
            handleStepTransition(initial: false)
        }
        // Red: si el overlay se desmonta con una transición en vuelo, ningún
        // Task pendiente debe poder dejar el tap-blocker armado al remontar.
        .onDisappear {
            transitionGeneration += 1
            isTransitioning = false
        }
    }

    // MARK: - Step Transitions

    private func handleStepTransition(initial: Bool) {
        guard let step = currentStep else {
            // Fin del tour (currentIndex fuera de steps) con una transición en
            // vuelo: sin este reset, `isTransitioning` quedaba pegado y la rama
            // del tap-blocker invisible (opacity 0.001, hit-testeable) seguía
            // montada tragándose TODOS los taps — la misma clase de trampa que
            // el bug "toolbar muerta" del InboxAlertModal (TestFlight 2.0.5).
            transitionGeneration += 1
            isTransitioning = false
            return
        }
        isTransitioning = true
        transitionGeneration += 1
        let gen = transitionGeneration

        // Scroll to center the target on every step transition for best visibility.
        // scrollTo is a no-op for elements already centered or outside ScrollView (toolbar items).
        let shouldScroll = scrollProxy != nil
        let isOffScreen = resolveFrame(for: step) == nil

        if shouldScroll && (isOffScreen || !initial) {
            // Target off-screen or advancing between steps — scroll then show
            scrollThenShow(step: step, initial: initial, gen: gen)
        } else if shouldScroll && initial {
            // First appearance, target already visible — scroll to center then show
            withAnimation(.easeInOut(duration: DS.Animation.normal)) {
                scrollProxy?.scrollTo(step.id, anchor: .center)
            }
            Task {
                try? await Task.sleep(for: .seconds(DS.Animation.normal + 0.1))
                guard transitionGeneration == gen else { return }
                scrollSettleToken += 1
                dsWithAnimation(reduceMotion, .easeOut(duration: DS.Animation.slow)) {
                    isVisible = true
                }
                try? await Task.sleep(for: .seconds(DS.Animation.fast))
                guard transitionGeneration == gen else { return }
                isTransitioning = false
                dsWithAnimation(reduceMotion, .easeOut(duration: DS.Animation.normal)) {
                    showTooltip = true
                }
            }
        } else if initial {
            // No scroll proxy — fade in directly
            Task {
                try? await Task.sleep(for: .milliseconds(50))
                guard transitionGeneration == gen else { return }
                dsWithAnimation(reduceMotion, .easeOut(duration: DS.Animation.slow)) {
                    isVisible = true
                }
                try? await Task.sleep(for: .seconds(DS.Animation.fast))
                guard transitionGeneration == gen else { return }
                isTransitioning = false
                dsWithAnimation(reduceMotion, .easeOut(duration: DS.Animation.normal)) {
                    showTooltip = true
                }
            }
        } else {
            // Target visible, no scroll — crossfade tooltip
            dsWithAnimation(reduceMotion, .easeOut(duration: DS.Animation.normal)) {
                showTooltip = false
            }
            Task {
                try? await Task.sleep(for: .seconds(DS.Animation.fast))
                guard transitionGeneration == gen else { return }
                isTransitioning = false
                dsWithAnimation(reduceMotion, .easeOut(duration: DS.Animation.normal)) {
                    showTooltip = true
                }
            }
        }
    }

    private func scrollThenShow(step: CoachMarkStep, initial: Bool, gen: UInt) {
        // Hide tooltip during scroll (spotlight stays dimmed)
        if !initial {
            dsWithAnimation(reduceMotion, .easeOut(duration: DS.Animation.fast)) {
                showTooltip = false
            }
        }

        // Scroll to the target
        withAnimation(.easeInOut(duration: DS.Animation.normal)) {
            scrollProxy?.scrollTo(step.id, anchor: .center)
        }

        // Wait for scroll to settle, then show
        Task {
            try? await Task.sleep(for: .seconds(DS.Animation.normal + 0.15))
            guard transitionGeneration == gen else { return }
            scrollSettleToken += 1
            isTransitioning = false
            if !isVisible {
                dsWithAnimation(reduceMotion, .easeOut(duration: DS.Animation.slow)) {
                    isVisible = true
                }
            }
            try? await Task.sleep(for: .seconds(DS.Animation.fast))
            guard transitionGeneration == gen else { return }
            dsWithAnimation(reduceMotion, .easeOut(duration: DS.Animation.normal)) {
                showTooltip = true
            }
        }
    }

    // MARK: - Tooltip Card

    private func tooltipCard(step: CoachMarkStep, targetFrame: CGRect) -> some View {
        let screenHeight = proxy.size.height
        let isAbove = targetFrame.midY > screenHeight * 0.4

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(step.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)

            Text(step.message)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Navigation buttons
            HStack {
                // Skip button
                Button {
                    dismissAndComplete()
                } label: {
                    Text(L10n.TipKit.skip)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                // Step indicator
                Text("\(currentIndex + 1)/\(steps.count)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)

                // Next / Done button
                Button {
                    advance()
                } label: {
                    Text(currentIndex < steps.count - 1 ? L10n.TipKit.next : L10n.TipKit.done)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(theme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, DS.Spacing.xs)
        }
        .padding(DS.Spacing.xl)
        .background {
            if theme.usesMaterial {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(theme.card)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .shadow(
            color: Color.black.opacity(0.2),
            radius: 16, x: 0, y: 8
        )
        .padding(.horizontal, DS.Spacing.xl)
        .position(
            x: proxy.size.width / 2,
            y: isAbove
                ? targetFrame.minY - CoachMarkLayout.tooltipGap
                : targetFrame.maxY + CoachMarkLayout.tooltipGap
        )
    }

    // MARK: - Navigation

    private func advance() {
        guard !isTransitioning else { return }
        if currentIndex < steps.count - 1 {
            // The spotlight shape animates automatically via animatableData
            dsWithAnimation(reduceMotion, .spring(duration: 0.45, bounce: 0.15)) {
                currentIndex += 1
            }
        } else {
            dismissAndComplete()
        }
    }

    private func dismissAndComplete() {
        isTransitioning = true
        dsWithAnimation(reduceMotion, .easeIn(duration: DS.Animation.fast)) {
            showTooltip = false
            isVisible = false
        }
        Task {
            try? await Task.sleep(for: .seconds(DS.Animation.fast + 0.05))
            isPresented = false
            onComplete()
        }
    }
}

// MARK: - View Modifier

extension View {
    /// Attaches a coach mark tour overlay to this view.
    /// The view must contain children with `.coachMarkAnchor("id")` matching the step IDs.
    /// Pass a `ScrollViewProxy` to auto-scroll to off-screen targets.
    func coachMarkOverlay(
        steps: [CoachMarkStep],
        isPresented: Binding<Bool>,
        currentIndex: Binding<Int>,
        scrollProxy: ScrollViewProxy? = nil,
        onComplete: @escaping () -> Void
    ) -> some View {
        self.overlayPreferenceValue(CoachMarkAnchorKey.self) { anchors in
            if isPresented.wrappedValue {
                GeometryReader { proxy in
                    CoachMarkOverlay(
                        steps: steps,
                        anchors: anchors,
                        proxy: proxy,
                        scrollProxy: scrollProxy,
                        currentIndex: currentIndex,
                        isPresented: isPresented,
                        onComplete: onComplete
                    )
                }
                .ignoresSafeArea()
            }
        }
    }
}
