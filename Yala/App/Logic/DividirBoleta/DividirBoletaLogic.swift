//
//  DividirBoletaLogic.swift
//  Yala
//
//  Dividir una boleta sin crear grupo (maqueta 1A, decisión de Jürgen del 26-nov-2026). Las personas se escriben al vuelo
//  y no se guardan: son valores (`DividirBoletaPerson`), no `SplitMember`. El cálculo es el de Grupos
//  (`ReceiptSplitLogic`, céntimos enteros, el céntimo que sobra al primero) y aquí solo se suma lo que A añade:
//
//  - «Por igual» reparte todas las líneas de consumo entre todos, se lea lo que se lea de la frase.
//  - Quién pagó: lo que cada uno le debe a esa persona. Si pagó otra, mi parte es lo que yo le debo.
//  - El desglose por persona (qué le tocó de cada línea), que es lo que enseña la imagen «Con detalle».
//
//  Sin IA ni vistas: lo fijan los tests de `YalaTests/DividirBoletaSinGrupo/`.
//

import Foundation

/// Una persona de la boleta. `isMe` es quien usa la app: siempre está y no se puede quitar.
nonisolated struct DividirBoletaPerson: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    var name: String
    let isMe: Bool

    init(id: String = UUID().uuidString, name: String, isMe: Bool = false) {
        self.id = id
        self.name = name
        self.isMe = isMe
    }
}

/// Cómo se reparte la boleta.
nonisolated enum DividirBoletaMode: String, CaseIterable, Sendable {
    /// Todo entre todos, a partes iguales (con el céntimo que sobra a los primeros).
    case equal
    /// Cada línea a quien la comió; sin nadie, entre todos. Es el reparto de Grupos.
    case byLines
}

