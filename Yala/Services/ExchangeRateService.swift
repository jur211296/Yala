//
//  ExchangeRateService.swift
//  Yala
//
//  Business logic for managing exchange rates.
//  Handles persistence, caching, and API coordination.
//

import Foundation
import Observation
import SwiftData

// MARK: - Exchange Rate Service Protocol

/// Protocol for exchange rate management, enabling dependency injection and testing.
protocol ExchangeRateServiceProtocol {
    func preloadHistoricalIfNeeded(context: ModelContext) async
    func updateTodayIfNeeded(context: ModelContext) async
    func forceUpdateToday(context: ModelContext) async
    func ensureRates(for dateRange: DateInterval, context: ModelContext) async
    func ensureRates(for dateRange: DateInterval, needing codes: Set<String>, context: ModelContext)
        async
    func forceRefreshRates(for dateRange: DateInterval, context: ModelContext) async
    func ensureRatesForExistingTransactions(context: ModelContext) async
    func getRate(for date: Date, context: ModelContext) -> ExchangeRate?
    func getMostRecentRate(onOrBefore date: Date, context: ModelContext) -> ExchangeRate?
    func getLatestRate(context: ModelContext) -> ExchangeRate?
    func getOldestRate(context: ModelContext) -> ExchangeRate?
    func getStoredDateRange(context: ModelContext) -> DateInterval?
}

// MARK: - Exchange Rate Service

/// Service responsible for managing exchange rate data.
/// Handles fetching from API and persisting to SwiftData.
/// Supports @Environment injection in SwiftUI views.
@Observable
@MainActor
final class ExchangeRateService: ExchangeRateServiceProtocol {

    // MARK: - Singleton (for backward compatibility)

    /// Shared instance for backward compatibility. Prefer @Environment injection in Views.
    static let shared = ExchangeRateService(provider: ExchangeRateAPIService())

    // MARK: - Properties

    private let provider: ExchangeRateProviderProtocol
    private let baseCurrency = "USD"
    // All supported currencies - derived from CurrencyCode enum (single source of truth)
    private var supportedSymbols: [String] { CurrencyCode.allRawValues }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    // UserDefaults keys
    private let lastHistoricalLoadKey = "exchangeRate_lastHistoricalLoad"
    private let lastTodayUpdateKey = "exchangeRate_lastTodayUpdate"
    /// Tope de días por petición al proveedor. **Lo impone la API, no nosotros**
    /// (`preloadHistoricalIfNeeded` ya troceaba mes a mes por este motivo), y hasta ahora
    /// `ensureRates` no lo respetaba porque en la práctica nunca pedía rangos largos: preguntaba por
    /// EXISTENCIA de fila, así que sobre un histórico ya descargado no pedía nada. Al pasar a
    /// preguntar por cobertura de divisa, un histórico entero sin una divisa pasa a ser el caso
    /// normal — y con él, la petición de varios años que el proveedor rechaza entera.
    private static let maxDaysPerRequest = 365

    // MARK: - Initialization

    init(provider: ExchangeRateProviderProtocol) {
        self.provider = provider
    }

    // MARK: - Public API

    /// Preloads historical exchange rates if needed (last 12 months).
    /// Should be called on first app launch or after data reset.
    func preloadHistoricalIfNeeded(context: ModelContext) async {
        // Check if we've already loaded historical data
        let lastLoad = UserDefaults.standard.object(forKey: lastHistoricalLoadKey) as? Date

        // Only reload if never loaded or more than 30 days ago
        if let lastLoad = lastLoad {
            let daysSinceLoad =
                Calendar.current.dateComponents([.day], from: lastLoad, to: Date.now).day ?? 0
            if daysSinceLoad < 30 {
                return
            }
        }

        // Check if we already have enough data
        let existingCount = countExistingRates(context: context)
        if existingCount > 300 {  // ~1 year of data
            UserDefaults.standard.set(Date.now, forKey: lastHistoricalLoadKey)
            return
        }

        // Get only required currencies (preferred + secondary + account currencies)
        let requiredCurrencies = Array(getRequiredCurrencies(context: context))

        // Load last 12 months in chunks to avoid API limits
        let calendar = Calendar.current
        let today = Date.now

        // Fetch in monthly chunks (exchangerate.host allows max 365 days per request)
        for monthOffset in 0..<12 {
            guard let chunkEnd = calendar.date(byAdding: .month, value: -monthOffset, to: today),
                let chunkStart = calendar.date(byAdding: .month, value: -1, to: chunkEnd)
            else {
                continue
            }

            do {
                try await fetchAndPersistRates(
                    from: chunkStart, to: chunkEnd, symbols: requiredCurrencies, context: context)
                // Small delay between requests to avoid rate limiting
                try? await Task.sleep(for: .seconds(0.5))
            } catch {
                #if DEBUG
                print(
                    "ExchangeRateService: Error loading historical chunk: \(error.localizedDescription)"
                )
                #endif
                // Continue with other chunks even if one fails
            }
        }

        UserDefaults.standard.set(Date.now, forKey: lastHistoricalLoadKey)
    }

