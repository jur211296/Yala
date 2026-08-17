//
//  DateAlignmentHelper.swift
//  Yala
//
//  Pure temporal-alignment logic for period comparison (MTD-vs-MTD).
//
//  Extraído desde `PeriodComparisonChartView` para poder reusar la MISMA
//  alineación que dibuja la curva del período anterior al computar el KPI /
//  total del período anterior. Sin esto, el KPI usaba el ÚLTIMO punto del
//  período anterior COMPLETO (fin de mes) mientras la curva se alinea/clippea
//  al día equivalente del último día con datos del actual → descuadre
//  KPI-vs-curva (ticket p20-15). Toda la lógica es pura; `calendar` es
//  inyectable (default `.current`) para determinismo en tests.
//

import Foundation

enum DateAlignmentHelper {

    /// Estrategia de alineación temporal entre el período anterior y el actual.
    enum AlignmentStrategy {
        case calendarYear   // Exact date -1 year
        case dayOfMonth     // Same day of month (13 → 13)
        case dayOfWeek      // Same day of week (Mon → Mon)
        case proportional   // Position-based (day 1 → day 1)
    }

    /// Determina la estrategia según el período y el modo de comparación.
    /// Función pura de `(period, comparisonMode)`.
    static func alignmentStrategy(
        period: DetailPeriod,
        comparisonMode: ComparisonMode
    ) -> AlignmentStrategy {
        switch comparisonMode {
        case .year:
            // Year mode: always align by exact calendar date (-1 year)
            return .calendarYear
        case .month:
            switch period {
            case .thisWeek:
                // Weekly periods: align by day of week (Mon↔Mon, Tue↔Tue)
                return .dayOfWeek
            case .thisMonth, .lastMonth:
                // Monthly periods: align by day of month (13↔13)
                return .dayOfMonth
            case .last7Days, .last30Days, .custom, .thisYear, .lastYear, .allTime:
                // Rolling/custom periods: proportional mapping (day 1↔day 1)
                return .proportional
            }
        }
    }

    /// Mapea una fecha del período ANTERIOR → fecha en el dominio del período ACTUAL.
    static func adjustDateToCurrent(
        _ previousDate: Date,
        currentInterval: DateInterval,
        previousInterval: DateInterval,
        period: DetailPeriod,
        comparisonMode: ComparisonMode,
        calendar: Calendar = .current
    ) -> Date {
        switch alignmentStrategy(period: period, comparisonMode: comparisonMode) {
        case .calendarYear:
            // Add 1 year to previous date to align with current
            return calendar.date(byAdding: .year, value: 1, to: previousDate) ?? previousDate

        case .dayOfMonth:
            // Align by day of month: Dec 13 → Jan 13
            let dayOfMonth = calendar.component(.day, from: previousDate)
            var components = calendar.dateComponents([.year, .month], from: currentInterval.start)
            components.day = dayOfMonth
            // Handle edge case: day doesn't exist in current month (e.g., 31 in Feb)
            if let targetDate = calendar.date(from: components) {
                return targetDate
            }
            let lastDayOfMonth = calendar.range(of: .day, in: .month, for: currentInterval.start)?.upperBound ?? 28
            components.day = min(dayOfMonth, lastDayOfMonth - 1)
            return calendar.date(from: components) ?? previousDate

        case .dayOfWeek:
            // Align by day of week: Mon → Mon, Tue → Tue
            let weekday = calendar.component(.weekday, from: previousDate)
            let currentWeekStart = currentInterval.start
            let currentWeekday = calendar.component(.weekday, from: currentWeekStart)
            let dayOffset = weekday - currentWeekday
            return calendar.date(byAdding: .day, value: dayOffset, to: currentWeekStart) ?? previousDate

        case .proportional:
            let previousDuration = previousInterval.duration
            let currentDuration = currentInterval.duration
            guard previousDuration > 0 else { return previousDate }
            let relativePosition = previousDate.timeIntervalSince(previousInterval.start) / previousDuration
            return currentInterval.start.addingTimeInterval(relativePosition * currentDuration)
        }
    }

