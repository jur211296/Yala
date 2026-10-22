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
                        optionRow(.delete, label: L10n.Groups.Bridge.deactivationOptionDelete)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Semantic.errorForeground)
                    }

                    YalaPrimaryButton(L10n.Action.continueAction, icon: "checkmark.circle.fill") {
                        Task { await performAction() }
                    }
                    .disabled(isProcessing)
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
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }

    @ViewBuilder
    private func optionRow(_ option: Option, label: String) -> some View {
        Button {
            selectedOption = option
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: selectedOption == option ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selectedOption == option ? .thAccent : .thSecondaryText)
                Text(label)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)
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
            onConfirm()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
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
        let txs = try modelContext.fetch(descriptor)
        // Solo borrar TX en cuentas NO sistema (preservar virtuales).
        for tx in txs where tx.account?.isSystemAccount == false {
            modelContext.delete(tx)
        }
        try modelContext.save()
    }
}
