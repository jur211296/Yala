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
//  **Es el «¡Hola de nuevo!» de la referencia del 15-sep** (`WelcomeForm.swift`): titular serif, una
//  tarjeta con los dos caminos y la pregunta de pie. Dentro de la tarjeta, Apple y Google LLENOS y con la
//  misma forma —prominencia equivalente, guideline 4.8— y, tras el «o», Restaurar desde iCloud con
//  CONTORNO: es la entrada sin cuenta de Yala, que es lo que la referencia hace con «Explorar sin cuenta».
//  Cada bloque lleva encima su etiqueta, que son las líneas que antes iban dentro de cada card.
//
//  Los botones de Apple y Google de aquí NO firman nada: eligen la opción y abren la entrada a la nube,
//  que es la que pinta los botones de marca de verdad. Por eso son `WelcomeFormButton` y no
//  `AppleSignInButton`/`GoogleSignInButton`, que además cuentan sus construcciones en
//  `WelcomeSignInVerbTests`.
//

import SwiftUI

struct WelcomeExistingChooserView: View {

    let options: [WelcomeAccountChoiceLogic.ExistingOption]
    var onSelect: (WelcomeAccountChoiceLogic.ExistingOption) -> Void
    var onBack: () -> Void
    /// La pregunta de pie: «¿Es tu primera vez en Yala?». Va a la misma rama que la card «Es mi primera
    /// vez» del Chooser —faro incluido—, no directa a una opción: quien la toca dijo que es nuevo, no
    /// dónde quiere guardar sus datos.
    var onStartNew: () -> Void

    /// Las entradas a una cuenta de Yala, en el orden de la lógica (Apple, Google).
    private var accountOptions: [WelcomeAccountChoiceLogic.ExistingOption] {
        options.filter { $0 != .restoreICloud }
    }

    private var offersRestore: Bool { options.contains(.restoreICloud) }

    var body: some View {
        WelcomeFormScreen(
            title: L10n.Welcome.Existing.title,
            subtitle: L10n.Welcome.Existing.subtitle
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if !accountOptions.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        WelcomeFormLabel(L10n.Welcome.Existing.cloudBody)
                        ForEach(accountOptions, id: \.self) { option in
                            optionButton(option, weight: .filled)
                        }
                    }
                }

                if !accountOptions.isEmpty && offersRestore {
                    WelcomeFormSeparator()
                }

                if offersRestore {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        WelcomeFormLabel(L10n.Welcome.Existing.restoreBody)
                        optionButton(.restoreICloud, weight: .outline)
                    }
                }
            }
            .welcomeFormCard()

            footer
        }
        .welcomeBackButton(tint: .white, action: onBack)
    }

    /// Fuera de la tarjeta solo queda esto (rasgo 2 de la referencia). `ViewThatFits` y no un `HStack`
    /// a secas: con Dynamic Type grande la pregunta y la acción no caben en una línea y se apilan.
    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DS.Spacing.xs) {
                footerQuestion
                footerAction
            }
            VStack(spacing: DS.Spacing.xs) {
                footerQuestion
                footerAction
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var footerQuestion: some View {
        Text(L10n.Welcome.Existing.firstTimeQuestion)
            .font(DS.Typography.subheadline)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
    }

    private var footerAction: some View {
        Button {
            DS.Haptic.selection()
            onStartNew()
        } label: {
            Text(L10n.Welcome.Existing.firstTimeAction)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.white)
                .underline()
                .frame(minHeight: DS.Button.actionSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("welcome_existing_start_new")
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

    /// El logo de Google va como imagen de catálogo y sin recolorear (brand guideline): el fondo blanco
    /// del botón lleno es el fondo de contraste que el logo exige.
    private func icon(for option: WelcomeAccountChoiceLogic.ExistingOption) -> WelcomeFormButton.Icon {
        switch option {
        case .restoreICloud: .system("icloud.and.arrow.down")
        case .cloudSignIn: .system("apple.logo")
        case .googleSignIn: .asset("GoogleG")
        }
    }

    private func accessibilityIdentifier(for option: WelcomeAccountChoiceLogic.ExistingOption) -> String {
        switch option {
        case .restoreICloud: "welcome_existing_restore"
        case .cloudSignIn: "welcome_existing_cloud"
        case .googleSignIn: "welcome_existing_google"
        }
    }

    /// La línea de cada opción ya está a la vista como etiqueta del bloque; a VoiceOver se le da como
    /// pista del botón, que es donde la oye quien navega de botón en botón. La de Google es la suya
    /// («si la creaste con tu cuenta de Google»), no la del bloque.
    private func optionButton(
        _ option: WelcomeAccountChoiceLogic.ExistingOption,
        weight: WelcomeFormButton.Weight
    ) -> some View {
        WelcomeFormButton(title: title(for: option), icon: icon(for: option), weight: weight) {
            onSelect(option)
        }
        .accessibilityHint(body(for: option))
        .accessibilityIdentifier(accessibilityIdentifier(for: option))
    }
}
