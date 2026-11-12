//
//  SetupDeckLogic.swift
//  Yala
//
//  Y23-05 (bienvenida 2.3, docs/onboarding-2-3/SPEC.md): «Primeros pasos» se ve como un MAZO. Adelante, el paso
//  actual («Primeros pasos · N de 7» y su nombre); asomando detrás, los dos siguientes que faltan («Después: …»,
//  «Luego: …»). El mazo avanza al completar u omitir el de adelante y desaparece al resolver el séptimo.
//

import Foundation

nonisolated enum SetupDeckLogic {

    struct Deck: Equatable {
        /// El paso de adelante.
        let current: SetupStepID
        /// Su lugar en el orden de la ficha (1…7): «Primeros pasos · N de 7».
        let position: Int
        /// Cuántos pasos tiene el mazo.
        let total: Int
        /// Los que asoman detrás: como mucho dos, los siguientes en orden que aún faltan.
        let upcoming: [SetupStepID]
    }

    /// Cuántos pasos asoman detrás del de adelante.
    static let peekingCount = 2

    /// El mazo para un orden y lo ya resuelto (hecho u omitido). `nil` cuando no queda ninguno por resolver.
    static func deck(order: [SetupStepID], isResolved: (SetupStepID) -> Bool) -> Deck? {
        guard let index = order.firstIndex(where: { !isResolved($0) }) else { return nil }
        let upcoming = order[(index + 1)...].filter { !isResolved($0) }.prefix(peekingCount)
        return Deck(current: order[index], position: index + 1, total: order.count, upcoming: Array(upcoming))
    }
}
