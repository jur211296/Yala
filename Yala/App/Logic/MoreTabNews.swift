//
//  MoreTabNews.swift
//  Yala
//
//  Y23-10: al terminar «Aprender a registrar», la pestaña Más lleva un punto de «algo nuevo» (ahí viven las gráficas de
//  lo que se acaba de anotar). Se apaga la primera vez que se abre Más. Del teléfono, guardado en `UserDefaults`.
//

import Foundation
import Observation

@MainActor
@Observable
final class MoreTabNews {

    static let shared = MoreTabNews()

    /// El punto está encendido.
    private(set) var isPending: Bool

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored static let storageKey = "setup.moreTabNews.pending"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isPending = defaults.bool(forKey: Self.storageKey)
    }

    /// Enciende el punto.
    func markPending() {
        guard !isPending else { return }
        isPending = true
        defaults.set(true, forKey: Self.storageKey)
    }

    /// Se abrió Más: el punto se apaga.
    func clear() {
        guard isPending else { return }
        isPending = false
        defaults.removeObject(forKey: Self.storageKey)
    }
}
