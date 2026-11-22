//
//  ComercioFotoCategoriaTests.swift
//  YalaTests
//
//  Captura por foto: la IA reconoce el comercio y Yala lo propone con su categoría y su cuenta (decisión 75, encargo del
//  22-nov). La IA devuelve `merchantKind` de una lista cerrada; el teléfono lo traduce a una subcategoría del usuario.
//  Los casos de prueba son vouchers y recibos reales de Perú (Starbucks, Wong, Carrefour, Tambo+, Inkafarma, Primax),
//  con la respuesta del modelo escrita a mano: lo que se prueba aquí es lo que hace Yala con ella.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Foto · el comercio propone su categoría y su cuenta", .serialized)
@MainActor
struct ComercioFotoCategoriaTests {

    // MARK: - La palabra de la IA

    @Test("La palabra se lee con mayúsculas, espacios o guiones; una inventada no elige nada")
    func parse_toleratesFormatting_andRejectsUnknownWords() {
        #expect(VisionMerchantKind.parse("supermarket") == .supermarket)
        #expect(VisionMerchantKind.parse(" Personal care ") == .personalCare)
        #expect(VisionMerchantKind.parse("public-transport") == .publicTransport)
        #expect(VisionMerchantKind.parse("PHONE_INTERNET") == .phoneInternet)
        #expect(VisionMerchantKind.parse("coffee") == nil)
        #expect(VisionMerchantKind.parse("") == nil)
        #expect(VisionMerchantKind.parse(nil) == nil)
    }

    @Test("La lista del prompt es la del enum, en su orden")
    func promptList_isTheEnumInOrder() {
        #expect(VisionMerchantKind.promptList == VisionMerchantKind.allCases.map(\.rawValue).joined(separator: ", "))
        #expect(VisionMerchantKind.promptList.hasPrefix("supermarket, restaurant, "))
    }

    @Test("El prompt de la foto pide el tipo y el nombre comercial, y no lleva ninguna categoría del usuario")
    func systemPrompt_asksForTheKind_withoutUserCategories() {
        let prompt = ImageVisionService.shared.systemPrompt(currency: .unknown)
        #expect(prompt.contains("- MerchantKind:"))
        #expect(prompt.contains(VisionMerchantKind.promptList))
        #expect(prompt.contains("known trade name"))
        #expect(prompt.contains("\"merchantKind\": \"restaurant\""))
        #expect(!prompt.lowercased().contains("subcategor"))
    }

    @Test("Una respuesta sin el campo, o con algo que no es texto, se lee igual que antes")
    func decoding_isLenient() throws {
        let without = #"{"amount": -12.5, "date": null, "merchant": "Wong", "note": null, "currency": "PEN"}"#
        let wrongType = #"{"amount": -12.5, "date": null, "merchant": "Wong", "note": null, "currency": "PEN", "merchantKind": 7}"#
        let with = #"{"amount": -12.5, "date": null, "merchant": "Wong", "note": null, "currency": "PEN", "merchantKind": "supermarket"}"#
        let decode = { (json: String) throws -> VisionTransaction in
            try JSONDecoder().decode(VisionTransaction.self, from: Data(json.utf8))
        }
        #expect(try decode(without).merchantKind == nil)
        #expect(try decode(wrongType).merchantKind == nil)
        #expect(try decode(wrongType).amount == -12.5)
        #expect(try decode(with).merchantKind == "supermarket")
    }

    // MARK: - Del tipo a la subcategoría (puro)

    private typealias Candidate = MerchantKindSubcategory.Candidate