nonisolated enum DividirBoletaLogic {

    /// Hasta cuántas personas: una boleta de restaurante rara vez pasa de 20 y la imagen tiene que caber.
    static let maxPeople = 20
    /// Hasta cuántas letras por nombre (lo que cabe en una fila de la imagen).
    static let maxNameLength = 24

    // MARK: - Nombres al vuelo

    /// El nombre tal como se guarda en la boleta: sin espacios de más y cortado. `nil` si queda vacío o si ya hay
    /// alguien con ese nombre (sin mayúsculas ni tildes): dos «Ana» no se distinguirían en la imagen.
    static func cleanedName(_ raw: String, existing: [DividirBoletaPerson]) -> String? {
        let collapsed = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        let name = String(collapsed.prefix(maxNameLength))
        let folded = ReceiptPeopleMatcher.fold(name)
        guard !existing.contains(where: { ReceiptPeopleMatcher.fold($0.name) == folded }) else { return nil }
        return name
    }

    /// Para casar los nombres de la frase con las personas de la boleta (el mismo `ReceiptPeopleMatcher` de Grupos).
    static func matcherMembers(_ people: [DividirBoletaPerson]) -> [ReceiptPeopleMatcher.Member] {
        people.map { ReceiptPeopleMatcher.Member(id: $0.id, name: $0.name, isCurrentUser: $0.isMe) }
    }

    /// Quitar a alguien de la boleta lo quita de las líneas donde estaba. Una línea de consumo que se queda sin nadie
    /// vuelve a «entre todos»; un extra «solo para» que se queda sin nadie vuelve a «sin incluir».
    static func removing(_ personID: String, from lines: [ReceiptSplitLine]) -> [ReceiptSplitLine] {
        lines.map { line in
            guard line.assignees.contains(personID) else { return line }
            var copy = line
            copy.assignees.remove(personID)
            if copy.kind.isExtra, copy.extraShare == .people, copy.assignees.isEmpty { copy.extraShare = .excluded }
            return copy
        }
    }

    // MARK: - Reparto

    /// Las líneas con las que se calcula: «por igual» quita los asignados del consumo (todo entre todos). Los extras se
    /// quedan como la persona los eligió.
    static func effectiveLines(_ lines: [ReceiptSplitLine], mode: DividirBoletaMode) -> [ReceiptSplitLine] {
        guard mode == .equal else { return lines }
        return lines.map { line in
            guard !line.kind.isExtra else { return line }
            var copy = line
            copy.assignees = []
            copy.needsReview = false
            return copy
        }
    }

    /// Cuánto le toca a cada uno, en céntimos y en el orden de la boleta. Con «por igual», todos comen.
    static func shareCents(
        _ lines: [ReceiptSplitLine],
        people: [DividirBoletaPerson],
        mode: DividirBoletaMode
    ) -> [String: Int] {
        let ids = people.map(\.id)
        var result: [String: Int] = [:]
        for part in ReceiptSplitLogic.shares(effectiveLines(lines, mode: mode), memberIDs: ids) {
            result[part.memberID] = Int((part.amount * 100).rounded())
        }
        return result
    }

    /// Lo que debe cada uno a quien pagó.
    struct Debt: Equatable, Sendable {
        let personID: String
        let cents: Int
    }

    /// El reparto visto desde quien pagó.
    struct Summary: Equatable, Sendable {
        let totalCents: Int
        let payerID: String
        /// Lo que le tocó a quien pagó: no se lo debe nadie.
        let payerShareCents: Int
        /// Lo que le deben a quien pagó, entre todos (el total menos su parte).
        let owedToPayerCents: Int
        /// Mi parte, pagara quien pagara: es lo que se registra como mi gasto.
        let myShareCents: Int
        /// Quién le debe a quien pagó, en el orden de la boleta, sin los que quedan a cero.
        let debts: [Debt]
        /// Pagó quien usa la app: «Te deben». Si no, «Le debes».
        let payerIsMe: Bool
    }

    /// `nil` si no hay nada que repartir o si alguien queda en negativo (un descuento mayor que lo suyo).
    static func summary(
        _ lines: [ReceiptSplitLine],
        people: [DividirBoletaPerson],
        mode: DividirBoletaMode,
        payerID: String
    ) -> Summary? {
        let shares = shareCents(lines, people: people, mode: mode)
        guard !shares.isEmpty, !shares.values.contains(where: { $0 < 0 }) else { return nil }
        let payer = people.first { $0.id == payerID } ?? people.first { $0.isMe }
        guard let payer else { return nil }
        let total = shares.values.reduce(0, +)
        let payerShare = shares[payer.id] ?? 0
        let me = people.first { $0.isMe }
        let debts = people.compactMap { person -> Debt? in
            guard person.id != payer.id, let cents = shares[person.id], cents > 0 else { return nil }
            return Debt(personID: person.id, cents: cents)
        }
        return Summary(
            totalCents: total,
            payerID: payer.id,
            payerShareCents: payerShare,
            owedToPayerCents: total - payerShare,
            myShareCents: me.flatMap { shares[$0.id] } ?? 0,
            debts: debts,
            payerIsMe: payer.isMe
        )
    }

    /// Si la revisión deja seguir: hay algo que repartir y nadie queda en negativo.
    static func canSplit(_ lines: [ReceiptSplitLine], people: [DividirBoletaPerson], mode: DividirBoletaMode) -> Bool {
        let shares = shareCents(lines, people: people, mode: mode)
        return !shares.isEmpty && !shares.values.contains { $0 < 0 }
    }

    // MARK: - Desglose por persona

    /// Lo que le tocó a una persona de una línea. `sharedBy` es entre cuántos se partió (1 = entera).
    struct Part: Equatable, Sendable {
        let lineID: UUID
        let description: String
        let kind: ReceiptLineKind
        let cents: Int
        let sharedBy: Int
    }

    /// Qué le tocó a cada uno, línea por línea. Repite las reglas de `ReceiptSplitLogic.shares` y su suma por persona es
    /// exactamente su parte (lo fija un test): la imagen «Con detalle» no puede decir una cosa y el total otra.
    static func breakdown(
        _ lines: [ReceiptSplitLine],
        people: [DividirBoletaPerson],
        mode: DividirBoletaMode
    ) -> [String: [Part]] {
        let ids = people.map(\.id)
        let lines = effectiveLines(lines, mode: mode)
        guard !ids.isEmpty, ReceiptSplitLogic.totalCents(lines) > 0 else { return [:] }
        let diners = ReceiptSplitLogic.diners(lines, memberIDs: ids)
        var result: [String: [Part]] = [:]
        var consumed: [String: Int] = [:]
        for line in lines where !line.kind.isExtra {
            let payers = ReceiptSplitLogic.payers(of: line, diners: diners, memberIDs: ids)
            for (id, part) in zip(payers, ReceiptSplitLogic.evenSplit(ReceiptSplitLogic.cents(line.amount), parts: payers.count)) {
                consumed[id, default: 0] += part
                result[id, default: []].append(Part(
                    lineID: line.id, description: line.description, kind: line.kind, cents: part, sharedBy: payers.count))
            }
        }
        for line in lines where line.kind.isExtra && line.isIncluded {
            let value = ReceiptSplitLogic.signedCents(line)
            let targets: [String]
            let parts: [Int]
            switch line.extraShare {
            case .excluded:
                continue
            case .proportional:
                targets = diners
                parts = ReceiptSplitLogic.proportionalSplit(value, weights: diners.map { consumed[$0] ?? 0 })
            case .equal:
                targets = diners
                parts = ReceiptSplitLogic.evenSplit(value, parts: diners.count)
            case .people:
                targets = ids.filter { line.assignees.contains($0) }
                parts = ReceiptSplitLogic.evenSplit(value, parts: targets.count)
            }
            for (id, part) in zip(targets, parts) where part != 0 {
                result[id, default: []].append(Part(
                    lineID: line.id, description: line.description, kind: line.kind, cents: part, sharedBy: targets.count))
            }
        }
        return result
    }

    // MARK: - La parte que se registra

    /// Mi parte como importe de un borrador de la Bandeja: un gasto, en negativo.
    static func draftAmount(myShareCents: Int) -> Double? {
        guard myShareCents > 0 else { return nil }
        return -Double(myShareCents) / 100
    }

    /// El borrador de la Bandeja con mi parte, sin insertar: el comercio como nota, la moneda de la boleta y sin cuenta
    /// ni categoría (se eligen al aprobarlo). `nil` si mi parte es cero.
    @MainActor
    static func myShareDraft(
        myShareCents: Int,
        merchant: String?,
        fallbackNote: String,
        currencyCode: String,
        date: Date
    ) -> InboxDraft? {
        guard let amount = draftAmount(myShareCents: myShareCents) else { return nil }
        let draft = InboxDraft(
            note: merchant ?? fallbackNote,
            amount: amount,
            date: date,
            sourceType: .receiptPhoto,
            evidence: merchant
        )
        draft.cachedCurrencyCode = currencyCode
        return draft
    }
}

