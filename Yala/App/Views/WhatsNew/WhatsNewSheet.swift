//
//  WhatsNewSheet.swift
//  Yala
//
//  Pantalla estilo Apple que muestra novedades post-actualización.
//

import SwiftUI

// MARK: - Model

struct WhatsNewFeature: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    // Identity for `.presentWhatsNew` intent dedup uses stable fields, not the UUID.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.icon == rhs.icon && lhs.title == rhs.title && lhs.description == rhs.description
    }
}

// MARK: - WhatsNewSheet

struct WhatsNewSheet: View {
    let features: [WhatsNewFeature]
    let version: String
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme

    @State private var animatedRows: Set<Int> = []
    @State private var headerOpacity: Double = 0

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    // Header — generous top padding (Apple Pages style)
                    VStack(spacing: DS.Spacing.sm) {
                        Text(L10n.WhatsNew.title)
                            .font(DS.Typography.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.thPrimaryText)
                            .multilineTextAlignment(.center)

                        Text(L10n.WhatsNew.subtitle(version))
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.thSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 72)
                    .padding(.horizontal, DS.Spacing.xl)
                    .opacity(headerOpacity)

                    // Features — individual rows, no card wrapper
                    VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                        ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                            featureRow(feature: feature, index: index)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            // CTA button — OUTSIDE ScrollView, always visible at bottom
            YalaPrimaryButton(L10n.WhatsNew.continueButton) {
                onDismiss()
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
            .padding(.top, DS.Spacing.md)
        }
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.large])
        .interactiveDismissDisabled()
        .onAppear {
            if reduceMotion {
                headerOpacity = 1.0
                animatedRows = Set(features.indices)
            } else {
                dsWithAnimation(reduceMotion) {
                    headerOpacity = 1.0
                }
                Task {
                    try? await Task.sleep(for: .seconds(0.2))
                    for i in features.indices {
                        if i > 0 {
                            try? await Task.sleep(for: .seconds(0.1))
                        }
                        dsWithAnimation(reduceMotion) {
                            animatedRows.insert(i)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Feature Row

    private func featureRow(feature: WhatsNewFeature, index: Int) -> some View {
        let isVisible = animatedRows.contains(index)
        return HStack(alignment: .top, spacing: DS.Spacing.lg) {
            Image(systemName: feature.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(feature.iconColor))

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(feature.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)

                Text(feature.description)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
            }

            Spacer()
        }
        .opacity(reduceMotion ? 1.0 : (isVisible ? 1.0 : 0.0))
        .offset(y: reduceMotion ? 0 : (isVisible ? 0 : 10))
    }
}

// MARK: - Preview

#Preview {
    WhatsNewSheet(
        features: [
            WhatsNewFeature(icon: "hand.point.up.left.fill", iconColor: .blue,
                            title: "Guías paso a paso",
                            description: "Ahora te mostramos cómo usar cada sección."),
            WhatsNewFeature(icon: "bell.badge.fill", iconColor: .orange,
                            title: "Notificaciones",
                            description: "Activa recordatorios y reportes."),
        ],
        version: "1.2",
        onDismiss: {}
    )
}
