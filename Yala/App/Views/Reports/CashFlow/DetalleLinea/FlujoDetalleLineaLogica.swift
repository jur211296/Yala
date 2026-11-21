//
//  FlujoDetalleLineaLogica.swift
//  Yala
//
//  Lo que cuenta el detalle de una línea del flujo de caja (S3 del replanteo, 18-nov-2026; decisiones en el «Paso 0» del
//  encargo `2026-11-18-flujo-detalle-de-linea`):
//  - los registros del mes que el reparto del motor (`FlujoMotorMes.Dueños`) da a ESA línea, por día, con el mismo
//    alcance de cuentas que su cifra: la lista suma lo que dice la línea;
//  - si sigue al ritmo (solo gastos del mes en curso);
//  - seis meses de real contra límite, con el mismo reparto y el mismo cálculo del límite que el motor
//    (`CashFlowProjectionCalculator.resolvePlanned`), aunque el plan guarde menos meses atrás;
//  - el período con el que «Ver en Registros» abre ese mes.
//

import Foundation
import SwiftData

enum FlujoDetalleLineaLogica {

    // MARK: - Registros de la línea

    /// Un registro de la línea con lo que suma a ella (con signo del lado: en un gasto, lo gastado es positivo y una
    /// devolución, negativa), ya en la divisa del plan.
    struct Registro {
        let transaction: TransactionItem
        let importe: Double
        /// Fechado de mañana en adelante: aún no es real.
        let esFechado: Bool
    }

    /// Un día de la lista, con sus registros y lo que suman a la línea.
    struct Dia: Identifiable {
        let fecha: Date
        let registros: [Registro]
        var total: Double { registros.reduce(0) { $0 + $1.importe } }
        /// El día es de mañana en adelante.
        var esProgramado: Bool { registros.allSatisfy(\.esFechado) }
        var id: Date { fecha }
    }

