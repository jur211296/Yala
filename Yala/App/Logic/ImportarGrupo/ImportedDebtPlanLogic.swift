//
//  ImportedDebtPlanLogic.swift
//  Yala
//
//  De los saldos de un export a los saldos iniciales de Yala, y cuáles se pueden crear ya.
//
//  Un saldo inicial de Yala es una arista «quién debe a quién» entre dos miembros activos, uno por pareja y moneda
//  (`GroupExpenseService.setOpeningBalance`). Los netos por persona se convierten en el mínimo de aristas: el mayor deudor
//  paga al mayor acreedor hasta que uno de los dos queda a cero, moneda por moneda. Con todas las aristas creadas, cada
//  miembro queda en Yala con el saldo exacto que tenía en la otra app. Una pareja nunca sale dos veces: en cada paso uno
//  de los dos sale de la cuenta.
//
//  Las personas del export que aún no están en el grupo no tienen miembro (el teléfono no puede crearlo: `SplitMember` es
//  solo de bajada). Sus aristas esperan a que se unan y alguien con permiso las empareje.
//

import Foundation

/// Una arista del import: `debtor` debe `cents` a `creditor` en `currency`. Personas por su nombre en el export.
struct ImportedDebt: Codable, Hashable, Sendable, Identifiable {
    let debtor: String
    let creditor: String
    let currency: String
    let cents: Int

    /// Con el separador de unidad (U+001F), que no aparece en un nombre: con «|», «A|B»→«C» y «A»→«B|C» chocaban.
    var id: String { [currency, debtor, creditor].joined(separator: "\u{1F}") }
}

enum ImportedDebtPlanLogic {

    /// El mínimo de aristas que deja a cada persona con su saldo, en orden estable (moneda, y dentro el orden de pago).
    static func debts(from balances: [String: [String: Int]]) -> [ImportedDebt] {
        var result: [ImportedDebt] = []
        for currency in balances.keys.sorted() {
            var creditors = (balances[currency] ?? [:]).filter { $0.value > 0 }.map { (name: $0.key, cents: $0.value) }
            var debtors = (balances[currency] ?? [:]).filter { $0.value < 0 }.map { (name: $0.key, cents: -$0.value) }
            // El mayor primero; a igual importe, por nombre: el mismo export da siempre las mismas aristas.
            let order: ((name: String, cents: Int), (name: String, cents: Int)) -> Bool = {
                $0.cents == $1.cents ? $0.name < $1.name : $0.cents > $1.cents
            }
            while !creditors.isEmpty && !debtors.isEmpty {
                creditors.sort(by: order)
                debtors.sort(by: order)
                let paid = min(creditors[0].cents, debtors[0].cents)
                result.append(ImportedDebt(
                    debtor: debtors[0].name, creditor: creditors[0].name, currency: currency, cents: paid))
                creditors[0].cents -= paid
                debtors[0].cents -= paid
                creditors.removeAll { $0.cents == 0 }
                debtors.removeAll { $0.cents == 0 }
            }
        }
        return result
    }

    /// El saldo que deja un conjunto de aristas a cada persona en cada moneda. Sirve para comprobar el plan (tests) y
    /// para enseñar en la vista previa lo que quedará en Yala.
    static func balances(after debts: [ImportedDebt]) -> [String: [String: Int]] {
        var result: [String: [String: Int]] = [:]
        for debt in debts {
            result[debt.currency, default: [:]][debt.creditor, default: 0] += debt.cents
            result[debt.currency, default: [:]][debt.debtor, default: 0] -= debt.cents
        }
        return result
    }

    /// Las aristas que se pueden crear ya: sus dos personas emparejadas con miembros activos distintos y sin crear aún.
    static func applicable(
        debts: [ImportedDebt],
        mapping: [String: String],
        applied: Set<String>,
        activeMemberIDs: Set<String>
    ) -> [(debt: ImportedDebt, debtorMemberID: String, creditorMemberID: String)] {
        debts.compactMap { debt in
            guard !applied.contains(debt.id),
                  let debtor = mapping[debt.debtor], activeMemberIDs.contains(debtor),
                  let creditor = mapping[debt.creditor], activeMemberIDs.contains(creditor),
                  debtor != creditor else { return nil }
            return (debt, debtor, creditor)
        }
    }

    /// Personas por emparejar: tienen alguna arista sin crear y todavía no se sabe quién son en el grupo (o su miembro
    /// ya no está activo). Quien ya está emparejado no sale aunque su arista espere a la otra persona: el aviso del grupo
    /// decía «Por emparejar: Tú y Carla» con «Tú» ya emparejado (medido en la captura del 2026-11-16).
    static func pendingPeople(
        debts: [ImportedDebt],
        applied: Set<String>,
        people: [String],
        mapping: [String: String],
        activeMemberIDs: Set<String>? = nil
    ) -> [String] {
        let waiting = debts.filter { !applied.contains($0.id) }
        let names = Set(waiting.flatMap { [$0.debtor, $0.creditor] })
        return people.filter { person in
            guard names.contains(person) else { return false }
            guard let member = mapping[person] else { return true }
            if let activeMemberIDs { return !activeMemberIDs.contains(member) }
            return false
        }
    }

    /// Una persona del export se propone para un miembro solo si su nombre coincide (sin mayúsculas, tildes ni espacios
    /// de sobra) con UN solo miembro libre, y ese miembro con una sola persona. Si hay dudas no se propone nada.
    static func suggestedMatches(
        people: [String],
        members: [(id: String, name: String)],
        alreadyMapped: [String: String]
    ) -> [String: String] {
        let usedMembers = Set(alreadyMapped.values)
        let freeMembers = members.filter { !usedMembers.contains($0.id) }
        let freePeople = people.filter { alreadyMapped[$0] == nil }
        var result: [String: String] = [:]
        for person in freePeople {
            let key = nameKey(person)
            let candidates = freeMembers.filter { nameKey($0.name) == key }
            let rivals = freePeople.filter { nameKey($0) == key }
            if candidates.count == 1, rivals.count == 1 { result[person] = candidates[0].id }
        }
        return result
    }

    static func nameKey(_ name: String) -> String {
        GroupExportCSV.headerKey(name)
    }
}
