//
//  GroupSettlementDraftFinalizationSheet.swift
//  Yala
//
//  A0-Bridge V2.0 (P1-4): sheet dedicada para finalizar drafts source=.groupSettlement.
//  Solo permite asignar cuenta (subcat sistema "Liquidación enviada/recibida" ya viene
//  del bridge). La TX creada queda como TX manual independiente (D7) — no setea
//  splitSettlementID.
//
//  El cuerpo visual usa GroupDraftFinalizationScaffold (mismo lenguaje que el editor
//  normal del Inbox): banner explicativo, monto grande read-only, chip de cuenta activo.
//

import SwiftUI
import SwiftData

struct GroupSettlementDraftFinalizationSheet: View {

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
                bannerMessage: String(format: L10n.Inbox.GroupSettlementDraft.banner, groupName),
                note: draft.note,
                amount: draft.amount,
                currencyCode: resolvedCurrency,
                date: draft.effectiveDate,
                categoryReadOnly: categoryReadOnly,
                finalizeDisabled: selectedAccount == nil,
                onFinalize: { handleFinalize() }
            ) {
                SelectionChip(
                    icon: "creditcard",
                    text: selectedAccount?.name ?? L10n.Inbox.GroupSettlementDraft.assignAccount,
                    isSelected: selectedAccount != nil,
                    color: selectedAccount.map { Color(hex: $0.colorHex) }
                ) {
                    showAccountSelector = true
                }
            }
            .navigationTitle(L10n.Inbox.GroupSettlementDraft.title)
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
                    title: L10n.Inbox.GroupSettlementDraft.assignAccount,
                    currencyFilter: resolvedCurrency.isEmpty ? nil : resolvedCurrency
                )
            }
            .alert(L10n.Common.error, isPresented: $showSaveError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(saveErrorMessage ?? L10n.Common.unknownError)
            }
            // M6: NO defaults — eliminado resolvePreselectedAccount, user siempre elige cuenta.
            .onAppear { loadMetadata() }
        }
    }

    // MARK: - Derived

    /// Chip de categoría read-only: subcat sistema "Liquidación enviada/recibida" (siempre
    /// poblada por el bridge). Defensivo a `nil` durante hidratación lazy de CloudKit.
    private var categoryReadOnly: (name: String, iconName: String, colorHex: String)? {
        guard let sub = draft.subcategory else { return nil }
        return (sub.name, sub.iconName ?? sub.safeCategory.iconName ?? "folder", sub.safeCategory.colorHex)
    }

    // MARK: - Actions

    private func loadMetadata() {
        // Group name desde zoneID.
        if let zoneID = draft.splitGroupZoneID {
            let groupDesc = FetchDescriptor<SplitGroup>(
                predicate: #Predicate { $0.cloudKitZoneID == zoneID }
            )
            groupName = (try? modelContext.fetch(groupDesc).first?.name) ?? ""
        }
        // Currency desde SplitSettlement origen.
        // SwiftData no soporta `$0.id.uuidString == String` con tipos valor — convertir antes.
        if let settlementID = draft.splitSettlementID, let settlementUUID = UUID(uuidString: settlementID) {
            let settDesc = FetchDescriptor<SplitSettlement>(
                predicate: #Predicate { $0.id == settlementUUID }
            )
            resolvedCurrency = (try? modelContext.fetch(settDesc).first?.currencyCode) ?? ""
        }
    }

    private func handleFinalize() {
        guard let account = selectedAccount else { return }
        draft.account = account
        do {
            _ = try DraftService.shared.approveDraft(draft, currencyConverter: currencyConverter)
            // M6: NO defaults — eliminada persistencia setDefaultSettlementAccount.
            DS.Haptic.success()
            onApproved()
            dismiss()
        } catch {
            #if DEBUG
            print("GroupSettlementDraftFinalizationSheet: approve failed: \(error)")
            #endif
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }
}
