//
//  InboxDismissCapturedDraftTests.swift
//  YalaTests
//
//  Ticket `inbox-dismiss-x-does-not-delete-the-draft-for-good`, las fuentes que capturan fuera de la app y
//  materializan una cola del App Group: Apple Pay y Siri/Shortcuts. Se vuelven a procesar en cada arranque, en
//  cada vuelta a primer plano y tras cada ráfaga de cambios remotos (`InboundCaptureDrain`), así que el contrato
//  es que un borrador descartado no vuelve en el pase siguiente: la entrada de la cola se consume al guardar.
//  No deduplican a propósito («nunca perder un gasto capturado»): lo que se recuerda es la cola consumida, no el
//  parecido. El residual —un kill entre el `save()` y el `remove` reprocesa la entrada— está en el ticket.
//
//  Las fuentes que no tienen cola (voz, foto o captura, chat) no se re-ejecutan sobre el mismo dato, y correo y
//  automatización no tienen creador: no pueden recrear nada por construcción (ver el ticket).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized, .lastUsedAccountIsolated)
@MainActor
struct InboxDismissCapturedDraftTests {

    private let pendingDefaults: UserDefaults

    init() {
        pendingDefaults = UserDefaults(suiteName: "test.inboxdismiss.pending.\(UUID().uuidString)")!
        iCloudSyncService.shared._testReset()
    }

    private func dismissAll(_ drafts: [InboxDraft], _ context: ModelContext) throws {
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }
        try DraftService.shared.bulkReject(drafts)
    }

    @Test func applePayCapture_dismissed_doesNotComeBackOnTheNextPass() throws {
        let context = try makeTestContext()
        context.insert(Account(name: "BCP", currencyCode: "USD", colorHex: "#000000", iconName: "creditcard", type: "debit"))
        try context.save()
        ApplePayPendingStore.append(ApplePayPendingExpense(rawAmount: "$18", merchant: "Starbucks", savedAt: 1_700_000_000),
                                    defaults: pendingDefaults)

        #expect(ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true) == 1)
        let drafts = try context.fetch(FetchDescriptor<InboxDraft>())
        try dismissAll(drafts, context)

        // Arranque, primer plano y ráfaga remota.
        for _ in 0..<3 {
            #expect(ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true) == 0)
        }
        #expect(try context.fetch(FetchDescriptor<InboxDraft>()).allSatisfy { $0.status == .rejected })
    }

    @Test func siriCapture_dismissed_doesNotComeBackOnTheNextPass() throws {
        let context = try makeTestContext()
        let parsed = ParsedTransaction(
            amount: 50, date: nil, note: "café", isExpense: true, subcategoryHint: nil, tagHints: [], currencyHint: nil,
            confidence: ParsedTransaction.TransactionConfidence(amount: 1, date: 0, merchant: 0, subcategory: 0, tags: 0)
        )
        SiriPendingStore.append(SiriPendingEntry(rawText: "50 en café", transactions: [parsed], savedAt: 1),
                                defaults: pendingDefaults)

        #expect(SiriDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true) == 1)
        try dismissAll(try context.fetch(FetchDescriptor<InboxDraft>()), context)

        for _ in 0..<3 {
            #expect(SiriDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true) == 0)
        }
        #expect(try context.fetch(FetchDescriptor<InboxDraft>()).allSatisfy { $0.status == .rejected })
    }

    @Test func twoIdenticalApplePayCaptures_stayTwo_andDismissingOneKeepsTheOther() throws {
        let context = try makeTestContext()
        context.insert(Account(name: "BCP", currencyCode: "USD", colorHex: "#000000", iconName: "creditcard", type: "debit"))
        try context.save()
        ApplePayPendingStore.append(ApplePayPendingExpense(rawAmount: "$18", merchant: "Starbucks", savedAt: 1_700_000_000),
                                    defaults: pendingDefaults)
        ApplePayPendingStore.append(ApplePayPendingExpense(rawAmount: "$18", merchant: "Starbucks", savedAt: 1_700_000_000),
                                    defaults: pendingDefaults)

        #expect(ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true) == 2)
        let drafts = try context.fetch(FetchDescriptor<InboxDraft>())
        #expect(drafts.count == 2, "dos gastos idénticos reales siguen siendo dos")
        try dismissAll([try #require(drafts.first)], context)
        ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)
        ScheduledPaymentDraftService.processDuePayments(context: context)
        #expect(try context.fetch(FetchDescriptor<InboxDraft>()).filter { $0.status == .pending }.count == 1)
    }
}
