//
//  EntityFilter.swift
//  Yala
//
//  Filtro de UNA dimensión (cuentas, categorías, subcategorías, etiquetas, necesidades o monedas) con incluidos y
//  excluidos a la vez. Sustituye al interruptor global «modo excluir», que daba a todos los conjuntos un solo
//  significado y vaciaba los filtros al cambiar (ticket `stats-filter-segment-tap-should-ask-include-or-exclude`,
//  opción B de Jürgen del 2026-10-12).
//

import Foundation

/// Incluidos y excluidos de una dimensión. Es la ÚNICA regla de coincidencia: `FilterService`, la elegibilidad de
/// cuentas del Panel y de Estadísticas y el saldo vivo la llaman, así que dos pantallas no pueden leer el mismo filtro
/// de dos maneras.
nonisolated struct EntityFilter<ID: Hashable & Sendable>: Hashable, Sendable {
    /// «Solo estos». Vacío = sin restricción.
    var included: Set<ID> = []
    /// «Todos menos estos».
    var excluded: Set<ID> = []

    init(included: Set<ID> = [], excluded: Set<ID> = []) {
        self.included = included
        self.excluded = excluded
    }

    /// Hay algo que filtrar en esta dimensión.
    var isActive: Bool { !included.isEmpty || !excluded.isEmpty }

    /// Un valor pasa si está entre los incluidos (cuando los hay) y no está entre los excluidos. Un valor ausente
    /// (`nil`: el movimiento no tiene cuenta, categoría…) no pasa un filtro de incluidos y sí uno de excluidos, como
    /// hacían los dos modos por separado. Si un id estuviera en los dos conjuntos, excluido gana.
    func matches(_ value: ID?) -> Bool {
        if !included.isEmpty {
            guard let value, included.contains(value) else { return false }
        }
        if let value, excluded.contains(value) { return false }
        return true
    }

    /// Para valores múltiples (las etiquetas de un movimiento): pasa si comparte alguno con los incluidos (cuando los
    /// hay) y ninguno con los excluidos.
    func matchesAny(_ values: Set<ID>) -> Bool {
        if !included.isEmpty, values.isDisjoint(with: included) { return false }
        if !excluded.isEmpty, !values.isDisjoint(with: excluded) { return false }
        return true
    }
}

/// Cómo está un valor en el filtro de su dimensión. Lo leen el diálogo del toque y la marca de las gráficas.
nonisolated enum EntityFilterMembership: Equatable, Sendable {
    case none
    case included
    case excluded
}

nonisolated extension EntityFilter {
    func membership(of value: ID) -> EntityFilterMembership {
        if excluded.contains(value) { return .excluded }
        if included.contains(value) { return .included }
        return .none
    }
}
