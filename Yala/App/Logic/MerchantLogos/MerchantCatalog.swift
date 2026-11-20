//
//  MerchantCatalog.swift
//  Yala
//
//  Pagos planificados: logos reales y banco amplio de comercios (card `scheduled-payments-real-brand-logos`, 2.3).
//
//  El banco vive en `MerchantCatalog.json` (empaquetado) y sus logos en `MerchantLogos.xcassets`, los dos al lado de este
//  fichero. Los genera `scripts/merchant_logos.py`, que baja una sola vez, en la Mac, el icono que cada comercio publica
//  en su web: el teléfono no descarga nada y no sale ningún dato (ni el dominio).
//
//  Solo decide el DIBUJO. `SubscriptionBrandCatalog` sigue decidiendo qué es una suscripción para el detector de
//  recurrentes y el chat guiado (monto exacto, categoría): meter aquí Claro o Luz del Sur no cambia esas funciones.
//  Los ids de `SubscriptionBrandCatalog` existen igual aquí, así que un `ScheduledPayment.brandLogoID` guardado sigue
//  valiendo; el banco añade ids nuevos que también se guardan en ese campo (sin esquema nuevo).
//

import Foundation
import UIKit

/// Un comercio del banco.
struct Merchant: Identifiable, Equatable, Decodable {
    let id: String
    let name: String
    /// El dominio del que salió el logo. Solo informativo: la app no lo usa para pedir nada.
    let domain: String
    let category: String
    let aliases: [String]
    /// Nombre de la imagen en `MerchantLogos.xcassets`, o `nil` si su web no publica un icono usable.
    let logo: String?

    private enum CodingKeys: String, CodingKey { case id, name, domain, category, aliases, logo }

    init(id: String, name: String, domain: String, category: String, aliases: [String] = [], logo: String? = nil) {
        self.id = id
        self.name = name
        self.domain = domain
        self.category = category
        self.aliases = aliases
        self.logo = logo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        domain = try c.decode(String.self, forKey: .domain)
        category = try c.decode(String.self, forKey: .category)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        logo = try c.decodeIfPresent(String.self, forKey: .logo)
    }
}

enum MerchantCatalog {

    static let resourceName = "MerchantCatalog"

    /// El banco entero, en el orden del JSON. Vacío si el recurso no se puede leer (la app pinta la inicial de siempre).
    static let all: [Merchant] = load(from: Bundle.main)

