//
//  FlujoPagosDeLineaLogica.swift
//  Yala
//
//  Guardar los pagos de una línea «Pagos planificados» y el monto fijo en otra moneda, y lo que pasa cuando un pago deja
//  la línea (encargo del 2026-11-20, decisiones `seleccion`, `borrado`, `fijo` y `sync` de Jürgen):
//  - un pago está en UNA línea: elegirlo en otra lo quita de la primera;
//  - una línea que se queda sin pagos ni extra pasa a «Monto fijo» con el límite que tenía ese mes, y su detalle lo dice
//    una vez (aviso local, `FlujoAvisoPagoQuitado`);
//  - `scheduledPayment` guarda siempre el primer pago y `manualAmount` el límite convertido del mes, para que una versión
//    anterior de la app vea una línea de un pago y un monto fijo en la moneda del flujo.
//

import Foundation
import SwiftData

enum FlujoPagosDeLineaLogica {

    // MARK: - Qué se puede elegir

    /// Un pago que se ofrece en la hoja: del lado de la línea, personal (los de grupo siguen el camino de hoy).
    static func ofrecible(_ pago: ScheduledPayment, esIngreso: Bool) -> Bool {
        !pago.isDeleted && pago.groupZoneID == nil
            && CashFlowLineSideLogic.scheduledPaymentMatchesSide(transactionType: pago.transactionType, isIncome: esIngreso)
    }

