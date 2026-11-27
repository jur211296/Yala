//
//  MotorMesOrdenPartidasTests.swift
//  YalaTests
//
//  El orden de las partidas de «otros» del motor del mes (`FlujoMotorMes.ordenarPartidas`). Antes, cada comparación
//  del `sorted` convertía en texto el `PersistentIdentifier` de las dos partidas (`String(describing:)`, que va por
//  reflexión): con la detección ya arreglada era el 34 % del motor del mes en la traza de 13 meses y 16 mil movimientos.
//
//  Lo que fija este fichero:
//  - **Paridad**: el orden nuevo da exactamente lo mismo que el de antes (`ordenAntes`, copia congelada del 27-nov-2026,
//    `origin/2.3` en 28cdb9ad8a) con varias semillas y con los desempates: totales iguales, categoría, subcategoría y
//    sin categoría. Y sobre el motor entero: las partidas que devuelve `calcular` ya vienen en el orden de antes.
//  - **Una clave por partida** (testigo `_testClavesDeOrden`): la red determinista; el tiempo depende de la máquina.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Arreglos pre-build 12 · el orden de «otros» del motor del mes", .serialized)
struct MotorMesOrdenPartidasTests {

    typealias Base = FlujoProyeccionInteligente.Clave.Base

    // MARK: - Referencia congelada (no se mantiene: si el orden cambia a propósito, se retira con su paridad)

    private static func ordenAntes(_ base: Base) -> String {
        switch base {
        case .subcategoria(let id): return "s\(String(describing: id))"
        case .categoria(let id): return "c\(String(describing: id))"
        case .sinCategoria: return "z"
        }
    }

    private static func ordenarAntes(_ partidas: [FlujoMotorMes.PartidaOtros]) -> [FlujoMotorMes.PartidaOtros] {
        partidas.sorted { ($0.total, ordenAntes($0.base)) > ($1.total, ordenAntes($1.base)) }
    }

    // MARK: - Ayudantes

    private static func nombre(_ base: Base) -> String {
        switch base {
        case .subcategoria(let id): return "s\(id.hashValue)"
        case .categoria(let id): return "c\(id.hashValue)"
        case .sinCategoria: return "z"
        }
    }

    private static func huella(_ partidas: [FlujoMotorMes.PartidaOtros]) -> [String] {
        partidas.map { "\(nombre($0.base))|\($0.total)" }
    }

    private static func partida(_ base: Base, real: Double, programado: Double = 0, proyectado: Double = 0)
        -> FlujoMotorMes.PartidaOtros {
        var fila = FlujoMotorMes.PartidaOtros(base: base, categoriaID: nil)
        fila.real = real
        fila.programado = programado
        fila.proyectado = proyectado
        return fila
    }

    /// Todas las bases del catálogo (12 categorías, 72 subcategorías y «sin categoría»).
    private static func bases(_ c: MotorMesFixture.Catalogo) -> [Base] {
        var result: [Base] = [.sinCategoria]
        for categoria in c.ingresos + c.gastos {
            result.append(.categoria(categoria.persistentModelID))
            result += c.subcategorias(de: categoria).map { .subcategoria($0.persistentModelID) }
        }
        return result
    }

    // MARK: - Paridad

    @Test(arguments: [UInt64(1), 2, 3, 4, 5, 6, 7, 8])
    func paridad_conPartidasAlAzar(semilla: UInt64) throws {
        let c = try MotorMesFixture.catalogo(en: makeTestContext())
        var azar = MotorMesFixture.Azar(estado: semilla)
        // Pocos importes distintos a propósito: muchos totales iguales, que es donde decide la clave.
        let importes: [Double] = [0, 10, 10, 25.5, 100, -40, 100, 3_000]
        var mezcla = Self.bases(c)
        for i in stride(from: mezcla.count - 1, to: 0, by: -1) { mezcla.swapAt(i, azar.entero(0...i)) }
        let partidas = mezcla.map { base in
            Self.partida(base, real: importes[azar.entero(0...(importes.count - 1))],
                         programado: azar.probable(0.3) ? 10 : 0,
                         proyectado: azar.probable(0.2) ? importes[azar.entero(0...(importes.count - 1))] : 0)
        }
        #expect(Self.huella(FlujoMotorMes.ordenarPartidas(partidas)) == Self.huella(Self.ordenarAntes(partidas)))
    }

