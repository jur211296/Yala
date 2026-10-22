//
//  GroupOwnerExitLogic.swift
//  Yala
//
//  Lógica PURA (nonisolated, sin efectos) de QUÉ SALIDA se le ofrece al dueño en Ajustes del grupo.
//
//  POR QUÉ EXISTE. El dueño de un grupo CON DEUDA se quedaba sin salida: «Salir» no se le muestra
//  (es el dueño) y «Eliminar» está deshabilitado mientras haya saldos — y el saldo que lo bloquea
//  puede ser **entre terceros**, así que el hint le pedía liquidar deudas que no son suyas. Decisión
//  del owner (2026-09-06, ticket `groups-owner-transfer-and-leave`): ofrecerle **«Transferir y
//  salir»**. «Eliminar» sigue bloqueado con deuda — no se borra el grupo con saldos vivos.
//
//  SEGUNDA DECISIÓN (2026-09-08, ticket `groups-owner-debt-no-heir-dead-end`). Lo anterior cubre al
//  dueño CON heredero y deja fuera al que no lo tiene: con deuda y sin nadie a quien ceder el grupo,
//  las tres salidas quedaban cerradas. Ahora el hint le nombra **«Archivar grupo»**, que ya existía
//  en esta misma pantalla y ya funciona con deuda. No es una salida nueva: es dejar de esconderla.
//  «Eliminar» sigue bloqueado, y sigue sin borrarse ninguna deuda de nadie.
//
//  POR QUÉ NO SE REUSA `GroupBatchLeaveLogic.classify`. Su primera línea es
//  `if facts.hasOutstandingDebt { return .skipHasDebt }`, correcta para el batch «salir de todos mis
//  grupos» (que solo se OFRECE con cero deudas globales) y exactamente lo contrario de lo que se
//  decidió aquí: en Ajustes, la deuda es la razón POR LA QUE hay que ofrecer la transferencia. Las
//  dos superficies responden preguntas distintas sobre los mismos facts.
//
//  Molde: `GroupLeaveErrorLogic` / `GroupBackendAcceptErrorLogic` — este tipo NO devuelve copy, solo
//  la decisión; el string lo elige la vista. Sin SwiftData ni UI; tabla completa en
//  `GroupOwnerExitLogicTests`.
//

import Foundation

