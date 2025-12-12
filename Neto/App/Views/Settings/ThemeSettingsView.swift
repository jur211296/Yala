//
//  ThemeSettingsView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

struct ThemeSettingsView: View {
    @AppStorage("userTheme") private var userThemeRaw: Int = AppTheme.system.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: DesignSystem.Spacing.xxLarge) {
                // Header / Intro
                VStack(spacing: 8) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.brandPrimary)
                        .padding(.bottom, 8)

                    Text("Apariencia")
                        .font(.title2.bold())
                        .foregroundStyle(Color.netoPrimaryText)

                    Text("Elige cómo quieres que se vea Neto.")
                        .font(.body)
                        .foregroundStyle(Color.netoSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                // Selection
                VStack(spacing: 16) {
                    ForEach(AppTheme.allCases) { theme in
                        themeRow(for: theme)
                    }
                }
                .padding()
                .background(Color.netoCard)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.large))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.large)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Temas")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SheetTopButton(systemName: "chevron.left") {
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
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.netoPrimaryText)

                Spacer()

                if userThemeRaw == theme.rawValue {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandPrimary)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(Color.netoSecondaryText.opacity(0.3))
                        .font(.title3)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if theme != AppTheme.allCases.last {
            Divider()
                .padding(.leading, 0)
        }
    }
}