    static func load(from bundle: Bundle) -> [Merchant] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            #if DEBUG
            print("MerchantCatalog: Error: falta \(resourceName).json en el bundle")
            #endif
            return []
        }
        do {
            return try JSONDecoder().decode([Merchant].self, from: Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("MerchantCatalog: Error: \(error)")
            #endif
            return []
        }
    }

    private static let byID: [String: Merchant] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    /// Cada forma de escribirlo, normalizada, de la más larga a la más corta: así gana «uber eats» a «uber».
    private static let index: [(key: String, merchant: Merchant)] = makeIndex(all)

    static func makeIndex(_ merchants: [Merchant]) -> [(key: String, merchant: Merchant)] {
        var entries: [(key: String, merchant: Merchant)] = []
        var seen = Set<String>()
        for merchant in merchants {
            for candidate in [merchant.name] + merchant.aliases {
                let key = SubscriptionBrandCatalog.normalize(candidate)
                // La primera entrada del banco con esa forma se la queda: el orden del JSON desempata.
                guard !key.isEmpty, seen.insert(key).inserted else { continue }
                entries.append((key, merchant))
            }
        }
        // Orden estable: a igual largo manda el orden del banco.
        return entries.enumerated()
            .sorted { lhs, rhs in
                lhs.element.key.count != rhs.element.key.count
                    ? lhs.element.key.count > rhs.element.key.count
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    static func merchant(id: String) -> Merchant? { byID[id] }

    /// Para elegir a mano: alfabético. Se ordena una vez: la hoja lo lee en cada tecla del buscador.
    static let sortedForPicking: [Merchant] =
        all.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    /// El comercio que casa con el nombre de un pago, o `nil`.
    static func match(name: String) -> Merchant? {
        match(name: name, in: index)
    }

    static func match(name: String, in index: [(key: String, merchant: Merchant)]) -> Merchant? {
        let normalized = SubscriptionBrandCatalog.normalize(name)
        guard !normalized.isEmpty else { return nil }
        if let hit = firstHit(normalized, in: index) { return hit }
        let cleaned = MerchantNameCleaner.clean(normalized)
        guard !cleaned.isEmpty, cleaned != normalized else { return nil }
        return firstHit(cleaned, in: index)
    }

    /// Casa si el nombre ES la forma o empieza por ella seguida de otra palabra («Netflix familiar», «SmartFit J1»).
    private static func firstHit(_ normalized: String, in index: [(key: String, merchant: Merchant)]) -> Merchant? {
        for entry in index where normalized == entry.key || normalized.hasPrefix(entry.key + " ") {
            return entry.merchant
        }
        return nil
    }
}

/// La segunda pasada del casado: quita lo que la gente escribe alrededor del comercio (D3 del encargo).
enum MerchantNameCleaner {

    /// Palabras de trámite que van DELANTE: «Pago Claro», «Tarjeta de crédito BCP», «Recibo Luz del Sur».
    static let leadingNoise: Set<String> = [
        "pago", "pagos", "recibo", "recibos", "tarjeta", "tarj", "tc", "credito", "debito", "cuota", "cuotas", "plan",
        "suscripcion", "subscripcion", "subscription", "mensualidad", "membresia", "servicio", "factura", "deuda",
        "prestamo", "seguro", "poliza", "renovacion", "abono", "cargo", "cobro", "compra", "de", "del", "la", "el",
        "los", "las", "mi", "a", "al", "en", "cuenta",
    ]

    /// Lo que va DETRÁS: país, razón social, tipo de producto, periodicidad.
    static let trailingNoise: Set<String> = [
        "pe", "peru", "sac", "saa", "sa", "srl", "eirl", "ltda", "inc", "llc", "corp", "mx", "co", "cl", "ar", "ec",
        "credito", "debito", "visa", "mastercard", "mensual", "anual", "pago", "cuota", "online", "web",
    ]

    /// Razones sociales que la normalización parte en letras sueltas («S.A.C.» → «s a c»).
    static let trailingSequences: [[String]] = [["s", "a", "c"], ["s", "a", "a"], ["s", "r", "l"], ["e", "i", "r", "l"], ["s", "a"]]

    /// Códigos sueltos: «J1», «P2», «3», «2024».
    static func isCode(_ token: Substring) -> Bool {
        token.range(of: #"^([a-z]{1,2}[0-9]{1,3}|[0-9]+)$"#, options: .regularExpression) != nil
    }

    static func clean(_ normalized: String) -> String {
        var tokens = normalized.split(separator: " ").filter { !isCode($0) }.map(String.init)
        while let first = tokens.first, leadingNoise.contains(first) { tokens.removeFirst() }
        var changed = true
        while changed {
            changed = false
            if let last = tokens.last, trailingNoise.contains(last) {
                tokens.removeLast()
                changed = true
                continue
            }
            for sequence in trailingSequences where tokens.count > sequence.count && Array(tokens.suffix(sequence.count)) == sequence {
                tokens.removeLast(sequence.count)
                changed = true
                break
            }
        }
        return tokens.joined(separator: " ")
    }
}

/// Lo que se pinta para un pago: el logo del banco, la foto que eligió la persona (logo propio) o, sin imagen, la
/// inicial sobre color.
struct PaymentLogo: Identifiable, Equatable {
    let id: String
    let name: String
    /// Imagen en `MerchantLogos.xcassets`; `nil` ⇒ se pinta `monogram` sobre `colorHex`.
    let assetName: String?
    let monogram: String
    let colorHex: String
    /// Logo propio: la foto del pago, ya decodificada (`PagoLogoPropioImagenes`). Gana a `assetName` y al monograma.
    var photo: UIImage? = nil

    /// El id de un logo propio, también para los `accessibilityIdentifier` (`scheduled_brand_badge_custom_photo`).
    static let customPhotoID = "custom_photo"

    /// El logo propio de un pago: su foto, con el nombre del pago (VoiceOver lo lee así en el editor).
    init(photo: UIImage, paymentName: String) {
        id = Self.customPhotoID
        name = paymentName
        assetName = nil
        monogram = PaymentLogo.monogram(for: paymentName)
        colorHex = PaymentLogo.fallbackColor(for: paymentName)
        self.photo = photo
    }

    static func == (lhs: PaymentLogo, rhs: PaymentLogo) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.assetName == rhs.assetName && lhs.monogram == rhs.monogram
            && lhs.colorHex == rhs.colorHex && lhs.photo === rhs.photo
    }

    init(merchant: Merchant) {
        id = merchant.id
        name = merchant.name
        assetName = merchant.logo
        if let brand = SubscriptionBrandCatalog.brand(id: merchant.id) {
            monogram = brand.monogram
            colorHex = brand.colorHex
        } else {
            monogram = PaymentLogo.monogram(for: merchant.name)
            colorHex = PaymentLogo.fallbackColor(for: merchant.id)
        }
    }

    init(brand: SubscriptionBrand) {
        id = brand.id
        name = brand.name
        assetName = MerchantCatalog.merchant(id: brand.id)?.logo
        monogram = brand.monogram
        colorHex = brand.colorHex
    }

    /// La inicial de cada una de las dos primeras palabras («Luz del Sur» → «LS», «Claro» → «C»).
    static func monogram(for name: String) -> String {
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .filter { word in !["de", "del", "la", "el", "y", "the", "of", "and"].contains(word.lowercased()) }
        let initials = words.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }
        return initials.isEmpty ? "?" : initials.joined()
    }

    static let fallbackPalette = [
        "#3D36B3", "#0F7A80", "#C2185B", "#E65100", "#2E7D32", "#1565C0", "#6A1B9A", "#AD1457", "#00838F", "#4E342E",
    ]

    /// Un color fijo por comercio (no cambia entre lanzamientos: nada de `hashValue`).
    static func fallbackColor(for id: String) -> String {
        let sum = id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return fallbackPalette[sum % fallbackPalette.count]
    }
}

