//
//  WelcomeNewChooserView.swift
//  Yala
//
//  Sub-chooser de "Soy nuevo" (2º nivel del Welcome, A4 de D-A7 · §k.2): dónde
//  viven los datos personales — privacidad total (iCloud) o cuenta en la nube de
//  Yala. Calco estructural de `WelcomeExistingChooserView`; lo que añade es la
//  JERARQUÍA que pide §k.6: la opción privacy-first va arriba y destacada con
//  "Recomendado", y la de nube dice la renuncia sin eufemismos, inline y visible.
//
//  Solo se monta con MÁS de una opción visible: con una sola (producción con el
//  percent remoto en 0, backend no configurado, o uitest sin el opt-in) el
//  container hace bypass directo (`WelcomeAccountChoiceLogic.bypass`) y este
//  screen ni se construye — el recorrido "Soy nuevo" queda byte-idéntico al de hoy.
//

import SwiftUI

struct WelcomeNewChooserView: View {

    let options: [WelcomeAccountChoiceLogic.NewOption]
    var onSelect: (WelcomeAccountChoiceLogic.NewOption) -> Void
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
                    Text(L10n.Welcome.Chooser.optionNewTitle)
                        .font(DS.Typography.title2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(L10n.Welcome.New.subtitle)
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

    private func title(for option: WelcomeAccountChoiceLogic.NewOption) -> String {
        switch option {
        case .privateAccount: L10n.Welcome.New.privateTitle
        case .cloudAccount: L10n.Welcome.New.cloudTitle
        }
    }

    private func body(for option: WelcomeAccountChoiceLogic.NewOption) -> String {
        switch option {
        case .privateAccount: L10n.Welcome.New.privateBody
        case .cloudAccount: L10n.Welcome.New.cloudBody
        }
    }

    private func iconName(for option: WelcomeAccountChoiceLogic.NewOption) -> String {
        switch option {
        case .privateAccount: "lock.shield.fill"
        case .cloudAccount: "icloud.fill"
        }
    }

    private func iconTint(for option: WelcomeAccountChoiceLogic.NewOption) -> Color {
        switch option {
        case .privateAccount: .neonCyan
        case .cloudAccount: .hotPink
        }
    }

    private func accessibilityIdentifier(for option: WelcomeAccountChoiceLogic.NewOption) -> String {
        switch option {
        case .privateAccount: "welcome_new_private"
        case .cloudAccount: "welcome_new_cloud"
        }
    }

    /// Etiqueta de accesibilidad completa: el badge y el aviso son parte del mensaje, no adorno —
    /// leerlos importa especialmente en la card de nube, que es donde vive la renuncia.
    private func accessibilityLabel(for option: WelcomeAccountChoiceLogic.NewOption) -> String {
        switch option {
        case .privateAccount:
            "\(title(for: option)). \(L10n.Welcome.New.recommendedBadge). \(body(for: option))"
        case .cloudAccount:
            "\(title(for: option)). \(body(for: option)). \(L10n.Welcome.New.cloudWarning)"
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

    /// "Recomendado" (§k.6: la privacy-first es la opción primaria y se ve).
    private var recommendedBadge: some View {
        Text(L10n.Welcome.New.recommendedBadge)
            .font(DS.Typography.labelTiny)
            .foregroundStyle(Color.neonCyan)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(
                Capsule().fill(Color.neonCyan.opacity(0.18))
            )
    }

    /// La renuncia, dicha inline y sin eufemismos (§k.6). No es un disclaimer escondido: va DENTRO
    /// de la card que la provoca.
    private var cloudWarning: some View {
        HStack(alignment: .top, spacing: DS.Spacing.xxs) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(DS.Typography.captionSmall)
            Text(L10n.Welcome.New.cloudWarning)
                .font(DS.Typography.captionSmall)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white.opacity(0.85))
    }

    /// Mismo shape visual que `WelcomeExistingChooserView.optionCard` (réplica consciente: no se
    /// refactoriza el hermano para no tocar un flujo vivo por un calco).
    private func optionCard(_ option: WelcomeAccountChoiceLogic.NewOption) -> some View {
        Button {
            DS.Haptic.selection()
            onSelect(option)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                systemIconCircle(name: iconName(for: option), tint: iconTint(for: option))

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    // El badge va ENCIMA y no al lado: medido en sim, junto a un título de dos
                    // líneas lo parte, y con las traducciones largas (de/pl) sería peor.
                    if option == .privateAccount {
                        recommendedBadge
                    }

                    Text(title(for: option))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    Text(body(for: option))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if option == .cloudAccount {
                        cloudWarning
                            .padding(.top, DS.Spacing.xxs)
                    }
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
        .accessibilityLabel(accessibilityLabel(for: option))
        .accessibilityIdentifier(accessibilityIdentifier(for: option))
    }
}
