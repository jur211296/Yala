//
//  GroupSplitLinesRecipe.swift
//  Yala
//
//  Grupos, opción B acordada con Jürgen el 2026-11-01 (`docs/disenos/grupos-tu-parte-en-lineas/README.md`, «Versión
//  final acordada»): tu parte de un gasto de grupo se puede partir en LÍNEAS. Cada línea es un gasto con su categoría
//  o una recarga a una cuenta tuya (S/ 510 que pagó Pía = 500 que pasan a Sip + 10 de comisión). Las líneas tienen que
//  sumar tu parte.
//
//  Esto son solo las REGLAS de la receta: cómo se guarda, cómo se lee, si cuadra y qué línea está mal. Quién la aplica
//  (el puente, que deriva de ella tus registros en cada pasada) está en `tickets/in-progress/grupos-tu-parte-en-lineas.md`.
//
//  DÓNDE VIVE. En una sola columna de texto de `TransactionItem` (`splitLinesRaw`, card 1), con dos formas:
//   · la RECETA, en la pata que el puente conserva: `{"l":[{"a":"10","i":…,"k":"e","s":…}, …],"v":1}`;
//   · la MARCA de pata derivada, en cada pata que el puente fabrica a partir de una línea: `{"of":"<id línea>","v":1}`.
//  Una columna y no dos porque el manifest personal versiona columnas, y una pata nunca es las dos cosas a la vez.
//
//  DINERO EN `Decimal`, GUARDADO COMO TEXTO. «500» + «10» tienen que dar exactamente «510»: con `Double` la suma de
//  líneas tecleadas puede quedarse a una diezmilésima del total y apagar «Guardar» sin motivo visible. El importe viaja
//  como cadena (`"10.5"`) para que ni `JSONEncoder` ni otro aparato lo pasen por `Double`.
//
//  REFERENCIAS POR IDENTIDAD DE SYNC. La categoría y la cuenta destino se guardan por su `shortcutID`, que es la
//  identidad con la que viajan entre aparatos (Modo Nube e iCloud). Un `PersistentIdentifier` no sobrevive al viaje.
//
//  UNA VERSIÓN QUE NO SE ENTIENDE NO SE PISA. Una receta con `v` mayor que la que conoce este build se lee como
//  `.newerVersion`: el puente la deja como está en vez de rehacer tu parte en una línea y borrar lo que otro aparato
//  más nuevo escribió.
//
//  Lógica pura: sin SwiftData. Sin `nonisolated` porque los decimales de cada divisa los da
//  `AccountCurrencyPlanLogic.fractionDigits`, del actor principal como el puente y las pantallas que la usan.
//

import Foundation

enum GroupSplitLinesRecipe {

    /// La versión de la receta que este build escribe y entiende.
    static let currentVersion = 1

    // MARK: - Tipos

    /// Qué es una línea: un gasto con su categoría o una recarga a una cuenta tuya.
    enum Kind: String, Equatable, Sendable {
        case expense = "e"
        case transfer = "t"
    }

    struct Line: Equatable, Sendable, Identifiable {
        let id: UUID
        let kind: Kind
        /// Siempre positivo: es una parte de tu parte, no un movimiento con signo.
        let amount: Decimal
        /// `shortcutID` de la subcategoría. Obligatorio en un gasto; `nil` en una recarga.
        let subcategoryID: UUID?
        /// `shortcutID` de la cuenta a la que va la recarga. Obligatorio en una recarga; `nil` en un gasto.
        let destinationAccountID: UUID?

        static func expense(id: UUID = UUID(), amount: Decimal, subcategoryID: UUID?) -> Line {
            Line(id: id, kind: .expense, amount: amount, subcategoryID: subcategoryID, destinationAccountID: nil)
        }

        static func transfer(id: UUID = UUID(), amount: Decimal, destinationAccountID: UUID?) -> Line {
            Line(id: id, kind: .transfer, amount: amount, subcategoryID: nil, destinationAccountID: destinationAccountID)
        }
    }

