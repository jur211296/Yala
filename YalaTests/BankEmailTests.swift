//
//  BankEmailTests.swift
//  YalaTests
//
//  Correo del banco por reenvío (2.3): del movimiento que leyó el gateway al borrador de la Bandeja, la fila de Ajustes,
//  cuándo pregunta la app y el transporte contra `/mail/*`.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

private func dto(
    id: String = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", kind: String? = "expense", amount: Double = 45.9,
    currency: String? = "PEN", merchant: String? = "TAMBO SAN ISIDRO", date: String? = "2026-11-04",
    bank: String? = "BCP", last4: String? = "4321", receivedAtMs: Double = 1_793_800_000_000
) -> BankEmailDraftDTO {
    let json: [String: Any?] = [
        "id": id, "received_at_ms": receivedAtMs, "kind": kind, "amount": amount, "currency": currency,
        "merchant": merchant, "date": date, "bank": bank, "account_last4": last4,
    ]
    let clean = json.compactMapValues { $0 }
    // swiftlint:disable:next force_try
    let data = try! JSONSerialization.data(withJSONObject: clean)
    // swiftlint:disable:next force_try
    return try! JSONDecoder().decode(BankEmailDraftDTO.self, from: data)
}

private var lima: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
    return cal
}

@Suite("Correo del banco · del aviso al borrador")
struct BankEmailDraftLogicTests {

    @Test func gasto_vaNegativo_eIngreso_positivo() {
        #expect(BankEmailDraftLogic.fields(from: dto(kind: "expense", amount: 45.9), calendar: lima).amount == -45.9)
        #expect(BankEmailDraftLogic.fields(from: dto(kind: "income", amount: 1200), calendar: lima).amount == 1200)
        // Sin tipo, gasto: es lo que casi siempre es un aviso, y se cambia al revisar.
        #expect(BankEmailDraftLogic.fields(from: dto(kind: nil, amount: 10), calendar: lima).amount == -10)
    }

    @Test func laMencion_yLaEvidencia_salenDelBancoYLosDigitos() {
        let f = BankEmailDraftLogic.fields(from: dto(), calendar: lima)
        #expect(f.accountMention == "BCP 4321")
        #expect(f.evidence == "BCP · ****4321")
        #expect(f.note == "TAMBO SAN ISIDRO")
        let none = BankEmailDraftLogic.fields(from: dto(bank: nil, last4: nil), calendar: lima)
        #expect(none.accountMention == nil)
        #expect(none.evidence == nil)
    }

    @Test func laDivisa_seNormaliza_yUnaRara_seDescarta() {
        #expect(BankEmailDraftLogic.fields(from: dto(currency: "usd"), calendar: lima).currencyCode == "USD")
        #expect(BankEmailDraftLogic.fields(from: dto(currency: "soles"), calendar: lima).currencyCode == nil)
        #expect(BankEmailDraftLogic.fields(from: dto(currency: nil), calendar: lima).currencyCode == nil)
    }

    @Test func laFecha_esDelAvisoAMediodia() throws {
        let f = BankEmailDraftLogic.fields(from: dto(date: "2026-11-03"), calendar: lima)
        let parts = lima.dateComponents([.year, .month, .day, .hour], from: f.date)
        #expect(parts.year == 2026 && parts.month == 11 && parts.day == 3 && parts.hour == 12)
    }

    @Test func unaFechaFutura_oIlegible_caeALaDeLlegada() {
        let received = 1_793_800_000_000.0 // 2026-11-04
        let llegada = Date(timeIntervalSince1970: received / 1000)
        #expect(BankEmailDraftLogic.date(from: "2027-01-01", receivedAtMs: received, calendar: lima) == llegada)
        #expect(BankEmailDraftLogic.date(from: "4/11/2026", receivedAtMs: received, calendar: lima) == llegada)
        #expect(BankEmailDraftLogic.date(from: nil, receivedAtMs: received, calendar: lima) == llegada)
    }
}

@Suite("Correo del banco · cuándo sale y cuándo pregunta")
struct BankEmailGatesTests {

