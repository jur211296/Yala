//
//  OpeningBalanceSectionLogic.swift
//  Yala
//
//  Card jqgy · qué enseña la sección «Saldos iniciales» de Miembros. Sin SwiftData: testeable en aislamiento.
//

import Foundation

nonisolated enum OpeningBalanceSectionLogic {

    enum Mode: Equatable, Sendable {
        /// Quien no gestiona los saldos iniciales no ve la sección.
        case hidden
        /// Se ven, se añaden y se editan.
        case editable
        /// Grupo congelado (se movió a la nube de Yala): se ven, sin «Añadir» ni editor, con la explicación.
        /// Ocultarlos escondería datos que el resto del grupo congelado sí enseña en solo lectura.
        case frozenReadOnly

        var allowsChanges: Bool { self == .editable }
    }

    /// `isManager`: `OpeningBalancePermissionLogic.canManage` (dueño, o admin activo). `isFrozen`: `isMigratedFrozen`,
    /// la misma fuente que bloquea las escrituras en `GroupExpenseService.validateGroupIsWritable`.
    static func mode(isManager: Bool, isFrozen: Bool) -> Mode {
        guard isManager else { return .hidden }
        return isFrozen ? .frozenReadOnly : .editable
    }
}
