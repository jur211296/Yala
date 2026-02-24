//
//  ThemeSettingsView.swift
//  Yala
//
//  Theme selection with 6 themes: 3 free + 3 PRO.
//  Grid layout with preview cards following AppIconSettingsView pattern.
//

import SwiftUI

struct ThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    private let featureGate = FeatureGateService.shared

    /// Called after theme changes to dismiss the entire profile sheet
    var onThemeChanged: (() -> Void)?

    @State private var showUpgradeSheet = false

    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 48

    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.lg),
        GridItem(.flexible(), spacing: DS.Spacing.lg),
    ]

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: heroIconSize))
                            .foregroundStyle(.thAccent)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .padding(.bottom, DS.Spacing.sm)

                        Text(L10n.Profile.appearance)
                            .font(DS.Typography.title2.bold())
                            .foregroundStyle(.thPrimaryText)

                        Text(L10n.Settings.themeDescription)
                            .font(DS.Typography.body)
                            .foregroundStyle(.thSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xxxl)

                    // Theme Grid
                    LazyVGrid(columns: columns, spacing: DS.Spacing.lg) {
                        ForEach(AppTheme.allCases) { appTheme in
                            themeCard(for: appTheme)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
        }
        .navigationTitle(L10n.Settings.theme)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradePromptSheet(feature: .proThemes, context: .proFeature)
        }
    }

    // MARK: - Theme Card

    @ViewBuilder
    private func themeCard(for appTheme: AppTheme) -> some View {
        let isSelected = themeManager.userChoice == appTheme
        let isLocked = appTheme.isPro && !featureGate.isProUser

        Button {
            if isLocked {
                showUpgradeSheet = true
            } else {
                themeManager.userChoice = appTheme
                // Dismiss theme view + parent profile sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                    onThemeChanged?()
                }
            }
        } label: {
            VStack(spacing: DS.Spacing.md) {
                // Preview area
                ZStack(alignment: .topTrailing) {
                    themePreview(for: appTheme)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(
                                    isSelected ? Color.brandPrimary : Color.clear,
                                    lineWidth: 3
                                )
                        )
                        .opacity(isLocked ? 0.5 : 1.0)

                    // Lock badge
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(.white)
                            .padding(DS.Chip.paddingV)
                            .background(Circle().fill(Color.gray))
                            .offset(x: 4, y: -4)
                    }
                }

                // Label row
                HStack(spacing: DS.Spacing.xs) {
                    Text(appTheme.label)
                        .font(DS.Typography.label)
                        .foregroundStyle(isLocked ? .thSecondaryText : .thPrimaryText)

                    if appTheme.isPro && !isSelected {
                        ProBadge(size: .small)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.thAccent)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
            .padding(.horizontal, DS.Spacing.sm)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(
                        isSelected ? Color.brandPrimary.opacity(0.3) : Color.primary.opacity(0.05),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Theme Preview

    @ViewBuilder
    private func themePreview(for appTheme: AppTheme) -> some View {
        if appTheme == .system {
            // Split preview: left light, right dark
            GeometryReader { geo in
                HStack(spacing: 0) {
                    themeMockup(palette: .light)
                        .frame(width: geo.size.width / 2)
                        .clipped()

                    themeMockup(palette: .dark)
                        .frame(width: geo.size.width / 2)
                        .clipped()
                }
            }
        } else {
            themeMockup(palette: appTheme.yalaTheme)
        }
    }

    // MARK: - Mock Card

    private func themeMockup(palette: YalaTheme) -> some View {
        ZStack {
            // Background
            Rectangle().fill(palette.background)

            // Inner card mock
            VStack(spacing: DS.Spacing.sm) {
                // Colored dots row
                HStack(spacing: DS.Spacing.sm) {
                    Circle().fill(palette.accent).frame(width: 8, height: 8)
                    Circle().fill(palette.income).frame(width: 8, height: 8)
                    Circle().fill(palette.expense).frame(width: 8, height: 8)
                    Spacer()
                }

                // Simulated text lines
                Capsule()
                    .fill(palette.primaryText.opacity(0.6))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)

                Capsule()
                    .fill(palette.secondaryText.opacity(0.4))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, DS.Spacing.xxl)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(palette.card)
            )
            .padding(DS.Spacing.md)
        }
    }
}
