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
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        @Bindable var prefs = appPreferences
        return NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                        // Metrics Section
                        SectionBox(title: L10n.Insights.metricsSection) {
                            VStack(spacing: DS.Spacing.none) {
                                settingsToggle(L10n.Insights.quickStats, isOn: $prefs.insightsShowQuickStats)
                            }
                        }

                        // Commitments Section
                        SectionBox(title: L10n.Insights.commitments) {
                            VStack(spacing: DS.Spacing.none) {
                                settingsToggle(L10n.Insights.pendingPayments, isOn: $prefs.insightsShowPendingPayments)
                                SubsectionDivider()
                                settingsToggle(L10n.Insights.activeSubscriptions, isOn: $prefs.insightsShowSubscriptions)
                                SubsectionDivider()
                                settingsToggle(L10n.Insights.budgetsAtRisk, isOn: $prefs.insightsShowBudgetsAtRisk)
                            }
                        }

                        // Charts Section
                        SectionBox(title: L10n.Insights.chartsSection) {
                            VStack(spacing: DS.Spacing.none) {
                                settingsToggle(L10n.Insights.weekdayAverage, isOn: $prefs.insightsShowWeekday)
                            }
                        }

                        // Analysis Section
                        SectionBox(title: L10n.Insights.analysisSection) {
                            VStack(spacing: DS.Spacing.none) {
                                settingsToggle(L10n.Insights.needDistribution, isOn: $prefs.insightsShowNature)
                                SubsectionDivider()
                                settingsToggle(L10n.Insights.intelligentInsights, isOn: $prefs.insightsShowTexts)
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
            .navigationTitle(L10n.Settings.customizeAISummary)
            .navigationBarTitleDisplayMode(.inline)
            .yalaScreenBackground(.subtle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.done) { dismiss() }
                }
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
        appPreferences.insightsShowQuickStats = true
        appPreferences.insightsShowPendingPayments = true
        appPreferences.insightsShowSubscriptions = true
        appPreferences.insightsShowBudgetsAtRisk = true
        appPreferences.insightsShowWeekday = true
        appPreferences.insightsShowNature = true
        appPreferences.insightsShowTexts = true
    }
}
