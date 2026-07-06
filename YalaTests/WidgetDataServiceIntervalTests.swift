//
//  WidgetDataServiceIntervalTests.swift
//  YalaTests
//
//  Cubre el mirror manual de intervalos de período del target de WIDGETS
//  (`WidgetPeriod.dateInterval()` en YalaWidgets/Services/WidgetDataService.swift,
//  commit cd30951e) contra el SSOT de la app (`DetailPeriod.dateInterval(now:)`
//  en Yala/App/Models/SharedModels.swift).
//
//  IMPORTANTE — por qué se REPLICA la lógica del widget en el test:
//  `WidgetPeriod` y `WidgetDataService` viven SOLO en el target
//  `YalaWidgetsExtension` (verificado en project.pbxproj: el único archivo de
//  `YalaWidgets/` que compila en el target `Yala` es `Utils/WidgetURLHelper.swift`,
//  vía `PBXFileSystemSynchronizedBuildFileExceptionSet`). El target `YalaTests`
//  hostea la app `Yala`, así que `@testable import Yala` NO alcanza los símbolos
//  del widget — mismo motivo por el que `WidgetLocalizationParityTests` lee los
//  .strings del widget desde disco vía `#filePath` en vez de importarlos.
//
//  Estrategia (misma que la "réplica independiente" de `DateAlignmentHelperTests`):
//  - `widgetDateInterval(_:calendar:now:)` es una RÉPLICA FIEL, línea por línea,
//    del cuerpo de `WidgetPeriod.dateInterval()` (parametrizando el `calendar` y el
//    `now`, que el original toma de `WidgetDataService.widgetConfiguredCalendar()`
//    y `Date()` sin inyección).
//  - PARIDAD: para cada período la réplica del widget == el SSOT REAL alcanzable
//    `DetailPeriod.dateInterval(now:)`. Como el SSOT usa `userConfiguredCalendar()`
//    (lee `firstWeekday` de `.standard`), la paridad exacta se comprueba sobre los
//    períodos INDEPENDIENTES de `firstWeekday` (todos menos `.thisWeek`); para
//    `.thisWeek` se verifica que la réplica del widget coincide con una réplica del
//    SSOT usando el MISMO calendario inyectado (prueba que ambos algoritmos son
//    idénticos incluso en el caso dependiente de la semana).
//  - EXCLUSIÓN medianoche: sobre el SSOT real y sobre la réplica del widget, que el
//    `end` de "mes pasado"/"año pasado" lleve el -1 segundo (excluye la medianoche
//    del día 1 del período actual — regla `DateInterval` cerrado en ambos extremos).
//
//  NOTA (fuera de cobertura): `WidgetPeriod.dateInterval()` no es inyectable
//  (usa `Date()` y el calendario del App Group internamente), por lo que no se
//  puede invocar la implementación REAL del widget de forma determinista desde
//  este target. Si algún día `WidgetDataService.swift` se agrega al target de la
//  app, sustituir la réplica por la llamada directa.
//

import Foundation
import Testing

@testable import Yala

struct WidgetDataServiceIntervalTests {

    // MARK: - Fixtures deterministas

