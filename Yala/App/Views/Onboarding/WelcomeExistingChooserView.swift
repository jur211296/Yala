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

    /// Las opciones en el orden en que se pintan. El orden lo decide el faro (`WelcomeNewBranchRouter.existingOrder`):
    /// esta vista no reordena nada.
    let options: [WelcomeAccountChoiceLogic.ExistingOption]
    /// **La entrada con la que se creó la cuenta de este Apple ID, según el faro** (ticket vb1f, opción A). Va primera
    /// —eso ya viene en `options`— y lleva debajo «La que usaste en este iPhone». `nil` = sin nota.
    var usedOnThisDevice: WelcomeAccountChoiceLogic.ExistingOption? = nil
    var onSelect: (WelcomeAccountChoiceLogic.ExistingOption) -> Void
    var onBack: () -> Void
    /// La pregunta de pie: «¿Es tu primera vez en Yala?». Va a la misma rama que la card «Es mi primera
    /// vez» del Chooser —faro incluido—, no directa a una opción: quien la toca dijo que es nuevo, no
    /// dónde quiere guardar sus datos.
    var onStartNew: () -> Void

    /// Las entradas a una cuenta de Yala, en el orden que llega (Apple, Google; o Google, Apple si el faro dice Google).
    private var accountOptions: [WelcomeAccountChoiceLogic.ExistingOption] {
        options.filter { $0 != .restoreICloud }
    }

    private var offersRestore: Bool { options.contains(.restoreICloud) }

    /// Los dos caminos a la vez: la cuenta de Yala en la nube y el iCloud. Es cuando hay que elegir, y por tanto cuando
    /// la ayuda de L6-1 tiene sentido.
    private var offersBothPaths: Bool { offersRestore && !accountOptions.isEmpty }

    /// UX 2.2 · L6-1 (opción B): quien usó Yala hace meses no recuerda si guardó sus datos en su iCloud o en una cuenta
    /// de la nube. Una frase lo resuelve sin cambiar el flujo: el modo de siempre de Yala es el iCloud, y la nube exige
    /// haber entrado con Apple o Google. Fuera de la tarjeta, entre el título y lo que se elige, con un icono que la
    /// marca como ayuda y no como una opción más.
    private var dontRememberHelp: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "questionmark.circle.fill")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .accessibilityHidden(true)
            Text(L10n.UXLote6.existingDontRemember)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("welcome_existing_dont_remember")
    }

    var body: some View {
        WelcomeFormScreen(
            title: L10n.Welcome.Existing.title,
            subtitle: L10n.Welcome.Existing.subtitle
        ) {
            if offersBothPaths {
                dontRememberHelp
            }

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if !accountOptions.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        WelcomeFormLabel(L10n.Welcome.Existing.cloudBody)
                        ForEach(accountOptions, id: \.self) { option in
                            accountEntry(option)
                        }
                        // UX 2.2 · L6-3: la nota del método vivía en la pantalla intermedia «Entra a tu cuenta», que ya no
                        // se enseña (estos botones abren directamente el consentimiento). Es aquí donde se elige el método.
                        Text(L10n.Welcome.Cloud.providerNote)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("welcome_existing_provider_note")
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

    /// Un botón de entrada a una cuenta y, si es el del faro, su nota debajo. Los dos botones conservan el mismo peso
    /// (guideline 4.8): lo que distingue al del faro es el sitio y la nota, no el estilo.
    @ViewBuilder
    private func accountEntry(_ option: WelcomeAccountChoiceLogic.ExistingOption) -> some View {
        if option == usedOnThisDevice {
            VStack(spacing: DS.Spacing.xs) {
                optionButton(option, weight: .filled)
                Text(L10n.Welcome.Existing.usedOnThisDeviceNote)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("welcome_existing_used_on_this_device")
            }
        } else {
            optionButton(option, weight: .filled)
        }
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
