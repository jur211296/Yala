//
//  BridgeDeactivationSheet.swift
//  Yala
//
//  Sheet presentada cuando el user desactiva el bridge (global o per-grupo) y
//  ya existen TX bridgeadas pre-existentes. Ofrece 2 opciones:
//  - "Mantener como histórico" (default): freeze (libera `splitExpenseID/etc.`)
//  - "Eliminar": destructive cleanup de TX reales bridgeadas
//

import SwiftUI
import SwiftData

/// Scope del cambio de modo del bridge — usado por sheets compartidos.
enum BridgeScope: Equatable {
    case global
    case perGroup(zoneID: String, groupName: String)
}

struct BridgeDeactivationSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let scope: BridgeScope
    /// Callback invocado tras confirmar la acción. El parent presenter resetea el
    /// pending toggle state si user cancela el sheet.
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var selectedOption: Option = .keep
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var selectedDetent: PresentationDetent = .medium
    /// UX 2.2 · L13-14: «Eliminar de mis cuentas» borra de golpe; antes de hacerlo pregunta cuántos movimientos se van.
    @State private var deleteCount: Int = 0
    @State private var showDeleteConfirm = false
    /// La acción ya se aplicó: la X ya no puede «cancelar» (revertiría el ajuste con los movimientos ya borrados).
    @State private var actionApplied = false

    enum Option: String, CaseIterable {
        case keep
        case delete
    }

    private var isLargeDetent: Bool { selectedDetent == .large }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text(L10n.Groups.Bridge.deactivationSheetBody)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thSecondaryText)

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        optionRow(.keep, label: L10n.Groups.Bridge.deactivationOptionFreeze)
                        optionRow(.delete, label: L10n.Groups.Bridge.deactivationOptionDelete, isDestructive: true)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Semantic.errorForeground)
                    }

                    YalaPrimaryButton(L10n.Action.continueAction, icon: "checkmark.circle.fill") {
                        continueTapped()
                    }
                    .disabled(isProcessing)
                    .accessibilityIdentifier("bridge_deactivation_continue")
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
            .yalaScreenBackground(isLargeDetent ? .subtle : .transparent)
            .navigationTitle(L10n.Groups.Bridge.deactivationSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        if !actionApplied { onCancel() }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
        // Una `.alert` y no un diálogo: pinta siempre las dos salidas (`.claude/rules/swiftui-ds.md`).
        .alert(L10n.Groups.Bridge.deleteConfirmTitle, isPresented: $showDeleteConfirm) {
            Button(L10n.Action.delete, role: .destructive) {
                // Se aplica cuando la alerta ya se fue: cerrar la hoja mientras la alerta se desmonta puede no cerrarla.
                Task { @MainActor in
                    do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                    await performAction()
                }
            }
            .accessibilityIdentifier("bridge_deactivation_delete_confirm")
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Groups.Bridge.deleteConfirmMessage(deleteCount))
        }
    }

    /// «Mantener» sigue sin preguntar; «Eliminar de mis cuentas» cuenta primero lo que se iría y lo pregunta. Si no hay
    /// nada que borrar, no hay nada que confirmar.
    private func continueTapped() {
        guard selectedOption == .delete else {
            Task { await performAction() }
            return
        }
        do {
            deleteCount = try transactionsToDelete(zoneID: scopeZoneID).count
        } catch {
            errorMessage = GroupsUserFacingErrorLogic.message(for: error)
            return
        }
        if deleteCount > 0 {
            showDeleteConfirm = true
        } else {
            Task { await performAction() }
        }
    }

    private var scopeZoneID: String? {
        if case .perGroup(let zoneID, _) = scope { return zoneID }
        return nil
    }

    @ViewBuilder
    private func optionRow(_ option: Option, label: String, isDestructive: Bool = false) -> some View {
        Button {
            selectedOption = option
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: selectedOption == option ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selectedOption == option ? .thAccent : .thSecondaryText)
                Text(label)
                    .font(DS.Typography.body)
                    // UX 2.2 · L13-14: la opción que borra va en el color de peligro.
                    .foregroundStyle(isDestructive ? AnyShapeStyle(DS.Semantic.errorForeground) : AnyShapeStyle(.thPrimaryText))
                Spacer()
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func performAction() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            switch (selectedOption, scope) {
            case (.keep, .global):
                try freezeAllGroups()
            case (.keep, .perGroup(let zoneID, _)):
                try freezeSingleGroup(zoneID: zoneID)
            case (.delete, .global):
                try deleteBridgedTransactions(zoneID: nil)
            case (.delete, .perGroup(let zoneID, _)):
                try deleteBridgedTransactions(zoneID: zoneID)
            }
            actionApplied = true
            onConfirm()
            dismiss()
        } catch {
            errorMessage = GroupsUserFacingErrorLogic.message(for: error)
        }
    }

    /// Freeze scope global: itera todos los SplitGroup vivos del user (no hidden) e
    /// invoca `freezeForSoftDelete` que libera `splitExpenseID/splitSettlementID`
    /// preservando monto/fecha/cuenta/subcat de las TX reales.
    private func freezeAllGroups() throws {
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate<SplitGroup> { $0.isHiddenForAll == false }
        )
        let groups = try modelContext.fetch(descriptor)
        for group in groups {
            try GroupTransactionBridge.shared.freezeForSoftDelete(group: group)
        }
    }

    private func freezeSingleGroup(zoneID: String) throws {
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate<SplitGroup> { $0.cloudKitZoneID == zoneID }
        )
        guard let group = try modelContext.fetch(descriptor).first else { return }
        try GroupTransactionBridge.shared.freezeForSoftDelete(group: group)
    }

    /// Delete destructivo: borra TX reales con `splitExpenseID/splitSettlementID` no-nil.
    /// Scope global → todas. Scope per-grupo → filtra por `splitGroupZoneID`.
    private func deleteBridgedTransactions(zoneID: String?) throws {
        for tx in try transactionsToDelete(zoneID: zoneID) {
            modelContext.delete(tx)
        }
        try modelContext.save()
    }

    /// Lo que «Eliminar de mis cuentas» se lleva: las TX reales puenteadas (las virtuales del sistema se conservan). La
    /// confirmación cuenta con esta MISMA lista, así que el número que ve la persona es el que se borra.
    private func transactionsToDelete(zoneID: String?) throws -> [TransactionItem] {
        let descriptor: FetchDescriptor<TransactionItem>
        if let zoneID {
            descriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> {
                    $0.splitGroupZoneID == zoneID &&
                    ($0.splitExpenseID != nil || $0.splitSettlementID != nil)
                }
            )
        } else {
            descriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> {
                    $0.splitExpenseID != nil || $0.splitSettlementID != nil
                }
            )
        }
        // Solo TX en cuentas NO sistema (preservar virtuales).
        return try modelContext.fetch(descriptor).filter { $0.account?.isSystemAccount == false }
    }
}
