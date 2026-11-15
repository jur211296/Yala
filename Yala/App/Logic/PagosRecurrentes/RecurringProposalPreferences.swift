//
//  RecurringProposalPreferences.swift
//  Yala
//
//  Lo que la persona contestó a las propuestas de pagos que se repiten (lote S1). Vive en ESTE dispositivo (decisión
//  S3: «en cada iPhone», sin esquema nuevo): en el iPad lo descartado puede volver a salir, y es lo aceptado.
//
//  - Interruptor «Proponer pagos que se repiten» (encendido por defecto).
//  - «No es fijo»: descartado hasta que se pida «Volver a proponer».
//  - «Ahora no»: oculto hasta que llegue un cobro más nuevo de ese comercio.
//
//  Es un hecho del dispositivo, no de la persona: no va por el canal de preferencias sincronizadas.
//

import Foundation
import Observation

@MainActor
@Observable
final class RecurringProposalPreferences {

    static let shared = RecurringProposalPreferences()

    enum Keys {
        static let isEnabled = "recurringProposals.isEnabled"
        static let dismissed = "recurringProposals.dismissed"
        static let snoozed = "recurringProposals.snoozed"
    }

    /// Un comercio marcado «No es fijo».
    struct DismissedEntry: Codable, Equatable, Identifiable {
        let key: String
        let name: String
        let dismissedAt: Date
        var id: String { key }
    }

    private let defaults: UserDefaults

    private(set) var isEnabled: Bool
    private(set) var dismissed: [DismissedEntry]
    /// Clave del comercio → fecha del último cobro que había al tocar «Ahora no».
    private(set) var snoozed: [String: Date]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        dismissed = Self.decode([DismissedEntry].self, from: defaults.data(forKey: Keys.dismissed)) ?? []
        snoozed = Self.decode([String: Date].self, from: defaults.data(forKey: Keys.snoozed)) ?? [:]
    }

    // MARK: - Lectura

    /// Lo que se enseña: la función encendida, sin lo descartado y sin lo pospuesto que no tenga un cobro nuevo.
    func visible(_ proposals: [RecurringPaymentDetector.Proposal]) -> [RecurringPaymentDetector.Proposal] {
        guard isEnabled else { return [] }
        let dismissedKeys = Set(dismissed.map(\.key))
        return proposals.filter { proposal in
            guard !dismissedKeys.contains(proposal.key) else { return false }
            if let snoozedAt = snoozed[proposal.key], proposal.lastChargeDate <= snoozedAt { return false }
            return true
        }
    }

    /// Hay algo que gestionar fuera de la tarjeta: la función apagada o algún descartado.
    var hasSomethingToManage: Bool { !isEnabled || !dismissed.isEmpty }

    // MARK: - Escritura

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Keys.isEnabled)
    }

    func dismiss(_ proposal: RecurringPaymentDetector.Proposal, now: Date = .now) {
        dismissed.removeAll { $0.key == proposal.key }
        dismissed.insert(DismissedEntry(key: proposal.key, name: proposal.displayName, dismissedAt: now), at: 0)
        snoozed[proposal.key] = nil
        persist()
    }

    func snooze(_ proposal: RecurringPaymentDetector.Proposal) {
        snoozed[proposal.key] = proposal.lastChargeDate
        persist()
    }

    func restore(_ entry: DismissedEntry) {
        dismissed.removeAll { $0.key == entry.key }
        persist()
    }

    /// Al crear el pago planificado ya no hace falta recordar nada de ese comercio.
    func forget(_ proposal: RecurringPaymentDetector.Proposal) {
        dismissed.removeAll { $0.key == proposal.key }
        snoozed[proposal.key] = nil
        persist()
    }

    // MARK: - Disco

    private func persist() {
        Self.encode(dismissed).map { defaults.set($0, forKey: Keys.dismissed) }
        Self.encode(snoozed).map { defaults.set($0, forKey: Keys.snoozed) }
    }

    private static func encode<T: Encodable>(_ value: T) -> Data? {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            #if DEBUG
            print("RecurringProposalPreferences: Error: \(error)")
            #endif
            return nil
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            #if DEBUG
            print("RecurringProposalPreferences: Error: \(error)")
            #endif
            return nil
        }
    }
}