    @Test(arguments: [
        (true, true, false, true),
        (false, true, false, false),
        (true, false, false, false),
        (true, true, true, false),
    ])
    func laFilaDeAjustes(storageIsCloud: Bool, hasSession: Bool, groupsOnly: Bool, expected: Bool) {
        #expect(BankEmailEntryLogic.showsRow(storageIsCloud: storageIsCloud, hasSession: hasSession,
                                             isGroupsFocusedShell: groupsOnly) == expected)
    }

    @Test func soloPregunta_conTodoEnOrden() {
        #expect(BankEmailDraftService.shouldSync(isSetUp: true, storageIsCloud: true, hasSession: true, wipeArmed: false, importQuiescent: true))
        #expect(!BankEmailDraftService.shouldSync(isSetUp: false, storageIsCloud: true, hasSession: true, wipeArmed: false, importQuiescent: true))
        #expect(!BankEmailDraftService.shouldSync(isSetUp: true, storageIsCloud: false, hasSession: true, wipeArmed: false, importQuiescent: true))
        #expect(!BankEmailDraftService.shouldSync(isSetUp: true, storageIsCloud: true, hasSession: false, wipeArmed: false, importQuiescent: true))
        #expect(!BankEmailDraftService.shouldSync(isSetUp: true, storageIsCloud: true, hasSession: true, wipeArmed: true, importQuiescent: true))
        #expect(!BankEmailDraftService.shouldSync(isSetUp: true, storageIsCloud: true, hasSession: true, wipeArmed: false, importQuiescent: false))
    }

    @Test func idsCreados_noSeDuplican_yGuardanLosUltimos() {
        let defaults = makeIsolatedDefaults(prefix: "bankEmailIDs")
        BankEmailCreatedIDsStore.add(["a", "b"], defaults: defaults)
        BankEmailCreatedIDsStore.add(["b", "c"], defaults: defaults)
        #expect(defaults.stringArray(forKey: BankEmailCreatedIDsStore.key) == ["a", "b", "c"])
        BankEmailCreatedIDsStore.add((0..<250).map(String.init), defaults: defaults)
        #expect(defaults.stringArray(forKey: BankEmailCreatedIDsStore.key)?.count == BankEmailCreatedIDsStore.limit)
        #expect(!BankEmailCreatedIDsStore.contains("a", defaults: defaults))
        #expect(BankEmailCreatedIDsStore.contains("249", defaults: defaults))
    }
}

@Suite("Correo del banco · la línea del cupo")
struct BankEmailCopyTests {
    private func info(pro: Bool, used: Int, skipped: Int = 0) throws -> BankEmailAddressInfo {
        let json = """
        {"address":"auto+abcdefghjk@yala-app.pe","pro":\(pro),"trial_limit":5,"trial_used":\(used),
         "skipped_quota":\(skipped),"last_received_at_ms":null,"gmail_confirmation":null}
        """
        return try JSONDecoder().decode(BankEmailAddressInfo.self, from: Data(json.utf8))
    }

    @Test func pro_trialEnCurso_yAgotado() throws {
        #expect(BankEmailCopy.quotaLine(try info(pro: true, used: 5)) == L10n.BankEmail.proLine)
        #expect(BankEmailCopy.quotaLine(try info(pro: false, used: 2)) == L10n.BankEmail.trialUsed(2, 5))
        #expect(BankEmailCopy.quotaLine(try info(pro: false, used: 5)) == L10n.BankEmail.trialExhausted)
        #expect(BankEmailCopy.quotaLine(try info(pro: false, used: 5, skipped: 3))
                == L10n.BankEmail.trialExhausted + " " + L10n.BankEmail.skipped(3))
    }
}

// MARK: - Transporte

private final class MailStubSession: SyncHTTPSession, @unchecked Sendable {
    var status = 200
    var body = Data("{}".utf8)
    private(set) var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badURL)
        }
        return (body, response)
    }
}

@Suite("Correo del banco · transporte", .serialized)
@MainActor
struct BankEmailClientTests {
    private let base = URL(fileURLWithPath: "/") // nunca sale a la red: la sesión es un stub

