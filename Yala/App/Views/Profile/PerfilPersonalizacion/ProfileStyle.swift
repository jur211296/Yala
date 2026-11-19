//
//  ProfileStyle.swift
//  Yala
//
//  La personalización del perfil (encargo del 17-nov, «perfil con personalización de verdad»): qué lleva el avatar
//  (símbolo, emoji o iniciales), su color y el fondo de la tarjeta de perfil. El fondo reusa el catálogo y el contraste
//  de las tarjetas de cuentas (`CardTemplateCatalog`, `CardLookLogic`): el mismo lenguaje visual, sin tocar sus ficheros.
//
//  Dónde vive: el símbolo sigue en `userProfileIcon` (lo leen las versiones de antes, que no conocen lo demás) y el resto
//  en UNA preferencia sincronizada nueva, `userProfileStyle`, un JSON corto. Quien ya tenía un símbolo elegido y nunca abre
//  la personalización sigue viendo exactamente lo de antes: el estilo vacío es «el de siempre».
//
//  La foto no entra aquí: vive en un archivo local (`ProfileImageStorage`) y no sincroniza. Si hay foto, manda la foto; en
//  los otros dispositivos se ve el avatar elegido aquí.
//
//  Lógica pura, sin `Color` ni vistas, para medirla en tests.
//

import Foundation

// MARK: - Qué lleva el avatar

nonisolated enum ProfileAvatarKind: String, CaseIterable, Codable, Sendable {
    case symbol
    case emoji
    case initials
}

/// Lo que se dibuja dentro del círculo, ya resuelto.
nonisolated enum ProfileAvatarContent: Equatable, Sendable {
    case symbol(String)
    case emoji(String)
    case initials(String)
}

// MARK: - Estilo guardado

nonisolated struct ProfileStyle: Equatable, Codable, Sendable {
    var kind: ProfileAvatarKind
    /// Un solo emoji. `nil` = ninguno elegido (el avatar cae al símbolo).
    var emoji: String?
    /// Color del círculo del avatar, «#RRGGBB». `nil` = el del tema, como siempre.
    var avatarColorHex: String?
    /// Plantilla del fondo de la tarjeta de perfil (`CardTemplateCatalog`). `nil` = «Tu color» (el del avatar o el del
    /// tema).
    var cardTemplateID: String?

    init(kind: ProfileAvatarKind = .symbol, emoji: String? = nil, avatarColorHex: String? = nil,
         cardTemplateID: String? = nil) {
        self.kind = kind
        self.emoji = emoji
        self.avatarColorHex = avatarColorHex
        self.cardTemplateID = cardTemplateID
    }

    /// El estilo de quien nunca personalizó: símbolo, colores del tema y la tarjeta en «Tu color».
    static let standard = ProfileStyle()

    // Claves cortas, como `CardDesign`: viaja entero por el canal de preferencias.
    private enum CodingKeys: String, CodingKey {
        case kind = "k"
        case emoji = "e"
        case avatarColorHex = "a"
        case cardTemplateID = "t"
    }

    /// Lectura tolerante: lo que no se entiende (un tipo de una versión más nueva, un color mal formado, un emoji que no
    /// es un emoji, una plantilla que ya no existe) se ignora sin perder el resto.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawKind = try container.decodeIfPresent(String.self, forKey: .kind)
        kind = rawKind.flatMap(ProfileAvatarKind.init(rawValue:)) ?? .symbol
        emoji = ProfileStyleLogic.sanitizedEmoji(try container.decodeIfPresent(String.self, forKey: .emoji))
        avatarColorHex = CardDesignLogic.sanitizedHex(try container.decodeIfPresent(String.self, forKey: .avatarColorHex))
        let template = try container.decodeIfPresent(String.self, forKey: .cardTemplateID)
        cardTemplateID = template.flatMap { ProfileStyleLogic.knownTemplateID($0) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind.rawValue, forKey: .kind)
        try container.encodeIfPresent(emoji, forKey: .emoji)
        try container.encodeIfPresent(avatarColorHex, forKey: .avatarColorHex)
        try container.encodeIfPresent(cardTemplateID, forKey: .cardTemplateID)
    }
}

// MARK: - Lógica

