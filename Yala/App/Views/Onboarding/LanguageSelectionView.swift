//
//  LanguageSelectionView.swift
//  Yala
//
//  Pre-onboarding screen shown when the device language is not one of the 6 supported locales.
//  The user picks their preferred language, which is set as an in-app override before onboarding begins.
//

import SwiftUI

struct LanguageSelectionView: View {
    @Environment(\.yalaTheme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 56 // A11Y-DT: @ScaledMetric

    @State private var selectedLanguage: String = LanguageManager.closestSupportedLanguage
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            Spacer()

            // Header
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "globe")
                    .font(.system(size: heroSize))
                    .foregroundStyle(Color.electricIndigo)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                Text(L10n.Onboarding.languageTitle)
                    .font(DS.Typography.title)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.languageSubtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.bottom, DS.Spacing.xxl)

            // Language list
            VStack(spacing: DS.Spacing.sm) {
                ForEach(LanguageManager.supportedLanguages, id: \.code) { lang in
                    languageRow(code: lang.code, name: lang.nativeName, flag: lang.flag)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)

            Spacer()
            Spacer()

            // Continue button
            Button {
                LanguageManager.overrideLanguage = selectedLanguage
                onComplete()
            } label: {
                Text(L10n.Action.next)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(Color.electricIndigo)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxxl)
        }
        .background(.thBackground)
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
    LanguageSelectionView {
        print("Language selected!")
    }
}
