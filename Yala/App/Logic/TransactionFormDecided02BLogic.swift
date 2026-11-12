//
//  TransactionFormDecided02BLogic.swift
//  Yala
//
//  Lógica pura del lote decidido 2.2 · 02, sesión B (decisiones de Jürgen del 14 y el 21-oct): el buscador de la hoja
//  de categoría (L2-3), la pista de los atajos (L2-8), los textos de «Mi parte» (L2-12 y L2-17), la pregunta del monto
//  (L2-16) y el relleno de lo elegido con contraste AA (L2-19). Sin SwiftUI ni SwiftData, para fijarla con tests.
//

import Foundation

// MARK: - L2-3 · Buscar una categoría

/// Busca en el nombre de la categoría y en el de su grupo, sin distinguir tildes ni mayúsculas: «alimentacion» trae todo
/// Alimentación y «tax» trae «Taxis y apps». Sin sinónimos (decisión de Jürgen: después, con datos).
enum CategorySearchLogic {

    /// El texto como lo compara el buscador: sin tildes, sin mayúsculas y sin espacios en los extremos.
    static func folded(_ text: String, locale: Locale = .current) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: locale)
    }

    /// ¿La categoría `name`, del grupo `groupName`, sale con lo escrito? Lo vacío lo trae todo.
    static func matches(query: String, name: String, groupName: String, locale: Locale = .current) -> Bool {
        let needle = folded(query, locale: locale)
        guard !needle.isEmpty else { return true }
        return folded(name, locale: locale).contains(needle) || folded(groupName, locale: locale).contains(needle)
    }

    /// Los grupos con lo que queda de cada uno. Un grupo cuyo nombre casa trae todas sus categorías; si no, solo las que
    /// casan por su nombre. Los grupos vacíos desaparecen. Con la búsqueda vacía, todo tal cual.
    static func filter<Group, Item>(
        _ groups: [(category: Group, subcategories: [Item])],
        query: String,
        groupName: (Group) -> String,
        itemName: (Item) -> String,
        locale: Locale = .current
    ) -> [(category: Group, subcategories: [Item])] {
        guard !folded(query, locale: locale).isEmpty else { return groups }
        return groups.compactMap { group in
            let parent = groupName(group.category)
            let kept = group.subcategories.filter {
                matches(query: query, name: itemName($0), groupName: parent, locale: locale)
            }
            return kept.isEmpty ? nil : (category: group.category, subcategories: kept)
        }
    }
}

// MARK: - L2-8 · La pista de los atajos

/// La pista bajo la descripción rota entre los tres atajos (! categoría, # etiqueta, @ cuenta), una por apertura del
/// formulario, y desaparece tras 6 aperturas (dos por atajo) o en cuanto la persona usa uno.
enum DescriptionShortcutHintLogic {

    enum Shortcut: String, CaseIterable {
        case category, tag, account

        var hint: String {
            switch self {
            case .category: return L10n.UXL2B.hintCategory
            case .tag: return L10n.UXL2B.hintTag
            case .account: return L10n.UXL2B.hintAccount
            }
        }
    }

    static let maxOpenings = 6
    /// Cuántas aperturas ya enseñaron la pista. Se borra con «Vaciar datos» (`DataWipeService`).
    static let openingsKey = "l2d.descriptionHint.openings"
    /// La persona ya usó un atajo: la pista no vuelve.
    static let usedKey = "l2d.descriptionHint.used"

    /// La pista de la apertura número `openingsSoFar` (empieza en 0), o `nil` si ya no toca.
    static func shortcut(openingsSoFar: Int, usedShortcut: Bool) -> Shortcut? {
        guard !usedShortcut, openingsSoFar >= 0, openingsSoFar < maxOpenings else { return nil }
        return Shortcut.allCases[openingsSoFar % Shortcut.allCases.count]
    }

    /// Cuenta una apertura y devuelve la pista que le toca. Sin pista no cuenta (ya no hace falta).
    static func registerOpening(defaults: UserDefaults = .standard) -> Shortcut? {
        let count = defaults.integer(forKey: openingsKey)
        guard let shortcut = shortcut(openingsSoFar: count, usedShortcut: defaults.bool(forKey: usedKey)) else {
            return nil
        }
        defaults.set(count + 1, forKey: openingsKey)
        return shortcut
    }

    static func markShortcutUsed(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: usedKey)
    }
}

// MARK: - L2-12 y L2-17 · Mi parte

/// Los textos de «Mi parte»: el chip del formulario, la fórmula del resultado y la barra tú / los demás. Los importes
/// llegan ya formateados con su moneda (`format`), así que aquí solo se decide qué frase va con cada modo.
enum SplitSummaryLogic {

    /// El modo con el que abre la hoja: «Iguales» la primera vez y, después, el último usado (`lastSplitType`).
    static func initialType(lastUsedRaw: String?) -> SplitType {
        lastUsedRaw.flatMap(SplitType.init(rawValue:)) ?? .equal
    }

    /// Lo que ponen los demás: el total menos tu parte, nunca negativo.
    static func othersAmount(total: Double, mine: Double) -> Double {
        max(total - mine, 0)
    }

