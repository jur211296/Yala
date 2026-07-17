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
        case .googleSignIn: L10n.Welcome.Existing.googleTitle
        }
    }

    private func body(for option: WelcomeAccountChoiceLogic.ExistingOption) -> String {
        switch option {
        case .restoreICloud: L10n.Welcome.Existing.restoreBody
        case .cloudSignIn: L10n.Welcome.Existing.cloudBody
        case .googleSignIn: L10n.Welcome.Existing.googleBody
        }
    }

    /// Icono por opción. Las de sistema van en círculo tintado 0.25 (como el chooser nivel 1);
    /// la de Google es el logo "G" multicolor sobre círculo BLANCO sólido (brand guideline:
    /// el logo exige fondo claro de contraste y JAMÁS se recolorea/template).
    @ViewBuilder
    private func iconView(for option: WelcomeAccountChoiceLogic.ExistingOption) -> some View {
        switch option {
        case .restoreICloud:
            systemIconCircle(name: "icloud.and.arrow.down", tint: .neonCyan)
        case .cloudSignIn:
            systemIconCircle(name: "apple.logo", tint: .white)
        case .googleSignIn:
            ZStack {
                Circle()
                    .fill(.white)  // A11Y-DM: fondo de contraste OBLIGATORIO del logo G (brand guideline de Google, no adapta al tema)
                    .frame(width: 48, height: 48)
                Image("GoogleG")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            }
        }
    }

    private func systemIconCircle(name: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.25))
                .frame(width: 48, height: 48)
            Image(systemName: name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    private func accessibilityIdentifier(for option: WelcomeAccountChoiceLogic.ExistingOption) -> String {
        switch option {
        case .restoreICloud: "welcome_existing_restore"
        case .cloudSignIn: "welcome_existing_cloud"
        case .googleSignIn: "welcome_existing_google"
        }
    }

    /// Mismo shape visual que `WelcomeChooserView.chooserCard` (builder privado allá;
    /// réplica consciente para no refactorizar el chooser existente).
    private func optionCard(_ option: WelcomeAccountChoiceLogic.ExistingOption) -> some View {
        Button {
            DS.Haptic.selection()
            onSelect(option)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                iconView(for: option)

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
            .welcomeFlowCard(radius: DS.Radius.xl)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title(for: option)). \(body(for: option))")
        .accessibilityIdentifier(accessibilityIdentifier(for: option))
    }
}
