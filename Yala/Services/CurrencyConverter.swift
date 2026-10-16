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

    /// Cuánto se degradó, para poder quedarse con la peor de dos. Una conversión toca DOS divisas y
    /// vale lo que valga la peor de las dos: decir `.exact` porque una de ellas lo era es
    /// exactamente el tipo de verdad a medias que este enum existe para impedir.
    var severity: Int {
        switch self {
        case .exact: return 0
        case .carriedForward: return 1
        case .staticFallback: return 2
        }
    }

    static func worse(_ lhs: RateQuality, _ rhs: RateQuality) -> RateQuality {
        lhs.severity >= rhs.severity ? lhs : rhs
    }
}

// MARK: - Currency Converting Protocol

/// Protocol for currency conversion without ModelContext dependency.
/// Enables dependency injection and testing of calculators/helpers.
///
/// **Las variantes `…Checked` NO tienen implementación por defecto en una extensión, y es
/// deliberado.** Un default que devolviera `.exact` haría que cualquier conformer nuevo declarase
/// tasas perfectas por omisión — exactamente la forma del bug que este protocolo existe para cerrar
/// (`hasExactRate` respondía por que la FILA existiera, y sus cinco llamadores leían eso como «tengo
/// la tasa»). Añadir un conformer obliga a decidir qué calidad declara.
protocol CurrencyConverting {
    func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal
    func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal

    /// `convert` + de dónde salió la tasa. Quien PINTA un total lo usa para decidir si el número
    /// lleva la marca de aproximado.
    func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
        -> (amount: Decimal, quality: RateQuality)

    /// `convertWithLatestRate` + de dónde salió la tasa.
    func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
        -> (amount: Decimal, quality: RateQuality)

    /// Las tasas de VARIAS fechas a la vez: para cada fecha y cada divisa de `codes`, cuánto vale una unidad en
    /// `to` y de dónde salió la tasa. Da lo mismo que `convertChecked(1, from: code, to: to, on: fecha)` fecha a
    /// fecha (`CurrencyConverterDailyFactorsTests` lo compara); existe porque una curva de saldo valora cada día
    /// a su tipo de cambio y pedirlas una a una cuesta una consulta por día
    /// (`panel-balance-chart-contradicts-its-own-figure`).
    func rateFactors(for codes: Set<String>, to: String, on dates: [Date]) -> [Date: [String: RateFactor]]
}

/// Cuánto vale una unidad de una divisa en otra en una fecha, y de dónde salió la tasa. La conversión es lineal,
/// así que `importe × factor` es la conversión del importe.
struct RateFactor: Equatable {
    let factor: Decimal
    let quality: RateQuality
}

extension CurrencyConverting {
    /// Por defecto, fecha a fecha con `convertChecked`: la calidad es la que declara cada conformer, no una
    /// inventada aquí (ver la nota del protocolo sobre las variantes `…Checked`).
    func rateFactors(for codes: Set<String>, to: String, on dates: [Date]) -> [Date: [String: RateFactor]] {
        var out: [Date: [String: RateFactor]] = [:]
        for date in dates {
            var byCode: [String: RateFactor] = [:]
            for code in codes {
                let converted = convertChecked(1, from: code, to: to, on: date)
                byCode[code] = RateFactor(factor: converted.amount, quality: converted.quality)
            }
            out[date] = byCode
        }
        return out
    }
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
        var rates: [String: Double]
        let dayKey: String  // dateKey (yyyy-MM-dd UTC) usado para la lectura