    /// Gregoriano en zona sin DST (Lima, UTC-5), lunes como primer día de semana
    /// (default de la app cuando `firstWeekday` no está seteado).
    private func makeCalendar(firstWeekday: Int = 2) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima")!
        c.firstWeekday = firstWeekday
        return c
    }

    /// `now` fijo: miércoles 15 de julio de 2026, 14:30:00 (America/Lima).
    private func fixedNow(_ calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 15, hour: 14, minute: 30, second: 0))!
    }

    /// Todos los períodos con contraparte 1:1 entre `WidgetPeriod` y `DetailPeriod`.
    /// (`WidgetPeriod` no tiene `.custom`; `DetailPeriod` sí, se excluye.)
    private var mirroredPeriods: [DetailPeriod] {
        [.thisWeek, .last7Days, .last30Days, .thisMonth,
         .lastMonth, .thisYear, .lastYear, .allTime]
    }

    // MARK: - Réplica FIEL de WidgetPeriod.dateInterval()

    /// Copia línea por línea de `WidgetPeriod.dateInterval()` del target de widgets,
    /// con `calendar` y `now` inyectados. Debe mantenerse en sync con
    /// `YalaWidgets/Services/WidgetDataService.swift`.
    private func widgetDateInterval(
        _ period: DetailPeriod,
        calendar: Calendar,
        now: Date
    ) -> DateInterval {
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now

        switch period {
        case .thisWeek:
            let startOfWeek = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? startOfToday
            return DateInterval(start: startOfWeek, end: endOfToday)

        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: endOfToday)

        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: endOfToday)

        case .thisMonth:
            let startOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)) ?? startOfToday
            return DateInterval(start: startOfMonth, end: endOfToday)

        case .lastMonth:
            let startOfThisMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)) ?? startOfToday
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? startOfToday
            let endOfLastMonth = calendar.date(byAdding: .second, value: -1, to: startOfThisMonth) ?? startOfThisMonth
            return DateInterval(start: startOfLastMonth, end: endOfLastMonth)

        case .thisYear:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? startOfToday
            return DateInterval(start: startOfYear, end: endOfToday)

        case .lastYear:
            let startOfThisYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? startOfToday
            let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfThisYear) ?? startOfToday
            let endOfLastYear = calendar.date(byAdding: .second, value: -1, to: startOfThisYear) ?? startOfThisYear
            return DateInterval(start: startOfLastYear, end: endOfLastYear)

        case .allTime:
            let start = calendar.date(byAdding: .year, value: -10, to: now) ?? startOfToday
            return DateInterval(start: start, end: endOfToday)

        case .custom:
            // WidgetPeriod no tiene `.custom`; nunca se ejerce aquí.
            let startOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)) ?? startOfToday
            return DateInterval(start: startOfMonth, end: now)
        }
    }

    // MARK: - (1) Exclusión de la medianoche del día 1 del período actual

    @Test func lastMonth_ssot_excludes_midnight_of_first_day_of_this_month() {
        let calendar = makeCalendar()
        let now = fixedNow(calendar)
        let startOfThisMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now))!

        let interval = DetailPeriod.lastMonth.dateInterval(now: now)

        // El `end` es la medianoche del día 1 del mes actual MENOS 1 segundo.
        #expect(interval.end == calendar.date(byAdding: .second, value: -1, to: startOfThisMonth))
        // La medianoche del día 1 del mes actual NO cae dentro de "mes pasado".
        #expect(!interval.contains(startOfThisMonth))
    }

    @Test func lastYear_ssot_excludes_midnight_of_first_day_of_this_year() {
        let calendar = makeCalendar()
        let now = fixedNow(calendar)
        let startOfThisYear = calendar.date(
            from: calendar.dateComponents([.year], from: now))!

        let interval = DetailPeriod.lastYear.dateInterval(now: now)

        #expect(interval.end == calendar.date(byAdding: .second, value: -1, to: startOfThisYear))
        #expect(!interval.contains(startOfThisYear))
    }

    @Test func widgetReplica_lastMonth_excludes_midnight_of_first_day_of_this_month() {
        let calendar = makeCalendar()
        let now = fixedNow(calendar)
        let startOfThisMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now))!

        let interval = widgetDateInterval(.lastMonth, calendar: calendar, now: now)

        #expect(interval.end == calendar.date(byAdding: .second, value: -1, to: startOfThisMonth))
        #expect(!interval.contains(startOfThisMonth))
    }

    @Test func widgetReplica_lastYear_excludes_midnight_of_first_day_of_this_year() {
        let calendar = makeCalendar()
        let now = fixedNow(calendar)
        let startOfThisYear = calendar.date(
            from: calendar.dateComponents([.year], from: now))!

        let interval = widgetDateInterval(.lastYear, calendar: calendar, now: now)

        #expect(interval.end == calendar.date(byAdding: .second, value: -1, to: startOfThisYear))
        #expect(!interval.contains(startOfThisYear))
    }

    /// Guard directo del `-1 segundo`: un día 1 a medianoche (que `DatePicker`
    /// normaliza así) NO debe contarse en el período anterior.
    @Test func lastMonth_ssot_end_is_exactly_one_second_before_this_month_start() {
        let calendar = makeCalendar()
        let now = fixedNow(calendar)
        let startOfThisMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now))!

        let end = DetailPeriod.lastMonth.dateInterval(now: now).end

        #expect(startOfThisMonth.timeIntervalSince(end) == 1)
    }

    // MARK: - (2) PARIDAD: réplica del widget == SSOT real (períodos indep. de firstWeekday)

    @Test func parity_widgetReplica_matches_ssot_for_all_non_weekly_periods() {
        let calendar = makeCalendar()
        let now = fixedNow(calendar)

        for period in mirroredPeriods where period != .thisWeek {
            let widget = widgetDateInterval(period, calendar: calendar, now: now)
            let ssot = period.dateInterval(now: now)  // usa userConfiguredCalendar() real
            #expect(
                widget == ssot,
                "Drift widget↔SSOT en \(period.rawValue): widget=\(widget) ssot=\(ssot)"
            )
        }
    }

    /// `.thisWeek` depende de `firstWeekday`; el SSOT real lo lee de `.standard`,
    /// no inyectable aquí. Se prueba que ambos ALGORITMOS coinciden usando el mismo
    /// calendario inyectado (réplica del widget vs réplica del SSOT).
    @Test func parity_thisWeek_algorithms_match_with_shared_calendar() {
        let calendar = makeCalendar(firstWeekday: 2)  // lunes
        let now = fixedNow(calendar)

        let widget = widgetDateInterval(.thisWeek, calendar: calendar, now: now)

        // Réplica del SSOT (`DetailPeriod.thisWeek`) con el mismo calendario.
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let ssotReplica = DateInterval(start: startOfWeek, end: endOfToday)

        #expect(widget == ssotReplica)
    }

    /// Con `firstWeekday = domingo (1)` el inicio de semana cambia — la réplica del
    /// widget debe seguir el calendario inyectado (no hardcodea el lunes).
    @Test func parity_thisWeek_respects_sunday_firstWeekday() {
        let calendar = makeCalendar(firstWeekday: 1)  // domingo
        let now = fixedNow(calendar)  // miércoles 15-jul-2026

        let interval = widgetDateInterval(.thisWeek, calendar: calendar, now: now)

        // El inicio de semana debe ser el domingo 12-jul-2026 (medianoche).
        let expectedStart = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 12))!
        #expect(interval.start == expectedStart)
    }

    // MARK: - Comprobaciones estructurales adicionales

    /// Todos los períodos "actuales" comparten el mismo `end` (fin del día de hoy).
    @Test func currentPeriods_share_endOfToday_in_widgetReplica() {
        let calendar = makeCalendar()
        let now = fixedNow(calendar)
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        for period in [DetailPeriod.thisWeek, .last7Days, .last30Days,
                       .thisMonth, .thisYear, .allTime] {
            let interval = widgetDateInterval(period, calendar: calendar, now: now)
            #expect(
                interval.end == endOfToday,
                "\(period.rawValue) debería terminar al fin del día de hoy"
            )
        }
    }

    /// `.allTime` arranca 10 años antes de `now` (no del inicio del día).
    @Test func allTime_starts_ten_years_before_now_in_both_impls() {
        let calendar = makeCalendar()
        let now = fixedNow(calendar)
        let expectedStart = calendar.date(byAdding: .year, value: -10, to: now)!

        let widget = widgetDateInterval(.allTime, calendar: calendar, now: now)
        let ssot = DetailPeriod.allTime.dateInterval(now: now)

        #expect(widget.start == expectedStart)
        #expect(ssot.start == expectedStart)
    }
}
