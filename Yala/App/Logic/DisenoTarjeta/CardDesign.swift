//
//  CardDesign.swift
//  Yala
//
//  Diseño de la tarjeta de una cuenta en el carrusel «Tus finanzas» del Panel (2026-11-16, ticket
//  `2026-11-15-tarjetas-personalizables`). Solo diseño: plantilla, color, patrón, ícono, chip y, si la persona quiere, los
//  últimos 4 dígitos. Nunca el número completo ni otro dato de la tarjeta real.
//
//  Dónde vive: en UNA preferencia sincronizada (`PrefSyncKey.accountCardDesigns`), un JSON compacto por
//  `Account.shortcutID` con solo las cuentas que la persona cambió. Mismo molde que `panelMoneyAccountOverrides`: sin campo
//  nuevo en el esquema de CloudKit ni en el de Supabase, y una cuenta nueva recibe el diseño de por defecto sin escribir nada.
//

import Foundation

// MARK: - Patrón

/// El adorno que se dibuja encima del fondo. Siempre en el color del texto y a muy poca opacidad: decora, no compite.
nonisolated enum CardPattern: String, CaseIterable, Codable, Sendable {
    case none
    case grid
    case waves
    case lines
    case dots
    case topographic
    case diamonds
}

// MARK: - Diseño elegido

/// Lo que la persona eligió para una tarjeta. Los campos opcionales en `nil` dejan mandar a la plantilla (o a la cuenta).
nonisolated struct CardDesign: Equatable, Codable, Sendable {
    /// Plantilla del catálogo (`CardTemplateCatalog`). Una que ya no existe se lee como la de por defecto.
    var templateID: String
    /// Color base propio, «#RRGGBB». `nil` = el de la plantilla (en «Tu color», el de la cuenta).
    var colorHex: String?
    /// Patrón propio. `nil` = el de la plantilla.
    var pattern: CardPattern?
    /// Símbolo propio. `nil` = el ícono de la cuenta.
    var iconName: String?
    var showsChip: Bool
    /// Últimos 4 dígitos, exactamente 4 números (`CardDesignLogic.sanitizedLastFour`). `nil` = no se muestran.
    var lastFour: String?

    // Claves cortas: la preferencia viaja entera por el canal de preferencias, que tiene tope.
    private enum CodingKeys: String, CodingKey {
        case templateID = "t"
        case colorHex = "c"
        case pattern = "p"
        case iconName = "i"
        case showsChip = "ch"
        case lastFour = "d"
    }

    init(
        templateID: String, colorHex: String? = nil, pattern: CardPattern? = nil, iconName: String? = nil,
        showsChip: Bool, lastFour: String? = nil
    ) {
        self.templateID = templateID
        self.colorHex = colorHex
        self.pattern = pattern
        self.iconName = iconName
        self.showsChip = showsChip
        self.lastFour = lastFour
    }

    /// Lectura tolerante: un patrón desconocido (de una versión más nueva) o unos dígitos que no son 4 números se ignoran
    /// sin perder el resto del diseño.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        templateID = try container.decode(String.self, forKey: .templateID)
        colorHex = CardDesignLogic.sanitizedHex(try container.decodeIfPresent(String.self, forKey: .colorHex))
        pattern = (try container.decodeIfPresent(String.self, forKey: .pattern)).flatMap(CardPattern.init(rawValue:))
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
        showsChip = try container.decodeIfPresent(Bool.self, forKey: .showsChip) ?? false
        lastFour = CardDesignLogic.sanitizedLastFour(try container.decodeIfPresent(String.self, forKey: .lastFour))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(templateID, forKey: .templateID)
        try container.encodeIfPresent(colorHex, forKey: .colorHex)
        try container.encodeIfPresent(pattern?.rawValue, forKey: .pattern)
        try container.encodeIfPresent(iconName, forKey: .iconName)
        try container.encode(showsChip, forKey: .showsChip)
        try container.encodeIfPresent(lastFour, forKey: .lastFour)
    }
}

// MARK: - Lógica

