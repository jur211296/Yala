//
//  DividirBoletaRepartoTests.swift
//  YalaTests
//
//  «Dividir una boleta» sin grupo (maqueta 1A, 26-nov-2026): el reparto por igual y por líneas al céntimo, los extras,
//  quién pagó distinto de mí, el desglose que enseña la imagen «Con detalle» y el borrador de mi parte. La boleta es la
//  de la maqueta: Cevichería El Muelle, 7 líneas de consumo para Yo, Carla, Martín y Rocío, y la propina del 10 % aparte.
//

import Foundation
import Testing

@testable import Yala

@Suite("Dividir una boleta · reparto")
@MainActor
struct DividirBoletaRepartoTests {

    // MARK: - Fixture

    private static let response = ReceiptSplitResponse(
        merchant: "Cevichería El Muelle",
        currency: "PEN",
        printedTotal: 260.70,
        lines: [
            .init(description: "Ceviche clásico", amount: 42, kind: "item", people: ["@me"]),
            .init(description: "Lomo saltado", amount: 48, kind: "item", people: ["Martín"]),
            .init(description: "Ají de gallina", amount: 36, kind: "item", people: ["Carla"]),
            .init(description: "Arroz con mariscos", amount: 45, kind: "item", people: ["Rocío"]),
            .init(description: "Chicha morada 1 L", amount: 24, kind: "item", people: []),
            .init(description: "Gaseosa 500 ml ×2", amount: 14, kind: "item", people: ["Carla", "Martín"]),
            .init(description: "Leche de tigre para compartir", amount: 28, kind: "item", people: ["Rocío", "@me"]),
            .init(description: "Propina 10 %", amount: 23.70, kind: "tip", people: []),
        ]
    )

    /// La boleta leída con las cuatro personas escritas al vuelo.
    private func readModel() -> DividirBoletaModel {
        let model = DividirBoletaModel(meName: "Yo", currencyCode: "PEN")
        model.addPerson(named: "Carla")
        model.addPerson(named: "Martín")
        model.addPerson(named: "Rocío")
        model.apply(Self.response)
        return model
    }

    private func id(_ model: DividirBoletaModel, _ name: String) -> String {
        model.people.first { $0.name == name }?.id ?? ""
    }

    private func includeTipProportionally(_ model: DividirBoletaModel) {
        guard let tip = model.lines.first(where: { $0.kind == .tip }) else { return }
        model.setExtraShare(.proportional, for: tip.id)
    }

    // MARK: - Por líneas

    @Test("Por líneas: cada uno paga lo suyo, lo compartido a medias y la chicha entre los cuatro")
    func byLines_withoutTip() {
        let model = readModel()
        let shares = model.shareCents
        #expect(model.people.count == 4)
        #expect(model.unmatchedNames.isEmpty)
        #expect(shares[model.me?.id ?? ""] == 6_200)
        #expect(shares[id(model, "Carla")] == 4_900)
        #expect(shares[id(model, "Martín")] == 6_100)
        #expect(shares[id(model, "Rocío")] == 6_500)
        // La propina llega sin incluir (decisión del 5-nov): el total es el consumo.
        #expect(shares.values.reduce(0, +) == 23_700)
    }

    @Test("La propina según lo que consumió cada uno da las cifras de la maqueta y suma el total al céntimo")
    func byLines_tipProportional() {
        let model = readModel()
        includeTipProportionally(model)
        let shares = model.shareCents
        #expect(shares[model.me?.id ?? ""] == 6_820)
        #expect(shares[id(model, "Carla")] == 5_390)
        #expect(shares[id(model, "Martín")] == 6_710)
        #expect(shares[id(model, "Rocío")] == 7_150)
        #expect(shares.values.reduce(0, +) == 26_070)
    }

    // MARK: - Por igual

    @Test("Por igual: todo entre los cuatro, aunque la frase dijera quién comió qué")
    func equal_ignoresAssignees() {
        let model = readModel()
        model.mode = .equal
        let shares = model.shareCents
        #expect(Set(shares.values) == [5_925])
        #expect(shares.values.reduce(0, +) == 23_700)
    }

    @Test("Por igual con propina: el céntimo que sobra va a los primeros y la suma es exacta")
    func equal_withTip_centsGoToTheFirst() {
        let model = readModel()
        model.mode = .equal
        includeTipProportionally(model)
        let ordered = model.people.map { model.shareCents[$0.id] ?? 0 }
        #expect(ordered == [6_518, 6_518, 6_517, 6_517])
        #expect(ordered.reduce(0, +) == 26_070)
    }

    @Test("Por igual entre tres: 100,00 da 33,34 + 33,33 + 33,33")
    func equal_hundredAmongThree() {
        let people = [
            DividirBoletaPerson(name: "Yo", isMe: true),
            DividirBoletaPerson(name: "Ana"),
            DividirBoletaPerson(name: "Beto"),
        ]
        let lines = [ReceiptSplitLine(description: "Total", amount: 100, kind: .item)]
        let shares = DividirBoletaLogic.shareCents(lines, people: people, mode: .equal)
        #expect(people.map { shares[$0.id] ?? 0 } == [3_334, 3_333, 3_333])
    }

