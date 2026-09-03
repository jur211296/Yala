//
//  CurrencyConverter.swift
//  Yala
//
//  Central converter for all currency conversions in the app.
//  Uses stored exchange rates from ExchangeRateService.
//

import Foundation
import Observation
import SwiftData
import os.lock

// MARK: - Notification

extension Notification.Name {
    /// Posted by ExchangeRateService after persisting fresh today's exchange rates.
    /// Subscribers should invalidate any cached "latest rate" data and reload UI.
    static let yalaExchangeRatesUpdated = Notification.Name("yalaExchangeRatesUpdated")
}

// MARK: - Rate Quality

/// De dónde salió la tasa con la que se convirtió un monto.
///
/// **No es un `Bool` ni un opcional a propósito.** `getRatesForDate` ya degradaba en tres escalones
/// —fila del día, fila anterior, tabla estática— pero los colapsaba todos en un `[String: Double]`
/// indistinguible, y por eso el cuarto estado («la fila existe pero no trae esta divisa») podía
/// devolver el monto crudo sin que nadie se enterara. Quien PERSISTE necesita saber cuál de los
/// cuatro fue: solo el primero puede sellarse como definitivo.
enum RateQuality: Equatable {
    /// La fila de esa fecha traía las divisas pedidas.
    case exact
    /// Faltaba alguna y se completó con la fila real más reciente anterior. Aproximado pero del orden
    /// correcto; se marca provisional para que el reparador vuelva cuando lleguen las tasas del día.
    case carriedForward(fromDateKey: String)
    /// Hubo que recurrir a la tabla estática de `CurrencyCode`. Siempre da número y nunca envejece
    /// sola: es la señal más fuerte de que esa fecha necesita un refetch.
    case staticFallback

    /// Si esto es `false`, quien escriba el monto debe marcarlo `isExchangeRateProvisional`.
    var isExact: Bool { self == .exact }
}

// MARK: - Currency Converting Protocol

/// Protocol for currency conversion without ModelContext dependency.
/// Enables dependency injection and testing of calculators/helpers.
protocol CurrencyConverting {
    func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal
    func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal
}

// MARK: - Currency Converter

/// Central currency converter that uses stored exchange rates.
/// All conversions in the app should go through this class.
/// Supports @Environment injection in SwiftUI views.
@MainActor
@Observable
final class CurrencyConverter: CurrencyConverting {

    // MARK: - Singleton (for backward compatibility)

    /// Shared instance for backward compatibility. Prefer @Environment injection in Views.
    /// `nonisolated`: lets nonisolated pure-logic calculators/helpers reference it as a default
    /// argument (`converter: CurrencyConverting = CurrencyConverter.shared`). The conversion path
    /// is already engineered for cross-actor reads (lock-protected rates cache).
    nonisolated static let shared = CurrencyConverter()

    /// `nonisolated` initializer so the `nonisolated` `shared` singleton can be constructed off
    /// any actor. Every stored property has a default (or is optional → nil) and none require the
    /// main actor, so an empty nonisolated init is sound.
    nonisolated init() {}

    // MARK: - Properties

    @ObservationIgnored private var modelContext: ModelContext?
    private let baseCurrency = "USD"

    /// Thread-safe cache of latest exchange rates (TC actual). Read on every
    /// `convertWithLatestRate` to avoid hitting SwiftData per call. Invalidated
    /// cuando `ExchangeRateService` persiste rates frescos (via
    /// `.yalaExchangeRatesUpdated`) y al cambiar de día (sin esa invalidación
    /// implícita, una sesión que cruza medianoche seguiría usando los rates
    /// del día anterior aunque `Date.now` ya apunte a uno nuevo).
    @ObservationIgnored
    private let latestRatesCache = OSAllocatedUnfairLock<CachedRates?>(initialState: nil)

    private struct CachedRates {
        let rates: [String: Double]
        let dayKey: String  // dateKey (yyyy-MM-dd UTC) usado para la lectura
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    // MARK: - Fallback Rates (used when no stored rate available)

    /// Static fallback rates for when API data is unavailable.
    /// IMPORTANT: These are APPROXIMATE rates and should only be used
    /// as a last resort when: no API data, no internet, and no cached rates.
    /// All rates are relative to USD (base currency).
    /// Derived from CurrencyCode enum (single source of truth).
    private var fallbackRates: [String: Double] { CurrencyCode.fallbackRates }

    // MARK: - Context Setup

    /// Sets the ModelContext for database-backed conversions.
    /// Called from AppBootstrapper during app initialization.
    func setContext(_ context: ModelContext?) {
        self.modelContext = context
    }

    // MARK: - CurrencyConverting (context-free)

