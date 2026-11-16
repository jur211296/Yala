//
//  ReceiptSplitService.swift
//  Yala
//
//  Lee un recibo para repartirlo en un grupo (card «Grupos: repartir un recibo con IA», 2.3): las líneas y, por
//  línea, los NOMBRES tal como la persona los escribió o dijo en la frase. El miembro lo elige la app
//  (`ReceiptPeopleMatcher`): la lista del grupo no sale del teléfono.
//
//  Dos tareas del gateway con la misma respuesta: `receipt.photo` (foto + frase opcional, gasta foto) y
//  `receipt.voice` (la nota ya transcrita, va con la nota y no gasta otra). Modelo, esfuerzo y JSON estricto los
//  decide la fila del gateway (`gateway/src/ai/routes.ts`); `RECEIPT_SPLIT_SCHEMA` en `schemas.ts` es este DTO.
//

import UIKit
import OpenAI

// MARK: - Respuesta

nonisolated struct ReceiptSplitResponse: Codable, Equatable, Sendable {
    struct Line: Codable, Equatable, Sendable {
        let description: String
        let amount: Double
        /// `item`, `tip`, `tax`, `service` o `discount`. Uno desconocido se lee como consumo.
        let kind: String
        /// Los nombres de la frase («Ana»), `@me` para quien habla y `@all` para «todos». Vacío si la frase no dice.
        let people: [String]
    }

    let merchant: String?
    let currency: String?
    let printedTotal: Double?
    let lines: [Line]
}

nonisolated enum ReceiptSplitError: Error {
    case imageEncodingFailed
    case emptyNote
    case invalidResponse
    /// El modelo no encontró líneas con importe.
    case noLines
    /// El error del camino al gateway tal cual: la vista lo lee con `ProxyErrorMapper` (prueba agotada, ráfaga, día).
    case network(Error)
}

// MARK: - Servicio

@MainActor
final class ReceiptSplitService {

    static let shared = ReceiptSplitService()

    // MARK: Prompt

    func systemPrompt(currency: VisionCurrencyContext) -> String {
        """
        You split a restaurant or shop receipt among friends. You get the receipt (a photo, or a dictated note that \
        lists what was ordered) and, optionally, a sentence saying who had what.

        Return every line of the receipt:
        - description: the item as printed or said, short. Keep its language. Include the quantity if it is printed \
        ("2 Pisco sour").
        - amount: the LINE TOTAL as a positive number (quantity × unit price), never negative, no currency symbol.
        - kind: "item" for food, drinks and products; "tip" for tip or propina; "service" for service charge or \
        cubierto; "tax" for taxes printed APART from the items (IGV, VAT, IVA, sales tax); "discount" for discounts \
        and promotions (amount positive). Do NOT add a tax line when the tax is already included in the item prices \
        (a receipt that only says "includes IGV" has no tax line). Never return the subtotal or the total as a line.
        - people: who pays this line, copying the names EXACTLY as written or said in the sentence ("Ana", "Luis"). \
        Use "@me" for the speaker ("yo", "me", "mine", "I", "eu", "ich"…). Use "@all" when the sentence says everyone \
        shares it ("todos", "entre todos", "everyone"). Several names = shared by them. Empty when the sentence says \
        nothing about that line. Never invent a name that is not in the sentence. Tip, service, tax and discount \
        lines always have people empty.

        merchant: the place as printed, or null. printedTotal: the total printed on the receipt, or null.
        currency: an ISO 4217 code from symbols or words, or null. "S/" → "PEN", "€" → "EUR", "US$" → "USD", \
        "R$" → "BRL", "$" alone → \(currency.dollarRule).
        \(currency.userCurrencies)

        If the image or the note is not a receipt or has no amounts, return lines empty.

        Respond ONLY with valid JSON:
        {"merchant": "La Lucha", "currency": "PEN", "printedTotal": 91.0, "lines": [
          {"description": "Pizza familiar", "amount": 40.0, "kind": "item", "people": ["Luis", "@me"]},
          {"description": "Lomo saltado", "amount": 35.0, "kind": "item", "people": ["Ana"]},
          {"description": "2 Chicha morada", "amount": 16.0, "kind": "item", "people": []}
        ]}
        """
    }

    // MARK: Lecturas

