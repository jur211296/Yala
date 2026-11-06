//
//  ReceiptSplitLogic.swift
//  Yala
//
//  Repartir un recibo por líneas en un gasto de grupo (card «Grupos: repartir un recibo con IA», 2.3).
//
//  La IA lee las líneas del recibo y una frase de quién comió qué; esto decide, sin IA, cuánto le toca a cada uno.
//  El resultado es un gasto de grupo normal con importes exactos por persona: las líneas no se guardan.
//
//  Tres reglas que fijan los tests (`ReceiptSplitLogicTests`):
//  - Se calcula en céntimos enteros y la suma de las partes es SIEMPRE el total de lo incluido: el céntimo que sobra de
//    partir 10,00 entre tres va al primero en el orden de los miembros.
//  - Una línea de consumo sin nadie asignado es «entre todos»: los que aparecen en alguna línea, o todo el grupo si
//    nadie aparece.
//  - Propina, servicio, impuestos y descuentos NO se reparten solos (Jürgen, 2026-11-05): llegan sin incluir y la
//    persona elige cómo (`ReceiptExtraShare`).
//

import Foundation

/// Qué es una línea del recibo. Lo que no es consumo se reparte aparte (`ReceiptSplitLogic.shares`).
nonisolated enum ReceiptLineKind: String, Codable, CaseIterable, Sendable {
    case item, tip, tax, service, discount

    /// Propina, servicio, impuestos o descuento: no es de nadie en concreto y se incluye a mano.
    var isExtra: Bool { self != .item }
}

/// Cómo entra en el gasto una línea de propina, servicio, impuestos o descuento. Nace `.excluded`: Jürgen decidió que
/// no se repartan solas (2026-11-05). Para una línea de consumo no se usa.
nonisolated enum ReceiptExtraShare: String, CaseIterable, Sendable {
    /// Fuera del gasto.
    case excluded
    /// En proporción a lo que consumió cada uno de los que comen.
    case proportional
    /// A partes iguales entre los que comen.
    case equal
    /// A partes iguales entre los asignados de la línea (sin ninguno, fuera del gasto).
    case people
}

/// Una línea del recibo en la revisión. `amount` siempre en positivo; un descuento resta por su `kind`.
nonisolated struct ReceiptSplitLine: Identifiable, Equatable, Sendable {
    let id: UUID
    var description: String
    var amount: Double
    var kind: ReceiptLineKind
    /// Ids de miembro (`SplitMember.id.uuidString`). En consumo, vacío = entre todos; en un extra, solo con `.people`.
    var assignees: Set<String>
    /// Solo para extras: cómo entra en el gasto.
    var extraShare: ReceiptExtraShare
    /// La frase nombró en esta línea a alguien que no es del grupo: queda «entre todos» y la revisión la marca hasta
    /// que la persona elija quién la paga.
    var needsReview: Bool

    init(
        id: UUID = UUID(),
        description: String,
        amount: Double,
        kind: ReceiptLineKind,
        assignees: Set<String> = [],
        extraShare: ReceiptExtraShare = .excluded,
        needsReview: Bool = false
    ) {
        self.id = id
        self.description = description
        self.amount = amount
        self.kind = kind
        self.assignees = assignees
        self.extraShare = extraShare
        self.needsReview = needsReview
    }

    /// Si la línea cuenta en el gasto: el consumo siempre; un extra, si la persona lo incluyó.
    var isIncluded: Bool {
        guard kind.isExtra else { return true }
        switch extraShare {
        case .excluded: return false
        case .people: return !assignees.isEmpty
        case .proportional, .equal: return true
        }
    }
}

