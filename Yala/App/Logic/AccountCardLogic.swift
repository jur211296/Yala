//
//  AccountCardLogic.swift
//  Yala
//
//  Tarjeta con varias divisas, entrega 2 (ticket `multi-currency-accounts-2-card-view`): lo que las pantallas necesitan
//  saber para pintar una tarjeta con sus líneas, sin repetir las reglas. Qué es cada cuenta lo sigue decidiendo
//  `AccountLineLogic.resolve`; aquí solo se agrupa, se ordena y se pregunta.
//
//  Quien lo usa: el carrusel y los chips del Panel, la ficha de la cuenta, Ajustes › Cuentas, el formulario de cuenta,
//  el downgrade de plan y el recordatorio de pago de la tarjeta.
//

import Foundation

/// Una tarjeta tal como se pinta: la cuenta de cabeza (una principal o una cuenta suelta) y sus líneas, por divisa.
nonisolated struct AccountCard<Element> {
    let head: Element
    let lines: [Element]

    var hasLines: Bool { !lines.isEmpty }
    /// La cabeza y sus líneas, en ese orden.
    var members: [Element] { [head] + lines }
}

/// Una cuenta a la que se le podría vincular la tarjeta, y por qué no si no se puede.
nonisolated struct AccountLinkCandidate: Equatable, Sendable {
    let id: UUID
    let rejection: AccountLinkRejection?

    var isAllowed: Bool { rejection == nil }
}