        /// De qué escalón salió **cada** tasa, no el conjunto.
        ///
        /// **Guardar una sola calidad para toda la caché no servía, y el motivo se midió.** La
        /// primera versión la llenaba con `resolveRates(needing: [])`, que sin fila de hoy devuelve
        /// la tabla estática **entera**; como esa tabla cubre todas las divisas, la comprobación de
        /// cobertura daba siempre positiva y el escalón de la fila real anterior **no se alcanzaba
        /// nunca** por esta ruta. Medido el 2026-09-06 con una fila completa de ayer y ninguna de
        /// hoy: `convertWithLatestRate` devolvía 24,79 (tabla estática) mientras `convert(on:)`
        /// devolvía 40 (la fila de ayer) — dos APIs, el mismo instante, la que más pinta eligiendo
        /// la peor fuente. Con el origen por divisa la caché solo afirma lo que sabe.
        var origins: [String: RateQuality]
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
        convertChecked(amount, from: from, to: to, on: date).amount
    }

    /// Converts using the most recent available rate (context-free).
    func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal {
        convertCheckedWithLatestRate(amount, from: from, to: to).amount
    }

    func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
        -> (amount: Decimal, quality: RateQuality)
    {
        guard let context = modelContext else {
            return (convertWithFallback(amount, from: from, to: to), contextFreeQuality(from, to))
        }
        return convertChecked(amount, from: from, to: to, on: date, context: context)
    }

    func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
        -> (amount: Decimal, quality: RateQuality)
    {
        guard let context = modelContext else {
            return (convertWithFallback(amount, from: from, to: to), contextFreeQuality(from, to))
        }
        return convertCheckedWithLatestRate(amount, from: from, to: to, context: context)
    }

    /// Sin `ModelContext` no hay tasas guardadas que consultar: la conversión sale de la tabla
    /// estática, que es aproximada por definición. La única excepción es la identidad —convertir una
    /// divisa a sí misma es exacto por construcción, no por dato— y distinguirla importa: sin ella,
    /// el arranque de la app (antes de `setContext`) marcaría como aproximado cualquier total
    /// monomoneda, que es el caso de la inmensa mayoría de los usuarios.
    private func contextFreeQuality(_ from: String, _ to: String) -> RateQuality {
        normalizeCurrencyCode(from) == normalizeCurrencyCode(to) ? .exact : .staticFallback
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
        convertCheckedWithLatestRate(amount, from: from, to: to, context: context).amount
    }

    /// Igual que `convertWithLatestRate`, pero además dice **de dónde salió la tasa**.
    ///
    /// **El bug que esto cierra, medido el 2026-09-06 con la fila parcial del día: 1000 JPY salían
    /// como 1000 PEN.** `fx-partial-rate-rows-silent-1to1` destapó los tres escalones en
    /// `resolveRates`, pero esta ruta no llegaba a aprovecharlos: la caché se llena con `needing: []`
    /// —no puede saber qué divisas le van a pedir después— así que una fila parcial de hoy entraba
    /// entera en la caché y `performConversion` salía por su `guard let`, devolviendo el monto crudo.
    /// Otra vez la fila parcial resultaba ESTRICTAMENTE PEOR que no tener fila: sin fila la caché se
    /// llena con la tabla estática, que cubre todas las divisas y convierte bien (medido: 24,79 PEN).
    ///
    /// El arreglo es preguntar si la caché cubre de verdad las dos divisas ANTES de usarla, y
    /// resolver nombrándolas cuando no. El caso normal —fila completa— sigue dando acierto de caché
    /// y no paga ningún fetch; solo el caso patológico consulta, que es donde importa acertar.
    func convertCheckedWithLatestRate(
        _ amount: Decimal,
        from: String,
        to: String,
        context: ModelContext
    ) -> (amount: Decimal, quality: RateQuality) {
        let fromCode = normalizeCurrencyCode(from)
        let toCode = normalizeCurrencyCode(to)

        if fromCode == toCode {
            return (amount, .exact)
        }

        let cached = cachedLatestRates(context: context)
        if let fromQuality = cached.origins[fromCode], let toQuality = cached.origins[toCode] {
            return (
                performConversion(amount: amount, from: fromCode, to: toCode, rates: cached.rates),
                .worse(fromQuality, toQuality)
            )
        }

        // La caché no cubre alguna de las dos: se resuelve NOMBRÁNDOLAS, que es lo que hace bajar por
        // los escalones —incluido el de la fila real anterior, que es mejor que la tabla estática—, y
        // se funde para que la siguiente conversión de esa divisa no repita la consulta. Sin la
        // fusión, un día sin fila de tasas pagaría dos fetches por cada importe convertido, y hay
        // llamadores que convierten dentro de un bucle anidado (pagos × ocurrencias).
        let now = Date.now
        let resolved = resolveRates(for: now, needing: [fromCode, toCode], context: context)
        mergeIntoLatestCache(
            rates: resolved.rates,
            quality: resolved.quality,
            for: [fromCode, toCode],
            dayKey: dateFormatter.string(from: now)
        )
        return (
            performConversion(amount: amount, from: fromCode, to: toCode, rates: resolved.rates),
            resolved.quality
        )
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

        // El filtro NO es decorativo: una tasa `0` guardada pasaba la comprobación de presencia,
        // nunca contaba como ausente, y `performConversion` acababa devolviendo el monto CRUDO (o un
        // 0, si el cero estaba en la divisa de destino) etiquetado `.exact`. Tratarla como ausente
        // desde aquí deja que los escalones la rescaten, que es lo que ya hacen con una que falta.
        var merged = (fetchExchangeRate(for: dateKey, context: context)?.decodedRates() ?? [:])
            .filter { Self.isUsableRate($0.value) }
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
                for code in missing() {
                    guard let rate = previousRates[code], Self.isUsableRate(rate) else { continue }
                    merged[code] = rate
                    if carriedFrom == nil { carriedFrom = previous.dateKey }
                }
                if missing().isEmpty { break }
            }
        }

        // Escalón 3: lo que siga faltando, de la tabla estática.
        var usedStatic = false
        let staticTable = fallbackRates
        for code in missing() {
            if let staticRate = staticTable[code], Self.isUsableRate(staticRate) {
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

    // MARK: - Tasas de varias fechas en bloque

    /// `rateFactors` sin una consulta por fecha: lee de una vez las filas del rango —y las `carryForwardLookback`
    /// anteriores, que el escalón 2 de la primera fecha puede necesitar— y aplica a cada fecha y cada par
    /// `(divisa, to)` la MISMA escalera que `resolveRates`: la fila del día, las anteriores rellenando solo lo que
    /// falta, la tabla estática. Por par y no con todas las divisas a la vez, como `convertChecked`: con todas, una
    /// divisa sin tasa le empeoraría la calidad a las demás.
    ///
    /// **Si tocas `resolveRates`, toca esto**: `CurrencyConverterDailyFactorsTests` compara las dos rutas sobre
    /// filas parciales, huecos y tasas a cero, y se pone rojo si divergen.
    func rateFactors(for codes: Set<String>, to: String, on dates: [Date]) -> [Date: [String: RateFactor]] {
        guard let context = modelContext, !dates.isEmpty else {
            var out: [Date: [String: RateFactor]] = [:]
            for date in dates {
                var byCode: [String: RateFactor] = [:]
                for code in codes {
                    let converted = convertChecked(1, from: code, to: to, on: date)
                    byCode[code] = RateFactor(factor: converted.amount, quality: converted.quality)
                }
                out[date] = byCode
            }
            return out
        }
        let toCode = normalizeCurrencyCode(to)
        let keyed = dates.map { (date: $0, key: dateFormatter.string(from: $0)) }
        guard let minKey = keyed.map(\.key).min(), let maxKey = keyed.map(\.key).max() else { return [:] }

        // Las filas del rango y las anteriores que el escalón 2 puede pedir, en orden de fecha.
        let previous = fetchRates(strictlyBefore: minKey, limit: Self.carryForwardLookback, context: context)
        let inRange = fetchRates(from: minKey, through: maxKey, context: context)
        // Sin quitar duplicados de una misma fecha (dos dispositivos pueden escribir la fila del día): el escalón 2 de
        // `resolveRates` los recorre todos y cuenta cada uno en sus 30, y aquí tiene que ser igual. La fila «propia» de
        // una fecha es la primera de su clave, como en `fetchExchangeRate`.
        let rows: [(key: String, rates: [String: Double])] = (previous + inRange)
            .sorted { $0.dateKey < $1.dateKey }
            .map { ($0.dateKey, $0.decodedRates().filter { Self.isUsableRate($0.value) }) }
        var rowIndexByKey: [String: Int] = [:]
        for (index, row) in rows.enumerated() where rowIndexByKey[row.key] == nil { rowIndexByKey[row.key] = index }
        let staticTable = fallbackRates

        var out: [Date: [String: RateFactor]] = [:]
        for (date, key) in keyed {
            // Las filas estrictamente anteriores a la fecha, de la más reciente hacia atrás, como `fetchRates`.
            let upper = rowIndexByKey[key] ?? rows.firstIndex { $0.key > key } ?? rows.count
            let before = rows[..<upper].suffix(Self.carryForwardLookback).reversed()
            let own = rowIndexByKey[key].map { rows[$0].rates } ?? [:]

            var byCode: [String: RateFactor] = [:]
            for rawCode in codes {
                let fromCode = normalizeCurrencyCode(rawCode)
                if fromCode == toCode {
                    byCode[rawCode] = RateFactor(factor: 1, quality: .exact)
                    continue
                }
                let needing: Set<String> = [fromCode, toCode]
                var merged = own
                func missing() -> Set<String> { needing.subtracting(merged.keys) }
                var quality: RateQuality = .exact
                if merged.isEmpty || !missing().isEmpty {
                    var carriedFrom: String?
                    for row in before where !missing().isEmpty {
                        for code in missing() {
                            guard let rate = row.rates[code], Self.isUsableRate(rate) else { continue }
                            merged[code] = rate
                            if carriedFrom == nil { carriedFrom = row.key }
                        }
                    }
                    var usedStatic = false
                    for code in missing() {
                        if let staticRate = staticTable[code], Self.isUsableRate(staticRate) {
                            merged[code] = staticRate
                            usedStatic = true
                        }
                    }
                    if merged.isEmpty {
                        merged = staticTable
                        quality = .staticFallback
                    } else if usedStatic {
                        quality = .staticFallback
                    } else if let carriedFrom {
                        quality = .carriedForward(fromDateKey: carriedFrom)
                    }
                }
                byCode[rawCode] = RateFactor(
                    factor: performConversion(amount: 1, from: fromCode, to: toCode, rates: merged),
                    quality: quality
                )
            }
            out[date] = byCode
        }
        return out
    }

    private func fetchRates(from fromKey: String, through toKey: String, context: ModelContext) -> [ExchangeRate] {
        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { $0.dateKey >= fromKey && $0.dateKey <= toKey },
            sortBy: [SortDescriptor(\ExchangeRate.dateKey)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("CurrencyConverter: Error fetching rates in range: \(error)")
            #endif
            return []
        }
    }

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
    /// Siembra la caché con **solo lo que trae la fila de hoy**, nada más.
    ///
    /// No completa con escalones inferiores a propósito: esta caché se llena antes de saber qué
    /// divisas le van a pedir, y rellenarla «por si acaso» con la tabla estática es justo lo que
    /// mataba el carry-forward (ver `CachedRates.origins`). Lo que falte se resuelve **nombrándolo**
    /// en `convertCheckedWithLatestRate`, y se funde aquí para no repetir la consulta.
    private func cachedLatestRates(context: ModelContext) -> CachedRates {
        let todayKey = dateFormatter.string(from: Date.now)
        if let cached = latestRatesCache.withLock({ $0 }), cached.dayKey == todayKey {
            return cached
        }
        let row = fetchExchangeRate(for: todayKey, context: context)?.decodedRates() ?? [:]
        let usable = row.filter { Self.isUsableRate($0.value) }
        let entry = CachedRates(
            rates: usable,
            dayKey: todayKey,
            origins: usable.mapValues { _ in RateQuality.exact }
        )
        latestRatesCache.withLock { $0 = entry }
        return entry
    }

    /// Funde en la caché de hoy las divisas que hubo que resolver aparte, con el escalón del que
    /// salieron, para que la siguiente conversión de esa misma divisa no repita la consulta.
    ///
    /// **Si la caché fue invalidada mientras se resolvía, la fusión se descarta.** Escribir aquí
    /// resucitaría la entrada previa al refresco y la dejaría viva hasta medianoche, con tasas
    /// viejas y una etiqueta de calidad que ya no corresponde.
    private func mergeIntoLatestCache(
        rates: [String: Double],
        quality: RateQuality,
        for codes: Set<String>,
        dayKey: String
    ) {
        latestRatesCache.withLock { entry in
            guard var current = entry, current.dayKey == dayKey else { return }
            for code in codes where current.rates[code] == nil {
                guard let rate = rates[code], Self.isUsableRate(rate) else { continue }
                current.rates[code] = rate
                current.origins[code] = quality
            }
            entry = current
        }
    }

    /// Una tasa solo sirve si es finita y estrictamente positiva.
    ///
    /// **Un `0` guardado era indistinguible de una tasa buena** y se colaba por tres sitios que no
    /// coincidían: la cobertura preguntaba por existencia de la clave, `missing()` también, y solo
    /// `performConversion` exigía `> 0` — y cuando salía por ahí devolvía el monto **crudo**
    /// etiquetado `.exact`, que es el bug original de este ticket por otra puerta. Peor en el otro
    /// sentido: un `0` en la divisa de destino devolvía **0** sellado como exacto. Ahora las tres
    /// preguntas son la misma y una tasa inservible se trata como ausente, así que los escalones la
    /// rescatan.
    /// `nonisolated`: es aritmética pura sobre un `Double` y se consulta desde dentro del closure
    /// del lock, que no está aislado al main actor.
    nonisolated static func isUsableRate(_ rate: Double) -> Bool { rate.isFinite && rate > 0 }

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

        // `toRate` no se comprobaba: un 0 en la divisa de DESTINO no devolvía el monto crudo sino
        // un **0**, que es peor porque parece un dato. Hoy `resolveRates` ya filtra las inservibles,
        // así que esto es la segunda red, no la primera.
        guard Self.isUsableRate(fromRate), Self.isUsableRate(toRate) else {
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
