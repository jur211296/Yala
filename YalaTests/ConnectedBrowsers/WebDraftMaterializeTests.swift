//
//  WebDraftMaterializeTests.swift
//  YalaTests
//
//  Yala web, lote 1: lo apuntado en el navegador llega por la cola del correo del banco con `source: "web"` y entra en
//  la Bandeja con la cuenta y la subcategoría elegidas, origen `.automation` y la evidencia «Yala web».
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@MainActor
private func webDTO(
    account: String? = nil, subcategory: String? = nil, source: String? = "web",
    currency: String = "PEN", merchant: String? = "Almuerzo", kind: String = "expense", amount: Double = 25
) throws -> BankEmailDraftDTO {
    let json: [String: Any?] = [
        "id": "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "received_at_ms": 1_800_000_000_000.0, "kind": kind, "amount": amount,
        "currency": currency, "merchant": merchant, "date": "2027-01-15", "bank": nil, "account_last4": nil,
        "source": source, "account_ref": account, "subcategory_ref": subcategory,
    ]
    let data = try JSONSerialization.data(withJSONObject: json.compactMapValues { $0 })
    return try JSONDecoder().decode(BankEmailDraftDTO.self, from: data)
}

@Suite("Yala web · lo apuntado en la web entra en la Bandeja", .serialized)
@MainActor
struct WebDraftMaterializeTests {

    @Test func elPayloadDeLaWeb_seLee() throws {
        let dto = try webDTO(account: "11111111-1111-4111-8111-111111111111", subcategory: "44444444-4444-4444-8444-444444444444")
        #expect(dto.source == "web")
        #expect(dto.accountRef == "11111111-1111-4111-8111-111111111111")
        #expect(dto.subcategoryRef == "44444444-4444-4444-8444-444444444444")
        // El del correo no los trae y sigue leyéndose igual.
        let mail = try webDTO(source: nil)
        #expect(mail.source == nil && mail.accountRef == nil)
        #expect(!WebDraftLogic.isWeb(source: mail.source))
    }

    @Test func entraConLaCuenta_yLaSubcategoriaElegidas() throws {
        let context = try makeTestContext()
        let primera = Account(name: "BCP", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let elegida = Account(name: "Yape", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let categoria = Category(name: "Comida", colorHex: "#d97706", isIncome: false, iconName: "fork.knife")
        let sub = Subcategory(name: "Restaurantes", category: categoria)
        context.insert(primera)
        context.insert(elegida)
        context.insert(categoria)
        context.insert(sub)
        try context.save()

        let dto = try webDTO(account: elegida.shortcutID.uuidString, subcategory: sub.shortcutID.uuidString)
        #expect(BankEmailDraftService.materialize([dto], context: context) == 1)
        let draft = try #require(try context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.account?.shortcutID == elegida.shortcutID)
        #expect(draft.subcategory?.shortcutID == sub.shortcutID)
        #expect(draft.sourceType == .automation)
        #expect(draft.evidence == WebDraftLogic.evidence)
        #expect(draft.rawText == WebDraftLogic.evidence)
        #expect(draft.note == "Almuerzo")
        #expect(draft.amount == -25)
        #expect(draft.needsUserInput.isEmpty)
    }

    @Test func conUnaCuentaQueNoEsDeAqui_caeALaDeSuDivisa_yLaSubcategoriaSeElige() throws {
        let context = try makeTestContext()
        let dolares = Account(name: "Dólares", currencyCode: "USD", colorHex: "#000", iconName: "creditcard", type: "bank")
        context.insert(dolares)
        try context.save()

        let dto = try webDTO(account: "99999999-9999-4999-8999-999999999999", subcategory: "88888888-8888-4888-8888-888888888888", currency: "USD")
        _ = BankEmailDraftService.materialize([dto], context: context)
        let draft = try #require(try context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.account?.shortcutID == dolares.shortcutID)
        #expect(draft.subcategory == nil)
        #expect(draft.needsUserInput.contains(DraftInputRequirement.subcategory))
        #expect(draft.sourceType == .automation)
    }

    @Test func unaSubcategoriaOculta_oDelOtroLado_noSeFija() throws {
        let context = try makeTestContext()
        let gasto = Category(name: "Comida", colorHex: "#d97706", isIncome: false)
        let oculta = Subcategory(name: "Vieja", isVisible: false, category: gasto)
        let deGasto = Subcategory(name: "Restaurantes", category: gasto)
        context.insert(gasto)
        context.insert(oculta)
        context.insert(deGasto)
        try context.save()

        // Oculta: no vale aunque el id case.
        _ = BankEmailDraftService.materialize([try webDTO(subcategory: oculta.shortcutID.uuidString)], context: context)
        // Un ingreso no se pone en una subcategoría de gasto.
        let ingreso = try JSONDecoder().decode(BankEmailDraftDTO.self, from: JSONSerialization.data(withJSONObject: [
            "id": "dddddddd-dddd-4ddd-8ddd-dddddddddddd", "received_at_ms": 1_800_000_000_000.0, "kind": "income", "amount": 50.0,
            "currency": "PEN", "date": "2027-01-15", "source": "web", "subcategory_ref": deGasto.shortcutID.uuidString,
        ]))
        _ = BankEmailDraftService.materialize([ingreso], context: context)
        let drafts = try context.fetch(FetchDescriptor<InboxDraft>())
        #expect(drafts.count == 2)
        #expect(drafts.allSatisfy { $0.subcategory?.shortcutID != oculta.shortcutID })
        #expect(drafts.first { ($0.amount ?? 0) > 0 }?.subcategory?.shortcutID != deGasto.shortcutID)
    }

    @Test func laRegla_deLaSubcategoria() {
        #expect(WebDraftLogic.acceptsSubcategory(isVisible: true, isIncomeCategory: false, amount: -10))
        #expect(WebDraftLogic.acceptsSubcategory(isVisible: true, isIncomeCategory: true, amount: 10))
        #expect(!WebDraftLogic.acceptsSubcategory(isVisible: false, isIncomeCategory: false, amount: -10))
        #expect(!WebDraftLogic.acceptsSubcategory(isVisible: true, isIncomeCategory: true, amount: -10))
        #expect(!WebDraftLogic.acceptsSubcategory(isVisible: true, isIncomeCategory: nil, amount: -10))
    }

    @Test func unIngresoDeLaWeb_entraEnPositivo() throws {
        let context = try makeTestContext()
        _ = BankEmailDraftService.materialize([try webDTO(kind: "income", amount: 100)], context: context)
        let draft = try #require(try context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.amount == 100)
    }

    @Test func loDelCorreo_noCambia() throws {
        let context = try makeTestContext()
        let cuenta = Account(name: "BCP", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        context.insert(cuenta)
        try context.save()
        // Un `account_ref` sin `source: "web"` no se mira: el correo no elige cuenta.
        _ = BankEmailDraftService.materialize([try webDTO(account: cuenta.shortcutID.uuidString, source: nil)], context: context)
        let draft = try #require(try context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.sourceType == .emailAlert)
        #expect(draft.evidence == nil)
    }
}