    /// Converts using the stored ModelContext, falling back to static rates if unavailable.
    func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal {
        guard let context = modelContext else {
            return convertWithFallback(amount, from: from, to: to)
        }
        return convert(amount, from: from, to: to, on: date, context: context)
    }

    /// Converts using the most recent available rate (context-free).
    func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal {
        guard let context = modelContext else {
            return convertWithFallback(amount, from: from, to: to)
        }
        return convertWithLatestRate(amount, from: from, to: to, context: context)
    }

    // MARK: - Public API (with context)

    /// Converts an amount from one currency to another using the rate for a specific date.
    /// - Parameters:
    ///   - amount: The amount to convert
    ///   - from: Source currency code (will be normalized)
    ///   - to: Target currency code (will be normalized)
    ///   - date: The date to use for the exchange rate
    ///   - context: SwiftData ModelContext for fetching rates
    /// - Returns: The converted amount
    func convert(
        _ amount: Decimal,
        from: String,
        to: String,
        on date: Date,
        context: ModelContext
    ) -> Decimal {
        convertChecked(amount, from: from, to: to, on: date, context: context).amount
    }

    /// Igual que `convert`, pero además dice **de dónde salió la tasa**.
    ///
    /// Existe porque `convert` devuelve `Decimal` a secas y su llamador no puede distinguir «convertí»
    /// de «no pude y te devuelvo lo que me diste» — y hay 21 sitios que PERSISTEN ese número en disco
    /// y lo emiten por el canal nube. Quien escribe usa esto para marcar
    /// `isExchangeRateProvisional` cuando la tasa no fue exacta, que es lo que permite que
    /// `TransactionUpdateService` vuelva a pasar y lo repare. Quien solo PINTA el número puede seguir
    /// usando `convert`.
    func convertChecked(
        _ amount: Decimal,
        from: String,
        to: String,
        on date: Date,
        context: ModelContext
    ) -> (amount: Decimal, quality: RateQuality) {
        let fromCode = normalizeCurrencyCode(from)
        let toCode = normalizeCurrencyCode(to)

        // Misma divisa: no hay conversión que hacer y la tasa es exacta por definición, no por dato.
        if fromCode == toCode {
            return (amount, .exact)
        }

        let resolved = resolveRates(for: date, needing: [fromCode, toCode], context: context)
        return (
            performConversion(amount: amount, from: fromCode, to: toCode, rates: resolved.rates),
            resolved.quality
        )
    }

    /// Converts using the most recent available rate (for "today" calculations).
    /// Uses an in-memory cache invalidated by `.yalaExchangeRatesUpdated` to
    /// avoid SwiftData fetches on every call (LiveBalanceCalculator does
    /// M conversions per render).
    /// - Parameters:
    ///   - amount: The amount to convert
    ///   - from: Source currency code
    ///   - to: Target currency code
    ///   - context: SwiftData ModelContext
    /// - Returns: The converted amount
    func convertWithLatestRate(
        _ amount: Decimal,
        from: String,
        to: String,
        context: ModelContext
    ) -> Decimal {
        let fromCode = normalizeCurrencyCode(from)
        let toCode = normalizeCurrencyCode(to)

        if fromCode == toCode {
            return amount
        }

        let rates = cachedLatestRates(context: context)
        return performConversion(amount: amount, from: fromCode, to: toCode, rates: rates)
    }

    /// Invalidates the latest-rates cache. Call after `ExchangeRateService`
    /// persists fresh rates so subsequent conversions read updated data.
    /// `nonisolated`: only touches the thread-safe `OSAllocatedUnfairLock`, so it is safe to
    /// call from anywhere — including the `@Sendable` `.yalaExchangeRatesUpdated` observer.
    nonisolated func invalidateLatestRatesCache() {
        latestRatesCache.withLock { $0 = nil }
    }

    #if DEBUG
    /// Test-only accessor for cache state. Avoids flaky NotificationCenter
    /// integration tests by allowing direct inspection.
    var _testCacheState: [String: Double]? {
        latestRatesCache.withLock { $0?.rates }
    }
    #endif

    /// Synchronous conversion using fallback rates (no database access).
    /// Use this only when ModelContext is not available (e.g., in static calculators).
    /// Will be deprecated once all calculators are updated to use async version.
    func convertWithFallback(
        _ amount: Decimal,
        from: String,
        to: String
    ) -> Decimal {
        let fromCode = normalizeCurrencyCode(from)
        let toCode = normalizeCurrencyCode(to)

        if fromCode == toCode {
            return amount
        }

        return performConversion(amount: amount, from: fromCode, to: toCode, rates: fallbackRates)
    }

