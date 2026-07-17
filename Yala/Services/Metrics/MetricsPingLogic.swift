//
//  MetricsPingLogic.swift
//  Yala
//
//  Decisión pura del ping diario (usuarios activos/día). Día en UTC a propósito:
//  alinea con el bucketing por `timestamp` de Analytics Engine, así el guard
//  client-side "≤1 ping/día" y la query `GROUP BY day` cuentan lo mismo.
//  Molde RemoteFlagDecisionLogic: `now` inyectado, jamás Date() en la lógica.
//

import Foundation

nonisolated enum MetricsPingLogic {

    /// Día UTC estable `yyyy-MM-dd` (independiente de la zona horaria y del calendario
    /// del usuario — es una clave de dedup, no una fecha de display).
    static func dayString(for now: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// true si el día UTC de `now` difiere del último ping registrado (o nunca hubo).
    /// Un `lastPingDay` FUTURO (reloj rebobinado) también pingea — preferible un
    /// double-count raro a un silencio hasta que el wall-clock re-alcance.
    static func shouldPing(lastPingDay: String?, now: Date) -> Bool {
        lastPingDay != dayString(for: now)
    }
}
