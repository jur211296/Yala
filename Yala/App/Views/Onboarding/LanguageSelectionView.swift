//
//  LanguageSelectionView.swift
//  Yala
//
//  Pre-onboarding screen shown when the device language is not one of the supported locales.
//  The user picks their preferred language, which is set as an in-app override before onboarding begins.
//
//  La lista va en un `ScrollView` y el botón en `safeAreaInset`, NO en un `VStack` con `Spacer`s: con los
//  14 idiomas seleccionables la columna mide más que la pantalla de un iPhone 17 Pro, y el `VStack` empujaba
//  el título bajo la barra de estado y el botón «Siguiente» fuera de la pantalla — sin él no había forma
//  de salir de aquí (medido en el simulador el 2026-10-13, iPhone en coreano).
//

import SwiftUI

struct LanguageSelectionView: View {
    @Environment(\.yalaTheme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 56 // A11Y-DT: @ScaledMetric

    @State private var selectedLanguage: String = LanguageManager.closestSupportedLanguage
    var onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.none) {
                // Header
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "globe")
                        .font(.system(size: heroSize))
                        .foregroundStyle(Color.electricIndigo)
                        .accessibilityHidden(true)

                    Text(L10n.Onboarding.languageTitle)
                        .font(DS.Typography.title)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(L10n.Onboarding.languageSubtitle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.Spacing.xl)
                }
                .padding(.top, DS.Spacing.xxl)
                .padding(.bottom, DS.Spacing.xl)

                // Language list
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(LanguageManager.supportedLanguages) { lang in
                        languageRow(code: lang.code, name: lang.nativeName, flag: lang.flag)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.lg)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            // Continue button — fijo abajo, visible con cualquier número de idiomas y tamaño de letra.
            YalaPrimaryButton(L10n.Action.next) {
                LanguageManager.overrideLanguage = selectedLanguage
                onComplete()
            }
            .accessibilityIdentifier("language_selection_next")
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.lg)
        }
        .yalaScreenBackground(.panel)
    }

    private func languageRow(code: String, name: String, flag: String) -> some View {
        let isSelected = selectedLanguage == code

        return Button {
            selectedLanguage = code
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text(flag)
                    .font(DS.Typography.title)

                Text(name)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title)
                    .foregroundStyle(isSelected ? Color.electricIndigo : .secondary)
            }
            .padding(DS.Spacing.md)
            .background(isSelected ? Color.electricIndigo.opacity(0.1) : theme.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isSelected ? Color.electricIndigo.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LanguageSelectionView {}
}
