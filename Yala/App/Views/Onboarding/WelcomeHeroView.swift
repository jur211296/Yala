//
//  WelcomeHeroView.swift
//  Yala
//
//  A4 v3.1 — Pantalla de presentación entre splash y Welcome Chooser.
//  Mientras el user lee las cards animadas, el fetch de iCloud corre invisible.
//  Al tap "Empezar", ContentView decide entre alert (con data) o Chooser (sin data).
//

import SwiftData
import SwiftUI

// MARK: - Hero Decision

enum HeroDecision {
    /// Sin data en iCloud (o fetch no completó tras timeout). ContentView abre Chooser.
    case proceedNoData
    /// Data detectada. ContentView muestra alert "Detectamos tu cuenta".
    case proceedWithData(ICloudAccountSummary)
}

// MARK: - WelcomeHeroView

struct WelcomeHeroView: View {
    var onContinue: (HeroDecision) -> Void

    // MARK: State

    @State private var currentCardIndex: Int = 0
    @State private var rotationTask: Task<Void, Never>?
    @State private var iCloudFetchTask: Task<Void, Never>?
    @State private var detectedSummary: ICloudAccountSummary?
    @State private var fetchCompleted: Bool = false
    @State private var isCheckingFetch: Bool = false
    @State private var hasTappedEmpezar: Bool = false

    @Environment(\.yalaTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var appPreferences

    // MARK: Cards data

    private struct HeroCard: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
        let accentColor: Color
    }

    private var cards: [HeroCard] {
        [
            HeroCard(
                icon: "camera.fill",
                title: L10n.Welcome.Hero.Cards.Capture.title,
                body: L10n.Welcome.Hero.Cards.Capture.body,
                accentColor: .electricIndigo
            ),
            HeroCard(
                icon: "mic.fill",
                title: L10n.Welcome.Hero.Cards.Voice.title,
                body: L10n.Welcome.Hero.Cards.Voice.body,
                accentColor: .neonCyan
            ),
            HeroCard(
                icon: "arrow.down.doc.fill",
                title: L10n.Welcome.Hero.Cards.Import.title,
                body: L10n.Welcome.Hero.Cards.Import.body,
                accentColor: .priorityNeed
            ),
            HeroCard(
                icon: "creditcard.fill",
                title: L10n.Welcome.Hero.Cards.MultiAccount.title,
                body: L10n.Welcome.Hero.Cards.MultiAccount.body,
                accentColor: .hotPink
            ),
            HeroCard(
                icon: "globe",
                title: L10n.Welcome.Hero.Cards.Currencies.title,
                body: L10n.Welcome.Hero.Cards.Currencies.body,
                accentColor: .essentialNeed
            ),
            HeroCard(
                icon: "icloud.fill",
                title: L10n.Welcome.Hero.Cards.Icloud.title,
                body: L10n.Welcome.Hero.Cards.Icloud.body,
                accentColor: .electricIndigo
            ),
            HeroCard(
                icon: "sparkles",
                title: L10n.Welcome.Hero.Cards.More.title,
                body: L10n.Welcome.Hero.Cards.More.body,
                accentColor: .neonCyan
            ),
        ]
    }

    // MARK: Body

    var body: some View {
        ZStack {
            heroBackground

            VStack(spacing: 0) {
                Image("YalaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 36)
                    .padding(.top, DS.Spacing.lg)
                    .accessibilityHidden(true)

                Spacer(minLength: DS.Spacing.lg)

                cardStack
                    .frame(height: 380)

                Spacer(minLength: DS.Spacing.lg)

                titleAndSubtitle
                    .padding(.horizontal, DS.Spacing.xl)

                Spacer(minLength: DS.Spacing.xl)

                ctaSection
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xl)
            }
        }
        .task {
            startICloudFetch()
            startCardRotation()
        }
        .onDisappear {
            rotationTask?.cancel()
            iCloudFetchTask?.cancel()
        }
    }

    // MARK: Background

    private var heroBackground: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.hotPink.opacity(0.35),
                    Color.electricIndigo.opacity(0.18),
                    .clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Card stack