nonisolated enum ReceiptSplitLogic {

    static func cents(_ amount: Double) -> Int { Int((abs(amount) * 100).rounded()) }

    /// Lo que suma una línea con su signo, en céntimos: un descuento resta.
    static func signedCents(_ line: ReceiptSplitLine) -> Int {
        line.kind == .discount ? -cents(line.amount) : cents(line.amount)
    }

    /// Lo que suma el gasto: el consumo y los extras incluidos (un descuento resta). En céntimos.
    static func totalCents(_ lines: [ReceiptSplitLine]) -> Int {
        lines.filter(\.isIncluded).reduce(0) { $0 + signedCents($1) }
    }

    static func total(_ lines: [ReceiptSplitLine]) -> Double { Double(totalCents(lines)) / 100 }

    /// Lo que suman TODAS las líneas leídas, incluidas o no: es lo que se compara con el total impreso.
    static func readTotal(_ lines: [ReceiptSplitLine]) -> Double {
        Double(lines.reduce(0) { $0 + signedCents($1) }) / 100
    }

    /// Una propina o un servicio que no venía en el recibo: `percent` % del consumo, con el reparto que la persona
    /// eligió en el atajo (nunca uno por defecto: Jürgen, 2026-11-05).
    static func surcharge(
        kind: ReceiptLineKind,
        percent: Int,
        description: String,
        share: ReceiptExtraShare,
        lines: [ReceiptSplitLine]
    ) -> ReceiptSplitLine {
        let consumption = lines.filter { !$0.kind.isExtra }.reduce(0) { $0 + cents($1.amount) }
        let value = (Double(consumption) * Double(percent) / 100).rounded() / 100
        return ReceiptSplitLine(description: description, amount: value, kind: kind, extraShare: share)
    }

    /// Quiénes comen: los asignados a alguna línea de consumo, en el orden de `memberIDs`. Si nadie, el grupo entero.
    static func diners(_ lines: [ReceiptSplitLine], memberIDs: [String]) -> [String] {
        let named = Set(lines.filter { !$0.kind.isExtra }.flatMap(\.assignees))
        let ordered = memberIDs.filter { named.contains($0) }
        return ordered.isEmpty ? memberIDs : ordered
    }

    /// Quién paga una línea de consumo: sus asignados (en el orden del grupo) o, sin nadie, los que comen.
    static func payers(of line: ReceiptSplitLine, diners: [String], memberIDs: [String]) -> [String] {
        let assigned = memberIDs.filter { line.assignees.contains($0) }
        return assigned.isEmpty ? diners : assigned
    }

    /// Cuánto le toca a cada uno, en el orden de `memberIDs`, sin los que quedan a cero. La suma es el total exacto.
    /// Un total que no es positivo (descuentos mayores que el consumo) no se reparte: devuelve vacío.
    static func shares(_ lines: [ReceiptSplitLine], memberIDs: [String]) -> [(memberID: String, amount: Double)] {
        guard !memberIDs.isEmpty, totalCents(lines) > 0 else { return [] }
        let diners = diners(lines, memberIDs: memberIDs)
        var consumed: [String: Int] = [:]
        for line in lines where !line.kind.isExtra {
            let payers = payers(of: line, diners: diners, memberIDs: memberIDs)
            for (id, part) in zip(payers, evenSplit(cents(line.amount), parts: payers.count)) {
                consumed[id, default: 0] += part
            }
        }
        var result = consumed
        for line in lines where line.kind.isExtra && line.isIncluded {
            let value = signedCents(line)
            let targets: [String]
            let parts: [Int]
            switch line.extraShare {
            case .excluded:
                continue
            case .proportional:
                targets = diners
                parts = proportionalSplit(value, weights: diners.map { consumed[$0] ?? 0 })
            case .equal:
                targets = diners
                parts = evenSplit(value, parts: diners.count)
            case .people:
                targets = memberIDs.filter { line.assignees.contains($0) }
                parts = evenSplit(value, parts: targets.count)
            }
            for (id, part) in zip(targets, parts) { result[id, default: 0] += part }
        }
        return memberIDs.compactMap { id in
            guard let value = result[id], value != 0 else { return nil }
            return (id, Double(value) / 100)
        }
    }

    /// Parte `total` céntimos en `parts` trozos que se diferencian como mucho en uno; los de más, a los primeros.
    static func evenSplit(_ total: Int, parts: Int) -> [Int] {
        guard parts > 0 else { return [] }
        let magnitude = abs(total)
        let base = magnitude / parts
        let remainder = magnitude - base * parts
        let split = (0..<parts).map { base + ($0 < remainder ? 1 : 0) }
        return total < 0 ? split.map { -$0 } : split
    }

    /// Reparte `total` céntimos en proporción a `weights` por el mayor resto: la suma es exactamente `total`.
    /// Sin pesos (nadie consumió nada), a partes iguales.
    static func proportionalSplit(_ total: Int, weights: [Int]) -> [Int] {
        let sum = weights.reduce(0, +)
        guard sum > 0 else { return evenSplit(total, parts: weights.count) }
        let magnitude = abs(total)
        let exact = weights.map { Double(magnitude) * Double($0) / Double(sum) }
        var parts = exact.map { Int($0.rounded(.down)) }
        let missing = magnitude - parts.reduce(0, +)
        let order = exact.indices.sorted { lhs, rhs in
            let left = exact[lhs] - exact[lhs].rounded(.down)
            let right = exact[rhs] - exact[rhs].rounded(.down)
            return left == right ? lhs < rhs : left > right
        }
        for index in order.prefix(missing) { parts[index] += 1 }
        return total < 0 ? parts.map { -$0 } : parts
    }

    /// Un descuento incluido puede dejar a alguien por debajo de cero (Ana consumió 10 y el descuento a partes
    /// iguales le resta 15). El formulario no admite partes negativas, así que la revisión no deja usar ese reparto.
    static func hasNegativeShare(_ lines: [ReceiptSplitLine], memberIDs: [String]) -> Bool {
        shares(lines, memberIDs: memberIDs).contains { $0.amount < 0 }
    }

    /// La plantilla del formulario de gasto de grupo: reparto exacto por persona y el total del recibo.
    /// `nil` si no hay nada que repartir o si alguien queda en negativo.
    static func template(
        lines: [ReceiptSplitLine],
        memberIDs: [String],
        currencyCode: String,
        description: String,
        date: Date
    ) -> GroupExpensePrefillTemplate? {
        let parts = shares(lines, memberIDs: memberIDs)
        guard !parts.isEmpty, !parts.contains(where: { $0.amount < 0 }) else { return nil }
        var values: [UUID: Double] = [:]
        var participants: [UUID] = []
        for part in parts {
            guard let uuid = UUID(uuidString: part.memberID) else { continue }
            participants.append(uuid)
            values[uuid] = part.amount
        }
        guard !participants.isEmpty else { return nil }
        return GroupExpensePrefillTemplate(
            totalAmount: total(lines),
            currencyCode: currencyCode,
            splitType: .exact,
            participantIDs: participants,
            values: values,
            description: description,
            accountPrefill: nil,
            date: date,
            subcategory: nil
        )
    }
}

