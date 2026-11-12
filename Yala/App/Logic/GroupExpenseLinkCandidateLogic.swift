//
//  GroupExpenseLinkCandidateLogic.swift
//  Yala
//
//  UX 2.2 · L13-15 (decisión B de Jürgen, 2026-10-18): al completar el borrador de un gasto de grupo que pagaste tú,
//  «¿Ya lo apuntaste?» enseña los movimientos parecidos de ese día y elegir uno los enlaza.
//
//  «Parecido» es aquí MISMO día, MISMA divisa y MISMO importe (al céntimo). No es un capricho: al enlazar, el movimiento
//  pasa a ser la pata real del gasto y el puente le reescribe el importe a `-total` en cada re-puente
//  (`GroupTransactionBridge.bridgeExpense`, preserve+update). Con una tolerancia, enlazar le cambiaría el importe a lo
//  que la persona apuntó; con el importe exacto no cambia nada.
//
//  Fuera, siempre: lo que ya cuelga de un grupo (otra pata), las transferencias, los ajustes de saldo, lo que está en una
//  cuenta del sistema (las patas virtuales), el registro de un pago de grupo ya aprobado (su transacción real no lleva
//  puntero, D7, y se reconoce por su borrador aprobado) y lo que el libro de conservados guarda de un desasociar.
//

import Foundation

nonisolated enum GroupExpenseLinkCandidateLogic {

    /// Lo que hace falta saber de un movimiento para decidir, sin `@Model` (testeable sin contexto).
    struct Movement: Equatable {
        let date: Date
        let amount: Double
        let currencyCode: String
        let hasGroupPointer: Bool
        let isTransfer: Bool
        let isBalanceAdjustment: Bool
        let isOnRealAccount: Bool
        let isGroupPaymentRecord: Bool
        /// El libro de conservados al desasociar lo guarda como lo que dejó OTRO gasto o pago.
        let isConservedFromDetach: Bool
    }

    /// Cuántos se enseñan como mucho. Con más de tres «iguales» el mismo día la lista deja de ayudar.
    static let maxShown = 3

    static func isCandidate(
        _ movement: Movement,
        expenseTotal: Double,
        expenseCurrency: String,
        expenseDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard movement.isOnRealAccount,
              !movement.hasGroupPointer,
              !movement.isTransfer,
              !movement.isBalanceAdjustment,
              !movement.isGroupPaymentRecord,
              !movement.isConservedFromDetach else { return false }
        guard movement.currencyCode == expenseCurrency else { return false }
        // Un gasto sale de la cuenta: el movimiento es `-total`.
        guard abs(movement.amount + expenseTotal) < 0.005 else { return false }
        return calendar.isDate(movement.date, inSameDayAs: expenseDate)
    }
}
