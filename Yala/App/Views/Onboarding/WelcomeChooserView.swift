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
//  Forma de la referencia del 15-sep (`WelcomeForm.swift`): titular serif sin logo y las tres ramas
//  como filas de UNA tarjeta. Sin pesos de botón: son tres caminos, ninguno se recomienda.
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

    var onSelect: (Branch) -> Void
    var onBack: (() -> Void)? = nil

    private func iconTint(for branch: Branch) -> Color {
        switch branch {
        case .new: .hotPink
        case .restore: .neonCyan
        case .invite: .essentialNeed
        }
    }

    var body: some View {
        WelcomeFormScreen(
            title: L10n.Welcome.Chooser.title,
            subtitle: L10n.Welcome.Chooser.subtitle
        ) {
            VStack(spacing: 0) {
                ForEach(Branch.allCases, id: \.self) { branch in
                    if branch != Branch.allCases.first {
                        WelcomeOptionDivider()
                    }
                    chooserCard(
                        icon: branch.icon,
                        iconTint: iconTint(for: branch),
                        title: branch.title,
                        body: branch.body,
                        action: { handleSelect(branch) }
                    )
                    // Identifier aditivo de navegación XCUI (sesión 2 Google).
                    .accessibilityIdentifier("welcome_chooser_\(branch.rawValue)")
                }
            }
            .welcomeFlowCard(radius: DS.Radius.xl)
        }
        .welcomeBackButton(tint: .white, action: onBack)
    }

    private func handleSelect(_ branch: Branch) {
        DS.Haptic.selection()
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
                        .frame(width: WelcomeOptionRowMetrics.iconSize, height: WelcomeOptionRowMetrics.iconSize)
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
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(bodyText)")
    }
}
