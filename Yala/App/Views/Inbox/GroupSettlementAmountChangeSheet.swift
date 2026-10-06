//
//  GroupSettlementAmountChangeSheet.swift
//  Yala
//
//  Aviso de que cambió el importe de una liquidación que la persona ya aprobó a una cuenta real (ticket
//  `settlement-amount-edited-after-approval-leaves-the-bank-stale`, forma A de Jürgen del 2026-10-05). Usa el andamio de
//  las hojas de grupo: el banner dice qué cambió, el importe grande es el nuevo y la cuenta va fija. «Ajustar a…» pone la
//  transacción en el importe nuevo (`DraftService.approveDraft`); «Dejar en…» rechaza el aviso, que queda en Archivados
//  como la decisión y no vuelve a preguntar por la misma corrección.
//

import SwiftUI
import SwiftData

struct GroupSettlementAmountChangeSheet: View {

    // MARK: - Input

    let draft: InboxDraft
    let onResolved: () -> Void

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(CurrencyConverter.self) private var currencyConverter
    @Environment(AppPreferences.self) private var appPreferences

    // MARK: - State

    /// Lo que se ajusta, resuelto por la marca al montar (`GroupTransactionBridge.amountChangeTarget`). Valores, no
    /// modelos: la hoja no retiene un `@Model` que el re-puente pueda borrar mientras está abierta.
    private struct Target {
        /// Importe ya revisado: el de la marca (lo que la persona aprobó o ajustó por última vez).
        let reviewedAmount: Double
        /// Lo que tiene la transacción real ahora.
        let transactionAmount: Double
        let currencyCode: String
        let accountName: String
        let accountColorHex: String?
    }

    @State private var target: Target? = nil
    @State private var didResolve = false
    @State private var saveErrorMessage: String? = nil
    @State private var showSaveError: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GroupDraftFinalizationScaffold(
                bannerMessage: bannerMessage,
                note: draft.note,
                amount: draft.amount,
                currencyCode: target?.currencyCode ?? draft.displayCurrencyCode ?? "",
                date: draft.effectiveDate,
                categoryReadOnly: categoryReadOnly,
                finalizeDisabled: target == nil || draft.amount == nil,
                onFinalize: { handleAdjust() },
                finalizeTitle: L10n.Inbox.GroupSettlementAmountChange.adjust(formatted(draft.amount)),
                secondaryAction: target.map { target in
                    (title: L10n.Inbox.GroupSettlementAmountChange.keep(formatted(target.transactionAmount)),
                     action: { handleKeep() })
                }
            ) {
                SelectionChip(
                    icon: "creditcard",
                    text: target?.accountName ?? draft.displayAccountName ?? "",
                    isSelected: true,
                    color: target?.accountColorHex.map { Color(hex: $0) }
                ) {}
                .allowsHitTesting(false)
            }
            .navigationTitle(L10n.Inbox.GroupSettlementAmountChange.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .alert(L10n.Common.error, isPresented: $showSaveError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(saveErrorMessage ?? L10n.Common.unknownError)
            }
            .onAppear { resolveTarget() }
        }
    }

    // MARK: - Derived

    private func formatted(_ amount: Double?) -> String {
        guard let amount else { return "—" }
        let code = target?.currencyCode ?? draft.displayCurrencyCode ?? ""
        return appPreferences.currency(abs(amount), currencyCode: code, forceFullPrecision: true)
    }

    private var bannerMessage: String {
        // Sin transacción que ajustar (borrada, duplicada o en otra divisa) no hay cifras que contar: se dice y ya.
        guard let target else {
            return didResolve ? L10n.Inbox.GroupSettlementAmountChange.transactionGone : ""
        }
        let group = draft.originGroupName ?? ""
        let before = formatted(target.reviewedAmount)
        let now = formatted(draft.amount)
        let inAccount = formatted(target.transactionAmount)
        guard let person = draft.originActorName, !person.isEmpty else {
            return L10n.Inbox.GroupSettlementAmountChange.bannerUnnamed(group, before, now, target.accountName, inAccount)
        }
        // Con signo positivo, la otra persona me pagó (Caso D: cobro); con negativo, le pagué yo (Caso C).
        if (draft.amount ?? 0) >= 0 {
            return L10n.Inbox.GroupSettlementAmountChange.bannerReceived(
                person, group, before, now, target.accountName, inAccount)
        }
        return L10n.Inbox.GroupSettlementAmountChange.bannerSent(
            person, group, before, now, target.accountName, inAccount)
    }

    private var categoryReadOnly: (name: String, iconName: String, colorHex: String)? {
        guard let sub = draft.subcategory else { return nil }
        return (sub.name, sub.iconName ?? sub.safeCategory.iconName ?? "folder", sub.safeCategory.colorHex)
    }

    // MARK: - Actions

    private func resolveTarget() {
        defer { didResolve = true }
        do {
            guard let resolved = try GroupTransactionBridge.amountChangeTarget(
                settlementID: draft.splitSettlementID, in: modelContext) else { return }
            let transaction = resolved.transaction
            target = Target(
                reviewedAmount: resolved.mark.amount ?? transaction.amount,
                transactionAmount: transaction.amount,
                currencyCode: transaction.currencyCode,
                accountName: transaction.account?.name ?? "",
                accountColorHex: transaction.account?.colorHex)
        } catch {
            #if DEBUG
            print("GroupSettlementAmountChangeSheet: Error: \(error)")
            #endif
        }
    }

    private func handleAdjust() {
        do {
            _ = try DraftService.shared.approveDraft(draft, currencyConverter: currencyConverter)
            DS.Haptic.success()
            onResolved()
            dismiss()
        } catch {
            #if DEBUG
            print("GroupSettlementAmountChangeSheet: adjust failed: \(error)")
            #endif
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    private func handleKeep() {
        do {
            if draft.status != .rejected {
                try DraftService.shared.rejectDraft(draft)
            }
            onResolved()
            dismiss()
        } catch {
            #if DEBUG
            print("GroupSettlementAmountChangeSheet: keep failed: \(error)")
            #endif
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }
}
