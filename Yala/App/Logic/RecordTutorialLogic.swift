//
//  RecordTutorialLogic.swift
//  Yala
//
//  Y23-08 a Y23-10 (bienvenida 2.3, docs/onboarding-2-3/SPEC.md): «Aprender a registrar», el paso 2 de Primeros pasos.
//  Cuatro maneras en orden —a mano, voz, foto y Yala IA—, cada una se hace o se omite, y al final la hoja «¿Borramos los
//  de prueba?» con los registros que se apuntaron. Aquí están las reglas, sin efectos; el estado vivo es
//  `RecordTutorialSession` y la pantalla, `RecordTutorialView`.
//

import Foundation
import SwiftData

nonisolated enum RecordTutorialLogic {

    /// Las cuatro maneras de anotar, en el orden de la ficha.
    enum Method: String, CaseIterable, Codable, Equatable {
        case manual
        case voice
        case photo
        case ai

        /// Voz, foto y Yala IA son de Pro: aquí se prueban gratis una vez.
        var isCourtesyTrial: Bool { self != .manual }
    }

    /// Cómo quedó cada manera.
    enum MethodState: String, Codable, Equatable {
        case pending
        case done
        case skipped
    }

    /// La manera que sigue: la primera que falta, en orden. `nil` = ya están todas.
    static func next(_ states: [Method: MethodState]) -> Method? {
        Method.allCases.first { (states[$0] ?? .pending) == .pending }
    }

    /// Qué se enseña en la pantalla entre manera y manera. El título cuenta lo anotado.
    enum BetweenHeadline: Equatable {
        case firstRecord
        case records(Int)
        case keepGoing
    }

    static func betweenHeadline(recordCount: Int) -> BetweenHeadline {
        switch recordCount {
        case 0: return .keepGoing
        case 1: return .firstRecord
        default: return .records(recordCount)
        }
    }

    /// Una manera ya se resolvió: no se vuelve a ofrecer, y su prueba de cortesía no se vuelve a abrir.
    static func resolving(_ method: Method, as state: MethodState, in states: [Method: MethodState]) -> [Method: MethodState] {
        var copy = states
        guard (copy[method] ?? .pending) == .pending else { return copy }
        copy[method] = state
        return copy
    }

    /// «Omitir este paso»: lo que falte queda omitido.
    static func skippingAll(_ states: [Method: MethodState]) -> [Method: MethodState] {
        var copy = states
        for method in Method.allCases where (copy[method] ?? .pending) == .pending { copy[method] = .skipped }
        return copy
    }

    /// La hoja del final pregunta solo si hay algo que borrar.
    static func asksToCleanUp(recordCount: Int) -> Bool { recordCount > 0 }

    /// Los registros que se borran: los marcados. Al abrir la hoja, todos marcados (ficha Y23-10).
    static func initialSelection<ID: Hashable>(_ ids: [ID]) -> Set<ID> { Set(ids) }
}

/// Un registro apuntado durante el tutorial: el que la hoja del final ofrece borrar.
struct RecordTutorialRecord: Identifiable, Codable, Equatable {
    var id: PersistentIdentifier { persistentID }
    let persistentID: PersistentIdentifier
    let method: RecordTutorialLogic.Method
    /// `true` si quedó como borrador en la Bandeja (voz o foto cerradas sin guardar), no como registro.
    let isDraft: Bool
    /// Ids que van con él (una foto con varias líneas).
    let additionalIDs: [PersistentIdentifier]
}

/// El estado vivo del tutorial. Del proceso, como el mazo: hay uno por teléfono. Se guarda en `UserDefaults` para que,
/// si iOS cierra Yala a mitad, se siga donde iba.
@MainActor
@Observable
final class RecordTutorialSession {

    static let shared = RecordTutorialSession()