    @Test func paridad_casosDeBorde() throws {
        let c = try MotorMesFixture.catalogo(en: makeTestContext())
        let comida = c.gastos[0]
        let sub = c.subcategorias(de: comida)
        let todas: [Base] = [.sinCategoria, .categoria(comida.persistentModelID), .subcategoria(sub[0].persistentModelID),
                             .subcategoria(sub[1].persistentModelID), .categoria(c.gastos[1].persistentModelID)]
        // Todas con el mismo total: decide solo la clave, en descendente («z» › «s…» › «c…»), como antes.
        let iguales = todas.map { Self.partida($0, real: 50) }
        #expect(Self.huella(FlujoMotorMes.ordenarPartidas(iguales)) == Self.huella(Self.ordenarAntes(iguales)))
        #expect(Self.huella(FlujoMotorMes.ordenarPartidas(iguales.reversed()))
                == Self.huella(Self.ordenarAntes(iguales.reversed())))
        // El mismo total por caminos distintos (real, programado, proyectado).
        let porPartes = [Self.partida(todas[1], real: 30, programado: 20), Self.partida(todas[2], real: 0, proyectado: 50),
                         Self.partida(todas[0], real: 50), Self.partida(todas[3], real: 60, programado: -10)]
        #expect(Self.huella(FlujoMotorMes.ordenarPartidas(porPartes)) == Self.huella(Self.ordenarAntes(porPartes)))
        // Negativos (devoluciones) y vacía y de una.
        let negativos = todas.enumerated().map { Self.partida($1, real: Double($0) * -10) }
        #expect(Self.huella(FlujoMotorMes.ordenarPartidas(negativos)) == Self.huella(Self.ordenarAntes(negativos)))
        #expect(FlujoMotorMes.ordenarPartidas([]).isEmpty)
        #expect(Self.huella(FlujoMotorMes.ordenarPartidas([iguales[2]])) == Self.huella([iguales[2]]))
    }

    /// Sobre el motor entero, 13 meses y 16 mil movimientos: las partidas que salen ya están en el orden de antes.
    @Test(arguments: [UInt64(16_004), 7, 42])
    func paridad_motorEntero(semilla: UInt64) throws {
        let c = try MotorMesFixture.catalogo(en: makeTestContext())
        let historia = MotorMesFixture.movimientos(c, semilla: semilla, cantidad: 16_000)
        let meses = FlujoMotorMes.calcular(MotorMesFixture.entrada(historia))
        var vistas = 0
        for mes in meses {
            for lado in [mes.ingresos, mes.gastos] {
                let partidas = lado.otros.partidas
                vistas += partidas.count
                #expect(Self.huella(partidas) == Self.huella(Self.ordenarAntes(partidas)),
                        "mes \(mes.inicio): el orden de las partidas cambió")
            }
        }
        #expect(vistas > 100, "el escenario no produjo partidas que ordenar (\(vistas))")
    }

    // MARK: - Testigo: una clave por partida

    @Test func laClaveSeCalculaUnaVezPorPartida() throws {
        let c = try MotorMesFixture.catalogo(en: makeTestContext())
        let partidas = Self.bases(c).map { Self.partida($0, real: 10) }
        FlujoMotorMes._testClavesDeOrden = 0
        _ = FlujoMotorMes.ordenarPartidas(partidas)
        #expect(FlujoMotorMes._testClavesDeOrden == partidas.count,
                "\(FlujoMotorMes._testClavesDeOrden) claves para \(partidas.count) partidas")

        // Y en el motor entero: no más claves que partidas filtradas por mes y lado.
        let historia = MotorMesFixture.movimientos(c, semilla: 16_004, cantidad: 16_000)
        FlujoMotorMes._testClavesDeOrden = 0
        let meses = FlujoMotorMes.calcular(MotorMesFixture.entrada(historia))
        let total = meses.reduce(0) { $0 + $1.ingresos.otros.partidas.count + $1.gastos.otros.partidas.count }
        #expect(FlujoMotorMes._testClavesDeOrden == total,
                "motor: \(FlujoMotorMes._testClavesDeOrden) claves para \(total) partidas")
    }

    // MARK: - Medición (informativa: se imprime con `MEDICION:`, no afirma un tiempo)

    /// El motor entero, 13 meses y 16 mil movimientos. En `origin/2.3` (28cdb9ad8a), con el orden de antes, este mismo
    /// caso dio 232,1 ms en el simulador de la Mini (27-nov-2026, mejor de 5).
    @Test func medicion_motorDelMes13Meses() throws {
        let c = try MotorMesFixture.catalogo(en: makeTestContext())
        let historia = MotorMesFixture.movimientos(c, semilla: 16_004, cantidad: 16_000)
        let entrada = MotorMesFixture.entrada(historia)
        _ = FlujoMotorMes.calcular(entrada)  // calienta
        let motor = MotorMesFixture.milisegundos(5) { _ = FlujoMotorMes.calcular(entrada) }
        print(String(format: "MEDICION: motor del mes 13 meses, 16k movimientos: %.1f ms (mejor de 5)", motor))
        #expect(motor.isFinite)
    }

    // MARK: - Medición del orden (informativa)

    @Test func medicion_ordenAntesYDespues() throws {
        let c = try MotorMesFixture.catalogo(en: makeTestContext())
        let historia = MotorMesFixture.movimientos(c, semilla: 16_004, cantidad: 16_000)
        let meses = FlujoMotorMes.calcular(MotorMesFixture.entrada(historia))
        let listas = meses.flatMap { [$0.ingresos.otros.partidas, $0.gastos.otros.partidas] }
        let antes = MotorMesFixture.milisegundos(5) { for l in listas { _ = Self.ordenarAntes(l) } }
        let despues = MotorMesFixture.milisegundos(5) { for l in listas { _ = FlujoMotorMes.ordenarPartidas(l) } }
        print(String(format: "MEDICION: orden de «otros» en 13 meses (%d listas, %d partidas): antes %.1f ms · después %.1f ms",
                     listas.count, listas.reduce(0) { $0 + $1.count }, antes, despues))
        #expect(antes.isFinite && despues.isFinite)
    }
}