    @Test("Por nombre de la semilla en el idioma de la app; sin nombre, por el icono; dos que empatan no eligen")
    func match_byNameThenIcon_andTiesDoNotChoose() {
        let target = MerchantKindSubcategory.Target(name: "Supermercados", icon: "basket.fill")
        let byName = [Candidate(name: "Restaurantes", icon: "fork.knife", isExpense: true),
                      Candidate(name: "supermercados", icon: "cart.fill", isExpense: true)]
        #expect(MerchantKindSubcategory.match(target: target, isExpense: true, in: byName) == 1)

        // Renombrada a «Mercado»: decide el icono de la semilla.
        let renamed = [Candidate(name: "Mercado", icon: "basket.fill", isExpense: true),
                       Candidate(name: "Restaurantes", icon: "fork.knife", isExpense: true)]
        #expect(MerchantKindSubcategory.match(target: target, isExpense: true, in: renamed) == 0)

        // Dos con el mismo icono y ninguna con el nombre: mejor pedirla.
        let tie = [Candidate(name: "Mercado", icon: "basket.fill", isExpense: true),
                   Candidate(name: "Bodega", icon: "basket.fill", isExpense: true)]
        #expect(MerchantKindSubcategory.match(target: target, isExpense: true, in: tie) == nil)

        // Una de ingreso con el mismo nombre no cuenta para un gasto.
        let income = [Candidate(name: "Supermercados", icon: "basket.fill", isExpense: false)]
        #expect(MerchantKindSubcategory.match(target: target, isExpense: true, in: income) == nil)
    }

    @Test("Cada tipo apunta a una subcategoría que la semilla de verdad tiene, con su icono")
    func targets_existInTheSeed() throws {
        let source = try String(contentsOfFile: Self.repoFile("Yala/Seed/CategorySeed.swift"), encoding: .utf8)
        for kind in VisionMerchantKind.allCases {
            let target = MerchantKindSubcategory.target(for: kind)
            #expect(source.contains("iconName: \"\(target.icon)\""), "\(kind): \(target.icon) no está en la semilla")
            #expect(!target.name.isEmpty)
        }
    }

    @Test("El banco de comercios del teléfono solo responde con lo que no deja duda")
    func catalogFallback_onlyUnambiguousCategories() {
        #expect(MerchantKindSubcategory.resolvedKind(aiKind: nil, merchant: "TAMBO+ MIRAFLORES") == .supermarket)
        #expect(MerchantKindSubcategory.resolvedKind(aiKind: nil, merchant: "Starbucks") == .restaurant)
        #expect(MerchantKindSubcategory.resolvedKind(aiKind: nil, merchant: "Netflix") == .streaming)
        // «health» junta clínicas, farmacias y apps: sin la IA no se decide.
        #expect(MerchantKindSubcategory.resolvedKind(aiKind: nil, merchant: "Inkafarma") == nil)
        #expect(MerchantKindSubcategory.resolvedKind(aiKind: nil, merchant: "Bodega Don Lucho") == nil)
        // La IA manda sobre el banco.
        #expect(MerchantKindSubcategory.resolvedKind(aiKind: .pharmacy, merchant: "Inkafarma") == .pharmacy)
    }

    // MARK: - De la foto al borrador

    /// Las subcategorías de la semilla que estos casos usan, con su nombre en el idioma de la app y su icono.
    @discardableResult
    private func seedSubcategories(_ context: ModelContext) -> [VisionMerchantKind: Subcategory] {
        let expense = makeTestCategory(context: context, name: "Gastos")
        var made: [VisionMerchantKind: Subcategory] = [:]
        for kind in [VisionMerchantKind.supermarket, .restaurant, .pharmacy, .fuel, .rideshare] {
            let target = MerchantKindSubcategory.target(for: kind)
            let sub = makeTestSubcategory(context: context, name: target.name, category: expense)
            sub.iconName = target.icon
            made[kind] = sub
        }
        return made
    }

    private func response(_ items: [(merchant: String, kind: String?, payment: String?)]) -> VisionResponse {
        VisionResponse(
            imageType: "receipt",
            transactions: items.map { item in
                var tx = VisionTransaction(amount: -25.0, date: "2026-11-21", merchant: item.merchant, note: nil, currency: "PEN")
                tx.merchantKind = item.kind
                tx.payment = item.payment
                return tx
            },
            confidence: VisionConfidence(overall: 0.9, imageType: 0.9))
    }

