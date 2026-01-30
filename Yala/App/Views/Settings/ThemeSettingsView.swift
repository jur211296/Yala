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
                        .font(.system(size: 48))
                        .foregroundStyle(Color.brandPrimary)
                        .padding(.bottom, DS.Spacing.sm)

                    Text(L10n.Profile.appearance)
                        .font(.title2.bold())
                        .foregroundStyle(Color.yalaPrimaryText)

                    Text(L10n.Settings.themeDescription)
                        .font(.body)
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
                .padding()
                .background(Color.yalaCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )

                Spacer()
            }
            .padding()
        }
        .navigationTitle(L10n.Settings.theme)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func themeRow(for theme: AppTheme) -> some View {
        Button {
            userThemeRaw = theme.rawValue
            // Don't dismiss - ProfileView will handle navigation cleanup on theme change
        } label: {
            HStack {
                Text(theme.label)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.yalaPrimaryText)

                Spacer()

                if userThemeRaw == theme.rawValue {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandPrimary)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(Color.yalaSecondaryText.opacity(0.3))
                        .font(.title3)
                }
            }
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if theme != AppTheme.allCases.last {
            Divider()
                .padding(.leading, 0)
        }
    }
}