    @Test func attestVivo_viajaEnLaCabecera_yNil_noViaja() async throws {
        let session = MailStubSession()
        session.body = Data(#"{"drafts":[]}"#.utf8)
        let con = BankEmailClient(baseURL: base, tokenProvider: { "jwt" }, attestProvider: { "tok" }, urlSession: session)
        _ = try await con.drafts()
        #expect(session.requests.last?.value(forHTTPHeaderField: "X-Yala-Attest-Session") == "Bearer tok")
        let sin = BankEmailClient(baseURL: base, tokenProvider: { "jwt" }, attestProvider: { nil }, urlSession: session)
        _ = try await sin.drafts()
        #expect(session.requests.last?.value(forHTTPHeaderField: "X-Yala-Attest-Session") == nil)
        #expect(session.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt")
    }

    @Test func sinSesion_noManda_nada() async {
        let session = MailStubSession()
        let client = BankEmailClient(baseURL: base, tokenProvider: { nil }, urlSession: session)
        await #expect(throws: BankEmailClientError.sessionExpired) { _ = try await client.address() }
        #expect(session.requests.isEmpty)
    }

    @Test func el401DeAttest_esPasajero_yElOtro_sesionCaducada() async {
        let session = MailStubSession()
        session.status = 401
        session.body = Data(#"{"error":{"type":"yala_attest_required","code":"yala_attest_required","message":"x"}}"#.utf8)
        let client = BankEmailClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        await #expect(throws: BankEmailClientError.attestRequired) { _ = try await client.drafts() }
        session.body = Data(#"{"error":{"type":"yala_attest_invalid","code":"yala_attest_invalid","message":"x"}}"#.utf8)
        await #expect(throws: BankEmailClientError.sessionExpired) { _ = try await client.drafts() }
    }

    @Test func leeLaDireccion_yElCodigoDeGmail() async throws {
        let session = MailStubSession()
        session.body = Data("""
        {"address":"auto+abcdefghjk@yala-app.pe","pro":false,"trial_limit":5,"trial_used":1,"skipped_quota":0,
         "last_received_at_ms":1793800000000,"gmail_confirmation":{"code":"123456789","received_at_ms":1793800000000}}
        """.utf8)
        let client = BankEmailClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        let info = try await client.address()
        #expect(info.address == "auto+abcdefghjk@yala-app.pe")
        #expect(info.gmailConfirmation?.code == "123456789")
        #expect(session.requests.last?.httpMethod == "POST")
        #expect(session.requests.last?.url?.path.hasSuffix("mail/address") == true)
    }

    @Test func ack_mandaLosIds() async throws {
        let session = MailStubSession()
        let client = BankEmailClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        try await client.ack(ids: ["x", "y"])
        let body = try #require(session.requests.last?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: [String]])
        #expect(json["ids"] == ["x", "y"])
        try await client.ack(ids: [])
        #expect(session.requests.count == 1) // sin ids no hay petición
    }
}

// MARK: - Bandeja

@Suite("Correo del banco · borradores en la Bandeja", .serialized)
@MainActor
struct BankEmailMaterializeTests {

    @Test func unAvisoEnDolares_vaALaCuentaEnDolares() throws {
        let context = try makeTestContext()
        let soles = Account(name: "Ahorros", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let dolares = Account(name: "Cuenta dólares", currencyCode: "USD", colorHex: "#000", iconName: "creditcard", type: "bank")
        context.insert(soles)
        context.insert(dolares)
        try context.save()

        let created = BankEmailDraftService.materialize([dto(currency: "USD", bank: nil, last4: nil)], context: context)
        #expect(created == 1)
        let drafts = try context.fetch(FetchDescriptor<InboxDraft>())
        let draft = try #require(drafts.first)
        #expect(draft.sourceType == .emailAlert)
        #expect(draft.account?.currencyCode == "USD")
        #expect(draft.amount == -45.9)
        #expect(draft.status == .pending)
    }

    @Test func sinCuentaEnEsaDivisa_laPide_yEnseniaLaDivisaDelAviso() throws {
        let context = try makeTestContext()
        context.insert(Account(name: "Ahorros", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank"))
        try context.save()

        _ = BankEmailDraftService.materialize([dto(currency: "USD", bank: nil, last4: nil)], context: context)
        let draft = try #require(try context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.account == nil)
        #expect(draft.needsUserInput.contains(DraftInputRequirement.account))
        // Un aviso en dólares no puede salir en soles en la Bandeja.
        #expect(draft.displayCurrencyCode == "USD")
        // Y no guarda nada del correo: solo banco y dígitos como evidencia.
        #expect(draft.rawText == nil)
    }

    @Test func elBancoQueNombraElAviso_eligeLaCuenta() throws {
        let context = try makeTestContext()
        context.insert(Account(name: "Interbank", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank"))
        context.insert(Account(name: "BCP", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank"))
        try context.save()

        _ = BankEmailDraftService.materialize([dto(currency: "PEN", bank: "BCP", last4: nil)], context: context)
        let draft = try #require(try context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.account?.name == "BCP")
    }
}