    /// Los registros que el reparto de dueños da a `lineID` en el mes que empieza en `mes`, del más reciente al más
    /// antiguo. `lineas` va en el orden del plan (con dos líneas para lo mismo gana la primera, como en el motor).
    static func registros(
        de lineID: UUID,
        mes: Date,
        lineas: [FlujoMotorMes.Linea],
        transactions: [TransactionItem],
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment,
        converter: any CurrencyConverting,
        now: Date,
        calendar: Calendar
    ) -> [Registro] {
        guard let intervalo = calendar.dateInterval(of: .month, for: mes) else { return [] }
        let dueños = FlujoMotorMes.Dueños(lineas: lineas)
        let startOfTomorrow = LiveBalanceCalculator.TodayCutoff(asOf: now, calendar: calendar).startOfTomorrow
        var result: [Registro] = []
        for tx in transactions {
            // Las mismas puertas que `FlujoMotorMesEntrada.movimientos`: sin ajustes de saldo ni transferencias, sin la
            // pata de préstamo de un gasto de grupo. Y sin lo ya borrado (puede seguir en la lista que llega).
            guard !tx.isDeleted, tx.modelContext != nil,
                  tx.date >= intervalo.start, tx.date < intervalo.end,
                  tx.balanceAdjustmentType == nil, !adjustment.isSuppressed(tx) else { continue }
            let esIngreso = TransactionClassificationLogic.isIncome(tx)
            guard case .linea(let dueño) = dueños.dueño(
                esIngreso: esIngreso,
                categoriaID: tx.category?.persistentModelID,
                subcategoriaID: tx.subcategory?.persistentModelID,
                pagoID: tx.scheduledPaymentID.flatMap(UUID.init(uuidString:))
            ), dueño == lineID else { continue }
            let value = CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            ).value
            result.append(Registro(
                transaction: tx, importe: esIngreso ? value : -value, esFechado: tx.date >= startOfTomorrow
            ))
        }
        return result.sorted { $0.transaction.date > $1.transaction.date }
    }

    /// Los registros agrupados por día, del más reciente al más antiguo.
    static func dias(_ registros: [Registro], calendar: Calendar) -> [Dia] {
        var orden: [Date] = []
        var porDia: [Date: [Registro]] = [:]
        for registro in registros {
            let dia = calendar.startOfDay(for: registro.transaction.date)
            if porDia[dia] == nil { orden.append(dia) }
            porDia[dia, default: []].append(registro)
        }
        return orden.sorted(by: >).map { Dia(fecha: $0, registros: porDia[$0] ?? []) }
    }

    // MARK: - Ritmo

    enum Ritmo: Equatable {
        /// Lo real y lo fechado pasan del límite: cuenta lo que hay y no proyecta más (P2).
        case excedida(porCuanto: Double)
        /// Al ritmo de lo que va del mes, lo gastado llegaría a `llegarias` a fin de mes.
        case alRitmo(llegarias: Double, sePasa: Bool)
        /// Sin frase: ingresos (llegan en bloque), un mes que no es el actual o nada gastado todavía.
        case ninguno
    }

    /// El ritmo de un gasto en el mes en curso: lo real dividido por los días que van, por los días del mes.
    static func ritmo(
        real: Double, limite: Double, isExceeded: Bool, esIngreso: Bool, esMesActual: Bool,
        realMasFechado: Double, now: Date, calendar: Calendar
    ) -> Ritmo {
        guard !esIngreso, esMesActual else { return .ninguno }
        if isExceeded { return .excedida(porCuanto: max(0, realMasFechado - limite)) }
        guard real > 0,
              let diasDelMes = calendar.range(of: .day, in: .month, for: now)?.count else { return .ninguno }
        let diasQueVan = calendar.component(.day, from: now)
        guard diasQueVan > 0 else { return .ninguno }
        let llegarias = real / Double(diasQueVan) * Double(diasDelMes)
        return .alRitmo(llegarias: llegarias, sePasa: llegarias > limite + 0.005)
    }

    // MARK: - Seis meses

    struct MesHistoria: Identifiable, Equatable {
        let mes: Date
        let monthKey: String
        /// Lo real de la línea en el mes (fechado antes de mañana).
        let real: Double
        let limite: Double
        let esActual: Bool
        /// El mes quedó fuera del límite del mes que se ve por aislado (19-nov-2026).
        var esAislado: Bool = false
        /// La moneda del límite y su tasa del mes, si el límite se convierte (encargo del 2026-11-20): el globo de la
        /// barra la dice.
        var tasa: TasaDelMes?
        var id: String { monthKey }
        /// Lo real menos el límite: en un gasto, positivo es pasarse.
        var diferencia: Double { real - limite }
    }

    /// La tasa con que se convirtió el límite de un mes.
    struct TasaDelMes: Equatable {
        let moneda: String
        let tasa: FlujoTasaDelMes.Tasa
    }

    /// Lo pagado en la moneda del límite (con signo del lado), si TODO lo registrado del mes en la línea está en esa
    /// moneda. `nil` si no hay nada o algo está en otra moneda: entonces no se puede comparar en el original.
    static func pagadoEnMoneda(_ moneda: String, registros: [Registro]) -> Double? {
        let reales = registros.filter { !$0.esFechado }
        guard !reales.isEmpty, reales.allSatisfy({ $0.transaction.currencyCode == moneda }) else { return nil }
        return reales.reduce(0) { total, registro in
            let nativo = abs(registro.transaction.amount)
            return total + (registro.importe >= 0 ? nativo : -nativo)
        }
    }

    /// Lo que se pasó del límite solo por el tipo de cambio: lo pagado en la moneda del límite no pasa del original, pero
    /// convertido sí. `nil` si no es el caso (no hay original, no se pasó, o se pasó también en el original).
    static func excesoPorTipoDeCambio(
        real: Double, limite: Double, original: FlujoLimiteEnMoneda.Original?, pagadoEnOriginal: Double?
    ) -> (exceso: Double, justo: Bool)? {
        guard let original, let pagado = pagadoEnOriginal, real - limite >= 0.005,
              pagado <= original.monto + 0.005 else { return nil }
        return (real - limite, abs(pagado - original.monto) < 0.005)
    }

    /// Los seis meses y cómo sale el límite del mes que se ve.
    struct Historia {
        let meses: [MesHistoria]
        /// `nil` si el límite del mes no sale de un método que mira la historia (monto fijo, un ajuste, un cambio
        /// «desde», un pago planificado).
        let explicacion: CashFlowProjectionCalculator.LimitEstimate?
        /// El índice del límite, para las cifras de cada método en «Cálculo del monto».
        let indice: TransactionIndex
        /// El mes con que se calcula el límite del mes que se ve (el mismo, o el en curso si es un mes que viene).
        let referencia: Date
    }

    /// Los seis meses que acaban en `hasta` y cómo sale el límite de `hasta` (si es un método que mira la historia),
    /// con los meses que se dejaron fuera por aislados marcados en la gráfica.
    static func historia(
        line: CashFlowLine,
        lineasPlan: [CashFlowLine],
        transactions: [TransactionItem],
        historia: [TransactionItem],
        hasta: Date,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment,
        converter: any CurrencyConverting,
        now: Date,
        calendar: Calendar
    ) -> Historia? {
        guard let actual = calendar.dateInterval(of: .month, for: now)?.start,
              let pedido = calendar.dateInterval(of: .month, for: hasta)?.start else { return nil }
        let lineas = ordenDelPlan(lineasPlan).map { FlujoMotorMesEntrada.linea($0) }
        let index = indiceDelLimite(
            lineas: lineas, historia: historia, currencyCode: currencyCode, adjustment: adjustment,
            converter: converter, now: now, calendar: calendar
        )
        let referencia = min(pedido, actual)
        let explicacion = explicacion(
            line: line, monthKey: CashFlowProjectionCalculator.monthKey(for: pedido, calendar: calendar),
            referencia: referencia, index: index, calendar: calendar
        )
        let aislados = Set(explicacion?.isolatedMonths ?? [])
        let meses = seisMeses(
            line: line, lineasPlan: lineasPlan, transactions: transactions, historia: historia, hasta: hasta,
            currencyCode: currencyCode, adjustment: adjustment, converter: converter, now: now, calendar: calendar,
            index: index
        ).map { mes in
            var marcado = mes
            marcado.esAislado = aislados.contains(mes.mes)
            return marcado
        }
        return Historia(meses: meses, explicacion: explicacion, indice: index, referencia: referencia)
    }

    /// Cómo sale el límite de la línea en el mes, si sale de su método y el método mira la historia. Un ajuste de un
    /// mes o un cambio «desde» mandan sobre el método (`resolvePlanned`): ahí no hay promedio que explicar.
    static func explicacion(
        line: CashFlowLine, monthKey: String, referencia: Date, index: TransactionIndex, calendar: Calendar
    ) -> CashFlowProjectionCalculator.LimitEstimate? {
        guard line.monthOverride(for: monthKey) == nil,
              CashFlowAmountChangeLogic.change(for: monthKey, in: line.amountChanges) == nil else { return nil }
        switch line.method {
        case .average3m, .average6m, .average12m, .lastMonth, .trend:
            return CashFlowProjectionCalculator.explainEstimate(
                method: line.method, line: line, referenceDate: referencia, index: index, calendar: calendar
            )
        default:
            return nil
        }
    }

    /// El texto de «Cómo se calcula» del mes: el método, su ventana y los meses que se dejaron fuera por aislados; o
    /// «Monto fijo desde noviembre», o «Monto fijo: el mismo número cada mes». `nil` para lo que ya explica la
    /// descripción del método (un pago planificado, meses elegidos a mano).
    static func comoSeCalcula(
        line: CashFlowLine, explicacion: CashFlowProjectionCalculator.LimitEstimate?, cambioDesde: Date?
    ) -> String? {
        if let cambioDesde {
            return L10n.FlujoDetalleLinea.comoFijoDesde(CashFlowMonthSummaryLogic.monthInSentence(cambioDesde))
        }
        if let explicacion {
            let aislados = L10n.FlujoDetalleLinea.listaDeMeses(explicacion.isolatedMonths)
            switch explicacion.method {
            case .average3m, .average6m, .average12m:
                guard !explicacion.usedMonths.isEmpty else { return L10n.FlujoDetalleLinea.comoSinDatos }
                let meses = explicacion.method == .average3m ? 3 : explicacion.method == .average6m ? 6 : 12
                return L10n.FlujoDetalleLinea.comoPromedio(meses: meses, aislados: aislados)
            case .lastMonth:
                guard let mes = explicacion.usedMonths.first else { return L10n.FlujoDetalleLinea.comoSinDatos }
                return L10n.FlujoDetalleLinea.comoUltimoMes(
                    CashFlowMonthSummaryLogic.monthInSentence(mes), aislados: aislados
                )
            case .trend:
                return L10n.FlujoDetalleLinea.comoTendencia(aislados: aislados)
            default:
                return nil
            }
        }
        return line.method == .manual ? L10n.FlujoDetalleLinea.comoFijo : nil
    }

    /// «Cómo se calcula» de un límite que no sale de tus registros (encargo del 2026-11-20): «Suma de 4 pagos + S/ 30
    /// extra. Se actualiza solo cuando cambias un pago.» o «Monto fijo de 500.00 USD cada mes. En PEN sube y baja con el
    /// tipo de cambio.». `nil` si el límite no sale de ahí.
    static func comoSeCalcula(
        desglose: FlujoLimiteEnMoneda.Resultado?, monedaPlan: String, formato: (Double) -> String
    ) -> String? {
        guard let desglose else { return nil }
        if desglose.pagos.isEmpty, desglose.extra == nil, let original = desglose.original {
            return L10n.FlujoDetalleLinea.comoFijoEnMoneda(
                FlujoMonedaTexto.original(original.monto, moneda: original.moneda), monedaPlan: monedaPlan
            )
        }
        let cuantos = desglose.pagos.filter { $0.estado != .noEsta }.count
        let suma = L10n.FlujoDetalleLinea.calculoSumaPagos(cuantos, extra: desglose.extra.map(formato))
        return "\(suma) \(L10n.FlujoDetalleLinea.calculoSeActualiza)"
    }

    /// El índice con que el motor calcula los límites (`CashFlowProjectionCalculator.calculate`): por categoría y
    /// subcategoría, y lo que el reparto de dueños da a cada línea.
    static func indiceDelLimite(
        lineas: [FlujoMotorMes.Linea],
        historia: [TransactionItem],
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment,
        converter: any CurrencyConverting,
        now: Date,
        calendar: Calendar
    ) -> TransactionIndex {
        let startOfTomorrow = LiveBalanceCalculator.TodayCutoff(asOf: now, calendar: calendar).startOfTomorrow
        let movHistoria = FlujoMotorMesEntrada.movimientos(
            historia, currencyCode: currencyCode, adjustment: adjustment, converter: converter,
            startOfTomorrow: startOfTomorrow, calendar: calendar
        ).movimientos
        var index = TransactionIndex(movimientos: movHistoria, calendar: calendar)
        index.byLineMonth = FlujoMotorMes.importesPorLinea(movHistoria, lineas: lineas).mapValues { byMonth in
            Dictionary(byMonth.map { (CashFlowProjectionCalculator.monthKey(for: $0.key, calendar: calendar), $0.value) },
                       uniquingKeysWith: +)
        }
        return index
    }

    /// Los seis meses que acaban en `hasta` (sin pasar del mes en curso): real de la línea contra su límite.
    /// `real` sale de `transactions` (el alcance del saldo, como la cifra del mes); el límite, de toda la historia
    /// (`historia`), como en el motor.
    static func seisMeses(
        line: CashFlowLine,
        lineasPlan: [CashFlowLine],
        transactions: [TransactionItem],
        historia: [TransactionItem],
        hasta: Date,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment,
        converter: any CurrencyConverting,
        now: Date,
        calendar: Calendar,
        index indiceDado: TransactionIndex? = nil
    ) -> [MesHistoria] {
        guard let actual = calendar.dateInterval(of: .month, for: now)?.start,
              let pedido = calendar.dateInterval(of: .month, for: hasta)?.start else { return [] }
        let ultimo = min(pedido, actual)
        let meses: [Date] = (0..<6).reversed().compactMap { calendar.date(byAdding: .month, value: -$0, to: ultimo) }

        let startOfTomorrow = LiveBalanceCalculator.TodayCutoff(asOf: now, calendar: calendar).startOfTomorrow
        let lineas = ordenDelPlan(lineasPlan).map { FlujoMotorMesEntrada.linea($0) }
        let reales = FlujoMotorMesEntrada.movimientos(
            transactions, currencyCode: currencyCode, adjustment: adjustment, converter: converter,
            startOfTomorrow: startOfTomorrow, calendar: calendar
        ).movimientos.filter { !$0.esFechado }
        let realPorMes = FlujoMotorMes.importesPorLinea(reales, lineas: lineas)[line.id] ?? [:]

        // El índice del límite, como en `CashFlowProjectionCalculator.calculate`.
        let index = indiceDado ?? indiceDelLimite(
            lineas: lineas, historia: historia, currencyCode: currencyCode, adjustment: adjustment,
            converter: converter, now: now, calendar: calendar
        )

        // Los pagos y las tasas de los seis meses, leídos una vez (encargo del 2026-11-20).
        let usaFuentes = CashFlowProjectionCalculator.needsLimitSources(line, currencyCode: currencyCode)
        let fuentes = usaFuentes ? FlujoLimiteEnMoneda.Fuentes.deLinea(
            line, meses: meses, monedaPlan: currencyCode, converter: converter, hoy: now, calendar: calendar
        ) : nil

        return meses.map { mes in
            let key = CashFlowProjectionCalculator.monthKey(for: mes, calendar: calendar)
            let resuelto = CashFlowProjectionCalculator.resolvePlanned(
                line: line, monthKey: key, monthDate: mes, currentMonthStart: actual, index: index,
                currencyCode: currencyCode, converter: converter, fuentes: fuentes, calendar: calendar
            )
            var tasa: TasaDelMes?
            if let fuentes, !resuelto.isOverride, resuelto.changeFromMonthKey == nil,
               let desglose = FlujoLimiteEnMoneda.resultado(
                line: line, mes: mes, monedaPlan: currencyCode, fuentes: fuentes, calendar: calendar
               ), !desglose.sinNada, desglose.monedasExtranjeras.count == 1,
               let moneda = desglose.monedasExtranjeras.first, let tasaMes = desglose.tasa {
                tasa = TasaDelMes(moneda: moneda, tasa: tasaMes)
            }
            return MesHistoria(
                mes: mes, monthKey: key, real: realPorMes[mes] ?? 0, limite: resuelto.amount, esActual: mes == actual,
                tasa: tasa
            )
        }
    }

    /// Las líneas activas en el orden del plan, como las reparte el motor.
    static func ordenDelPlan(_ lineas: [CashFlowLine]) -> [CashFlowLine] {
        lineas.filter(\.isEnabled).sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
    }

    // MARK: - Categoría madre

    /// Lo anotado en la categoría madre sin subcategoría en el mes, si la línea es por subcategoría (el aviso). `nil`
    /// si no hay nada o la línea no es por subcategoría.
    static func anotadoEnLaMadre(lineID: UUID, esPorSubcategoria: Bool, grupos: [CashFlowCategoryGroup]) -> Double? {
        guard esPorSubcategoria,
              let grupo = grupos.first(where: { $0.lineIDs.contains(lineID) }),
              abs(grupo.unassignedAmount) >= 0.005 else { return nil }
        return grupo.unassignedAmount
    }

    // MARK: - Ver en Registros

    /// El período con que Registros enseña el mes: «Este mes», «Mes pasado» o ese mes como rango propio (cerrado en
    /// 23:59:59, `CLAUDE.md` · «Cálculos con fechas»).
    static func periodoDeRegistros(mes: Date, now: Date, calendar: Calendar) -> (period: DetailPeriod, range: DateInterval?) {
        guard let intervalo = calendar.dateInterval(of: .month, for: mes),
              let actual = calendar.dateInterval(of: .month, for: now)?.start else { return (.thisMonth, nil) }
        if intervalo.start == actual { return (.thisMonth, nil) }
        if let anterior = calendar.date(byAdding: .month, value: -1, to: actual), intervalo.start == anterior {
            return (.lastMonth, nil)
        }
        let fin = calendar.date(byAdding: .second, value: -1, to: intervalo.end) ?? intervalo.end
        return (.custom, DateInterval(start: intervalo.start, end: fin))
    }
}
