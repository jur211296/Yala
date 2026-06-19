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
///
/// `income` / `expense` / `available` se pasan al LLM ya formateados
/// (`"S/ 6,019"`) para que pueda citarlos de forma natural sin reformatear.
/// El `contextHash` bucketea al centenar para no invalidar cache en cada
/// micro-gasto del día.
struct HeroContext: Equatable {
    let state: HeroMonthState
    let financialScore: Int?
    let percentBudgetUsed: Double?
    let spendingTrend: HeroSpendingTrend?
    let monthName: String
    let userName: String?
    let daysRemaining: Int
    let daysElapsed: Int
    let locale: String
    let income: Double
    let expense: Double
    let available: Double
    let formattedIncome: String
    let formattedExpense: String
    let formattedAvailable: String
    /// Gasto del mes anterior — nil cuando no hay data suficiente (sin tx
    /// en el período previo). Le permite al LLM citar la comparación
    /// ("gastaste S/ 1,200 menos que en marzo") en vez de sólo describir la
    /// tendencia sin cifras.
    let previousExpense: Double?
    let formattedPreviousExpense: String?
    /// Delta absoluto firmado del gasto (`expense - previousExpense`) —
    /// positivo = gasta más, negativo = gasta menos. Facilita al LLM usar
    /// el monto de la diferencia directamente.
    let expenseDelta: Double?
    let formattedExpenseDelta: String?

    // Enriquecimiento contextual (best-effort, reusa computes existentes
    // de los widgets de Distribución/Tendencias).

    /// Nombre de la categoría #1 del mes (primer item de `categoriesWidget`
    /// ya computado). `nil` cuando la sección Distribución está toda oculta
    /// o no hay gasto categorizado.
    let topCategory: String?
    let formattedTopCategoryAmount: String?
    /// Variación porcentual vs mes anterior (`+15.0` / `-8.3`). El LLM puede
    /// citarlo cuando |delta| > 10% para justificar variaciones del expense.
    let topCategoryDeltaPercent: Double?

    /// Día de la semana con más gasto acumulado en el mes (`weekdayWidget`).
    /// `nil` cuando no hay suficientes datos para destacar un día.
    let topWeekday: String?
    let formattedTopWeekdayAmount: String?

    /// `daysElapsed / (daysElapsed + daysRemaining)` en [0.0, 1.0]. Le permite
    /// al LLM calcular "% del mes transcurrido" sin pedirle aritmética de
    /// fechas.
    let monthProgress: Double
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
        // Bucket al centenar: evita invalidar el cache por micro-gastos
        // intradía pero sí lo hace cuando el monto mueve ~100 de la moneda
        // del user (lo suficiente para que un mensaje previo se sienta stale).
        let incomeBucket = String(Int(ctx.income / 100))
        let expenseBucket = String(Int(ctx.expense / 100))
        let availableBucket = String(Int(ctx.available / 100))
        let prevExpenseBucket = ctx.previousExpense.map { String(Int($0 / 100)) } ?? "na"
        // Enriquecimiento contextual. `topCategory` cambia cuando el ranking
        // del mes se mueve — vale la pena invalidar. El delta se bucketea
        // al 5% para evitar regens por micro-cambios.
        let topCategoryToken = ctx.topCategory ?? "na"
        let topCategoryDeltaBucket = ctx.topCategoryDeltaPercent
            .map { String(Int(($0 / 5.0).rounded()) * 5) } ?? "na"
        let topWeekdayToken = ctx.topWeekday ?? "na"

        return [
            ctx.state.rawValue,
            scoreToken,
            percentToken,
            trendToken,
            daysBucket,
            ctx.locale,
            name,
            incomeBucket,
            expenseBucket,
            availableBucket,
            prevExpenseBucket,
            topCategoryToken,
            topCategoryDeltaBucket,
            topWeekdayToken,
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
