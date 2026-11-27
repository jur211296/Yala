//
//  IndiceYCesionTests.swift
//  YalaTests
//
//  Lote 4 de eficiencia (26-nov-2026): las dos piezas del recálculo por tramos del Panel.
//  - `IndiceFechasMovimientos` devuelve lo mismo que filtrar por el intervalo, y en el mismo orden (extremos incluidos,
//    como `DateInterval.contains`).
//  - `CesionDelHilo` no cambia lo que procesa, cede cuando el tramo pasa del límite y corta si el cálculo ya no sigue.
//  Y el cableado: el Panel usa las dos.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Recálculo del Panel · índice por fecha y cesión del hilo")
struct IndiceYCesionTests {

    private struct Fila: Equatable {
        let id: Int
        let fecha: Date
    }

    private static let base = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// Filas desordenadas, con fechas repetidas y algunas justo en los bordes de los intervalos de la prueba.
    private static func filas() -> [Fila] {
        var estado: UInt64 = 7
        return (0..<2_000).map { i in
            estado = estado &* 6_364_136_223_846_793_005 &+ 1
            let segundos = Double((estado >> 33) % 5_000) * 60
            let enBorde = Double(i / 9 % 40) * 3_600
            let desplazamiento: TimeInterval = i % 9 == 0 ? enBorde : segundos
            return Fila(id: i, fecha: base.addingTimeInterval(desplazamiento))
        }
    }

    private static func intervalos() -> [DateInterval] {
        var lista: [DateInterval] = []
        for desde in stride(from: -3_600.0, through: 300_000, by: 17_000) {
            for largo: TimeInterval in [0, 3_600, 59_999, 172_800] {
                lista.append(DateInterval(start: base.addingTimeInterval(desde), duration: largo))
            }
        }
        // Bordes exactos sobre fechas que existen.
        lista.append(DateInterval(start: base, end: base.addingTimeInterval(3_600)))
        lista.append(DateInterval(start: base.addingTimeInterval(7_200), end: base.addingTimeInterval(7_200)))
        return lista
    }

    @Test("Los elementos de un intervalo son los del filtro, en el orden original")
    func elementosEn_esElFiltro() {
        let filas = Self.filas()
        let indice = IndiceFechasMovimientos(filas, fecha: \.fecha)
        for intervalo in Self.intervalos() {
            #expect(indice.elementos(en: intervalo) == filas.filter { intervalo.contains($0.fecha) }, "\(intervalo)")
        }
    }

    @Test("Varios intervalos a la vez: la unión, sin repetir, en el orden original")
    func elementosEnAlguno_esLaUnion() {
        let filas = Self.filas()
        let indice = IndiceFechasMovimientos(filas, fecha: \.fecha)
        let intervalos = Array(Self.intervalos().prefix(9))
        let esperado = filas.filter { fila in intervalos.contains { $0.contains(fila.fecha) } }
        #expect(indice.elementos(enAlguno: intervalos) == esperado)
    }

    @Test("La última fecha hasta un límite es el máximo del filtro")
    func ultimaFecha_esElMaximo() {
        let filas = Self.filas()
        let indice = IndiceFechasMovimientos(filas, fecha: \.fecha)
        let cumple: (Fila) -> Bool = { $0.id % 3 != 0 }
        for limite in [Self.base.addingTimeInterval(-1), Self.base, Self.base.addingTimeInterval(3_600), Self.base.addingTimeInterval(1e6)] {
            let esperado = filas.filter { $0.fecha <= limite && cumple($0) }.map(\.fecha).max()
            #expect(indice.ultimaFecha(hasta: limite, donde: cumple) == esperado, "\(limite)")
        }
    }

    @Test("Con fechas que no casan en número, cada consulta devuelve todo (quien filtre después sigue bien)")
    func sinIndice_devuelveTodo() {
        let filas = Self.filas()
        let indice = IndiceFechasMovimientos(filas, fechas: [Self.base])
        #expect(indice.elementos(en: DateInterval(start: Self.base, duration: 1)) == filas)
    }

    // MARK: - Cesión