    private(set) var states: [RecordTutorialLogic.Method: RecordTutorialLogic.MethodState] = [:]
    private(set) var records: [RecordTutorialRecord] = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private static let statesKey = "setup.recordTutorial.states"
    @ObservationIgnored private static let recordsKey = "setup.recordTutorial.records"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var nextMethod: RecordTutorialLogic.Method? { RecordTutorialLogic.next(states) }

    /// Si ya se tocó alguna manera: al volver al tutorial se abre la pantalla de «entre maneras», no la página corta.
    var hasStarted: Bool { states.values.contains { $0 != .pending } }

    func state(of method: RecordTutorialLogic.Method) -> RecordTutorialLogic.MethodState {
        states[method] ?? .pending
    }

    /// Empieza (o retoma) el tutorial: mientras dure, nada da por hecho el paso 2.
    func begin() {
        SetupChecklistManager.shared.beginRecordTutorial()
    }

    /// Se guardó un registro con esa manera.
    func recordSaved(_ method: RecordTutorialLogic.Method, id: PersistentIdentifier, isDraft: Bool = false,
                     additionalIDs: [PersistentIdentifier] = []) {
        if !records.contains(where: { $0.persistentID == id }) {
            records.append(RecordTutorialRecord(
                persistentID: id, method: method, isDraft: isDraft, additionalIDs: additionalIDs))
        }
        states = RecordTutorialLogic.resolving(method, as: .done, in: states)
        save()
    }

    /// Borradores de más que dejó la prueba (una frase con varios gastos, una foto con varias líneas): entran en la hoja
    /// del final sin cambiar el estado de la manera.
    func addExtraDrafts(_ method: RecordTutorialLogic.Method, ids: [PersistentIdentifier]) {
        for id in ids where !records.contains(where: { $0.persistentID == id }) {
            records.append(RecordTutorialRecord(persistentID: id, method: method, isDraft: true, additionalIDs: []))
        }
        save()
    }

    /// La manera se omitió (o se cerró sin apuntar nada).
    func skip(_ method: RecordTutorialLogic.Method) {
        states = RecordTutorialLogic.resolving(method, as: .skipped, in: states)
        save()
    }

    /// «Omitir este paso».
    func skipAll() {
        states = RecordTutorialLogic.skippingAll(states)
        save()
    }

    /// Cierra el tutorial: el paso 2 queda hecho si se apuntó algo, si no, omitido. Lo de la sesión se borra.
    func finish() {
        SetupChecklistManager.shared.finishRecordTutorial(savedAnyRecord: !records.isEmpty)
        states = [:]
        records = []
        defaults.removeObject(forKey: Self.statesKey)
        defaults.removeObject(forKey: Self.recordsKey)
    }

    /// Para «Vaciar datos» y los tests.
    func reset() {
        states = [:]
        records = []
        defaults.removeObject(forKey: Self.statesKey)
        defaults.removeObject(forKey: Self.recordsKey)
    }

    private func save() {
        let raw = Dictionary(uniqueKeysWithValues: states.map { ($0.key.rawValue, $0.value.rawValue) })
        defaults.set(raw, forKey: Self.statesKey)
        do {
            defaults.set(try JSONEncoder().encode(records), forKey: Self.recordsKey)
        } catch {
            #if DEBUG
            print("RecordTutorialSession: Error: saving the tutorial records: \(error)")
            #endif
        }
    }

    private func load() {
        if let raw = defaults.dictionary(forKey: Self.statesKey) as? [String: String] {
            var loaded: [RecordTutorialLogic.Method: RecordTutorialLogic.MethodState] = [:]
            for (key, value) in raw {
                if let method = RecordTutorialLogic.Method(rawValue: key),
                   let state = RecordTutorialLogic.MethodState(rawValue: value) {
                    loaded[method] = state
                }
            }
            states = loaded
        }
        if let data = defaults.data(forKey: Self.recordsKey) {
            do {
                records = try JSONDecoder().decode([RecordTutorialRecord].self, from: data)
            } catch {
                #if DEBUG
                print("RecordTutorialSession: Error: reading the tutorial records: \(error)")
                #endif
                records = []
            }
        }
    }
}
