//
//  GroupsSaveSyncTrigger.swift
//  Yala
//
//  Tras guardar un gasto de grupo, pide tiempo de fondo (`beginBackgroundTask`) y, pasado
//  `SyncCadencePolicy.pushDebounce`, dispara UN ciclo del canal. Cubre el caso dominante: el emisor
//  bloquea el teléfono ~30s después de guardar; el loop de 60s se suspende y el silent push despierta
//  al receptor, no a quien acaba de escribir.
//
//  No afirma que iOS concedió ese tiempo: el handle puede ser `.invalid` y el expiration handler
//  solo corta el debounce. Un ciclo que no llega a pedirse no escala el backoff del loop.
//

import Foundation
import UIKit

/// Handle del `beginBackgroundTask` de iOS. El valor no implica que el sistema haya concedido
/// segundos extra — `.invalid` es una respuesta válida.
struct GroupsBackgroundTaskID: Equatable, Sendable {
    let rawValue: UInt
    static let invalid = GroupsBackgroundTaskID(rawValue: UIBackgroundTaskIdentifier.invalid.rawValue)
}

@MainActor
final class GroupsSaveSyncTrigger {

    static let shared = GroupsSaveSyncTrigger()

    typealias Begin = (_ name: String, _ expiration: @escaping () -> Void) -> GroupsBackgroundTaskID
    typealias End = (GroupsBackgroundTaskID) -> Void

    var beginBackgroundTask: Begin
    var endBackgroundTask: End
    var sleeper: (TimeInterval) async -> Void
    var runCycle: () async -> Void

    private var debounceTask: Task<Void, Never>?
    /// Conserva la última task para que los tests puedan await-earla tras un `cancel()`.
    private var inFlight: Task<Void, Never>?
    private var backgroundTask = GroupsBackgroundTaskID.invalid

    init(
        beginBackgroundTask: @escaping Begin = { name, expiration in
            let id = UIApplication.shared.beginBackgroundTask(withName: name, expirationHandler: expiration)
            return GroupsBackgroundTaskID(rawValue: id.rawValue)
        },
        endBackgroundTask: @escaping End = { handle in
            guard handle != .invalid else { return }
            UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: handle.rawValue))
        },
        sleeper: @escaping (TimeInterval) async -> Void = { seconds in
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                // CancellationError: el caller comprueba Task.isCancelled.
            }
        },
        runCycle: @escaping () async -> Void = {
            await GroupsSyncClient.shared.syncNowAfterLocalSave()
        }
    ) {
        self.beginBackgroundTask = beginBackgroundTask
        self.endBackgroundTask = endBackgroundTask
        self.sleeper = sleeper
        self.runCycle = runCycle
    }

    /// Pide el background task YA (antes de que el usuario salga) y encola UN ciclo tras el debounce.
    /// No bloquea al caller. Varias llamadas en ráfaga reutilizan el mismo task y reinician el debounce.
    func requestAfterLocalSave() {
        if backgroundTask == .invalid {
            backgroundTask = beginBackgroundTask("yala.groups.save-sync") { [weak self] in
                // UIKit entrega el expiration en el main thread; cancel() es @MainActor.
                MainActor.assumeIsolated {
                    self?.cancel()
                }
            }
        }

        debounceTask?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.sleeper(SyncCadencePolicy.pushDebounce)
            guard !Task.isCancelled else { return }
            await self.runCycle()
            guard !Task.isCancelled else { return }
            self.finishBackgroundTask()
        }
        debounceTask = task
        inFlight = task
    }

    /// Corta el debounce en vuelo y suelta el background task. Lo llama el expiration handler y
    /// `GroupsSyncClient.teardownForSignOut` para no ciclar sobre un store a punto de purgarse.
    func cancel() {
        debounceTask?.cancel()
        debounceTask = nil
        finishBackgroundTask()
    }

    /// Espera a que el debounce/ciclo en vuelo termine. SOLO tests.
    func _testAwaitInFlight() async {
        await inFlight?.value
    }

    private func finishBackgroundTask() {
        let id = backgroundTask
        backgroundTask = .invalid
        if id != .invalid {
            endBackgroundTask(id)
        }
    }
}
