//
//  CompartidoPersonasLogic.swift
//  Yala
//
//  El chip «Personas» de Compartido (lote 1, 26-nov-2026): una tarjeta por persona con la que compartes gastos, con
//  su neto por moneda sumando todos tus grupos. Lógica pura, sin SwiftData: recibe lo que `GroupsViewModel` ya cargó
//  de cada grupo y devuelve las dos listas (con deudas y liquidadas).
//
//  Tres reglas, decididas en el Paso 0 del encargo:
//  · Dos miembros de grupos distintos son la MISMA persona solo por su cuenta: `userID` del backend o, sin él, el
//    `cloudKitUserRecordID` de la era CloudKit. Nunca por el nombre: dos «Beto» sin cuenta se quedan aparte (D6).
//  · El neto de cada persona suma las deudas que su grupo ya enseña en la tarjeta (con «Menos pagos» y «Ver en una
//    moneda» de ESE grupo), archivados incluidos: archivar no salda (D5).
//  · «Liquidada» es neto cero con al menos un gasto o un pago contigo; quien solo comparte grupo no sale (D7).
//

import Foundation

enum CompartidoPersonasLogic {

    // MARK: - Entrada

    /// Un miembro de un grupo, ya leído del modelo.
    struct Member: Equatable, Sendable {
        let id: String
        let name: String
        /// Cuenta que identifica a la persona entre grupos; `nil` si no tiene (añadida a mano).
        let accountKey: String?
    }

    /// Lo que hace falta de un grupo para repartir su saldo por persona.
    struct GroupInput: Equatable, Sendable {
        let groupKey: String
        let groupName: String
        /// El grupo es una persona (`SplitGroup.isPerson`): en su tarjeta se nombra «Sin grupo», no con su nombre.
        var isPerson: Bool = false
        let members: [Member]
        /// Mis filas de miembro en este grupo (identidad resuelta: puede haber más de una en una zona migrada).
        let myMemberIDs: Set<String>
        /// Las deudas del grupo tal como las enseña su tarjeta (simplificadas o no, convertidas o no).
        let debts: [Debt]
        /// Con quién tuve algún gasto o pago en este grupo, aunque hoy estemos a mano.
        let interactedMemberIDs: Set<String>
    }

    // MARK: - Salida

    struct Person: Identifiable, Equatable, Sendable {
        let id: String
        let name: String
        /// Los grupos donde compartes con esta persona, en el orden de la lista de Grupos.
        let groupNames: [String]
        /// Neto por moneda: positivo, te debe; negativo, le debes. Sin las monedas en cero.
        let netByCurrency: [String: Double]

        var isSettled: Bool { netByCurrency.isEmpty }

        /// Las filas de la tarjeta, una por moneda, en el formato de la tarjeta de grupo: primero lo que debes.
        var rows: [GroupsViewModel.DebtRow] {
            netByCurrency
                .map { currency, value in
                    GroupsViewModel.DebtRow(
                        id: "\(id)-\(currency)",
                        counterpartyName: name,
                        amount: abs(value),
                        currencyCode: currency,
                        perspective: value < 0 ? .iOwe : .theyOweMe,
                        wasConverted: false)
                }
                .sorted { lhs, rhs in
                    if lhs.perspective != rhs.perspective { return lhs.perspective == .iOwe }
                    return lhs.currencyCode < rhs.currencyCode
                }
        }
    }

    struct Result: Equatable, Sendable {
        /// Personas con algo pendiente, de mayor a menor importe.
        let active: [Person]
        /// Personas con las que quedaste a mano, por nombre.
        let settled: [Person]

        var isEmpty: Bool { active.isEmpty && settled.isEmpty }
    }

    /// Por debajo de esto un neto es cero (el mismo umbral que `GroupBalanceService`).
    static let epsilon = 0.01

    // MARK: - Cálculo