// MARK: - Imagen para compartir

/// Qué cuenta la imagen.
nonisolated enum DividirBoletaImageKind: String, CaseIterable, Sendable {
    /// Quién le debe cuánto a quien pagó.
    case summary
    /// Además, qué le tocó a cada uno línea por línea, con los extras.
    case detailed
}

/// Los tres diseños de la tarjeta. Todos con los colores y el logo de Yala, en colores fijos.
nonisolated enum DividirBoletaImageStyle: String, CaseIterable, Sendable {
    /// Blanca con la franja índigo de Yala arriba.
    case light
    /// Índigo de Yala entero, con las personas en tarjetas.
    case brand
    /// Papel de boleta, con el logo en índigo y el subrayado rosa.
    case receipt
}

/// Los colores fijos de las tarjetas (nada de tema ni de modo oscuro: la imagen sale de la app y se ve igual en
/// cualquier teléfono). Cada pareja texto/fondo pasa AA (4,5:1): lo mide `DividirBoletaImagenTests`.
nonisolated enum DividirBoletaPalette {
    // Marca
    static let indigoDeep = "312E81"
    static let indigo = "4338CA"
    static let indigoBright = "6063F1"
    static let turquoise = "00C2CB"
    static let pink = "FF0080"

    // Clara
    static let lightBackground = "FFFFFF"
    static let lightInk = "111827"
    static let lightInkSecondary = "4B5563"
    static let lightHairline = "E5E7EB"
    static let lightAccentText = "4338CA"
    /// Lo que se lee sobre la franja índigo de arriba.
    static let onIndigo = "FFFFFF"
    static let onIndigoSecondary = "E0E7FF"

    // Yala (índigo entero)
    static let brandCard = "3B35A8"
    static let brandInkSecondary = "E0E7FF"

    // Boleta
    static let paper = "FBFAF6"
    static let paperInk = "1F2937"
    static let paperInkSecondary = "4B5563"
    static let paperAccent = "3D36B3"
    static let paperPinkText = "B0005A"
    static let paperRule = "C9C5B8"

    /// Los rellenos de las iniciales, con texto blanco encima (AA). Se asignan por orden en la boleta.
    static let avatars = ["4338CA", "B0005A", "0B6F75", "8A5200", "1D6B42", "6D28D9", "9F1239", "155E75"]

    static func avatar(at index: Int) -> String { avatars[index % avatars.count] }
}

