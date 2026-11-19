//
//  FlujoLimitesMovilesMigracion.swift
//  Yala
//
//  Límites móviles (decisión de Jürgen del 19-nov-2026, 10:21; corrige en parte el P4 del replanteo): las líneas con
//  Promedio 6 meses, Promedio 3 meses o Último mes se recalculan cada mes con los meses anteriores a ese mes; solo
//  «Monto fijo» deja un número quieto.
//
//  Entre el 18-nov (22:54) y esta decisión, crear el plan y «Agregar línea» guardaban la línea por promedio como monto
//  fijo con la cifra del promedio (P4). Solo lo tienen las builds de TestFlight de 2.3: la 2.2 no traía el P4. Esta
//  pasada, una vez por dispositivo, devuelve esas líneas a su método. Cómo las reconoce (Paso 0 del encargo, punto 4, y la
//  review adversarial): su plan se creó en la ventana del P4 y antes de este arranque, y es una línea en monto fijo, con categoría o subcategoría, sin pago, sin cambios «desde» ni ajustes de un mes, cuyo monto
//  coincide al céntimo con lo que su promedio de 6 meses, de 3 meses o el último mes daba con la regla de antes (sin
//  quitar aislados) en el mes en curso. Un monto que la persona escribió casi nunca coincide al céntimo con un promedio;
//  si no coincide, se queda fijo: lo seguro es no tocar lo que no se reconoce.
//

import Foundation
import SwiftData

enum FlujoLimitesMovilesMigracion {

    static let defaultsKey = "cashFlow.movingLimitsMigration.v1"

    /// Cuándo pudo sembrar el P4: desde que se mergeó (18-nov-2026, 22:54 en Lima) hasta dos semanas después, el margen
    /// para que quien tenía una build de TestFlight con el P4 actualice. Un plan creado fuera de la ventana no tiene
    /// líneas sembradas: un monto fijo de 2.2 que coincide con su promedio (un alquiler constante) es una elección.
    nonisolated static let ventanaP4: DateInterval = {
        let inicio = Date(timeIntervalSince1970: 1_795_060_440)   // 2026-11-19 03:54 UTC
        return DateInterval(start: inicio, duration: 14 * 86_400)
    }()

    /// Cuándo arrancó este proceso: un plan creado después ya no pudo sembrarlo el P4, aunque esté en la ventana (en esta
    /// build, elegir «Monto fijo» rellena el campo con el promedio y guardaría la misma cifra). Se lee del sistema, no de
    /// la primera vez que se pide: la primera pasada puede llegar justo después de crear el plan. Si no se puede leer,
    /// `distantPast`: no se migra nada, que es lo seguro.
    nonisolated static let arranque: Date = {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return .distantPast }
        let inicio = info.kp_proc.p_un.__p_starttime
        guard inicio.tv_sec > 0 else { return .distantPast }
        return Date(timeIntervalSince1970: Double(inicio.tv_sec) + Double(inicio.tv_usec) / 1_000_000)
    }()

    /// Los métodos que el P4 sembraba como monto fijo, en el orden en que se prueban.
    static let metodosSembrados: [EstimationMethod] = [.average6m, .average3m, .lastMonth]

    /// El método con que el P4 sembró esta línea, o `nil` si su monto fijo no es uno sembrado.
    /// `indice`: el de las sugerencias del plan (por categoría y subcategoría, sin el reparto de dueños), el mismo con
    /// que se calculó la cifra sembrada.
    @MainActor
    static func metodoSembrado(
        line: CashFlowLine, indice: TransactionIndex, mesEnCurso: Date, calendar: Calendar,
        ventana: DateInterval = ventanaP4, creadoAntesDe: Date = arranque
    ) -> EstimationMethod? {
        guard let creado = line.plan?.createdAt, ventana.contains(creado), creado < creadoAntesDe,
              line.method == .manual, line.scheduledPayment == nil,
              line.category != nil || line.subcategory != nil,
              (line.amountChangesRaw ?? "").isEmpty, line.shownMonthOverrides.isEmpty,
              let monto = line.manualAmount, monto > 0 else { return nil }
        return metodosSembrados.first { metodo in
            let antes = CashFlowProjectionCalculator.explainEstimate(
                method: metodo, line: line, referenceDate: mesEnCurso, index: indice, calendar: calendar,
                excludesIsolated: false
            ).amount
            return abs(antes - monto) < 0.005
        }
    }

    /// Devuelve a su método las líneas sembradas. Devuelve cuántas cambiaron; la llamada guarda.
    @MainActor
    static func migrar(
        lines: [CashFlowLine], indice: TransactionIndex, mesEnCurso: Date, calendar: Calendar,
        ventana: DateInterval = ventanaP4, creadoAntesDe: Date = arranque
    ) -> Int {
        var cambiadas = 0
        for line in lines where !line.isDeleted {
            guard let metodo = metodoSembrado(
                line: line, indice: indice, mesEnCurso: mesEnCurso, calendar: calendar,
                ventana: ventana, creadoAntesDe: creadoAntesDe
            ) else { continue }
            line.estimationMethod = metodo.rawValue
            line.manualAmount = nil
            cambiadas += 1
        }
        return cambiadas
    }
}

extension CashFlowPlanViewModel {

    /// La pasada de límites móviles, una vez por dispositivo (`FlujoLimitesMovilesMigracion`). La llama `recalculate`
    /// antes de calcular, con los mismos movimientos.
    func migrarLimitesSembradosSiHaceFalta(
        transactions: [TransactionItem], currencyCode: String, defaults: UserDefaults = .standard,
        now: Date = .now, calendar: Calendar = .current
    ) {
        guard !defaults.bool(forKey: FlujoLimitesMovilesMigracion.defaultsKey),
              // Con los movimientos aún sin cargar no se reconoce nada: se espera a la pasada con datos.
              !transactions.isEmpty, let plan, !(plan.lines ?? []).isEmpty, let ctx = plan.modelContext,
              let mesEnCurso = calendar.dateInterval(of: .month, for: now)?.start else { return }
        // El mismo índice que las sugerencias del plan (`generateSuggestions`): con categoría, sin ajustes de saldo y
        // sin subcategorías de sistema, «mi parte» de los gastos de grupo.
        let validas = transactions.filter {
            $0.category != nil && $0.balanceAdjustmentType == nil && $0.subcategory?.isAnySystem != true
        }
        let indice = TransactionIndex(
            transactions: validas, currencyCode: currencyCode.isEmpty ? "USD" : currencyCode,
            adjustment: GroupBridgeStatsAdjustment.build(from: transactions, context: ctx),
            converter: CurrencyConverter.shared, calendar: calendar
        )
        let cambiadas = FlujoLimitesMovilesMigracion.migrar(
            lines: plan.lines ?? [], indice: indice, mesEnCurso: mesEnCurso, calendar: calendar
        )
        if cambiadas > 0 {
            do {
                try ctx.save()
                Self.announcePlanChange(ctx)
            } catch {
                #if DEBUG
                print("CashFlowPlanViewModel: Error migrando límites sembrados: \(error)")
                #endif
                return
            }
        }
        defaults.set(true, forKey: FlujoLimitesMovilesMigracion.defaultsKey)
    }
}
