//
//  CuentaSolaAlLeerDraftTests.swift
//  YalaTests
//
//  La cuenta sola al leer, con cuentas de verdad (SwiftData): la foto (`VisionDraftFactory`), Apple Pay con la tarjeta de
//  Wallet y el aviso del banco con «****4417». Apple Pay y los avisos no pasan por la IA ni por la red: eligen su cuenta
//  sin conexión. La lógica pura va en `CuentaSolaAlLeerEscaleraTests`.
//
//  La cola de Apple Pay y la de avisos van aisladas por suite; la última cuenta usada del App Group real la aísla
//  `.lastUsedAccountIsolated`, como en `ApplePayDraftServiceTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized, .lastUsedAccountIsolated)
@MainActor
struct CuentaSolaAlLeerDraftTests {

    private let pendingDefaults: UserDefaults

    init() {
        pendingDefaults = testDefaults(suiteName: "test.cuentasola.pending.\(UUID().uuidString)")!
        iCloudSyncService.shared._testReset()
    }

    private func account(
        _ context: ModelContext, _ name: String, type: AccountType = .checking, currency: String = "PEN",
        number: String? = nil
    ) -> Account {
        let account = Account(
            name: name, currencyCode: currency, colorHex: "#6366F1", iconName: "creditcard.fill", type: type.rawValue,
            accountNumber: number)
        context.insert(account)
        return account
    }

    /// La semilla `ficha`: tres cuentas en soles y una en dólares.
    private func ficha(_ context: ModelContext) throws -> (principal: Account, efectivo: Account, tarjeta: Account) {
        let principal = account(context, "Cuenta Principal")
        let efectivo = account(context, "Efectivo", type: .cash)
        let tarjeta = account(context, "Tarjeta de crédito", type: .creditCard)
        _ = account(context, "Ahorros USD", type: .savings, currency: "USD")
        try context.save()
        return (principal, efectivo, tarjeta)
    }

    private func photo(payment: String?, account: String? = nil, currency: String? = "PEN") -> VisionResponse {
        VisionResponse(
            imageType: "single",
            transactions: [VisionTransaction(
                amount: -25.9, date: "2026-11-20", merchant: "Tambo", note: nil, currency: currency,
                payment: payment, account: account)],
            confidence: VisionConfidence(overall: 0.9, imageType: 0.9))
    }

    // MARK: - Foto

    @Test("Foto con «Tarjeta de crédito»: sale con esa cuenta, sin pedirla, y la elección dice «por el nombre»")
    func fotoEligeTarjeta() throws {
        let context = try makeTestContext()
        let cuentas = try ficha(context)
        let made = VisionDraftFactory.makeDraftsWithAccountChoice(
            from: photo(payment: "Tarjeta de crédito"), rawText: nil, context: context)
        let item = try #require(made.first)
        #expect(item.draft.account?.shortcutID == cuentas.tarjeta.shortcutID)
        #expect(!item.draft.needsUserInput.contains(DraftInputRequirement.account))
        #expect(item.eleccion.resultado == .sola(cuentas.tarjeta.shortcutID, .nombre))
    }

    @Test("Foto sin medio de pago (gateway sin el campo): como antes, por moneda o sin cuenta")
    func fotoSinCampoComoAntes() throws {
        let context = try makeTestContext()
        _ = try ficha(context)
        let made = VisionDraftFactory.makeDraftsWithAccountChoice(from: photo(payment: nil), rawText: nil, context: context)
        let item = try #require(made.first)
        // Tres cuentas en soles: la moneda no decide, igual que hoy.
        #expect(item.draft.account == nil)
        #expect(item.draft.needsUserInput.contains(DraftInputRequirement.account))
        #expect(item.eleccion.resultado == .ninguna)

        let usd = VisionDraftFactory.makeDraftsWithAccountChoice(
            from: photo(payment: nil, currency: "USD"), rawText: nil, context: context)
        #expect(usd.first?.draft.account?.name == "Ahorros USD")
        #expect(usd.first?.eleccion.resultado == .ninguna, "por moneda no lleva estrella")
    }

