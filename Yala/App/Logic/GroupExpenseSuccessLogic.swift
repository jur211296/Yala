//
//  GroupExpenseSuccessLogic.swift
//  Yala
//
//  Pure-logic que traduce el reparto de un gasto de grupo recién creado/editado en la
//  deuda que le queda al usuario actual. Alimenta `GroupExpenseSuccessView` y es testeable
//  sin `ModelContext` (sin SwiftData ni singletons).
//

import Foundation

/// Impacto de un gasto de grupo para el usuario actual, tras crearlo/editarlo.
/// `nonisolated`: bajo `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` el enum sería `@MainActor`
/// por default y su conformance `Equatable` no podría usarse desde contexto nonisolated
/// (tests Swift Testing) — error en Swift 6.
nonisolated enum GroupExpenseDebt: Equatable {
    /// El usuario pagó; los demás le deben este monto (total − su parte).
    case theyOweMe(Double)
    /// Pagó otra persona; el usuario le debe su parte.
    case iOwe(Double)
    /// El usuario pagó y era el único participante (o el resto ≈ 0): sin deuda pendiente.
    case settled
}

nonisolated enum GroupExpenseSuccessLogic {

    /// Umbral bajo el cual una diferencia se trata como cero — evita mostrar
    /// "te deben 0.00" por redondeos de la división.
    static let epsilon = 0.005

    /// Traduce el reparto de un gasto en la deuda del usuario actual.
    /// - Si el usuario pagó (`paidByMemberID == currentUserMemberID`): los demás le deben
    ///   `total − miParte` → `.theyOweMe` (o `.settled` si ese resto es ~0).
    /// - Si pagó otra persona: el usuario le debe su parte → `.iOwe` (o `.settled` si su parte es ~0).
    /// - `currentUserMemberID == nil` (caso edge, current user no resuelto) → `.settled`.
    static func debt(
        total: Double,
        shares: [(memberID: String, amount: Double)],
        currentUserMemberID: String?,
        paidByMemberID: String
    ) -> GroupExpenseDebt {
        let myShare = currentUserMemberID.flatMap { myID in
            shares.first(where: { $0.memberID == myID })?.amount
        } ?? 0

        let iPaid = currentUserMemberID != nil && paidByMemberID == currentUserMemberID
        if iPaid {
            let owedToMe = total - myShare
            return owedToMe > epsilon ? .theyOweMe(owedToMe) : .settled
        } else {
            return myShare > epsilon ? .iOwe(myShare) : .settled
        }
    }
}