nonisolated enum GroupOwnerExitLogic {

    /// Facts del grupo, derivados EN MEMORIA por `GroupService` (nunca `#Predicate` sobre opcionales —
    /// `SplitMember.userID` es opcional y un predicado sobre él crashea el SQL de SwiftData).
    struct Facts: Equatable {
        /// `SplitGroup.isOwner`. Device-local, pero ya reconciliado contra el servidor cuando este
        /// rechaza una salida con `yala_owner_cannot_leave` (`GroupService.reconcileServerSideOwnership`).
        let isOwner: Bool
        /// `routesMembershipToBackend(group)`. La transferencia SOLO existe en el canal backend:
        /// CloudKit no sabe ceder el ownership de un CKShare.
        let isBackendChannel: Bool
        /// Co-members `.isActive && !isCurrentUser`.
        let activeCoMemberCount: Int
        /// Herederos elegibles: co-members activos con `userID != nil`. Replica la elegibilidad de
        /// `transfer_group_ownership` (`user_id is not null` — los placeholders de un grupo legacy
        /// migrado y no reclamado NUNCA son herederos: no hay auth.user al que ceder).
        let eligibleHeirCount: Int
        /// `abs(netBalance) > 0.01` de CUALQUIER miembro — la deuda de TODO el grupo, que es la que
        /// bloquea «Eliminar» (molde `GroupSettingsView.recomputeOutstandingDebt`). NO es la deuda
        /// del usuario: el dueño puede estar a cero y quedar bloqueado por un saldo entre otros dos.
        let groupHasOutstandingDebt: Bool
        /// El servidor ya rechazó la transferencia con `no_eligible_owner` en esta sesión.
        ///
        /// Existe porque los conteos de arriba salen de las filas LOCALES, y un rechazo del servidor
        /// no las cambia: sin esto, la pantalla vuelve a ofrecer la transferencia y a nombrar al mismo
        /// heredero fantasma, el usuario confirma, y el mismo error otra vez — indefinidamente, con
        /// «Eliminar» en gris. El servidor sabe más que el cache; se le hace caso hasta que llegue
        /// dato nuevo (la vista lo baja con el siguiente `dataVersion`).
        let serverRefusedTransfer: Bool
        /// `SplitGroup.isArchived`. Decide si tiene sentido ofrecerle «Archivar» como salida: a un
        /// grupo que YA está archivado no se le puede proponer archivarlo.
        let isArchived: Bool
    }

    /// Qué se pinta en la zona de acciones de Ajustes.
    struct Offer: Equatable {
        /// «Salir del grupo» — solo para quien no es el dueño (el servidor lo rechazaría con
        /// `yala_owner_cannot_leave`).
        let showsLeave: Bool
        /// «Transferir y salir» — la salida nueva del dueño.
        let showsTransferAndLeave: Bool
        /// «Eliminar grupo» — owner-only, como hasta ahora.
        let showsDelete: Bool
        /// `false` con deuda en el grupo. NO cambia con esta decisión.
        let deleteEnabled: Bool
        /// Qué explica el bloqueo de «Eliminar». `nil` cuando no está bloqueado.
        let deleteHint: DeleteHint?
    }

    /// El copy del bloqueo depende de si hay una salida que ofrecer, y por eso son dos casos y no uno:
    /// mandar a transferir a quien no tiene heredero sería mandarlo a un botón que no existe.
    enum DeleteHint: Equatable {
        /// Hay saldos y SÍ hay a quién cederle el grupo ⇒ el hint apunta a «Transferir y salir».
        case debtTransferInstead
        /// Hay saldos y la transferencia NO está disponible. Las causas son varias y NO se distinguen
        /// a propósito, porque al usuario le cambian lo mismo (nada): único miembro activo, canal
        /// CloudKit —que no sabe ceder ownership—, co-members sin cuenta, o un rechazo del servidor.
        /// Se constata el hecho sin pedirle liquidar deudas ajenas: no puede, y no son suyas.
        ///
        /// El nombre dice «sin transferencia» y no «sin heredero» por precisión: en el caso CloudKit
        /// hay herederos de sobra y lo que falta es el canal.
        case debtNoTransferAvailable
        /// Hay saldos, la transferencia NO está disponible y el grupo **no está archivado todavía**
        /// ⇒ el hint apunta a «Archivar grupo».
        ///
        /// Decisión de Jürgen (2026-09-08), ticket `groups-owner-debt-no-heir-dead-end`. El dueño sin
        /// heredero tenía las tres salidas cerradas y el hint se lo decía con honestidad, pero
        /// **callándose la que sí tenía delante**: «Archivar» ya existe, ya funciona con deuda —solo
        /// pide su confirmación— y vive dos secciones más arriba en esta misma pantalla. Esto no
        /// añade una salida: deja de esconderla.
        ///
        /// No le saca del grupo —sigue siendo dueño y contando para los saldos—, así que **no toca el
        /// principio que la decisión del 6-sep protegió**: nadie pierde una deuda viva. Es «quítamelo
        /// de la vista», no «sácame de aquí».
        ///
        /// **Va el ÚLTIMO del enum a propósito.** Un case nuevo en medio renumera los demás, y esos
        /// números se usan para diagnosticar desde fuera.
        case debtArchiveInstead
    }

    // MARK: - Qué se ofrece

    static func offer(_ facts: Facts) -> Offer {
        guard facts.isOwner else {
            // No es el dueño: la única salida es salir, y «Eliminar» nunca fue suyo.
            return Offer(showsLeave: true, showsTransferAndLeave: false, showsDelete: false,
                         deleteEnabled: false, deleteHint: nil)
        }
        // Dueño. `activeCoMemberCount >= 1` va explícito y no se da por implicado en
        // `eligibleHeirCount >= 1`: son dos conteos distintos y el segundo es un subconjunto del
        // primero, pero los calcula el caller y un desajuste ahí no debe convertirse en ofrecer una
        // transferencia sin nadie a quien transferir.
        let canTransfer = !facts.serverRefusedTransfer
            && facts.isBackendChannel
            && facts.activeCoMemberCount >= 1
            && facts.eligibleHeirCount >= 1
        // Prioridad: transferir (sale de verdad) > archivar (se lo quita de la vista) > constatar el
        // hecho. Archivar solo se ofrece si queda algo que archivar.
        let hint: DeleteHint?
        if !facts.groupHasOutstandingDebt {
            hint = nil
        } else if canTransfer {
            hint = .debtTransferInstead
        } else if !facts.isArchived {
            hint = .debtArchiveInstead
        } else {
            hint = .debtNoTransferAvailable
        }
        return Offer(showsLeave: false,
                     showsTransferAndLeave: canTransfer,
                     showsDelete: true,
                     deleteEnabled: !facts.groupHasOutstandingDebt,
                     deleteHint: hint)
    }

    // MARK: - Quién hereda

    /// Candidato a heredero, ya filtrado por el caller (activo, `userID != nil`, distinto de mí).
    struct HeirCandidate: Equatable {
        let memberKey: String
        let displayName: String
        let isAdmin: Bool
        let joinedAt: Date
    }

    /// El heredero que elegirá el SERVIDOR, replicado aquí para poder decir su nombre antes de
    /// confirmar.
    ///
    /// ⚠️ Esto es un ESPEJO, no la decisión. `transfer_group_ownership(p_group_id text)` —medido
    /// contra producción el 2026-09-06, `pg_get_functiondef` md5 `dd3a049c793f6fe2479552ac0c7fba3f`,
    /// idéntico al del DDL del árbol— **no acepta heredero**: lo elige él con
    /// `order by (coalesce(role,'') = 'admin') desc, joined_at asc, member_key asc limit 1`. Se
    /// replica VERBATIM para que la hoja no prometa un nombre distinto del que acabará mandando.
    /// Si alguna vez el RPC pasa a aceptar un heredero, esta función deja de ser un espejo y hay que
    /// borrarla, no ajustarla.
    ///
    /// El desempate por `memberKey` importa: sin él, dos miembros con el mismo `joinedAt` (import de
    /// una migración, que sella la misma fecha en el lote) saldrían en orden indefinido y la app
    /// nombraría a uno mientras el servidor corona al otro.
    static func designatedHeir(from candidates: [HeirCandidate]) -> HeirCandidate? {
        candidates.min { lhs, rhs in
            if lhs.isAdmin != rhs.isAdmin { return lhs.isAdmin }        // admin primero
            if lhs.joinedAt != rhs.joinedAt { return lhs.joinedAt < rhs.joinedAt }  // más antiguo
            return lhs.memberKey < rhs.memberKey                        // desempate estable
        }
    }
}