    @Test("Por trozos, filtrar y transformar dan lo mismo que de una vez")
    func cesion_noCambiaElResultado() async throws {
        let filas = Self.filas()
        let cesion = CesionDelHilo(limite: .zero) { true }
        let porTrozos = try await cesion.porTrozos(filas, tamano: 300) { $0.filter { $0.id % 4 == 1 } }
        #expect(porTrozos == filas.filter { $0.id % 4 == 1 })
        let filtradas = try await cesion.filtrar(filas) { $0.id % 5 == 2 }
        #expect(filtradas == filas.filter { $0.id % 5 == 2 })
        let ids = try await cesion.transformar(filas) { $0.id * 2 }
        #expect(ids == filas.map { $0.id * 2 })
        #expect(cesion.cesiones > 0, "con límite cero tiene que haber cedido por el camino")
    }

    @Test("Si el cálculo ya no sigue, la cesión lo corta")
    func cesion_cortaSiNoSigue() async {
        let cesion = CesionDelHilo(limite: .zero) { false }
        await #expect(throws: CancellationError.self) {
            _ = try await cesion.filtrar(Self.filas()) { _ in true }
        }
    }

    @Test("Con el tramo por debajo del límite no cede")
    func cesion_noCedeSinNecesidad() async throws {
        let cesion = CesionDelHilo(limite: .seconds(60)) { true }
        _ = try await cesion.porTrozos(Self.filas(), tamano: 100) { $0 }
        #expect(cesion.cesiones == 0)
    }

    // MARK: - Cableado

    private static func repoFile(_ path: String, file: StaticString = #filePath) throws -> String {
        let root = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    private static func panelSource() throws -> String {
        try repoFile("Yala/App/ViewModels/PanelViewModel.swift")
    }

    private static func body(of signature: String, in code: String) throws -> String {
        let start = try #require(code.range(of: signature))
        let rest = code[start.upperBound...]
        let end = rest.range(of: "\n    }\n")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }

    @Test("El cálculo por etapas arma el índice una vez y cede dentro de las etapas")
    func cableado_etapasConIndiceYCesion() throws {
        let code = try Self.panelSource()
        let body = try Self.body(of: "private func performCalculationInStages() async -> Bool", in: code)
        #expect(body.contains("IndiceFechasMovimientos.armar(transactions"))
        #expect(body.contains("CesionDelHilo"))
        #expect(body.contains("cesion: cesion"), "la tendencia y los presupuestos ceden dentro de su etapa")
        #expect(body.contains("calculateHealthWidget(paidAmounts: paidForHealth, indice: indice, cesion: cesion)"))
        #expect(body.contains("calculateAccountPeriodExpenses(indice: indice)"))
        #expect(body.contains("MarcasRecalculoPanel()"), "sin marcas no hay cómo medirlo en el iPhone")
    }

    @Test("Los recorridos del historial de la tendencia van por trozos")
    func cableado_contextoPorTrozos() throws {
        let code = try Self.panelSource()
        let body = try Self.body(of: "private func buildCalculationContext(", in: code)
        #expect(body.components(separatedBy: "cesion.porTrozos(transactions)").count - 1 == 4,
                "los cuatro recorridos del historial (filtrado, sin fecha, saldo y tartas)")
        #expect(!body.contains("= transactions.filter"), "un recorrido del historial de una vez")
    }

    @Test("Nadie calcula la tendencia de una vez fuera del cálculo por etapas")
    func cableado_sinTendenciaSincrona() throws {
        let code = try Self.panelSource()
        #expect(code.components(separatedBy: "try await calculateTrendData(").count - 1 == 1)
        #expect(code.components(separatedBy: "calculateTrendData(").count - 1 == 2, "la definición y su única llamada")
    }

    @Test("El ritmo de la nota no ordena los movimientos")
    func cableado_ritmoSinOrdenar() throws {
        let code = try Self.repoFile("Yala/App/Logic/Calculators/FinancialScoreCalculator.swift")
        let body = try Self.body(of: "private static func calculateRhythm(", in: code)
        #expect(!body.contains(".sorted"))
    }
}