/// Lo que pinta la tarjeta, ya en texto: la tarjeta se rasteriza fuera del árbol de la app y no puede leer
/// preferencias ni idioma (la regla 1 de `GroupShareableSummaryCard`).
nonisolated struct DividirBoletaImageContent: Equatable, Sendable {
    struct PersonRow: Equatable, Sendable, Identifiable {
        let id: String
        let name: String
        let initials: String
        let colorHex: String
        let amount: String
        /// Solo «Con detalle»: qué le tocó, una entrada por línea.
        let items: [String]
    }

    struct LineRow: Equatable, Sendable, Identifiable {
        let id: UUID
        let description: String
        let amount: String
        /// Quién la pagó, o «Entre todos».
        let who: String
    }

    let kind: DividirBoletaImageKind
    let merchant: String
    let dateText: String
    /// «A Jürgen le deben», «Ana le debe a Jürgen».
    let headline: String
    let headlineAmount: String
    /// «Pagó Carla · total S/ 260.70».
    let subtitle: String
    /// Quién le debe a quien pagó.
    let rows: [PersonRow]
    /// Solo «Con detalle»: la parte de quien pagó, que nadie le debe («La parte de Jürgen»).
    let payerLine: String?
    /// Solo «Con detalle»: las líneas de la boleta con quién las pagó.
    let lines: [LineRow]
    let footerTitle: String
    let footerSubtitle: String
}

