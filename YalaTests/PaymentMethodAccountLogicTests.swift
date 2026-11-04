//
//  PaymentMethodAccountLogicTests.swift
//  YalaTests
//
//  Yala IA propone la cuenta que el usuario nombra como medio de pago («25 almuerzo yape») y no inventa ninguna si no la
//  nombra (card «Yala IA: detectar medio de pago», 2026-11-04). Frases reales de Perú y de los demás idiomas de la app.
//
//  `PaymentMethodAccountLogicTests` es lógica pura (sin SwiftData). La suite con contexto va aparte
//  (`PaymentMethodDraftTests.swift`): dos suites del mismo fichero comparten store (regla de `testing.md`).
//

import Foundation
import Testing

@testable import Yala

struct PaymentMethodAccountLogicTests {

    private typealias Logic = PaymentMethodAccountLogic

    private let yape = Logic.Candidate(id: UUID(), name: "Yape", kind: .bank)
    private let plin = Logic.Candidate(id: UUID(), name: "Plin Interbank", kind: .bank)
    private let bcp = Logic.Candidate(id: UUID(), name: "BCP Soles", kind: .bank)
    private let efectivo = Logic.Candidate(id: UUID(), name: "Billetera", kind: .cash)
    private let visa = Logic.Candidate(id: UUID(), name: "Visa BBVA", kind: .creditCard)
    private let todo = Logic.Candidate(id: UUID(), name: "Todo junto", kind: .other)

    private var peruvian: [Logic.Candidate] { [yape, plin, bcp, efectivo, visa] }

    /// La mención como la vería la app: el modelo contestó el campo y la palabra está en la frase.
    private func answered(_ hint: String?, in text: String, batch: Int = 1) -> String? {
        Logic.mention(hint: hint, hintAnswered: true, sourceText: text, batchCount: batch)
    }

    // MARK: - Frases de Perú, con el modelo

    @Test("«25 almuerzo yape» elige la cuenta Yape", arguments: [
        ("25 almuerzo yape", "yape"),
        ("25 almuerzo Yape", "Yape"),
        ("le yapeé 30 a mi pata por la pizza", "yapeé"),
        ("menú 15 con yape", "con yape"),
    ])
    func yapeFromPeru(_ text: String, _ hint: String) {
        #expect(Logic.account(for: answered(hint, in: text), among: peruvian) == yape.id)
    }

    @Test("«con plin», «plineé» eligen la cuenta que se llama Plin")
    func plinByName() {
        #expect(Logic.account(for: answered("plin", in: "pasaje 12 con plin"), among: peruvian) == plin.id)
        #expect(Logic.account(for: answered("plineé", in: "le plineé 20 a Rosa"), among: peruvian) == plin.id)
    }

    @Test("«en efectivo» elige la única cuenta de efectivo aunque no se llame así")
    func cashByKind() {
        #expect(Logic.account(for: answered("efectivo", in: "menú 15 en efectivo"), among: peruvian) == efectivo.id)
    }

    @Test("«con mi BCP» elige BCP Soles por su nombre")
    func bankByName() {
        #expect(Logic.account(for: answered("mi BCP", in: "gasté 60 en Plaza Vea con mi BCP"), among: peruvian) == bcp.id)
    }

    @Test("«con la de crédito» elige la única tarjeta de crédito")
    func creditByKind() {
        #expect(Logic.account(for: answered("crédito", in: "Wong 120 con la de crédito"), among: peruvian) == visa.id)
    }

    @Test("«con tarjeta» con dos cuentas con tarjeta no elige ninguna")
    func genericCardIsAmbiguousWithSeveral() {
        #expect(Logic.account(for: answered("tarjeta", in: "40 en Tottus con tarjeta"), among: peruvian) == nil)
    }

    @Test("«con tarjeta» con una sola cuenta con tarjeta la elige; la cuenta General no cuenta")
    func genericCardWithOne() {
        #expect(Logic.account(for: answered("tarjeta", in: "40 en Tottus con tarjeta"), among: [efectivo, bcp, todo]) == bcp.id)
    }

    // MARK: - Sin inventar

    @Test("Sin mención no hay cuenta, aunque el modelo devuelva algo que la frase no dice", arguments: [
        ("almuerzo en el chifa 22", nil as String?),
        ("almuerzo en el chifa 22", "yape"),
        ("taxi 15", "efectivo"),
    ])
    func neverInvents(_ text: String, _ hint: String?) {
        #expect(Logic.account(for: answered(hint, in: text), among: peruvian) == nil)
    }

    @Test("Una mención que casa con dos cuentas no elige ninguna (ni sigue a la clase)")
    func twoByNameIsNone() {
        let yapeBCP = Logic.Candidate(id: UUID(), name: "Yape BCP", kind: .bank)
        #expect(Logic.account(for: answered("yape", in: "25 almuerzo yape"), among: [yape, yapeBCP]) == nil)
    }

    @Test("Un medio de pago que el usuario no tiene como cuenta no elige ninguna")
    func unknownWallet() {
        #expect(Logic.account(for: answered("tunki", in: "15 de pasaje con tunki"), among: peruvian) == nil)
    }

