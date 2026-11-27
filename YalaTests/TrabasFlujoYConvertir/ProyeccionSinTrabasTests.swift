//
//  ProyeccionSinTrabasTests.swift
//  YalaTests
//
//  YALA-IOS-15 (build 5 de 2.3, 20-nov-2026): la app se trababa segundos en el flujo de caja dentro de
//  `FlujoProyeccionInteligente.detectar`, en el hilo principal. La pila de Sentry cae en el `sorted` de los grupos: cada
//  comparación convertía dos `PersistentIdentifier` en texto (`String(describing:)`, que va por reflexión), y cada
//  lectura de `Movimiento.comercio` pasaba la nota por dos expresiones regulares, varias veces por movimiento.
//
//  Lo que fija este fichero:
//  - **Paridad**: la detección nueva da lo mismo que la de antes (`FlujoProyeccionInteligenteAntes`, copia congelada)
//    con 16 mil movimientos y con los casos de borde: fijos, fijos a futuro, aislados, lo variable, el mes típico y lo
//    que contestan las preguntas del motor (`fijoQueReconoce`, `fijoAFuturo`, `esAisladoEnMesProyectado`, `adelantado`).
//  - **Un solo cálculo por grupo y por nota** (testigos `_testOrdenes`, `_testComerciosCalculados`): el orden entre
//    grupos se calcula una vez por grupo y el comercio una vez por nota distinta. Es la red determinista: el tiempo
//    depende de la máquina, los testigos no.
//  - **La medición** antes/después (se imprime con `MEDICION:`; no se afirma un tiempo).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Trabas · la proyección inteligente no traba el flujo de caja (YALA-IOS-15)", .serialized)
struct ProyeccionSinTrabasTests {