    /// La foto del recibo y, si la hay, la frase de quién comió qué. Tarea `receipt.photo`: gasta foto.
    func readPhoto(image: UIImage, phrase: String, currency: VisionCurrencyContext) async throws -> ReceiptSplitResponse {
        let client: OpenAI
        do {
            client = try await ProxyClientFactory.makeOpenAI(task: .receiptPhoto)
        } catch {
            throw ReceiptSplitError.network(error)
        }
        let maxEdge = PhotoUploadSizing.maxEdge(remote: CloudRemoteConfigStore.readSnapshot()?.photoMaxEdge)
        guard let imageData = ImageVisionService.uploadJPEG(image, maxEdge: maxEdge) else {
            throw ReceiptSplitError.imageEncodingFailed
        }
        let textPart = ChatQuery.ChatCompletionMessageParam.ContentPartTextParam(text: Self.userText(phrase: phrase))
        let imagePart = ChatQuery.ChatCompletionMessageParam.ContentPartImageParam(
            imageUrl: .init(imageData: imageData, detail: .auto)
        )
        let query = ChatQuery(
            messages: [
                .system(.init(content: .textContent(systemPrompt(currency: currency)))),
                .user(.init(content: .contentParts([.text(textPart), .image(imagePart)])))
            ],
            model: .gpt4_1_mini,
            responseFormat: .jsonObject
        )
        return try await send(query, with: client)
    }

    /// La nota ya transcrita: lo que se pidió y quién comió qué. Tarea `receipt.voice`: va con la nota que abrió la
    /// transcripción y no gasta otra.
    func readNote(text: String, currency: VisionCurrencyContext) async throws -> ReceiptSplitResponse {
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { throw ReceiptSplitError.emptyNote }
        let client: OpenAI
        do {
            client = try await ProxyClientFactory.makeOpenAI(task: .receiptVoice)
        } catch {
            throw ReceiptSplitError.network(error)
        }
        let query = ChatQuery(
            messages: [
                .system(.init(content: .textContent(systemPrompt(currency: currency)))),
                .user(.init(content: .string("Dictated note:\n\(note)")))
            ],
            model: .gpt4_1_mini,
            responseFormat: .jsonObject
        )
        return try await send(query, with: client)
    }

    // MARK: Privado

    static func userText(phrase: String) -> String {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
            ? "Split this receipt. Nobody said who had what."
            : "Split this receipt. Who had what: \(trimmed)"
    }

    private func send(_ query: ChatQuery, with client: OpenAI) async throws -> ReceiptSplitResponse {
        let content: String
        do {
            let result = try await client.chats(query: query)
            guard let text = result.choices.first?.message.content, !text.isEmpty else {
                throw ReceiptSplitError.invalidResponse
            }
            content = text
        } catch let error as ReceiptSplitError {
            throw error
        } catch {
            throw ReceiptSplitError.network(error)
        }
        return try Self.decode(content)
    }

    /// Decodifica la respuesta y descarta las líneas sin importe. Sin ninguna, `noLines`.
    nonisolated static func decode(_ content: String) throws -> ReceiptSplitResponse {
        var json = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if json.hasPrefix("```") {
            json = json.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let response: ReceiptSplitResponse
        do {
            response = try JSONDecoder().decode(ReceiptSplitResponse.self, from: Data(json.utf8))
        } catch {
            #if DEBUG
            print("ReceiptSplitService: Error: \(error)")
            #endif
            throw ReceiptSplitError.invalidResponse
        }
        let lines = response.lines.filter { abs($0.amount) >= 0.005 }
        guard lines.contains(where: { (ReceiptLineKind(rawValue: $0.kind) ?? .item) == .item }) else {
            throw ReceiptSplitError.noLines
        }
        return ReceiptSplitResponse(
            merchant: response.merchant,
            currency: response.currency,
            printedTotal: response.printedTotal,
            lines: lines
        )
    }
}

// MARK: - De la respuesta a las líneas de la revisión

nonisolated enum ReceiptSplitDraftLogic {
    struct Draft: Equatable, Sendable {
        var lines: [ReceiptSplitLine]
        /// Nombres de la frase que no son de nadie del grupo, sin repetir.
        var unmatchedNames: [String]
    }

    static func draft(from response: ReceiptSplitResponse, members: [ReceiptPeopleMatcher.Member]) -> Draft {
        var unmatched: [String] = []
        let lines = response.lines.map { line -> ReceiptSplitLine in
            var kind = ReceiptLineKind(rawValue: line.kind) ?? .item
            // Un consumo en negativo («PROMO 2x1 -12») es un descuento: cobrarlo en positivo subiría el gasto.
            if kind == .item, line.amount < 0 { kind = .discount }
            let resolution = kind.isExtra
                ? ReceiptPeopleMatcher.Resolution(memberIDs: [], unmatched: [])
                : ReceiptPeopleMatcher.resolve(line.people, members: members)
            for name in resolution.unmatched where !unmatched.contains(name) { unmatched.append(name) }
            // Con alguien que no es del grupo, la línea no se le carga entera a los que sí casaron («Ana y Carla» no es
            // «Ana»): queda entre todos y marcada.
            let needsReview = !resolution.unmatched.isEmpty
            return ReceiptSplitLine(
                description: line.description.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: abs(line.amount),
                kind: kind,
                assignees: needsReview ? [] : resolution.memberIDs,
                needsReview: needsReview
            )
        }
        return Draft(lines: lines, unmatchedNames: unmatched)
    }
}