    @Test("Las palabras de relleno solas no casan con nada («con la»)")
    func fillerOnly() {
        let la = Logic.Candidate(id: UUID(), name: "La cuenta", kind: .bank)
        #expect(Logic.account(for: answered("con la", in: "15 con la"), among: [la, efectivo]) == nil)
    }

    // MARK: - Varios movimientos

    @Test("Con el modelo, cada movimiento usa su mención")
    func perTransactionWithModel() {
        let text = "café 8 con yape y taxi 15 en efectivo"
        #expect(Logic.account(for: answered("yape", in: text, batch: 2), among: peruvian) == yape.id)
        #expect(Logic.account(for: answered("efectivo", in: text, batch: 2), among: peruvian) == efectivo.id)
        #expect(Logic.account(for: answered(nil, in: text, batch: 2), among: peruvian) == nil)
    }

    // MARK: - Sin el campo (gateway sin desplegar, Siri en el dispositivo)

    @Test("Sin el campo, un movimiento y una sola mención del léxico: se busca en la frase", arguments: [
        ("25 almuerzo yape", "yape"),
        ("menú 15 en efectivo", "efectivo"),
        ("Wong 120 con tarjeta de crédito", "tarjeta de credito"),
    ])
    func fallbackFindsTheMention(_ text: String, _ expected: String) {
        #expect(Logic.mention(hint: nil, hintAnswered: nil, sourceText: text, batchCount: 1) == expected)
    }

    @Test("Sin el campo, no se busca con varios movimientos, con dos menciones ni con palabras ambiguas")
    func fallbackStaysQuiet() {
        #expect(Logic.mention(hint: nil, hintAnswered: nil, sourceText: "café 8 y taxi 15 con yape", batchCount: 2) == nil)
        #expect(Logic.mention(hint: nil, hintAnswered: nil, sourceText: "25 con yape o efectivo", batchCount: 1) == nil)
        #expect(Logic.mention(hint: nil, hintAnswered: nil, sourceText: "una cerveza en el bar 12", batchCount: 1) == nil)
        #expect(Logic.mention(hint: nil, hintAnswered: nil, sourceText: "almuerzo 18", batchCount: 1) == nil)
    }

    @Test("Con el campo contestado a null no se busca en la frase: manda el modelo")
    func answeredNullWins() {
        #expect(Logic.mention(hint: nil, hintAnswered: true, sourceText: "25 almuerzo yape", batchCount: 1) == nil)
    }

    // MARK: - Los demás idiomas de la app

    @Test("Efectivo, en los idiomas de la app", arguments: [
        ("paid 40 cash for the taxi", "cash"),
        ("10 € beim Bäcker bar bezahlt", "bar"),
        ("45 € chez Carrefour en espèces", "espèces"),
        ("pagato 20 euro in contanti", "contanti"),
        ("pagámos 20 euros em dinheiro", "dinheiro"),
        ("12 euro contant betaald", "contant"),
        ("zapłaciłem gotówką 30 zł", "gotówką"),
        ("コンビニで500円、現金で", "現金"),
        ("现金付了20块打车", "现金"),
    ])
    func cashInEveryLanguage(_ text: String, _ hint: String) {
        #expect(Logic.account(for: answered(hint, in: text), among: peruvian) == efectivo.id)
    }

    @Test("Tarjeta de crédito, en los idiomas de la app", arguments: [
        ("groceries 85 on my credit card", "credit card"),
        ("Tanken 60 € mit Kreditkarte", "Kreditkarte"),
        ("Pagato con carta di credito 30 €", "carta di credito"),
        ("paguei no cartão de crédito 120", "cartão de crédito"),
        ("服を3000円、クレジットカードで", "クレジットカード"),
        ("信用卡付了200元", "信用卡"),
    ])
    func creditInEveryLanguage(_ text: String, _ hint: String) {
        #expect(Logic.account(for: answered(hint, in: text), among: peruvian) == visa.id)
    }

    @Test("Una cuenta con el nombre del medio, en otros idiomas: Pix, Bizum, 微信")
    func walletsByName() {
        let pix = Logic.Candidate(id: UUID(), name: "Pix Nubank", kind: .bank)
        let bizum = Logic.Candidate(id: UUID(), name: "Bizum", kind: .bank)
        let wechat = Logic.Candidate(id: UUID(), name: "微信", kind: .bank)
        let accounts = [pix, bizum, wechat, efectivo]
        #expect(Logic.account(for: answered("pix", in: "paguei 30 no pix pro almoço"), among: accounts) == pix.id)
        #expect(Logic.account(for: answered("Bizum", in: "15 a Laura por Bizum"), among: accounts) == bizum.id)
        #expect(Logic.account(for: answered("微信", in: "用微信支付了35元午饭"), among: accounts) == wechat.id)
    }

    @Test("Débito y «pin» van a la única cuenta bancaria")
    func debitGoesToTheBank() {
        let accounts = [efectivo, bcp, visa]
        #expect(Logic.account(for: answered("débito", in: "gastei 50 no débito no mercado"), among: accounts) == bcp.id)
        #expect(Logic.account(for: answered("gepind", in: "12 euro gepind bij Jumbo"), among: accounts) == bcp.id)
    }
}
