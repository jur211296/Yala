//
//  RecalculationDebouncer.swift
//  Yala
//
//  El freno de 150 ms que comparten las pantallas de Grupos ante los cambios remotos.
//
//  Una ráfaga de `dataVersion` (un pull que aplica varias páginas, dos gastos seguidos de otro
//  miembro) se junta en UN solo recálculo: cada petición cancela la tarea anterior y vuelve a
//  esperar. Las acciones del propio usuario no pasan por aquí — siguen llamando a `loadData()`
//  directo, porque esperan respuesta en el acto.
//
//  Vivía duplicado letra a letra en `GroupsViewModel` y `GroupDetailViewModel`. Se sacó a un tipo
//  para darle una costura: la espera y el «¿está la app activa?» se inyectan, y así el coalescing
//  se prueba de forma determinista sin depender de `UIApplication.shared.applicationState` del
//  host de test.
//

import Foundation
import UIKit

@MainActor
final class RecalculationDebouncer {

    /// La espera entre la última petición y el recálculo. Tiene que lanzar si la tarea se cancela;
    /// si no lo hace, el `guard !Task.isCancelled` de después sigue impidiendo que publique.
    typealias Sleep = @Sendable (Duration) async throws -> Void

    /// Nombre de quien lo usa, solo para la traza de DEBUG.
    private let label: String
    private let delay: Duration
    private let sleep: Sleep
    private let isApplicationActive: @MainActor () -> Bool

    private var task: Task<Void, Never>?
    /// Un reload pedido dentro de la ventana no se pierde aunque la última petición sea solo de cálculo.
    private var pendingReload = false
    /// Suprime el recálculo en segundo plano (trabajo inútil y traps de snapshot).
    private(set) var isInBackground = false

    #if DEBUG
    /// Peticiones que entraron en la ventana actual. Solo para la traza: el guion de device-QA de dos
    /// aparatos (`tickets/qa/groups-tab-missing-panel-perf.md`) cuenta con ella cuántos cambios remotos
    /// se juntaron en cada recálculo, que en pantalla no se ve.
    private var requestsInWindow = 0
    #endif

    init(
        label: String = "",
        delay: Duration = .milliseconds(150),
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) },
        isApplicationActive: (@MainActor () -> Bool)? = nil
    ) {
        self.label = label
        self.delay = delay
        self.sleep = sleep
        // El valor real se resuelve aquí dentro y no como argumento por defecto: en Swift 5 el default se
        // evalúa fuera del MainActor, y `UIApplication.shared` no se puede leer ahí.
        self.isApplicationActive = isApplicationActive ?? { UIApplication.shared.applicationState == .active }
    }

    /// Programa un recálculo y cancela el que estuviera esperando. `perform` recibe si hay que volver
    /// a leer del disco (`true` si ALGUNA petición de la ventana lo pidió) y corre como mucho una vez
    /// por ventana.
    func schedule(reload: Bool, perform: @escaping (_ reload: Bool) -> Void) {
        guard !isInBackground else { return }
        guard isApplicationActive() else { return }
        if reload { pendingReload = true }
        #if DEBUG
        requestsInWindow += 1
        #endif
        task?.cancel()
        task = Task { [sleep, delay] in
            do { try await sleep(delay) } catch { return }
            // Entre este guard y `perform` no hay ningún `await`: una tarea vieja que ya pasó la
            // espera no puede publicar después de que otra la haya sustituido.
            guard !Task.isCancelled else { return }
            let shouldReload = pendingReload
            pendingReload = false
            #if DEBUG
            print("RecalculationDebouncer[\(label)]: un recálculo para \(requestsInWindow) peticiones (reload: \(shouldReload))")
            requestsInWindow = 0
            #endif
            perform(shouldReload)
        }
    }

    /// Cancela el recálculo que esté esperando (lo llaman los `.onDisappear`).
    func cancel() {
        task?.cancel()
    }

    /// Al pasar a segundo plano se cancela lo pendiente y se olvida el reload pedido: la vuelta a
    /// primer plano programa uno nuevo.
    func setBackground(_ value: Bool) {
        isInBackground = value
        if value {
            task?.cancel()
            task = nil
            pendingReload = false
            #if DEBUG
            requestsInWindow = 0
            #endif
        }
    }
}
