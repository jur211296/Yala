//
//  AIConnectorDraftTests.swift
//  YalaTests
//
//  Tu IA registra en Yala (2.3): de lo que Claude, ChatGPT o Grok apuntó por el conector al borrador de la Bandeja,
//  cuándo pregunta la app y el transporte. Llega por la cola COMÚN (`/mail/drafts`, decisión D9) con `source: "ai"`.
//  Lo que fija, por gravedad si se rompiera:
//   - «apunta 25 soles de almuerzo» con cuenta y subcategoría resueltas sale LISTO para guardar de un toque;
//   - una cuenta en otra divisa o una subcategoría del otro lado (ingreso para un gasto) no se ponen: la Bandeja las pide;
//   - en la misma vuelta que el correo y la web, cada uno sale con su origen;
//   - sin correo ni web, la app pregunta igual a la cola, como mucho cada 2 minutos;
//   - lo que otro aparato ya creó no se duplica.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

private func connectorDTO(
    id: String = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", kind: String = "expense", amount: Double = 25,
    currency: String? = "PEN", note: String? = "Almuerzo", date: String? = "2026-11-05",
    accountID: String? = nil, accountName: String? = nil, subcategoryID: String? = nil, subcategoryName: String? = nil,
    client: String? = "Claude", receivedAtMs: Double = 1_793_900_000_000, source: String? = "ai"
) -> BankEmailDraftDTO {
    // La forma exacta de la fila que deja el gateway (`commonQueuePayload` de `gateway/src/connector/store.ts`).
    let json: [String: Any?] = [
        "id": id, "received_at_ms": receivedAtMs, "kind": kind, "amount": amount, "currency": currency, "merchant": note,
        "date": date, "bank": nil, "account_last4": nil, "source": source, "account_ref": accountID,
        "account_name": accountName, "subcategory_ref": subcategoryID, "subcategory_name": subcategoryName, "client": client,
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

@Suite("Tu IA registra · de lo apuntado al borrador")
struct AIConnectorDraftLogicTests {

    @Test func gasto_vaNegativo_eIngreso_positivo_ySinTipoEsGasto() {
        #expect(AIConnectorDraftLogic.fields(from: connectorDTO(kind: "expense"), calendar: lima).amount == -25)
        #expect(AIConnectorDraftLogic.fields(from: connectorDTO(kind: "income", amount: 3000), calendar: lima).amount == 3000)
        #expect(AIConnectorDraftLogic.fields(from: connectorDTO(kind: "otro"), calendar: lima).isExpense)
    }

    @Test func laIA_esLaEvidencia_yLaFechaEsElDiaAMediodia() throws {
        let fields = AIConnectorDraftLogic.fields(from: connectorDTO(client: " ChatGPT "), calendar: lima)
        #expect(fields.evidence == "ChatGPT")
        #expect(lima.component(.hour, from: fields.date) == 12)
        #expect(lima.component(.day, from: fields.date) == 5)
        #expect(AIConnectorDraftLogic.fields(from: connectorDTO(client: nil), calendar: lima).evidence == nil)
    }

    @Test func losIdsSeLeen_yUnoMalFormado_seIgnora() {
        let ok = AIConnectorDraftLogic.fields(from: connectorDTO(accountID: "AAAAAAAA-0000-4000-8000-000000000001"), calendar: lima)
        #expect(ok.accountID?.uuidString == "AAAAAAAA-0000-4000-8000-000000000001")
        #expect(AIConnectorDraftLogic.fields(from: connectorDTO(accountID: "BCP"), calendar: lima).accountID == nil)
    }

    @Test func yaMaterializado_esElMismoInstanteImporteYNota() {
        let fields = AIConnectorDraftLogic.fields(from: connectorDTO(), calendar: lima)
        let at = Date(timeIntervalSince1970: 1_793_900_000)
        let same = AIConnectorDraftLogic.Existing(createdAt: at.addingTimeInterval(0.000_2), amount: -25, note: "Almuerzo")
        #expect(AIConnectorDraftLogic.alreadyMaterialized(receivedAt: at, fields: fields, among: [same]))
        let otherInstant = AIConnectorDraftLogic.Existing(createdAt: at.addingTimeInterval(1), amount: -25, note: "Almuerzo")
        let otherAmount = AIConnectorDraftLogic.Existing(createdAt: at, amount: -26, note: "Almuerzo")
        let otherNote = AIConnectorDraftLogic.Existing(createdAt: at, amount: -25, note: "Cena")
        #expect(!AIConnectorDraftLogic.alreadyMaterialized(receivedAt: at, fields: fields, among: [otherInstant, otherAmount, otherNote]))
    }

    @Test func sinCorreoNiWeb_preguntaIgual_peroComoMuchoCadaDosMinutos() {
        #expect(AIConnectorDraftLogic.pollInterval == 120)
        let now = Date(timeIntervalSince1970: 1_793_900_000)
        #expect(AIConnectorDraftLogic.isPollDue(lastPoll: nil, now: now))
        #expect(!AIConnectorDraftLogic.isPollDue(lastPoll: now.addingTimeInterval(-119), now: now))
        #expect(AIConnectorDraftLogic.isPollDue(lastPoll: now.addingTimeInterval(-120), now: now))
        // Un reloj que retrocede no deja la pregunta parada.
        #expect(AIConnectorDraftLogic.isPollDue(lastPoll: now.addingTimeInterval(3600), now: now))

        // La IA abre la puerta sola, sin correo ni web; el resto de condiciones se quedan.
        #expect(BankEmailDraftService.shouldSync(isSetUp: false, webConnected: false, aiPollDue: true, storageIsCloud: true, hasSession: true, wipeArmed: false, importQuiescent: true))
        #expect(!BankEmailDraftService.shouldSync(isSetUp: false, webConnected: false, aiPollDue: false, storageIsCloud: true, hasSession: true, wipeArmed: false, importQuiescent: true))
        #expect(!BankEmailDraftService.shouldSync(isSetUp: false, webConnected: false, aiPollDue: true, storageIsCloud: false, hasSession: true, wipeArmed: false, importQuiescent: true))
        #expect(!BankEmailDraftService.shouldSync(isSetUp: false, webConnected: false, aiPollDue: true, storageIsCloud: true, hasSession: false, wipeArmed: false, importQuiescent: true))
        #expect(!BankEmailDraftService.shouldSync(isSetUp: false, webConnected: false, aiPollDue: true, storageIsCloud: true, hasSession: true, wipeArmed: true, importQuiescent: true))
        #expect(!BankEmailDraftService.shouldSync(isSetUp: false, webConnected: false, aiPollDue: true, storageIsCloud: true, hasSession: true, wipeArmed: false, importQuiescent: false))
    }

    @Test func soloLoDeSourceAI_esDeLaIA() {
        #expect(AIConnectorDraftLogic.source == "ai")
        #expect(AIConnectorDraftLogic.isAI(source: "ai"))
        #expect(!AIConnectorDraftLogic.isAI(source: "web"))
        #expect(!AIConnectorDraftLogic.isAI(source: nil))
    }
}

// MARK: - Transporte

private final class ConnectorStubSession: SyncHTTPSession, @unchecked Sendable {
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

@Suite("Tu IA registra · transporte por la cola común", .serialized)
@MainActor
struct AIConnectorClientTests {
    private let base = URL(fileURLWithPath: "/") // nunca sale a la red: la sesión es un stub

    @Test func loDeLaIA_llegaPorMailDrafts_conTodosSusCampos() async throws {
        let session = ConnectorStubSession()
        session.body = Data("""
        {"drafts":[{"id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","received_at_ms":1793900000000,"kind":"expense","amount":25,
          "currency":"PEN","merchant":"Almuerzo","date":"2026-11-05","bank":null,"account_last4":null,"source":"ai",
          "account_ref":null,"subcategory_ref":null,"account_name":null,"subcategory_name":null,"client":"Claude"}]}
        """.utf8)
        let client = BankEmailClient(baseURL: base, tokenProvider: { "jwt" }, attestProvider: { "tok" }, urlSession: session)
        let drafts = try await client.drafts()
        #expect(drafts == [connectorDTO()])
        #expect(session.requests.last?.url?.path.hasSuffix("mail/drafts") == true)
        #expect(session.requests.last?.value(forHTTPHeaderField: "X-Yala-Attest-Session") == "Bearer tok")
    }
}

// MARK: - Bandeja

@Suite("Tu IA registra · borradores en la Bandeja", .serialized)
@MainActor
struct AIConnectorMaterializeTests {

    private struct World {
        let context: ModelContext
        let soles: Account
        let bbva: Account
        let dolares: Account
        let restaurantes: Subcategory
        let sueldo: Subcategory
    }

    private func world() throws -> World {
        let context = try makeTestContext()
        let soles = Account(name: "BCP Soles", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let bbva = Account(name: "BBVA", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let dolares = Account(name: "Interbank Dólares", currencyCode: "USD", colorHex: "#000", iconName: "creditcard", type: "bank")
        let comida = Category(name: "Comida", colorHex: "#000", isIncome: false)
        let ingresos = Category(name: "Ingresos", colorHex: "#000", isIncome: true)
        let restaurantes = Subcategory(name: "Restaurantes", category: comida)
        let sueldo = Subcategory(name: "Sueldo", category: ingresos)
        [soles, bbva, dolares].forEach { context.insert($0) }
        [comida, ingresos].forEach { context.insert($0) }
        [restaurantes, sueldo].forEach { context.insert($0) }
        try context.save()
        return World(context: context, soles: soles, bbva: bbva, dolares: dolares, restaurantes: restaurantes, sueldo: sueldo)
    }

    @Test func elAlmuerzoResuelto_saleListoParaGuardarDeUnToque() throws {
        let w = try world()
        let created = BankEmailDraftService.materialize([connectorDTO(
            accountID: w.soles.shortcutID.uuidString, accountName: "BCP Soles",
            subcategoryID: w.restaurantes.shortcutID.uuidString, subcategoryName: "Restaurantes"
        )], context: w.context)
        #expect(created == 1)
        let draft = try #require(try w.context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.sourceType == .aiConnector)
        #expect(draft.sourceDisplayName == L10n.Inbox.sourceAIConnector)
        #expect(draft.amount == -25)
        #expect(draft.note == "Almuerzo")
        #expect(draft.account?.shortcutID == w.soles.shortcutID)
        #expect(draft.subcategory?.shortcutID == w.restaurantes.shortcutID)
        #expect(draft.evidence == "Claude")
        #expect(draft.needsUserInput.isEmpty)
        #expect(draft.status == .pending)
        // «Aprobable con un toque»: el mismo criterio que deslizar para guardar en la Bandeja.
        #expect(InboxSaveReadyLogic.ready([draft]).count == 1)
    }

    @Test func sinIds_porNombre_ySinAmbiguedad() throws {
        let w = try world()
        _ = BankEmailDraftService.materialize([connectorDTO(accountName: "bbva", subcategoryName: "restaurantes")], context: w.context)
        let draft = try #require(try w.context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.account?.shortcutID == w.bbva.shortcutID)
        #expect(draft.subcategory?.shortcutID == w.restaurantes.shortcutID)
    }

    @Test func sinCuenta_ySinUnaUnicaEnSoles_laPide_enLaDivisaQueDijoLaIA() throws {
        let w = try world()
        _ = BankEmailDraftService.materialize([connectorDTO(currency: "PEN")], context: w.context)
        let draft = try #require(try w.context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.account == nil)
        #expect(draft.needsUserInput.contains(DraftInputRequirement.account))
        #expect(draft.needsUserInput.contains(DraftInputRequirement.subcategory))
        #expect(InboxSaveReadyLogic.ready([draft]).isEmpty)
        #expect(draft.displayCurrencyCode == "PEN")
    }

    @Test func enDolares_sinCuenta_vaALaUnicaEnDolares() throws {
        let w = try world()
        _ = BankEmailDraftService.materialize([connectorDTO(amount: 12.5, currency: "USD")], context: w.context)
        let draft = try #require(try w.context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.account?.shortcutID == w.dolares.shortcutID)
    }

    @Test func unaCuentaEnOtraDivisa_noSePone() throws {
        let w = try world()
        _ = BankEmailDraftService.materialize([connectorDTO(currency: "USD", accountID: w.soles.shortcutID.uuidString)], context: w.context)
        let draft = try #require(try w.context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.account == nil)
        #expect(draft.displayCurrencyCode == "USD")
    }

    @Test func unaSubcategoriaDeIngreso_noVaAUnGasto() throws {
        let w = try world()
        _ = BankEmailDraftService.materialize([connectorDTO(subcategoryID: w.sueldo.shortcutID.uuidString)], context: w.context)
        let gasto = try #require(try w.context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(gasto.subcategory == nil)
        try w.context.delete(model: InboxDraft.self)
        _ = BankEmailDraftService.materialize([connectorDTO(kind: "income", amount: 3000, subcategoryID: w.sueldo.shortcutID.uuidString)], context: w.context)
        let ingreso = try #require(try w.context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(ingreso.subcategory?.shortcutID == w.sueldo.shortcutID)
        #expect(ingreso.amount == 3000)
    }

    @Test func loQueCreoOtroAparato_yLlegoPorElSync_noSeDuplica() throws {
        let w = try world()
        let dto = connectorDTO(receivedAtMs: 1_793_900_000_123)
        // El iPhone lo creó y el `ack` no llegó: el iPad recibe por el sync su borrador y la cola se lo vuelve a dar.
        #expect(BankEmailDraftService.materialize([dto], context: w.context) == 1)
        let first = try #require(try w.context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(abs(first.createdAt.timeIntervalSince1970 - 1_793_900_000.123) < 0.000_5)
        #expect(BankEmailDraftService.materialize([dto], context: w.context) == 0)
        #expect(try w.context.fetch(FetchDescriptor<InboxDraft>()).count == 1)
        // Otro movimiento distinto que llegó en otro instante sí entra.
        #expect(BankEmailDraftService.materialize([connectorDTO(id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc", receivedAtMs: 1_793_900_060_000)], context: w.context) == 1)
    }

    @Test func unaCuentaArchivada_noSeElige() throws {
        let w = try world()
        w.soles.isArchived = true
        try w.context.save()
        _ = BankEmailDraftService.materialize([connectorDTO(accountID: w.soles.shortcutID.uuidString)], context: w.context)
        let draft = try #require(try w.context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.account == nil)
    }

    @Test func enLaMismaVuelta_queElCorreoYLaWeb_cadaUnoSaleConSuOrigen() throws {
        let w = try world()
        let banco = connectorDTO(id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd", client: nil, source: nil)
        let web = connectorDTO(id: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee", client: nil, source: "web")
        let ia = connectorDTO()
        #expect(BankEmailDraftService.materialize([banco, web, ia], context: w.context) == 3)
        let drafts = try w.context.fetch(FetchDescriptor<InboxDraft>())
        #expect(drafts.filter { $0.sourceType == .aiConnector }.count == 1)
        #expect(drafts.filter { $0.sourceType == .emailAlert }.count == 1)
        #expect(drafts.filter { $0.sourceType == .automation }.count == 1)
        #expect(drafts.first { $0.sourceType == .aiConnector }?.evidence == "Claude")
    }
}
