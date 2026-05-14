//
//  ProfileSectionsCarouselDemo.swift
//  Yala
//
//  Demo del Step 1 (`exploreSettings`): carrusel auto-rotando de 5 mini-cards
//  representando las secciones principales de ProfileView. Chrome alineado con
//  resto de Steps standalone: progress bar indigo + CTA "Abrir Ajustes" enabled
//  tras 5s. Divergencias documentadas vs Steps 2-6: SIN botón Reiniciar (carrusel
//  rota cíclicamente), SIN toast (CTA es la acción real, no completion).
//

import SwiftUI

struct ProfileSectionsCarouselDemo: View {
    let onOpenSettings: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentIndex: Int = 0
    @State private var rotationTask: Task<Void, Never>?
    @State private var progressTask: Task<Void, Never>?
    @State private var elapsedSeconds: Double = 0

    private var progress: Double { min(1.0, elapsedSeconds / 5.0) }
    private var demoCompleted: Bool { progress >= 1.0 }
    private var demoAccent: Color { Color.electricIndigo }

    private struct PreviewItem: Identifiable {
        let id: Int
        let iconName: String
        let title: String
        let caption: String
    }

    @State private var items: [PreviewItem] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                Spacer()

                ZStack {
                    ForEach(items) { item in
                        if item.id == currentIndex {
                            ProfileSectionPreviewCard(
                                iconName: item.iconName,
                                title: item.title,
                                caption: item.caption
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        }
                    }
                }
                .animation(reduceMotion ? .easeInOut(duration: 0.25) : .smooth(duration: 0.45, extraBounce: 0.1), value: currentIndex)

                // Page indicator capsules
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(items) { item in
                        Capsule()
                            .fill(item.id == currentIndex ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: item.id == currentIndex ? 18 : 6, height: 3)
                            .animation(.smooth(duration: 0.3), value: currentIndex)
                            .onTapGesture {
                                currentIndex = item.id
                                restartRotationIfNeeded()
                            }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PanelBackgroundView())
            .navigationTitle(L10n.SetupChecklist.Demo.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
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
            .task {
                populateItems()
                startRotation()
                startProgressTimer()
            }
            .onDisappear {
                rotationTask?.cancel(); rotationTask = nil
                progressTask?.cancel(); progressTask = nil
            }
        }
    }

    // MARK: - Progress bar + CTA (chrome standalone alineado con Steps 2-6)

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
                onOpenSettings()
                dismiss()
            } label: {
                Text(L10n.SetupChecklist.Demo.settingsCta)
                    .font(DS.Typography.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(demoCompleted ? demoAccent : DS.Semantic.disabledForeground.opacity(0.4))
            .controlSize(.large)
            .disabled(!demoCompleted)
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

    // MARK: - Data + rotation

    private func populateItems() {
        items = [
            PreviewItem(id: 0, iconName: "creditcard.fill",
                        title: L10n.SetupChecklist.Demo.settingsCard1Title,
                        caption: L10n.SetupChecklist.Demo.settingsCard1Caption),
            PreviewItem(id: 1, iconName: "paintbrush.fill",
                        title: L10n.SetupChecklist.Demo.settingsCard2Title,
                        caption: L10n.SetupChecklist.Demo.settingsCard2Caption),
            PreviewItem(id: 2, iconName: "bell.fill",
                        title: L10n.SetupChecklist.Demo.settingsCard3Title,
                        caption: L10n.SetupChecklist.Demo.settingsCard3Caption),
            PreviewItem(id: 3, iconName: "lock.shield.fill",
                        title: L10n.SetupChecklist.Demo.settingsCard4Title,
                        caption: L10n.SetupChecklist.Demo.settingsCard4Caption),
            PreviewItem(id: 4, iconName: "sparkles",
                        title: L10n.SetupChecklist.Demo.settingsCard5Title,
                        caption: L10n.SetupChecklist.Demo.settingsCard5Caption),
        ]
    }

    private func startRotation() {
        guard !voiceOverEnabled else { return }
        rotationTask?.cancel()
        rotationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1500))
                guard !Task.isCancelled, !items.isEmpty else { return }
                currentIndex = (currentIndex + 1) % items.count
            }
        }
    }

    private func restartRotationIfNeeded() {
        rotationTask?.cancel()
        startRotation()
    }

    /// Progress timer INDEPENDIENTE del carrusel (decisión plan: 5s arbitrarios
    /// para habilitar CTA sin esperar la primera vuelta completa de 7.5s).
    private func startProgressTimer() {
        if voiceOverEnabled {
            elapsedSeconds = 5.0
            return
        }
        progressTask?.cancel()
        progressTask = Task { @MainActor in
            let start = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                withAnimation(reduceMotion ? nil : .linear(duration: 0.1)) {
                    elapsedSeconds = min(elapsed, 5.0)
                }
                if elapsed >= 5.0 { return }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
