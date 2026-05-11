//
//  ProfileSectionsCarouselDemo.swift
//  Yala
//
//  Demo del Step 1 (`exploreSettings`): carrusel auto-rotando de 5 mini-cards
//  representando las secciones principales de ProfileView. A diferencia de Steps
//  2-6 (que renderizan el View real existente + overlay DemoBanner), Step 1 es
//  un demo standalone con chrome propio (X topLeft + título principal + CTA).
//

import SwiftUI

struct ProfileSectionsCarouselDemo: View {
    let onOpenSettings: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentIndex: Int = 0
    @State private var rotationTask: Task<Void, Never>?

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

                Button(action: { onOpenSettings(); dismiss() }) {
                    Text(L10n.SetupChecklist.Demo.settingsCta)
                        .font(DS.Typography.label.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xl)
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
            .task { populateItems(); startRotation() }
            .onDisappear { rotationTask?.cancel(); rotationTask = nil }
        }
    }

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
        guard !voiceOverEnabled else { return } // a11y: estado estable
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
}
