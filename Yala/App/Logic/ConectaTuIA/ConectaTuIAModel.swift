//
//  ConectaTuIAModel.swift
//  Yala
//
//  El estado de «Tus IA conectadas»: cargar la lista y quitar una. Lo quitado se aparta de la lista al momento y se
//  sigue apartando aunque una recarga lo traiga: el listado del conector puede ir hasta un minuto atrasado
//  (`mcp/src/connections.ts`, medido en staging el 23-nov).
//

import Foundation
import Observation

@MainActor
@Observable
final class ConectaTuIAModel {
    enum Phase: Equatable {
        case loading
        case loaded([AIConnection])
        case failed
    }

    private(set) var phase: Phase = .loading
    /// El id que se está quitando. Mientras no es `nil`, los botones de quitar están apagados.
    private(set) var disconnecting: String?
    /// El último «Desconectar» falló: la pantalla lo dice encima de la lista.
    private(set) var disconnectFailed = false
    private var removed: Set<String> = []

    private let client: ConectaTuIAClient

    init(client: ConectaTuIAClient) {
        self.client = client
    }

    var connections: [AIConnection] {
        if case .loaded(let list) = phase { return list }
        return []
    }

    func load() async {
        if case .loaded = phase {} else { phase = .loading }
        do {
            let list = try await client.connections()
            phase = .loaded(list.filter { !removed.contains($0.id) })
        } catch {
            #if DEBUG
            print("ConectaTuIAModel: Error: \(error)")
            #endif
            if case .loaded = phase {} else { phase = .failed }
        }
    }

    func disconnect(_ connection: AIConnection) async {
        guard disconnecting == nil else { return }
        disconnecting = connection.id
        disconnectFailed = false
        defer { disconnecting = nil }
        do {
            try await client.disconnect(id: connection.id)
        } catch ConectaTuIAClientError.notFound {
            // Ya no estaba (la quitó la propia IA, o caducó): para la persona, quitada igual.
        } catch {
            #if DEBUG
            print("ConectaTuIAModel: Error: \(error)")
            #endif
            disconnectFailed = true
            DS.Haptic.error()
            return
        }
        removed.insert(connection.id)
        phase = .loaded(connections.filter { $0.id != connection.id })
        DS.Haptic.success()
    }
}
