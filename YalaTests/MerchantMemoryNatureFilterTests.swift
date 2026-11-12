//
//  MerchantMemoryNatureFilterTests.swift
//  YalaTests
//
//  Ticket `merchant-memory-suggests-across-natures-in-three-more-places` (card k5jh): la memoria de comercios no le pone
//  a un gasto una subcategoría de ingreso (ni al revés). Manda el tipo del borrador, con el criterio de
//  `DraftBuilder.matchesNature`. Apple Pay lo prueba de punta a punta en `ApplePayDraftServiceTests`; aquí, el servicio
//  con su control positivo y el cableado de la voz y la Bandeja (vistas: solo se pueden fijar por su código).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Memoria de comercios — filtro de naturaleza", .serialized)
struct MerchantMemoryNatureFilterTests {

    private func remember(
        _ merchant: String, as subcategory: Subcategory, approved: Int, in context: ModelContext
    ) {
        context.insert(MerchantMemory(
            merchantCanonical: MerchantCanonicalizer.canonicalize(merchant),
            subcategory: subcategory,
            countApproved: approved,
            countCorrected: 0,
            lastApprovedAt: Date(timeIntervalSince1970: 1_700_000_000),
            aliases: [merchant]
        ))
    }

    private func subcategoryOf(_ suggestion: MerchantSuggestion) -> Subcategory? {
        switch suggestion {
        case .autoAssign(let sub), .suggest(let sub): sub
        case .none: nil
        }
    }

    // MARK: - El servicio

    @Test func incomeMemory_isDroppedForAnExpense_andKeptForAnIncome() throws {
        let context = try makeTestContext()
        let income = makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        let refund = makeTestSubcategory(context: context, name: "Reembolso", category: income)
        remember("Wong", as: refund, approved: 6, in: context)
        try context.save()
        let service = MerchantMemoryService(modelContext: context)

        #expect(subcategoryOf(service.suggest(for: "Wong", isExpense: true)) == nil)
        // Control: con un ingreso la misma memoria sí vale, y conserva su nivel (autoAssign).
        guard case .autoAssign(let kept) = service.suggest(for: "Wong", isExpense: false) else {
            Issue.record("Con un ingreso la memoria de ingreso tenía que autoasignarse.")
            return
        }
        #expect(kept === refund)
    }

    @Test func expenseMemory_isDroppedForAnIncome_andKeptForAnExpense() throws {
        let context = try makeTestContext()
        let food = makeTestCategory(context: context, name: "Comida", isIncome: false)
        let market = makeTestSubcategory(context: context, name: "Supermercado", category: food)
        remember("Plaza Vea", as: market, approved: 3, in: context)
        try context.save()
        let service = MerchantMemoryService(modelContext: context)

        #expect(subcategoryOf(service.suggest(for: "Plaza Vea", isExpense: false)) == nil)
        // Control: con un gasto vale, y conserva su nivel (suggest).
        guard case .suggest(let kept) = service.suggest(for: "Plaza Vea", isExpense: true) else {
            Issue.record("Con un gasto la memoria de gasto tenía que sugerirse.")
            return
        }
        #expect(kept === market)
    }

    // MARK: - El cableado de la voz y la Bandeja

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Las tres superficies del ticket piden la sugerencia con su tipo. Una llamada a `suggest(for:)` a secas en
    /// cualquiera de ellas reabre el bug.
    @Test func voiceInboxAndApplePay_askWithTheDraftType() throws {
        let voice = try source("Yala/App/Views/Voice/VoiceRecordingView.swift")
        #expect(voice.contains("merchantService.suggest(for: parsed.note, isExpense: parsed.isExpense)"))
        #expect(!voice.contains("merchantService.suggest(for: parsed.note)"))

        let inbox = try source("Yala/App/Views/Inbox/InboxDraftEditSheet.swift")
        #expect(inbox.contains("merchantService.suggest(for: note, isExpense: isExpense)"))
        #expect(!inbox.contains("merchantService.suggest(for: note)"))

        let applePay = try source("Yala/App/Services/ApplePayDraftService.swift")
        #expect(applePay.contains(".suggest(for: merchant, isExpense: true)"))
        #expect(!applePay.contains(".suggest(for: merchant)"))
    }
}
