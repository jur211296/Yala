//
//  GmailBankAlertImporter.swift
//  Yala
//
//  «Conectar Gmail», fase 1 (encargo 2026-10-23). SOLO `DEV_BUILD`: existe para grabar el video que pide Google al
//  verificar el permiso `gmail.readonly` del proyecto `yala-502622`, no es la función final.
//
//  Qué hace: pide el permiso con el inicio de sesión real de Google (GoogleSignIn-iOS, client ID del build), busca en
//  Gmail los avisos de movimiento del banco (`BankAlertEmailParser.knownSenders`), lee los más recientes y deja cada
//  uno nuevo como borrador en la Bandeja (origen `.emailAlert`).
//
//  Qué NO hace, a propósito:
//  - No guarda el token: lo custodia el SDK de Google en el llavero, como el del inicio de sesión de la nube.
//  - No manda el correo a ningún servidor ni a ninguna IA: se lee en el teléfono.
//  - No lee nada fuera de la búsqueda por remitente, y del cuerpo solo guarda un extracto corto en el borrador.
//
//  La versión final va por el servidor y exige cuenta en la nube (docs/ROADMAP.md, 2.3 «Correo del banco»).
//

#if DEV_BUILD
import Foundation
import GoogleSignIn
import SwiftData
import UIKit

@MainActor
enum GmailBankAlertImporter {

    static let gmailReadonlyScope = "https://www.googleapis.com/auth/gmail.readonly"

    /// Cuántos avisos se leen por toque. Pocos a propósito: es una demostración y cada uno es una petición.
    static let maxMessages = 5

    /// Marca del mensaje en `InboxDraft.evidence`, para no duplicar el borrador si se vuelve a tocar.
    static func evidenceMarker(messageID: String) -> String { "gmail:\(messageID)" }

    struct Summary: Equatable {
        let email: String?
        let found: Int
        let created: Int
        let alreadyInInbox: Int
    }

    enum ImportError: LocalizedError {
        case noPresenter
        case scopeNotGranted
        case gmail(status: Int)

        var errorDescription: String? {
            switch self {
            case .noPresenter:
                return "No se pudo abrir la pantalla de Google."
            case .scopeNotGranted:
                return "Google no dio permiso para leer Gmail. Vuelve a intentarlo y marca la casilla de Gmail."
            case .gmail(let status):
                return "Gmail no respondió (código \(status))."
            }
        }
    }

    // MARK: - Estado

    /// Correo de la cuenta de Google que ya dio el permiso en este dispositivo, o `nil`.
    static var connectedEmail: String? {
        guard let user = GIDSignIn.sharedInstance.currentUser,
              user.grantedScopes?.contains(gmailReadonlyScope) == true else { return nil }
        return user.profile?.email
    }

    /// Recupera la sesión del SDK guardada en el llavero, para saber si el permiso ya estaba dado.
    static func restoreIfPossible() async {
        guard GIDSignIn.sharedInstance.currentUser == nil, GIDSignIn.sharedInstance.hasPreviousSignIn() else { return }
        do {
            _ = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
        } catch {
            #if DEBUG
            print("GmailBankAlertImporter: Error: \(error)")
            #endif
        }
    }

    // MARK: - Conectar y leer

