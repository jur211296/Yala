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
            YalaSettingsList {
                YalaSettingsSection(L10n.Insights.metricsSection) {
                    YalaSettingsToggleRow(L10n.Insights.quickStats, isOn: $prefs.insightsShowQuickStats)
                }

                YalaSettingsSection(L10n.Insights.commitments) {
                    YalaSettingsToggleRow(L10n.Insights.pendingPayments, isOn: $prefs.insightsShowPendingPayments)
                    YalaSettingsToggleRow(L10n.Insights.activeSubscriptions, isOn: $prefs.insightsShowSubscriptions)
                    YalaSettingsToggleRow(L10n.Insights.budgetsAtRisk, isOn: $prefs.insightsShowBudgetsAtRisk)
                }

                YalaSettingsSection(L10n.Insights.chartsSection) {
                    YalaSettingsToggleRow(L10n.Insights.weekdayAverage, isOn: $prefs.insightsShowWeekday)
                }

                YalaSettingsSection(L10n.Insights.analysisSection) {
                    YalaSettingsToggleRow(L10n.Insights.needDistribution, isOn: $prefs.insightsShowNature)
                    YalaSettingsToggleRow(L10n.Insights.intelligentInsights, isOn: $prefs.insightsShowTexts)
                }

                // Restore Defaults: suelto bajo los bloques, sin fondo, como antes.
                Section {
                    Button {
                        restoreDefaults()
                    } label: {
                        Text(L10n.Insights.restoreDefaults)
                            .font(DS.Typography.body)
                            .foregroundStyle(theme.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
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
