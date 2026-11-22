//
//  RecurringProposalsSettingsView.swift
//  Yala
//
//  «Pagos que se repiten» (lote S1): apagar las propuestas y arrepentirse de lo descartado. La definición la pone en
//  Ajustes; mientras esa fila no existe se abre desde la tarjeta y desde el pie de Pagos planificados (Paso 0, D4).
//

import SwiftUI

struct RecurringProposalsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isEnabled = RecurringProposalPreferences.shared.isEnabled

    private var preferences: RecurringProposalPreferences { .shared }

    var body: some View {
        NavigationStack {
            YalaSettingsList {
                YalaSettingsSection {
                    YalaSettingsToggleRow(
                        PagosRecurrentesText.settingsToggle,
                        isOn: $isEnabled
                    )
                    .accessibilityIdentifier("recurring_settings_toggle")
                    .onChange(of: isEnabled) { _, enabled in preferences.setEnabled(enabled) }
                } footer: {
                    Text(PagosRecurrentesText.settingsFooter)
                }

                if !preferences.dismissed.isEmpty {
                    YalaSettingsSection(PagosRecurrentesText.settingsDismissed) {
                        ForEach(preferences.dismissed) { entry in
                            dismissedRow(entry)
                        }
                    }
                }
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(PagosRecurrentesText.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    YalaToolbarTextButton(PagosRecurrentesText.settingsDone) { dismiss() }
                        .accessibilityIdentifier("recurring_settings_done")
                }
            }
        }
    }

    private func dismissedRow(_ entry: RecurringProposalPreferences.DismissedEntry) -> some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(entry.name)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                Text(PagosRecurrentesText.settingsDismissedOn(ScheduledPaymentDateText.dayMonth(entry.dismissedAt)))
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }
            Spacer(minLength: DS.Spacing.sm)
            Button(PagosRecurrentesText.settingsRestore) {
                preferences.restore(entry)
            }
            .buttonStyle(.borderless)
            .font(DS.Typography.label)
            .accessibilityIdentifier("recurring_settings_restore_\(entry.key)")
        }
    }
}

/// El enlace al pie de Pagos planificados: solo sale con la función apagada o con algo descartado, que es cuando hay
/// algo que gestionar sin tarjeta a la vista.
struct RecurringProposalsFooterLink: View {
    @State private var showsSettings = false

    private var preferences: RecurringProposalPreferences { .shared }

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            if preferences.hasSomethingToManage {
                Button {
                    showsSettings = true
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: PaymentCategory.recurring.iconName)
                            .accessibilityHidden(true)
                        Text(PagosRecurrentesText.footerLink)
                        if !preferences.isEnabled {
                            Text(verbatim: "·").accessibilityHidden(true)
                            Text(PagosRecurrentesText.footerOff)
                        }
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.captionSmall)
                            .accessibilityHidden(true)
                    }
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("recurring_proposals_footer_link")
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
            }
        }
        .sheet(isPresented: $showsSettings) {
            RecurringProposalsSettingsView()
        }
    }
}