    /// Updates today's exchange rate if not already fetched.
    /// Should be called on app launch and when opening Panel.
    ///
    /// **Preguntaba si la fila de hoy EXISTÍA, y ésa es la mitad del bucle que el usuario nota.** La
    /// fila de hoy es la que más transacciones marca provisionales —son las que acaba de apuntar—, y
    /// una fila de hoy parcial se quedaba parcial: existía, así que este método volvía en el acto sin
    /// pedir nada, y el reparador no tenía de dónde sacar la divisa que faltaba. Ahora la condición es
    /// la cobertura de lo que esta app usa de verdad (`getRequiredCurrencies`: preferida, secundarias
    /// del widget y las de las cuentas), no las 48 soportadas: exigir las 48 haría un refetch en cada
    /// arranque para siempre en cuanto el proveedor no sirviera una divisa exótica que nadie mira —el
    /// mismo bucle con otra ropa.
    func updateTodayIfNeeded(context: ModelContext) async {
        let todayKey = dateFormatter.string(from: Date.now)

        // Check if we already have today's rate, con las divisas que esta app necesita
        if rateCovers(getRequiredCurrencies(context: context), for: todayKey, context: context) {
            return
        }

        // Segundo freno, y sin él la cobertura sería un bucle: si alguna divisa requerida no viene
        // NUNCA en la respuesta del proveedor, la fila de hoy jamás cubre y esto pediría otra vez en
        // cada arranque y en cada apertura del formulario de transacción, para siempre. Con el freno,
        // el peor caso es UNA petición por día. La clave ya se escribía desde siempre; lo que no había
        // era quien la leyera.
        if let lastAttempt = UserDefaults.standard.object(forKey: lastTodayUpdateKey) as? Date,
            dateFormatter.string(from: lastAttempt) == todayKey
        {
            return
        }

        do {
            let result = try await provider.fetchLatest(
                base: baseCurrency, symbols: supportedSymbols)
            try persistRate(
                dateKey: todayKey, rates: result.rates, timestamp: result.timestamp,
                context: context)
            UserDefaults.standard.set(Date.now, forKey: lastTodayUpdateKey)
            NotificationCenter.default.post(name: .yalaExchangeRatesUpdated, object: nil)
        } catch {
            #if DEBUG
            print("ExchangeRateService: Error updating today's rate: \(error.localizedDescription)")
            #endif
            // Don't throw - app should continue working with cached rates
        }
    }

    /// Forces update of today's exchange rate even if it already exists.
    /// Used after onboarding to ensure we have ALL 7 currencies, not just the ones
    /// that might have been fetched earlier with a partial set.
    func forceUpdateToday(context: ModelContext) async {
        let todayKey = dateFormatter.string(from: Date.now)

        do {
            let result = try await provider.fetchLatest(
                base: baseCurrency, symbols: supportedSymbols)
            try persistRate(
                dateKey: todayKey, rates: result.rates, timestamp: result.timestamp,
                context: context)
            UserDefaults.standard.set(Date.now, forKey: lastTodayUpdateKey)
            NotificationCenter.default.post(name: .yalaExchangeRatesUpdated, object: nil)
            #if DEBUG
            print("ExchangeRateService: Force updated today's rate with all \(supportedSymbols.count) currencies")
            #endif
        } catch {
            #if DEBUG
            print("ExchangeRateService: Error force updating today's rate: \(error.localizedDescription)")
            #endif
        }
    }

