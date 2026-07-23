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
//  - Gasto: no me notifico de lo que YO CREÉ/EDITÉ, y solo si tengo un share.
//  - Liquidación: solo al receptor real (toMemberID), y no de la que YO registré.
//
//  Autoexclusión del eco por AUTOR (2026-07-23): al editar un gasto pagado por
//  otro, el cambio se pushea a CloudKit y el eco vuelve por fetchedRecordZoneChanges
//  → notificaba atribuyendo al PAGADOR (proxy), no al editor. El campo stored
//  `SplitExpense.lastEditedByMemberID` (id del editor, escrito por el path local)
//  permite (a) atribuir "X actualizó" al editor real y (b) autoexcluir el eco de
//  la propia edición de forma determinista (mismo device y 2º device mismo iCloud,
//  que resuelven el MISMO SplitMember.id). Se prefirió un campo stored a la metadata
//  CloudKit `lastModifiedUserRecordID` (que devuelve "__defaultOwner__" para la
//  edición del propio owner y difiere por participante en zonas compartidas), igual
//  que el patrón de autoexclusión de members. `recordedByMemberID` hace lo análogo
//  para la liquidación (eco Caso D: registro "X me pagó"). Campo nil ⇒ fallback al
//  comportamiento legado (proxy paidByMemberID). Residual de rollout (limitación de
//  plataforma): una edición hecha por un cliente en app VIEJA no deja nil — CloudKit
//  hace merge por-campo y RETIENE el autor previo → puede atribuir/suprimir por un autor
//  que ya no corresponde; transitorio, auto-sana cuando todos actualizan.
//
//  Los IDs (paidByMemberID, lastEditedByMemberID, recordedByMemberID, SplitShare.memberID,
//  currentMemberID) provienen todos de `SplitMember.id.uuidString` (uppercase canónico
//  de UUID) → comparar por String directo es seguro, sin riesgo de case-mismatch.
//

import Foundation

enum ExpenseNotifyDecision: Equatable {
    /// No notificar (soy el autor, no participo, o no sé quién soy).
    case skip
    /// Notificar mostrando la porción que me toca a mí.
    case notify(share: Double)
}

enum GroupNotificationRecipientLogic {
    /// Miembro al que se ATRIBUYE el gasto ("X agregó/actualizó"): el editor real si se conoce,
    /// si no el pagador como proxy legado (records pre-campo o editor con app vieja).
    /// SSOT de la regla de atribución — consumido por `GroupNotificationService.buildExpenseNotification`.
    static func expenseAttributionMemberID(lastEditedByMemberID: String?,
                                           paidByMemberID: String) -> String {
        lastEditedByMemberID ?? paidByMemberID
    }

    /// Decide si un gasto (nuevo o modificado) debe notificarme.
    /// - `currentMemberID == nil` (mi SplitMember aún no marcado isCurrentUser) → `.skip` conservador.
    /// - YO hice el cambio (autor efectivo == yo) → `.skip` (autoexclusión del eco de mi propia
    ///   creación/edición; el autor efectivo es `lastEditedByMemberID`, o el pagador como proxy si nil).
    /// - Soy el pagador → `.skip` (preserva el comportamiento legado: nunca notificar al pagador;
    ///   cambiarlo — notificar "alguien editó un gasto que pagué yo" — queda fuera de scope).
    /// - No tengo share, o mi share es 0 → `.skip` (no participo, me quitaron del split,
    ///   o mi porción es 0 → "te toca S/0" sería ruido; financieramente no me concierne).
    /// - En otro caso → `.notify(share:)` con mi porción.
    static func expenseDecision(currentMemberID: String?,
                                paidByMemberID: String,
                                lastEditedByMemberID: String? = nil,
                                myShareAmount: Double?) -> ExpenseNotifyDecision {
        guard let me = currentMemberID else { return .skip }
        // Autor efectivo del cambio; si el campo es nil (legado) cae al proxy pagador.
        let author = lastEditedByMemberID ?? paidByMemberID
        if author == me { return .skip }
        if paidByMemberID == me { return .skip }
        guard let share = myShareAmount, share > 0 else { return .skip }
        return .notify(share: share)
    }

    /// Una liquidación solo notifica a su receptor real. Excluye al pagador por
    /// construcción (él es `fromMemberID`, no `toMemberID`) y a quien la REGISTRÓ
    /// (`recordedByMemberID`) — eco Caso D: registro "X me pagó" (soy el receptor) y
    /// no debo recibir "X te pagó" por algo que registré yo. nil (legado) ⇒ solo el
    /// filtro por receptor.
    static func shouldNotifySettlement(currentMemberID: String?,
                                       toMemberID: String,
                                       recordedByMemberID: String? = nil) -> Bool {
        guard let me = currentMemberID else { return false }
        if let recorder = recordedByMemberID, recorder == me { return false }
        return toMemberID == me
    }
}
