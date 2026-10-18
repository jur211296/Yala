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

    // MARK: - Entrega 3: elegir la tarjeta y que la divisa decida la línea

    /// Adónde va un importe cuando se elige `chosenID` y el importe está en `currencyCode`.
    struct Route: Equatable, Sendable {
        /// La cuenta concreta en la que se guarda: la principal o una de sus líneas.
        let accountID: UUID
        /// `true` si la tarjeta no tiene ninguna cuenta en esa divisa y el importe se queda en la principal (o en la cuenta
        /// elegida, si no tiene líneas). Quien llama decide qué divisa usa entonces: la de esa cuenta, como hoy.
        let isFallback: Bool
    }

    /// La función de la decisión 6 de Jürgen, la misma para todas las entradas (formulario, chat, voz, imagen, Siri, Apple Pay,
    /// Bandeja, programados, favoritos e importación): se elige la tarjeta y la divisa del importe decide la línea.
    /// - Si `chosenID` es una cuenta sin líneas (suelta, o una línea rota que se lee suelta), devuelve esa misma cuenta.
    /// - Si es la principal o una línea de una tarjeta, devuelve el miembro vivo cuya divisa es `currencyCode`.
    /// - Si ningún miembro está en esa divisa, devuelve la principal con `isFallback`. **Nunca crea una línea.**
    /// Elegir una línea en otra divisa que la del importe también enruta: la tarjeta es una, y la línea elegida es solo cómo
    /// se llegó a ella. Sin la cuenta en `nodes`, `nil`.
    static func route(chosenID: UUID, currencyCode: String, nodes: [AccountLineNode]) -> Route? {
        guard nodes.contains(where: { $0.id == chosenID }) else { return nil }
        let roles = AccountLineLogic.resolve(nodes)
        let headID: UUID
        if case .line(let principalID)? = roles[chosenID] { headID = principalID } else { headID = chosenID }
        let members = liveMembers(ofHead: headID, nodes: nodes, roles: roles)
        guard members.count > 1 else {
            let only = nodes.first { $0.id == chosenID }
            return Route(accountID: chosenID, isFallback: only.map { !sameCurrency($0.currencyCode, currencyCode) } ?? false)
        }
        if let match = members.first(where: { sameCurrency($0.currencyCode, currencyCode) }) {
            return Route(accountID: match.id, isFallback: false)
        }
        return Route(accountID: headID, isFallback: true)
    }

    /// La cabeza de la tarjeta a la que pertenece `id`: la principal si es una línea válida; si no, la propia cuenta.
    static func headID(of id: UUID, roles: [UUID: AccountLineRole]) -> UUID {
        if case .line(let principalID)? = roles[id] { return principalID }
        return id
    }

    /// Los miembros vivos de la tarjeta de `id` (la cabeza primero y sus líneas por divisa). Una cuenta sin líneas devuelve
    /// solo ella. Lo usan las pastillas de divisa del formulario y la importación.
    static func liveMembers(of id: UUID, nodes: [AccountLineNode]) -> [AccountLineNode] {
        let roles = AccountLineLogic.resolve(nodes)
        return liveMembers(ofHead: headID(of: id, roles: roles), nodes: nodes, roles: roles)
    }

    /// Importación con varias divisas (decisión D11): al elegir `chosenID` para una divisa, las demás divisas del fichero que
    /// aún no tienen cuenta se rellenan con la cuenta de su tarjeta en esa divisa. Solo devuelve las nuevas; nunca pisa una
    /// ya elegida ni cae a la principal (una divisa que la tarjeta no tiene se queda sin asignar).
    static func importAssignments(
        chosenID: UUID, currencies: [String], assigned: Set<String>, nodes: [AccountLineNode]
    ) -> [String: UUID] {
        var result: [String: UUID] = [:]
        for currency in currencies where !assigned.contains(currency) {
            guard let route = route(chosenID: chosenID, currencyCode: currency, nodes: nodes), !route.isFallback,
                  liveMembers(of: chosenID, nodes: nodes).count > 1 else { continue }
            result[currency] = route.accountID
        }
        return result
    }

    // MARK: - Entrega 3: filtros y presupuestos

    /// Las líneas de cada cabeza con líneas, por identificador cualquiera (`PersistentIdentifier` en el filtro de sesión,
    /// `UUID` en los presupuestos). Solo aparecen las cabezas que tienen alguna. **Incluye las líneas archivadas** (siguen
    /// siendo de la tarjeta para `resolve`): archivar no decide la suma (`session-filters.md`), así que archivar una línea no
    /// le quita su gasto al presupuesto de la tarjeta ni sus movimientos al filtro (review del 2026-10-18).
    static func linesByHead<E, ID: Hashable>(
        _ accounts: [E], node: (E) -> AccountLineNode, id: (E) -> ID
    ) -> [ID: Set<ID>] {
        let nodes = accounts.map(node)
        let roles = AccountLineLogic.resolve(nodes)
        var idByShortcut: [UUID: ID] = [:]
        for account in accounts { idByShortcut[node(account).id] = id(account) }
        var result: [ID: Set<ID>] = [:]
        for account in accounts {
            let n = node(account)
            guard case .line(let principalID)? = roles[n.id],
                  let headKey = idByShortcut[principalID] else { continue }
            result[headKey, default: []].insert(id(account))
        }
        return result
    }

    /// El conjunto que se guarda en el filtro de sesión tras un cambio de `old` a `new` (decisión D1 del encargo): poner una
    /// tarjeta añade sus líneas; quitarla las quita; con la tarjeta puesta, sus líneas siguen puestas. Una línea elegida SOLA
    /// (sin su tarjeta) se respeta: puede venir de un presupuesto anterior al enlace y vaciarla quitaría el filtro entero.
    static func normalizedSelection<ID: Hashable>(old: Set<ID>, new: Set<ID>, linesByHead: [ID: Set<ID>]) -> Set<ID> {
        var result = new
        for (head, lines) in linesByHead {
            if new.contains(head) {
                result.formUnion(lines)
            } else if old.contains(head) {
                result.subtract(lines)
            }
        }
        return result
    }

    /// Lo que se pinta de una selección: cada tarjeta una vez. Quita las líneas cuya cabeza también está.
    static func shownSelection<ID: Hashable>(_ selection: Set<ID>, linesByHead: [ID: Set<ID>]) -> Set<ID> {
        var result = selection
        for (head, lines) in linesByHead where selection.contains(head) { result.subtract(lines) }
        return result
    }

    /// Las cuentas que cuenta un presupuesto: las que guarda y las líneas vivas de las tarjetas que guarda (decisión D2).
    static func includingLines<ID: Hashable>(_ ids: Set<ID>, linesByHead: [ID: Set<ID>]) -> Set<ID> {
        var result = ids
        for id in ids { if let lines = linesByHead[id] { result.formUnion(lines) } }
        return result
    }

    // MARK: - Privado

    private static func sameCurrency(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespaces).uppercased() == b.trimmingCharacters(in: .whitespaces).uppercased()
    }

    /// La cabeza (si está viva) y sus líneas vivas, por divisa. Una cabeza archivada no tiene líneas (`resolve` las lee sueltas).
    private static func liveMembers(
        ofHead headID: UUID, nodes: [AccountLineNode], roles: [UUID: AccountLineRole]
    ) -> [AccountLineNode] {
        guard let head = nodes.first(where: { $0.id == headID }) else { return [] }
        let lines = nodes
            .filter { !$0.isArchived && roles[$0.id] == .line(principalID: headID) }
            .sorted { $0.currencyCode < $1.currencyCode }
        return (head.isArchived ? [] : [head]) + lines
    }

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