    /// Forces a refresh of exchange rates for a date range.
    /// Only refetches dates that are missing OR don't have all currencies.
    /// Optimized to skip dates that already have complete data.
    func forceRefreshRates(for dateRange: DateInterval, context: ModelContext) async {
        let calendar = Calendar.current

        // Find dates that need refresh (missing or incomplete)
        var datesToRefresh: [Date] = []
        var currentDate = dateRange.start
        while currentDate <= dateRange.end {
            let dateKey = dateFormatter.string(from: currentDate)
            // Only add dates that don't have ALL currencies
            if !rateHasAllCurrencies(for: dateKey, context: context) {
                datesToRefresh.append(currentDate)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate.addingTimeInterval(86400)
        }

        guard !datesToRefresh.isEmpty else {
            #if DEBUG
            print("ExchangeRateService: All rates already have all currencies, skipping refresh")
            #endif
            return
        }

        #if DEBUG
        let totalDays = Int(dateRange.duration / 86400)
        print("ExchangeRateService: Refreshing \(datesToRefresh.count) of \(totalDays) days (skipped \(totalDays - datesToRefresh.count) complete)")
        #endif

        // Group into contiguous ranges for efficient fetching
        let ranges = groupIntoRanges(dates: datesToRefresh)

        for range in ranges {
            do {
                try await fetchAndPersistRates(from: range.start, to: range.end, context: context)
                // Small delay between requests
                try? await Task.sleep(for: .seconds(0.3))
            } catch {
                #if DEBUG
                print("ExchangeRateService: Error refreshing range \(range): \(error.localizedDescription)")
                #endif
            }
        }

        // La caché de últimas tasas del converter guarda, con cada tasa, el escalón del que salió.
        // Si este refresco trajo la fila de HOY —lo hace siempre que hoy estuviera incompleto, que
        // es su caso normal— y nadie invalida, el converter sigue sirviendo lo que sembró antes y
        // además lo sigue declarando aproximado hasta medianoche, con la fila buena ya en disco.
        // Los otros dos escritores de tasas ya postean esta señal; éste se quedó sin ella.
        NotificationCenter.default.post(name: .yalaExchangeRatesUpdated, object: nil)

        #if DEBUG
        print("ExchangeRateService: Force refresh complete")
        #endif
    }

    /// Ensures exchange rates exist for a given date range.
    /// Used after CSV import to fetch historical rates for imported transactions.
    ///
    /// Sin decir qué divisas, se pide la cobertura de las que **esta app usa**
    /// (`getRequiredCurrencies`). Es lo que quieren los cuatro llamadores que no son el reparador —una
    /// transacción nueva, un import, un cambio de divisa preferida—, y deja de responder «no falta
    /// nada» ante una fila que existe pero no trae la divisa del caso.
    func ensureRates(for dateRange: DateInterval, context: ModelContext) async {
        await ensureRates(
            for: dateRange, needing: getRequiredCurrencies(context: context), context: context)
    }

    /// Igual, pero para quien SÍ sabe qué divisas necesita.
    ///
    /// **Existe por el reparador de arranque, y es la salida que no tenía.** Las divisas de sus
    /// transacciones provisionales no tienen por qué estar en `getRequiredCurrencies`: una transacción
    /// en yenes de un viaje no deja ninguna cuenta en yenes detrás. Preguntando por lo que esa cola
    /// necesita de verdad, un refetch la cura; preguntando por lo genérico, se quedaría dando vueltas.
    func ensureRates(for dateRange: DateInterval, needing codes: Set<String>, context: ModelContext)
        async
    {
        let missingDates = findMissingDates(in: dateRange, needing: codes, context: context)
        await fetchRates(for: missingDates, context: context)
    }

    /// De las fechas dadas, las que **no** tienen cubiertas `codes`. No toca la red.
    ///
    /// **Es la versión por fechas SUELTAS, y para el reparador de arranque es la correcta.** Su cola
    /// son transacciones concretas, no un intervalo: pedir el rango `min…max` de una cola con un gasto
    /// de 2023 y otro de hoy son ~1.000 días, de los que solo interesan dos. Con el paso a cobertura
    /// por divisa eso dejó de ser teórico —si al proveedor le falta esa divisa, le falta todos los
    /// días del rango— y el barrido pasaba a refetchear el histórico entero en cada intento.
    ///
    /// De paso cierra un desajuste de fechas: recorrer el rango día a día parte de la hora de
    /// `min` y compara contra `max`, así que si las dos transacciones tienen hora distinta el último
    /// día podía no generarse nunca. Aquí cada fecha produce su clave directamente.
    func uncoveredDates(among dates: Set<Date>, needing codes: Set<String>, context: ModelContext)
        -> [Date]
    {
        guard let minDate = dates.min(), let maxDate = dates.max() else { return [] }
        let coverage = coverageByDateKey(
            in: DateInterval(start: minDate, end: maxDate), context: context)
        let keyed = dates.map { (key: dateFormatter.string(from: $0), date: $0) }
        let uncovered = Set(
            ExchangeRateCoverageLogic.uncoveredDateKeys(
                among: keyed.map(\.key), coverage: coverage, needing: codes))
        return keyed.filter { uncovered.contains($0.key) }.map(\.date).sorted()
    }

    /// Pide y persiste las tasas de esas fechas, agrupándolas en rangos contiguos.
    ///
    /// - Returns: `true` si **todas** las peticiones salieron bien. Distinguirlo importa: un fallo de
    ///   red es transitorio y merece reintento, mientras que «pedí y el proveedor no trae esa divisa»
    ///   es permanente. Quien decide si un barrido fue estéril necesita saber cuál de los dos fue, o
    ///   sella como imposible lo que solo estaba sin cobertura.
    @discardableResult
    func fetchRates(for dates: [Date], context: ModelContext) async -> Bool {
        guard !dates.isEmpty else { return true }

        var allSucceeded = true
        for range in groupIntoRanges(dates: dates) {
            do {
                try await fetchAndPersistRates(from: range.start, to: range.end, context: context)
                // Small delay between requests
                try? await Task.sleep(for: .seconds(0.3))
            } catch {
                allSucceeded = false
                #if DEBUG
                print(
                    "ExchangeRateService: Error fetching range \(range): \(error.localizedDescription)"
                )
                #endif
            }
        }
        return allSucceeded
    }

    /// Ensures exchange rates exist for all dates that have transactions.
    /// Should be called after onboarding or when secondary currencies change,
    /// to guarantee historical data for existing transactions.
    func ensureRatesForExistingTransactions(context: ModelContext) async {
        // Fetch all transactions to get date range
        let descriptor = FetchDescriptor<TransactionItem>(
            sortBy: [SortDescriptor(\TransactionItem.date, order: .forward)]
        )

        do {
            let transactions = try context.fetch(descriptor)
            guard !transactions.isEmpty,
                  let firstDate = transactions.first?.date,
                  let lastDate = transactions.last?.date else {
                #if DEBUG
                print("ExchangeRateService: No transactions found, skipping historical rates")
                #endif
                return
            }

            let dateInterval = DateInterval(start: firstDate, end: lastDate)
            #if DEBUG
            print("ExchangeRateService: Ensuring rates for transaction range: \(firstDate) to \(lastDate)")
            #endif

            await ensureRates(for: dateInterval, context: context)
        } catch {
            #if DEBUG
            print("ExchangeRateService: Error fetching transactions for rate sync: \(error)")
            #endif
        }
    }

    /// Gets the exchange rate for a specific date.
    /// Returns nil if not found (caller should use fallback logic).
    func getRate(for date: Date, context: ModelContext) -> ExchangeRate? {
        let dateKey = dateFormatter.string(from: date)
        return fetchExchangeRate(for: dateKey, context: context)
    }

    /// Gets the most recent exchange rate on or before the given date.
    /// Used as fallback when exact date rate is not available.
    func getMostRecentRate(onOrBefore date: Date, context: ModelContext) -> ExchangeRate? {
        let dateKey = dateFormatter.string(from: date)

        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { $0.dateKey <= dateKey },
            sortBy: [SortDescriptor(\ExchangeRate.dateKey, order: .reverse)]
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            #if DEBUG
            print("ExchangeRateService: Error fetching fallback rate: \(error)")
            #endif
            return nil
        }
    }

