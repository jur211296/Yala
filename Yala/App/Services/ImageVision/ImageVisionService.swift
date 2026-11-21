//
//  ImageVisionService.swift
//  Yala
//
//  Service for extracting transactions from images using GPT-4o Vision.
//  Falls back to local OCR pipeline if API unavailable.
//

import UIKit
import ImageIO
import UniformTypeIdentifiers
import Observation
import OpenAI

// MARK: - Response Models

/// A single transaction extracted from an image
struct VisionTransaction: Codable {
    let amount: Double?
    let date: String?        // YYYY-MM-DD format
    let merchant: String?
    let note: String?
    let currency: String?    // "USD", "EUR", "PEN", etc.
    /// El medio de pago tal como sale en la imagen («Tarjeta de crédito», «Zip Visa ••4417»), o `nil`. La cuenta la
    /// decide la escalera del teléfono (`CuentaSolaAlLeer`). Un gateway o una respuesta sin el campo, `nil`: como antes.
    var payment: String? = nil
    /// La cuenta que la IA cree, copiada de la lista que recibió (solo con la cuenta en la nube), o `nil`. Es la segunda
    /// capa: solo vale si existe y sus palabras están en `payment` (`CuentaSolaAlLeer.cuentaDeIA`).
    var account: String? = nil
}

extension VisionTransaction {
    private enum CodingKeys: String, CodingKey {
        case amount, date, merchant, note, currency, payment, account
    }

    /// Los cinco campos de siempre como antes; `payment` y `account`, si traen otra cosa que un texto, se leen como `nil`
    /// en vez de tumbar la lectura entera: son una ayuda para elegir la cuenta, no el movimiento.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        amount = try container.decodeIfPresent(Double.self, forKey: .amount)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        merchant = try container.decodeIfPresent(String.self, forKey: .merchant)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        payment = Self.lenientText(container, .payment)
        account = Self.lenientText(container, .account)
    }

    private static func lenientText(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        do {
            return try container.decodeIfPresent(String.self, forKey: key)
        } catch {
            #if DEBUG
            print("VisionTransaction: \(key.stringValue) ilegible: \(error)")
            #endif
            return nil
        }
    }
}

/// Confidence scores for the vision extraction
struct VisionConfidence: Codable {
    let overall: Double       // 0.0-1.0
    let imageType: Double     // Confidence in image classification
}

/// Complete response from GPT-4o Vision
struct VisionResponse: Codable {
    let imageType: String     // "single", "list", "receipt", "unknown"
    let transactions: [VisionTransaction]
    let confidence: VisionConfidence
}

// MARK: - Divisas del usuario

/// Lo que la lectura de la foto necesita saber de las divisas del usuario para un símbolo que la imagen no aclara
/// (sesión 2 del gateway de IA, paso 6 bis, con `vision-reads-every-dollar-sign-as-usd`). Un «$» a secas es dólar en
/// EE. UU. y peso en México, Colombia, Chile, Argentina o Uruguay: lo decide la divisa principal del usuario.
nonisolated struct VisionCurrencyContext: Equatable, Sendable {
    let mainCurrency: String?
    let accountCurrencies: [String]

    static let unknown = VisionCurrencyContext(mainCurrency: nil, accountCurrencies: [])

    /// «$» a secas → la divisa principal si se escribe con «$»; si no, `nil` (el usuario elige en la revisión).
    /// En el actor principal porque `CurrencyCode.symbol` vive ahí; la usa el prompt, que también.
    @MainActor var dollarAlone: String? {
        guard let main = mainCurrency, CurrencyCode(rawValue: main)?.symbol == "$" else { return nil }
        return main
    }

    /// La regla del «$» como la lee el modelo.
    @MainActor var dollarRule: String {
        dollarAlone.map { "\"\($0)\" (the user's main currency is written with $)" } ?? "null (a \"$\" alone does not say which dollar it is)"
    }

    /// Las divisas del usuario, para desempatar símbolos compartidos. Vacío si no se saben.
    var userCurrencies: String {
        guard let main = mainCurrency else { return "" }
        let accounts = accountCurrencies.isEmpty ? main : accountCurrencies.joined(separator: ", ")
        return "The user's main currency is \(main) and their accounts use \(accounts). Use this ONLY to choose between currencies that share a symbol."
    }
}

// MARK: - Errors

enum VisionError: Error, LocalizedError {
    case noAPIKey
    case imageEncodingFailed
    case networkError(Error)
    case invalidResponse
    case noTransactionsFound

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "AI service not configured"
        case .imageEncodingFailed:
            return "Failed to encode image"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Vision API"
        case .noTransactionsFound:
            return "No transactions found in image"
        }
    }
}

