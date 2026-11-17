//
//  CardLook.swift
//  Yala
//
//  Lo que se pinta de una tarjeta, ya resuelto: los colores del fondo, el color del texto, el patrón, el acabado, el
//  ícono, el chip y los últimos 4. Sale de `CardDesign` + plantilla + cuenta, y garantiza el contraste del texto: el saldo
//  se lee siempre, elija lo que elija la persona.
//
//  Lógica pura con colores en RGB (0…1), sin `Color` ni `UIColor`, para poder medirla en tests.
//

import Foundation

// MARK: - Color en RGB

nonisolated struct CardRGB: Equatable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    static let white = CardRGB(red: 1, green: 1, blue: 1)
    /// El «negro» del texto oscuro: casi negro, un pelo azulado como el resto de la app.
    static let ink = CardRGB(red: 0.07, green: 0.08, blue: 0.10)
    static let black = CardRGB(red: 0, green: 0, blue: 0)

    init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    /// «#RRGGBB» (con o sin «#»). `nil` si no lo es.
    init?(hex: String) {
        guard let clean = CardDesignLogic.sanitizedHex(hex) else { return nil }
        let digits = clean.dropFirst()
        guard let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hex: String {
        String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded())
        )
    }

    /// Mezcla con otro color: `amount` 0 = este, 1 = el otro.
    func mixed(with other: CardRGB, _ amount: Double) -> CardRGB {
        let t = min(max(amount, 0), 1)
        return CardRGB(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t
        )
    }

    func lightened(_ amount: Double) -> CardRGB { mixed(with: .white, amount) }
    func darkened(_ amount: Double) -> CardRGB { mixed(with: .black, amount) }

    /// Luminancia relativa de WCAG 2.x.
    var relativeLuminance: Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// Contraste de WCAG entre dos colores (1…21).
    func contrast(with other: CardRGB) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

// MARK: - Acabado

/// Lo que se pone encima del degradado, además del patrón.
nonisolated enum CardFinish: String, Sendable {
    /// Solo el degradado.
    case flat
    /// Una franja de brillo en diagonal, como el metal pulido.
    case metallic
    /// Un halo claro en la esquina de arriba a la derecha.
    case glow

    /// Cuánto aclara el fondo, como mucho, donde pasa el brillo.
    var highlightOpacity: Double {
        switch self {
        case .flat: return 0
        case .metallic: return 0.22
        case .glow: return 0.18
        }
    }
}

// MARK: - Lo que se pinta

nonisolated struct CardLook: Equatable, Sendable {
    /// De arriba a la izquierda a abajo a la derecha. Siempre 2 o más.
    let stops: [CardRGB]
    let foreground: CardRGB
    let pattern: CardPattern
    let finish: CardFinish
    let iconName: String
    let showsChip: Bool
    /// El chip va plateado sobre las plantillas plateadas y frías; dorado en el resto.
    let silverChip: Bool
    let lastFour: String?

    /// `true` si el texto es claro (fondo oscuro).
    var hasLightText: Bool { foreground == .white }

    /// Opacidad del texto secundario (rótulos, subtítulo, el equivalente en otra moneda).
    static let secondaryOpacity = 0.85
    /// Opacidad a la que `AmountText` pinta el símbolo y los decimales.
    static let amountFractionOpacity = 0.6
    /// Opacidad del patrón (en el color del texto).
    static let patternOpacity = 0.11
    /// Contraste mínimo del texto principal y del secundario (AA, texto normal).
    static let minimumTextContrast = 4.5
    /// Contraste mínimo del símbolo y los decimales del importe, que van en grande (AA, texto grande).
    static let minimumLargeTextContrast = 3.0
}

// MARK: - Resolución