    /// Gets the most recent exchange rate available (for UI display).
    func getLatestRate(context: ModelContext) -> ExchangeRate? {
        let descriptor = FetchDescriptor<ExchangeRate>(
            sortBy: [SortDescriptor(\ExchangeRate.dateKey, order: .reverse)]
        )

        do {
            var fetchDescriptor = descriptor
            fetchDescriptor.fetchLimit = 1
            let results = try context.fetch(fetchDescriptor)
            return results.first
        } catch {
            #if DEBUG
            print("ExchangeRateService: Error fetching latest rate: \(error)")
            #endif
            return nil
        }
    }

    /// Gets the oldest exchange rate available (for determining data range).
    func getOldestRate(context: ModelContext) -> ExchangeRate? {
        let descriptor = FetchDescriptor<ExchangeRate>(
            sortBy: [SortDescriptor(\ExchangeRate.dateKey, order: .forward)]
        )

        do {
            var fetchDescriptor = descriptor
            fetchDescriptor.fetchLimit = 1
            let results = try context.fetch(fetchDescriptor)
            return results.first
        } catch {
            #if DEBUG
            print("ExchangeRateService: Error fetching oldest rate: \(error)")
            #endif
            return nil
        }
    }

    /// Gets the actual date range of stored exchange rates.
    /// Returns nil if no rates are stored.
    func getStoredDateRange(context: ModelContext) -> DateInterval? {
        guard let oldest = getOldestRate(context: context),
              let latest = getLatestRate(context: context) else {
            return nil
        }

        // Parse dateKey to Date
        let oldestDate = dateFormatter.date(from: oldest.dateKey) ?? Date.now
        let latestDate = dateFormatter.date(from: latest.dateKey) ?? Date.now

        return DateInterval(start: oldestDate, end: latestDate)
    }

