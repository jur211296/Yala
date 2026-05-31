//
//  GroupSettlementDraftFinalizationSheet.swift
//  Yala
//
//  A0-Bridge V2.0 (P1-4): sheet dedicada para finalizar drafts source=.groupSettlement.
//  Solo permite asignar cuenta (subcat sistema "Liquidación enviada/recibida" ya viene
//  del bridge). Persiste defaultSettlementAccount tras éxito. La TX creada queda como
//  TX manual independiente (D7) — no setea splitSettlementID.
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
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    GroupDraftReadOnlyHeader(
                        groupName: groupName,
                        note: draft.note,
                        amount: draft.amount,
                        currencyCode: resolvedCurrency,
                        date: draft.effectiveDate,
                        iconName: "arrow.left.arrow.right.circle.fill"
                    )

                    // Selector de cuenta
                    Button {
                        showAccountSelector = true
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Text(L10n.Inbox.GroupSettlementDraft.assignAccount)
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
