//
//  GroupExpenseDraftFinalizationSheet.swift
//  Yala
//
//  A0-Bridge V2.0 (P1-4): sheet dedicada para finalizar drafts source=.groupExpense.
//  Solo permite asignar subcategoría — los demás campos vienen del bridge y son read-only.
//  approveDraft sigue el path TX-puntero (UPDATE de la TX virtual existente).
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
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    GroupDraftReadOnlyHeader(
                        groupName: groupName,
                        note: draft.note,
                        amount: draft.amount,
                        currencyCode: resolvedCurrency,
                        date: draft.effectiveDate,
                        iconName: "person.2.fill"
                    )

                    // Selector de subcategoría
                    Button {
                        showSubcategorySelector = true
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Text(L10n.Inbox.GroupExpenseDraft.assignSubcategory)
                                .font(DS.Typography.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            if let sub = selectedSubcategory {
                                Text(sub.name)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text(L10n.Common.select)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.tertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.vertical, DS.FormRow.paddingV)
                    }
                    .buttonStyle(.plain)
                    .panelCard()
                    .padding(.horizontal, DS.Spacing.lg)

                    YalaPrimaryButton(L10n.Inbox.GroupDraft.finalize, icon: "checkmark.circle.fill") {
                        handleFinalize()
                    }
                    .disabled(selectedSubcategory == nil)
                    .padding(.horizontal, DS.Spacing.lg)
                }
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
            .background(PanelBackgroundView())
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
        if let splitID = draft.splitExpenseID {
            let expenseDesc = FetchDescriptor<SplitExpense>(
                predicate: #Predicate { expense in
                    expense.id.uuidString == splitID
                }
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
