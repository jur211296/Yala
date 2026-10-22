//
//  StatsHeroCaptionWiringTests.swift
//  YalaTests
//
//  Que el rótulo del hero llegue a la PANTALLA, y con el estado correcto.
//  Ticket `hero-estadisticas-stock-vs-flujo-entre-pestanas`.
//
//  **Por qué hace falta.** `StatsHeroCaptionTests` cubre la derivación entera, y aun así se puede
//  borrar el `Text(...)` de las cuatro vistas —o cablearlo a un valor fijo— y **la suite sigue en
//  verde**: eso es exactamente el bug del ticket, el número sin decir qué es. Afirmar el render de
//  un `Text` dentro de un `VStack` pide un XCUITest por pestaña con filtros sembrados, el montaje
//  más caro del ticket.
//
//  El sustituto es fijar el CABLEADO leyendo el fuente, el mismo compromiso que ya toma
//  `ApproximateMarkWiringTests`. Es más débil que un test de comportamiento —fija el texto, no el
//  resultado— y se elige a conciencia: sin él, un rótulo que miente no lo nota nadie hasta que un
//  usuario lee "Saldo de cuentas" sobre un total de gastos.
//

import Foundation
import Testing

@testable import Yala

@Suite("Cableado del rótulo del hero de Estadísticas (source-scan)")
struct StatsHeroCaptionWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private static let views = [
        "Yala/App/Views/Statistics/CategoriesTabView.swift",
        "Yala/App/Views/Statistics/TrendsTabView.swift",
        "Yala/App/Views/Statistics/InsightsTabView.swift",
        "Yala/App/Views/Statistics/RecordsTabView.swift",
    ]

    @Test("Las cuatro pestañas pintan el rótulo")
    func allFourTabsRenderTheCaption() throws {
        for path in Self.views {
            let src = try Self.source(path)
            #expect(src.contains("StatsHeroCaptionLogic."), """
                \(path) no usa `StatsHeroCaptionLogic`: su hero volvió a ser un número sin decir qué es.
                """)
            #expect(src.contains("\"stats_hero_caption\""), """
                \(path) perdió el identificador de accesibilidad del rótulo, con el que el device-QA
                lo localiza en las cuatro pestañas.
                """)
        }
    }

    /// El caso que motivó el ticket: aquí es donde un rótulo fijo mentía.
    @Test("Distribución deriva el rótulo de isBalanceMode Y de las naturalezas")
    func distributionPassesBothSignals() throws {
        let src = try Self.source("Yala/App/Views/Statistics/CategoriesTabView.swift")

        #expect(src.contains("isBalanceMode: isBalanceMode"), """
            Sin `isBalanceMode` el rótulo no puede distinguir el saldo (stock) del flujo del período,
            que es justo la ambigüedad que este ticket venía a cerrar.
            """)
        #expect(src.contains("natures: viewModel.selectedTransactionNatures"), """
            Sin las naturalezas, Distribución rotularía "Saldo de cuentas" también con un chip de
            Gastos puesto — donde el hero muestra flujo por decisión del owner del 2026-08-26.
            """)
    }

    @Test("Tendencias deriva el rótulo de la métrica, que es la que elige el número")
    func trendsPassesTheMetric() throws {
        let src = try Self.source("Yala/App/Views/Statistics/TrendsTabView.swift")
        #expect(src.contains("StatsHeroCaptionLogic.trends(metric: trendsViewModel.selectedMetric)"), """
            `heroKPIValue` devuelve uno de tres números según `selectedMetric`; con el rótulo cableado
            a otra cosa, dos de los tres estados quedan mal rotulados.
            """)
    }

    @Test("Registros deriva el rótulo del filtro de naturaleza")
    func recordsPassesTheNatureFilter() throws {
        let src = try Self.source("Yala/App/Views/Statistics/RecordsTabView.swift")
        #expect(src.contains("natures: viewModel.selectedTransactionNatures"), """
            Con un chip activo `recordsSummary.balance` deja de ser un neto; sin esta señal el rótulo
            seguiría diciendo "Neto del período".
            """)
    }

    /// El comentario que el ticket manda reescribir: documentaba una coherencia que ya no existe.
    @Test("El comentario de TrendsTabView ya no justifica el hero por coherencia cross-tab")
    func trendsCommentNoLongerClaimsCrossTabCoherence() throws {
        let src = try Self.source("Yala/App/Views/Statistics/TrendsTabView.swift")
        #expect(!src.contains("período para coherencia cross-tab"), """
            El comentario seguía diciendo que el hero usa el agregado del período "para coherencia
            cross-tab". Desde el 2026-09-06 Distribución puede enseñar un saldo en ese mismo hueco,
            así que esa coherencia ya no existe y el comentario manda al yo-futuro en la dirección
            contraria.
            """)
    }
}
