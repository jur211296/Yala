//
//  WhatsNewSheet.swift
//  Yala
//
//  Pantalla estilo Apple que muestra novedades post-actualización.
//

import SwiftUI

// MARK: - Model

struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
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
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                // Header
                VStack(spacing: DS.Spacing.sm) {
                    Text(L10n.WhatsNew.title)
                        .font(DS.Typography.largeTitle)
                        .foregroundStyle(.thPrimaryText)
                        .multilineTextAlignment(.center)

                    Text(L10n.WhatsNew.subtitle(version))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                }
                .padding(.top, DS.Spacing.xxl)
                .padding(.horizontal, DS.Spacing.xl)
                .opacity(headerOpacity)

                // Features list
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                        featureRow(feature: feature, index: index)
                    }
                }
                .padding(.vertical, DS.Spacing.sm)
                .glassEffect(.regular)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
                .padding(.horizontal, DS.Spacing.lg)

                Spacer(minLength: DS.Spacing.xxl)

                // CTA button
                YalaPrimaryButton(L10n.WhatsNew.continueButton) {
                    onDismiss()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
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
        return HStack(spacing: DS.Spacing.sm) {
            Image(systemName: feature.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(feature.iconColor))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(feature.title)
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.thPrimaryText)

                Text(feature.description)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
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