    /// Los pagos de la hoja, en orden: activos primero y por nombre.
    static func ordenados(_ pagos: [ScheduledPayment]) -> [ScheduledPayment] {
        pagos.sorted {
            if $0.isActive != $1.isActive { return $0.isActive }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// El buscador sale desde 8 pagos.
    static func muestraBuscador(_ cuantos: Int) -> Bool { cuantos >= 8 }

    /// Qué línea (otra que `lineID`) tiene ya cada pago, por id de pago.
    static func dueños(de lineas: [CashFlowLine], excepto lineID: UUID?) -> [UUID: CashFlowLine] {
        var result: [UUID: CashFlowLine] = [:]
        for linea in lineas where linea.id != lineID && !linea.isDeleted && linea.method == .scheduled {
            for id in linea.scheduledPaymentIDs where result[id] == nil { result[id] = linea }
        }
        return result
    }

    /// Si la línea puede ofrecer «Pagos planificados»: ya lo usa, o hay al menos un pago activo de su lado.
    static func ofreceMetodo(lineaUsaPagos: Bool, pagos: [ScheduledPayment], esIngreso: Bool) -> Bool {
        lineaUsaPagos || pagos.contains { $0.isActive && ofrecible($0, esIngreso: esIngreso) }
    }

    // MARK: - Guardar

    /// Guarda la línea con sus pagos (en orden) y el extra. Quita esos pagos de las otras líneas del plan y retira lo
    /// escrito encima del método (los cambios «desde» y el ajuste del mes que se ve), como `aplicarMetodo`.
    /// - Returns: las líneas de las que salió algún pago (para el aviso de la hoja).
    @discardableResult
    static func guardarPagos(
        line: CashFlowLine, ids: [UUID], extra: Double?, monthKey: String, mes: Date, monedaPlan: String,
        converter: any CurrencyConverting, hoy: Date = .now, calendar: Calendar = .current
    ) throws -> [CashFlowLine] {
        guard !line.isDeleted, let ctx = line.modelContext else { return [] }
        let lineas = (line.plan?.lines ?? []).filter { !$0.isDeleted }
        let dueños = dueños(de: lineas, excepto: line.id)
        var tocadas: [CashFlowLine] = []
        for id in ids {
            guard let otra = dueños[id], !tocadas.contains(where: { $0.id == otra.id }) else { continue }
            tocadas.append(otra)
        }
        // Todo lo que se va a leer, ANTES de tocar nada: si no se deja leer, se lanza con las líneas intactas.
        let pagos = try buscar(ids, en: ctx)
        _ = try buscar(Array(Set(tocadas.flatMap(\.scheduledPaymentIDs))), en: ctx)
        for otra in tocadas {
            try quitar(Set(ids), de: otra, mes: mes, monedaPlan: monedaPlan, converter: converter, hoy: hoy,
                   calendar: calendar, aviso: .movido(destino: line.name))
        }

        let ajustesDelMes = ((line.monthOverrides ?? []) + (line.overrides ?? [])).filter { $0.monthKey == monthKey }
        ajustesDelMes.forEach { ctx.delete($0) }
        if line.amountChangesRaw != nil { line.amountChangesRaw = nil }
        line.estimationMethod = EstimationMethod.scheduled.rawValue
        let raw = FlujoLimiteEnMoneda.serializeIDs(ids)
        if line.scheduledPaymentIDsRaw != raw { line.scheduledPaymentIDsRaw = raw }
        let extraVivo = extra.flatMap { $0 > 0 ? $0 : nil }
        if line.limitExtraAmount != extraVivo { line.limitExtraAmount = extraVivo }
        if line.limitCurrencyCode != nil { line.limitCurrencyCode = nil }
        if line.limitForeignAmount != nil { line.limitForeignAmount = nil }
        let primero = ids.lazy.compactMap { id in pagos.first { $0.id == id } }.first
        if line.scheduledPayment?.id != primero?.id { line.scheduledPayment = primero }
        line.manualAmount = limiteDelMes(line: line, mes: mes, monedaPlan: monedaPlan, converter: converter, hoy: hoy,
                                         calendar: calendar, pagos: pagos)
        try ctx.save()
        CashFlowPlanViewModel.announcePlanChange(ctx)
        return tocadas
    }

    /// Guarda un monto fijo en otra moneda: vale para todos los meses, así que retira los cambios «desde» y TODOS los
    /// ajustes de un mes (como el alcance «Todos los meses»). `manualAmount` guarda el convertido del mes que se ve.
    static func guardarFijoEnMoneda(
        line: CashFlowLine, monto: Double, moneda: String, mes: Date, monedaPlan: String,
        converter: any CurrencyConverting, hoy: Date = .now, calendar: Calendar = .current
    ) throws {
        guard !line.isDeleted, let ctx = line.modelContext, monto >= 0, monto.isFinite else { return }
        ((line.monthOverrides ?? []) + (line.overrides ?? [])).forEach { ctx.delete($0) }
        if line.amountChangesRaw != nil { line.amountChangesRaw = nil }
        line.estimationMethod = EstimationMethod.manual.rawValue
        line.limitCurrencyCode = moneda
        line.limitForeignAmount = monto
        if line.limitExtraAmount != nil { line.limitExtraAmount = nil }
        line.manualAmount = limiteDelMes(line: line, mes: mes, monedaPlan: monedaPlan, converter: converter, hoy: hoy,
                                         calendar: calendar)
        try ctx.save()
        CashFlowPlanViewModel.announcePlanChange(ctx)
    }

    /// El límite de la línea en el mes, con sus fuentes leídas en el acto (para `manualAmount` y los avisos).
    /// `pagos`: los ya leídos por quien llama, para no volver a leerlos (y no tomar una segunda lectura fallida por
    /// «no están»).
    static func limiteDelMes(
        line: CashFlowLine, mes: Date, monedaPlan: String, converter: any CurrencyConverting, hoy: Date,
        calendar: Calendar, pagos: [ScheduledPayment] = []
    ) -> Double {
        let fuentes = FlujoLimiteEnMoneda.Fuentes.construir(
            lines: [line], scheduledPayments: pagos, meses: [mes], monedaPlan: monedaPlan, converter: converter,
            hoy: hoy, calendar: calendar
        )
        guard let resultado = FlujoLimiteEnMoneda.resultado(
            line: line, mes: mes, monedaPlan: monedaPlan, fuentes: fuentes, calendar: calendar
        ), !resultado.sinNada else { return line.manualAmount ?? 0 }
        return resultado.monto
    }

    // MARK: - Un pago deja la línea

    /// Quita `ids` de la línea sin guardar. Si se queda sin pagos ni extra pasa a «Monto fijo» con el límite que tenía en
    /// `mes` (con esos pagos aún dentro) y deja el aviso; si le quedan, la relación pasa al primero que queda. Si los pagos
    /// no se dejan leer, lanza sin tocar la línea: con la lectura vacía dejaría la relación a `nil` y el límite a medias.
    static func quitar(
        _ ids: Set<UUID>, de line: CashFlowLine, mes: Date, monedaPlan: String, converter: any CurrencyConverting,
        hoy: Date, calendar: Calendar, aviso: FlujoAvisoPagoQuitado.Motivo
    ) throws {
        guard !line.isDeleted, let ctx = line.modelContext else { return }
        let actuales = line.scheduledPaymentIDs
        let quedan = actuales.filter { !ids.contains($0) }
        guard quedan.count != actuales.count else { return }
        let delMes = try buscar(actuales, en: ctx)
        let limiteAntes = limiteDelMes(line: line, mes: mes, monedaPlan: monedaPlan, converter: converter, hoy: hoy,
                                       calendar: calendar, pagos: delMes)
        let nombres = delMes.filter { ids.contains($0.id) }.map(\.name).sorted()
        let sinExtra = (line.limitExtraAmount ?? 0) <= 0
        if quedan.isEmpty && sinExtra {
            line.estimationMethod = EstimationMethod.manual.rawValue
            line.manualAmount = limiteAntes
            line.scheduledPaymentIDsRaw = nil
            line.scheduledPayment = nil
            FlujoAvisoPagoQuitado.apuntar(lineID: line.id, nombre: nombres.first ?? "", motivo: aviso, fijoEn: limiteAntes)
        } else {
            line.scheduledPaymentIDsRaw = FlujoLimiteEnMoneda.serializeIDs(quedan)
            let pagos = delMes.filter { quedan.contains($0.id) }
            line.scheduledPayment = quedan.lazy.compactMap { id in pagos.first { $0.id == id } }.first
            line.manualAmount = limiteDelMes(line: line, mes: mes, monedaPlan: monedaPlan, converter: converter, hoy: hoy,
                                             calendar: calendar, pagos: pagos)
            FlujoAvisoPagoQuitado.apuntar(lineID: line.id, nombre: nombres.first ?? "", motivo: aviso, fijoEn: nil)
        }
    }

    /// Lo llama el borrado de un pago planificado (`EntityDeletionService.deleteScheduledPayment`) ANTES de borrarlo: lo
    /// saca de toda línea que lo tenga. No guarda: guarda el borrado, en el mismo `save`. Si las líneas o los pagos no se
    /// dejan leer, LANZA y el borrado no sigue: un pago borrado a medias dejaría líneas con la relación vacía.
    static func alBorrarPago(
        _ pago: ScheduledPayment, context: ModelContext,
        monedaPlan: String = CurrencyDefaults.preferred(in: .standard).rawValue,
        converter: any CurrencyConverting = CurrencyConverter.shared, hoy: Date = .now, calendar: Calendar = .current
    ) throws {
        let id = pago.id
        let lineas = try context.fetch(FetchDescriptor<CashFlowLine>())
        let mes = calendar.dateInterval(of: .month, for: hoy)?.start ?? hoy
        let afectadas = lineas.filter { !$0.isDeleted && $0.scheduledPaymentIDs.contains(id) }
        // Una lectura de todos sus pagos ANTES del bucle: si falla, ninguna línea queda tocada.
        _ = try buscar(Array(Set(afectadas.flatMap(\.scheduledPaymentIDs))), en: context)
        for linea in afectadas {
            try quitar([id], de: linea, mes: mes, monedaPlan: monedaPlan, converter: converter, hoy: hoy,
                   calendar: calendar, aviso: .borrado)
        }
    }

    /// Los pagos de esos ids. Lanza si no se dejan leer: quien escribe con lo leído no puede tomar «no pude leer» por
    /// «no están». `_testThrowOnFetch` lo fuerza en las pruebas.
    static func buscar(_ ids: [UUID], en contexto: ModelContext) throws -> [ScheduledPayment] {
        guard !ids.isEmpty else { return [] }
        if _testThrowOnFetch { throw CocoaError(.coderReadCorrupt) }
        let descriptor = FetchDescriptor<ScheduledPayment>(predicate: #Predicate<ScheduledPayment> { ids.contains($0.id) })
        return try contexto.fetch(descriptor).filter { !$0.isDeleted }
    }

    nonisolated(unsafe) static var _testThrowOnFetch = false
}

// MARK: - El aviso de una vez

/// «Se borró el pago Renta. El límite quedó fijo en S/ 1.850.»: lo apunta quien quita el pago y lo enseña el detalle de
/// la línea una sola vez. Es de este teléfono (lo vio quien hizo el gesto); no viaja.
enum FlujoAvisoPagoQuitado {

    enum Motivo: Equatable {
        case borrado
        case movido(destino: String)
    }

    struct Aviso: Equatable, Codable {
        let nombre: String
        /// `nil` = el pago se fue a otra línea; si no, se borró.
        let destino: String?
        /// El límite con que la línea quedó fija; `nil` si le quedan pagos o extra.
        let fijoEn: Double?
    }

    static let clave = "cashFlow.paymentLeftLineNotices"
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    static func apuntar(lineID: UUID, nombre: String, motivo: Motivo, fijoEn: Double?) {
        var todos = leer()
        let destino: String?
        if case .movido(let otra) = motivo { destino = otra } else { destino = nil }
        todos[lineID.uuidString] = Aviso(nombre: nombre, destino: destino, fijoEn: fijoEn)
        escribir(todos)
    }

    /// El aviso de la línea, si hay; lo retira (sale una vez).
    static func consumir(lineID: UUID) -> Aviso? {
        var todos = leer()
        guard let aviso = todos.removeValue(forKey: lineID.uuidString) else { return nil }
        escribir(todos)
        return aviso
    }

    private static func leer() -> [String: Aviso] {
        guard let data = defaults.data(forKey: clave) else { return [:] }
        do {
            return try JSONDecoder().decode([String: Aviso].self, from: data)
        } catch {
            #if DEBUG
            print("FlujoAvisoPagoQuitado: Error leyendo: \(error)")
            #endif
            return [:]
        }
    }

    private static func escribir(_ todos: [String: Aviso]) {
        if todos.isEmpty { defaults.removeObject(forKey: clave); return }
        do {
            defaults.set(try JSONEncoder().encode(todos), forKey: clave)
        } catch {
            #if DEBUG
            print("FlujoAvisoPagoQuitado: Error guardando: \(error)")
            #endif
        }
    }
}
