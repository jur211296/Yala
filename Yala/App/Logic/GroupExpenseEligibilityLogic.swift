//
//  GroupExpenseEligibilityLogic.swift
//  Yala
//
//  Pure-logic helper para decidir si el current user puede crear un gasto en un
//  grupo DESDE EL FAB del tab Grupos (composer "Nuevo gasto", sin entrar al grupo).
//
//  Más estricto que `GroupExpenseService.validateCurrentUserCanWrite` a propósito:
//  exige que el current user sea un miembro `.active` YA PRESENTE (status no-nil).
//  El composer deriva `paidBy`/miembros de la cache; si abriéramos el form para un
//  grupo cuyo SplitMember del current user aún no sincronizó (ventana de cold
//  start/restore — `isOwner` true pero member ausente), el form quedaría imposible
//  de guardar sin explicación. Excluirlo hasta que el member llegue es lo correcto.
//  Pending/rejected/left/removed/ausente → no pueden. Archivado u oculto → tampoco.
//  Extraído para tests pure-logic sin SwiftData/ModelContext (evita flake R8).
//

import Foundation

enum GroupExpenseEligibilityLogic {
    /// `true` si el current user puede abrir un form de gasto USABLE para el grupo.
    ///
    /// - Parameters:
    ///   - currentMemberStatus: status del current user en el grupo (`nil` si aún no es member).
    ///   - isArchived / isHiddenForAll: un grupo archivado u oculto nunca acepta gastos nuevos.
    static func canCreateExpense(
        currentMemberStatus: SplitMemberStatus?,
        isArchived: Bool,
        isHiddenForAll: Bool
    ) -> Bool {
        guard !isArchived, !isHiddenForAll else { return false }
        return currentMemberStatus == .active
    }
}