enum PaymentLogoResolver {

    /// El logo de un pago con lo que tiene guardado (`ScheduledPayment.brandLogoID`), con las reglas de siempre:
    /// `nil` = automático por el nombre, `SubscriptionBrandCatalog.noneID` = quitado, un id = el elegido (si ya no
    /// existe en el banco, el automático).
    static func resolve(storedID: String?, name: String) -> PaymentLogo? {
        switch storedID {
        case .none: return automatic(name: name)
        case .some(SubscriptionBrandCatalog.noneID): return nil
        case .some(let id): return logo(id: id) ?? automatic(name: name)
        }
    }

    static func logo(id: String) -> PaymentLogo? {
        if let merchant = MerchantCatalog.merchant(id: id) { return PaymentLogo(merchant: merchant) }
        return SubscriptionBrandCatalog.brand(id: id).map { PaymentLogo(brand: $0) }
    }

    /// El del nombre: primero el banco; si el banco no se dejó leer, las suscripciones de siempre.
    static func automatic(name: String) -> PaymentLogo? {
        if let merchant = MerchantCatalog.match(name: name) { return PaymentLogo(merchant: merchant) }
        return SubscriptionBrandCatalog.match(name: name).map { PaymentLogo(brand: $0) }
    }
}

extension ScheduledPayment {
    /// El logo que se pinta para este pago, o `nil` si no hay (icono de su subcategoría).
    var paymentLogo: PaymentLogo? {
        PaymentLogoResolver.resolve(storedID: brandLogoID, name: name)
    }
}
