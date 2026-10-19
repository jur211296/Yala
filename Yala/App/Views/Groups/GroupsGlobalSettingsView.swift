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

    /// L19-12 (decisión de Jürgen, 2026-10-18): «Salir de todos mis grupos» vive aquí y no en «Vaciar datos», donde
    /// parecía el botón principal y salía de todos sin preguntar. Se lee al abrir la hoja (READ-ONLY).
    @State private var offersLeaveAllGroups = false
    /// Los grupos que el lote va a tocar, leídos al tocar el botón: la confirmación los nombra.
    @State private var leaveAllGroupNames: [String] = []
    @State private var showLeaveAllConfirm = false
    @State private var showBatchLeave = false

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

                    // MARK: - Salir de todos mis grupos (L19-12)
                    if offersLeaveAllGroups {
                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                            YalaSectionHeader(L10n.UXL20D.leaveAllSection)
                            // Secundario a propósito: salir de todos es más grave que salir de uno.
                            YalaSecondaryButton(L10n.UXL20D.leaveAllButton, destructive: true) {
                                leaveAllGroupNames = Self.groupsTheBatchWouldTouch()
                                showLeaveAllConfirm = true
                            }
                            .accessibilityIdentifier("groups_settings_leave_all")
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
            // Antes de empezar, la lista: salir de UN grupo pregunta, y salir de todos preguntaba menos.
            .alert(L10n.UXL20D.leaveAllConfirmTitle, isPresented: $showLeaveAllConfirm) {
                Button(L10n.UXL20D.leaveAllConfirmAction, role: .destructive) { showBatchLeave = true }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(Self.confirmMessage(for: leaveAllGroupNames))
            }
            // El flujo de siempre del lote (D10), headless: si se cierra a mitad, sigue y el resultado se ve en Grupos.
            .sheet(isPresented: $showBatchLeave) {
                GroupBatchLeaveView(onRequestCloseSettings: { dismiss() })
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
        .onAppear {
            offersLeaveAllGroups = Self.offersLeaveAllGroups(GroupService.shared.accountDeletionGroupsSummary())
        }
    }

    // MARK: - Salir de todos mis grupos (L19-12)

    /// Las mismas condiciones que tenía en «Vaciar datos» (D10): el canal de grupos encendido, algún grupo vivo y CERO
    /// saldos pendientes (el lote no se ofrece con deudas: cada grupo con saldo se sale a mano, desde él).
    static func offersLeaveAllGroups(_ summary: AccountDeletionGroupsSummary) -> Bool {
        // QA/XCUITest: fuerza la oferta (los dos seams son inertes en release).
        if UITestHooks.groupsBatchDemo || UITestHooks.groupsBatchRunning { return true }
        return CloudSyncFlags.groupsBackendEnabled && summary.hasGroups && !summary.hasOutstandingDebt
    }

    /// Los nombres de los grupos que el lote va a tocar: la MISMA clasificación con la que arranca
    /// (`GroupService.batchClassifyAllGroups`), así la lista no promete grupos que el lote salta.
    private static func groupsTheBatchWouldTouch() -> [String] {
        do {
            return try GroupService.shared.batchClassifyAllGroups().map(\.groupName)
        } catch {
            #if DEBUG
            print("GroupsGlobalSettingsView: Error: no se pudieron leer los grupos del lote: \(error)")
            #endif
            return []
        }
    }

    /// «Vas a salir de Viaje a Cusco y Viaje a Lima.» Sin nombres (no se pudieron leer), la frase general.
    static func confirmMessage(for names: [String], locale: Locale = AppLocale.current) -> String {
        guard !names.isEmpty else { return L10n.UXL20D.leaveAllConfirmMessageGeneric }
        let formatter = ListFormatter()
        formatter.locale = locale
        let list = formatter.string(from: names) ?? names.joined(separator: ", ")
        return L10n.UXL20D.leaveAllConfirmMessage(list)
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