/// Arma el contenido de la imagen. Los textos llegan de fuera (`L10n.DividirBoleta`) para que esto se pueda probar sin
/// idioma ni preferencias.
nonisolated enum DividirBoletaImageBuilder {

    /// La imagen se manda a otras personas, así que habla de quien la manda en tercera persona y con su nombre
    /// (Jürgen, 26-nov-2026: «que lo nuestro no diga "Yo", diga mi nombre»): nada de «Me deben» ni «Mi parte».
    struct Texts: Sendable {
        /// «A %@ le deben».
        let owedToOther: String
        /// «%1$@ le debe a %2$@».
        let oneOwesOther: String
        /// «Pagó %1$@ · total %2$@».
        let paidByTotal: String
        /// El nombre de quien usa la app, tal como sale en la imagen.
        let meName: String
        /// «La parte de %1$@: %2$@».
        let payerPart: String
        /// «Entre todos».
        let everyone: String
        /// «entre %d» para una línea partida.
        let sharedBy: String
        let footerTitle: String
        let footerSubtitle: String
        /// «Carla y Martín», con el idioma de la app.
        let joinNames: @Sendable ([String]) -> String
    }

    static func initials(_ name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        let letters = words.prefix(2).compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    static func make(
        kind: DividirBoletaImageKind,
        merchant: String,
        dateText: String,
        lines: [ReceiptSplitLine],
        people: [DividirBoletaPerson],
        mode: DividirBoletaMode,
        payerID: String,
        texts: Texts,
        money: (Int) -> String
    ) -> DividirBoletaImageContent? {
        guard let summary = DividirBoletaLogic.summary(lines, people: people, mode: mode, payerID: payerID),
              let payer = people.first(where: { $0.id == summary.payerID }) else { return nil }
        let name: (DividirBoletaPerson) -> String = { $0.isMe ? texts.meName : $0.name }
        let breakdown = kind == .detailed ? DividirBoletaLogic.breakdown(lines, people: people, mode: mode) : [:]
        let colorIndex = Dictionary(uniqueKeysWithValues: people.enumerated().map { ($1.id, $0) })

        func itemTexts(_ personID: String) -> [String] {
            (breakdown[personID] ?? []).map { part in
                let shared = part.sharedBy > 1 && !part.kind.isExtra
                    ? " (" + String(format: texts.sharedBy, part.sharedBy) + ")" : ""
                // Espacio duro dentro del importe: «S/» y «42.00» no se separan al partir la línea.
                return "\(part.description)\(shared) \(money(part.cents).replacingOccurrences(of: " ", with: "\u{00A0}"))"
            }
        }

        let rows = summary.debts.compactMap { debt -> DividirBoletaImageContent.PersonRow? in
            guard let person = people.first(where: { $0.id == debt.personID }) else { return nil }
            return DividirBoletaImageContent.PersonRow(
                id: person.id,
                name: name(person),
                initials: initials(name(person)),
                colorHex: DividirBoletaPalette.avatar(at: colorIndex[person.id] ?? 0),
                amount: money(debt.cents),
                items: itemTexts(person.id)
            )
        }

        let payerName = name(payer)
        let headline = rows.count == 1
            ? String(format: texts.oneOwesOther, rows[0].name, payerName)
            : String(format: texts.owedToOther, payerName)

        let payerLine: String? = kind == .detailed && summary.payerShareCents > 0
            ? String(format: texts.payerPart, payerName, money(summary.payerShareCents))
            : nil

        let effective = DividirBoletaLogic.effectiveLines(lines, mode: mode)
        let ids = people.map(\.id)
        let diners = ReceiptSplitLogic.diners(effective, memberIDs: ids)
        let lineRows: [DividirBoletaImageContent.LineRow] = kind == .detailed
            ? effective.filter(\.isIncluded).map { line in
                let payers = line.kind.isExtra
                    ? (line.extraShare == .people ? ids.filter { line.assignees.contains($0) } : diners)
                    : ReceiptSplitLogic.payers(of: line, diners: diners, memberIDs: ids)
                let who = payers.count == people.count || payers.isEmpty
                    ? texts.everyone
                    : texts.joinNames(payers.compactMap { id in people.first { $0.id == id }.map(name) })
                let sign = line.kind == .discount ? "−" : ""
                return DividirBoletaImageContent.LineRow(
                    id: line.id,
                    description: line.description,
                    amount: sign + money(ReceiptSplitLogic.cents(line.amount)),
                    who: who
                )
            }
            : []

        return DividirBoletaImageContent(
            kind: kind,
            merchant: merchant,
            dateText: dateText,
            headline: headline,
            headlineAmount: money(summary.owedToPayerCents),
            subtitle: String(format: texts.paidByTotal, name(payer), money(summary.totalCents)),
            rows: rows,
            payerLine: payerLine,
            lines: lineRows,
            footerTitle: texts.footerTitle,
            footerSubtitle: texts.footerSubtitle
        )
    }
}
