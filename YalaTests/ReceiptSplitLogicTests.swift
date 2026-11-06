//
//  ReceiptSplitLogicTests.swift
//  YalaTests
//
//  «Desde un recibo» de Grupos (card «Grupos: repartir un recibo con IA», 2.3): cuánto le toca a cada uno, los nombres
//  de la frase contra el grupo y la respuesta de la IA.
//

import Foundation
import Testing
@testable import Yala

@Suite("Repartir un recibo: la cuenta")
struct ReceiptSplitLogicTests {
    let me = "00000000-0000-0000-0000-000000000001"
    let ana = "00000000-0000-0000-0000-000000000002"
    let beto = "00000000-0000-0000-0000-000000000003"
    var ids: [String] { [me, ana, beto] }

    /// En céntimos: comparar `Double` sumados a mano con `==` falla por redondeo.
    private func amounts(_ lines: [ReceiptSplitLine]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: ReceiptSplitLogic.shares(lines, memberIDs: ids).map {
            ($0.memberID, ReceiptSplitLogic.cents($0.amount))
        })
    }

    /// El criterio del encargo: cinco líneas y una frase, repartido bien a la primera.
    @Test("cinco líneas de una cena: cada uno paga lo suyo y lo compartido a partes iguales")
    func fiveLineDinner() {
        let lines = [
            ReceiptSplitLine(description: "Lomo", amount: 38, kind: .item, assignees: [ana]),
            ReceiptSplitLine(description: "Ají", amount: 32, kind: .item, assignees: [beto]),
            ReceiptSplitLine(description: "Pizza", amount: 48, kind: .item, assignees: [me, ana]),
            ReceiptSplitLine(description: "Chicha", amount: 18, kind: .item),
            ReceiptSplitLine(description: "Cuy", amount: 28, kind: .item),
        ]
        let parts = amounts(lines)
        // Chicha y cuy, entre los tres: 46 / 3 = 15,34 + 15,33 + 15,33 (el céntimo, al primero del grupo).
        #expect(parts[me] == 3934)
        #expect(parts[ana] == 7733)
        #expect(parts[beto] == 4733)
        #expect(ReceiptSplitLogic.total(lines) == 164)
        #expect(parts.values.reduce(0, +) == 16400)
    }

    @Test("el céntimo que sobra va al primero y la suma es el total exacto")
    func remainderCents() {
        let lines = [ReceiptSplitLine(description: "Pan", amount: 10, kind: .item)]
        #expect(ReceiptSplitLogic.shares(lines, memberIDs: ids).map { ReceiptSplitLogic.cents($0.amount) } == [334, 333, 333])
    }

    @Test("sin nadie nombrado en ninguna línea, «entre todos» es el grupo entero")
    func nobodyNamedMeansWholeGroup() {
        let lines = [ReceiptSplitLine(description: "Pizza", amount: 30, kind: .item)]
        #expect(ReceiptSplitLogic.diners(lines, memberIDs: ids) == ids)
    }

    @Test("«entre todos» son los que comen: quien no aparece en ninguna línea no paga lo compartido")
    func everyoneMeansTheDiners() {
        let lines = [
            ReceiptSplitLine(description: "Lomo", amount: 20, kind: .item, assignees: [ana]),
            ReceiptSplitLine(description: "Pizza", amount: 30, kind: .item, assignees: [me]),
            ReceiptSplitLine(description: "Agua", amount: 10, kind: .item),
        ]
        let parts = amounts(lines)
        #expect(parts[beto] == nil)
        #expect(parts[me] == 3500)
        #expect(parts[ana] == 2500)
    }

    // MARK: Propina, servicio e impuestos (Jürgen, 2026-11-05: no se reparten solos)

    @Test("un servicio leído del recibo llega sin incluir: ni suma al total ni le toca a nadie")
    func extrasStartExcluded() {
        let lines = [
            ReceiptSplitLine(description: "Lomo", amount: 40, kind: .item, assignees: [ana]),
            ReceiptSplitLine(description: "Servicio", amount: 4, kind: .service),
        ]
        #expect(ReceiptSplitLogic.total(lines) == 40)
        #expect(amounts(lines) == [ana: 4000])
        #expect(ReceiptSplitLogic.readTotal(lines) == 44)
    }

    @Test("incluido según lo que consumió cada uno")
    func proportionalExtra() {
        let lines = [
            ReceiptSplitLine(description: "Lomo", amount: 30, kind: .item, assignees: [ana]),
            ReceiptSplitLine(description: "Sopa", amount: 10, kind: .item, assignees: [beto]),
            ReceiptSplitLine(description: "Propina", amount: 4, kind: .tip, extraShare: .proportional),
        ]
        let parts = amounts(lines)
        #expect(parts[ana] == 3300)
        #expect(parts[beto] == 1100)
        #expect(parts[me] == nil)
    }

    @Test("incluido a partes iguales entre los que comen")
    func equalExtra() {
        let lines = [
            ReceiptSplitLine(description: "Lomo", amount: 30, kind: .item, assignees: [ana]),
            ReceiptSplitLine(description: "Sopa", amount: 10, kind: .item, assignees: [beto]),
            ReceiptSplitLine(description: "Propina", amount: 4, kind: .tip, extraShare: .equal),
        ]
        #expect(amounts(lines) == [ana: 3200, beto: 1200])
    }

    @Test("solo para unas personas; sin ninguna elegida, fuera del gasto")
    func peopleExtra() {
        var tip = ReceiptSplitLine(description: "Propina", amount: 6, kind: .tip, extraShare: .people)
        let item = ReceiptSplitLine(description: "Lomo", amount: 30, kind: .item, assignees: [ana])
        #expect(!tip.isIncluded)
        #expect(ReceiptSplitLogic.total([item, tip]) == 30)
        tip.assignees = [me]
        #expect(amounts([item, tip]) == [me: 600, ana: 3000])
    }

    @Test("un descuento incluido resta en proporción")
    func discount() {
        let lines = [
            ReceiptSplitLine(description: "Lomo", amount: 30, kind: .item, assignees: [ana]),
            ReceiptSplitLine(description: "Sopa", amount: 10, kind: .item, assignees: [beto]),
            ReceiptSplitLine(description: "Promo", amount: 4, kind: .discount, extraShare: .proportional),
        ]
        #expect(amounts(lines) == [ana: 2700, beto: 900])
        #expect(ReceiptSplitLogic.total(lines) == 36)
    }

    @Test("el atajo de propina calcula sobre el consumo y lleva el reparto que se eligió")
    func surcharge() {
        let items = [ReceiptSplitLine(description: "Lomo", amount: 33.33, kind: .item)]
        let tip = ReceiptSplitLogic.surcharge(kind: .tip, percent: 10, description: "Propina 10 %", share: .equal, lines: items)
        #expect(tip.amount == 3.33)
        #expect(tip.extraShare == .equal)
        #expect(tip.isIncluded)
    }

    @Test("la plantilla del formulario: reparto exacto, el total y solo quien paga algo")
    func template() throws {
        let lines = [
            ReceiptSplitLine(description: "Lomo", amount: 38, kind: .item, assignees: [ana]),
            ReceiptSplitLine(description: "Pizza", amount: 20, kind: .item, assignees: [me]),
        ]
        let template = try #require(ReceiptSplitLogic.template(
            lines: lines, memberIDs: ids, currencyCode: "PEN", description: "Cena", date: .now
        ))
        #expect(template.splitType == .exact)
        #expect(template.totalAmount == 58)
        #expect(Set(template.participantIDs.map(\.uuidString)) == [me, ana])
        #expect(ReceiptSplitLogic.cents(template.values.values.reduce(0, +)) == 5800)
        #expect(template.description == "Cena")
    }

    @Test("un descuento que deja a alguien en negativo no da plantilla (el formulario no admite partes negativas)")
    func negativeShare() {
        let lines = [
            ReceiptSplitLine(description: "Sopa", amount: 10, kind: .item, assignees: [ana]),
            ReceiptSplitLine(description: "Lomo", amount: 40, kind: .item, assignees: [beto]),
            ReceiptSplitLine(description: "Promo", amount: 30, kind: .discount, extraShare: .equal),
        ]
        #expect(ReceiptSplitLogic.hasNegativeShare(lines, memberIDs: ids))
        #expect(ReceiptSplitLogic.template(lines: lines, memberIDs: ids, currencyCode: "PEN", description: "", date: .now) == nil)
    }

    @Test("sin nada que repartir, no hay plantilla")
    func emptyTemplate() {
        let lines = [ReceiptSplitLine(description: "Servicio", amount: 5, kind: .service)]
        #expect(ReceiptSplitLogic.template(lines: lines, memberIDs: ids, currencyCode: "PEN", description: "", date: .now) == nil)
    }
}