    private var cardStack: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { offset in
                let cardIdx = (currentCardIndex + offset) % cards.count
                let card = cards[cardIdx]
                heroCardView(card)
                    .scaleEffect(scaleForOffset(offset))
                    .rotationEffect(rotationForOffset(offset))
                    .offset(offsetForOffset(offset))
                    .opacity(opacityForOffset(offset))
                    .zIndex(Double(2 - offset))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(offset == 0 ? "\(card.title). \(card.body)" : "")
                    .accessibilityHidden(offset != 0)
            }
        }
    }

    private func heroCardView(_ card: HeroCard) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: card.icon)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))

            Text(card.title)
                .font(DS.Typography.title)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)

            Text(card.body)
                .font(DS.Typography.body)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, DS.Spacing.md)
        }
        .padding(DS.Spacing.xl)
        .frame(width: 280)
        .frame(idealHeight: 360, maxHeight: 420)
        .background(
            LinearGradient(
                colors: [card.accentColor.opacity(0.95), card.accentColor.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .shadow(color: card.accentColor.opacity(0.4), radius: 24, x: 0, y: 12)
    }

    private func scaleForOffset(_ offset: Int) -> CGFloat {
        [1.0, 0.92, 0.85][offset]
    }

    private func rotationForOffset(_ offset: Int) -> Angle {
        Angle(degrees: [0, 5, -7][offset])
    }

    private func offsetForOffset(_ offset: Int) -> CGSize {
        [.zero, CGSize(width: 12, height: 8), CGSize(width: -14, height: 16)][offset]
    }

    private func opacityForOffset(_ offset: Int) -> Double {
        [1.0, 0.6, 0.32][offset]
    }

    // MARK: Title + subtitle

    private var titleAndSubtitle: some View {
        VStack(spacing: DS.Spacing.sm) {
            VStack(spacing: 0) {
                Text(L10n.Welcome.Hero.title)
                    .foregroundStyle(.primary)
                Text(L10n.Welcome.Hero.titleAccent)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.electricIndigo, .hotPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .font(DS.Typography.largeTitle)
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(L10n.Welcome.Hero.title) \(L10n.Welcome.Hero.titleAccent)")

            Text(L10n.Welcome.Hero.subtitle)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: CTA

    private var ctaSection: some View {
        VStack(spacing: DS.Spacing.md) {
            YalaPrimaryButton(
                L10n.Welcome.Hero.cta,
                isDisabled: false,
                isLoading: isCheckingFetch
            ) {
                handleEmpezar()
            }

            Text(L10n.Welcome.Hero.trust)
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Empezar handler (single-shot, sin recursión)

    private func handleEmpezar() {
        guard !hasTappedEmpezar else { return }
        hasTappedEmpezar = true
        DS.Haptic.selection()

        Task {
            // Fast path: fetch ya completó.
            if fetchCompleted {
                await MainActor.run { dispatchDecision() }
                return
            }

            // Slow path: esperar máx 3s extra con spinner. Sin recursión.
            await MainActor.run { isCheckingFetch = true }
            for _ in 0..<6 {  // 6 × 500ms = 3s
                try? await Task.sleep(for: .milliseconds(500))
                if fetchCompleted { break }
            }
            await MainActor.run {
                isCheckingFetch = false
                dispatchDecision()
            }
        }
    }

    @MainActor
    private func dispatchDecision() {
        if let summary = detectedSummary, summary.hasAnyData {
            onContinue(.proceedWithData(summary))
        } else {
            onContinue(.proceedNoData)
        }
    }

    // MARK: Tasks

    private func startICloudFetch() {
        iCloudFetchTask = Task {
            guard iCloudSyncService.shared.isAccountAvailable else {
                await MainActor.run { fetchCompleted = true }
                return
            }
            _ = await iCloudSyncService.shared.forceFetchAndWait(timeout: 10)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                detectedSummary = try? modelContext.iCloudAccountSummary(appPreferences: appPreferences)
                fetchCompleted = true
            }
        }
    }

    private func startCardRotation() {
        rotationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.5))
                guard !Task.isCancelled else { return }
                // Pausa rotation si VoiceOver activo (a11y).
                if voiceOverEnabled { continue }
                await MainActor.run {
                    let animation: Animation? = reduceMotion
                        ? nil
                        : .spring(response: 0.6, dampingFraction: 0.75)
                    withAnimation(animation) {
                        currentCardIndex = (currentCardIndex + 1) % cards.count
                    }
                }
            }
        }
    }
}

// Preview removido: WelcomeHeroView depende de AppPreferences inyectado vía
// @Environment, ModelContext y iCloudSyncService — no es trivial mockearlos
// para el canvas. Verificación visual se hace en simulator (`/device-qa`).