    /// Inversa: mapea una fecha del período ACTUAL → fecha en el período ANTERIOR.
    static func getOriginalPreviousDate(
        for currentDate: Date,
        currentInterval: DateInterval,
        previousInterval: DateInterval,
        period: DetailPeriod,
        comparisonMode: ComparisonMode,
        calendar: Calendar = .current
    ) -> Date {
        switch alignmentStrategy(period: period, comparisonMode: comparisonMode) {
        case .calendarYear:
            // Subtract 1 year from current date
            return calendar.date(byAdding: .year, value: -1, to: currentDate) ?? currentDate

        case .dayOfMonth:
            // Inverse: get day of month from current, apply to previous month
            let dayOfMonth = calendar.component(.day, from: currentDate)
            var components = calendar.dateComponents([.year, .month], from: previousInterval.start)
            components.day = dayOfMonth
            if let targetDate = calendar.date(from: components) {
                return targetDate
            }
            let lastDayOfMonth = calendar.range(of: .day, in: .month, for: previousInterval.start)?.upperBound ?? 28
            components.day = min(dayOfMonth, lastDayOfMonth - 1)
            return calendar.date(from: components) ?? currentDate

        case .dayOfWeek:
            // Inverse: get weekday from current, find same in previous week
            let weekday = calendar.component(.weekday, from: currentDate)
            let previousWeekStart = previousInterval.start
            let previousWeekday = calendar.component(.weekday, from: previousWeekStart)
            let dayOffset = weekday - previousWeekday
            return calendar.date(byAdding: .day, value: dayOffset, to: previousWeekStart) ?? currentDate

        case .proportional:
            let currentDuration = currentInterval.duration
            let previousDuration = previousInterval.duration
            guard currentDuration > 0 else { return currentDate }
            let relativePosition = currentDate.timeIntervalSince(currentInterval.start) / currentDuration
            return previousInterval.start.addingTimeInterval(relativePosition * previousDuration)
        }
    }

    /// Trunca el intervalo del período ANTERIOR al día equivalente del "as-of"
    /// actual (MTD-vs-MTD) para el ÚNICO caso con asimetría parcial-vs-completo:
    /// `.thisMonth` en modo `.month` (actual = MTD parcial; previo = mes COMPLETO).
    /// Para cualquier otro período/modo devuelve `previousInterval` sin tocar: el
    /// resto ya es simétrico en duración (su previo es del mismo span vía
    /// `sameIntervalPreviousYear` o la ventana trailing de igual duración), así que
    /// alinear sería no-op o dañino (excluiría txns no-medianoche del día
    /// equivalente sin arreglar nada). Pura; reusa `getOriginalPreviousDate` (misma
    /// estrategia `.dayOfMonth` que la curva). Usado por el hero de Estadísticas
    /// (`InsightsCalculator`) para que su variación no compare parcial-vs-completo
    /// (D2 de p20-15). `calendar` inyectable para tests deterministas.
    static func alignedPreviousInterval(
        currentInterval: DateInterval,
        previousInterval: DateInterval,
        asOf: Date,
        period: DetailPeriod,
        comparisonMode: ComparisonMode,
        calendar: Calendar = .current
    ) -> DateInterval {
        // Gate: períodos parciales en curso (mes / semana / año). Resto → no-op.
        guard aggregatePreviousNeedsAlignment(period: period, comparisonMode: comparisonMode) else {
            return previousInterval
        }

        // Normaliza a medianoche del día en curso; defensivo si el período ya cerró.
        let startOfToday = calendar.startOfDay(for: asOf)
        guard startOfToday < currentInterval.end else { return previousInterval }

        // Mapea el día en curso → día equivalente del mes previo (medianoche, por
        // la estrategia .dayOfMonth de .thisMonth).
        let mapped = getOriginalPreviousDate(
            for: startOfToday,
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            period: period,
            comparisonMode: comparisonMode,
            calendar: calendar
        )

        // Extiende al INICIO del día SIGUIENTE al equivalente para incluir ese día
        // COMPLETO. El intervalo actual termina en `endOfToday` (inicio de mañana),
        // así que cuenta hoy entero; el previo debe incluir el día equivalente
        // entero o la comparación MTD-vs-MTD queda asimétrica (una TX del previo con
        // hora — jun 6 14:00 — caería fuera mientras su gemela jul 6 14:00 sí cuenta;
        // y en día 1 el intervalo colapsaría a ancho cero). OJO: esta regla de borde
        // (día equivalente COMPLETO, `.contains` cerrado) DIFIERE del pipeline de la
        // curva (`clippedPreviousPoints`, padding ±1d sobre puntos) — el hero filtra
        // TX crudas, no puntos; no asumir paridad de borde entre ambos.
        let endOfEquivalentDay = calendar.date(byAdding: .day, value: 1, to: mapped) ?? mapped

        // Clamp al rango del previo: neutraliza el rollover del mes destino más
        // corto (ej. hoy día 31, junio 30d → mapped+1 se pasa → clamp a fin del
        // previo = mes completo) y el último día del mes.
        let alignedEnd = min(max(endOfEquivalentDay, previousInterval.start), previousInterval.end)
        return DateInterval(start: previousInterval.start, end: alignedEnd)
    }

