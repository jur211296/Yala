//
//  PendingGroupImportApplier.swift
//  Yala
//
//  Convierte en saldos iniciales las aristas de un import que ya se pueden crear, y deja apuntado lo que espera.
//
//  Cada arista pasa por `GroupExpenseService.setOpeningBalance`, el mismo camino de «Añadir saldo inicial»: hereda sus
//  permisos (dueño o admin), el freeze del grupo, que no avisa a nadie y que no cuenta en las estadísticas. Se marca como
//  creada justo después de crearla, una a una: si la tercera falla, las dos primeras no se vuelven a crear.
//

import Foundation

@MainActor
enum PendingGroupImportApplier {

    /// Crea un saldo inicial: deudor, acreedor, importe y moneda. Inyectable en los tests.
    typealias CreateOpeningBalance = (_ debtorMemberID: String, _ creditorMemberID: String, _ amount: Double,
                                      _ currencyCode: String) throws -> Void

    struct Outcome: Equatable {
        /// Saldos iniciales creados en esta pasada.
        var created: Int
        /// Personas que aún esperan a ser emparejadas.
        var stillPending: [String]
        /// La pasada se cortó por un error (el texto lo pone la vista).
        var failed: Bool
        /// No queda ninguna arista por crear: lo que esperaba se borró.
        var isComplete: Bool = false
    }

    /// Al crear el grupo desde un import: apunta lo que espera, con «yo» ya emparejado con el miembro del dueño, y crea lo
    /// que ya se pueda (nada, salvo que el export no tenga más gente con saldo). Sin aristas no apunta nada.
    @discardableResult
    static func start(
        snapshot: ImportedGroupSnapshot,
        me: String?,
        zoneID: String,
        ownerMemberID: String?,
        activeMemberIDs: Set<String>,
        store explicitStore: PendingGroupImportStore? = nil,
        now: Date = .now,
        create: CreateOpeningBalance
    ) -> Outcome {
        // El valor por defecto de un parámetro se evalúa fuera del actor principal: `.shared` se resuelve aquí dentro.
        let store = explicitStore ?? .shared
        let debts = ImportedDebtPlanLogic.debts(from: snapshot.balances)
        guard !debts.isEmpty else { return Outcome(created: 0, stillPending: [], failed: false, isComplete: true) }
        var mapping: [String: String] = [:]
        if let me, let ownerMemberID { mapping[me] = ownerMemberID }
        store.save(PendingGroupImport(
            zoneID: zoneID,
            source: snapshot.source,
            people: snapshot.people,
            balances: snapshot.balances,
            debts: debts,
            mapping: mapping,
            applied: [],
            createdAt: now
        ))
        return apply(zoneID: zoneID, activeMemberIDs: activeMemberIDs, store: store, create: create)
    }

    /// Guarda el emparejamiento elegido y crea las aristas que ya tienen a sus dos personas. Completo, el import se borra.
    @discardableResult
    static func apply(
        zoneID: String,
        mapping newMapping: [String: String]? = nil,
        activeMemberIDs: Set<String>,
        store explicitStore: PendingGroupImportStore? = nil,
        create: CreateOpeningBalance
    ) -> Outcome {
        let store = explicitStore ?? .shared
        guard var pending = store.pending(for: zoneID) else {
            return Outcome(created: 0, stillPending: [], failed: false)
        }
        if let newMapping { pending.mapping = newMapping }
        store.save(pending)

        var created = 0
        var failed = false
        let ready = ImportedDebtPlanLogic.applicable(
            debts: pending.debts, mapping: pending.mapping, applied: pending.applied, activeMemberIDs: activeMemberIDs)
        for item in ready {
            do {
                try create(item.debtorMemberID, item.creditorMemberID, Double(item.debt.cents) / 100, item.debt.currency)
                pending.applied.insert(item.debt.id)
                store.save(pending)
                created += 1
            } catch {
                #if DEBUG
                print("PendingGroupImportApplier: Error: \(error)")
                #endif
                failed = true
                break
            }
        }

        if pending.isComplete {
            store.remove(zoneID: zoneID)
        }
        let stillPending = ImportedDebtPlanLogic.pendingPeople(
            debts: pending.debts, applied: pending.applied, people: pending.people, mapping: pending.mapping,
            activeMemberIDs: activeMemberIDs)
        return Outcome(created: created, stillPending: stillPending, failed: failed, isComplete: pending.isComplete)
    }

    /// El camino de producción: el saldo inicial de siempre, fechado hoy.
    static func liveCreate(in group: SplitGroup) -> CreateOpeningBalance {
        { debtor, creditor, amount, currency in
            _ = try GroupExpenseService.shared.setOpeningBalance(
                in: group,
                debtorMemberID: debtor,
                creditorMemberID: creditor,
                amount: amount,
                currencyCode: currency,
                date: .now
            )
        }
    }
}
