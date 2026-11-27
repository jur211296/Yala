//
//  MotorMesFixture.swift
//  YalaTests
//
//  Datos de prueba del motor del mes: un catálogo de categorías con subcategorías y una historia de movimientos
//  determinista (SplitMix64), como una cuenta real con años de uso. Copia reducida del fixture de
//  `ProyeccionSinTrabasTests` (que es `private`): mismos rasgos que separan las reglas, sin los casos armados de la
//  detección.
//

import Foundation
import SwiftData

@testable import Yala

@MainActor
enum MotorMesFixture {

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }()

    static func mes(_ year: Int, _ month: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    static let mesEnCurso = mes(2026, 11)

    struct Azar {
        var estado: UInt64
        mutating func siguiente() -> UInt64 {
            estado &+= 0x9E37_79B9_7F4A_7C15
            var z = estado
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        mutating func entero(_ rango: ClosedRange<Int>) -> Int {
            rango.lowerBound + Int(siguiente() % UInt64(rango.count))
        }
        mutating func real(_ desde: Double, _ hasta: Double) -> Double {
            desde + (hasta - desde) * Double(siguiente() % 1_000_000) / 1_000_000
        }
        mutating func probable(_ p: Double) -> Bool { real(0, 1) < p }
    }

    struct Catalogo {
        let ingresos: [YalaCategory]
        let gastos: [YalaCategory]
        let subs: [ObjectIdentifier: [Subcategory]]
        func subcategorias(de categoria: YalaCategory) -> [Subcategory] { subs[ObjectIdentifier(categoria)] ?? [] }
    }

    /// Dos categorías de ingreso y diez de gasto, cada una con seis subcategorías. El contexto lo pone la suite (que es
    /// `.serialized`): `makeTestContext()` reusa un contenedor por fichero y vacía el almacén en cada llamada.
    static func catalogo(en context: ModelContext) throws -> Catalogo {
        var subs: [ObjectIdentifier: [Subcategory]] = [:]
        func cat(_ name: String, income: Bool) -> YalaCategory {
            let category = YalaCategory(name: name, colorHex: "#000000", isIncome: income)
            context.insert(category)
            var lista: [Subcategory] = []
            for i in 1...6 {
                let sub = Subcategory(name: "\(name) \(i)", category: category)
                context.insert(sub)
                lista.append(sub)
            }
            subs[ObjectIdentifier(category)] = lista
            return category
        }
        let ingresos = ["Sueldo", "Freelance"].map { cat($0, income: true) }
        let gastos = ["Comida", "Transporte", "Casa", "Salud", "Ocio", "Compras", "Servicios", "Viajes", "Educación",
                      "Mascotas"].map { cat($0, income: false) }
        try context.save()
        return Catalogo(ingresos: ingresos, gastos: gastos, subs: subs)
    }

    static func mov(
        _ mes: Date, _ importe: Double, ingreso: Bool, categoria: YalaCategory?, sub: Subcategory? = nil, dia: Int,
        nota: String? = nil, pago: UUID? = nil, fechado: Bool = false
    ) -> FlujoMotorMes.Movimiento {
        var movimiento = FlujoMotorMes.Movimiento(
            mes: mes, importe: importe, esIngreso: ingreso, categoriaID: categoria?.persistentModelID,
            subcategoriaID: sub?.persistentModelID, categoria: categoria, pagoID: pago, esFechado: fechado
        )
        movimiento.dia = dia
        movimiento.nota = nota
        movimiento.subcategoriaNombre = sub?.name
        movimiento.subcategoria = sub
        return movimiento
    }

    /// `cantidad` movimientos en dos años hasta el mes en curso: sueldos y gastos fijos que se repiten, relleno de los
    /// dos signos con y sin categoría, pagos programados y fechados.
    static func movimientos(_ c: Catalogo, semilla: UInt64, cantidad: Int, meses: Int = 24)
        -> [FlujoMotorMes.Movimiento] {
        var azar = Azar(estado: semilla)
        let historia: [Date] = (0..<meses).compactMap { calendar.date(byAdding: .month, value: -$0, to: mesEnCurso) }
        var result: [FlujoMotorMes.Movimiento] = []
        let sueldo = c.ingresos[0]
        let casa = c.gastos[2], servicios = c.gastos[6], salud = c.gastos[3]
        for (i, m) in historia.enumerated() where i > 0 {
            result.append(mov(m, 3_000 * azar.real(0.97, 1.03), ingreso: true, categoria: sueldo,
                              sub: c.subcategorias(de: sueldo)[0], dia: 28, nota: "ACME SAC"))
            result.append(mov(m, 1_500, ingreso: false, categoria: casa, sub: c.subcategorias(de: casa)[0], dia: 1,
                              nota: "Alquiler depa"))
            result.append(mov(m, 44.9, ingreso: false, categoria: servicios, dia: 12, nota: "PAY*NETFLIX.COM"))
            if i != 3 {
                result.append(mov(m, 120, ingreso: false, categoria: salud, sub: c.subcategorias(de: salud)[2], dia: 5,
                                  nota: "Gimnasio"))
            }
        }
        while result.count < cantidad {
            let m = historia[azar.entero(0...(historia.count - 1))]
            let esIngreso = azar.probable(0.12)
            let categoria: YalaCategory?
            let sub: Subcategory?
            if azar.probable(0.08) {
                categoria = nil
                sub = nil
            } else {
                let lista = esIngreso ? c.ingresos : c.gastos
                let elegida = lista[azar.entero(0...(lista.count - 1))]
                categoria = elegida
                let subs = c.subcategorias(de: elegida)
                sub = azar.probable(0.75) ? subs[azar.entero(0...(subs.count - 2))] : nil
            }
            var importe = azar.probable(0.01) ? azar.real(2_000, 9_000) : azar.real(3, 400)
            if azar.probable(0.04) { importe = -azar.real(5, 300) }
            result.append(mov(
                m, importe, ingreso: esIngreso, categoria: categoria, sub: sub, dia: azar.entero(1...28),
                nota: "Comercio \(azar.entero(1...320))", pago: azar.probable(0.04) ? UUID() : nil,
                fechado: m == mesEnCurso && azar.probable(0.05)
            ))
        }
        return result
    }

    /// El flujo de caja de un año: seis meses cerrados, el mes en curso y seis que vienen, sin plan.
    static func entrada(_ historia: [FlujoMotorMes.Movimiento]) -> FlujoMotorMes.Entrada {
        let meses = (0...12).compactMap { calendar.date(byAdding: .month, value: $0 - 6, to: mesEnCurso) }
        return FlujoMotorMes.Entrada(
            meses: meses, mesEnCurso: mesEnCurso, quedanDiasEnElMes: true, lineas: [], limite: { _, _ in 0 },
            movimientos: historia, pendientes: [], calendar: calendar)
    }

    static func milisegundos(_ veces: Int = 3, _ bloque: () -> Void) -> Double {
        var mejor = Double.infinity
        for _ in 0..<veces {
            let inicio = ContinuousClock.now
            bloque()
            let d = ContinuousClock.now - inicio
            mejor = min(mejor, Double(d.components.seconds) * 1_000 + Double(d.components.attoseconds) / 1e15)
        }
        return mejor
    }
}