    /// `noGroupLabel`: cómo se nombra lo que se comparte con una persona fuera de un grupo («Sin grupo»).
    static func people(from groups: [GroupInput], noGroupLabel: String = "") -> Result {
        var order: [String] = []
        var names: [String: String] = [:]
        var groupNames: [String: [String]] = [:]
        var net: [String: [String: Double]] = [:]
        var interacted = Set<String>()

        for group in groups {
            let byID = Dictionary(group.members.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            var touched = Set<String>()

            func key(for memberID: String) -> String? {
                guard !group.myMemberIDs.contains(memberID), let member = byID[memberID] else { return nil }
                let key = personKey(member: member, groupKey: group.groupKey)
                if names[key] == nil {
                    names[key] = member.name
                    order.append(key)
                }
                if !touched.contains(key) {
                    touched.insert(key)
                    let label = group.isPerson ? noGroupLabel : group.groupName
                    if !(groupNames[key] ?? []).contains(label) { groupNames[key, default: []].append(label) }
                }
                return key
            }

            for debt in group.debts {
                if group.myMemberIDs.contains(debt.toMemberID), let other = key(for: debt.fromMemberID) {
                    net[other, default: [:]][debt.currencyCode, default: 0] += debt.amount
                    interacted.insert(other)
                } else if group.myMemberIDs.contains(debt.fromMemberID), let other = key(for: debt.toMemberID) {
                    net[other, default: [:]][debt.currencyCode, default: 0] -= debt.amount
                    interacted.insert(other)
                }
            }
            for memberID in group.interactedMemberIDs {
                if let other = key(for: memberID) { interacted.insert(other) }
            }
        }

        var active: [Person] = []
        var settled: [Person] = []
        for key in order where interacted.contains(key) {
            let cleaned = (net[key] ?? [:]).compactMapValues { value -> Double? in
                let rounded = (value * 100).rounded() / 100
                return abs(rounded) >= epsilon ? rounded : nil
            }
            let person = Person(
                id: key, name: names[key] ?? "", groupNames: groupNames[key] ?? [], netByCurrency: cleaned)
            if person.isSettled { settled.append(person) } else { active.append(person) }
        }
        active.sort { lhs, rhs in
            let l = lhs.netByCurrency.values.map(abs).max() ?? 0
            let r = rhs.netByCurrency.values.map(abs).max() ?? 0
            if l != r { return l > r }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        settled.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return Result(active: active, settled: settled)
    }

    /// La clave de una persona: su cuenta si la tiene; si no, ella misma dentro de su grupo.
    static func personKey(member: Member, groupKey: String) -> String {
        if let account = member.accountKey, !account.isEmpty { return "cuenta:\(account)" }
        return "grupo:\(groupKey):\(member.id)"
    }

    /// La cuenta de un miembro: `userID` del backend; sin él, el `cloudKitUserRecordID` de la era CloudKit. Un miembro
    /// eliminado (`deletedUserSentinel`) no tiene cuenta que lo junte con nadie.
    static func accountKey(userID: String?, cloudKitUserRecordID: String, displayName: String) -> String? {
        if displayName == SplitMember.deletedUserSentinel { return nil }
        if let userID, !userID.isEmpty { return "u:\(userID)" }
        if !cloudKitUserRecordID.isEmpty { return "ck:\(cloudKitUserRecordID)" }
        return nil
    }

    /// Con quién tuve algún gasto o pago en un grupo: quien pagó un gasto en el que tengo parte, quien tiene parte en
    /// uno que pagué yo, y quien me pagó o a quien pagué.
    static func interactedMemberIDs(
        myMemberIDs: Set<String>,
        expenses: [(id: UUID, paidBy: String)],
        shares: [(expenseID: UUID, memberID: String)],
        settlements: [(from: String, to: String)]
    ) -> Set<String> {
        var result = Set<String>()
        let sharesByExpense = Dictionary(grouping: shares, by: \.expenseID)
        for expense in expenses {
            let participants = Set((sharesByExpense[expense.id] ?? []).map(\.memberID))
            if myMemberIDs.contains(expense.paidBy) {
                result.formUnion(participants)
            } else if !participants.isDisjoint(with: myMemberIDs) {
                result.insert(expense.paidBy)
            }
        }
        for settlement in settlements {
            if myMemberIDs.contains(settlement.from) { result.insert(settlement.to) }
            if myMemberIDs.contains(settlement.to) { result.insert(settlement.from) }
        }
        return result.subtracting(myMemberIDs)
    }
}

/// Qué chip de Compartido manda en pantalla.
enum CompartidoChipLogic {
    /// Los chips solo están con la lista de grupos activos. Sin ella (cargando, sin grupos o solo archivados) la pestaña
    /// es la de hoy, y la barra y la lista se portan como el chip Grupos aunque Personas siguiera elegido.
    static func shown(selected: CompartidoChip, hasLoaded: Bool, hasActiveGroups: Bool) -> CompartidoChip {
        hasLoaded && hasActiveGroups ? selected : .groups
    }
}
