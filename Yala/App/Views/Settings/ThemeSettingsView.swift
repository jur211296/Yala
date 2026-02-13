//
//  ThemeSettingsView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

struct ThemeSettingsView: View {
    @AppStorage("userTheme") private var userThemeRaw: Int = AppTheme.system.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: DS.Spacing.xxl) {
                // Header / Intro
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: DS.Spacing.xxxxl))
                        .foregroundStyle(Color.brandPrimary)
                        .padding(.bottom, DS.Spacing.sm)

                    Text(L10n.Profile.appearance)
                        .font(DS.Typography.title2)
                        .foregroundStyle(Color.yalaPrimaryText)

                    Text(L10n.Settings.themeDescription)
                        .font(DS.Typography.body)
                        .foregroundStyle(Color.yalaSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DS.Spacing.xxxl)

                // Selection
                VStack(spacing: DS.Spacing.lg) {
                    ForEach(AppTheme.allCases) { theme in
                        themeRow(for: theme)
                    }
                }
                .padding(DS.Spacing.lg)
                .background(Color.yalaCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.primary.opacity(DS.Card.borderOpacity), lineWidth: 1)
                )

                Spacer()
            }
            .padding(DS.Spacing.lg)
        }
        .navigationTitle(L10n.Settings.theme)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: "Atrás") {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func themeRow(for theme: AppTheme) -> some View {
        Button {
            userThemeRaw = theme.rawValue
        } label: {
            HStack {
                Text(theme.label)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(Color.yalaPrimaryText)

                Spacer()

                if userThemeRaw == theme.rawValue {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandPrimary)
                        .font(DS.Typography.title)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(Color.yalaSecondaryText.opacity(0.3))
                        .font(DS.Typography.title)
                }
            }
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if theme != AppTheme.allCases.last {
            Divider()
        }
    }
}
