//
//  GroupsAccountCardLogic.swift
//  Yala
//
//  Card extra de Jürgen (2026-11-03) · las cuentas de sistema de Grupos ocupan un solo sitio en «Tus finanzas».
//
//  Las cuentas de sistema son una por MONEDA («Grupos PEN», «Grupos USD»: `GroupBridgeSystemEntities`), no una por grupo,
//  y el carrusel y los chips del Panel las pintaban cada una por su lado. Ahora van en UNA tarjeta «Grupos», en el sitio
//  de la primera, y dentro se ve una línea por grupo con lo que ese grupo aporta: la suma de los movimientos de las
//  cuentas de sistema que apuntan a él. Las cuentas siguen siendo las mismas y el total de la tarjeta es la suma de sus
//  saldos, así que ningún saldo cambia: solo cambia cómo se agrupan en pantalla.
//

nonisolated enum GroupsAccountCardLogic {

    /// Junta las tarjetas cuya cabeza es una cuenta de sistema en una sola, en el sitio de la primera, con las demás
    /// cuentas de sistema como sus líneas. Con una o ninguna, las tarjetas quedan como estaban.
    static func mergingSystemCards<E>(_ cards: [AccountCard<E>], isSystem: (E) -> Bool) -> [AccountCard<E>] {
        let system = cards.filter { isSystem($0.head) }
        guard system.count > 1, let first = system.first else { return cards }
        let members = system.flatMap(\.members)
        let merged = AccountCard(head: first.head, lines: Array(members.dropFirst()))
        var result: [AccountCard<E>] = []
        var placed = false
        for card in cards {
            guard isSystem(card.head) else { result.append(card); continue }
            if !placed { result.append(merged); placed = true }
        }
        return result
    }

    /// Un movimiento de una cuenta de sistema: a qué grupo apunta (`nil` si a ninguno) y cuánto, en la moneda de su cuenta.
    struct Movement: Equatable, Sendable {
        let zoneID: String?
        let currencyCode: String
        let amount: Double
    }

    /// Lo que un grupo aporta en una moneda. `zoneID == nil` junta lo que no apunta a ningún grupo, para que la suma de las
    /// líneas de una moneda sea el saldo de su cuenta de sistema.
    struct GroupLine: Equatable, Sendable {
        let zoneID: String?
        let currencyCode: String
        let value: Double
    }

    /// Por debajo de medio céntimo, la línea es cero y no se enseña (un grupo saldado no ocupa sitio).
    static let negligible = 0.005

    /// Una línea por (grupo, moneda), las mayores primero. El orden es estable: a igual magnitud, por zona.
    static func groupLines(_ movements: [Movement]) -> [GroupLine] {
        struct Key: Hashable { let zoneID: String?; let currencyCode: String }
        var sums: [Key: Double] = [:]
        for movement in movements {
            sums[Key(zoneID: movement.zoneID, currencyCode: movement.currencyCode), default: 0] += movement.amount
        }
        return sums
            .filter { abs($0.value) >= negligible }
            .map { GroupLine(zoneID: $0.key.zoneID, currencyCode: $0.key.currencyCode, value: $0.value) }
            .sorted {
                if abs($0.value) != abs($1.value) { return abs($0.value) > abs($1.value) }
                if $0.currencyCode != $1.currencyCode { return $0.currencyCode < $1.currencyCode }
                return ($0.zoneID ?? "") < ($1.zoneID ?? "")
            }
    }
}