    /// Gets the exchange rate between two currencies for display purposes.
    /// Returns format: "1 FROM = X.XX TO"
    func getDisplayRate(
        from: String,
        to: String,
        date: Date = Date.now,
        context: ModelContext
    ) -> Double? {
        let fromCode = normalizeCurrencyCode(from)
        let toCode = normalizeCurrencyCode(to)

        if fromCode == toCode {
            return 1.0
        }

        // Este método YA era honesto —devuelve `nil` cuando falta la divisa, veinte líneas encima del
        // `guard` que devolvía el monto crudo—, así que aquí el cambio solo le da mejor material: con
        // los escalones destapados, «no hay tasa» pasa a ser de verdad excepcional.
        let rates = resolveRates(for: date, needing: [fromCode, toCode], context: context).rates

        guard let fromRate = rates[fromCode], let toRate = rates[toCode] else {
            return nil
        }

        // Convert 1 unit of 'from' to 'to'
        // If base is USD: 1 FROM in USD = 1 / fromRate
        // Then to 'to': (1 / fromRate) * toRate
        if fromCode == baseCurrency {
            return toRate
        } else if toCode == baseCurrency {
            return fromRate > 0 ? 1.0 / fromRate : nil
        } else {
            return fromRate > 0 ? toRate / fromRate : nil
        }
    }

    /// Checks if an exact exchange rate exists for a specific date.
    /// Used to determine if a transaction's exchange rate is provisional (fallback) or official.
    /// - Parameters:
    ///   - date: The date to check
    ///   - context: SwiftData ModelContext
    /// - Returns: `true` si la fila de esa fecha trae las divisas pedidas.
    ///
    /// **El parámetro `needing` NO tiene default a propósito, y ésa es la corrección de fondo.** Hasta
    /// el 2026-09-03 esta función respondía solo por que la FILA EXISTIERA
    /// (`fetchExchangeRate(...) != nil`), y sus cinco llamadores leían esa respuesta como «tengo la
    /// tasa». Sobre una fila parcial —existe, pero sin la divisa que hace falta— decía `true`, la
    /// conversión devolvía el monto crudo y quien escribía lo sellaba con
    /// `isExchangeRateProvisional = false`: un 1:1 marcado como oficial que ningún proceso volvía a
    /// revisar. Obligar a nombrar las divisas hace que la pregunta vieja ya no sea expresable
    /// (`fx-partial-rate-rows-silent-1to1`).
    ///
    /// Hoy no la llama nadie —los cinco call-sites usan `convertChecked`, que además devuelve el
    /// monto— y se conserva porque la pregunta «¿es exacta la tasa de esta fecha?» es legítima por sí
    /// misma. Si vuelve a tener un consumidor que persista, que use la calidad de `convertChecked`.
    func hasExactRate(for date: Date, needing codes: Set<String>, context: ModelContext) -> Bool {
        let dateKey = dateFormatter.string(from: date)
        guard let row = fetchExchangeRate(for: dateKey, context: context) else { return false }
        return codes.isSubset(of: Set(row.decodedRates().keys))
    }

    // MARK: - Private Helpers

    /// Resuelve las tasas de una fecha **para las divisas que hacen falta**, bajando por los tres
    /// escalones hasta completarlas, y dice de dónde salió la peor de ellas.
    ///
    /// **El bug que esto arregla (`fx-partial-rate-rows-silent-1to1`), y su forma exacta.** La versión
    /// anterior cortaba en el primer escalón por EXISTENCIA: `if let exactRate = fetch(...) { return
    /// exactRate.decodedRates() }`. Una fila que existía pero no traía la divisa pedida devolvía su
    /// diccionario incompleto, `performConversion` salía por su `guard let` y devolvía el monto CRUDO
    /// —1000 JPY contados como 1000 PEN— presentándolo como bueno.
    ///
    /// Lo perverso es que la tasa **sí estaba disponible dos escalones más abajo**: una fila parcial
    /// era ESTRICTAMENTE PEOR que no tener fila, porque sin fila se llegaba a la tabla estática, que
    /// cubre las 54 divisas por construcción (`CurrencyCode.allCases.map`) y convierte bien. La fila
    /// no es que faltara información: es que TAPABA la que había. Pinneado en
    /// `CurrencyConverterPartialRateTests.noRowAtAll_convertsBetterThanAPartialRow`.
    ///
    /// **La trampa al destapar los escalones, y por eso este método no usa `fetchMostRecentRate`:**
    /// su predicado es `$0.dateKey <= dateKey` con `fetchLimit = 1`, o sea INCLUSIVO — sobre una fila
    /// parcial de hoy devuelve *esa misma fila* y el escalón no aporta nada. Aquí se piden las filas
    /// **estrictamente anteriores** y se recorren hasta cubrir lo que falta.
    ///
    /// `needing` vacío = «lo que traiga la fila», que es la semántica que necesita la caché de últimas
    /// tasas: no sabe qué divisas le van a pedir después.
    private func resolveRates(
        for date: Date,
        needing codes: Set<String>,
        context: ModelContext
    ) -> (rates: [String: Double], quality: RateQuality) {
        let dateKey = dateFormatter.string(from: date)

        var merged = fetchExchangeRate(for: dateKey, context: context)?.decodedRates() ?? [:]
        func missing() -> Set<String> { codes.subtracting(merged.keys) }

        if !merged.isEmpty && missing().isEmpty {
            return (merged, .exact)
        }

        // Escalón 2: filas anteriores, de la más reciente hacia atrás, rellenando SOLO lo que falta —
        // una tasa real de otro día es mejor aproximación que la tabla estática, que no envejece.
        var carriedFrom: String?
        if !missing().isEmpty {
            for previous in fetchRates(strictlyBefore: dateKey, limit: Self.carryForwardLookback, context: context) {
                let previousRates = previous.decodedRates()
                for code in missing() where previousRates[code] != nil {
                    merged[code] = previousRates[code]
                    if carriedFrom == nil { carriedFrom = previous.dateKey }
                }
                if missing().isEmpty { break }
            }
        }

        // Escalón 3: lo que siga faltando, de la tabla estática.
        var usedStatic = false
        for code in missing() {
            if let staticRate = fallbackRates[code] {
                merged[code] = staticRate
                usedStatic = true
            }
        }

        if merged.isEmpty { return (fallbackRates, .staticFallback) }
        if usedStatic { return (merged, .staticFallback) }
        if let carriedFrom { return (merged, .carriedForward(fromDateKey: carriedFrom)) }
        return (merged, .exact)
    }