nonisolated enum CardLookLogic {

    /// Lo que se pinta para una cuenta con ese diseño.
    /// - Parameters:
    ///   - accountColorHex: el color de la cuenta (lo usa «Tu color» y el selector «El de tu cuenta»).
    ///   - accountIconName: el ícono de la cuenta, si el diseño no trae uno propio.
    static func look(
        for design: CardDesign, type: AccountType, accountColorHex: String, accountIconName: String
    ) -> CardLook {
        let template = CardTemplateCatalog.template(id: design.templateID)
        let accountColor = CardRGB(hex: accountColorHex) ?? CardRGB(hex: "#6366F1") ?? .ink
        let rawStops: [CardRGB] = {
            if let custom = design.colorHex.flatMap(CardRGB.init(hex:)) {
                return template.recipe.stops(from: custom)
            }
            if template.usesAccountColor {
                return template.recipe.stops(from: accountColor)
            }
            return template.stops
        }()
        let pattern = design.pattern ?? (template.usesAccountColor ? CardDesignLogic.defaultPattern(type: type) : template.pattern)
        let readable = readableStops(rawStops, finish: template.finish, pattern: pattern)
        let icon = design.iconName.flatMap { $0.isEmpty ? nil : $0 } ?? accountIconName
        return CardLook(
            stops: readable.stops,
            foreground: readable.foreground,
            pattern: pattern,
            finish: template.finish,
            iconName: icon,
            showsChip: design.showsChip,
            silverChip: template.silverChip,
            lastFour: CardDesignLogic.sanitizedLastFour(design.lastFour)
        )
    }

    /// La tarjeta de las cuentas de sistema de Grupos: grafito neutro, sin chip, sin dígitos. No se diseña.
    static func systemLook(iconName: String) -> CardLook {
        let template = CardTemplateCatalog.template(id: "graphite")
        let readable = readableStops(template.stops, finish: template.finish, pattern: .none)
        return CardLook(
            stops: readable.stops, foreground: readable.foreground, pattern: .none, finish: template.finish,
            iconName: iconName, showsChip: false, silverChip: true, lastFour: nil
        )
    }

    // MARK: Contraste

    /// Los fondos contra los que se lee el texto en un punto del degradado: el color tal cual, con el patrón encima (en
    /// el color del texto) y con el brillo del acabado.
    static func backgroundsToCheck(stop: CardRGB, foreground: CardRGB, finish: CardFinish, pattern: CardPattern)
        -> [CardRGB]
    {
        var result = [stop]
        let patternOpacity = pattern == .none ? 0 : CardLook.patternOpacity
        if patternOpacity > 0 { result.append(stop.mixed(with: foreground, patternOpacity)) }
        if finish.highlightOpacity > 0 {
            let lit = stop.mixed(with: .white, finish.highlightOpacity)
            result.append(lit)
            if patternOpacity > 0 { result.append(lit.mixed(with: foreground, patternOpacity)) }
        }
        return result
    }

    /// El peor contraste que tendrían el texto, el secundario y los decimales del importe sobre ese punto del fondo,
    /// cada uno normalizado por su mínimo (≥ 1 = pasa).
    static func worstScore(stop: CardRGB, foreground: CardRGB, finish: CardFinish, pattern: CardPattern) -> Double {
        var worst = Double.infinity
        for background in backgroundsToCheck(stop: stop, foreground: foreground, finish: finish, pattern: pattern) {
            let primary = foreground.contrast(with: background) / CardLook.minimumTextContrast
            let secondaryColor = background.mixed(with: foreground, CardLook.secondaryOpacity)
            let secondary = secondaryColor.contrast(with: background) / CardLook.minimumTextContrast
            let fractionColor = background.mixed(with: foreground, CardLook.amountFractionOpacity)
            let fraction = fractionColor.contrast(with: background) / CardLook.minimumLargeTextContrast
            worst = min(worst, primary, secondary, fraction)
        }
        return worst
    }

    /// Elige el color del texto que mejor se lee y, si algún punto del fondo no llega, lo oscurece (texto claro) o lo
    /// aclara (texto oscuro) a pasos pequeños hasta que llegue. Siempre termina: el negro con texto blanco y el blanco con
    /// texto casi negro pasan con margen.
    static func readableStops(_ stops: [CardRGB], finish: CardFinish, pattern: CardPattern)
        -> (stops: [CardRGB], foreground: CardRGB)
    {
        let base: [CardRGB] = {
            if stops.count >= 2 { return stops }
            let only = stops.first ?? .ink
            return [only, only]
        }()
        func minimumScore(_ fg: CardRGB) -> Double {
            base.map { worstScore(stop: $0, foreground: fg, finish: finish, pattern: pattern) }.min() ?? 0
        }
        let foreground: CardRGB = minimumScore(.white) >= minimumScore(.ink) ? .white : .ink
        let adjusted = base.map { stop -> CardRGB in
            var current = stop
            var step = 0
            while worstScore(stop: current, foreground: foreground, finish: finish, pattern: pattern) < 1, step < 40 {
                current = foreground == .white ? current.darkened(0.05) : current.lightened(0.05)
                step += 1
            }
            return current
        }
        return (adjusted, foreground)
    }
}

// MARK: - Textos de la cara de la tarjeta

enum CardFaceText {
    /// «•••• 1256»; con «Ocultar montos», «•••• ••••»: los dígitos de una tarjeta tampoco se enseñan a quien mira.
    static func maskedDigits(_ digits: String, hidden: Bool) -> String {
        hidden ? "•••• ••••" : "•••• \(digits)"
    }

    /// Lo que lee VoiceOver: lo de siempre (nombre y saldo) y, si hay dígitos y no están ocultos, «terminada en 1256».
    /// Nada del adorno (plantilla, patrón, chip).
    static func spokenSummary(_ base: String, lastFour: String?, hidden: Bool) -> String {
        guard let lastFour, !hidden else { return base }
        return "\(base). \(L10n.DisenoTarjeta.endingIn(lastFour))"
    }
}
