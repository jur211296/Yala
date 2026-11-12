//
//  AccountLineLogic.swift
//  Yala
//
//  Tarjeta con varias divisas (entrega 1, ticket `multi-currency-accounts-1-model-and-sync`). Una tarjeta
//  que cobra en soles y en dólares es una cuenta PRINCIPAL (la de soles, por ejemplo) y una LÍNEA por cada
//  divisa extra: otra `Account` de una sola divisa con `parentAccountID` = el `shortcutID` de la principal.
//  Cada línea conserva su saldo y su divisa; ningún cálculo de dinero cambia de premisa (decisión A1 de
//  Jürgen, 2026-10-09, `docs/multi-currency-accounts-impact-2026-10.md` §4-5).
//
//  Esta lógica es PURA (sin SwiftData en la firma) y es el ÚNICO sitio que decide qué es cada cuenta.
//  Quien pinte, cuente o desduplique pregunta aquí; repetir las reglas a mano es como divergen.
//
//  Las reglas:
//   - una tarjeta no tiene dos líneas en la misma divisa, ni una línea en la divisa de la principal;
//   - un solo nivel: una línea no tiene líneas, y una cuenta con líneas no pasa a ser línea;
//   - sin ciclos ni autoenlace;
//   - válida para CUALQUIER tipo de cuenta (decisión 3): no se mira `type`;
//   - vincular dos cuentas con movimientos es legal (decisión 4): enlazar solo escribe `parentAccountID`.
//
//  Lo que llega por sync puede romper cualquiera de esas reglas (dos teléfonos, una principal borrada, un
//  `shortcutID` regenerado). Un enlace roto NUNCA se esconde: la cuenta se lee como SUELTA, que es como la
//  ve un teléfono con una versión anterior. Falla cerrado y visible.
//

import Foundation

/// Lo que la lógica necesita de una cuenta. Sin `@Model`: se construye en el sitio que lee SwiftData.
nonisolated struct AccountLineNode: Equatable, Sendable {
    let id: UUID
    let parentID: UUID?
    let currencyCode: String
    let isArchived: Bool
    let isSystem: Bool

    init(id: UUID, parentID: UUID?, currencyCode: String, isArchived: Bool = false, isSystem: Bool = false) {
        self.id = id
        self.parentID = parentID
        self.currencyCode = currencyCode
        self.isArchived = isArchived
        self.isSystem = isSystem
    }
}

extension AccountLineNode {
    init(_ account: Account) {
        self.init(id: account.shortcutID, parentID: account.parentAccountID, currencyCode: account.currencyCode,
                  isArchived: account.isArchived, isSystem: account.isSystemAccount)
    }
}

/// Por qué un enlace declarado NO cuenta como línea.
nonisolated enum AccountLineIssue: Equatable, Sendable {
    /// La principal no existe aquí: borrada, o todavía no ha llegado por sync.
    case orphan
    /// Dos o más cuentas comparten el `shortcutID` de la línea o de su principal (identidad colapsada).
    case ambiguousIdentity
    case selfLink
    /// La principal es a su vez una línea (segundo nivel) — un ciclo cae aquí también.
    case principalIsLine
    case principalArchived
    /// La línea o su principal es una cuenta de sistema del bridge de Grupos.
    case systemAccount
    case sameCurrencyAsPrincipal
    /// Otra línea viva de la misma tarjeta y divisa gana el desempate (menor `shortcutID`).
    case duplicateCurrency(keptLineID: UUID)
}

/// Qué es cada cuenta.
nonisolated enum AccountLineRole: Equatable, Sendable {
    case standalone
    /// Principal de una tarjeta con al menos una línea; `lineIDs` ordenadas por `uuidString`.
    case principal(lineIDs: [UUID])
    case line(principalID: UUID)
    /// Declara un enlace que no vale: se trata como cuenta suelta.
    case brokenLine(AccountLineIssue)

    var isLine: Bool {
        switch self {
        case .line: return true
        case .standalone, .principal, .brokenLine: return false
        }
    }
}

/// Por qué no se puede vincular una cuenta como línea de otra.
nonisolated enum AccountLinkRejection: Equatable, Sendable {
    case accountNotFound
    case ambiguousIdentity
    case selfLink
    case cycle
    case systemAccount
    case archivedAccount
    case sameCurrencyAsPrincipal
    /// La principal elegida ya es línea de otra tarjeta: no hay segundo nivel.
    case principalIsLine
    /// La cuenta que pasaría a ser línea ya tiene líneas propias.
    case lineHasLines
    /// La tarjeta ya tiene una línea viva en esa divisa.
    case currencyAlreadyLinked(existingLineID: UUID)
}

/// Un `shortcutID` regenerado: el valor de antes, el de ahora y cómo es la cuenta.
nonisolated struct RegeneratedAccountIdentity: Equatable, Sendable {
    let oldID: UUID
    let newID: UUID
    let parentID: UUID?
    let currencyCode: String
    let isSystem: Bool
}

