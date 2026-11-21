//
//  SaludFinancieraDetalleMuestra.swift
//  Yala
//
//  Los seis estados de las maquetas de la hoja de Salud financiera (artifact «Salud financiera en tres secciones»,
//  20-nov-2026), para los XCUITest y las capturas: `-uitest-salud-estado <estado>` con `-uitest`. Pinta la nota y los
//  datos de la muestra en vez de leer el almacén. Solo DEBUG: en producción no existe.
//

#if DEBUG
import Foundation

enum SaludFinancieraDetalleMuestra {

    enum Estado: String, CaseIterable {
        case bien, excedido, noalcanza, sinpres, sinpagos, sinpro
    }

    static let argumento = "-uitest-salud-estado"

    /// La muestra pedida por el lanzamiento, si la hay.
    static var actual: (score: FinancialScore, datos: SaludFinancieraDetalleCargador.Datos)? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uitest"), let i = args.firstIndex(of: argumento), i + 1 < args.count,
              let estado = Estado(rawValue: args[i + 1]) else { return nil }
        return muestra(estado)
    }

    static func muestra(
        _ estado: Estado, now: Date = .now, calendar: Calendar = .current
    ) -> (score: FinancialScore, datos: SaludFinancieraDetalleCargador.Datos) {
        typealias L = SaludFinancieraDetalleLogica
        let hoy = calendar.startOfDay(for: now)
        let mes = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: hoy, duration: 30 * 86_400)
        let finDeMes = mes.end.addingTimeInterval(-1)
        func dia(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: hoy) ?? hoy }
        // Los pagos caen entre hoy y el último día del mes, para que la muestra no dependa del día en que corre.
        let restantes = max(0, calendar.dateComponents([.day], from: hoy, to: calendar.startOfDay(for: finDeMes)).day ?? 0)
        func enElMes(_ fraccion: Double) -> Int { Int((Double(restantes) * fraccion).rounded()) }

        func presupuesto(_ nombre: String, icono: String, color: String, gastado: Double, limite: Double,
                         historial: [Double] = [], recortes: [(String, Double)] = []) -> L.Presupuesto {
            L.Presupuesto(id: UUID(), nombre: nombre, icono: icono, color: color, gastado: gastado, limite: limite,
                          moneda: "PEN", historial: historial,
                          dondeMasPesa: recortes.map { L.Recorte(nombre: $0.0, monto: $0.1, filtro: .ninguno) })
        }
        let dentro = [
            presupuesto("Supermercado", icono: "cart.fill", color: "34C759", gastado: 820.50, limite: 1200),
            presupuesto("Comidas fuera", icono: "fork.knife", color: "FF9F0A", gastado: 612.30, limite: 1000),
            presupuesto("Transporte", icono: "car.fill", color: "0A84FF", gastado: 180, limite: 350),
        ]
        let pasado = [
            presupuesto("Comidas fuera", icono: "fork.knife", color: "FF9F0A", gastado: 1120.40, limite: 1000,
                        historial: [1210, 1185, 980, 1345],
                        recortes: [("Delivery", 412.30), ("Restaurantes", 386.10), ("Cafés", 148)]),
            presupuesto("Supermercado", icono: "cart.fill", color: "34C759", gastado: 820.50, limite: 1200),
            presupuesto("Transporte", icono: "car.fill", color: "0A84FF", gastado: 180, limite: 350),
        ]

        func pago(_ nombre: String, _ offset: Int, _ monto: Double) -> L.Pago {
            L.Pago(id: UUID(), nombre: nombre, fecha: dia(offset), dias: offset, monto: monto, moneda: "PEN",
                   montoConvertido: monto, esAproximado: false)
        }
        let pagosBien = [pago("Gimnasio Smart Fit", enElMes(0.3), 180), pago("Spotify", enElMes(0.6), 26.90),
                         pago("Alquiler", restantes, 2230)]
        let pagosJustos = [pago("Luz del Sur", -1, 142.60), pago("Tarjeta Visa BCP", enElMes(0.2), 6120),
                           pago("Gimnasio Smart Fit", enElMes(0.5), 180), pago("Spotify", enElMes(0.7), 26.90),
                           pago("Alquiler", restantes, 2230)]
        let dinero = 7850.0
        let racha = L.racha(diasConMovimiento: Set((0..<23).map { dia(-$0) }), now: now, calendar: calendar)
        let rachaSinHoy = L.racha(diasConMovimiento: Set((1...6).map { dia(-$0) }), now: now, calendar: calendar)

        var datos = SaludFinancieraDetalleCargador.Datos(
            presupuestos: dentro, pagos: pagosBien,
            comparacion: L.comparacion(pagos: pagosBien, dineroHoy: dinero, moneda: "PEN"),
            dineroHoy: dinero, tienePagos: true, racha: racha, esPro: true, finDeMes: finDeMes
        )
        var score = FinancialScore(total: 91, budget: 92, activity: 100, bills: 84)

        switch estado {
        case .bien:
            break
        case .excedido, .sinpro:
            datos.presupuestos = pasado
            datos.esPro = estado == .excedido
            datos.tarjetaIA = estado == .excedido ? L.TarjetaIA(
                texto: "Tus pedidos de delivery subieron 38 % frente al mes pasado, sobre todo viernes y sábado.",
                consejo: "Con un tope de dos pedidos por fin de semana ahorrarías unos S/ 180 al mes."
            ) : nil
            score = FinancialScore(total: 78, budget: 58, activity: 100, bills: 84)
        case .noalcanza:
            datos.pagos = pagosJustos
            datos.comparacion = L.comparacion(pagos: pagosJustos, dineroHoy: dinero, moneda: "PEN")
            datos.ingresos = [L.IngresoEsperado(nombre: "Sueldo", fecha: dia(enElMes(0.8)), monto: 4500,
                                                moneda: "PEN")]
            datos.racha = rachaSinHoy
            score = FinancialScore(total: 66, budget: 92, activity: 85, bills: 22)
        case .sinpres:
            datos.presupuestos = []
            datos.categoriaSugerida = .init(nombre: "Comidas fuera", promedioMensual: 1050, moneda: "PEN")
            score = FinancialScore(total: 91, budget: nil, activity: 100, bills: 84)
        case .sinpagos:
            datos.pagos = []
            datos.comparacion = nil
            datos.tienePagos = false
            datos.cobrosQueSeRepiten = ["Spotify", "Netflix", "Gimnasio Smart Fit"]
            score = FinancialScore(total: 95, budget: 92, activity: 100, bills: nil)
        }
        return (score, datos)
    }
}
#endif