nonisolated enum ProfileStyleLogic {

    /// El símbolo de quien no eligió ninguno.
    static let defaultSymbol = "person.fill"

    /// El color de la tarjeta en «Tu color» cuando ni el avatar ni el tema dan uno: el índigo de Yala.
    static let fallbackAccentHex = "#6366F1"

    // MARK: Catálogos

    /// Los doce del selector de antes, en su orden: quien ya tenía uno lo encuentra donde estaba.
    static let legacySymbols: [String] = [
        "person.fill", "face.smiling.fill", "star.fill", "heart.fill", "bolt.fill", "crown.fill",
        "leaf.fill", "flame.fill", "moon.fill", "sun.max.fill", "cloud.fill", "drop.fill",
    ]

    /// Los símbolos que ofrece la personalización: los doce de antes y 24 más.
    static let symbols: [String] = legacySymbols + [
        "pawprint.fill", "cat.fill", "dog.fill", "bird.fill", "fish.fill", "tortoise.fill",
        "airplane", "car.fill", "bicycle", "figure.run", "dumbbell.fill", "gamecontroller.fill",
        "music.note", "paintpalette.fill", "camera.fill", "book.fill", "graduationcap.fill", "briefcase.fill",
        "cup.and.saucer.fill", "fork.knife", "mountain.2.fill", "globe.americas.fill", "sparkles", "gift.fill",
    ]

    /// Los emojis que ofrece la personalización: caras, animales, naturaleza y cosas. VoiceOver los lee por su nombre.
    static let emojis: [String] = [
        "😀", "😎", "🤓", "🥳", "😇", "🤠",
        "🐶", "🐱", "🦊", "🐼", "🐨", "🦁",
        "🐸", "🐙", "🦄", "🐝", "🌵", "🌻",
        "🍀", "🌈", "🔥", "⚡️", "🌙", "⭐️",
        "🍕", "🥑", "☕️", "🎧", "🎮", "⚽️",
        "🚀", "💎", "🏝️", "🎨", "📚", "💰",
    ]

    /// Los colores del avatar: los mismos que ofrece el editor de las tarjetas de cuentas.
    static var avatarColors: [String] { CardTemplateCatalog.swatches }

    /// Una plantilla que ya no existe (o de otra versión) se lee como «Tu color».
    static func knownTemplateID(_ id: String) -> String? {
        CardTemplateCatalog.all.contains { $0.id == id } ? id : nil
    }

    // MARK: La preferencia

    /// Lee la preferencia. Vacío o ilegible = el estilo de siempre.
    static func decode(_ stored: String) -> ProfileStyle {
        guard !stored.isEmpty, let data = stored.data(using: .utf8) else { return .standard }
        do {
            return try JSONDecoder().decode(ProfileStyle.self, from: data)
        } catch {
            #if DEBUG
            print("ProfileStyleLogic: Error: la preferencia no se entiende: \(error)")
            #endif
            return .standard
        }
    }

    /// Escribe la preferencia con las claves en orden: el mismo estilo da siempre el mismo texto. El de siempre → "", así
    /// la preferencia no viaja para quien no personalizó nada.
    static func encode(_ style: ProfileStyle) -> String {
        guard style != .standard else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            let data = try encoder.encode(style)
            return String(decoding: data, as: UTF8.self)
        } catch {
            #if DEBUG
            print("ProfileStyleLogic: Error: no se pudo escribir la preferencia: \(error)")
            #endif
            return ""
        }
    }

    // MARK: Emoji

    /// Un solo emoji, o `nil`. Se queda con el primer carácter si es un emoji (con sus modificadores: tono de piel,
    /// banderas, secuencias). Letras, números o un texto vacío dan `nil`.
    static func sanitizedEmoji(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, isEmoji(first) else { return nil }
        return String(first)
    }

    static func isEmoji(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        guard let firstScalar = scalars.first else { return false }
        if firstScalar.properties.isEmojiPresentation { return true }
        // «1», «#» y «*» son `isEmoji` por sus teclas: un carácter ASCII nunca cuenta. Los demás, solo con el selector de
        // presentación detrás («⚡️»).
        return firstScalar.properties.isEmoji && scalars.count > 1 && !firstScalar.isASCII
    }

    // MARK: Iniciales

    /// Hasta dos iniciales del nombre, en mayúsculas: la primera letra de la primera palabra y la de la última. Con el
    /// nombre de serie («Usuario») o vacío no hay iniciales: el avatar cae al símbolo.
    static func initials(from name: String, defaultName: String, locale: Locale = .current) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != defaultName else { return "" }
        let words = trimmed.split(whereSeparator: { $0.isWhitespace || $0 == "-" })
        let letters = words.compactMap { word in word.first { $0.isLetter } }
        guard let first = letters.first else { return "" }
        var result = String(first)
        if letters.count > 1, let last = letters.last {
            result.append(last)
        }
        return result.uppercased(with: locale)
    }

    // MARK: Lo que se pinta

    /// Lo que lleva el avatar, con sus caídas: emoji sin emoji y nombre sin iniciales vuelven al símbolo; un símbolo vacío
    /// es el de siempre.
    static func content(style: ProfileStyle, symbol: String, name: String, defaultName: String) -> ProfileAvatarContent {
        let resolvedSymbol = symbol.isEmpty ? defaultSymbol : symbol
        switch style.kind {
        case .symbol:
            return .symbol(resolvedSymbol)
        case .emoji:
            if let emoji = style.emoji { return .emoji(emoji) }
            return .symbol(resolvedSymbol)
        case .initials:
            let letters = initials(from: name, defaultName: defaultName)
            return letters.isEmpty ? .symbol(resolvedSymbol) : .initials(letters)
        }
    }

    /// El color del texto o del símbolo encima de un relleno: blanco o casi negro, el que más contraste dé.
    static func foreground(onFill hex: String) -> CardRGB {
        let fill = CardRGB(hex: hex) ?? .ink
        return fill.contrast(with: .white) >= fill.contrast(with: .ink) ? .white : .ink
    }

    /// El fondo de la tarjeta de perfil. «Tu color» se tiñe con el color del avatar o, sin él, con el del tema. Sin chip
    /// ni dígitos: es una tarjeta de perfil, no de banco. El texto se lee siempre (contraste de `CardLookLogic`).
    static func cardLook(style: ProfileStyle, themeAccentHex: String) -> CardLook {
        let templateID = style.cardTemplateID ?? CardTemplateCatalog.accountColorID
        let design = CardDesign(templateID: templateID, showsChip: false)
        return CardLookLogic.look(
            for: design, type: .general, accountColorHex: style.avatarColorHex ?? themeAccentHex,
            accountIconName: defaultSymbol)
    }
}
