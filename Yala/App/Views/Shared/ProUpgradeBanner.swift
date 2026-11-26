//
//  ProUpgradeBanner.swift
//  Yala
//
//  Periodic banner reminding Free users about Pro features.
//

import SwiftUI

struct ProUpgradeBanner: View {

    // MARK: - Environment

    @Environment(\.yalaTheme) private var theme

    // MARK: - Properties

    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    /// Con derecho al mes gratis (elegibilidad medida, prueba de un mes), el texto de la maqueta A (Jürgen, 25-nov-2026):
    /// «1 MES GRATIS», «Prueba Yala Pro gratis 1 mes» y «Empezar mes gratis». Sin derecho, el de siempre.
    private var offersFreeMonth: Bool { SetupCompleteTrialOfferLogic.announcesFreeMonthNow }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                YalaSpark(size: .medium, animated: false)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    if offersFreeMonth {
                        Text(L10n.PrimerosPasos23.ProBannerFreeMonth.chip)
                            .font(DS.Typography.badgeLabel)
                            .tracking(0.6) // A11Y-DT: espaciado del rótulo en mayúsculas de la maqueta; no cambia el tamaño
                            .foregroundStyle(.thOnAccent)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(Capsule().fill(theme.accent))
                            .accessibilityIdentifier("pro_banner_free_month_chip")
                    }

                    Text(offersFreeMonth ? L10n.PrimerosPasos23.ProBannerFreeMonth.title : L10n.ProBanner.title)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("pro_banner_title")

                    Text(offersFreeMonth ? L10n.PrimerosPasos23.ProBannerFreeMonth.subtitle : L10n.ProBanner.subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                        .padding(DS.Spacing.xs)
                }
                .accessibilityLabel(L10n.Action.close)
            }

            Button {
                onUpgrade()
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    YalaSpark(size: .small, animated: false)
                    // «Probar Pro gratis» o «Pasarme a Pro»: «Actualizar» sonaba a la App Store (UX 2.2 · L17-4).
                    Text(offersFreeMonth ? L10n.PrimerosPasos23.ProBannerFreeMonth.cta : ProPresentation.upgradeButtonTitle)
                        .font(DS.Typography.labelSmall)
                }
                .foregroundStyle(.thOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .background(theme.accent)
                .clipShape(Capsule())
            }
            .accessibilityIdentifier("pro_banner_cta")
        }
        .padding(DS.Spacing.md)
        .background(DS.Semantic.infoBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

// MARK: - L10n Extension

extension L10n {
    enum ProBanner {
        static var title: String {
            NSLocalizedString("proBanner.title", comment: "Pro upgrade banner title")
        }
        static var subtitle: String {
            NSLocalizedString("proBanner.subtitle", comment: "Pro upgrade banner subtitle")
        }
    }
}

// MARK: - Preview

#Preview {
    ProUpgradeBanner(onUpgrade: {}, onDismiss: {})
        .padding()
}