    /// «60» o «62.5»: el porcentaje sin decimales de relleno.
    static func percentText(_ value: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// El chip del formulario: «Tu parte de S/ 120.00 · ÷ 3 personas», «· 60 %», «· 2 de 5 partes», «· monto exacto».
    static func chipText(
        type: SplitType,
        total: Double,
        myValue: Double,
        divisor: Double?,
        format: (Double) -> String
    ) -> String {
        let totalText = format(total)
        switch type {
        case .equal:
            return L10n.UXL2B.splitChipEqual(total: totalText, people: Int(myValue))
        case .percentage:
            return L10n.UXL2B.splitChipPercentage(total: totalText, percent: percentText(myValue))
        case .shares:
            return L10n.UXL2B.splitChipShares(total: totalText, mine: Int(myValue), of: Int(divisor ?? 0))
        case .exact:
            return L10n.UXL2B.splitChipExact(total: totalText)
        }
    }

    /// La fórmula bajo «Te toca pagar»: «S/ 120.00 ÷ 3 personas = S/ 40.00 cada una», «60 % de S/ 120.00»,
    /// «2 de 5 partes de S/ 120.00», «S/ 40.00 de S/ 120.00».
    static func formula(
        type: SplitType,
        total: Double,
        mine: Double,
        myValue: Double,
        divisor: Double?,
        format: (Double) -> String
    ) -> String {
        switch type {
        case .equal:
            return L10n.UXL2B.splitFormulaEqual(total: format(total), people: Int(myValue), each: format(mine))
        case .percentage:
            return L10n.UXL2B.splitFormulaPercentage(percent: percentText(myValue), total: format(total))
        case .shares:
            return L10n.UXL2B.splitFormulaShares(mine: Int(myValue), of: Int(divisor ?? 0), total: format(total))
        case .exact:
            return L10n.UXL2B.splitFormulaExact(mine: format(mine), total: format(total))
        }
    }

    /// La parte de la barra que es tuya (0…1).
    static func myFraction(total: Double, mine: Double) -> Double {
        guard total > 0 else { return 0 }
        return min(max(mine / total, 0), 1)
    }
}

// MARK: - L2-16 · La pregunta del monto

enum AmountQuestionLogic {
    static func question(for type: TransactionType) -> String {
        switch type {
        case .expense: return L10n.UXL2B.questionExpense
        case .income: return L10n.UXL2B.questionIncome
        case .transfer: return L10n.UXL2B.questionTransfer
        }
    }
}

// MARK: - L2-19 · Lo elegido, relleno y con texto blanco AA

/// El relleno de un chip o una fila elegida: el color de la cuenta, categoría, necesidad o etiqueta, oscurecido lo justo
/// para que el texto blanco encima dé al menos 4,5:1 (WCAG AA). Un color que ya llega se queda tal cual.
enum SelectedFillContrast {

    struct RGB: Equatable {
        var red: Double
        var green: Double
        var blue: Double
    }

    static let minimumContrast = 4.5

    /// «#FF9F0A», «FF9F0A» o «#F90» → componentes 0…1. `nil` si no se deja leer.
    static func rgb(fromHex hex: String) -> RGB? {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        if text.count == 3 { text = text.map { "\($0)\($0)" }.joined() }
        guard text.count == 6 || text.count == 8, let value = UInt64(text.prefix(6), radix: 16) else { return nil }
        return RGB(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// Luminancia relativa WCAG 2.x.
    static func luminance(_ color: RGB) -> Double {
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.red) + 0.7152 * channel(color.green) + 0.0722 * channel(color.blue)
    }

    /// Contraste del blanco sobre `color`.
    static func whiteContrast(on color: RGB) -> Double {
        1.05 / (luminance(color) + 0.05)
    }

    /// `color` mezclado con negro a pasos de 2 % hasta que el blanco encima llegue a `minimum`.
    static func fill(for color: RGB, minimum: Double = minimumContrast) -> RGB {
        var mixed = color
        var step = 0
        while whiteContrast(on: mixed) < minimum && step < 50 {
            step += 1
            let keep = 1 - Double(step) * 0.02
            mixed = RGB(red: color.red * keep, green: color.green * keep, blue: color.blue * keep)
        }
        return mixed
    }
}

// MARK: - L2-11 · La tasa escrita a mano

/// Cuándo un gasto o ingreso en otra divisa se guarda con la tasa que la persona escribió en la cápsula, y cómo.
enum ForeignManualRateLogic {

    /// La tasa a usar, o `nil` para convertir como siempre. Solo si se escribió a mano, no es una transferencia (cada
    /// pata va en su divisa) y el importe no está ya en la preferida.
    static func manualRate(
        isManual: Bool,
        isTransfer: Bool,
        rate: Double,
        amountCurrency: String,
        preferredCurrency: String
    ) -> Double? {
        guard isManual, !isTransfer, rate.isFinite, rate > 0,
              normalizeCurrencyCode(amountCurrency) != normalizeCurrencyCode(preferredCurrency) else { return nil }
        return rate
    }

    /// El importe en la preferida con esa tasa, en `Decimal` para no arrastrar el error del `Double`.
    static func converted(_ amount: Double, rate: Double) -> Decimal {
        Decimal(string: String(amount)).map { $0 * (Decimal(string: String(rate)) ?? Decimal(rate)) } ?? Decimal(amount * rate)
    }
}
