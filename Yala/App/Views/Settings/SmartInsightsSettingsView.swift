//
//  SmartInsightsSettingsView.swift
//  Yala
//
//  Settings sheet for Smart Insights: AI toggle, section visibility toggles.
//

import SwiftUI

struct SmartInsightsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    // MARK: - AI

    @AppStorage("aiDataConsentAccepted") private var aiDataConsentAccepted = false

    // MARK: - Section Visibility

    @AppStorage("insightsShowQuickStats") private var showQuickStats = true
    @AppStorage("insightsShowCommitments") private var showCommitments = true
    @AppStorage("insightsShowPendingPayments") private var showPendingPayments = true
    @AppStorage("insightsShowSubscriptions") private var showSubscriptions = true
    @AppStorage("insightsShowBudgetsAtRisk") private var showBudgetsAtRisk = true
    @AppStorage("insightsShowWeekday") private var showWeekday = true
    @AppStorage("insightsShowNature") private var showNature = true
    @AppStorage("insightsShowTexts") private var showTexts = true

    private var isProUser: Bool {
        FeatureGateService.shared.canAccess(.smartInsightsAI)
    }

    @State private var showUpgrade = false

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        // AI Section
                        SectionBox(title: L10n.Insights.aiSectionTitle) {
                            VStack(spacing: DS.Spacing.none) {
                                HStack {
                                    Text(L10n.Insights.aiToggle)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if isProUser {
                                        Toggle("", isOn: $aiDataConsentAccepted)
                                            .labelsHidden()
                                    } else {
                                        Button {
                                            showUpgrade = true
                                        } label: {
                                            HStack(spacing: DS.Spacing.xs) {
                                                Image(systemName: "lock.fill")
                                                    .font(DS.Typography.captionSmall)
                                                ProBadge(size: .small)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.vertical, DS.FormRow.paddingV)
                            }
                        }

                        Text(L10n.Insights.aiCaption)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.top, -DS.Spacing.lg)

                        // Metrics Section
                        SectionBox(title: L10n.Insights.metricsSection) {
                            VStack(spacing: DS.Spacing.none) {
                                settingsToggle(L10n.Insights.quickStats, isOn: $showQuickStats)
                            }
                        }

                        // Commitments Section
                        SectionBox(title: L10n.Insights.commitments) {
                            VStack(spacing: DS.Spacing.none) {
                                settingsToggle(L10n.Insights.pendingPayments, isOn: $showPendingPayments)
                                SubsectionDivider()
                                settingsToggle(L10n.Insights.activeSubscriptions, isOn: $showSubscriptions)
                                SubsectionDivider()
                                settingsToggle(L10n.Insights.budgetsAtRisk, isOn: $showBudgetsAtRisk)
                            }
                        }

                        // Charts Section
                        SectionBox(title: L10n.Insights.chartsSection) {
                            VStack(spacing: DS.Spacing.none) {
                                settingsToggle(L10n.Insights.weekdayAverage, isOn: $showWeekday)
                            }
                        }

                        // Analysis Section
                        SectionBox(title: L10n.Insights.analysisSection) {
                            VStack(spacing: DS.Spacing.none) {
                                settingsToggle(L10n.Insights.natureDistribution, isOn: $showNature)
                                SubsectionDivider()
                                settingsToggle(L10n.Insights.intelligentInsights, isOn: $showTexts)
                            }
                        }

                        // Restore Defaults
                        Button {
                            restoreDefaults()
                        } label: {
                            Text(L10n.Insights.restoreDefaults)
                                .font(DS.Typography.body)
                                .foregroundStyle(theme.accent)
                        }
                        .padding(.top, DS.Spacing.md)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
            }
            .navigationTitle(L10n.Insights.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.done) { dismiss() }
                }
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradePromptSheet(feature: .smartInsightsAI, context: .proFeature)
            }
        }
    }

    // MARK: - Toggle Row

    private func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    // MARK: - Restore Defaults

    private func restoreDefaults() {
        showQuickStats = true
        showCommitments = true
        showPendingPayments = true
        showSubscriptions = true
        showBudgetsAtRisk = true
        showWeekday = true
        showNature = true
        showTexts = true
    }
}