    /// Lo que hay guardado en `splitLinesRaw`.
    enum Stored: Equatable, Sendable {
        /// Nada: tu parte es una sola línea, como siempre.
        case none
        /// La receta, en la pata que el puente conserva.
        case recipe([Line])
        /// Marca de una pata que el puente fabricó a partir de la línea `lineID`.
        case derived(lineID: UUID)
        /// Una versión posterior a la de este build. No se toca.
        case newerVersion
        /// Texto que no se entiende. El puente no lo da por bueno ni lo borra.
        case unreadable
    }

    /// Si las líneas suman tu parte, redondeado a los decimales de la divisa.
    enum Balance: Equatable, Sendable {
        case balanced
        /// Faltan tantos para llegar a tu parte («Faltan S/ 10.00»).
        case missing(Decimal)
        /// Las líneas pasan de tu parte en tanto.
        case over(Decimal)
    }

    /// Lo que impide guardar una línea.
    enum Problem: Equatable, Sendable {
        /// Importe cero, negativo o que no es un número.
        case nonPositiveAmount(lineID: UUID)
        /// Importe con más decimales de los que tiene la divisa (10.005 soles).
        case tooManyDecimals(lineID: UUID)
        case expenseWithoutSubcategory(lineID: UUID)
        case transferWithoutDestination(lineID: UUID)
        /// Dos líneas con el mismo id: la marca de las patas derivadas no sabría de cuál vienen.
        case duplicateID(lineID: UUID)
        case noLines
    }

    // MARK: - Reglas

    /// Lo que impide guardar estas líneas, en el orden de las líneas. Vacío = se pueden guardar si además cuadran.
    static func problems(in lines: [Line], currencyCode: String) -> [Problem] {
        guard !lines.isEmpty else { return [.noLines] }
        let digits = AccountCurrencyPlanLogic.fractionDigits(for: currencyCode)
        var seen: Set<UUID> = []
        var result: [Problem] = []
        for line in lines {
            if !seen.insert(line.id).inserted { result.append(.duplicateID(lineID: line.id)) }
            if line.amount.isNaN || line.amount <= 0 {
                result.append(.nonPositiveAmount(lineID: line.id))
            } else if rounded(line.amount, digits: digits) != line.amount {
                result.append(.tooManyDecimals(lineID: line.id))
            }
            switch line.kind {
            case .expense where line.subcategoryID == nil:
                result.append(.expenseWithoutSubcategory(lineID: line.id))
            case .transfer where line.destinationAccountID == nil:
                result.append(.transferWithoutDestination(lineID: line.id))
            default:
                break
            }
        }
        return result
    }

    /// Si `lines` suman `share` (tu parte), comparando con los decimales de la divisa. `share` llega del reparto y puede
    /// traer más decimales (511/3 = 170.333…): se redondea igual que lo que la persona ve.
    static func balance(of lines: [Line], share: Decimal, currencyCode: String) -> Balance {
        let digits = AccountCurrencyPlanLogic.fractionDigits(for: currencyCode)
        let total = lines.reduce(Decimal(0)) { $0 + $1.amount }
        let difference = rounded(share, digits: digits) - rounded(total, digits: digits)
        if difference == 0 { return .balanced }
        return difference > 0 ? .missing(difference) : .over(-difference)
    }

    /// «Guardar» / «Aprobar» se encienden: ninguna línea tiene problemas y suman tu parte.
    static func canSave(_ lines: [Line], share: Decimal, currencyCode: String) -> Bool {
        problems(in: lines, currencyCode: currencyCode).isEmpty
            && balance(of: lines, share: share, currencyCode: currencyCode) == .balanced
    }

    /// `true` si estas líneas son lo mismo que no partir: un solo gasto. Entonces no se guarda receta y la categoría de
    /// esa línea va a la pata como hoy. Una sola RECARGA sí es una receta (Pía recarga 500 a Sip sin comisión).
    static func isSingleExpense(_ lines: [Line]) -> Bool {
        lines.count == 1 && lines[0].kind == .expense
    }

    // MARK: - Guardar y leer