// MARK: - Service

/// Service for extracting transactions from images using GPT-4o Vision API.
/// Supports @Environment injection in SwiftUI views.
@MainActor @Observable
final class ImageVisionService {

    // MARK: - Singleton (for backward compatibility)

    /// Shared instance for backward compatibility. Prefer @Environment injection in Views.
    static let shared = ImageVisionService()

    init() {}

    // MARK: - Properties

    /// La disponibilidad real se resuelve al llamar al proxy (degradación graciosa si falla).
    var isAvailable: Bool {
        true
    }

    // MARK: - System Prompt

    func systemPrompt(currency: VisionCurrencyContext) -> String {
        let dateContext = DateContextProvider.buildDateContext()
        let dollarRule = currency.dollarRule
        let userCurrencies = currency.userCurrencies

        return """
        You are a financial transaction extractor. Analyze images and extract transaction data.

        Image types:
        - "single": One transaction (bank alert, notification)
        - "list": Multiple transactions (bank history, statement)
        - "receipt": Photo of a receipt (extract TOTAL only)
        - "unknown": Cannot identify as financial

        Rules:
        - Merchant: the shop, service or person as printed. Never the bank, the wallet (Yape, Plin) or the card.
        - Note: null, unless a short detail helps to know where the money went (branch, city). Never the bank's
          template text ("Consumo con tarjeta de crédito BCP", "Purchase approved"), operation numbers or card digits.
        - Amounts: No currency symbol, expenses are NEGATIVE, income is POSITIVE
        - Dates: ALWAYS convert to YYYY-MM-DD format
        - Currency: Extract from symbols or explicit mentions
        - Payment: the words that say how it was paid, copied exactly as printed (card or account name, wallet, "cash",
          masked digits like "••4417"). null if the image does not say it. Never guess it from the bank's logo alone.
        - Account: only if the user's accounts are listed in the message, the name of the one account that the payment
          words point to, copied exactly from that list. null if none clearly matches or there is no list. Never invent one.

        Currency extraction rules (always answer an ISO 4217 code or null):
        - "US$" → "USD"
        - "$" symbol alone → \(dollarRule)
        - "€" symbol → "EUR"
        - "S/" symbol → "PEN"
        - "£" symbol → "GBP"
        - "R$" symbol → "BRL"
        - "zł" or "PLN" → "PLN"
        - "¥", "円" or "JP¥" in a Japanese text → "JPY"
        - "¥", "元", "CN¥" or "RMB" in a Chinese text → "CNY"
        - "CHF" or "Fr." → "CHF"
        - "MX$" → "MXN", "COL$" → "COP", "CLP$" → "CLP", "C$" or "CA$" → "CAD", "A$" or "AU$" → "AUD"
        - Explicit mentions: "dollars", "dólares", "USD" → "USD"
        - Explicit mentions: "soles", "PEN" → "PEN"
        - Explicit mentions: "euros", "EUR" → "EUR"
        - Explicit mentions: "reais", "real", "BRL" → "BRL"
        - Explicit mentions: "złotych", "złoty" → "PLN"
        - Explicit mentions: "yen", "円" → "JPY"; "yuan", "元", "人民币" → "CNY"
        - Any other ISO 4217 code written in the image (e.g. "MXN", "COP", "ARS", "CAD") → that code
        - If no currency indicator found → null
        \(userCurrencies)

        \(dateContext)

        Date formats to recognize and convert:
        - Spanish abbreviated: "13 ene. 2026", "13 ene 2026" → 2026-01-13
        - English abbreviated: "Jan 13, 2026", "13 Jan 2026" → 2026-01-13
        - Spanish full: "13 de enero de 2026" → 2026-01-13
        - English full: "January 13, 2026" → 2026-01-13
        - Numeric short: "15/01/26", "15-01-26" → 2026-01-15
        - Numeric long: "15/01/2026", "15-01-2026" → 2026-01-15
        - ISO: "2026-01-15" → 2026-01-15
        - Day/month only (assume current year): "15/01" → current-year-01-15

        Spanish months: ene, feb, mar, abr, may, jun, jul, ago, sep, oct, nov, dic
        English months: jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov, dec

        Respond ONLY with valid JSON (no markdown, no explanation):
        {
          "imageType": "single",
          "transactions": [{"amount": -45.50, "date": "2026-01-25", "merchant": "Starbucks", "note": null, "currency": "USD", "payment": null, "account": null}],
          "confidence": {"overall": 0.95, "imageType": 0.90}
        }
        """
    }

    // MARK: - Public Methods

