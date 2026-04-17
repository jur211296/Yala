//
//  HeroMessageCache.swift
//  Yala
//
//  Cache 24h del mensaje IA del Hero del mes.
//
//  Capa pura (sin OpenAI, sin SwiftUI) — testeable contra
//  `UserDefaults(suiteName:)` efímero. `InsightsLLMService` es el único
//  consumidor: lee antes de llamar la API y escribe tras un parse válido.
//
//  Key única `panelHeroAIMessage_v1` con JSON `{day, hash, text}`. TTL
//  implícito = mismo `yyyy-MM-dd` + mismo `contextHash`; cualquier cambio
//  invalida el cache y fuerza regeneración.
//

import Foundation

// MARK: - Context

/// Tendencia del gasto del mes actual vs el mes anterior. `nil` cuando el
/// mes anterior no tiene data suficiente (usuarios con >2000 tx recortan el
/// fetch del VM). El prompt omite la referencia cuando es `nil`.
enum HeroSpendingTrend: String, Equatable {
    case down, flat, up
}

/// Snapshot agregado que alimenta al LLM. Sin transacciones individuales —
/// solo contadores. Cambios en cualquier campo reemplazan el `contextHash` y
/// fuerzan regeneración.
struct HeroContext: Equatable {
    let state: HeroMonthState
    let financialScore: Int?
    let percentBudgetUsed: Double?
    let spendingTrend: HeroSpendingTrend?
    let monthName: String
    let userName: String?
    let daysRemaining: Int
    let locale: String
}

// MARK: - Entry

struct HeroMessageCacheEntry: Codable, Equatable {
    let day: String
    let hash: String
    let text: String
}

// MARK: - Cache

enum HeroMessageCache {

    /// Single JSON blob bajo una sola key. `v1` se reserva para cambios de
    /// schema futuros (`v2` limpiaría la key anterior via `DataWipeService`).
    static let key = "panelHeroAIMessage_v1"

    /// Hash estable y compacto — cada token contribuye a una colisión
    /// controlada. `"na"` diferencia explícitamente `nil` de `0` para
    /// `financialScore`, `percentBudgetUsed` y `spendingTrend`. Buckets de
    /// decenas (porcentaje) y semanas (días restantes) evitan invalidar la
    /// cache por micro-cambios intradía.
    static func contextHash(_ ctx: HeroContext) -> String {
        let scoreToken: String
        if let score = ctx.financialScore {
            scoreToken = String((score / 10) * 10)
        } else {
            scoreToken = "na"
        }

        let percentToken: String
        if let percent = ctx.percentBudgetUsed {
            let decile = Int((percent * 100).rounded(.down) / 10) * 10
            percentToken = String(format: "%03d", max(0, decile))
        } else {
            percentToken = "na"
        }

        let trendToken = ctx.spendingTrend?.rawValue ?? "na"
        let daysBucket = String(ctx.daysRemaining / 7)
        let name = ctx.userName?.isEmpty == false ? ctx.userName! : "_"

        return [
            ctx.state.rawValue,
            scoreToken,
            percentToken,
            trendToken,
            daysBucket,
            ctx.locale,
            name,
        ].joined(separator: "_")
    }

    // MARK: - Day formatter (stable across timezones)

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// `en_US_POSIX` evita drift en locales que usan calendarios no-gregorianos.
    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    static func dayString(from date: Date) -> String {
        dayFormatter.string(from: date)
    }

    // MARK: - Read / Write / Clear

    /// Devuelve `nil` si no hay entry, si no decodifica, o si el `day` no
    /// coincide con `today`. El caller compara el `hash` contra el contexto
    /// actual antes de usar el texto.
    static func read(defaults: UserDefaults = .standard, today: Date = .now) -> HeroMessageCacheEntry? {
        guard let data = defaults.data(forKey: key),
              let entry = try? decoder.decode(HeroMessageCacheEntry.self, from: data),
              entry.day == dayString(from: today) else {
            return nil
        }
        return entry
    }

    static func write(_ entry: HeroMessageCacheEntry, defaults: UserDefaults = .standard) {
        guard let data = try? encoder.encode(entry) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
