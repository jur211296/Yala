//
//  WelcomeHeroView.swift
//  Yala
//
//  Pantalla de presentación entre splash y Welcome Chooser.
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

    /// Intervalo entre rotaciones de cards. Spring animation 0.55s ya cubre el movimiento.
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

    /// Cacheado en `@State`: 16 lookups `ls(...)` × cada body recompute (animation
    /// 60fps) sería derroche. Se popula una vez en `.task`.
    private static func makeCards() -> [HeroCard] {
        [
            HeroCard(icon: "camera.fill", title: L10n.Welcome.Hero.captureTitle, body: L10n.Welcome.Hero.captureBody, accentColor: .electricIndigo),
            HeroCard(icon: "bubble.left.and.bubble.right.fill", title: L10n.Welcome.Hero.assistantTitle, body: L10n.Welcome.Hero.assistantBody, accentColor: .hotPink),
            HeroCard(icon: "person.2.fill", title: L10n.Welcome.Hero.groupsTitle, body: L10n.Welcome.Hero.groupsBody, accentColor: .priorityNeed),
            HeroCard(icon: "target", title: L10n.Welcome.Hero.budgetsTitle, body: L10n.Welcome.Hero.budgetsBody, accentColor: .essentialNeed),
            HeroCard(icon: "creditcard.fill", title: L10n.Welcome.Hero.multiAndCurrenciesTitle, body: L10n.Welcome.Hero.multiAndCurrenciesBody, accentColor: .priorityNeedNew),
            HeroCard(icon: "arrow.down.doc.fill", title: L10n.Welcome.Hero.importTitle, body: L10n.Welcome.Hero.importBody, accentColor: .electricIndigo),
            HeroCard(icon: "icloud.fill", title: L10n.Welcome.Hero.icloudTitle, body: L10n.Welcome.Hero.icloudBody, accentColor: .hotPink),
            HeroCard(icon: "sparkles", title: L10n.Welcome.Hero.moreTitle, body: L10n.Welcome.Hero.moreBody, accentColor: .essentialNeed),
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
                    .colorMultiply(.white)
                    .padding(.top, DS.Spacing.lg)
                    .accessibilityHidden(true)

                Spacer(minLength: DS.Spacing.lg)

                cardStack
                    .frame(height: 260)

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
        LinearGradient(
            colors: DS.Gradients.heroIndigoBlack,
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: Card stack

    /// Front card con `.id(currentCardIndex)` + transition asymmetric horizontal.
    /// Back/middle se animan implícitamente dentro del `withAnimation(spring)` del
    /// incremento de índice porque cambian sus offset/scale/rotation derivados.
    private var cardStack: some View {
        ZStack {
            if !cards.isEmpty {
                // Back y middle: decorativos, sin transition propia — interpolan con spring.
                ForEach([2, 1], id: \.self) { offset in
                    let cardIdx = (currentCardIndex + offset) % cards.count
                    let card = cards[cardIdx]
                    heroCardView(card)
                        .scaleEffect(Self.cardScales[offset])
                        .rotationEffect(.degrees(Self.cardRotations[offset]))
                        .offset(Self.cardOffsets[offset])
                        .opacity(Self.cardOpacities[offset])
                        .zIndex(Double(2 - offset))
                        .accessibilityHidden(true)
                }

                // Front card: con `.id` para forzar re-creación + transition horizontal.
                let frontCard = cards[currentCardIndex]
                heroCardView(frontCard)
                    .id(currentCardIndex)
                    .scaleEffect(Self.cardScales[0])
                    .zIndex(2)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(frontCard.title). \(frontCard.body)")
            }
        }
        .clipped()
    }

    /// Front (offset 0, full) → middle (offset 1, leve rotation) → back
    /// (offset 2, más pequeño y rotado al lado opuesto).
    private static let cardScales: [CGFloat] = [1.0, 0.88, 0.78]
    private static let cardRotations: [Double] = [0, 7, -9]
    private static let cardOffsets: [CGSize] = [.zero, CGSize(width: 32, height: 12), CGSize(width: -32, height: 18)]
    private static let cardOpacities: [Double] = [1.0, 0.55, 0.28]

    private func heroCardView(_ card: HeroCard) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: card.icon)
                // A11Y-DT: tamaño hero del icono dentro del card animado (no escala con DT).
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))

            Text(card.title)
                .font(DS.Typography.title2)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .lineLimit(2)

            Text(card.body)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .lineLimit(2)
                .padding(.horizontal, DS.Spacing.sm)
        }
        .padding(DS.Spacing.lg)
        // A11Y-DT: card width 280pt + idealHeight 200 / maxHeight 240 absorbe DT XXL
        // con minimumScaleFactor(0.85) en title/body.
        .frame(width: 280)
        .frame(idealHeight: 200, maxHeight: 240)
        .background(
            ZStack {
                // Sólido base + difuminado claro/oscuro suave para textura.
                card.accentColor
                LinearGradient(
                    colors: [.white.opacity(0.12), .clear, .black.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .shadow(color: card.accentColor.opacity(0.3), radius: 18, x: 0, y: 10)
    }

    // MARK: Title + subtitle

    /// Texto sobre fondo dark: `.white` para title base + gradient
    /// `.hotPink → .white` para titleAccent (contraste >4.5:1 sobre indigo).
    private var titleAndSubtitle: some View {
        VStack(spacing: DS.Spacing.sm) {
            VStack(spacing: 0) {
                Text(L10n.Welcome.Hero.title)
                    .foregroundStyle(.white)
                Text(L10n.Welcome.Hero.titleAccent)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.hotPink, .white],
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
                .foregroundStyle(.white.opacity(0.7))
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
                .foregroundStyle(.white.opacity(0.55))
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
                        : .spring(response: 0.55, dampingFraction: 0.78)
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
