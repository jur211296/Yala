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
                // UX 2.2 · L16-8: la hoja no decía dónde se ve lo que enciende. El camino se arma con los títulos
                // reales de la pestaña y del chip, así que no nombra una pantalla que no existe en ese idioma.
                Section {
                    Text(L10n.UXL14D.summaryWhere("\(L10n.Tab.statistics) › \(L10n.Insights.title)"))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: DS.Spacing.sm, bottom: 0, trailing: DS.Spacing.sm))
                        .accessibilityIdentifier("ai_summary_where")
                }

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
                    // De todo lo que enciende esta hoja, solo las Observaciones las escribe la IA: la marca va solo aquí.
                    YalaSettingsToggleRow(L10n.Insights.intelligentInsights, isOn: $prefs.insightsShowTexts) {
                        aiMark
                    }
                    .accessibilityIdentifier("ai_summary_row_observations")
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

    /// La marca de IA de la app (destellos + «IA», la de Flujo de caja), en gris: informa, no se toca.
    private var aiMark: some View {
        HStack(spacing: DS.Chip.spacing) {
            Image(systemName: "sparkles")
                .font(DS.Typography.labelTiny)
            Text(L10n.CashFlowPlan.aiChipLabel)
                .font(DS.Typography.labelSmall.weight(.semibold))
        }
        .foregroundStyle(.thSecondaryText)
        .padding(.horizontal, DS.Chip.paddingV)
        .padding(.vertical, DS.Spacing.xxs)
        .background(Capsule().fill(.thSecondaryText.opacity(0.12)))
        .accessibilityElement(children: .combine)
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
