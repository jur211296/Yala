//
//  GroupBridgeLeftoverLogic.swift
//  Yala
//
//  Qué le SOBRA al puente de Grupos en tus registros cuando una pasada suya no vio lo que ya había (bug del 2026-11-09,
//  Jürgen: gastos de grupo pagados con cuenta que dejaron un borrador «Falta: Cuenta» en la Bandeja y el «Préstamo a
//  grupos» repetido).
//
//  Cómo se llega ahí. La pasada REMOTA del puente (la que corre cuando un gasto baja por el canal de Grupos, o el
//  reintento del arranque) busca tu registro real por `splitExpenseID` y cuenta no de sistema. Si en ese instante no lo
//  ve —su fila aún no está aquí, o está sin cuenta mientras el canal personal la re-aplica—, crea el borrador «Elige
//  cuenta» (`createDraftCaseA(.remoteCreate)`) y una pata de préstamo nueva al lado de la que ya existía. Cuando el
//  registro real vuelve a verse, nadie lo arreglaba: la única limpieza (`GroupBridgeRaceCleaner`) solo corría tras un
//  import de iCloud y solo retiraba el borrador. En la nube no corría nunca, y el préstamo doble no lo quitaba nadie.
//
//  Lo que SOBRA, y nada más:
//   - Un borrador PENDIENTE de gasto de grupo que pide cuenta, creado por el puente (no el «Sí, registrar» del puente
//     apagado: `optInPersonalOnly`), de un gasto cuyo registro real con cuenta ya está aquí.
//   - Las patas de «Préstamo a grupos» del MISMO gasto, en la misma cuenta de sistema, divisa e importe, más allá de
//     una. El puente nunca crea más de una por gasto (Caso A: una `+lent`; solo grupos: una `+total`; con líneas, el
//     préstamo engorda en la misma). Se queda la MÁS NUEVA; empate, el menor `syncID`: dos dispositivos que vean las
//     mismas filas eligen la MISMA (regla de `swiftdata-cloudkit.md`, «fundir duplicados que llegan de dos dispositivos»;
//     `createdAt` viaja en los dos almacenes). La más nueva y no la más antigua porque cada pasada del puente BORRA el
//     préstamo que ve y crea otro: quedarse con el viejo podía borrar justo el que la última pasada conserva y, al llegar
//     después el borrado del viejo desde el otro dispositivo, dejar el gasto sin ninguno (review adversarial del
//     2026-11-09). Si los importes NO coinciden no se toca nada: uno sería el viejo y no se adivina cuál.
//
//  Una pata sin cuenta no cuenta para nada (ni como real ni como préstamo): es justo el estado en que la pasada remota
//  se equivoca, y aquí no se decide sobre él.
//
//  `onlyCreatedSince`: la limpieza AUTOMÁTICA solo quita lo que nació desde que se instaló el arreglo (decisión de
//  Jürgen del 2026-11-09: «solo lo nuevo»; lo de antes lo limpia la persona desde el aviso de la Bandeja, viendo qué se
//  quita). Con `nil`, todo (el aviso).
//
import Foundation

nonisolated enum GroupBridgeLeftoverLogic {

    struct Leg: Equatable {
        let expenseID: String
        /// `nil` = la pata no tiene cuenta (o no se pudo leer): no participa.
        let accountKey: String?
        let accountIsSystem: Bool
        let isLoanToGroups: Bool
        /// Patas que el puente gestiona aparte: derivadas de una línea (Grupos B) o cobradas de una venta.
        let isManagedApart: Bool
        let amount: Double
        let currencyCode: String
        let createdAt: Date
        let tiebreak: String
    }

    struct Draft: Equatable {
        let expenseID: String?
        let isPending: Bool
        let isGroupExpense: Bool
        let isOptIn: Bool
        let needsAccount: Bool
        let createdAt: Date
    }

    struct Plan: Equatable {
        var draftIndices: [Int] = []
        var legIndices: [Int] = []
        /// Gastos afectados, para contarlos en el aviso.
        var expenseIDs: Set<String> = []
        var isEmpty: Bool { draftIndices.isEmpty && legIndices.isEmpty }
    }

    static func plan(legs: [Leg], drafts: [Draft], onlyCreatedSince since: Date?) -> Plan {
        var plan = Plan()
        func isNew(_ date: Date) -> Bool { since.map { date >= $0 } ?? true }

        // Gastos con su registro real a la vista: cuenta de verdad, no de sistema, y no una pata gestionada aparte.
        let withRealRecord = Set(legs.compactMap { leg -> String? in
            guard leg.accountKey != nil, !leg.accountIsSystem, !leg.isManagedApart else { return nil }
            return leg.expenseID
        })

        for (index, draft) in drafts.enumerated() {
            guard draft.isPending, draft.isGroupExpense, !draft.isOptIn, draft.needsAccount,
                  let id = draft.expenseID, withRealRecord.contains(id), isNew(draft.createdAt) else { continue }
            plan.draftIndices.append(index)
            plan.expenseIDs.insert(id)
        }

        // Préstamos repetidos: mismo gasto, misma cuenta de sistema, misma divisa y mismo importe (al céntimo).
        struct LoanKey: Hashable { let expense: String; let account: String; let currency: String; let cents: Int64 }
        var groups: [LoanKey: [Int]] = [:]
        for (index, leg) in legs.enumerated() {
            guard let account = leg.accountKey, leg.accountIsSystem, leg.isLoanToGroups, !leg.isManagedApart,
                  leg.amount.isFinite else { continue }
            let key = LoanKey(expense: leg.expenseID, account: account, currency: leg.currencyCode,
                              cents: Int64((leg.amount * 100).rounded()))
            groups[key, default: []].append(index)
        }
        // Un gasto cuyos préstamos tienen importes distintos no se toca: no se adivina cuál es el viejo.
        let loansPerExpense = Dictionary(grouping: groups.keys, by: \.expense).mapValues(\.count)
        for (key, indices) in groups where indices.count > 1 && loansPerExpense[key.expense] == 1 {
            // El superviviente va primero: el más nuevo; empate, el menor desempate.
            let ordered = indices.sorted { a, b in
                if legs[a].createdAt != legs[b].createdAt { return legs[a].createdAt > legs[b].createdAt }
                return legs[a].tiebreak < legs[b].tiebreak
            }
            for index in ordered.dropFirst() where isNew(legs[index].createdAt) {
                plan.legIndices.append(index)
                plan.expenseIDs.insert(key.expense)
            }
        }
        plan.draftIndices.sort()
        plan.legIndices.sort()
        return plan
    }
}
