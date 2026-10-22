//
//  TrendHistoryLogic.swift
//  Yala
//
//  Histórico de los últimos N períodos COMPLETOS anteriores al seleccionado —
//  el dato que alimenta la Rule TREND_SOSTENIDO del Trend Insight Card y el
//  contexto temporal del análisis con IA (ticket trends-insight-card-v2-bullets, D2).
//
//  Pure logic: intervalos y agregación sin SwiftData; el ViewModel le pasa los
//  importes ya clasificados.
//

import Foundation

/// Totales de un período del histórico. `income` y `expense` en positivo
/// (acumulación signed: un reembolso resta de su bucket).
struct TrendHistoryPoint: Equatable {
    let start: Date
    let income: Double
    let expense: Double

    var net: Double { income - expense }
}

/// Unidad de los períodos del histórico — decide la palabra de la racha
/// («desde hace 3 meses»).
enum TrendHistoryUnit: String, Equatable {
    case weeks, months, years
}

/// Un importe ya clasificado: `isIncome` decide el bucket y `amount` llega con
/// signo de acumulación (positivo suma al bucket, negativo resta).
struct TrendHistoryEntry {
    let date: Date
    let isIncome: Bool
    let amount: Double
}

enum TrendHistoryLogic {

    /// Tope de períodos del histórico (R-T-5 del V1).
    static let maxPeriods = 12

    /// Paso de calendario entre períodos consecutivos. `nil` cuando el período
    /// no se repite hacia atrás de forma natural (Todo el tiempo, Personalizado).
    static func step(for period: DetailPeriod) -> (component: Calendar.Component, value: Int)? {
        switch period {
        case .thisWeek: return (.weekOfYear, 1)
        case .last7Days: return (.day, 7)
        case .last30Days: return (.day, 30)
        case .thisMonth, .lastMonth: return (.month, 1)
        case .thisYear, .lastYear: return (.year, 1)
        case .allTime, .custom: return nil
        }
    }

    /// Unidad para el copy de la racha. Últimos 30 días no tiene una palabra
    /// exacta («meses» sería falso), así que no produce bullet de Tendencia.
    static func unit(for period: DetailPeriod) -> TrendHistoryUnit? {
        switch period {
        case .thisWeek, .last7Days: return .weeks
        case .thisMonth, .lastMonth: return .months
        case .thisYear, .lastYear: return .years
        case .last30Days, .allTime, .custom: return nil
        }
    }

    /// Dónde termina el histórico. En un período en curso («Este mes») es su
    /// inicio: el período va a medias y no entra. En uno cerrado («Mes pasado»,
    /// «Año pasado») ya está completo y entra: si no, la racha hablaría de los
    /// meses anteriores y podría contradecir a la Comparativa de al lado.
    static func historyAnchor(for period: DetailPeriod, interval: DateInterval) -> Date {
        switch period {
        case .lastMonth, .lastYear: return interval.end.addingTimeInterval(1)
        default: return interval.start
        }
    }

    /// Los `count` períodos completos anteriores a `anchor` (ver `historyAnchor`),
    /// del más antiguo al más reciente.
    ///
    /// `DateInterval` es cerrado en los dos extremos: cada `end` es el inicio
    /// del siguiente menos 1 s, para que la medianoche compartida no cuente en
    /// los dos lados (CLAUDE.md, «Cálculos con fechas»).
    static func previousIntervals(
        for period: DetailPeriod,
        anchor: Date,
        count: Int = maxPeriods,
        calendar: Calendar
    ) -> [DateInterval] {
        guard let step = step(for: period), count > 0 else { return [] }
        var result: [DateInterval] = []
        for k in stride(from: count, through: 1, by: -1) {
            guard let start = calendar.date(byAdding: step.component, value: -k * step.value, to: anchor),
                  let nextStart = calendar.date(byAdding: step.component, value: -(k - 1) * step.value, to: anchor),
                  let end = calendar.date(byAdding: .second, value: -1, to: nextStart),
                  end > start else { continue }
            result.append(DateInterval(start: start, end: end))
        }
        return result
    }

    /// Suma las entradas en el período que las contiene. Los períodos sin
    /// movimientos salen con 0. Recorta por delante los períodos vacíos
    /// anteriores al primer movimiento («sin datos» no es «gastaste 0») y
    /// también ese primer período con datos si no es el primero de la ventana:
    /// ahí empezó a registrar y casi nunca está entero, así que inflaría una
    /// racha al alza. Si los datos llenan la ventana desde el principio, no hay
    /// motivo para pensar que el primero esté a medias y se queda.
    static func aggregate(entries: [TrendHistoryEntry], intervals: [DateInterval]) -> [TrendHistoryPoint] {
        guard !intervals.isEmpty else { return [] }
        var income = Array(repeating: 0.0, count: intervals.count)
        var expense = Array(repeating: 0.0, count: intervals.count)
        var hasData = Array(repeating: false, count: intervals.count)

        for entry in entries {
            guard let index = intervals.firstIndex(where: { $0.contains(entry.date) }) else { continue }
            hasData[index] = true
            if entry.isIncome {
                income[index] += entry.amount
            } else {
                expense[index] += entry.amount
            }
        }

        guard let firstWithData = hasData.firstIndex(of: true) else { return [] }
        let first = firstWithData == 0 ? 0 : firstWithData + 1
        guard first < intervals.count else { return [] }
        return (first..<intervals.count).map {
            TrendHistoryPoint(start: intervals[$0].start, income: income[$0], expense: expense[$0])
        }
    }
}
