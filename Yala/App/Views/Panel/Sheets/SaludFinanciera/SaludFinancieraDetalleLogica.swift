//
//  SaludFinancieraDetalleLogica.swift
//  Yala
//
//  La hoja de la nota de salud, visual y accionable (pedido de Jürgen del 17-nov-2026: «pésimo, nada de valor añadido,
//  puro texto que nadie leerá»). Aquí vive lo que no es pantalla: qué alertas salen y en qué orden, cómo va cada
//  presupuesto, qué pagos vienen y si el saldo los cubre, la racha de días registrando y qué hacer para subir la nota.
//
//  No hay cálculos nuevos de dinero: lo gastado de un presupuesto es el de Planificación
//  (`BudgetsViewModel.calculateSpending` en `BudgetPeriodInterval.current`), su estado el de `BudgetStatusCounter`, y la
//  cobertura de los pagos es «Al 30 tendrías» del Panel (`MonthEndBalanceLogic`). La nota no se recalcula: la hoja
//  recibe la del Panel.
//

import Foundation

enum SaludFinancieraDetalleLogica {

    // MARK: - Piezas

    /// Un presupuesto con su barra.
    struct Presupuesto: Equatable, Identifiable {
        let id: UUID
        let nombre: String
        let icono: String
        /// Color del presupuesto en hex, el de su fila en Planificación.
        let color: String
        let gastado: Double
        let limite: Double
        let moneda: String

        var porcentaje: Double { limite > 0 ? gastado / limite * 100 : 0 }
        var estado: BudgetCounterStatus { BudgetStatusCounter.classify(spent: gastado, limit: limite) }
        /// Lo que queda (negativo: lo que se pasó), con la regla de «Te quedan / Te pasaste por».
        var restante: Double { BudgetRemainingLogic.remaining(limit: limite, spent: gastado) }
    }

    /// Un pago planificado que viene.
    struct Pago: Equatable, Identifiable {
        let id: UUID
        let nombre: String
        let fecha: Date
        /// Días de calendario desde hoy: 0 hoy, 1 mañana, negativo si ya venció.
        let dias: Int
        let monto: Double
        let moneda: String
    }

    /// «Al 30 de noviembre tendrías»: lo que dice el Panel, para saber si el saldo cubre lo que falta pagar.
    struct Cobertura: Equatable {
        let alCierre: Double
        let faltaSalir: Double
        let fechaCierre: Date
        let moneda: String
        let esAproximada: Bool

        var cubre: Bool { alCierre >= 0 || CurrencyFormattingHelper.isShownAsZero(alCierre) }
    }

    /// Días seguidos registrando y la tira de los últimos días.
    struct Racha: Equatable {
        /// Días seguidos con algún movimiento, contando desde hoy (o desde ayer si hoy aún no hay).
        let dias: Int
        /// Los últimos `diasEnTira` días, del más antiguo a hoy: `true` si ese día hay movimiento.
        let tira: [Bool]
        let registroHoy: Bool
    }

    enum Alerta: Equatable, Identifiable {
        case presupuestoPasado(Presupuesto)
        case presupuestoAlLimite(Presupuesto)
        /// Dos o más al límite van en una sola fila: la lista de presupuestos de abajo ya dice cuáles.
        case presupuestosAlLimite([Presupuesto])
        case cuentaEnRojo(nombre: String, cuentaID: UUID?)
        case pagoVencido(Pago)
        case pagosSinCubrir(Cobertura)

        var id: String {
            switch self {
            case .presupuestoPasado(let p): "pasado-\(p.id)"
            case .presupuestoAlLimite(let p): "limite-\(p.id)"
            case .presupuestosAlLimite: "limites"
            case .cuentaEnRojo(let nombre, let id): "cuenta-\(id?.uuidString ?? nombre)"
            case .pagoVencido(let p): "vencido-\(p.id)"
            case .pagosSinCubrir: "cobertura"
            }
        }

        /// Pasarse o no llegar a fin de mes pesa más que acercarse al límite.
        var esGrave: Bool {
            switch self {
            case .presupuestoAlLimite, .presupuestosAlLimite: false
            default: true
            }
        }
    }

    /// Un paso para subir la nota.
    enum Paso: String, Equatable, Identifiable {
        case crearPresupuesto
        case registrarHoy
        case agregarPagos
        case revisarPresupuestos
        case revisarRitmo
        case revisarPagos

        var id: String { rawValue }

        /// La parte de la nota que mueve, para decir cuánto pesa.
        var parte: FinancialScoreDetailKind {
            switch self {
            case .crearPresupuesto, .revisarPresupuestos: .budget
            case .registrarHoy, .revisarRitmo: .activity
            case .agregarPagos, .revisarPagos: .bills
            }
        }
    }

    // MARK: - Constantes

    /// Los días que pinta la tira de la racha.
    static let diasEnTira = 14
    /// Hasta cuántos días por delante salen los próximos pagos.
    static let horizontePagos = 14
    /// Cuántos pagos y presupuestos se enseñan antes de «Ver todos».
    static let maximoPagos = 3
    static let maximoPresupuestos = 4
    static let maximoPasos = 2

    // MARK: - Presupuestos

    /// Primero los que van peor: pasados, al límite, y luego por lo gastado. Empate, por nombre.
    static func ordenar(_ presupuestos: [Presupuesto]) -> [Presupuesto] {
        presupuestos.sorted { a, b in
            let ra = rango(a.estado), rb = rango(b.estado)
            if ra != rb { return ra < rb }
            if a.porcentaje != b.porcentaje { return a.porcentaje > b.porcentaje }
            return a.nombre.localizedStandardCompare(b.nombre) == .orderedAscending
        }
    }

