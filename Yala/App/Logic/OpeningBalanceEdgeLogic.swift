//
//  OpeningBalanceEdgeLogic.swift
//  Yala
//
//  Pure-logic de los saldos iniciales de un grupo (card t3fq, 2026-10-28):
//
//  1. **Uno por pareja y moneda.** Un saldo inicial nuevo entre dos personas que ya tienen uno en la misma moneda
//     —en cualquier sentido— reemplaza al que había en vez de sumarse como otra fila. Dos saldos de la misma pareja y
//     moneda solo se suman, y en Registros salían dos filas para una sola deuda de partida.
//  2. **Qué abre «Saldo inicial» desde una persona.** Con exactamente un saldo en el que esa persona está (debe o le
//     deben), se edita ése; sin ninguno o con varios, se abre uno nuevo con ella en «Quién debe» (los varios siguen en
//     la sección «Saldos iniciales», cada uno con su fila).
//  3. **La fecha nunca va al futuro.** El formulario no la deja elegir, y el servicio la recorta por si llega otra.
//

import Foundation

enum OpeningBalanceEdgeLogic {

    /// Un saldo inicial ya resuelto a sus dos personas.
    struct Edge: Equatable {
        let id: UUID
        let debtorMemberID: String
        let creditorMemberID: String
        let currencyCode: String
    }

    /// El saldo que un saldo nuevo entre `memberA` y `memberB` en `currencyCode` reemplaza, o `nil` si no hay ninguno.
    /// Con varios (datos de antes de esta regla), el primero en el orden recibido: quien llama los pasa del más antiguo
    /// al más nuevo, y los demás se quedan como estaban.
    static func replaceable(
        among edges: [Edge],
        memberA: String,
        memberB: String,
        currencyCode: String
    ) -> Edge? {
        let pair: Set<String> = [memberA, memberB]
        return edges.first {
            $0.currencyCode == currencyCode && Set([$0.debtorMemberID, $0.creditorMemberID]) == pair
        }
    }

    /// Qué abre «Saldo inicial» en el menú de una persona.
    enum MemberEntry: Equatable {
        case edit(UUID)
        case create(prefillDebtorMemberID: String)
    }

    static func memberEntry(for memberID: String, among edges: [Edge]) -> MemberEntry {
        let mine = edges.filter { $0.debtorMemberID == memberID || $0.creditorMemberID == memberID }
        if mine.count == 1, let only = mine.first { return .edit(only.id) }
        return .create(prefillDebtorMemberID: memberID)
    }

    /// La fecha que se guarda: la elegida, salvo que sea posterior a `now`, que se queda en `now`.
    static func storedDate(_ chosen: Date, now: Date) -> Date {
        min(chosen, now)
    }
}