nonisolated enum AccountCardLogic {

    // MARK: - Agrupar

    /// Agrupa `shown` en tarjetas conservando su orden. Una línea solo se mete dentro de su principal si la principal
    /// también está en `shown`; si no, sale como cuenta propia (falla visible, igual que una línea rota). `roles` sale
    /// de `AccountLineLogic.resolve` sobre TODAS las cuentas, archivadas incluidas: una principal archivada tiene que
    /// estar ahí para que su línea se lea suelta.
    static func cards<E>(
        _ shown: [E],
        roles: [UUID: AccountLineRole],
        id: (E) -> UUID,
        currencyCode: (E) -> String
    ) -> [AccountCard<E>] {
        let shownIDs = Set(shown.map(id))
        var linesByPrincipal: [UUID: [E]] = [:]
        var heads: [E] = []
        for element in shown {
            if case .line(let principalID)? = roles[id(element)], principalID != id(element),
               shownIDs.contains(principalID) {
                linesByPrincipal[principalID, default: []].append(element)
            } else {
                heads.append(element)
            }
        }
        return heads.map { head in
            let lines = (linesByPrincipal[id(head)] ?? []).sorted { currencyCode($0) < currencyCode($1) }
            return AccountCard(head: head, lines: lines)
        }
    }

    /// El orden que se guarda en `accountsSortOrderNames`: cada tarjeta y, justo detrás, sus líneas. Sin ellas,
    /// reordenar en Ajustes borraba la posición de las líneas y el Panel las mandaba al final (review de la entrega 1).
    static func sortOrderNames<E>(_ cards: [AccountCard<E>], name: (E) -> String) -> [String] {
        cards.flatMap { $0.members.map(name) }
    }

    // MARK: - Qué ofrece cada cuenta

    /// Recordatorio y día de pago: solo la principal (o una cuenta suelta). En una línea la notificación llegaría
    /// duplicada. Una línea rota se ve suelta, así que tiene los suyos.
    static func ownsCardSettings(_ role: AccountLineRole?) -> Bool {
        !(role?.isLine ?? false)
    }

    /// Si a esta cuenta se le pueden añadir o vincular líneas: una cuenta de usuario, viva y sin enlace propio. Una
    /// con un enlace roto tiene que desvincularse antes (`linkRejection` la rechaza como principal).
    static func canHaveLines(_ node: AccountLineNode) -> Bool {
        !node.isSystem && !node.isArchived && node.parentID == nil
    }

    /// Las divisas en las que se puede añadir una línea a la tarjeta: todas menos la de la principal y las de sus
    /// líneas, archivadas incluidas. Una línea nueva junto a una archivada de su misma divisa dejaría dos en la ranura
    /// al desarchivar la vieja, y `resolve` se quedaría con una al azar (la otra, con sus movimientos, saldría suelta).
    /// En el orden de `available`.
    static func addableCurrencies(principalID: UUID, nodes: [AccountLineNode], available: [String]) -> [String] {
        guard let principal = nodes.first(where: { $0.id == principalID }) else { return [] }
        let taken = Set(lines(of: principalID, nodes: nodes).map(\.currencyCode)).union([principal.currencyCode])
        return available.filter { !taken.contains($0) }
    }

    /// Las cuentas que se le pueden ofrecer a la tarjeta para vincular, con su motivo de rechazo. Fuera quedan la
    /// propia tarjeta, sus líneas, las archivadas y las de sistema (no son cuentas que el usuario elija). Primero las
    /// que se pueden; dentro de cada grupo, el orden de `nodes`.
    static func linkCandidates(principalID: UUID, nodes: [AccountLineNode]) -> [AccountLinkCandidate] {
        let roles = AccountLineLogic.resolve(nodes)
        let candidates = nodes.filter { node in
            node.id != principalID && !node.isArchived && !node.isSystem
                && roles[node.id] != .line(principalID: principalID)
        }
        let all = candidates.map { node in
            AccountLinkCandidate(
                id: node.id,
                rejection: AccountLineLogic.linkRejection(lineID: node.id, principalID: principalID, among: nodes))
        }
        return all.filter(\.isAllowed) + all.filter { !$0.isAllowed }
    }

    /// ¿La principal choca con una de sus líneas si pasa a `currencyCode`? La línea dejaría de serlo en silencio.
    static func currencyCollidesWithLine(principalID: UUID, currencyCode: String, nodes: [AccountLineNode]) -> Bool {
        liveLines(of: principalID, nodes: nodes).contains { $0.currencyCode == currencyCode }
    }

    /// El nombre de una línea nueva: «Visa BCP · USD». Si ya existe (sin distinguir mayúsculas), le añade un número:
    /// los nombres de cuenta no se repiten (el formulario lo exige y el orden guardado va por nombre).
    static func lineName(cardName: String, currencyCode: String, taken: [String]) -> String {
        let used = Set(taken.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        let base = "\(cardName) · \(currencyCode)"
        guard used.contains(base.lowercased()) else { return base }
        var index = 2
        while used.contains("\(base) \(index)".lowercased()) { index += 1 }
        return "\(base) \(index)"
    }

    // MARK: - Archivar

    /// Las líneas vivas que se archivan con la principal. Se resuelve como si la principal NO estuviera archivada:
    /// así da igual si quien llama ya escribió `isArchived` en ella (con la principal archivada sus líneas se leen
    /// sueltas y la cascada no encontraría ninguna).
    static func linesToArchive(principalID: UUID, nodes: [AccountLineNode]) -> [UUID] {
        liveLines(of: principalID, nodes: nodes).map(\.id)
    }

    // MARK: - Total de la tarjeta

    /// Lo que vale una línea, en su divisa.
    struct LineAmount: Equatable, Sendable {
        let value: Double
        let currencyCode: String
    }

    /// El total de la tarjeta en `target`. `isConverted` dice si alguna línea se convirtió (la marca «≈»). Una línea
    /// que no se puede convertir no se suma en silencio: `convert` devuelve siempre un valor (la tasa más reciente que
    /// haya, como el saldo total del Panel).
    static func total(
        _ amounts: [LineAmount],
        in target: String,
        convert: (Double, String) -> Double
    ) -> (value: Double, isConverted: Bool) {
        var value = 0.0
        var isConverted = false
        for amount in amounts {
            if amount.currencyCode == target {
                value += amount.value
            } else {
                value += convert(amount.value, amount.currencyCode)
                isConverted = true
            }
        }
        return (value, isConverted)
    }

    // MARK: - Privado

    private static func liveLines(of principalID: UUID, nodes: [AccountLineNode]) -> [AccountLineNode] {
        lines(of: principalID, nodes: nodes).filter { !$0.isArchived }
    }

    /// Las líneas de la tarjeta, archivadas incluidas, resolviendo como si la principal no estuviera archivada.
    private static func lines(of principalID: UUID, nodes: [AccountLineNode]) -> [AccountLineNode] {
        let unarchivedPrincipal = nodes.map { node in
            node.id == principalID
                ? AccountLineNode(id: node.id, parentID: node.parentID, currencyCode: node.currencyCode,
                                  isArchived: false, isSystem: node.isSystem)
                : node
        }
        let roles = AccountLineLogic.resolve(unarchivedPrincipal)
        return unarchivedPrincipal.filter { node in roles[node.id] == .line(principalID: principalID) }
    }
}
