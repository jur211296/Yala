//
//  GroupNotificationRecipientLogic.swift
//  Yala
//
//  Pure-logic que decide SI una notificación de gasto/liquidación debe llegarle
//  al current user, según su participación. Extraído de GroupNotificationService
//  para test sin SwiftData/CloudKit (regla R8: makeTestContext flakea en local).
//
//  Antes, un gasto nuevo/modificado notificaba a TODO el grupo (el clasificador
//  solo miraba tipo de record + zona, nunca SplitShare), y la liquidación
//  ("te pagó") llegaba a terceros a los que no se les pagó. Ahora:
//  - Gasto: no me notifico de lo que yo mismo pagué, y solo si tengo un share.
//  - Liquidación: solo al receptor real (toMemberID).
//
//  Los IDs (paidByMemberID, SplitShare.memberID, currentMemberID) provienen todos
//  de `SplitMember.id.uuidString` (uppercase canónico de UUID) → comparar por
//  String directo es seguro, sin riesgo de case-mismatch.
//

import Foundation

enum ExpenseNotifyDecision: Equatable {
    /// No notificar (soy el autor, no participo, o no sé quién soy).
    case skip
    /// Notificar mostrando la porción que me toca a mí.
    case notify(share: Double)
}

enum GroupNotificationRecipientLogic {
    /// Decide si un gasto (nuevo o modificado) debe notificarme.
    /// - `currentMemberID == nil` (mi SplitMember aún no marcado isCurrentUser) → `.skip` conservador.
    /// - Soy el pagador → `.skip` (no me notifico de lo que yo registré).
    /// - No tengo share, o mi share es 0 → `.skip` (no participo, me quitaron del split,
    ///   o mi porción es 0 → "te toca S/0" sería ruido; financieramente no me concierne).
    /// - En otro caso → `.notify(share:)` con mi porción.
    static func expenseDecision(currentMemberID: String?,
                                paidByMemberID: String,
                                myShareAmount: Double?) -> ExpenseNotifyDecision {
        guard let me = currentMemberID else { return .skip }
        if paidByMemberID == me { return .skip }
        guard let share = myShareAmount, share > 0 else { return .skip }
        return .notify(share: share)
    }

    /// Una liquidación solo notifica a su receptor real. Excluye al pagador por
    /// construcción (él es `fromMemberID`, no `toMemberID`).
    static func shouldNotifySettlement(currentMemberID: String?, toMemberID: String) -> Bool {
        guard let me = currentMemberID else { return false }
        return toMemberID == me
    }
}
