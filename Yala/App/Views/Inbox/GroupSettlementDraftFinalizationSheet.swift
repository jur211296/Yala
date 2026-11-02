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
    /// UX 2.2 · L13-7: tras «Sí, registrar» de un pago, quien abre la hoja recibe la cuenta elegida.
    var onRegistered: ((String) -> Void)? = nil

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
    /// UX 2.2 · L13-12: «Pago a Ana · Viaje a Cusco» cuando el borrador no trae descripción.
    @State private var paymentName: String?
    /// Grupos B · card 10: lo que este pago cobra de tus ventas, que cuenta como ingreso el día del pago.
    @State private var collectedLine: String?

    @Environment(AppPreferences.self) private var appPreferences

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GroupDraftFinalizationScaffold(
                bannerMessage: String(format: L10n.Inbox.GroupSettlementDraft.banner, groupName),
                note: draft.note.isEmpty ? (paymentName ?? draft.note) : draft.note,
                amount: draft.amount,
                currencyCode: resolvedCurrency,
                date: draft.effectiveDate,
                categoryReadOnly: categoryReadOnly,
                finalizeDisabled: selectedAccount == nil,
                onFinalize: { handleFinalize() },
                footnote: collectedLine
            ) {
                SelectionChip(
                    icon: "creditcard",
                    text: selectedAccount?.name ?? accountLabel,
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
                    title: accountLabel,
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

    /// El borrador de quien PAGA lleva el importe en negativo (`bridgeSettlement`, Caso C): ahí el dinero
    /// sale de la cuenta, y «Cuenta de destino» le decía lo contrario.
    private var accountLabel: String {
        GroupSettlementDraftAccountLabelLogic.isOutgoing(amount: draft.amount)
            ? L10n.Inbox.GroupExpenseAccountDraft.assignAccount
            : L10n.Inbox.GroupSettlementDraft.assignAccount
    }

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
        paymentName = GroupSettlementDraftNameResolver.name(for: draft, context: modelContext)
        collectedLine = loadCollectedLine()
    }

    /// La frase de lo que este pago cobra: las patas cobradas que el puente escribió con esta liquidación
    /// (`GroupTransactionBridge.reconcileReceivables`). Solo en un pago que recibes.
    private func loadCollectedLine() -> String? {
        guard (draft.amount ?? 0) > 0, let settlementID = draft.splitSettlementID,
              let settlementUUID = UUID(uuidString: settlementID) else { return nil }
        let marker = GroupSplitLinesRecipe.encodeCollectedMarker(eventID: settlementUUID)
        do {
            let legs = try modelContext.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitLinesRaw == marker }))
            let bySale = Dictionary(grouping: legs.filter { !$0.isDeleted }) { $0.splitExpenseID ?? "" }
            var parts: [(date: Date, part: GroupSettlementCollectedLineLogic.Part)] = []
            for (saleID, saleLegs) in bySale {
                guard let saleUUID = UUID(uuidString: saleID) else { continue }
                let sale = try modelContext.fetch(FetchDescriptor<SplitExpense>(
                    predicate: #Predicate { $0.id == saleUUID })).first
                let name = sale?.expenseDescription.isEmpty == false
                    ? (sale?.expenseDescription ?? "") : (saleLegs.first?.note ?? "")
                parts.append((sale?.date ?? .distantPast, .init(
                    saleName: name,
                    categoryName: sale?.subcategoryName ?? saleLegs.first?.subcategory?.name,
                    amount: saleLegs.reduce(0) { $0 + $1.amount })))
            }
            let currency = resolvedCurrency.isEmpty ? (legs.first?.currencyCode ?? "") : resolvedCurrency
            return GroupSettlementCollectedLineLogic.line(
                parts: parts.sorted { $0.date < $1.date }.map(\.part),
                date: draft.effectiveDate,
                formatAmount: { appPreferences.currency($0, currencyCode: currency, forceFullPrecision: true) },
                formatDate: { GroupSettlementCollectedLineLogic.dateText($0) })
        } catch {
            #if DEBUG
            print("GroupSettlementDraftFinalizationSheet: Error: \(error)")
            #endif
            return nil
        }
    }

    private func handleFinalize() {
        guard let account = selectedAccount else { return }
        draft.account = account
        do {
            _ = try DraftService.shared.approveDraft(draft, currencyConverter: currencyConverter)
            // M6: NO defaults — eliminada persistencia setDefaultSettlementAccount.
            DS.Haptic.success()
            onRegistered?(account.name)
            onApproved()
            dismiss()
        } catch {
            #if DEBUG
            print("GroupSettlementDraftFinalizationSheet: approve failed: \(error)")
            #endif
            saveErrorMessage = GroupsUserFacingErrorLogic.message(for: error)
            showSaveError = true
        }
    }
}
