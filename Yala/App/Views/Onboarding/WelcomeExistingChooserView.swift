//
//  WelcomeExistingChooserView.swift
//  Yala
//
//  Sub-chooser de "Ya tengo una cuenta" (2º nivel del Welcome, decisión owner
//  2026-07-12): Restaurar desde iCloud (flujo restore existente) o entrar con
//  Apple a una cuenta del Modo Nube. Solo se muestra cuando hay MÁS de una
//  opción visible (backend configurado y fuera de UITest) — con una sola, el
//  container hace bypass directo (WelcomeAccountChoiceLogic.bypass) y este
//  screen ni se monta, preservando el flujo actual de producción.
//

import SwiftUI

struct WelcomeExistingChooserView: View {

    let options: [WelcomeAccountChoiceLogic.ExistingOption]
    var onSelect: (WelcomeAccountChoiceLogic.ExistingOption) -> Void
    var onBack: () -> Void

    var body: some View {
        WelcomeFlowScreen { logoTopSpacing in
            VStack(spacing: 0) {
                Spacer(minLength: logoTopSpacing)

                Image("YalaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 128)
                    .colorMultiply(.white)
                    .accessibilityHidden(true)

                Spacer(minLength: DS.Spacing.lg)

                VStack(spacing: DS.Spacing.sm) {
                    Text(L10n.Welcome.Chooser.optionExistingTitle)
                        .font(DS.Typography.title2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(L10n.Welcome.Existing.subtitle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.lg)
                }

                Spacer(minLength: DS.Spacing.lg)

                VStack(spacing: DS.Spacing.md) {
                    ForEach(options, id: \.self) { option in
                        optionCard(option)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)

                Spacer(minLength: DS.Spacing.xl)
            }
        }
        .welcomeBackButton(tint: .white, action: onBack)
    }

    private func title(for option: WelcomeAccountChoiceLogic.ExistingOption) -> String {
        switch option {
        case .restoreICloud: L10n.Welcome.Existing.restoreTitle
        case .cloudSignIn: L10n.Welcome.Existing.cloudTitle
        }
    }

    private func body(for option: WelcomeAccountChoiceLogic.ExistingOption) -> String {
        switch option {
        case .restoreICloud: L10n.Welcome.Existing.restoreBody
        case .cloudSignIn: L10n.Welcome.Existing.cloudBody
        }
    }

    private func icon(for option: WelcomeAccountChoiceLogic.ExistingOption) -> (name: String, tint: Color) {
        switch option {
        case .restoreICloud: ("icloud.and.arrow.down", .neonCyan)
        case .cloudSignIn: ("apple.logo", .white)
        }
    }

    /// Mismo shape visual que `WelcomeChooserView.chooserCard` (builder privado allá;
    /// réplica consciente para no refactorizar el chooser existente).
    private func optionCard(_ option: WelcomeAccountChoiceLogic.ExistingOption) -> some View {
        let iconSpec = icon(for: option)
        return Button {
            DS.Haptic.selection()
            onSelect(option)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(iconSpec.tint.opacity(0.25))
                        .frame(width: 48, height: 48)
                    Image(systemName: iconSpec.name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(iconSpec.tint)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title(for: option))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    Text(body(for: option))
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
            .solidCard(padding: 0, radius: DS.Radius.xl)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title(for: option)). \(body(for: option))")
        .accessibilityIdentifier(option == .restoreICloud
            ? "welcome_existing_restore" : "welcome_existing_cloud")
    }
}
