//
//  BridgeActivationSheet.swift
//  Yala
//
//  Sheet presentada cuando el user activa el bridge (global o per-grupo) y existen
//  expenses pre-existentes Caso A. Ofrece 2 opciones:
//  - "Empezar desde ahora" (default): solo nuevos expenses generan TX real
//  - "Importar todo el historial": loop bridge sobre expenses pre-existentes,
//    generando drafts en Inbox (con detección fuzzy de duplicates D4 incluida).
//

import SwiftUI
import SwiftData

struct BridgeActivationSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let scope: BridgeScope
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var selectedOption: Option = .startNow
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    /// Conteo de expenses pre-existentes del scope, resuelto una sola vez en `.onAppear`
    /// (evita re-fetch en cada render del body). Alimenta los `%d` de los copys.
    @State private var previousExpenseCount: Int = 0

    enum Option: String, CaseIterable {
        case startNow
        case importAll
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text(L10n.Groups.Bridge.activateBody(previousExpenseCount))
                        .font(DS.Typography.body)
                        .foregroundStyle(.thSecondaryText)

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        optionRow(.startNow,
                                  label: L10n.Groups.Bridge.activateOptionFromNow,
                                  hint: L10n.Groups.Bridge.activateOptionFromNowHint)
                        optionRow(.importAll,
                                  label: L10n.Groups.Bridge.activateOptionImportAll,
                                  hint: L10n.Groups.Bridge.activateOptionImportAllHint(previousExpenseCount))
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
            .yalaScreenBackground(.panel)
            .navigationTitle(L10n.Groups.Bridge.activateTitle)
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
        .onAppear {
            do {
                previousExpenseCount = try fetchScopedExpenses().count
            } catch {
                #if DEBUG
                print("BridgeActivationSheet: Error fetching scoped expenses: \(error)")
                #endif
            }
        }
    }

    @ViewBuilder
    private func optionRow(_ option: Option, label: String, hint: String) -> some View {
        Button {
            selectedOption = option
        } label: {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: selectedOption == option ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selectedOption == option ? .thAccent : .thSecondaryText)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(label)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thPrimaryText)
                    Text(hint)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.thSecondaryText)
                }
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

        switch selectedOption {
        case .startNow:
            // Toggle ya está ON. Próximos expenses Caso A generarán TX real automáticamente.
            TelemetryService.track(.bridgeActivationCompleted, parameters: [
                "scope": scope.telemetryName,
                "option": "startNow"
            ])
            onConfirm()
            dismiss()
        case .importAll:
            do {
                let count = try importHistory()
                TelemetryService.track(.bridgeActivationCompleted, parameters: [
                    "scope": scope.telemetryName,
                    "option": "importAll",
                    "importedCount": String(count)
                ])
                onConfirm()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Loop bridge sobre expenses pre-existentes Caso A scoped. El bridge crea drafts
    /// en Inbox con `needsUserInput=[account]` para que el user finalice cada uno con
    /// la cuenta personal correspondiente. Detección fuzzy de duplicados se integra
    /// en el sheet de approval del draft (iteración follow-up).
    @discardableResult
    private func importHistory() throws -> Int {
        let allExpenses = try fetchScopedExpenses()
        for expense in allExpenses {
            guard let group = try fetchGroup(for: expense.groupZoneID) else { continue }
            try GroupTransactionBridge.shared.bridgeExpense(
                expense, in: group,
                accountForCurrentUser: nil,
                isRemoteSync: false,
                isBulkImport: true,
                shouldSave: false
            )
        }
        try modelContext.save()
        return allExpenses.count
    }

    private func fetchScopedExpenses() throws -> [SplitExpense] {
        switch scope {
        case .global:
            return try modelContext.fetch(FetchDescriptor<SplitExpense>())
        case .perGroup(let zoneID, _):
            return try modelContext.fetch(FetchDescriptor<SplitExpense>(
                predicate: #Predicate<SplitExpense> { $0.groupZoneID == zoneID }
            ))
        }
    }

    private func fetchGroup(for zoneID: String) throws -> SplitGroup? {
        try modelContext.fetch(FetchDescriptor<SplitGroup>(
            predicate: #Predicate<SplitGroup> { $0.cloudKitZoneID == zoneID }
        )).first
    }
}
