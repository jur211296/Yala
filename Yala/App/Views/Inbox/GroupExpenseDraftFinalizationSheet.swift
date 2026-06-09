//
//  GroupExpenseDraftFinalizationSheet.swift
//  Yala
//
//  A0-Bridge V2.0 (P1-4): sheet dedicada para finalizar drafts source=.groupExpense.
//  Solo permite asignar subcategoría — los demás campos vienen del bridge y son read-only.
//  approveDraft sigue el path TX-puntero (UPDATE de la TX virtual existente).
//
//  El cuerpo visual usa GroupDraftFinalizationScaffold (mismo lenguaje que el editor
//  normal del Inbox): banner explicativo, monto grande read-only, chip de categoría activo.
//

import SwiftUI
import SwiftData

struct GroupExpenseDraftFinalizationSheet: View {

    // MARK: - Input

    let draft: InboxDraft
    let onApproved: () -> Void

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(CurrencyConverter.self) private var currencyConverter

    // MARK: - State

    @State private var selectedSubcategory: Subcategory? = nil
    @State private var showSubcategorySelector: Bool = false
    @State private var groupName: String = ""
    @State private var resolvedCurrency: String = ""
    @State private var saveErrorMessage: String? = nil
    @State private var showSaveError: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GroupDraftFinalizationScaffold(
                bannerMessage: String(format: L10n.Inbox.GroupExpenseDraft.banner, groupName),
                note: draft.note,
                amount: draft.amount,
                currencyCode: resolvedCurrency,
                date: draft.effectiveDate,
                finalizeDisabled: selectedSubcategory == nil,
                onFinalize: { handleFinalize() }
            ) {
                SelectionChip(
                    icon: "tag",
                    text: selectedSubcategory?.name ?? L10n.Inbox.GroupExpenseDraft.assignSubcategory,
                    isSelected: selectedSubcategory != nil,
                    color: selectedSubcategory.map { Color(hex: $0.safeCategory.colorHex) }
                ) {
                    showSubcategorySelector = true
                }
            }
            .navigationTitle(L10n.Inbox.GroupExpenseDraft.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSubcategorySelector) {
                let txType: TransactionType = (draft.amount ?? 0) >= 0 ? .income : .expense
                SubcategorySelectorSheet(
                    selectedSubcategory: $selectedSubcategory,
                    transactionType: txType
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

    // MARK: - Actions

    private func loadMetadata() {
        // Group name desde zoneID.
        if let zoneID = draft.splitGroupZoneID {
            let groupDesc = FetchDescriptor<SplitGroup>(
                predicate: #Predicate { $0.cloudKitZoneID == zoneID }
            )
            groupName = (try? modelContext.fetch(groupDesc).first?.name) ?? ""
        }
        // Currency desde el SplitExpense origen (cachedCurrencyCode no se popula al crear el draft).
        // SwiftData no soporta `$0.id.uuidString == String` con tipos valor — convertir antes.
        if let splitID = draft.splitExpenseID, let splitUUID = UUID(uuidString: splitID) {
            let expenseDesc = FetchDescriptor<SplitExpense>(
                predicate: #Predicate { $0.id == splitUUID }
            )
            resolvedCurrency = (try? modelContext.fetch(expenseDesc).first?.currencyCode) ?? ""
        }
    }

    private func handleFinalize() {
        guard let subcategory = selectedSubcategory else { return }
        draft.subcategory = subcategory
        do {
            _ = try DraftService.shared.approveDraft(draft, currencyConverter: currencyConverter)
            DS.Haptic.success()
            onApproved()
            dismiss()
        } catch {
            #if DEBUG
            print("GroupExpenseDraftFinalizationSheet: approve failed: \(error)")
            #endif
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }
}
