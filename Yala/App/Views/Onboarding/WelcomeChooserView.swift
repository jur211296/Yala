//
//  WelcomeChooserView.swift
//  Yala
//
//  Welcome Chooser pre-onboarding. Full-screen presentado UNA SOLA VEZ al primer
//  launch fresh, ANTES del OnboardingView, cuando NO hay data en iCloud y NO hay
//  invite via universal link. 3 ramas: nuevo / restore desde iCloud / paste invite.
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onSelect: (Branch) -> Void
    var onBack: (() -> Void)? = nil

    private func iconTint(for branch: Branch) -> Color {
        switch branch {
        case .new: .hotPink
        case .restore: .neonCyan
        case .invite: .priorityNeed
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: DS.Gradients.heroIndigoBlack,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    Spacer(minLength: DS.Spacing.xxl)

                    Image("YalaLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 64)
                        .colorMultiply(.white)
                        .accessibilityHidden(true)

                    VStack(spacing: DS.Spacing.sm) {
                        Text(L10n.Welcome.Chooser.title)
                            .font(DS.Typography.title2)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text(L10n.Welcome.Chooser.subtitle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
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
        .welcomeBackButton(tint: .white, action: onBack)
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
                        .fill(iconTint.opacity(0.25))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(iconTint)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    Text(bodyText)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DS.Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(DS.Typography.chevron)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(bodyText)")
    }
}