    // MARK: - Private Helpers

    private func fetchAndPersistRates(
        from startDate: Date, to endDate: Date, symbols: [String]? = nil, context: ModelContext
    ) async throws {
        // Use provided symbols or default to all supported currencies
        let symbolsToFetch = symbols ?? supportedSymbols

        let rates = try await provider.fetchTimeseries(
            base: baseCurrency,
            symbols: symbolsToFetch,
            startDate: startDate,
            endDate: endDate
        )

        for (dateKey, dayRates) in rates {
            try persistRate(dateKey: dateKey, rates: dayRates, context: context)
        }
    }

    private func persistRate(
        dateKey: String, rates: [String: Double], timestamp: Date? = nil, context: ModelContext
    ) throws {
        // Gate de quiescencia: `ExchangeRate` vive en el store personal (CloudKit private) → su `save()`
        // durante el import del restore dispararía el `_assertionFailure`. Diferir (cache best-effort:
        // se re-cachea tras la quiescencia). Guard antes de fetch/insert para no dejar inserts pendientes.
        guard iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("ExchangeRateService.persistRate", "import not quiescent")
            return
        }
        // Check if rate already exists for this date
        if let existing = fetchExchangeRate(for: dateKey, context: context) {
            // FUSIÓN, no reemplazo (`fx-partial-rate-rows-silent-1to1`). `existing.rates = data`
            // descartaba todo lo que la fila ya tenía y el `rates` entrante no traía, y el mismo
            // ARRANQUE hacía las dos escrituras en el orden que peor le sienta: `updateTodayIfNeeded`
            // guarda hoy con las 54 divisas, y acto seguido `preloadHistoricalIfNeeded` —cuyo primer
            // chunk INCLUYE hoy— la repisa con las 2-4 de `getRequiredCurrencies`. El trabajo bueno se
            // perdía solo, todos los días, sin que nadie tocara nada.
            existing.rates = try JSONEncoder().encode(
                ExchangeRateMergeLogic.merged(existing: existing.decodedRates(), incoming: rates)
            )
            existing.timestamp = ExchangeRateMergeLogic.mergedTimestamp(
                existing: existing.timestamp, incoming: timestamp
            )
        } else {
            // Create new rate
            let newRate = try ExchangeRate(
                dateKey: dateKey,
                base: baseCurrency,
                ratesDictionary: rates,
                timestamp: timestamp
            )
            // Modo Nube I2: born-cloud identity capture (gateado DARK; no-op en producción hoy).
            SyncIdentityService.captureIfEnabled(newRate)
            context.insert(newRate)
        }

