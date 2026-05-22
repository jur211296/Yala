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

                    // Hint contextual M6 — copy distinto según originReasonKey.
                    contextualHint

                    // Selector de cuenta (filtrado por moneda del expense).
                    accountSelectorRow

                    YalaPrimaryButton(L10n.Inbox.GroupDraft.finalize, icon: "checkmark.circle.fill") {
                        handleFinalize()
                    }
                    .disabled(selectedAccount == nil)
                    .padding(.horizontal, DS.Spacing.lg)
                }
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
            .yalaScreenBackground()
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

    @ViewBuilder
    private var contextualHint: some View {
        if let reasonKey = draft.originReasonKey {
            let copy = resolveHintCopy(reasonKey: reasonKey)
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Semantic.warningForeground)
                Text(copy)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg).fill(DS.Semantic.warningBackground)
            )
            .padding(.horizontal, DS.Spacing.lg)
        }
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

    // MARK: - Account Selector Row

    private var accountSelectorRow: some View {
        Button {
            showAccountSelector = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text(L10n.Inbox.GroupExpenseAccountDraft.assignAccount)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                Spacer()
                if let account = selectedAccount {
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(Color(hex: account.colorHex))
                            .frame(width: 20, height: 20) // A11Y-DT: row icon decorative
                        Text(account.name)
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
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