    // MARK: - Fixture

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }()

    private static func mes(_ year: Int, _ month: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    private static let mesEnCurso = mes(2026, 11)

    /// Generador determinista (SplitMix64): la misma semilla da los mismos movimientos en cualquier máquina.
    private struct Azar {
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

    /// Categorías del almacén: dos de ingreso y diez de gasto, cada una con seis subcategorías (84 grupos posibles, como
    /// una cuenta real con años de uso).
    private struct Catalogo {
        let ingresos: [YalaCategory]
        let gastos: [YalaCategory]
        let subs: [ObjectIdentifier: [Subcategory]]
        func subcategorias(de categoria: YalaCategory) -> [Subcategory] { subs[ObjectIdentifier(categoria)] ?? [] }
    }

    private static func catalogo() throws -> Catalogo {
        let context = try makeTestContext()
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

    private static func mov(
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

    /// Notas como las escribe la gente: el mismo comercio con prefijos de procesador, mayúsculas y símbolos distintos.
    private static func nota(_ azar: inout Azar) -> String? {
        guard azar.probable(0.65) else { return azar.probable(0.1) ? "   " : nil }
        let base = "Comercio \(azar.entero(1...320))"
        switch azar.entero(0...4) {
        case 0: return base
        case 1: return "DP*" + base.uppercased()
        case 2: return base.lowercased() + " #\(azar.entero(1...9))"
        case 3: return "IZI*" + base + "!"
        default: return "  " + base + "  "
        }
    }

    /// `cantidad` movimientos en dos años hasta el mes en curso, con lo que separa las reglas: sueldos fijos (uno que
    /// bajó, uno que dejó de llegar, uno por comercio dentro de un grupo que varía), gastos que se repiten el mismo día,
    /// compras grandes que no se repiten y su devolución, devoluciones sueltas, sin categoría de los dos signos, pagos
    /// programados y fechados.
    private static func movimientos(_ c: Catalogo, semilla: UInt64, cantidad: Int, meses: Int = 24)
        -> [FlujoMotorMes.Movimiento] {
        var azar = Azar(estado: semilla)
        let historia: [Date] = (0..<meses).compactMap { calendar.date(byAdding: .month, value: -$0, to: mesEnCurso) }
        var result: [FlujoMotorMes.Movimiento] = []
        let sueldo = c.ingresos[0], freelance = c.ingresos[1]
        let sueldoSub = c.subcategorias(de: sueldo)
        let casa = c.gastos[2], servicios = c.gastos[6], salud = c.gastos[3]
        for (i, m) in historia.enumerated() where i > 0 {
            // Sueldo fijo el 28 (un mes adelantado al 30 del anterior no hace falta: lo cubre `adelantado`).
            result.append(mov(m, 3_000 * azar.real(0.97, 1.03), ingreso: true, categoria: sueldo, sub: sueldoSub[0],
                              dia: i % 5 == 0 ? 1 : 28, nota: "ACME SAC"))
            // Un sueldo que bajó el último mes completo.
            result.append(mov(m, i == 1 ? 1_200 : 2_000, ingreso: true, categoria: sueldo, sub: sueldoSub[1], dia: 15))
            // Un sueldo que dejó de llegar hace tres meses.
            if i > 3 { result.append(mov(m, 900, ingreso: true, categoria: sueldo, sub: sueldoSub[2], dia: 5)) }
            // Freelance que varía, con un cliente fijo dentro (en una subcategoría que el relleno no usa: con miles de
            // movimientos, una subcategoría compartida suma tan parejo que sale fija entera).
            let clientes = c.subcategorias(de: freelance)[5]
            result.append(mov(m, 800 * azar.real(0.95, 1.05), ingreso: true, categoria: freelance, sub: clientes, dia: 15,
                              nota: "PAYPAL *Cliente Fijo"))
            if azar.probable(0.6) {
                result.append(mov(m, azar.real(50, 2_500), ingreso: true, categoria: freelance, sub: clientes,
                                  dia: azar.entero(1...28), nota: "Cliente \(azar.entero(1...40))"))
            }
            // Gastos fijos de verdad: alquiler el 1 y Netflix el 12; el gimnasio salta un mes.
            result.append(mov(m, 1_500, ingreso: false, categoria: casa, sub: c.subcategorias(de: casa)[0], dia: 1,
                              nota: "Alquiler depa"))
            result.append(mov(m, 44.9, ingreso: false, categoria: servicios, dia: 12, nota: "PAY*NETFLIX.COM"))
            if i != 3 {
                result.append(mov(m, 120, ingreso: false, categoria: salud, sub: c.subcategorias(de: salud)[2], dia: 5,
                                  nota: "Gimnasio"))
            }
        }
        // Una compra grande que no se repite, con su devolución, y otra sin devolver. «Grande» es relativo a lo que se
        // gasta en un mes: con 16 mil movimientos un mes típico ronda los 100 mil.
        if historia.count > 4 {
            let compras = c.gastos[5]
            let tech = c.subcategorias(de: compras)[5]
            let grande = Double(max(cantidad, 300)) * 40
            result.append(mov(historia[3], grande, ingreso: false, categoria: compras, sub: tech, dia: 20, nota: "iShop"))
            result.append(mov(historia[2], -grande, ingreso: false, categoria: compras, sub: tech, dia: 3, nota: "iShop"))
            result.append(mov(historia[2], grande * 1.5, ingreso: false, categoria: c.gastos[7],
                              sub: c.subcategorias(de: c.gastos[7])[5], dia: 9, nota: "Aerolínea"))
            // Un ingreso grande suelto.
            result.append(mov(historia[4], 20_000, ingreso: true, categoria: nil, dia: 10, nota: "Herencia"))
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
                // La sexta subcategoría de cada categoría queda para los casos armados a mano.
                let subs = c.subcategorias(de: elegida)
                sub = azar.probable(0.75) ? subs[azar.entero(0...(subs.count - 2))] : nil
            }
            var importe = azar.probable(0.01) ? azar.real(2_000, 9_000) : azar.real(3, 400)
            if azar.probable(0.04) { importe = -azar.real(5, 300) }
            result.append(mov(
                m, importe, ingreso: esIngreso, categoria: categoria, sub: sub, dia: azar.entero(1...28),
                nota: nota(&azar), pago: azar.probable(0.04) ? UUID() : nil, fechado: m == mesEnCurso && azar.probable(0.05)
            ))
        }
        return result
    }

    // MARK: - Comparación con la referencia

    private static func nombre(_ base: FlujoProyeccionInteligente.Clave.Base) -> String {
        switch base {
        case .subcategoria(let id): return "s\(String(describing: id))"
        case .categoria(let id): return "c\(String(describing: id))"
        case .sinCategoria: return "z"
        }
    }

    private static func nombre(_ base: FlujoProyeccionInteligenteAntes.Clave.Base) -> String {
        switch base {
        case .subcategoria(let id): return "s\(String(describing: id))"
        case .categoria(let id): return "c\(String(describing: id))"
        case .sinCategoria: return "z"
        }
    }

    private static func redondo(_ x: Double) -> Double { (x * 1_000_000).rounded() / 1_000_000 }

    private static func huella(_ f: FlujoProyeccionInteligente.Fijo) -> String {
        [nombre(f.clave.base), f.clave.comercio ?? "-", "\(f.esIngreso)", "\(redondo(f.monto))", "\(f.dia)",
         "\(f.unaVezAlMes)", "\(f.mesesVistos)/\(f.mesesVentana)", f.categoria?.name ?? "-", f.subcategoriaNombre ?? "-",
         f.comercioVisible ?? "-", f.subcategoria?.name ?? "-", f.claveEstable].joined(separator: "|")
    }

    private static func huella(_ f: FlujoProyeccionInteligenteAntes.Fijo) -> String {
        [nombre(f.clave.base), f.clave.comercio ?? "-", "\(f.esIngreso)", "\(redondo(f.monto))", "\(f.dia)",
         "\(f.unaVezAlMes)", "\(f.mesesVistos)/\(f.mesesVentana)", f.categoria?.name ?? "-", f.subcategoriaNombre ?? "-",
         f.comercioVisible ?? "-", f.subcategoria?.name ?? "-", f.claveEstable].joined(separator: "|")
    }

    private static func huella(_ a: FlujoProyeccionInteligente.Aislado) -> String {
        "\(a.mes.timeIntervalSince1970)|\(redondo(a.importe))|\(a.esIngreso)|\(a.categoria?.name ?? "-")|"
            + "\(a.subcategoriaNombre ?? "-")|\(a.comercioVisible ?? "-")"
    }

    private static func huella(_ a: FlujoProyeccionInteligenteAntes.Aislado) -> String {
        "\(a.mes.timeIntervalSince1970)|\(redondo(a.importe))|\(a.esIngreso)|\(a.categoria?.name ?? "-")|"
            + "\(a.subcategoriaNombre ?? "-")|\(a.comercioVisible ?? "-")"
    }

    private static func primerMes(_ movs: [FlujoMotorMes.Movimiento]) -> Date? { movs.map(\.mes).min() }

    /// Las dos detecciones de un lado, campo por campo, y lo que contestan sobre cada movimiento de la historia.
    private static func comparar(
        _ historia: [FlujoMotorMes.Movimiento], esIngreso: Bool, primerMes: Date?, caso: String
    ) {
        let nuevo = FlujoProyeccionInteligente.detectar(
            esIngreso: esIngreso, historia: historia, primerMes: primerMes, mesEnCurso: mesEnCurso, calendar: calendar)
        let antes = FlujoProyeccionInteligenteAntes.detectar(
            esIngreso: esIngreso, historia: historia, primerMes: primerMes, mesEnCurso: mesEnCurso, calendar: calendar)
        let lado = "\(caso) · \(esIngreso ? "ingresos" : "gastos")"

        #expect(nuevo.mesesDeHistoria == antes.mesesDeHistoria, "\(lado): meses de historia")
        #expect(nuevo.detecta == antes.detecta, "\(lado): detecta")
        #expect(nuevo.fijos.map(huella) == antes.fijos.map(huella), "\(lado): fijos")
        #expect(nuevo.fijosAFuturo.map(huella) == antes.fijosAFuturo.map(huella), "\(lado): fijos a futuro")
        #expect(nuevo.aisladosVentana.map(huella).sorted() == antes.aisladosVentana.map(huella).sorted(),
                "\(lado): aislados")
        #expect(redondo(nuevo.variable) == redondo(antes.variable), "\(lado): lo variable")
        #expect(redondo(nuevo.mesTipico) == redondo(antes.mesTipico), "\(lado): mes típico")

        var difieren = 0
        for mov in historia {
            if nuevo.fijoQueReconoce(mov).map(huella) != antes.fijoQueReconoce(mov).map(huella) { difieren += 1 }
            if nuevo.fijoAFuturo(de: mov).map(huella) != antes.fijoAFuturo(de: mov).map(huella) { difieren += 1 }
            if nuevo.fijo(de: mov).map(huella) != antes.fijo(de: mov).map(huella) { difieren += 1 }
            if nuevo.esAisladoEnMesProyectado(mov) != antes.esAisladoEnMesProyectado(mov) { difieren += 1 }
        }
        #expect(difieren == 0, "\(lado): \(difieren) respuestas distintas sobre los movimientos")

        // Lo adelantado del mes anterior, para cada fijo (los fijos coinciden, así que se emparejan por posición).
        let anterior = calendar.date(byAdding: .month, value: -1, to: mesEnCurso)
        let delAnterior = historia.filter { $0.mes == anterior }
        for (f, g) in zip(nuevo.fijos, antes.fijos) {
            #expect(redondo(FlujoProyeccionInteligente.adelantado(f, enElMesAnterior: delAnterior, lado: nuevo))
                == redondo(FlujoProyeccionInteligenteAntes.adelantado(g, enElMesAnterior: delAnterior, lado: antes)),
                "\(lado): adelantado de \(huella(f))")
        }
    }

    private static func compararLosDosLados(_ historia: [FlujoMotorMes.Movimiento], caso: String) {
        let primero = primerMes(historia)
        comparar(historia, esIngreso: true, primerMes: primero, caso: caso)
        comparar(historia, esIngreso: false, primerMes: primero, caso: caso)
    }

    // MARK: - Paridad

    @Test func paridad_conDieciseisMilMovimientos() throws {
        let c = try Self.catalogo()
        let historia = Self.movimientos(c, semilla: 16_004, cantidad: 16_000)
        // El fixture trae lo que separa las reglas: algún fijo por comercio, algún fijo a futuro y algún aislado.
        let ingresos = FlujoProyeccionInteligente.detectar(
            esIngreso: true, historia: historia, primerMes: Self.primerMes(historia), mesEnCurso: Self.mesEnCurso,
            calendar: Self.calendar)
        let gastos = FlujoProyeccionInteligente.detectar(
            esIngreso: false, historia: historia, primerMes: Self.primerMes(historia), mesEnCurso: Self.mesEnCurso,
            calendar: Self.calendar)
        #expect(ingresos.fijos.contains { $0.clave.comercio != nil }, "El fixture no trae un fijo por comercio")
        #expect(ingresos.fijos.contains { $0.clave.comercio == nil }, "El fixture no trae un fijo por grupo")
        #expect(!gastos.fijosAFuturo.isEmpty, "El fixture no trae gastos fijos a futuro")
        #expect(!gastos.aisladosVentana.isEmpty, "El fixture no trae aislados")
        Self.compararLosDosLados(historia, caso: "16 mil")
    }

    @Test(arguments: [UInt64(1), 2, 3, 4, 5])
    func paridad_conOtrasSemillas(semilla: UInt64) throws {
        let c = try Self.catalogo()
        Self.compararLosDosLados(Self.movimientos(c, semilla: semilla, cantidad: 1_500), caso: "semilla \(semilla)")
    }

    @Test func paridad_casosDeBorde() throws {
        let c = try Self.catalogo()
        // Sin historia, y sin primer mes.
        Self.compararLosDosLados([], caso: "vacío")
        Self.comparar(Self.movimientos(c, semilla: 9, cantidad: 300), esIngreso: false, primerMes: nil, caso: "sin primer mes")
        // Solo el mes en curso: la ventana queda vacía.
        Self.compararLosDosLados(Self.movimientos(c, semilla: 10, cantidad: 200, meses: 1), caso: "solo el mes en curso")
        // Historia corta (2 meses completos) y justo en el mínimo (3).
        Self.compararLosDosLados(Self.movimientos(c, semilla: 11, cantidad: 400, meses: 3), caso: "dos meses")
        Self.compararLosDosLados(Self.movimientos(c, semilla: 12, cantidad: 400, meses: 4), caso: "tres meses")
        // Todo sin nota, y todo con la misma nota.
        let sinNota = Self.movimientos(c, semilla: 13, cantidad: 800).map { m -> FlujoMotorMes.Movimiento in
            var copia = m
            copia.nota = nil
            return copia
        }
        Self.compararLosDosLados(sinNota, caso: "sin notas")
        let mismaNota = Self.movimientos(c, semilla: 14, cantidad: 800).map { m -> FlujoMotorMes.Movimiento in
            var copia = m
            copia.nota = "SQ *Bodega"
            return copia
        }
        Self.compararLosDosLados(mismaNota, caso: "una sola nota")
        // Todo sin categoría.
        let sinCategoria = Self.movimientos(c, semilla: 15, cantidad: 800).map { m -> FlujoMotorMes.Movimiento in
            var copia = FlujoMotorMes.Movimiento(
                mes: m.mes, importe: m.importe, esIngreso: m.esIngreso, categoriaID: nil, subcategoriaID: nil,
                categoria: nil, pagoID: m.pagoID, esFechado: m.esFechado)
            copia.dia = m.dia
            copia.nota = m.nota
            return copia
        }
        Self.compararLosDosLados(sinCategoria, caso: "sin categoría")
    }

    // MARK: - Testigos: una vez por grupo y una vez por nota

    @Test func elOrdenSeCalculaUnaVezPorGrupo_yElComercioUnaVezPorNota() throws {
        let c = try Self.catalogo()
        let historia = Self.movimientos(c, semilla: 16_004, cantidad: 16_000)
        let primero = Self.primerMes(historia)
        let ventana = Set((1...6).compactMap { Self.calendar.date(byAdding: .month, value: -$0, to: Self.mesEnCurso) })
        for esIngreso in [true, false] {
            let delLado = historia.filter { $0.esIngreso == esIngreso && !$0.enPagoProgramado && !$0.esFechado }
            let grupos = Set(delLado.filter { ventana.contains($0.mes) }.map { Self.nombre(FlujoProyeccionInteligente.base(de: $0)) })
            let notas = Set(delLado.filter { ventana.contains($0.mes) || $0.mes == Self.mesEnCurso }.compactMap(\.nota))
            FlujoProyeccionInteligente._testOrdenes = 0
            FlujoProyeccionInteligente._testComerciosCalculados = 0
            _ = FlujoProyeccionInteligente.detectar(
                esIngreso: esIngreso, historia: historia, primerMes: primero, mesEnCurso: Self.mesEnCurso,
                calendar: Self.calendar)
            let lado = esIngreso ? "ingresos" : "gastos"
            // Dos ordenaciones por lado como mucho (los grupos y, en gastos, los fijos a futuro): una vez por grupo cada una.
            #expect(FlujoProyeccionInteligente._testOrdenes <= 2 * grupos.count,
                    "\(lado): \(FlujoProyeccionInteligente._testOrdenes) órdenes para \(grupos.count) grupos")
            #expect(FlujoProyeccionInteligente._testComerciosCalculados <= notas.count,
                    "\(lado): \(FlujoProyeccionInteligente._testComerciosCalculados) comercios para \(notas.count) notas")
        }
    }

    // MARK: - Medición (informativa)

    private static func milisegundos(_ veces: Int = 3, _ bloque: () -> Void) -> Double {
        var mejor = Double.infinity
        for _ in 0..<veces {
            let inicio = ContinuousClock.now
            bloque()
            let d = ContinuousClock.now - inicio
            mejor = min(mejor, Double(d.components.seconds) * 1_000 + Double(d.components.attoseconds) / 1e15)
        }
        return mejor
    }

    @Test func medicion_antesYDespues() throws {
        let c = try Self.catalogo()
        let historia = Self.movimientos(c, semilla: 16_004, cantidad: 16_000)
        let primero = Self.primerMes(historia)
        let antes = Self.milisegundos {
            for esIngreso in [true, false] {
                _ = FlujoProyeccionInteligenteAntes.detectar(
                    esIngreso: esIngreso, historia: historia, primerMes: primero, mesEnCurso: Self.mesEnCurso,
                    calendar: Self.calendar)
            }
        }
        let despues = Self.milisegundos {
            for esIngreso in [true, false] {
                _ = FlujoProyeccionInteligente.detectar(
                    esIngreso: esIngreso, historia: historia, primerMes: primero, mesEnCurso: Self.mesEnCurso,
                    calendar: Self.calendar)
            }
        }
        // El motor entero, 13 meses (el flujo de caja de un año), con la detección nueva dentro.
        let meses = (0...12).compactMap { Self.calendar.date(byAdding: .month, value: $0 - 6, to: Self.mesEnCurso) }
        let entrada = FlujoMotorMes.Entrada(
            meses: meses, mesEnCurso: Self.mesEnCurso, quedanDiasEnElMes: true, lineas: [], limite: { _, _ in 0 },
            movimientos: historia, pendientes: [], calendar: Self.calendar)
        let motor = Self.milisegundos { _ = FlujoMotorMes.calcular(entrada) }
        let ids = historia.compactMap(\.subcategoriaID).prefix(1_000)
        let describir = Self.milisegundos(1) { for id in ids { _ = String(describing: id) } }
        print(String(format: "MEDICION: detectar (dos lados, 16k) antes %.1f ms · después %.1f ms · motor del mes 13 meses %.1f ms · String(describing:) de 1000 ids %.1f ms",
                     antes, despues, motor, describir))
        #expect(despues.isFinite && antes.isFinite)
    }

    /// Para Time Profiler (`TEST_RUNNER_YALA_PERFIL_PROYECCION=1`): 6 s de la detección de antes y 6 s de la de ahora,
    /// por separado, para que la traza los distinga. Sin la variable no corre.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["YALA_PERFIL_PROYECCION"] == "1"))
    func perfil_detectarEnBucle() throws {
        let c = try Self.catalogo()
        let historia = Self.movimientos(c, semilla: 16_004, cantidad: 16_000)
        let primero = Self.primerMes(historia)
        func bucle(_ cuerpo: () -> Void) -> Int {
            let fin = ContinuousClock.now + .seconds(6)
            var vueltas = 0
            while ContinuousClock.now < fin { cuerpo(); vueltas += 1 }
            return vueltas
        }
        let antes = bucle {
            for esIngreso in [true, false] {
                _ = FlujoProyeccionInteligenteAntes.detectar(
                    esIngreso: esIngreso, historia: historia, primerMes: primero, mesEnCurso: Self.mesEnCurso,
                    calendar: Self.calendar)
            }
        }
        let despues = bucle {
            for esIngreso in [true, false] {
                _ = FlujoProyeccionInteligente.detectar(
                    esIngreso: esIngreso, historia: historia, primerMes: primero, mesEnCurso: Self.mesEnCurso,
                    calendar: Self.calendar)
            }
        }
        // Y el motor entero del flujo de caja (13 meses), para ver qué queda fuera de la detección.
        let meses = (0...12).compactMap { Self.calendar.date(byAdding: .month, value: $0 - 6, to: Self.mesEnCurso) }
        let entrada = FlujoMotorMes.Entrada(
            meses: meses, mesEnCurso: Self.mesEnCurso, quedanDiasEnElMes: true, lineas: [], limite: { _, _ in 0 },
            movimientos: historia, pendientes: [], calendar: Self.calendar)
        let motor = bucle { _ = FlujoMotorMes.calcular(entrada) }
        print("MEDICION: vueltas en 6 s · antes \(antes) · después \(despues) · motor \(motor)")
        #expect(antes > 0 && despues > 0)
    }
}
