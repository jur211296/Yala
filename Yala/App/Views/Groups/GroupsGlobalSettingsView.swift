//
//  GroupsGlobalSettingsView.swift
//  Yala
//
//  Sheet "Ajustes de Grupos" accesible desde el gear del toolbar del tab Grupos.
//  Centraliza el toggle del bridge opt-out + los 3 toggles de visibilidad existing
//  (movidos desde `PersonalizationSettingsView`).
//
//  Patrón sheet iOS 26: NavigationStack + .navigationTitle .inline + toolbar X
//  topBarLeading + .presentationDetents([.large]) + .presentationDragIndicator.
//

import SwiftUI
import SwiftData

struct GroupsGlobalSettingsView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    // MARK: - State

    /// Anti-loop guard: cuando bridge toggle dispara `BridgeDeactivationSheet`, capturar
    /// pre-state para revertir sin re-disparar `onChange` si user cancela el sheet.
    @State private var showDeactivationSheet: Bool = false
    @State private var pendingBridgeValue: Bool?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xxl) {

                    // MARK: - Integración con tu Yala personal
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        YalaSectionHeader(L10n.Groups.GlobalSettings.bridgeSectionTitle)

                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Toggle(isOn: bridgeBinding) {
                                Text(L10n.Groups.GlobalSettings.bridgeToggleLabel)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.thPrimaryText)
                            }
                            .accessibilityIdentifier("groups_bridge_toggle")
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.Spacing.sm)
                            .solidCard(padding: 0, radius: DS.Radius.lg)

                            Text(L10n.Groups.GlobalSettings.bridgeCaption)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }
                    }

                    // MARK: - Visibilidad
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        YalaSectionHeader(L10n.Groups.GlobalSettings.visibilitySectionTitle)

                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            @Bindable var prefs = appPreferences
                            Toggle(isOn: $prefs.includeGroupsInPanelTotal) {
                                Text(L10n.Settings.includeGroupsInPanelTotal)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.thPrimaryText)
                            }
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.Spacing.sm)
                            .solidCard(padding: 0, radius: DS.Radius.lg)

                            Toggle(isOn: $prefs.includeGroupTransactionsInStats) {
                                Text(L10n.Settings.includeGroupTransactionsInStats)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.thPrimaryText)
                            }
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.Spacing.sm)
                            .solidCard(padding: 0, radius: DS.Radius.lg)

                            Toggle(isOn: $prefs.includeGroupTransactionsInFeed) {
                                Text(L10n.Groups.GlobalSettings.includeGroupTransactionsInFeedLabel)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.thPrimaryText)
                            }
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.Spacing.sm)
                            .solidCard(padding: 0, radius: DS.Radius.lg)

                            Text(L10n.Groups.GlobalSettings.visibilityCaption)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Groups.GlobalSettings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDeactivationSheet) {
                BridgeDeactivationSheet(
                    scope: .global,
                    onConfirm: confirmDeactivation,
                    onCancel: cancelDeactivation
                )
            }
            .sheet(isPresented: $showActivationSheet) {
                BridgeActivationSheet(
                    scope: .global,
                    onConfirm: confirmActivation,
                    onCancel: cancelActivation
                )
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Bridge toggle binding con anti-loop guard

    @State private var showActivationSheet: Bool = false
    @State private var isApplyingSilentRevert: Bool = false

    /// Binding al bridge toggle con interceptor: cuando cambia, presenta sheet correspondiente
    /// (activation o deactivation) si hay TX bridgeadas que requieren decisión del user.
    private var bridgeBinding: Binding<Bool> {
        Binding(
            get: { appPreferences.bridgeGroupExpensesToPersonalAccounts },
            set: { newValue in
                guard !isApplyingSilentRevert else { return }
                let currentValue = appPreferences.bridgeGroupExpensesToPersonalAccounts
                guard newValue != currentValue else { return }
                pendingBridgeValue = currentValue
                appPreferences.bridgeGroupExpensesToPersonalAccounts = newValue
                // Invalidar cache del resolver (override per-grupo no cambia pero el
                // effective sí depende del global).
                BridgeModeResolver.shared.invalidateCache()
                let hasBridged = hasBridgedTransactions()
                TelemetryService.track(.bridgeGlobalToggled, parameters: [
                    "enabled": String(newValue),
                    "hadBridgedTx": String(hasBridged)
                ])
                if hasBridged {
                    if newValue {
                        showActivationSheet = true
                    } else {
                        showDeactivationSheet = true
                    }
                } else {
                    // Sin TX bridgeadas: no se presentará sheet → reset pendingBridgeValue
                    // para evitar que un cancel futuro de OTRO toggle use este stale value.
                    pendingBridgeValue = nil
                }
            }
        )
    }

    private func hasBridgedTransactions() -> Bool {
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> {
                $0.splitExpenseID != nil || $0.splitSettlementID != nil
            }
        )
        do {
            return try modelContext.fetchCount(descriptor) > 0
        } catch {
            #if DEBUG
            print("hasBridgedTransactions: fetchCount failed: \(error)")
            #endif
            return false
        }
    }

    private func confirmDeactivation() {
        pendingBridgeValue = nil
    }

    private func cancelDeactivation() {
        revertToggleIfPending()
    }

    private func confirmActivation() {
        pendingBridgeValue = nil
    }

    private func cancelActivation() {
        revertToggleIfPending()
    }

    private func revertToggleIfPending() {
        guard let pending = pendingBridgeValue else { return }
        isApplyingSilentRevert = true
        appPreferences.bridgeGroupExpensesToPersonalAccounts = pending
        BridgeModeResolver.shared.invalidateCache()
        pendingBridgeValue = nil
        // Reset el flag tras el ciclo del run-loop para no comer cambios posteriores.
        DispatchQueue.main.async { isApplyingSilentRevert = false }
    }
}
