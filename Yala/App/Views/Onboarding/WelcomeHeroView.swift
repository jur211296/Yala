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

    // MARK: Constants

    /// Intervalo entre rotaciones de cards. Spring animation 0.6s ya cubre el movimiento.
    private static let cardRotationInterval: Duration = .seconds(3.5)
    /// Timeout del fetch background de iCloud durante el Hero.
    private static let iCloudFetchTimeout: TimeInterval = 10
    /// Espera adicional tras tap "Empezar" si el fetch aún no completó.
    private static let postTapWaitTimeout: Duration = .seconds(3)

    // MARK: State

    @State private var currentCardIndex: Int = 0
    @State private var rotationTask: Task<Void, Never>?
    @State private var iCloudFetchTask: Task<Void, Never>?
    @State private var cards: [HeroCard] = []
    @State private var detectedSummary: ICloudAccountSummary?
    @State private var fetchCompleted: Bool = false
    /// Continuations parqueadas mientras `fetchCompleted == false`. Se reanudan
    /// todas en `markFetchCompleted()` — reemplaza el polling busy-loop.
    @State private var fetchWaiters: [CheckedContinuation<Void, Never>] = []
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

    /// Cacheado en `@State`: 14 lookups `ls(...)` × cada body recompute (animation
    /// 60fps) sería derroche. Se popula una vez en `.task`.
    private static func makeCards() -> [HeroCard] {
        [
            HeroCard(icon: "camera.fill", title: L10n.Welcome.Hero.captureTitle, body: L10n.Welcome.Hero.captureBody, accentColor: .electricIndigo),
            HeroCard(icon: "mic.fill", title: L10n.Welcome.Hero.voiceTitle, body: L10n.Welcome.Hero.voiceBody, accentColor: .neonCyan),
            HeroCard(icon: "arrow.down.doc.fill", title: L10n.Welcome.Hero.importTitle, body: L10n.Welcome.Hero.importBody, accentColor: .priorityNeed),
            HeroCard(icon: "creditcard.fill", title: L10n.Welcome.Hero.multiAccountTitle, body: L10n.Welcome.Hero.multiAccountBody, accentColor: .hotPink),
            HeroCard(icon: "globe", title: L10n.Welcome.Hero.currenciesTitle, body: L10n.Welcome.Hero.currenciesBody, accentColor: .essentialNeed),
            HeroCard(icon: "icloud.fill", title: L10n.Welcome.Hero.icloudTitle, body: L10n.Welcome.Hero.icloudBody, accentColor: .electricIndigo),
            HeroCard(icon: "sparkles", title: L10n.Welcome.Hero.moreTitle, body: L10n.Welcome.Hero.moreBody, accentColor: .neonCyan),
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
            if cards.isEmpty {
                cards = Self.makeCards()
            }
            startICloudFetch()
            startCardRotation()
        }
        .onDisappear {
            rotationTask?.cancel()
            iCloudFetchTask?.cancel()
            // Drenar continuations parqueadas — evita leak si el view se cierra mid-tap.
            for waiter in fetchWaiters { waiter.resume() }
            fetchWaiters = []
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
            if !cards.isEmpty {
                ForEach(0..<3, id: \.self) { offset in
                    let cardIdx = (currentCardIndex + offset) % cards.count
                    let card = cards[cardIdx]
                    heroCardView(card)
                        .scaleEffect(Self.cardScales[offset])
                        .rotationEffect(.degrees(Self.cardRotations[offset]))
                        .offset(Self.cardOffsets[offset])
                        .opacity(Self.cardOpacities[offset])
                        .zIndex(Double(2 - offset))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(offset == 0 ? "\(card.title). \(card.body)" : "")
                        .accessibilityHidden(offset != 0)
                }
            }
        }
    }

    /// Stack visual: front (offset 0, full) → middle (offset 1, leve rotation) → back
    /// (offset 2, más pequeño y rotado al lado opuesto). Coreografiado para sentirse
    /// "fanned" sin overlap visual pesado.
    private static let cardScales: [CGFloat] = [1.0, 0.92, 0.85]
    private static let cardRotations: [Double] = [0, 5, -7]
    private static let cardOffsets: [CGSize] = [.zero, CGSize(width: 12, height: 8), CGSize(width: -14, height: 16)]
    private static let cardOpacities: [Double] = [1.0, 0.6, 0.32]

    private func heroCardView(_ card: HeroCard) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: card.icon)
                // A11Y-DT: tamaño hero del icono dentro del card animado (no escala con DT).
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
        // A11Y-DT: card width fijo 280pt + idealHeight permite escalado vertical
        // hasta 420pt antes de limitar; minimumScaleFactor(0.85) en title/body
        // absorbe el resto del Dynamic Type XXL.
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

    // MARK: Empezar handler (single-shot, signal-based — sin polling)

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

            // Slow path: esperar señal real (`markFetchCompleted`) con timeout.
            // Sin polling busy-loop. Si timeout primero → asume noData.
            await MainActor.run { isCheckingFetch = true }
            await waitForFetchOrTimeout()
            await MainActor.run {
                isCheckingFetch = false
                dispatchDecision()
            }
        }
    }

    /// Suspende hasta que `markFetchCompleted()` resuma la continuation o el timeout
    /// expire. Reemplaza el polling con sleeps de 500ms — la señal real es el flag
    /// `fetchCompleted` que `startICloudFetch` setea cuando termina.
    private func waitForFetchOrTimeout() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task { @MainActor in
                if fetchCompleted {
                    continuation.resume()
                    return
                }
                fetchWaiters.append(continuation)
                Task {
                    try? await Task.sleep(for: Self.postTapWaitTimeout)
                    await MainActor.run { resolvePendingWaiters() }
                }
            }
        }
    }

    @MainActor
    private func markFetchCompleted() {
        fetchCompleted = true
        resolvePendingWaiters()
    }

    @MainActor
    private func resolvePendingWaiters() {
        guard !fetchWaiters.isEmpty else { return }
        let pending = fetchWaiters
        fetchWaiters = []
        for waiter in pending { waiter.resume() }
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
                await MainActor.run { markFetchCompleted() }
                return
            }
            _ = await iCloudSyncService.shared.forceFetchAndWait(timeout: Self.iCloudFetchTimeout)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                detectedSummary = try? modelContext.iCloudAccountSummary(appPreferences: appPreferences)
                markFetchCompleted()
            }
        }
    }

    private func startCardRotation() {
        rotationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.cardRotationInterval)
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