nonisolated enum CardDesignLogic {

    // MARK: Diseño por defecto

    /// El diseño de una cuenta que nadie tocó: «Tu color» con el color de la cuenta, el patrón de su tipo y chip en las
    /// cuentas que en la vida real llevan tarjeta. Así nadie ve un cambio feo al actualizar: su tarjeta sale de su color.
    static func defaultDesign(type: AccountType) -> CardDesign {
        CardDesign(templateID: CardTemplateCatalog.accountColorID, showsChip: defaultShowsChip(type: type))
    }

    static func defaultPattern(type: AccountType) -> CardPattern {
        switch type {
        case .creditCard: return .grid
        case .checking: return .lines
        case .savings: return .waves
        case .cash: return .dots
        case .general: return .topographic
        }
    }

    static func defaultShowsChip(type: AccountType) -> Bool {
        switch type {
        case .creditCard, .checking, .general: return true
        case .savings, .cash: return false
        }
    }

    // MARK: Últimos 4 dígitos

    /// Los últimos 4 dígitos que se guardan: exactamente 4 números ASCII, o nada. Cualquier otra cosa (3 números, letras,
    /// el número completo pegado) devuelve `nil`: no se guarda ni se pinta nada que no sean esos 4.
    static func sanitizedLastFour(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 4, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return trimmed
    }

    /// Lo que el campo deja escribir mientras se teclea: solo números y como mucho 4. Pegar un número largo NO se queda
    /// con sus últimos 4: se queda con los primeros 4 de lo pegado y la persona ve que no es lo que quería.
    static func typedLastFour(_ raw: String) -> String {
        String(raw.filter { $0.isASCII && $0.isNumber }.prefix(4))
    }

    // MARK: Color

    /// «#RRGGBB» en mayúsculas, o `nil` si no es un color de 6 cifras hexadecimales.
    static func sanitizedHex(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        return "#" + hex
    }

    // MARK: La preferencia

    /// Lee la preferencia: `[shortcutID: diseño]`. Una entrada que no se entiende se ignora y esa cuenta vuelve al diseño
    /// por defecto; un texto que no es JSON deja todas en el suyo.
    static func decode(_ stored: String) -> [UUID: CardDesign] {
        guard !stored.isEmpty, let data = stored.data(using: .utf8) else { return [:] }
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data)
        } catch {
            #if DEBUG
            print("CardDesignLogic: Error: la preferencia no es JSON: \(error)")
            #endif
            return [:]
        }
        guard let raw = parsed as? [String: Any] else { return [:] }
        var result: [UUID: CardDesign] = [:]
        for (key, value) in raw {
            guard let id = UUID(uuidString: key), JSONSerialization.isValidJSONObject(value) else { continue }
            do {
                let entryData = try JSONSerialization.data(withJSONObject: value)
                result[id] = try JSONDecoder().decode(CardDesign.self, from: entryData)
            } catch {
                #if DEBUG
                print("CardDesignLogic: Error: entrada ilegible: \(error)")
                #endif
            }
        }
        return result
    }

    /// Escribe la preferencia con las claves en orden: el mismo mapa da siempre el mismo texto, y la sincronización no ve
    /// un cambio donde no lo hay. Vacío → "".
    static func encode(_ designs: [UUID: CardDesign]) -> String {
        guard !designs.isEmpty else { return "" }
        let keyed = Dictionary(uniqueKeysWithValues: designs.map { ($0.key.uuidString, $0.value) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            let data = try encoder.encode(keyed)
            return String(decoding: data, as: UTF8.self)
        } catch {
            #if DEBUG
            print("CardDesignLogic: Error: no se pudo escribir la preferencia: \(error)")
            #endif
            return ""
        }
    }

    /// El diseño que se pinta para una cuenta: el guardado o, si no hay, el de por defecto de su tipo.
    static func design(for shortcutID: UUID, type: AccountType, in stored: String) -> CardDesign {
        decode(stored)[shortcutID] ?? defaultDesign(type: type)
    }

    /// La preferencia tras guardar el diseño de una cuenta. Un diseño igual al de por defecto se retira: la cuenta vuelve
    /// a seguir su color y su tipo.
    static func setting(_ design: CardDesign, for shortcutID: UUID, type: AccountType, in stored: String) -> String {
        var designs = decode(stored)
        var cleaned = design
        cleaned.lastFour = sanitizedLastFour(design.lastFour)
        cleaned.colorHex = sanitizedHex(design.colorHex)
        if cleaned == defaultDesign(type: type) {
            designs[shortcutID] = nil
        } else {
            designs[shortcutID] = cleaned
        }
        return encode(designs)
    }

    /// La preferencia sin el diseño de esa cuenta («Volver al diseño original»).
    static func removing(_ shortcutID: UUID, in stored: String) -> String {
        var designs = decode(stored)
        designs[shortcutID] = nil
        return encode(designs)
    }
}