    @Test("Vouchers y recibos reales: el comercio que lee la IA llega con su categoría, sin historial")
    func receipts_proposeMerchantAndCategory_withoutHistory() throws {
        let context = try makeTestContext()
        let subs = seedSubcategories(context)
        let cases: [(merchant: String, kind: String?, expected: VisionMerchantKind)] = [
            ("Starbucks", "restaurant", .restaurant),
            ("Wong", "supermarket", .supermarket),
            ("Carrefour", "supermarket", .supermarket),
            ("Inkafarma", "pharmacy", .pharmacy),
            ("Primax", "fuel", .fuel),
            ("Uber", "rideshare", .rideshare),
            // Sin la IA (gateway sin desplegar), el banco de comercios del teléfono.
            ("TAMBO+ MIRAFLORES", nil, .supermarket),
        ]
        let drafts = VisionDraftFactory.makeDrafts(
            from: response(cases.map { ($0.merchant, $0.kind, nil) }), rawText: nil, context: context)
        #expect(drafts.count == cases.count)
        for (draft, item) in zip(drafts, cases) {
            // La nota es el comercio que leyó la IA, limpio como siempre («TAMBO+ MIRAFLORES» → «Tambo+ Miraflores»).
            #expect(draft.note == VisionNoteCleaner.note(merchant: item.merchant, note: nil), "comercio de \(item.merchant)")
            #expect(draft.evidence == item.merchant)
            #expect(draft.subcategory === subs[item.expected], "categoría de \(item.merchant)")
            #expect(!draft.needsUserInput.contains(DraftInputRequirement.subcategory), "\(item.merchant) no pide categoría")
        }
    }

    @Test("Un tipo que no está en la lista o sin subcategoría que lo tenga deja la categoría por elegir")
    func unknownKindOrMissingSubcategory_leavesItToChoose() throws {
        let context = try makeTestContext()
        seedSubcategories(context)
        let drafts = VisionDraftFactory.makeDrafts(
            from: response([("Bodega Don Lucho", "corner_store", nil), ("Clínica San Felipe", "health", nil)]),
            rawText: nil, context: context)
        #expect(drafts.allSatisfy { $0.subcategory == nil })
        #expect(drafts.allSatisfy { $0.needsUserInput.contains(DraftInputRequirement.subcategory) })
    }

    @Test("Lo que recuerda la persona manda sobre lo que dice la IA")
    func merchantMemory_winsOverTheAI() throws {
        let context = try makeTestContext()
        let subs = seedSubcategories(context)
        let remembered = try #require(subs[.supermarket])
        context.insert(MerchantMemory(
            merchantCanonical: MerchantCanonicalizer.canonicalize("Starbucks"), subcategory: remembered,
            countApproved: 5, countCorrected: 0, lastApprovedAt: Date.now, aliases: ["Starbucks"]))
        let draft = try #require(VisionDraftFactory.makeDrafts(
            from: response([("Starbucks", "restaurant", nil)]), rawText: nil, context: context).first)
        #expect(draft.subcategory === remembered)
    }

    @Test("El voucher que dice «Tarjeta de crédito BCP» se va a esa cuenta, con el comercio y la categoría")
    func voucherWithTheCardName_choosesTheAccount() throws {
        let context = try makeTestContext()
        let subs = seedSubcategories(context)
        let bcp = makeTestAccount(context: context, name: "Tarjeta de crédito BCP", currencyCode: "PEN")
        _ = makeTestAccount(context: context, name: "Débito Interbank", currencyCode: "PEN")
        let draft = try #require(VisionDraftFactory.makeDrafts(
            from: response([("Wong", "supermarket", "Tarjeta de crédito BCP")]), rawText: nil, context: context).first)
        #expect(draft.account === bcp)
        #expect(draft.subcategory === subs[.supermarket])
        #expect(draft.note == "Wong")
    }

    // MARK: - Ayudas

    static func repoFile(_ relative: String, filePath: String = #filePath) -> String {
        var url = URL(fileURLWithPath: filePath)
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Yala.xcodeproj").path) { break }
        }
        return url.appendingPathComponent(relative).path
    }
}
