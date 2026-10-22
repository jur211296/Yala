//
//  GroupScheduledPaymentGate.swift
//  Yala
//
//  Decisión pure-logic de qué hacer con un pago planificado de grupo cuando vence.
//  Separa "aún no sincronizado" (race de CloudKit → reintentar next launch, NO pausar)
//  de "inválido" (grupo archivado/oculto o ya no soy miembro activo → pausar el pago).
//  Sin SwiftData ni UI → testeable sin contexto.
//

import Foundation

enum GroupScheduledPaymentGate {

    enum Decision: Equatable {
        /// Grupo válido y sigo siendo miembro activo → materializar el draft.
        case proceed
        /// Grupo o membresía aún no sincronizados (posible race de import) → no pausar,
        /// reintentar en el próximo arranque.
        case retryLater
        /// Grupo archivado/oculto o ya no soy miembro activo → desactivar el pago.
        case pause
    }

    static func decide(
        groupExists: Bool,
        isArchived: Bool,
        isHidden: Bool,
        memberExists: Bool,
        memberIsActive: Bool
    ) -> Decision {
        // Grupo no cargado aún: no distinguible de "sync pendiente" → reintentar (nunca pausar).
        guard groupExists else { return .retryLater }
        // Grupo presente pero fuera de juego: pausar el pago (no generar drafts huérfanos).
        if isArchived || isHidden { return .pause }
        // Miembro propio no cargado aún → sync pendiente → reintentar.
        guard memberExists else { return .retryLater }
        // Miembro presente: activo procede; removido/salido pausa.
        return memberIsActive ? .proceed : .pause
    }
}