    @Test("Foto con «Visa» y dos cuentas Visa: sin cuenta y con las dos que coinciden")
    func fotoDosVisa() throws {
        let context = try makeTestContext()
        let bcp = account(context, "BCP Visa", type: .creditCard)
        let ibk = account(context, "Interbank Visa", type: .creditCard)
        try context.save()
        let item = try #require(VisionDraftFactory.makeDraftsWithAccountChoice(
            from: photo(payment: "Visa"), rawText: nil, context: context).first)
        #expect(item.draft.account == nil)
        guard case .varias(let ids) = item.eleccion.resultado else {
            Issue.record("esperaba varias, salió \(item.eleccion.resultado)")
            return
        }
        #expect(Set(ids) == [bcp.shortcutID, ibk.shortcutID])
    }

    @Test("Foto con «Visa» y la IA proponiendo «Interbank Visa»: sugerida y preseleccionada")
    func fotoSugerida() throws {
        let context = try makeTestContext()
        _ = account(context, "BCP Visa", type: .creditCard)
        let ibk = account(context, "Interbank Visa", type: .creditCard)
        try context.save()
        let item = try #require(VisionDraftFactory.makeDraftsWithAccountChoice(
            from: photo(payment: "Visa", account: "Interbank Visa"), rawText: nil, context: context).first)
        #expect(item.draft.account?.shortcutID == ibk.shortcutID)
        #expect(item.eleccion.resultado == .sugerida(ibk.shortcutID))
    }

    @Test("Foto con la IA nombrando una cuenta que no existe: se ignora")
    func fotoIAInventa() throws {
        let context = try makeTestContext()
        let cuentas = try ficha(context)
        let item = try #require(VisionDraftFactory.makeDraftsWithAccountChoice(
            from: photo(payment: "Tarjeta de crédito", account: "Diners Club"), rawText: nil, context: context).first)
        #expect(item.draft.account?.shortcutID == cuentas.tarjeta.shortcutID)
        #expect(item.eleccion.resultado == .sola(cuentas.tarjeta.shortcutID, .nombre))
    }

    @Test("Foto donde la imagen y la IA discrepan: sin cuenta, y el resultado guarda las dos")
    func fotoChoque() throws {
        let context = try makeTestContext()
        let cuentas = try ficha(context)
        let item = try #require(VisionDraftFactory.makeDraftsWithAccountChoice(
            from: photo(payment: "Tarjeta de crédito · Cuenta Principal", account: "Cuenta Principal"),
            rawText: nil, context: context).first)
        #expect(item.draft.account == nil)
        #expect(item.eleccion.resultado == .choque(telefono: cuentas.tarjeta.shortcutID, ia: cuentas.principal.shortcutID))
        #expect(CuentaSolaAlLeerSelectorPista.pista(for: item.eleccion)?.filas.count == 2)
    }

    @Test("Una cuenta elegida por el nombre en otra moneda no se fuerza: sigue la regla por moneda")
    func fotoOtraMoneda() throws {
        let context = try makeTestContext()
        _ = try ficha(context)
        let item = try #require(VisionDraftFactory.makeDraftsWithAccountChoice(
            from: photo(payment: "Tarjeta de crédito", currency: "USD"), rawText: nil, context: context).first)
        #expect(item.draft.account?.name == "Ahorros USD")
        #expect(item.eleccion.resultado == .ninguna)
    }

    // MARK: - Apple Pay, sin conexión

    @Test("Apple Pay con la tarjeta «Interbank Visa» va a esa cuenta")
    func applePayConTarjeta() throws {
        let context = try makeTestContext()
        _ = account(context, "BCP Visa", type: .creditCard)
        let ibk = account(context, "Interbank Visa", type: .creditCard)
        try context.save()
        ApplePayPendingStore.append(
            ApplePayPendingExpense(rawAmount: "S/ 25,90", merchant: "Tambo", savedAt: 1_800_000_000, card: "Interbank Visa"),
            defaults: pendingDefaults)

        #expect(ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true) == 1)
        let draft = try #require(try context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.account?.shortcutID == ibk.shortcutID)
    }

    @Test("Apple Pay sin tarjeta (atajo viejo) y con una que no casa: la regla de siempre")
    func applePaySinTarjeta() throws {
        let context = try makeTestContext()
        _ = account(context, "BCP Visa", type: .creditCard)
        _ = account(context, "Interbank Visa", type: .creditCard)
        try context.save()
        ApplePayPendingStore.append(
            ApplePayPendingExpense(rawAmount: "S/ 10", merchant: "A", savedAt: 1_800_000_000), defaults: pendingDefaults)
        ApplePayPendingStore.append(
            ApplePayPendingExpense(rawAmount: "S/ 11", merchant: "B", savedAt: 1_800_000_001, card: "Diners"),
            defaults: pendingDefaults)
        #expect(ApplePayDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true) == 2)
        #expect(try context.fetch(FetchDescriptor<InboxDraft>()).allSatisfy { $0.account == nil })
    }

    @Test("Un pago encolado por un atajo viejo (sin el campo) se sigue leyendo")
    func applePayColaVieja() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","rawAmount":"$5","merchant":"X","savedAt":1}"#
        let expense = try JSONDecoder().decode(ApplePayPendingExpense.self, from: Data(json.utf8))
        #expect(expense.card == nil)
        #expect(expense.rawAmount == "$5")
    }

    // MARK: - Aviso del banco, sin conexión

    @Test("Un aviso con «****4417» va a la cuenta cuyo número acaba en 4417, aunque haya otra del mismo banco")
    func avisoUltimos4() throws {
        let context = try makeTestContext()
        _ = account(context, "BCP Soles")
        let visa = account(context, "Visa BCP", type: .creditCard, number: "4557-8800-1234-4417")
        try context.save()
        let text = "Consumo con tu tarjeta\nRealizaste un consumo de S/ 12.50 con tu Tarjeta de Débito BCP ****4417 en TAMBO+ MIRAFLORES."
        let reading = BankNoticeParser.read(text, bankHint: .bcp) ?? .notUnderstood
        guard case .movement(let movement, _) = reading else {
            Issue.record("el aviso de prueba no se leyó como movimiento")
            return
        }
        #expect(movement.cardLast4 == "4417")
        BankNoticePendingStore.append(
            BankNoticePendingEntry(rawText: text, bank: .bcp, reading: reading, receivedAt: 1_800_000_000),
            defaults: pendingDefaults)

        #expect(BankNoticeDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true) == 1)
        let draft = try #require(try context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.account?.shortcutID == visa.shortcutID)
    }

    // MARK: - Correo, voz, Siri y chat (por `findAccount(paymentMention:)`)

    @Test("Los últimos 4 del correo eligen la cuenta aunque el banco tenga dos")
    func correoUltimos4() throws {
        let context = try makeTestContext()
        _ = account(context, "BCP Soles")
        let visa = account(context, "BCP Visa", type: .creditCard, number: "4417")
        try context.save()
        let accounts = DraftBuilder.fetchActiveAccounts(context: context)
        #expect(DraftBuilder.findAccount(paymentMention: "BCP 4417", last4: "4417", dictatedCurrency: "PEN", in: accounts)?
            .shortcutID == visa.shortcutID)
        // Sin los dígitos, «BCP» casa con las dos y no elige.
        #expect(DraftBuilder.findAccount(paymentMention: "BCP", dictatedCurrency: "PEN", in: accounts) == nil)
    }

    @Test("Con dos que casan, la moneda dicha desempata si solo una la tiene")
    func monedaDesempata() throws {
        let context = try makeTestContext()
        let soles = account(context, "BCP Soles")
        _ = account(context, "BCP Dólares", currency: "USD")
        try context.save()
        let accounts = DraftBuilder.fetchActiveAccounts(context: context)
        #expect(DraftBuilder.findAccount(paymentMention: "BCP", dictatedCurrency: "PEN", in: accounts)?.shortcutID == soles.shortcutID)
    }
}
