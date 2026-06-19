//
//  GroupExpenseAccountFinalizationSheet.swift
//  Yala
//
//  M6: sheet finalización para drafts source=.groupExpense con needsUserInput=["account"].
//  Caso A bridgeado pero sin cuenta personal disponible (sync remoto, cambio moneda invalidante).
//
//  El user elige una cuenta compatible con la moneda del expense. La finalización crea TX
//  cuenta real con `splitExpenseID` setteado e invoca el bridge para regenerar TX virtual lent.
//
//  Hint contextual leído de `draft.originReasonKey` + interpolación de actor/group snapshot.
//  El cuerpo visual usa GroupDraftFinalizationScaffold (mismo lenguaje que el editor normal
//  del Inbox): banner explicativo, monto grande read-only, chip de cuenta activo, hint warning.
//

import SwiftUI
import SwiftData

struct GroupExpenseAccountFinalizationSheet: View {

    // MARK: - Input

    let draft: InboxDraft
    let onApproved: () -> Void

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(CurrencyConverter.self) private var currencyConverter

    // MARK: - State

    @State private var selectedAccount: Account? = nil
    @State private var showAccountSelector: Bool = false
    @State private var groupName: String = ""
    @State private var resolvedCurrency: String = ""
    @State private var saveErrorMessage: String? = nil
    @State private var showSaveError: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GroupDraftFinalizationScaffold(
                bannerMessage: String(format: L10n.Inbox.GroupExpenseAccountDraft.banner, groupName),
                note: draft.note,
                amount: draft.amount,
                currencyCode: resolvedCurrency,
                date: draft.effectiveDate,
                hint: hintMessage,
                finalizeDisabled: selectedAccount == nil,
                onFinalize: { handleFinalize() }
            ) {
                SelectionChip(
                    icon: "creditcard",
                    text: selectedAccount?.name ?? L10n.Inbox.GroupExpenseAccountDraft.assignAccount,
                    isSelected: selectedAccount != nil,
                    color: selectedAccount.map { Color(hex: $0.colorHex) }
                ) {
                    showAccountSelector = true
                }
            }
            .navigationTitle(L10n.Inbox.GroupExpenseAccountDraft.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAccountSelector) {
                AccountSelectorSheet(
                    selectedAccount: $selectedAccount,
                    title: L10n.Inbox.GroupExpenseAccountDraft.assignAccount,
                    currencyFilter: resolvedCurrency.isEmpty ? nil : resolvedCurrency
                )
            }
            .alert(L10n.Common.error, isPresented: $showSaveError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(saveErrorMessage ?? L10n.Common.unknownError)
            }
            .onAppear { loadMetadata() }
        }
    }

    // MARK: - Contextual Hint

    /// Hint warning de causa específica (debajo del selector). Solo cuando hay `originReasonKey`.
    private var hintMessage: String? {
        guard let reasonKey = draft.originReasonKey else { return nil }
        return resolveHintCopy(reasonKey: reasonKey)
    }

    /// Resuelve el copy contextual con interpolación de actor + group según el reasonKey.
    /// `currencyChanged` → impersonal (sync remoto no expone "modifiedBy").
    /// `remoteCreate` → con actor name (payer original snapshot).
    private func resolveHintCopy(reasonKey: String) -> String {
        guard let reason = DraftOriginReason(rawValue: reasonKey) else { return "" }
        let group = draft.originGroupName ?? groupName
        switch reason {
        case .currencyChanged:
            return String(format: L10n.Groups.Bridge.draftReasonCurrencyChanged, group)
        case .remoteCreate:
            let actor = draft.originActorName ?? "?"
            return String(format: L10n.Groups.Bridge.draftReasonRemoteCreate, actor, group)
        }
    }

    // MARK: - Actions

    /// Resuelve groupName + currency desde SplitGroup/SplitExpense origen (snapshot fallback
    /// a draft.originGroupName si SplitGroup no se encuentra — caso edge race).
    private func loadMetadata() {
        // Currency desde SplitExpense origen (fuente de verdad).
        // SwiftData no soporta `$0.id.uuidString == String` con tipos valor — convertir antes.
        if let splitID = draft.splitExpenseID, let splitUUID = UUID(uuidString: splitID) {
            let descriptor = FetchDescriptor<SplitExpense>(
                predicate: #Predicate { $0.id == splitUUID }
            )
            resolvedCurrency = (try? modelContext.fetch(descriptor).first?.currencyCode) ?? ""
        }
        // Group name desde SplitGroup live; fallback al snapshot del draft.
        if let zoneID = draft.splitGroupZoneID {
            let descriptor = FetchDescriptor<SplitGroup>(
                predicate: #Predicate { $0.cloudKitZoneID == zoneID }
            )
            groupName = (try? modelContext.fetch(descriptor).first?.name) ?? draft.originGroupName ?? ""
        } else {
            groupName = draft.originGroupName ?? ""
        }
    }

    private func handleFinalize() {
        guard let account = selectedAccount else { return }
        draft.account = account
        do {
            _ = try DraftService.shared.approveDraft(draft, currencyConverter: currencyConverter)
            DS.Haptic.success()
            onApproved()
            dismiss()
        } catch {
            #if DEBUG
            print("GroupExpenseAccountFinalizationSheet: approve failed: \(error)")
            #endif
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }
}