    @Test("Un extra «solo para» alguien se reparte entre esos y nada más")
    func extraForSomePeople() {
        let model = readModel()
        guard let tip = model.lines.first(where: { $0.kind == .tip }) else {
            Issue.record("Sin propina")
            return
        }
        model.toggleExtraPerson(id(model, "Carla"), in: tip.id)
        let shares = model.shareCents
        #expect(shares[id(model, "Carla")] == 4_900 + 2_370)
        #expect(shares[model.me?.id ?? ""] == 6_200)
    }

    // MARK: - Quién pagó

    @Test("Pagué yo: me deben el total menos mi parte, sin contarme a mí")
    func payerIsMe() throws {
        let model = readModel()
        includeTipProportionally(model)
        let summary = try #require(model.summary)
        #expect(summary.payerIsMe)
        #expect(summary.totalCents == 26_070)
        #expect(summary.owedToPayerCents == 26_070 - 6_820)
        #expect(summary.myShareCents == 6_820)
        #expect(summary.debts.map(\.personID) == [id(model, "Carla"), id(model, "Martín"), id(model, "Rocío")])
    }

    @Test("Pagó Carla: a Carla le deben los demás, yo incluido, y mi parte sigue siendo mi gasto")
    func payerIsSomeoneElse() throws {
        let model = readModel()
        includeTipProportionally(model)
        model.payerID = id(model, "Carla")
        let summary = try #require(model.summary)
        #expect(!summary.payerIsMe)
        #expect(summary.payerShareCents == 5_390)
        #expect(summary.owedToPayerCents == 26_070 - 5_390)
        #expect(summary.myShareCents == 6_820)
        #expect(summary.debts.map(\.personID) == [model.me?.id, id(model, "Martín"), id(model, "Rocío")])
        #expect(summary.debts.map(\.cents) == [6_820, 6_710, 7_150])
    }

    @Test("Quitar a quien pagó devuelve el pago a mí y lo saca de sus líneas")
    func removingThePayer() {
        let model = readModel()
        let carla = id(model, "Carla")
        model.payerID = carla
        model.removePerson(carla)
        #expect(model.payerID == model.me?.id)
        #expect(!model.lines.contains { $0.assignees.contains(carla) })
        #expect(model.shareCents.values.reduce(0, +) == 23_700)
    }

    @Test("Yo no me puedo quitar, y un nombre repetido (sin tildes ni mayúsculas) no entra")
    func peopleRules() {
        let model = readModel()
        model.removePerson(model.me?.id ?? "")
        #expect(model.people.count == 4)
        #expect(!model.addPerson(named: "martin"))
        #expect(!model.addPerson(named: "   "))
        #expect(model.addPerson(named: "  Ana   María "))
        #expect(model.people.last?.name == "Ana María")
    }

    @Test("Repartir con la boleta ya leída va a la revisión sin volver a leer")
    func splitAfterReadDoesNotReread() {
        let model = readModel()
        model.step = .who
        model.split()
        #expect(model.step == .review)
        #expect(model.readPhase == .read)
    }

    @Test("A mano: el total escrito se reparte por igual")
    func manualTotal() {
        let model = DividirBoletaModel(meName: "Yo", currencyCode: "PEN")
        model.addPerson(named: "Ana")
        model.useManualTotal(90.01)
        #expect(model.mode == .equal)
        #expect(model.step == .review)
        #expect(model.people.map { model.shareCents[$0.id] ?? 0 } == [4_501, 4_500])
    }

    // MARK: - Desglose

    @Test("El desglose por persona suma exactamente su parte, en los dos modos")
    func breakdownMatchesShares() {
        for mode in DividirBoletaMode.allCases {
            let model = readModel()
            includeTipProportionally(model)
            model.mode = mode
            let breakdown = DividirBoletaLogic.breakdown(model.lines, people: model.people, mode: mode)
            for person in model.people {
                let sum = (breakdown[person.id] ?? []).reduce(0) { $0 + $1.cents }
                #expect(sum == model.shareCents[person.id], "\(mode) \(person.name)")
            }
        }
    }

    // MARK: - Mi parte

    @Test("Mi parte va a la Bandeja como gasto, con el comercio y la moneda de la boleta")
    func myShareDraft() throws {
        let draft = try #require(DividirBoletaLogic.myShareDraft(
            myShareCents: 6_820, merchant: "Cevichería El Muelle", fallbackNote: "Boleta", currencyCode: "PEN",
            date: Date(timeIntervalSince1970: 1_800_000_000)))
        #expect(draft.amount == -68.20)
        #expect(draft.note == "Cevichería El Muelle")
        #expect(draft.sourceType == .receiptPhoto)
        #expect(draft.status == .pending)
        #expect(draft.account == nil)
        #expect(draft.cachedCurrencyCode == "PEN")
        #expect(DividirBoletaLogic.myShareDraft(
            myShareCents: 0, merchant: nil, fallbackNote: "Boleta", currencyCode: "PEN", date: .now) == nil)
    }
}
