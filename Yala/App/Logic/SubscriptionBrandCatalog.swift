//
//  SubscriptionBrandCatalog.swift
//  Yala
//
//  Logos de suscripción en pagos planificados (card 2.3 `tablero-logos-de-suscripcion-en-pagos-planificad-9nn7`).
//
//  Un «logo» es un distintivo propio de Yala: las iniciales del servicio sobre su color de marca. NO son imágenes de
//  logos de terceros (licencia de marcas). El catálogo va empaquetado: el nombre del pago se compara con los nombres y
//  alias de cada servicio y, si casa, se propone el suyo.
//
//  Qué guarda el pago (`ScheduledPayment.brandLogoID`):
//  - `nil`: automático, el que case con el nombre (también para los pagos de antes de esta función).
//  - `noneID`: la persona lo quitó; se pinta el icono de siempre.
//  - el id de un servicio: el que eligió a mano, aunque el nombre no case.
//

import Foundation

struct SubscriptionBrand: Identifiable, Equatable {
    let id: String
    /// Nombre que se enseña al elegir.
    let name: String
    /// Lo que se pinta en el círculo (1-3 caracteres).
    let monogram: String
    let colorHex: String
    /// Formas en que la gente lo escribe, además del nombre. Se comparan normalizadas.
    let aliases: [String]
}

enum SubscriptionBrandCatalog {

    /// Valor guardado cuando la persona quita el logo.
    static let noneID = "none"

    static let all: [SubscriptionBrand] = [
        .init(id: "netflix", name: "Netflix", monogram: "N", colorHex: "#E50914", aliases: []),
        .init(id: "spotify", name: "Spotify", monogram: "S", colorHex: "#1DB954", aliases: ["spotify premium"]),
        .init(id: "disneyplus", name: "Disney+", monogram: "D+", colorHex: "#113CCF", aliases: ["disney plus", "disney", "star plus", "star+"]),
        .init(id: "max", name: "Max", monogram: "M", colorHex: "#002BE7", aliases: ["hbo", "hbo max"]),
        .init(id: "primevideo", name: "Prime Video", monogram: "P", colorHex: "#00A8E1", aliases: ["amazon prime", "prime", "amazon prime video"]),
        .init(id: "youtube", name: "YouTube Premium", monogram: "YT", colorHex: "#FF0000", aliases: ["youtube", "youtube music"]),
        .init(id: "applemusic", name: "Apple Music", monogram: "♪", colorHex: "#FA243C", aliases: []),
        .init(id: "icloud", name: "iCloud+", monogram: "iC", colorHex: "#3693F3", aliases: ["icloud", "icloud plus"]),
        .init(id: "appletv", name: "Apple TV+", monogram: "tv", colorHex: "#1C1C1E", aliases: ["apple tv", "apple tv plus"]),
        .init(id: "appleone", name: "Apple One", monogram: "1", colorHex: "#1C1C1E", aliases: []),
        .init(id: "chatgpt", name: "ChatGPT", monogram: "AI", colorHex: "#10A37F", aliases: ["chatgpt plus", "openai"]),
        .init(id: "claude", name: "Claude", monogram: "C", colorHex: "#D97757", aliases: ["claude pro", "anthropic"]),
        .init(id: "googleone", name: "Google One", monogram: "G", colorHex: "#4285F4", aliases: ["google drive", "google storage"]),
        .init(id: "microsoft365", name: "Microsoft 365", monogram: "M", colorHex: "#D83B01", aliases: ["office 365", "office", "microsoft"]),
        .init(id: "xbox", name: "Xbox Game Pass", monogram: "X", colorHex: "#107C10", aliases: ["xbox", "game pass"]),
        .init(id: "playstation", name: "PlayStation Plus", monogram: "PS", colorHex: "#003791", aliases: ["ps plus", "playstation"]),
        .init(id: "nintendo", name: "Nintendo Switch Online", monogram: "N", colorHex: "#E60012", aliases: ["nintendo"]),
        .init(id: "crunchyroll", name: "Crunchyroll", monogram: "C", colorHex: "#F47521", aliases: []),
        .init(id: "paramountplus", name: "Paramount+", monogram: "P+", colorHex: "#0064FF", aliases: ["paramount", "paramount plus"]),
        .init(id: "vix", name: "ViX", monogram: "V", colorHex: "#FF5A00", aliases: ["vix premium"]),
        .init(id: "deezer", name: "Deezer", monogram: "D", colorHex: "#A238FF", aliases: []),
        .init(id: "twitch", name: "Twitch", monogram: "T", colorHex: "#9146FF", aliases: []),
        .init(id: "canva", name: "Canva", monogram: "C", colorHex: "#00C4CC", aliases: ["canva pro"]),
        .init(id: "notion", name: "Notion", monogram: "N", colorHex: "#1C1C1E", aliases: []),
        .init(id: "dropbox", name: "Dropbox", monogram: "D", colorHex: "#0061FF", aliases: []),
        .init(id: "adobe", name: "Adobe", monogram: "A", colorHex: "#FA0F00", aliases: ["adobe creative cloud", "creative cloud", "photoshop", "lightroom"]),
        .init(id: "duolingo", name: "Duolingo", monogram: "D", colorHex: "#58CC02", aliases: ["duolingo super", "duolingo plus"]),
        .init(id: "linkedin", name: "LinkedIn Premium", monogram: "in", colorHex: "#0A66C2", aliases: ["linkedin"]),
        .init(id: "uberone", name: "Uber One", monogram: "U", colorHex: "#1C1C1E", aliases: ["uber"]),
        .init(id: "rappi", name: "Rappi Turbo", monogram: "R", colorHex: "#FF441F", aliases: ["rappi", "rappi prime", "rappi pro"]),
        .init(id: "pedidosya", name: "PedidosYa Plus", monogram: "PY", colorHex: "#FA0050", aliases: ["pedidosya", "pedidos ya"]),
        .init(id: "audible", name: "Audible", monogram: "A", colorHex: "#F8991C", aliases: []),
        .init(id: "kindle", name: "Kindle Unlimited", monogram: "K", colorHex: "#232F3E", aliases: ["kindle"]),
        .init(id: "patreon", name: "Patreon", monogram: "P", colorHex: "#FF424D", aliases: []),
        .init(id: "github", name: "GitHub", monogram: "GH", colorHex: "#24292F", aliases: ["github copilot", "copilot"]),
        .init(id: "zoom", name: "Zoom", monogram: "Z", colorHex: "#0B5CFF", aliases: []),
        .init(id: "strava", name: "Strava", monogram: "S", colorHex: "#FC4C02", aliases: []),
        .init(id: "headspace", name: "Headspace", monogram: "H", colorHex: "#F47D31", aliases: []),
        .init(id: "tinder", name: "Tinder", monogram: "T", colorHex: "#FE3C72", aliases: []),
        .init(id: "smartfit", name: "Smart Fit", monogram: "SF", colorHex: "#FFB800", aliases: ["smartfit"]),
    ]

