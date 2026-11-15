//
//  BankEmailClient.swift
//  Yala
//
//  Cliente HTTP del correo del banco por reenvío (2.3) contra el gateway (`gateway/src/mail/routes.ts`):
//    - `POST /mail/address`     → la dirección `auto+<código>@yalainbox.com`, el cupo de prueba y el código de Gmail.
//    - `GET  /mail/drafts`      → los movimientos que el gateway leyó de los avisos reenviados.
//    - `POST /mail/drafts/ack`  → la app ya los creó en la Bandeja: el gateway los borra.
//
//  Las tres rutas pasan por `requireUserAndAttest` (`gateway/src/mail/routes.ts`, que reusa la guard de
//  `groups/routes.ts`): producción pasa `AttestSessionProvider.live`; el default `{ nil }` es solo para tests
//  (`AttestWiringTests` cuenta la construcción). Sin logging de datos: logs bajo `#if DEBUG`.
//

import Foundation

enum BankEmailClientError: Error, Equatable {
    /// 401 que no es de attest, o sin token de sesión (no se manda nada).
    case sessionExpired
    /// 401 `yala_attest_required`: sesión buena, attest ausente. Pasajero.
    case attestRequired
    /// 4xx (≠ 401). `-2` = el cuerpo no serializó.
    case serverRejected(status: Int)
    /// 5xx, transporte o respuesta ilegible. `-1` = sin respuesta HTTP.
    case transient(status: Int)
}

/// Lo que devuelve `POST /mail/address`.
struct BankEmailAddressInfo: Decodable, Equatable, Sendable {
    struct GmailConfirmation: Decodable, Equatable, Sendable {
        let code: String
        let receivedAtMs: Double

        enum CodingKeys: String, CodingKey {
            case code
            case receivedAtMs = "received_at_ms"
        }
    }

    let address: String
    let pro: Bool
    let trialLimit: Int
    let trialUsed: Int
    let skippedQuota: Int
    let lastReceivedAtMs: Double?
    let gmailConfirmation: GmailConfirmation?

    enum CodingKeys: String, CodingKey {
        case address, pro
        case trialLimit = "trial_limit"
        case trialUsed = "trial_used"
        case skippedQuota = "skipped_quota"
        case lastReceivedAtMs = "last_received_at_ms"
        case gmailConfirmation = "gmail_confirmation"
    }
}

/// Un movimiento leído de un aviso reenviado (`GET /mail/drafts`).
struct BankEmailDraftDTO: Decodable, Equatable, Sendable {
    let id: String
    let receivedAtMs: Double
    let kind: String?
    let amount: Double
    let currency: String?
    let merchant: String?
    let date: String?
    let bank: String?
    let accountLast4: String?
    /// Yala web (lote 1): `"web"` en lo apuntado desde el navegador, que entra por esta misma cola (`WebDraftLogic`).
    /// Con la cuenta y la subcategoría elegidas, por su id de la nube (`shortcutID`). El correo no los manda.
    var source: String? = nil
    var accountRef: String? = nil
    var subcategoryRef: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, kind, amount, currency, merchant, date, bank, source
        case receivedAtMs = "received_at_ms"
        case accountLast4 = "account_last4"
        case accountRef = "account_ref"
        case subcategoryRef = "subcategory_ref"
    }
}

@MainActor
final class BankEmailClient {
    private let baseURL: URL
    private let tokenProvider: @MainActor () async -> String?
    private let attestProvider: @MainActor () async -> String?
    private let urlSession: SyncHTTPSession

    /// El default `{ nil }` de `attestProvider` es **SOLO PARA TESTS**: las tres rutas exigen attest
    /// (`gateway/src/mail/routes.ts`, `requireUserAndAttest`). Producción pasa `AttestSessionProvider.live`.
    init(
        baseURL: URL = ProxyConfig.baseURL,
        tokenProvider: @escaping @MainActor () async -> String? = { await CloudAuthService.shared.accessToken() },
        attestProvider: @escaping @MainActor () async -> String? = { nil },
        urlSession: SyncHTTPSession = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.attestProvider = attestProvider
        self.urlSession = urlSession
    }

    func address() async throws -> BankEmailAddressInfo {
        let data = try await send(method: "POST", path: "mail/address", body: [:])
        return try decode(BankEmailAddressInfo.self, from: data)
    }

    func drafts() async throws -> [BankEmailDraftDTO] {
        struct Envelope: Decodable { let drafts: [BankEmailDraftDTO] }
        let data = try await send(method: "GET", path: "mail/drafts", body: nil)
        return try decode(Envelope.self, from: data).drafts
    }

    func ack(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        _ = try await send(method: "POST", path: "mail/drafts/ack", body: ["ids": ids])
    }

    // MARK: - Red

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            #if DEBUG
            print("BankEmailClient: Error: \(error)")
            #endif
            throw BankEmailClientError.transient(status: -1)
        }
    }

    private func send(method: String, path: String, body: [String: Any]?) async throws -> Data {
        guard let token = await tokenProvider(), !token.isEmpty else { throw BankEmailClientError.sessionExpired }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let attest = await attestProvider(), !attest.isEmpty {
            request.setValue("Bearer \(attest)", forHTTPHeaderField: "X-Yala-Attest-Session")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            } catch {
                #if DEBUG
                print("BankEmailClient: Error: \(error)")
                #endif
                throw BankEmailClientError.serverRejected(status: -2)
            }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw BankEmailClientError.transient(status: -1)
        }
        guard let http = response as? HTTPURLResponse else { throw BankEmailClientError.transient(status: -1) }
        switch http.statusCode {
        case 200...299:
            return data
        case 401 where GatewayErrorEnvelope.isAttestRequired(data):
            AttestSessionProvider.reportRejected(sentIn: request)
            throw BankEmailClientError.attestRequired
        case 401:
            throw BankEmailClientError.sessionExpired
        case 400...499:
            throw BankEmailClientError.serverRejected(status: http.statusCode)
        default:
            throw BankEmailClientError.transient(status: http.statusCode)
        }
    }
}