// MARK: - Nombres de la frase → miembros

/// La IA copia los nombres tal como están escritos en la frase («Ana», «yo», «todos»); el miembro lo elige Swift
/// contra la lista del grupo. Así los nombres del grupo no salen del teléfono y un nombre inventado no casa con nadie
/// (el mismo molde que `PaymentMethodAccountLogic` con las cuentas).
nonisolated enum ReceiptPeopleMatcher {
    /// Quien habla («yo», «me», «I»): la IA lo devuelve así.
    static let meToken = "@me"
    /// «Todos», «entre todos»: la línea es de todos los que comen.
    static let allToken = "@all"

    struct Member: Equatable, Sendable {
        let id: String
        let name: String
        let isCurrentUser: Bool
    }

    struct Resolution: Equatable, Sendable {
        var memberIDs: Set<String>
        /// Nombres de la frase que no casan con nadie del grupo (o con más de uno): la revisión los enseña.
        var unmatched: [String]
    }

    static func resolve(_ names: [String], members: [Member]) -> Resolution {
        var resolution = Resolution(memberIDs: [], unmatched: [])
        var everyone = false
        for raw in names {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            if name == allToken {
                everyone = true
            } else if name == meToken {
                if let me = members.first(where: \.isCurrentUser) { resolution.memberIDs.insert(me.id) }
            } else if let id = match(name, in: members) {
                resolution.memberIDs.insert(id)
            } else {
                resolution.unmatched.append(name)
            }
        }
        // «Todos» gana: la línea queda sin asignados, que es «entre todos».
        if everyone { resolution.memberIDs = [] }
        return resolution
    }

    /// Un solo miembro o ninguno: el nombre completo igual, o la primera palabra igual a la primera del miembro.
    static func match(_ name: String, in members: [Member]) -> String? {
        let wanted = fold(name)
        let exact = members.filter { fold($0.name) == wanted }
        if exact.count == 1 { return exact[0].id }
        guard exact.isEmpty, let firstWanted = wanted.split(separator: " ").first else { return nil }
        let byFirst = members.filter { fold($0.name).split(separator: " ").first == firstWanted }
        return byFirst.count == 1 ? byFirst[0].id : nil
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