    private static let byID: [String: SubscriptionBrand] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// Para elegir a mano: alfabético.
    static var sortedForPicking: [SubscriptionBrand] {
        all.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func brand(id: String) -> SubscriptionBrand? { byID[id] }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: #"[^\p{L}\p{N}+ ]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// El servicio que casa con el nombre de un pago. Casa si el nombre ES el servicio o un alias, o si empieza por él
    /// seguido de otra palabra («Netflix familiar», «Spotify Duo»). Gana el alias más largo («Apple TV+» antes que
    /// «Apple»). `nil` si nada casa.
    static func match(name: String) -> SubscriptionBrand? {
        let n = normalize(name)
        guard !n.isEmpty else { return nil }
        var best: (brand: SubscriptionBrand, length: Int)?
        for brand in all {
            for candidate in [brand.name] + brand.aliases {
                let c = normalize(candidate)
                guard !c.isEmpty else { continue }
                if n == c || n.hasPrefix(c + " ") {
                    if best.map({ c.count > $0.length }) ?? true { best = (brand, c.count) }
                }
            }
        }
        return best?.brand
    }

    /// Lo que se pinta para un pago: el elegido, el automático o ninguno.
    static func resolve(storedID: String?, name: String) -> SubscriptionBrand? {
        switch storedID {
        case .none: return match(name: name)
        case .some(noneID): return nil
        case .some(let id): return brand(id: id) ?? match(name: name)
        }
    }
}

extension ScheduledPayment {
    /// El distintivo que se pinta para este pago, o `nil` si no hay (icono de siempre).
    var subscriptionBrand: SubscriptionBrand? {
        SubscriptionBrandCatalog.resolve(storedID: brandLogoID, name: name)
    }
}