    /// Total del período anterior alineado al día equivalente del último día
    /// con datos del período actual (MTD-vs-MTD). Devuelve el valor del ÚLTIMO
    /// punto VISIBLE de la curva anterior — replica EXACTAMENTE el pipeline de
    /// `PeriodComparisonChartView` (`dataXDomain` + `clippedPreviousPoints`):
    /// filtra `value != 0`, mapea con `adjustDateToCurrent`, clippea al dominio
    /// de datos del actual (con padding ±1d) y toma el último por fecha.
    ///
    /// Garantiza `alignedPreviousTotal == clippedPreviousPoints.last?.value`
    /// (verificado por `DateAlignmentHelperTests`). `nil` si no hay puntos
    /// anteriores visibles (sin variación comparable).
    static func alignedPreviousTotal(
        previousPoints: [BarPoint],
        currentPoints: [BarPoint],
        currentInterval: DateInterval,
        previousInterval: DateInterval,
        period: DetailPeriod,
        comparisonMode: ComparisonMode,
        calendar: Calendar = .current
    ) -> Double? {
        clippedPreviousPoints(
            previousPoints: previousPoints,
            currentPoints: currentPoints,
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            period: period,
            comparisonMode: comparisonMode,
            calendar: calendar
        ).last?.value
    }

    /// Dominio X de la comparación: rango de datos del período ACTUAL (puntos
    /// con `value != 0`) con padding de ±1 día; fallback al intervalo si no hay
    /// datos. **SSOT** del dominio — la curva (`chartXScale` + clipping) y el
    /// KPI leen de aquí, así el padding no puede divergir entre ambos (p20-15).
    /// `currentPoints` debe venir ORDENADO por fecha.
    static func currentDataDomain(
        currentPoints: [BarPoint],
        currentInterval: DateInterval,
        calendar: Calendar = .current
    ) -> ClosedRange<Date> {
        let filteredCurrent = currentPoints.filter { $0.value != 0 }
        guard let firstDate = filteredCurrent.first?.date,
              let lastDate = filteredCurrent.last?.date else {
            return currentInterval.start...currentInterval.end
        }
        let paddedStart = calendar.date(byAdding: .day, value: -1, to: firstDate) ?? firstDate
        let paddedEnd = calendar.date(byAdding: .day, value: 1, to: lastDate) ?? lastDate
        return paddedStart...paddedEnd
    }