    /// El texto de la receta. `nil` si no hay nada que guardar: sin líneas, o una sola línea de gasto (es lo de siempre,
    /// y un opcional a `nil` no viaja a iCloud ni a la nube). No valida: guarda lo que le dan, y quien llama comprueba
    /// antes con `canSave`.
    static func encode(_ lines: [Line]) -> String? {
        guard !lines.isEmpty, !isSingleExpense(lines) else { return nil }
        return encodeJSON(WireRecipe(v: currentVersion, l: lines.map { WireLine($0) }))
    }

    /// La marca de una pata derivada de la línea `lineID`.
    static func encodeDerivedMarker(lineID: UUID) -> String {
        encodeJSON(WireMarker(v: currentVersion, of: lineID.uuidString)) ?? ""
    }

    /// Lee `splitLinesRaw`. Nunca lanza: lo que no se entiende es `.unreadable` y lo de una versión posterior,
    /// `.newerVersion`.
    static func parse(_ raw: String?) -> Stored {
        guard let raw, !raw.isEmpty else { return .none }
        guard let data = raw.data(using: .utf8) else { return .unreadable }
        let decoder = JSONDecoder()

        // La versión, sola y primero: una receta posterior puede traer líneas con otra forma, y leerlas con la de hoy
        // la daría por ilegible en vez de por nueva.
        let version: Int
        do {
            version = try decoder.decode(WireVersion.self, from: data).v
        } catch {
            return .unreadable
        }
        guard version >= 1 else { return .unreadable }
        guard version <= currentVersion else { return .newerVersion }

        let header: WireHeader
        do {
            header = try decoder.decode(WireHeader.self, from: data)
        } catch {
            return .unreadable
        }

        // Una marca lleva `of`; una receta, `l`. Con los dos (o ninguno) no se adivina.
        switch (header.of, header.l) {
        case let (.some(of), nil):
            guard let id = UUID(uuidString: of) else { return .unreadable }
            return .derived(lineID: id)
        case let (nil, .some(wireLines)):
            var lines: [Line] = []
            for wire in wireLines {
                guard let line = wire.line else { return .unreadable }
                lines.append(line)
            }
            return lines.isEmpty ? .unreadable : .recipe(lines)
        default:
            return .unreadable
        }
    }

    // MARK: - Formato en el cable

    private struct WireVersion: Decodable { let v: Int }

    private struct WireHeader: Decodable {
        let of: String?
        let l: [WireLine]?
    }

    private struct WireMarker: Encodable {
        let v: Int
        let of: String
    }

    private struct WireRecipe: Encodable {
        let v: Int
        let l: [WireLine]
    }

    private struct WireLine: Codable {
        let i: String
        let k: String
        let a: String
        let s: String?
        let d: String?

        init(_ line: Line) {
            i = line.id.uuidString
            k = line.kind.rawValue
            a = NSDecimalNumber(decimal: line.amount).stringValue
            s = line.subcategoryID?.uuidString
            d = line.destinationAccountID?.uuidString
        }

        /// `nil` si algún campo no se entiende: una línea a medias no se adivina.
        var line: Line? {
            guard let id = UUID(uuidString: i),
                  let kind = Kind(rawValue: k),
                  let amount = Decimal(string: a, locale: Locale(identifier: "en_US_POSIX")),
                  !amount.isNaN
            else { return nil }
            var subcategory: UUID?
            if let s {
                guard let parsed = UUID(uuidString: s) else { return nil }
                subcategory = parsed
            }
            var destination: UUID?
            if let d {
                guard let parsed = UUID(uuidString: d) else { return nil }
                destination = parsed
            }
            return Line(id: id, kind: kind, amount: amount, subcategoryID: subcategory, destinationAccountID: destination)
        }
    }

    private static func encodeJSON<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(value)
            return String(data: data, encoding: .utf8)
        } catch {
            #if DEBUG
            print("GroupSplitLinesRecipe: Error: \(error)")
            #endif
            return nil
        }
    }

    private static func rounded(_ value: Decimal, digits: Int) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, digits, .plain)
        return result
    }
}