    /// Abre la pantalla de Google pidiendo `gmail.readonly`, lee los avisos del banco y crea los borradores.
    /// Lanza `CloudAuthError.cancelled` si la persona cierra la pantalla de Google.
    static func connectAndImport(context: ModelContext, draftService: DraftService) async throws -> Summary {
        guard let presenter = topPresentingViewController() else { throw ImportError.noPresenter }

        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenter,
                hint: nil,
                additionalScopes: [gmailReadonlyScope]
            )
        } catch {
            if CloudAuthService.isGoogleCancellation(error) { throw CloudAuthError.cancelled }
            throw error
        }

        // Con el consentimiento granular de Google la persona puede desmarcar Gmail y aceptar el resto.
        guard result.user.grantedScopes?.contains(gmailReadonlyScope) == true else {
            throw ImportError.scopeNotGranted
        }
        let user = try await result.user.refreshTokensIfNeeded()
        let token = user.accessToken.tokenString

        let ids = try await listMessageIDs(token: token)
        var created = 0
        var already = 0
        for id in ids {
            if try draftExists(marker: evidenceMarker(messageID: id), context: context) {
                already += 1
                continue
            }
            let message = try await fetchMessage(id: id, token: token)
            let draft = makeDraft(from: message, context: context)
            try draftService.createDraft(draft)
            created += 1
        }
        return Summary(email: user.profile?.email, found: ids.count, created: created, alreadyInInbox: already)
    }

    /// Quita el permiso en Google (revoca el acceso de esta app para esa cuenta). Sirve para repetir la toma del video.
    static func disconnect() async throws {
        try await GIDSignIn.sharedInstance.disconnect()
    }

    // MARK: - Gmail API

    private static let apiBase = "https://gmail.googleapis.com/gmail/v1/users/me"

    static var searchQuery: String {
        let senders = BankAlertEmailParser.knownSenders.map { "from:\($0)" }.joined(separator: " OR ")
        return "(\(senders)) newer_than:180d"
    }

    private struct ListResponse: Decodable {
        struct Ref: Decodable { let id: String }
        let messages: [Ref]?
    }

    struct Message: Decodable {
        struct Header: Decodable { let name: String; let value: String }
        struct Body: Decodable { let data: String? }
        struct Part: Decodable {
            let mimeType: String?
            let headers: [Header]?
            let body: Body?
            let parts: [Part]?
        }
        let id: String
        let internalDate: String?
        let snippet: String?
        let payload: Part?
    }

    private static func listMessageIDs(token: String) async throws -> [String] {
        var components = URLComponents(string: "\(apiBase)/messages")
        components?.queryItems = [
            URLQueryItem(name: "q", value: searchQuery),
            URLQueryItem(name: "maxResults", value: String(maxMessages))
        ]
        guard let url = components?.url else { return [] }
        let response: ListResponse = try await get(url, token: token)
        return response.messages?.map(\.id) ?? []
    }

    private static func fetchMessage(id: String, token: String) async throws -> Message {
        guard let url = URL(string: "\(apiBase)/messages/\(id)?format=full") else { throw ImportError.gmail(status: 0) }
        return try await get(url, token: token)
    }

    private static func get<T: Decodable>(_ url: URL, token: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw ImportError.gmail(status: status) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Mensaje → borrador

    private static func draftExists(marker: String, context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<InboxDraft>(predicate: #Predicate<InboxDraft> { $0.evidence == marker })
        return try context.fetchCount(descriptor) > 0
    }

    static func makeDraft(from message: Message, context: ModelContext) -> InboxDraft {
        let subject = header("Subject", in: message.payload) ?? ""
        let body = bodyText(of: message.payload) ?? message.snippet ?? ""
        let parsed = BankAlertEmailParser.parse(subject: subject, body: body)
        let date = message.internalDate.flatMap(Double.init).map { Date(timeIntervalSince1970: $0 / 1000) }
        let note = parsed.merchant ?? subject
        let isExpense = (parsed.amount ?? -1) < 0

        let account = parsed.currencyCode.flatMap { DraftBuilder.findAccount(byCurrency: $0, context: context) }
        let subcategory = DraftBuilder.suggestSubcategory(merchant: note, isExpense: isExpense, context: context)
        let draft = InboxDraft(
            note: note,
            amount: parsed.amount,
            date: date,
            subcategory: subcategory,
            sourceType: .emailAlert,
            rawText: String(body.prefix(500)),
            evidence: evidenceMarker(messageID: message.id),
            needsUserInput: DraftBuilder.computeNeedsUserInput(
                hasAmount: parsed.amount != nil,
                hasAccount: account != nil,
                hasSubcategory: subcategory != nil
            )
        )
        if let account { draft.account = account }
        return draft
    }

    private static func header(_ name: String, in part: Message.Part?) -> String? {
        part?.headers?.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    /// El texto del correo: `text/plain` si lo hay; si no, `text/html` pasado a texto.
    static func bodyText(of part: Message.Part?) -> String? {
        if let plain = firstBody(of: part, mimeType: "text/plain") { return plain }
        return firstBody(of: part, mimeType: "text/html").map(BankAlertEmailParser.plainText(fromHTML:))
    }

    private static func firstBody(of part: Message.Part?, mimeType: String) -> String? {
        guard let part else { return nil }
        if part.mimeType == mimeType, let data = part.body?.data, let text = decodeBase64URL(data) { return text }
        for child in part.parts ?? [] {
            if let text = firstBody(of: child, mimeType: mimeType) { return text }
        }
        return nil
    }

    static func decodeBase64URL(_ value: String) -> String? {
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: padding)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }

    // MARK: - Presentación

    /// El controlador de arriba del todo de la ventana activa (molde de `CloudAuthService`).
    private static func topPresentingViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.flatMap(\.windows).first
        guard var top = window?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
#endif