    /// Analyzes an image using GPT-4o Vision to extract transactions
    /// - Parameter image: UIImage to analyze
    /// - Returns: VisionResponse with extracted transactions
    /// - Throws: VisionError if analysis fails
    /// - Parameter accounts: las cuentas que la IA puede proponer (`CuentaSolaAlLeerPeticion.cuentas`): vacío en iCloud
    ///   privado, y entonces la petición sale como antes.
    func analyze(
        image: UIImage, currency: VisionCurrencyContext = .unknown, accounts: [CuentaSolaAlLeerPeticion.Cuenta] = []
    ) async throws -> VisionResponse {
        let client: OpenAI
        do {
            client = try await ProxyClientFactory.makeOpenAI(task: .photoRead)
        } catch {
            throw VisionError.networkError(error)
        }

        // Reducir al lado mayor que aprovecha el modelo (lo publica el gateway en /config) y codificar.
        let maxEdge = PhotoUploadSizing.maxEdge(remote: CloudRemoteConfigStore.readSnapshot()?.photoMaxEdge)
        guard let imageData = Self.uploadJPEG(image, maxEdge: maxEdge) else {
            throw VisionError.imageEncodingFailed
        }

        let query = makeQuery(imageData: imageData, currency: currency, accounts: accounts, today: currentDayAndDateString())

        do {
            let result = try await client.chats(query: query)

            // Extract text content from response
            guard let contentString = result.choices.first?.message.content,
                  !contentString.isEmpty else {
                throw VisionError.invalidResponse
            }

            // Parse JSON response
            guard let jsonData = contentString.data(using: .utf8) else {
                throw VisionError.invalidResponse
            }

            let response = try JSONDecoder().decode(VisionResponse.self, from: jsonData)
            return response

        } catch let error as VisionError {
            throw error
        } catch {
            throw VisionError.networkError(error)
        }
    }

    /// La petición de la foto. Aparte para poder comprobar su cuerpo: con cuentas lleva sus nombres, su clase y su
    /// moneda, y nada más de ellas (ni saldos, ni números de cuenta, ni últimos 4).
    func makeQuery(
        imageData: Data, currency: VisionCurrencyContext, accounts: [CuentaSolaAlLeerPeticion.Cuenta], today: String
    ) -> ChatQuery {
        var text = "Extract transactions from this image. Today is \(today)."
        if let list = CuentaSolaAlLeerPeticion.texto(accounts) {
            text += "\n\n" + list
        }
        let textPart = ChatQuery.ChatCompletionMessageParam.ContentPartTextParam(text: text)
        let imagePart = ChatQuery.ChatCompletionMessageParam.ContentPartImageParam(
            imageUrl: .init(imageData: imageData, detail: .auto)
        )
        return ChatQuery(
            messages: [
                .system(.init(content: .textContent(systemPrompt(currency: currency)))),
                .user(.init(content: .contentParts([.text(textPart), .image(imagePart)])))
            ],
            model: .gpt4_1_nano,
            responseFormat: .jsonObject
        )
    }

    // MARK: - Private Methods

    /// La foto como sube: reducida a `maxEdge` px de lado mayor (nunca ampliada), en JPEG al 80 % y SIN metadatos.
    /// El renderer con escala 1 trabaja en píxeles, aplica la orientación y dibuja solo los píxeles; el JPEG se escribe
    /// con ImageIO sin propiedades, así que no lleva GPS, fecha, cámara ni orientación. La política de privacidad lo
    /// promete desde el 2026-10-12: antes se mandaba `jpegData` sin redibujar cuando la foto no pasaba de `maxEdge`.
    static func uploadJPEG(_ image: UIImage, maxEdge: Int) -> Data? {
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let target = PhotoUploadSizing.targetPixelSize(for: pixels, maxEdge: maxEdge) ?? pixels
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let cgImage = rendered.cgImage else { return nil }
        return metadataFreeJPEG(cgImage, quality: 0.8)
    }

    /// JPEG sin metadatos de la foto original. ImageIO escribe siempre un bloque `{Exif}` con el ancho y el alto en
    /// píxeles (medido el 2026-10-12, no se puede suprimir); nada más: ni `{GPS}`, ni `{TIFF}`, ni fecha o cámara.
    static func metadataFreeJPEG(_ cgImage: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImageMetadataShouldExcludeGPS: true,
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private func currentDayAndDateString() -> String {
        let dayFmt = DateFormatter()
        dayFmt.locale = Locale(identifier: "en")
        dayFmt.dateFormat = "EEEE"
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let now = Date.now
        return "\(dayFmt.string(from: now)), \(dateFmt.string(from: now))"
    }
}