@Suite("Repartir un recibo: nombres y respuesta")
struct ReceiptPeopleMatcherTests {
    let members = [
        ReceiptPeopleMatcher.Member(id: "me", name: "Tú", isCurrentUser: true),
        ReceiptPeopleMatcher.Member(id: "ana", name: "Ana Torres", isCurrentUser: false),
        ReceiptPeopleMatcher.Member(id: "beto", name: "Beto", isCurrentUser: false),
        ReceiptPeopleMatcher.Member(id: "luis1", name: "Luis Pérez", isCurrentUser: false),
        ReceiptPeopleMatcher.Member(id: "luis2", name: "Luis Gómez", isCurrentUser: false),
    ]

    @Test("«yo» es quien usa la app; el nombre de pila basta; sin tildes ni mayúsculas")
    func basicMatching() {
        let result = ReceiptPeopleMatcher.resolve(["@me", "ana", "BETO"], members: members)
        #expect(result.memberIDs == ["me", "ana", "beto"])
        #expect(result.unmatched.isEmpty)
    }

    @Test("un nombre que no es del grupo, o que casa con dos, no elige a nadie y se avisa")
    func unmatched() {
        let result = ReceiptPeopleMatcher.resolve(["Carla", "Luis"], members: members)
        #expect(result.memberIDs.isEmpty)
        #expect(result.unmatched == ["Carla", "Luis"])
        #expect(ReceiptPeopleMatcher.resolve(["Luis Gómez"], members: members).memberIDs == ["luis2"])
    }