nonisolated enum AccountLineLogic {

    // MARK: - Resolver

    /// El rol de cada cuenta, por `shortcutID`. Determinista: el resultado no depende del orden de entrada.
    static func resolve(_ nodes: [AccountLineNode]) -> [UUID: AccountLineRole] {
        var counts: [UUID: Int] = [:]
        for node in nodes { counts[node.id, default: 0] += 1 }
        var byID: [UUID: AccountLineNode] = [:]
        for node in nodes where counts[node.id] == 1 { byID[node.id] = node }

        var roles: [UUID: AccountLineRole] = [:]
        for node in nodes { roles[node.id] = .standalone }
        // Una identidad compartida no puede ser ni línea ni principal: no se sabe de qué cuenta se habla.
        for node in nodes where counts[node.id] ?? 0 > 1 && node.parentID != nil {
            roles[node.id] = .brokenLine(.ambiguousIdentity)
        }

        // Candidatas: enlaces estructuralmente válidos.
        var candidates: [AccountLineNode] = []
        for node in byID.values {
            guard let parentID = node.parentID else { continue }
            if let issue = structuralIssue(of: node, parentID: parentID, counts: counts, byID: byID) {
                roles[node.id] = .brokenLine(issue)
            } else {
                candidates.append(node)
            }
        }

        // Una línea viva por (principal, divisa): gana el menor `shortcutID`. Las archivadas no compiten.
        var linesByPrincipal: [UUID: [UUID]] = [:]
        var liveBySlot: [String: [AccountLineNode]] = [:]
        for node in candidates {
            guard let parentID = node.parentID else { continue }
            if node.isArchived {
                roles[node.id] = .line(principalID: parentID)
                linesByPrincipal[parentID, default: []].append(node.id)
            } else {
                liveBySlot[slotKey(parentID, node.currencyCode), default: []].append(node)
            }
        }
        for (_, slot) in liveBySlot {
            let sorted = slot.sorted { $0.id.uuidString < $1.id.uuidString }
            guard let kept = sorted.first, let parentID = kept.parentID else { continue }
            roles[kept.id] = .line(principalID: parentID)
            linesByPrincipal[parentID, default: []].append(kept.id)
            for loser in sorted.dropFirst() {
                roles[loser.id] = .brokenLine(.duplicateCurrency(keptLineID: kept.id))
            }
        }
        for (principalID, lineIDs) in linesByPrincipal {
            roles[principalID] = .principal(lineIDs: lineIDs.sorted { $0.uuidString < $1.uuidString })
        }
        return roles
    }

    // MARK: - Vincular

    /// ¿Puede `lineID` pasar a ser línea de `principalID`? `nil` = sí. Vincular cuentas con movimientos es
    /// legal y el tipo de cuenta no importa; volver a vincular una línea a otra tarjeta también.
    static func linkRejection(lineID: UUID, principalID: UUID, among nodes: [AccountLineNode]) -> AccountLinkRejection? {
        guard lineID != principalID else { return .selfLink }
        let lineMatches = nodes.filter { $0.id == lineID }
        let principalMatches = nodes.filter { $0.id == principalID }
        guard let line = lineMatches.first, let principal = principalMatches.first else { return .accountNotFound }
        guard lineMatches.count == 1, principalMatches.count == 1 else { return .ambiguousIdentity }
        if principal.parentID == lineID { return .cycle }
        if line.isSystem || principal.isSystem { return .systemAccount }
        if line.isArchived || principal.isArchived { return .archivedAccount }
        if principal.parentID != nil { return .principalIsLine }
        if nodes.contains(where: { $0.parentID == lineID && $0.id != lineID }) { return .lineHasLines }
        if line.currencyCode == principal.currencyCode { return .sameCurrencyAsPrincipal }
        let roles = resolve(nodes)
        if let existing = nodes.first(where: { other in
            other.id != lineID && !other.isArchived && other.currencyCode == line.currencyCode
                && roles[other.id] == .line(principalID: principalID)
        }) {
            return .currencyAlreadyLinked(existingLineID: existing.id)
        }
        return nil
    }

    // MARK: - Identidad regenerada

    /// Tras regenerar `shortcutID`s colapsados, a qué principal NUEVA apunta cada línea que apuntaba a un
    /// valor viejo. Clave = la de `lines` (la usa el llamador para volver a su objeto). Solo se reenlaza
    /// cuando EXACTAMENTE una de las cuentas que compartían el valor viejo puede ser la principal de esa
    /// línea; con dos o más no hay forma de saber cuál era, y la línea se queda huérfana (suelta y visible)
    /// en vez de adivinar. Los `id` de `lines` son los de DESPUÉS de regenerar (una línea cuyo propio valor
    /// también colapsó aparece en `regenerated` con su `newID`, y así no se elige a sí misma).
    static func relinkTargets<Key: Hashable>(
        lines: [Key: AccountLineNode],
        regenerated: [RegeneratedAccountIdentity]
    ) -> [Key: UUID] {
        var result: [Key: UUID] = [:]
        for (key, line) in lines {
            guard let parentID = line.parentID else { continue }
            let candidates = regenerated.filter { candidate in
                candidate.oldID == parentID
                    && candidate.newID != line.id
                    && candidate.parentID == nil
                    && !candidate.isSystem
                    && candidate.currencyCode != line.currencyCode
            }
            if candidates.count == 1, let only = candidates.first { result[key] = only.newID }
        }
        return result
    }

    // MARK: - Privado

    private static func structuralIssue(
        of node: AccountLineNode, parentID: UUID, counts: [UUID: Int], byID: [UUID: AccountLineNode]
    ) -> AccountLineIssue? {
        if parentID == node.id { return .selfLink }
        if counts[parentID] ?? 0 > 1 { return .ambiguousIdentity }
        guard let parent = byID[parentID] else { return .orphan }
        if node.isSystem || parent.isSystem { return .systemAccount }
        if parent.parentID != nil { return .principalIsLine }
        if parent.isArchived { return .principalArchived }
        if parent.currencyCode == node.currencyCode { return .sameCurrencyAsPrincipal }
        return nil
    }

    private static func slotKey(_ principalID: UUID, _ currencyCode: String) -> String {
        "\(principalID.uuidString)|\(currencyCode)"
    }
}
