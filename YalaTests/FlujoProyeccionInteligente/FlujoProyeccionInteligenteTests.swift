//
//  FlujoProyeccionInteligenteTests.swift
//  YalaTests
//
//  Proyección inteligente del flujo de caja (decisión de Jürgen del 19-nov-2026, corrige P6 del replanteo; ticket
//  `2026-11-19-flujo-proyeccion-inteligente`): los ingresos fijos detectados en los registros se proyectan sin plan ni
//  línea, y los montos aislados (un iPhone de S/ 6,000 una sola vez) no mueven lo que se proyecta para los meses que
//  vienen. Sobre el motor del mes (`FlujoMotorMes.calcular`) sin líneas, con el «ahora» en noviembre de 2026 en Lima.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · proyección inteligente (fijos y aislados)", .serialized)
struct FlujoProyeccionInteligenteTests {

    // MARK: - Fixture

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }()

    private static func mes(_ year: Int, _ month: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    private static let noviembre = mes(2026, 11)
    private static let diciembre = mes(2026, 12)
    private static let enero = mes(2027, 1)

    private struct Categorias {
        let sueldo: YalaCategory
        let freelance: YalaCategory
        let comida: YalaCategory
        let tecnologia: YalaCategory
        let viajes: YalaCategory
    }

    private static func categorias() throws -> Categorias {
        let context = try makeTestContext()
        func cat(_ name: String, income: Bool = false) -> YalaCategory {
            let category = YalaCategory(name: name, colorHex: "#000000", isIncome: income)
            context.insert(category)
            return category
        }
        let result = Categorias(
            sueldo: cat("Sueldo", income: true), freelance: cat("Freelance", income: true), comida: cat("Comida"),
            tecnologia: cat("Tecnología"), viajes: cat("Viajes")
        )
        try context.save()
        return result
    }

    /// Un movimiento del motor: `importe` positivo es lo que suma a su lado (lo gastado en un gasto).
    private static func mov(
        _ mes: Date, _ importe: Double, ingreso: Bool = false, _ categoria: YalaCategory?, dia: Int = 10,
        nota: String? = nil, pago: UUID? = nil, fechado: Bool = false
    ) -> FlujoMotorMes.Movimiento {
        var movimiento = FlujoMotorMes.Movimiento(
            mes: mes, importe: importe, esIngreso: ingreso, categoriaID: categoria?.persistentModelID,
            subcategoriaID: nil, categoria: categoria, pagoID: pago, esFechado: fechado
        )
        movimiento.dia = dia
        movimiento.nota = nota
        return movimiento
    }

    private static func entrada(
        _ movimientos: [FlujoMotorMes.Movimiento], pendientes: [FlujoMotorMes.Pendiente] = []
    ) -> FlujoMotorMes.Entrada {
        FlujoMotorMes.Entrada(
            meses: [noviembre, diciembre, enero], mesEnCurso: noviembre, quedanDiasEnElMes: true, lineas: [],
            limite: { _, _ in 0 }, movimientos: movimientos, pendientes: pendientes, calendar: calendar
        )
    }

    /// Mayo a octubre de 2026 (los 6 meses completos antes de noviembre).
    private static let ventana = (5...10).map { mes(2026, $0) }

    private static func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }

    // MARK: - Sueldo fijo sin plan

    /// Sueldo de 3,000 los días 30 de mayo a octubre (con un mes de 3,100 y uno cobrado el 1): se proyecta en diciembre
    /// y enero aunque no haya plan ni línea, y en noviembre, que aún no lo cobró, falta entero, el día 30.
    @Test func sueldoFijo_seProyectaSinPlan() throws {
        let c = try Self.categorias()
        var movs: [FlujoMotorMes.Movimiento] = []
        for (i, mes) in Self.ventana.enumerated() {
            movs.append(Self.mov(mes, i == 2 ? 3_100 : 3_000, ingreso: true, c.sueldo, dia: i == 4 ? 1 : 30))
            movs.append(Self.mov(mes, 800, c.comida))
        }
        let meses = FlujoMotorMes.calcular(Self.entrada(movs))
        let nov = try #require(meses.first { $0.esEnCurso })
        let dic = try #require(meses.first { $0.inicio == Self.diciembre })

        let fijo = try #require(nov.ingresos.deteccion.fijos.first)
        #expect(nov.ingresos.deteccion.fijos.count == 1)
        #expect(Self.near(fijo.monto, 3_000))
        #expect(fijo.dia == 30)
        #expect(fijo.unaVezAlMes)
        #expect(fijo.mesesVistos == 6)

        #expect(Self.near(nov.ingresos.resto, 3_000), "Noviembre aún no cobró: falta el sueldo entero")
        #expect(nov.ingresos.faltaPorDia == [30: 3_000], "Se dibuja el día 30, no repartido")
        #expect(Self.near(nov.ingresos.faltaRepartible, 0))
        #expect(Self.near(dic.ingresos.total, 3_000))
        #expect(Self.near(dic.gastos.total, 800), "Los gastos siguen por la mediana")
    }

    /// Con el sueldo de noviembre ya cobrado (un poco menos, como un sueldo en dólares a otra tasa), noviembre no
    /// proyecta otra vez ni la diferencia.
    @Test func sueldoFijo_yaCobradoEsteMes_noSeCuentaDosVeces() throws {
        let c = try Self.categorias()
        var movs = Self.ventana.map { Self.mov($0, 3_000, ingreso: true, c.sueldo, dia: 30) }
        movs.append(Self.mov(Self.noviembre, 2_950, ingreso: true, c.sueldo, dia: 15))
        let nov = try #require(FlujoMotorMes.calcular(Self.entrada(movs)).first { $0.esEnCurso })
        #expect(Self.near(nov.ingresos.otros.falta, 0), "Ya llegó: no se proyectan los 50 de diferencia")
        #expect(Self.near(nov.ingresos.total, 2_950))
        #expect(Self.near(nov.ingresos.otros.fijos.first?.cobrado ?? 0, 2_950))
    }

    /// El sueldo de este mes anotado sin categoría (o en otra subcategoría) es el mismo sueldo: no se proyecta otra vez.
    /// Uno de otra categoría (Freelance) no lo es.
    @Test func sueldoDeEsteMes_conOtraBase_seReconoce() throws {
        let c = try Self.categorias()
        let historia = Self.ventana.map { Self.mov($0, 3_000, ingreso: true, c.sueldo, dia: 30) }
        let sinCategoria = historia + [Self.mov(Self.noviembre, 3_000, ingreso: true, nil, dia: 18)]
        let nov = try #require(FlujoMotorMes.calcular(Self.entrada(sinCategoria)).first { $0.esEnCurso })
        #expect(Self.near(nov.ingresos.resto, 0), "El cobro sin categoría es el sueldo: \(nov.ingresos.resto)")
        let freelance = historia + [Self.mov(Self.noviembre, 3_000, ingreso: true, c.freelance, dia: 18)]
        let novF = try #require(FlujoMotorMes.calcular(Self.entrada(freelance)).first { $0.esEnCurso })
        #expect(Self.near(novF.ingresos.resto, 3_000), "Freelance no es el sueldo: el sueldo sigue faltando")
    }

    /// El sueldo que llega el día 1 y se pagó el 28 del mes anterior (feriado) no se proyecta otra vez.
    @Test func sueldoAdelantadoAFinDeMes_noSeCuentaDosVeces() throws {
        let c = try Self.categorias()
        var movs = Self.ventana.map { Self.mov($0, 3_000, ingreso: true, c.sueldo, dia: 1) }
        movs.append(Self.mov(Self.noviembre, 3_000, ingreso: true, c.sueldo, dia: 1))
        movs.append(Self.mov(Self.noviembre, 3_000, ingreso: true, c.sueldo, dia: 28, fechado: true))
        let meses = FlujoMotorMes.calcular(Self.entrada(movs))
        let dic = try #require(meses.first { $0.inicio == Self.diciembre })
        let ene = try #require(meses.first { $0.inicio == Self.enero })
        #expect(Self.near(dic.ingresos.total, 0), "Diciembre ya se cobró el 28 de noviembre: \(dic.ingresos.total)")
        #expect(Self.near(ene.ingresos.total, 3_000))
    }

    /// Un sueldo que bajó el último mes (otro trabajo) se proyecta al nivel nuevo, no al viejo.
    @Test func sueldoQueBajo_seProyectaAlNivelNuevo() throws {
        let c = try Self.categorias()
        let montos: [Double] = [3_000, 3_000, 3_000, 3_000, 3_000, 2_000]
        let movs = zip(Self.ventana, montos).map { Self.mov($0, $1, ingreso: true, c.sueldo, dia: 30) }
        let dic = try #require(FlujoMotorMes.calcular(Self.entrada(movs)).first { $0.inicio == Self.diciembre })
        #expect(Self.near(dic.ingresos.total, 2_000))
    }

    /// Un sueldo que faltó el último mes completo ya no se proyecta, y un reembolso chico en «Sueldo» no lo revive.
    @Test func sueldoQueFaltoElUltimoMes_oSoloUnReembolso_noSeProyecta() throws {
        let c = try Self.categorias()
        let hastaSeptiembre = Self.ventana.prefix(5).map { Self.mov($0, 3_000, ingreso: true, c.sueldo, dia: 30) }
        let dic = try #require(FlujoMotorMes.calcular(Self.entrada(hastaSeptiembre)).first { $0.inicio == Self.diciembre })
        #expect(dic.ingresos.deteccion.fijos.isEmpty)
        let conReembolso = Self.ventana.prefix(4).map { Self.mov($0, 3_000, ingreso: true, c.sueldo, dia: 30) }
            + [Self.mov(Self.noviembre, 50, ingreso: true, c.sueldo, dia: 5)]
        let dicR = try #require(FlujoMotorMes.calcular(Self.entrada(conReembolso)).first { $0.inicio == Self.diciembre })
        #expect(dicR.ingresos.deteccion.fijos.isEmpty)
        #expect(Self.near(dicR.ingresos.total, 0))
    }

    /// Un sueldo que cae en una cuenta que no suma en el saldo no se proyecta en ese saldo: la detección de ingresos
    /// mira lo que cuenta para la cifra, no toda la historia.
    @Test func sueldoEnUnaCuentaQueNoSuma_noSeProyecta() throws {
        let c = try Self.categorias()
        let comida = Self.ventana.map { Self.mov($0, 800, c.comida) }
        let sueldo = Self.ventana.map { Self.mov($0, 3_000, ingreso: true, c.sueldo, dia: 30) }
        let entrada = FlujoMotorMes.Entrada(
            meses: [Self.noviembre, Self.diciembre], mesEnCurso: Self.noviembre, quedanDiasEnElMes: true, lineas: [],
            limite: { _, _ in 0 }, movimientos: comida, pendientes: [], calendar: Self.calendar,
            historia: comida + sueldo
        )
        let dic = try #require(FlujoMotorMes.calcular(entrada).last)
        #expect(dic.ingresos.deteccion.fijos.isEmpty)
        #expect(Self.near(dic.ingresos.total, 0))
        #expect(Self.near(dic.gastos.total, 800))
    }

    /// Un ingreso que se dejó de cobrar (mayo a agosto y nada en septiembre ni octubre) ya no es fijo.
    @Test func ingresoQueSeDejoDeCobrar_noSeProyecta() throws {
        let c = try Self.categorias()
        let movs = Self.ventana.prefix(4).map { Self.mov($0, 3_000, ingreso: true, c.sueldo, dia: 30) }
        let dic = try #require(FlujoMotorMes.calcular(Self.entrada(movs)).first { $0.inicio == Self.diciembre })
        #expect(dic.ingresos.deteccion.fijos.isEmpty)
        #expect(Self.near(dic.ingresos.total, 0))
    }

    /// Un cliente fijo por comercio dentro de «Freelance»: el grupo entero varía, la nota «ACME» se repite.
    @Test func ingresoFijoPorComercio_dentroDeUnGrupoQueVaria() throws {
        let c = try Self.categorias()
        var movs: [FlujoMotorMes.Movimiento] = []
        // El grupo: 1,600 · 2,100 · 2,700 · 3,700 · 1,900 · 3,200 ⇒ solo 3 meses dentro del ±25 % de su mediana.
        let sueltos: [Double] = [400, 900, 1_500, 2_500, 700, 2_000]
        for (i, mes) in Self.ventana.enumerated() {
            movs.append(Self.mov(mes, 1_200, ingreso: true, c.freelance, dia: 5, nota: "Pago ACME S.A."))
            movs.append(Self.mov(mes, sueltos[i], ingreso: true, c.freelance, nota: "Cliente \(i)"))
        }
        let dic = try #require(FlujoMotorMes.calcular(Self.entrada(movs)).first { $0.inicio == Self.diciembre })
        let fijo = try #require(dic.ingresos.deteccion.fijos.first)
        #expect(dic.ingresos.deteccion.fijos.count == 1)
        #expect(fijo.clave.comercio != nil)
        #expect(fijo.comercioVisible == "Pago ACME S.A.")
        #expect(Self.near(dic.ingresos.total, 1_200), "Solo el cliente fijo: lo que varía no se proyecta")
    }

    // MARK: - Aislados

    /// Un iPhone de 6,000 en agosto, en una categoría sin otros gastos: aislado. Sin él, diciembre proyecta lo que se
    /// gasta en un mes normal (la mediana de 800..900), no la de agosto con el iPhone dentro.
    @Test func iPhoneAislado_noMueveLaProyeccion() throws {
        let c = try Self.categorias()
        let comida: [Double] = [800, 900, 850, 820, 880, 870]
        var movs = zip(Self.ventana, comida).map { Self.mov($0, $1, c.comida) }
        movs.append(Self.mov(Self.mes(2026, 8), 6_000, c.tecnologia, nota: "iPhone"))
        let meses = FlujoMotorMes.calcular(Self.entrada(movs))
        let dic = try #require(meses.first { $0.inicio == Self.diciembre })

        let aislado = try #require(dic.gastos.deteccion.aisladosVentana.first)
        #expect(dic.gastos.deteccion.aisladosVentana.count == 1)
        #expect(Self.near(aislado.importe, 6_000))
        #expect(aislado.mes == Self.mes(2026, 8))
        // Sin el iPhone: [800, 820, 850, 870, 880, 900] ⇒ 860. Con él, agosto sería 6,820 y la mediana 875.
        #expect(Self.near(dic.gastos.deteccion.variable, 860))
        #expect(Self.near(dic.gastos.total, 860))
        #expect(Self.near(FlujoMotorMes.medianaDeOtros(Self.entrada(movs)), 875), "Control: la mediana cruda sí lo ve")
    }

    /// Con dos meses de historia el iPhone tiraba de la mediana a la mitad del mes con él; con tres meses ya se aparta.
    @Test func iPhoneAislado_conTresMeses_seApartaYLaMedianaNoLoVe() throws {
        let c = try Self.categorias()
        var movs = [8, 9, 10].map { Self.mov(Self.mes(2026, $0), 900, c.comida) }
        movs.append(Self.mov(Self.mes(2026, 10), 6_000, c.tecnologia))
        let dic = try #require(FlujoMotorMes.calcular(Self.entrada(movs)).first { $0.inicio == Self.diciembre })
        #expect(dic.gastos.deteccion.aisladosVentana.count == 1)
        #expect(Self.near(dic.gastos.total, 900))
    }

    /// Un gasto grande que se repite (un viaje de 2,000 en junio y otro de 1,800 en septiembre) no es aislado: entra.
    @Test func gastoQueSeRepite_entraEnLaProyeccion() throws {
        let c = try Self.categorias()
        var movs = Self.ventana.map { Self.mov($0, 500, c.comida) }
        movs.append(Self.mov(Self.mes(2026, 6), 2_000, c.viajes))
        movs.append(Self.mov(Self.mes(2026, 9), 1_800, c.viajes))
        let dic = try #require(FlujoMotorMes.calcular(Self.entrada(movs)).first { $0.inicio == Self.diciembre })
        #expect(dic.gastos.deteccion.aisladosVentana.isEmpty, "Se repite: no es aislado")
        // Meses: 500, 2,500, 500, 500, 2,300, 500 ⇒ mediana 500. Sigue en la mediana, que decide igual que antes.
        #expect(Self.near(dic.gastos.deteccion.variable, FlujoMotorMes.medianaDeOtros(Self.entrada(movs))))
    }

    /// Una suscripción mensual que «otros» paga cada mes forma parte de lo que se gasta en un mes normal: entra.
    @Test func gastoMensualQueSeRepite_entraEnLaMediana() throws {
        let c = try Self.categorias()
        var movs = Self.ventana.map { Self.mov($0, 400, c.comida) }
        movs += Self.ventana.map { Self.mov($0, 1_500, nil, dia: 3, nota: "Alquiler") }
        let dic = try #require(FlujoMotorMes.calcular(Self.entrada(movs)).first { $0.inicio == Self.diciembre })
        #expect(Self.near(dic.gastos.total, 1_900))
        #expect(dic.gastos.deteccion.fijos.isEmpty, "En gastos no se parte por grupos")
    }

    /// Un iPhone comprado este mes cuenta en noviembre, pero no se come lo que falta por gastar del resto del mes.
    @Test func iPhoneDeEsteMes_cuentaEnElMes_yNoSeComeLoQueFalta() throws {
        let c = try Self.categorias()
        var movs = Self.ventana.map { Self.mov($0, 900, c.comida) }
        movs.append(Self.mov(Self.noviembre, 300, c.comida))
        movs.append(Self.mov(Self.noviembre, 6_000, c.tecnologia, nota: "iPhone"))
        let nov = try #require(FlujoMotorMes.calcular(Self.entrada(movs)).first { $0.esEnCurso })
        #expect(Self.near(nov.gastos.real, 6_300), "El iPhone es real en su mes")
        #expect(Self.near(nov.gastos.otros.falta, 600), "Faltan 900 − 300 de lo demás; antes, cero")
        #expect(nov.gastos.otros.aislados.count == 1)
    }

    /// Un iPhone comprado y devuelto este mes: ni la compra ni la devolución mueven lo que falta del resto.
    @Test func iPhoneCompradoYDevueltoEsteMes_noInflaLoQueFalta() throws {
        let c = try Self.categorias()
        var movs = Self.ventana.map { Self.mov($0, 900, c.comida) }
        movs.append(Self.mov(Self.noviembre, 400, c.comida))
        movs.append(Self.mov(Self.noviembre, 6_000, c.tecnologia, dia: 3))
        movs.append(Self.mov(Self.noviembre, -6_000, c.tecnologia, dia: 10))
        let nov = try #require(FlujoMotorMes.calcular(Self.entrada(movs)).first { $0.esEnCurso })
        #expect(Self.near(nov.gastos.otros.falta, 500), "900 − 400; la devolución no suma 6,000: \(nov.gastos.otros.falta)")
    }

    /// Un iPhone de agosto devuelto en septiembre: septiembre no queda como un mes de −6,000 en la mediana.
    @Test func iPhoneDevueltoElMesSiguiente_noHundeLaMediana() throws {
        let c = try Self.categorias()
        var movs = Self.ventana.map { Self.mov($0, 900, c.comida) }
        movs.append(Self.mov(Self.mes(2026, 8), 6_000, c.tecnologia))
        movs.append(Self.mov(Self.mes(2026, 9), -6_000, c.tecnologia))
        let dic = try #require(FlujoMotorMes.calcular(Self.entrada(movs)).first { $0.inicio == Self.diciembre })
        #expect(Self.near(dic.gastos.deteccion.variable, 900))
        #expect(dic.gastos.deteccion.aisladosVentana.count == 1, "La devolución no se lista como aislado")
    }

    // MARK: - Sin doble conteo con pagos planificados

    /// El sueldo anotado a mano meses atrás y ahora planificado: el pago pendiente de diciembre lo cubre, y el sueldo de
    /// noviembre cobrado por su pago ya es el sueldo del mes.
    @Test func sueldoFijo_conPagoPlanificado_noSeCuentaDosVeces() throws {
        let c = try Self.categorias()
        let pago = UUID()
        var movs = Self.ventana.map { Self.mov($0, 3_000, ingreso: true, c.sueldo, dia: 30) }
        movs.append(Self.mov(Self.noviembre, 3_000, ingreso: true, c.sueldo, dia: 18, pago: pago))
        let pendiente = FlujoMotorMes.Pendiente(
            mes: Self.diciembre, pagoID: pago, categoriaID: c.sueldo.persistentModelID, subcategoriaID: nil,
            esIngreso: true, importe: 3_000
        )
        let meses = FlujoMotorMes.calcular(Self.entrada(movs, pendientes: [pendiente]))
        let nov = try #require(meses.first { $0.esEnCurso })
        let dic = try #require(meses.first { $0.inicio == Self.diciembre })
        let ene = try #require(meses.first { $0.inicio == Self.enero })
        #expect(Self.near(nov.ingresos.resto, 0), "Noviembre ya cobró por su pago")
        #expect(Self.near(dic.ingresos.total, 3_000), "Diciembre: el pago pendiente, una vez")
        #expect(Self.near(dic.ingresos.otros.faltaFijos, 0))
        #expect(Self.near(ene.ingresos.total, 3_000), "Enero sin pago pendiente: el fijo")
    }

    /// Una línea libre «Sueldo» (sin categoría) y el sueldo fijo de «otros» son el mismo dinero: cuenta una vez.
    @Test func lineaLibreDeIngresos_yElSueldoFijo_noSeSuman() throws {
        let c = try Self.categorias()
        let movs = Self.ventana.map { Self.mov($0, 3_000, ingreso: true, c.sueldo, dia: 30) }
        let libre = FlujoMotorMes.Linea(id: UUID(), esIngreso: true, categoriaID: nil, subcategoriaID: nil, pagoID: nil)
        let entrada = FlujoMotorMes.Entrada(
            meses: [Self.noviembre, Self.diciembre], mesEnCurso: Self.noviembre, quedanDiasEnElMes: true,
            lineas: [libre], limite: { _, _ in 3_000 }, movimientos: movs, pendientes: [], calendar: Self.calendar
        )
        let dic = try #require(FlujoMotorMes.calcular(entrada).last)
        #expect(Self.near(dic.ingresos.total, 3_000), "Una vez, no 6,000: \(dic.ingresos.total)")
        #expect(Self.near(dic.ingresos.otros.faltaFijos, 0))
        // Con una línea libre más chica que el fijo, el fijo pone lo que falta hasta su monto.
        let chica = FlujoMotorMes.Entrada(
            meses: [Self.noviembre, Self.diciembre], mesEnCurso: Self.noviembre, quedanDiasEnElMes: true,
            lineas: [libre], limite: { _, _ in 1_000 }, movimientos: movs, pendientes: [], calendar: Self.calendar
        )
        let dicChica = try #require(FlujoMotorMes.calcular(chica).last)
        #expect(Self.near(dicChica.ingresos.total, 3_000))
        #expect(Self.near(dicChica.ingresos.otros.faltaFijos, 2_000))
    }

    // MARK: - Historia corta

    /// Con dos meses completos no se detecta nada: ningún ingreso sin pago se proyecta y los gastos siguen por la
    /// mediana de todo, con el gasto grande dentro (lo conservador).
    @Test func historiaCorta_esConservadora() throws {
        let c = try Self.categorias()
        var movs = [9, 10].map { Self.mov(Self.mes(2026, $0), 3_000, ingreso: true, c.sueldo, dia: 30) }
        movs += [9, 10].map { Self.mov(Self.mes(2026, $0), 900, c.comida) }
        movs.append(Self.mov(Self.mes(2026, 10), 6_000, c.tecnologia))
        let dic = try #require(FlujoMotorMes.calcular(Self.entrada(movs)).first { $0.inicio == Self.diciembre })
        #expect(dic.ingresos.deteccion.detecta == false)
        #expect(dic.ingresos.deteccion.mesesDeHistoria == 2)
        #expect(dic.ingresos.deteccion.fijos.isEmpty)
        #expect(dic.gastos.deteccion.aisladosVentana.isEmpty)
        #expect(Self.near(dic.ingresos.total, 0))
        #expect(Self.near(dic.gastos.total, FlujoMotorMes.medianaDeOtros(Self.entrada(movs))))
        #expect(Self.near(dic.gastos.total, (900 + 6_900) / 2))
    }
}