    @Test("«todos» deja la línea entre todos aunque nombre a alguien más")
    func allToken() {
        #expect(ReceiptPeopleMatcher.resolve(["Ana", "@all"], members: members).memberIDs.isEmpty)
    }

    @Test("la respuesta de la IA: extras sin incluir, nombres resueltos y avisos sin repetir")
    func draftFromResponse() {
        let response = ReceiptSplitResponse(merchant: "X", currency: "PEN", printedTotal: 50, lines: [
            .init(description: " Lomo ", amount: 30, kind: "item", people: ["Ana", "Carla"]),
            .init(description: "Postre", amount: 10, kind: "dessert?", people: ["Carla"]),
            .init(description: "Servicio", amount: -3, kind: "service", people: ["Ana"]),
        ])
        let draft = ReceiptSplitDraftLogic.draft(from: response, members: members)
        #expect(draft.lines.map(\.description) == ["Lomo", "Postre", "Servicio"])
        // «Ana y Carla»: Carla no es del grupo, así que la línea no se le carga entera a Ana; queda entre todos, marcada.
        #expect(draft.lines[0].assignees.isEmpty)
        #expect(draft.lines[0].needsReview)
        #expect(draft.lines[1].kind == .item)
        #expect(draft.lines[2].kind == .service)
        #expect(draft.lines[2].amount == 3)
        #expect(draft.lines[2].extraShare == .excluded)
        #expect(draft.lines[2].assignees.isEmpty)
        #expect(draft.unmatchedNames == ["Carla"])
    }

    @Test("un consumo en negativo es un descuento, y «yo» es el miembro resuelto")
    func negativeItemAndMe() {
        let response = ReceiptSplitResponse(merchant: nil, currency: nil, printedTotal: nil, lines: [
            .init(description: "Pizza", amount: 30, kind: "item", people: ["@me", "Ana"]),
            .init(description: "PROMO 2x1", amount: -12, kind: "item", people: []),
        ])
        let draft = ReceiptSplitDraftLogic.draft(from: response, members: members)
        #expect(draft.lines[0].assignees == ["me", "ana"])
        #expect(!draft.lines[0].needsReview)
        #expect(draft.lines[1].kind == .discount)
        #expect(draft.lines[1].amount == 12)
        #expect(draft.lines[1].extraShare == .excluded)
    }

    @Test("decodificar: sin líneas de consumo es «no encontré líneas»; JSON roto es respuesta inválida")
    func decode() throws {
        let ok = #"{"merchant":null,"currency":"PEN","printedTotal":null,"lines":[{"description":"Pan","amount":5,"kind":"item","people":[]},{"description":"x","amount":0,"kind":"item","people":[]}]}"#
        #expect(try ReceiptSplitService.decode(ok).lines.count == 1)
        let onlyTip = #"{"merchant":null,"currency":null,"printedTotal":null,"lines":[{"description":"Propina","amount":5,"kind":"tip","people":[]}]}"#
        #expect(throws: ReceiptSplitError.self) { try ReceiptSplitService.decode(onlyTip) }
        #expect(throws: ReceiptSplitError.self) { try ReceiptSplitService.decode("no es json") }
    }

    @Test("el esquema de la app es el del gateway: mismas claves obligatorias")
    func schemaMatchesTheGateway() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("gateway/src/ai/schemas.ts")
        let ts = try String(contentsOf: url, encoding: .utf8)
        let start = try #require(ts.range(of: "export const RECEIPT_SPLIT_SCHEMA"))
        let block = ts[start.upperBound...].prefix(1500)
        #expect(block.contains(#"required: ["merchant", "currency", "printedTotal", "lines"]"#))
        #expect(block.contains(#"required: ["description", "amount", "kind", "people"]"#))
        #expect(block.contains(#"enum: ["item", "tip", "tax", "service", "discount"]"#))
        #expect(Set(ReceiptLineKind.allCases.map(\.rawValue)) == ["item", "tip", "tax", "service", "discount"])
    }
}
