//
//  LanguageSelectionView.swift
//  Yala
//
//  Pre-onboarding screen shown when the device language is not one of the 6 supported locales.
//  The user picks their preferred language, which is set as an in-app override before onboarding begins.
//

import SwiftUI

struct LanguageSelectionView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 56

    @State private var selectedLanguage: String = "en"
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "globe")
                    .font(.system(size: heroSize))
                    .foregroundStyle(Color.electricIndigo)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                Text(L10n.Onboarding.languageTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.languageSubtitle)
                    .font(.subheadline)
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
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(Color.electricIndigo)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxxl)
        }
        .background(Color.yalaBackground)
    }

    private func languageRow(code: String, name: String, flag: String) -> some View {
        let isSelected = selectedLanguage == code

        return Button {
            selectedLanguage = code
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text(flag)
                    .font(.title2)

                Text(name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.electricIndigo : .secondary)
            }
            .padding(DS.Spacing.md)
            .background(isSelected ? Color.electricIndigo.opacity(0.1) : Color.yalaCard)
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
