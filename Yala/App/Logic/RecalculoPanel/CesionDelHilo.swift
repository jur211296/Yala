//
//  CesionDelHilo.swift
//  Yala
//
//  Lote 4 de eficiencia (26-nov-2026). Ceder el hilo principal DENTRO de una etapa del cálculo del Panel.
//
//  El lote 3 partió el cálculo en cinco etapas que ceden entre una y otra, pero cada etapa seguía siendo de una vez: con
//  16.004 movimientos en el iPhone 14, la de la tendencia y la de la nota de salud pasaban del segundo. Esta pieza mide
//  cuánto lleva el tramo en curso y, si pasó de `limite`, cede un milisegundo (para que el run loop atienda toques y el
//  paso a segundo plano, como `PanelViewModel.fetchTransactionsInSlices`) y pregunta si sigue. Si no sigue —se canceló,
//  la app se fue, cambió el almacén— lanza `CancellationError` y quien la usa abandona sin publicar lo que iba calculando.
//
//  Mirar el reloj cuesta poco, pero no es gratis: los recorridos largos lo miran cada `cadaCuantos` elementos.
//

import Foundation

@MainActor
final class CesionDelHilo {

    /// Lo que puede durar un tramo antes de ceder. Por debajo de los 50 ms del encargo, con margen para la pieza que no
    /// se puede partir (una calculadora compartida) que caiga justo al final de un tramo.
    nonisolated static let limitePorDefecto: Duration = .milliseconds(25)

    /// Cada cuántos elementos mira el reloj un recorrido largo.
    nonisolated static let cadaCuantos = 256

    private let reloj = ContinuousClock()
    private let limite: Duration
    private let sigue: @MainActor () -> Bool
    private var inicioTramo: ContinuousClock.Instant

    /// El tramo más largo sin ceder (el último incluido, al llamar a `cerrar()`).
    private(set) var tramoMasLargo: Duration = .zero
    /// Cuántas veces cedió.
    private(set) var cesiones = 0

    init(limite: Duration = CesionDelHilo.limitePorDefecto, sigue: @escaping @MainActor () -> Bool) {
        self.limite = limite
        self.sigue = sigue
        self.inicioTramo = reloj.now
    }

    /// Cede si el tramo en curso pasó del límite. Lanza `CancellationError` si, al volver, el cálculo no sigue.
    func cederSiToca() async throws {
        guard reloj.now - inicioTramo >= limite else { return }
        try await ceder()
    }

    /// Cede siempre (el final de una etapa). Lanza `CancellationError` si, al volver, el cálculo no sigue.
    func ceder() async throws {
        tramoMasLargo = max(tramoMasLargo, reloj.now - inicioTramo)
        cesiones += 1
        // Un milisegundo y no `Task.yield()`: el `yield` solo deja pasar a otras tareas del hilo principal, y lo que hace
        // falta es que el run loop atienda los toques y el paso a segundo plano. Cancelada, la espera lanza.
        try await Task.sleep(for: .milliseconds(1))
        guard !Task.isCancelled, sigue() else { throw CancellationError() }
        inicioTramo = reloj.now
    }

    /// Apunta el último tramo, el que acaba sin ceder.
    func cerrar() {
        tramoMasLargo = max(tramoMasLargo, reloj.now - inicioTramo)
    }

    /// Pasa `elementos` a `procesa` en trozos de `tamano` y junta lo que devuelve, cediendo entre trozo y trozo si toca.
    /// Para un filtro elemento a elemento (`{ $0.filter(…) }`) el resultado es el mismo y en el mismo orden que procesar
    /// el arreglo entero, y la regla del filtro sigue viviendo en un solo sitio.
    func porTrozos<T, U>(_ elementos: [T], tamano: Int = 1_024, _ procesa: ([T]) -> [U]) async throws -> [U] {
        guard elementos.count > tamano else { return procesa(elementos) }
        var resultado: [U] = []
        var desde = 0
        while desde < elementos.count {
            let hasta = min(desde + tamano, elementos.count)
            resultado.append(contentsOf: procesa(Array(elementos[desde..<hasta])))
            desde = hasta
            try await cederSiToca()
        }
        return resultado
    }

    /// `filter` que cede por el camino. Devuelve los mismos elementos y en el mismo orden que `elementos.filter(incluye)`.
    func filtrar<T>(_ elementos: [T], _ incluye: (T) -> Bool) async throws -> [T] {
        var resultado: [T] = []
        resultado.reserveCapacity(elementos.count)
        var desdeElReloj = 0
        for elemento in elementos {
            if incluye(elemento) { resultado.append(elemento) }
            desdeElReloj += 1
            if desdeElReloj >= Self.cadaCuantos {
                desdeElReloj = 0
                try await cederSiToca()
            }
        }
        return resultado
    }

    /// `map` que cede por el camino. Mismo resultado y orden que `elementos.map(transforma)`.
    func transformar<T, U>(_ elementos: [T], _ transforma: (T) -> U) async throws -> [U] {
        var resultado: [U] = []
        resultado.reserveCapacity(elementos.count)
        var desdeElReloj = 0
        for elemento in elementos {
            resultado.append(transforma(elemento))
            desdeElReloj += 1
            if desdeElReloj >= Self.cadaCuantos {
                desdeElReloj = 0
                try await cederSiToca()
            }
        }
        return resultado
    }
}
