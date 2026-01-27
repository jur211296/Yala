//
//  DateContextProvider.swift
//  Yala
//
//  Generates date context strings for AI prompts (Voice + Image).
//  Provides today, yesterday, day-of-week lookups, and relative date instructions.
//

import Foundation

struct DateContextProvider {

    /// Builds a complete date context block for injection into AI system prompts.
    /// Includes today, yesterday, day-of-week → date mapping, and relative date rules.
    static func buildDateContext(now: Date = Date()) -> String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current

        let today = fmt.string(from: now)
        let yesterday = fmt.string(from: cal.date(byAdding: .day, value: -1, to: now)!)
        let dayBefore = fmt.string(from: cal.date(byAdding: .day, value: -2, to: now)!)

        // Day of week in Spanish and English
        let spanishDayFmt = DateFormatter()
        spanishDayFmt.locale = Locale(identifier: "es")
        spanishDayFmt.dateFormat = "EEEE"
        let todayDayES = spanishDayFmt.string(from: now).lowercased()

        let englishDayFmt = DateFormatter()
        englishDayFmt.locale = Locale(identifier: "en")
        englishDayFmt.dateFormat = "EEEE"
        let todayDayEN = englishDayFmt.string(from: now)

        // Lookup table: each day of week → most recent past date
        let weekdayLookup = buildWeekdayLookup(from: now, calendar: cal, formatter: fmt)

        // Last week range (Monday-Sunday)
        let lastWeekRange = buildLastWeekRange(from: now, calendar: cal, formatter: fmt)

        let currentYear = cal.component(.year, from: now)

        return """
        Reglas de fecha:
        - Hoy es \(todayDayEN) (\(todayDayES)), \(today)
        - "hoy", "ahorita", "recién", "acabo de", "today" → \(today)
        - "ayer", "yesterday" → \(yesterday)
        - "anteayer", "antes de ayer", "day before yesterday" → \(dayBefore)
        - Sin mención de fecha → \(today)
        - Fecha explícita → usar esa fecha en formato YYYY-MM-DD

        Días de la semana (referencia a la fecha más reciente pasada):
        \(weekdayLookup)

        - "la semana pasada" / "last week" → rango \(lastWeekRange)
        - "hace X días" / "X days ago" → restar X días a \(today)

        Reglas de año:
        - Si se menciona solo día y mes (ej: "13 de enero", "January 13") → asumir año \(currentYear)
        - Si la fecha resultante es futura (después de \(today)) → usar año \(currentYear - 1)
        """
    }

    /// Returns a formatted lookup of weekday names → most recent past date.
    private static func buildWeekdayLookup(
        from now: Date,
        calendar: Calendar,
        formatter: DateFormatter
    ) -> String {
        let spanishDays = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]
        let englishDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        // ISO weekday: Monday=2, Sunday=1 in Calendar, but we use ISO mapping
        let isoWeekdays = [2, 3, 4, 5, 6, 7, 1] // Mon-Sun in Calendar.weekday

        let todayWeekday = calendar.component(.weekday, from: now) // 1=Sun, 2=Mon, ...

        var lines: [String] = []
        for i in 0..<7 {
            let targetWeekday = isoWeekdays[i]
            var daysBack = (todayWeekday - targetWeekday + 7) % 7
            if daysBack == 0 { daysBack = 7 } // "el lunes" = last Monday, not today
            let date = calendar.date(byAdding: .day, value: -daysBack, to: now)!
            let dateStr = formatter.string(from: date)
            lines.append("- \"el \(spanishDays[i])\" / \"\(englishDays[i])\" → \(dateStr)")
        }
        return lines.joined(separator: "\n")
    }

    /// Returns last week's Monday-Sunday range as "YYYY-MM-DD a YYYY-MM-DD"
    private static func buildLastWeekRange(
        from now: Date,
        calendar: Calendar,
        formatter: DateFormatter
    ) -> String {
        // Find this week's Monday
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 2 // Monday
        guard let thisMonday = calendar.date(from: components) else {
            return "N/A"
        }
        // Last week Monday = thisMonday - 7
        let lastMonday = calendar.date(byAdding: .day, value: -7, to: thisMonday)!
        let lastSunday = calendar.date(byAdding: .day, value: 6, to: lastMonday)!
        return "\(formatter.string(from: lastMonday)) a \(formatter.string(from: lastSunday))"
    }
}