    /// Cuántas filas anteriores se miran como mucho al completar una fecha. Acotado a propósito: es
    /// una consulta por conversión y el caso normal se resuelve en la primera.
    private static let carryForwardLookback = 30

    private func fetchRates(
        strictlyBefore dateKey: String,
        limit: Int,
        context: ModelContext
    ) -> [ExchangeRate] {
        var descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { $0.dateKey < dateKey },
            sortBy: [SortDescriptor(\ExchangeRate.dateKey, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("CurrencyConverter: Error fetching previous rates: \(error)")
            #endif
            return []
        }
    }

    /// Returns latest rates from cache or fetches and caches them on miss.
    /// Lock-protected for thread-safety (CurrencyConverter is a singleton
    /// reachable from any actor; cache must be safe for concurrent reads).
    private func cachedLatestRates(context: ModelContext) -> [String: Double] {
        let now = Date.now
        let todayKey = dateFormatter.string(from: now)
        if let cached = latestRatesCache.withLock({ $0 }), cached.dayKey == todayKey {
            return cached.rates
        }
        // `needing: []` = «lo que traiga la fila»: esta caché se llena antes de saber qué divisas le
        // van a pedir, así que no puede completar por adelantado. Los consumidores que sí saben
        // (`convert`/`convertChecked`) resuelven por su cuenta.
        let rates = resolveRates(for: now, needing: [], context: context).rates
        latestRatesCache.withLock { $0 = CachedRates(rates: rates, dayKey: todayKey) }
        return rates
    }

    private func performConversion(
        amount: Decimal,
        from fromCode: String,
        to toCode: String,
        rates: [String: Double]
    ) -> Decimal {
        guard let fromRate = rates[fromCode], let toRate = rates[toCode] else {
            // If rates not available, return original amount
            return amount
        }

        guard fromRate > 0 else {
            return amount
        }

        // Convert to base currency (USD), then to target currency
        // Rate represents: 1 USD = X currency
        // So: amountInUSD = amount / fromRate
        // Then: amountInTarget = amountInUSD * toRate

        if fromCode == baseCurrency {
            // Direct: amount * toRate
            return amount * Decimal(toRate)
        } else if toCode == baseCurrency {
            // Direct: amount / fromRate
            return amount / Decimal(fromRate)
        } else {
            // Cross conversion through USD
            let amountInBase = amount / Decimal(fromRate)
            return amountInBase * Decimal(toRate)
        }
    }

    private func fetchExchangeRate(for dateKey: String, context: ModelContext) -> ExchangeRate? {
        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            #if DEBUG
            print("CurrencyConverter: Error fetching rate: \(error)")
            #endif
            return nil
        }
    }

    private func fetchMostRecentRate(onOrBefore dateKey: String, context: ModelContext)
        -> ExchangeRate?
    {
        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { $0.dateKey <= dateKey },
            sortBy: [SortDescriptor(\ExchangeRate.dateKey, order: .reverse)]
        )

        do {
            var limitedDescriptor = descriptor
            limitedDescriptor.fetchLimit = 1
            let results = try context.fetch(limitedDescriptor)
            return results.first
        } catch {
            #if DEBUG
            print("CurrencyConverter: Error fetching fallback rate: \(error)")
            #endif
            return nil
        }
    }
}