        SaveBreadcrumb.willSave("ExchangeRateService.persistRate")
        try context.save()
        SaveBreadcrumb.didSave("ExchangeRateService.persistRate")
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
            print("ExchangeRateService: Error fetching rate: \(error)")
            #endif
            return nil
        }
    }

    /// ¿La fila de esa fecha trae las divisas pedidas, con una tasa servible?
    ///
    /// **Sustituye a `rateExists`, que preguntaba solo si la fila existía.** Ésa era la pregunta que
    /// dejaba al reparador de arranque sin salida: sobre una fila parcial respondía «no falta nada»,
    /// `ensureRates` volvía en el acto, la conversión degradaba y la transacción se re-marcaba
    /// provisional en cada arranque, para siempre. La pregunta vieja ya no es expresable —igual que
    /// `CurrencyConverter.hasExactRate(for:needing:)` dejó de serlo por el mismo motivo.
    private func rateCovers(_ codes: Set<String>, for dateKey: String, context: ModelContext) -> Bool
    {
        guard let rate = fetchExchangeRate(for: dateKey, context: context) else { return false }
        return ExchangeRateCoverageLogic.covers(rate.decodedRates(), needing: codes)
    }

    /// Checks if a stored rate has ALL supported currencies.
    /// Returns false if any currency from CurrencyCode.allRawValues is missing.
    ///
    /// Ahora una tasa presente pero inservible (un `0` guardado) cuenta como ausente, igual que para
    /// `CurrencyConverter`: la fila con ceros se vuelve a pedir en vez de darse por completa.
    private func rateHasAllCurrencies(for dateKey: String, context: ModelContext) -> Bool {
        rateCovers(Set(CurrencyCode.allRawValues), for: dateKey, context: context)
    }

    private func countExistingRates(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<ExchangeRate>()
        do {
            return try context.fetchCount(descriptor)
        } catch {
            #if DEBUG
            print("ExchangeRateService: Error counting rates: \(error)")
            #endif
            return 0
        }
    }

    /// Qué días del rango hay que volver a pedir para cubrir `codes`.
    ///
    /// **Dos arreglos, y el segundo es el coste de arranque medido en el ticket.** (1) La condición era
    /// la existencia de la fila, no su cobertura. (2) Preguntaba con un `context.fetch` **por día**:
    /// tres años de histórico son ~1.100 fetches en cada arranque aunque no falte ni una fila, y esto
    /// va `await`-eado en el camino crítico del bootstrap. Un solo fetch del rango entero responde lo
    /// mismo; el recorrido día a día ya no toca disco.
    private func findMissingDates(
        in range: DateInterval, needing codes: Set<String>, context: ModelContext
    ) -> [Date] {
        let calendar = Calendar.current

        // Los días del rango, y su clave, en un solo recorrido.
        var datesByKey: [(key: String, date: Date)] = []
        var currentDate = range.start
        while currentDate <= range.end {
            datesByKey.append((dateFormatter.string(from: currentDate), currentDate))
            currentDate =
                calendar.date(byAdding: .day, value: 1, to: currentDate)
                ?? currentDate.addingTimeInterval(86400)
        }

        let coverage = coverageByDateKey(in: range, context: context)
        let uncovered = Set(
            ExchangeRateCoverageLogic.uncoveredDateKeys(
                among: datesByKey.map(\.key), coverage: coverage, needing: codes))

        return datesByKey.filter { uncovered.contains($0.key) }.map(\.date)
    }

    /// `dateKey → divisas servibles`, para todo el rango, en **un** fetch.
    ///
    /// El predicado compara claves `yyyy-MM-dd`, cuyo orden lexicográfico es el cronológico (mismo
    /// truco que `fetchMostRecentRate`). Si el fetch falla se devuelve vacío y todo el rango cuenta
    /// como faltante, que es lo que hacía la versión anterior ante un fetch fallido.
    private func coverageByDateKey(in range: DateInterval, context: ModelContext) -> [String:
        Set<String>]
    {
        let startKey = dateFormatter.string(from: range.start)
        let endKey = dateFormatter.string(from: range.end)
        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { $0.dateKey >= startKey && $0.dateKey <= endKey }
        )

        do {
            let rows = try context.fetch(descriptor)
            var coverage: [String: Set<String>] = [:]
            coverage.reserveCapacity(rows.count)
            for row in rows {
                coverage[row.dateKey] = ExchangeRateCoverageLogic.usableCurrencies(
                    in: row.decodedRates())
            }
            return coverage
        } catch {
            #if DEBUG
            print("ExchangeRateService: Error fetching rate coverage: \(error)")
            #endif
            return [:]
        }
    }

    /// Agrupa fechas sueltas en rangos contiguos **y trocea cada uno al tope del proveedor**.
    ///
    /// El troceo va aquí, y no en cada llamador, porque es la única función por la que pasan los tres
    /// caminos que piden tasas (`ensureRates`, `fetchRates`, `forceRefreshRates`). Ponerlo en uno solo
    /// habría dejado a los otros dos emitiendo la petición que la API rechaza — que es la forma exacta
    /// del bug que este ticket arregla: la misma pregunta contestada de dos maneras distintas.
    private func groupIntoRanges(dates: [Date]) -> [DateInterval] {
        chunked(contiguousRanges(dates: dates))
    }

    /// Parte cualquier rango más largo que `maxDaysPerRequest` en trozos que la API sí acepta.
    private func chunked(_ ranges: [DateInterval]) -> [DateInterval] {
        let calendar = Calendar.current
        var result: [DateInterval] = []

        for range in ranges {
            var chunkStart = range.start
            while chunkStart <= range.end {
                let tentativeEnd =
                    calendar.date(
                        byAdding: .day, value: Self.maxDaysPerRequest - 1, to: chunkStart)
                    ?? range.end
                let chunkEnd = min(tentativeEnd, range.end)
                result.append(DateInterval(start: chunkStart, end: chunkEnd))
                guard let next = calendar.date(byAdding: .day, value: 1, to: chunkEnd),
                    next > chunkStart  // sin avance no hay troceo posible: corta en vez de girar
                else { break }
                chunkStart = next
            }
        }
        return result
    }

    private func contiguousRanges(dates: [Date]) -> [DateInterval] {
        guard !dates.isEmpty else { return [] }

        let sortedDates = dates.sorted()
        var ranges: [DateInterval] = []
        var rangeStart = sortedDates[0]
        var rangeEnd = sortedDates[0]

        for date in sortedDates.dropFirst() {
            let daysDiff =
                Calendar.current.dateComponents([.day], from: rangeEnd, to: date).day ?? 0

            if daysDiff <= 1 {
                // Contiguous date, extend range
                rangeEnd = date
            } else {
                // Gap found, save current range and start new one
                ranges.append(DateInterval(start: rangeStart, end: rangeEnd))
                rangeStart = date
                rangeEnd = date
            }
        }

        // Don't forget the last range
        ranges.append(DateInterval(start: rangeStart, end: rangeEnd))

        return ranges
    }

    /// Returns the set of currency codes that need historical exchange rate data.
    /// Includes: preferred currency, secondary currencies, and currencies of existing accounts.
    private func getRequiredCurrencies(context: ModelContext) -> Set<String> {
        var required: Set<String> = []

        // 1. Preferred currency (always needed)
        let preferredCode = UserDefaults.standard.string(forKey: "defaultCurrencyCode") ?? "PEN"
        required.insert(preferredCode)

        // 2. Secondary currencies (for ExchangeRateWidget)
        if let secondaryRaw = UserDefaults.standard.string(forKey: "secondaryCurrencies"),
           !secondaryRaw.isEmpty
        {
            let secondary = secondaryRaw.split(separator: ",").map { String($0) }
            required.formUnion(secondary)
        }

        // 3. Currencies of existing accounts (for transaction conversions)
        let accountsDesc = FetchDescriptor<Account>()
        do {
            let accounts = try context.fetch(accountsDesc)
            let accountCurrencies = Set(accounts.map { $0.currencyCode })
            required.formUnion(accountCurrencies)
        } catch {
            #if DEBUG
                print("ExchangeRateService: Error fetching accounts for required currencies: \(error)")
            #endif
        }

        return required
    }
}
