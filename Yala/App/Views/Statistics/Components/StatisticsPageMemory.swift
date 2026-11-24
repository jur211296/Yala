//
//  StatisticsPageMemory.swift
//  Yala
//
//  Encargo de fluidez de Estadísticas (24-nov-2026). Cambiar de chip desmonta la página que se va (`StagedTabPages`:
//  el título grande vive en el scroll de la página y con dos montadas no pasa a la nueva). Al volver, la página nacía
//  sin nada y recalculaba desde cero lo que ya había calculado con los mismos datos y los mismos filtros. Medido en el
//  simulador con diez años («Todo el tiempo», Debug): el 70 % del hilo principal ocupado al alternar los chips eran
//  esos recálculos (las tarjetas de Tendencias ~240 ms por entrada, el Sankey de Distribución ~175 ms y «Tu dinero hoy»
//  ~27 ms por hero). En el iPhone 14 las tarjetas de Tendencias tardaban 1,4 s (G1 de la decisión 28): el primer scroll
//  tras cambiar de chip se quedaba trabado ese rato.
//
//  La página guarda lo último que calculó junto a la firma de lo que leyó, en algo que sobrevive al desmontaje (el
//  `StatisticsViewModel` del contenedor). Al volver con la misma firma enseña lo guardado sin calcular; con otra,
//  calcula como siempre. La firma es la de los observadores de la página: lo que la recalcula mientras está montada es
//  lo que invalida lo guardado (lo fija `EstadisticasFluidezCableadoTests`).
//

import Foundation
import SwiftData

/// Lo último que calculó una página, con la firma de sus entradas. Valor puro: lo prueba `EstadisticasMemoriaTests`.
struct StatisticsPageMemory<Key: Equatable, Value> {
    private(set) var key: Key?
    private(set) var value: Value?

    /// Lo guardado si se calculó con exactamente estas entradas; `nil` si no hay nada o cambió algo.
    func recall(_ key: Key) -> Value? {
        guard let stored = self.key, stored == key else { return nil }
        return value
    }

    mutating func remember(_ value: Value, for key: Key) {
        self.key = key
        self.value = value
    }
}

/// Lo que mueve «Tu dinero hoy» del hero de Estadísticas. El corte va como fecha solo con un período cerrado: en uno en
/// curso es «ahora», y meter el reloj aquí recalcularía en cada repintado.
struct StatsHeroMoneyInputs: Equatable {
    let needed: Bool
    let generation: Int
    let transactionCount: Int
    let accountScopes: [String]
    let currencyCode: String
    let includeGroups: Bool
    let overrides: String
    let selectedAccountIDs: Set<PersistentIdentifier>
    let excludedAccountIDs: Set<PersistentIdentifier>
    let closedAt: Date?
}

/// «Tu dinero hoy» ya calculado, compartido por los heros de las páginas de UN contenedor de Estadísticas. Todos piden
/// la misma cifra con las mismas entradas, y cada página que se montaba la volvía a calcular (dos pasadas por todo el
/// histórico). Va por contenedor y no por proceso: `generation` es el contador de recargas de SU
/// `DetailContainerViewModel`, y dos contenedores pueden llevar el mismo número con datos distintos.
@MainActor
final class StatsMoneyTodayMemory {
    private var memory = StatisticsPageMemory<Key, StatsMoneyTodayLogic.Figure>()
    /// Cuántas veces calculó de verdad (testigo de `EstadisticasMemoriaTests`).
    private(set) var computations = 0

    /// El día entra en la firma aunque el hero no lo observe: lo guardado ayer no vale hoy (un movimiento fechado hoy
    /// por la tarde ya cuenta). Con la página montada nada cambia: el hero solo pide cuando cambian sus entradas.
    struct Key: Equatable {
        let inputs: StatsHeroMoneyInputs
        let day: Date
    }

    func figure(
        for inputs: StatsHeroMoneyInputs,
        day: Date,
        compute: () -> StatsMoneyTodayLogic.Figure
    ) -> StatsMoneyTodayLogic.Figure {
        let key = Key(inputs: inputs, day: day)
        if let stored = memory.recall(key) { return stored }
        computations += 1
        let figure = compute()
        memory.remember(figure, for: key)
        return figure
    }
}
