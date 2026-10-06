//
//  GroupSettlementAmountChangeLogic.swift
//  Yala
//
//  Ticket `settlement-amount-edited-after-approval-leaves-the-bank-stale` (decisión A de Jürgen, 2026-10-04): si cambia
//  el importe de una liquidación que la persona ya aprobó a una cuenta real, el Inbox avisa y ofrece ajustar esa
//  transacción. La transacción real no sigue sola a la liquidación (D7 de `DraftService`); solo cambia si la persona
//  acepta el aviso.
//
//  Decisión pura, sin SwiftData: qué avisos de una liquidación sobran y qué importe tiene que llevar el pendiente.
//

import Foundation

nonisolated enum GroupSettlementAmountChangeLogic {

    /// Por debajo de medio céntimo dos importes son el mismo: los importes viajan como `Double` por el wire.
    static let tolerance = 0.005

    static func isSameAmount(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(abs(lhs) - abs(rhs)) < tolerance
    }

    /// La marca de aprobación de la liquidación (`DraftService.insertSettlementApprovalMark`). `amount` es el importe
    /// ya revisado, con signo: el que se aprobó o al que la persona ajustó desde un aviso. `transactionAmount` y
    /// `transactionCurrency` son los de su transacción real, `nil` si no está (la persona la borró, o CloudKit trajo
    /// la marca antes que ella).
    struct Mark: Equatable {
        let amount: Double?
        let transactionAmount: Double?
        let transactionCurrency: String?
    }

    struct Notice: Equatable {
        let status: DraftStatus
        let amount: Double?
    }

    struct Plan: Equatable {
        /// Importe con signo que tiene que llevar el único aviso pendiente; `nil` si no hace falta avisar.
        let pendingAmount: Double?
        /// Índice del aviso pendiente que se conserva y se pone al día. `nil` con `pendingAmount` = crear uno nuevo.
        let keepPendingIndex: Int?
        /// Avisos que sobran (índices de `notices`).
        let deleteIndices: [Int]

        static let nothing = Plan(pendingAmount: nil, keepPendingIndex: nil, deleteIndices: [])
    }

    /// Decide, para una liquidación, qué avisos quedan. `notices` llega ORDENADO de forma estable (el más antiguo primero):
    /// el pendiente que se conserva es el primero, y dos dispositivos que ven los mismos avisos conservan el mismo.
    ///
    /// - Sin UNA marca viva (ninguna, o dos de dos dispositivos que aprobaron a la vez), con su transacción en otra
    ///   divisa, o con la liquidación en el SENTIDO contrario al de la marca (`expectsOutflow`: yo pago ⇒ negativo), no
    ///   hay nada que ajustar con un importe: sobran los pendientes. Los rechazados se quedan, son la decisión de la
    ///   persona y la transacción puede llegar después. El cambio de sentido no se ajusta aquí: conservaría el signo
    ///   viejo (ticket `settlement-direction-edited-after-approval-leaves-the-bank-stale`).
    /// - Si la marca ya está en el importe de la liquidación, o la transacción ya lo tiene (la persona la editó a mano),
    ///   no hay nada que preguntar: sobran todos. Sin esto la hoja ofrecería «Ajustar a 30» y «Dejar en 30».
    /// - Si la persona ya dejó esta misma corrección como estaba (un rechazado con el importe de hoy), no se vuelve a
    ///   preguntar: sobran los pendientes y los rechazados de otras cifras.
    /// - Si no, toca avisar con el importe de hoy: se conserva el primer pendiente (puesto al día) y sobran los demás
    ///   pendientes y los rechazados, que eran de otra corrección.
    static func plan(
        settlementAmount: Double,
        settlementCurrency: String,
        expectsOutflow: Bool?,
        marks: [Mark],
        notices: [Notice]
    ) -> Plan {
        let pending = notices.indices.filter { notices[$0].status == .pending }
        let rejected = notices.indices.filter { notices[$0].status == .rejected }
        let allButRejected = notices.indices.filter { notices[$0].status != .rejected }

        let live = marks.filter { $0.transactionAmount != nil }
        guard live.count == 1, let mark = live.first,
              let transactionAmount = mark.transactionAmount,
              mark.transactionCurrency == settlementCurrency else {
            return Plan(pendingAmount: nil, keepPendingIndex: nil, deleteIndices: allButRejected)
        }

        let reviewed = mark.amount ?? transactionAmount
        if let expectsOutflow, (reviewed < 0) != expectsOutflow {
            return Plan(pendingAmount: nil, keepPendingIndex: nil, deleteIndices: allButRejected)
        }
        if isSameAmount(reviewed, settlementAmount) || isSameAmount(transactionAmount, settlementAmount) {
            return Plan(pendingAmount: nil, keepPendingIndex: nil, deleteIndices: Array(notices.indices))
        }

        if let kept = rejected.first(where: { notices[$0].amount.map { isSameAmount($0, settlementAmount) } ?? false }) {
            return Plan(pendingAmount: nil, keepPendingIndex: nil,
                        deleteIndices: notices.indices.filter { $0 != kept })
        }

        let signed = reviewed < 0 ? -abs(settlementAmount) : abs(settlementAmount)
        let keep = pending.first
        return Plan(pendingAmount: signed, keepPendingIndex: keep,
                    deleteIndices: notices.indices.filter { $0 != keep })
    }
}