    private static func rango(_ estado: BudgetCounterStatus) -> Int {
        switch estado {
        case .overLimit: 0
        case .reachedLimit: 1
        case .atLimit: 2
        case .onTrack: 3
        }
    }

    // MARK: - Pagos

    /// Los pagos de gasto activos que vencieron o vencen en los próximos `horizontePagos` días, del más cercano al más
    /// lejano. Se cuenta la fecha que el pago tiene pendiente (`nextDueDate`), salvo que la persona la haya saltado.
    static func proximosPagos(
        _ pagos: [(id: UUID, nombre: String, fecha: Date, monto: Double, moneda: String, esGasto: Bool, activo: Bool,
                   saltado: Bool)],
        now: Date,
        calendar: Calendar
    ) -> [Pago] {
        let hoy = calendar.startOfDay(for: now)
        return pagos
            .filter { $0.activo && $0.esGasto && !$0.saltado }
            .compactMap { pago -> Pago? in
                let dia = calendar.startOfDay(for: pago.fecha)
                guard let dias = calendar.dateComponents([.day], from: hoy, to: dia).day,
                      dias <= horizontePagos else { return nil }
                return Pago(id: pago.id, nombre: pago.nombre, fecha: pago.fecha, dias: dias, monto: pago.monto,
                            moneda: pago.moneda)
            }
            .sorted { a, b in
                if a.fecha != b.fecha { return a.fecha < b.fecha }
                return a.nombre.localizedStandardCompare(b.nombre) == .orderedAscending
            }
    }

    // MARK: - Racha

    /// La racha a partir de los días con algún movimiento. Si hoy aún no hay, cuenta desde ayer: la racha sigue viva
    /// hasta que termina el día.
    static func racha(diasConMovimiento: Set<Date>, now: Date, calendar: Calendar) -> Racha {
        let hoy = calendar.startOfDay(for: now)
        let dias = Set(diasConMovimiento.map { calendar.startOfDay(for: $0) })
        let registroHoy = dias.contains(hoy)

        var cuenta = 0
        var cursor: Date? = registroHoy ? hoy : calendar.date(byAdding: .day, value: -1, to: hoy)
        while let dia = cursor, dias.contains(dia) {
            cuenta += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: dia)
        }

        let tira: [Bool] = (0..<diasEnTira).reversed().map { atras in
            guard let dia = calendar.date(byAdding: .day, value: -atras, to: hoy) else { return false }
            return dias.contains(dia)
        }
        return Racha(dias: cuenta, tira: tira, registroHoy: registroHoy)
    }

    // MARK: - Alertas

    /// Lo que hay que mirar hoy, lo grave primero: pasarse de un presupuesto, no llegar a fin de mes con los pagos,
    /// un pago vencido y una cuenta en negativo; después, los presupuestos al límite (en una sola fila si son varios). En «Solo gastos» no hay saldos
    /// que valgan: ni cuentas en rojo ni cobertura.
    static func alertas(
        presupuestos: [Presupuesto],
        pagos: [Pago],
        cobertura: Cobertura?,
        cuentasEnRojo: [(nombre: String, id: UUID?)],
        isExpensesOnlyMode: Bool
    ) -> [Alerta] {
        let ordenados = ordenar(presupuestos)
        let pasados = ordenados.filter { $0.estado == .overLimit }.map(Alerta.presupuestoPasado)
        let enElLimite = ordenados.filter { $0.estado == .atLimit || $0.estado == .reachedLimit }
        let alLimite: [Alerta] = switch enElLimite.count {
        case 0: []
        case 1: [.presupuestoAlLimite(enElLimite[0])]
        default: [.presupuestosAlLimite(enElLimite)]
        }
        let vencidos = pagos.filter { $0.dias < 0 }.map(Alerta.pagoVencido)
        let sinCubrir: [Alerta] = {
            guard !isExpensesOnlyMode, let cobertura, cobertura.faltaSalir > 0, !cobertura.cubre else { return [] }
            return [.pagosSinCubrir(cobertura)]
        }()
        let cuentas: [Alerta] = isExpensesOnlyMode
            ? []
            : cuentasEnRojo.map { Alerta.cuentaEnRojo(nombre: $0.nombre, cuentaID: $0.id) }
        return pasados + sinCubrir + vencidos + cuentas + alLimite
    }

    // MARK: - Para subir la nota

    /// Hasta `maximoPasos` cosas concretas, la que más mueve la nota primero. Lo que falta para tener nota va antes que
    /// lo que la mejora: sin presupuestos o sin pagos, esa parte no cuenta.
    static func pasos(
        score: FinancialScore,
        tienePresupuestos: Bool,
        tienePagos: Bool,
        racha: Racha
    ) -> [Paso] {
        var pasos: [Paso] = []
        if score.budget == nil && !tienePresupuestos { pasos.append(.crearPresupuesto) }
        if !racha.registroHoy && (score.activity ?? 0) < 100 { pasos.append(.registrarHoy) }
        if score.bills == nil && !tienePagos { pasos.append(.agregarPagos) }

        switch FinancialScoreCalculator.weakestPart(of: score) {
        case .budget: pasos.append(.revisarPresupuestos)
        case .activity: if !pasos.contains(.registrarHoy) { pasos.append(.revisarRitmo) }
        case .bills: pasos.append(.revisarPagos)
        case .total, nil: break
        }
        return Array(pasos.prefix(maximoPasos))
    }
}
