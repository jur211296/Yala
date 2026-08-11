//
//  WelcomeNewChooserView.swift
//  Yala
//
//  Sub-chooser de "Soy nuevo" (2º nivel del Welcome, A4 de D-A7 · §k.2): dónde
//  viven los datos personales — privacidad total (iCloud) o cuenta en la nube de
//  Yala. Calco estructural de `WelcomeExistingChooserView`; lo que añade es que la
//  card de nube dice la renuncia sin eufemismos, inline y visible.
//
//  NINGUNA de las dos opciones se recomienda — decisión de producto del owner
//  (2026-08-10), que SUPERSEDE el §k.6 de arquitectura en esta pantalla: aquel pedía
//  destacar la privacy-first con un badge "Recomendado" y ese badge ya no existe, ni en
//  la vista ni en la etiqueta de accesibilidad. La elección es netamente del usuario.
//  Lo que §k.6 sigue gobernando aquí y NO cambia: el ORDEN de las cards (la privada va
//  primero) y la renuncia dicha dentro de la card que la provoca.
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

    /// Etiqueta de accesibilidad completa: el aviso de la card de nube es parte del mensaje, no
    /// adorno — es donde vive la renuncia y VoiceOver tiene que leerla.
    ///
    /// La card privada NO lleva ningún distintivo: mientras existió el badge "Recomendado" esta
    /// etiqueta lo incluía, y retirarlo de la vista dejándolo aquí le habría dicho a VoiceOver que
    /// Yala recomienda una opción que en pantalla ya no recomienda.
    private func accessibilityLabel(for option: WelcomeAccountChoiceLogic.NewOption) -> String {
        switch option {
        case .privateAccount:
            "\(title(for: option)). \(body(for: option))"
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
