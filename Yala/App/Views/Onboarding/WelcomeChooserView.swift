//
//  WelcomeChooserView.swift
//  Yala
//
//  A4 — Welcome Chooser pre-onboarding (épico Groups Pulido Final).
//
//  Pantalla full-screen presentada UNA SOLA VEZ al primer launch fresh, ANTES del
//  OnboardingView, cuando NO hay data en iCloud y NO hay invite via universal link.
//  3 ramas: nuevo / restore desde iCloud / paste invite link.
//
//  El flag `hasShownWelcomeChooser` se setea SOLO tras tap consciente en una de
//  las 3 cards (no en dismissals programáticos por race con CKShare).
//

import SwiftUI

struct WelcomeChooserView: View {

    enum Branch: String, CaseIterable {
        case new
        case restore
        case invite

        var icon: String {
            switch self {
            case .new: "sparkles"
            case .restore: "icloud.and.arrow.down"
            case .invite: "person.2.badge.plus"
            }
        }

        var title: String {
            switch self {
            case .new: L10n.Welcome.Chooser.optionNewTitle
            case .restore: L10n.Welcome.Chooser.optionExistingTitle
            case .invite: L10n.Welcome.Chooser.optionInviteTitle
            }
        }

        var body: String {
            switch self {
            case .new: L10n.Welcome.Chooser.optionNewBody
            case .restore: L10n.Welcome.Chooser.optionExistingBody
            case .invite: L10n.Welcome.Chooser.optionInviteBody
            }
        }
    }

    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onSelect: (Branch) -> Void

    private func iconTint(for branch: Branch) -> Color {
        switch branch {
        case .new: theme.accent
        case .restore: .blue
        case .invite: .green
        }
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    Spacer(minLength: DS.Spacing.xxl)

                    Image("YalaLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 64)
                        .accessibilityHidden(true)

                    VStack(spacing: DS.Spacing.sm) {
                        Text(L10n.Welcome.Chooser.title)
                            .font(DS.Typography.title2)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Text(L10n.Welcome.Chooser.subtitle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.lg)
                    }

                    VStack(spacing: DS.Spacing.md) {
                        ForEach(Branch.allCases, id: \.self) { branch in
                            chooserCard(
                                icon: branch.icon,
                                iconTint: iconTint(for: branch),
                                title: branch.title,
                                body: branch.body,
                                action: { handleSelect(branch) }
                            )
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)

                    Spacer(minLength: DS.Spacing.xxl)
                }
            }
        }
    }

    private func handleSelect(_ branch: Branch) {
        DS.Haptic.selection()
        TelemetryService.track(.welcomeChooserBranchSelected, parameters: [
            "branch": branch.rawValue
        ])
        onSelect(branch)
    }

    private func chooserCard(
        icon: String,
        iconTint: Color,
        title: String,
        body bodyText: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(iconTint.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(iconTint)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Text(bodyText)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DS.Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(DS.Typography.chevron)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.thCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .dsSubtleShadow()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(bodyText)")
    }
}
