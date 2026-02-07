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

    @State private var showPaywall = false

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
                .padding(DS.Spacing.lg)
                .background(Color.yalaCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
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
                YalaToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionView()
        }
    }

    @ViewBuilder
    private func themeRow(for theme: AppTheme) -> some View {
        Button {
            if theme.isProOnly && !FeatureGateService.shared.isProUser {
                showPaywall = true
            } else {
                userThemeRaw = theme.rawValue
            }
        } label: {
            HStack {
                Text(theme.label)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.yalaPrimaryText)

                if theme.isProOnly {
                    Text("PRO")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(Color.electricIndigo)
                        .clipShape(Capsule())
                }

                Spacer()

                if theme.isProOnly && !FeatureGateService.shared.isProUser {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Color.yalaSecondaryText.opacity(0.5))
                        .font(.body)
                } else if userThemeRaw == theme.rawValue {
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