    /// Puntos del período ANTERIOR mapeados al dominio del actual y clippeados:
    /// filtra `value != 0`, alinea con `adjustDateToCurrent`, descarta lo que
    /// cae fuera de `currentDataDomain` y ordena por fecha. **SSOT** del pipeline
    /// de clipping — consumido tanto por la curva (`PeriodComparisonChartView`)
    /// como por el KPI (`alignedPreviousTotal`), de modo que no pueden divergir.
    static func clippedPreviousPoints(
        previousPoints: [BarPoint],
        currentPoints: [BarPoint],
        currentInterval: DateInterval,
        previousInterval: DateInterval,
        period: DetailPeriod,
        comparisonMode: ComparisonMode,
        calendar: Calendar = .current
    ) -> [BarPoint] {
        let domain = currentDataDomain(
            currentPoints: currentPoints,
            currentInterval: currentInterval,
            calendar: calendar
        )
        return previousPoints
            .filter { $0.value != 0 }
            .compactMap { point -> BarPoint? in
                let adjustedDate = adjustDateToCurrent(
                    point.date,
                    currentInterval: currentInterval,
                    previousInterval: previousInterval,
                    period: period,
                    comparisonMode: comparisonMode,
                    calendar: calendar
                )
                guard adjustedDate >= domain.lowerBound && adjustedDate <= domain.upperBound else {
                    return nil
                }
                return BarPoint(date: adjustedDate, value: point.value)
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Sumas agregadas (VariationChips del Panel, p20-15 fase 2)

    /// El período ACTUAL es PARCIAL y el anterior es el período calendario
    /// COMPLETO (o más largo) → hay que truncar al día equivalente.
    /// p20-15: `.thisMonth`+`.month`, `.thisWeek`+`.month` (semana calendario
    /// anterior, no trailing) y `.thisYear` (YTD; default `.year`).
    /// Cerrados y rodantes (`.lastMonth`, `.last7Days`, …) se quedan full-vs-full.
    static func aggregatePreviousNeedsAlignment(
        period: DetailPeriod,
        comparisonMode: ComparisonMode
    ) -> Bool {
        switch period {
        case .thisMonth:
            return comparisonMode == .month
        case .thisWeek:
            return comparisonMode == .month
        case .thisYear:
            return true
        case .last7Days, .last30Days, .lastMonth, .lastYear, .allTime, .custom:
            return false
        }
    }

    /// Trunca los items del período ANTERIOR al mismo rango de días que los datos
    /// del período ACTUAL (MTD-vs-MTD para las SUMAS agregadas del Panel:
    /// categorías, subcategorías, tags, necesidades y cash flow). Mapea la fecha
    /// de cada item con `adjustDateToCurrent` (misma alineación que la curva de
    /// Comparativa) y lo conserva si la fecha alineada cae en la ventana
    /// `[currentInterval.start ... max(currentDates)]` (desde el inicio del período
    /// —una SUMA cuenta desde el arranque— hasta el último día con datos del
    /// actual). Como `adjustDateToCurrent` normaliza a medianoche, equivale a
    /// "día-del-período del previo entre el inicio del período y el del último dato
    /// del actual". Así la suma del previo cubre el MISMO span de días que la del
    /// actual (elimina el sesgo "mes en curso vs mes anterior completo").
    ///
    /// El gate `aggregatePreviousNeedsAlignment` sólo enruta `.thisMonth`
    /// (estrategia `.dayOfMonth`). El borde INFERIOR (`>= currentInterval.start`)
    /// es no-op para `.dayOfMonth` (el mapeo siempre cae dentro del mes actual) y
    /// se conserva como defensa: hace el filtro correcto para CUALQUIER estrategia
    /// —p.ej. `.dayOfWeek`, donde el domingo del previo (weekday 1 < lunes 2) mapea
    /// a un offset negativo, ANTES del inicio de semana— por si el gate se ampliara.
    ///
    /// A DIFERENCIA de la curva (`clippedPreviousPoints`) NO aplica padding ±1d:
    /// ese `+1d` es breathing-room del eje X, no semántica; para una SUMA el corte
    /// honesto es el día exacto. El gate limita a `.thisMonth` (nunca cerrados) →
    /// sin riesgo de rollover de fin-de-mes que exigiera el padding.
    ///
    /// No-op (devuelve `previous` intacto) cuando el período ya es simétrico
    /// (`aggregatePreviousNeedsAlignment == false`) o cuando el actual no tiene
    /// datos (`currentDates` vacío → sin referencia de corte). Genérico + closure
    /// `date:` para testear sin SwiftData.
    static func alignedPreviousItems<T>(
        _ previous: [T],
        currentDates: [Date],
        currentInterval: DateInterval,
        previousInterval: DateInterval,
        period: DetailPeriod,
        comparisonMode: ComparisonMode,
        calendar: Calendar = .current,
        date: (T) -> Date
    ) -> [T] {
        guard aggregatePreviousNeedsAlignment(period: period, comparisonMode: comparisonMode),
              let lastCurrentDate = currentDates.max() else {
            return previous
        }
        return previous.filter { item in
            let adjusted = adjustDateToCurrent(
                date(item),
                currentInterval: currentInterval,
                previousInterval: previousInterval,
                period: period,
                comparisonMode: comparisonMode,
                calendar: calendar
            )
            return adjusted >= currentInterval.start && adjusted <= lastCurrentDate
        }
    }
}
