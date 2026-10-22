//
//  FXRepairQueueTests.swift
//  YalaTests
//
//  La cola de reparación de tasas provisionales tiene salida.
//  Ticket `repair-queue-has-no-exit-for-partial-rate-rows`.
//
//  **Qué se prueba aquí y por qué no bastaba lo que había.** `CurrencyConverterPartialRateTests`
//  pinnea que una fila parcial CONVIERTE bien (baja los escalones en vez de devolver el monto crudo).
//  Lo que ningún test podía poner rojo es lo que pasa DESPUÉS: que el reparador de arranque vuelva a
//  recorrer esa misma transacción en cada arranque sin poder curarla, reescribiendo las cuatro
//  columnas del grupo `money` —y emitiéndolas al canal nube— cada vez, para siempre. El bucle no se
//  ve en una pasada: hace falta correr el recálculo DOS veces y mirar si la segunda escribió.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct FXRepairQueueTests {

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Contexto in-memory con UNA fila de tasas para `date`, con exactamente las divisas que se pidan.
    ///
    /// `cloudKitDatabase: .none` NO es decorativo: con el default `.automatic` SwiftData adjunta el
    /// mirror de CloudKit a un store in-memory y el `save()` mata el proceso en un simulador sin cuenta
    /// iCloud (`.claude/rules/testing.md`). Molde de `CurrencyConverterPartialRateTests`.
    private func makeContext(on date: Date, rates: [String: Double]) throws -> ModelContext {
        let schema = Schema([ExchangeRate.self, TransactionItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let row = try ExchangeRate(
            dateKey: Self.dateFormatter.string(from: date),
            base: "USD",
            ratesDictionary: rates
        )
        context.insert(row)
        try context.save()
        return context
    }

    /// Una divisa que NO es la preferida del entorno de test, para que la conversión sea real.
    /// Se lee del entorno en vez de fijarse: la preferida sale de `UserDefaults.standard` y otro test
    /// puede haberla movido — fijar "PEN" a ciegas haría que este test se volviera trivial en silencio.
    private var foreignCode: String {
        CurrencyDefaults.currentPreferred == "JPY" ? "PEN" : "JPY"
    }

    // MARK: - AC 5: dos pasadas no reescriben dos veces

    /// **El test del ticket.** Fila parcial (existe, pero sin la divisa de la transacción) y sin red:
    /// el segundo recálculo no debe escribir nada. Hoy reescribía las cuatro columnas del grupo
    /// `money` y las volvía a emitir con un HLC fresco.
    @Test func partialRow_secondRecalculateWritesNothing() throws {
        let date = Date.now
        let preferred = CurrencyDefaults.currentPreferred
        let foreign = foreignCode

        // Fila PARCIAL: trae la base y la preferida, pero NO la divisa de la transacción.
        let context = try makeContext(on: date, rates: ["USD": 1.0, preferred: 3.75])
        let tx = TransactionItem(date: date, amount: 1000, currencyCode: foreign)
        context.insert(tx)
        try context.save()

        // Pasada 1: convierte por el escalón que pueda y se marca provisional.
        tx.recalculatePreferredCurrency(context: context)
        #expect(
            tx.isExchangeRateProvisional,
            "una fila sin la divisa de la transacción no puede dar una tasa exacta")
        let rateAfterFirst = tx.exchangeRate
        let amountAfterFirst = tx.amountInPreferredCurrency
        try context.save()
        #expect(context.hasChanges == false, "premisa del test: el save deja el contexto limpio")

        // Pasada 2 — el arranque siguiente, sin que haya llegado ninguna tasa nueva.
        tx.recalculatePreferredCurrency(context: context)

        #expect(
            context.hasChanges == false,
            """
            El segundo recálculo escribió sobre la transacción sin que nada cambiara. \
            Cada escritura expande al grupo de coherencia `money` entero y le sella un HLC nuevo, \
            así que esto es una emisión al canal nube por arranque y por transacción marcada.
            """)
        #expect(tx.exchangeRate == rateAfterFirst)
        #expect(tx.amountInPreferredCurrency == amountAfterFirst)
        #expect(tx.isExchangeRateProvisional)
    }

    /// **Control positivo del test de arriba.** Sin esto, un `recalculatePreferredCurrency` que no
    /// escribiera NUNCA pasaría igual de verde: hay que ver el contexto ensuciarse cuando sí toca.
    @Test func completedRow_recalculateWritesAndSealsAsFinal() throws {
        let date = Date.now
        let preferred = CurrencyDefaults.currentPreferred
        let foreign = foreignCode

        let context = try makeContext(on: date, rates: ["USD": 1.0, preferred: 3.75])
        let tx = TransactionItem(date: date, amount: 1000, currencyCode: foreign)
        context.insert(tx)
        try context.save()

        tx.recalculatePreferredCurrency(context: context)
        try context.save()
        #expect(tx.isExchangeRateProvisional, "premisa: arranca provisional por la fila parcial")

        // Llega la tasa que faltaba. Deliberadamente distinta de la de la tabla estática, para que el
        // monto convertido cambie de valor y no solo cambie el flag.
        let rows = try context.fetch(FetchDescriptor<ExchangeRate>())
        let row = try #require(rows.first)
        var merged = row.decodedRates()
        merged[foreign] = 123.456
        row.rates = try JSONEncoder().encode(merged)
        try context.save()
        #expect(context.hasChanges == false, "premisa: el contexto queda limpio antes de medir")

        tx.recalculatePreferredCurrency(context: context)

        #expect(
            context.hasChanges,
            """
            Con la divisa ya cubierta, el recálculo TIENE que escribir. Si esto sale verde con el \
            contexto limpio, el guard de igualdad está cortando cambios reales y ninguna transacción \
            se curaría nunca.
            """)
        #expect(
            tx.isExchangeRateProvisional == false,
            "una tasa exacta sí puede sellarse como definitiva")
    }

    // MARK: - AC 1: la cobertura pregunta por divisa, no por existencia de fila

    @Test func coverage_partialRowDoesNotCoverMissingCurrency() {
        let partial = ["USD": 1.0, "PEN": 3.75]
        #expect(ExchangeRateCoverageLogic.covers(partial, needing: ["JPY", "PEN"]) == false)
        #expect(ExchangeRateCoverageLogic.covers(partial, needing: ["USD", "PEN"]))
    }

    /// La trampa que dejaría el bucle vivo para un subconjunto de filas: una tasa `0` tiene su clave
    /// presente, pero `CurrencyConverter` la trata como ausente y degrada. Si la cobertura contara la
    /// clave, diría «cubierta» de algo que nunca dará una conversión exacta.
    @Test func coverage_unusableRateCountsAsMissing() {
        #expect(
            ExchangeRateCoverageLogic.covers(["USD": 1.0, "JPY": 0], needing: ["JPY"]) == false)
        #expect(
            ExchangeRateCoverageLogic.covers(["USD": 1.0, "JPY": -3], needing: ["JPY"]) == false)
        #expect(ExchangeRateCoverageLogic.covers(["USD": 1.0, "JPY": 150.0], needing: ["JPY"]))
    }

    /// `needing: []` = «que traiga algo servible», la semántica de quien no sabe qué le pedirán.
    @Test func coverage_emptyNeedsMeansAnyUsableRate() {
        #expect(ExchangeRateCoverageLogic.covers(["USD": 1.0], needing: []))
        #expect(ExchangeRateCoverageLogic.covers([:], needing: []) == false)
        #expect(ExchangeRateCoverageLogic.covers(["USD": 0], needing: []) == false)
    }

    @Test func coverage_uncoveredDateKeys_separatesMissingPartialAndComplete() {
        let coverage: [String: Set<String>] = [
            "2026-09-02": ["USD", "PEN", "JPY"],  // completa
            "2026-09-03": ["USD", "PEN"],  // parcial: sin JPY
            // "2026-09-04" no existe
        ]
        let uncovered = ExchangeRateCoverageLogic.uncoveredDateKeys(
            among: ["2026-09-02", "2026-09-03", "2026-09-04"],
            coverage: coverage,
            needing: ["JPY", "PEN"])

        #expect(uncovered == ["2026-09-03", "2026-09-04"])
    }

    // MARK: - AC 3: la salida del bucle

    @Test func sweep_runsWhenThereIsNoFutileFingerprint() {
        let current = FXRepairQueueLogic.fingerprint(provisionalCount: 12, uncoveredDateCount: 4)
        #expect(FXRepairQueueLogic.shouldSkipSweep(current: current, lastFutile: nil) == false)
    }

    @Test func sweep_skipsWhenNothingChangedSinceAFutileSweep() {
        let current = FXRepairQueueLogic.fingerprint(provisionalCount: 12, uncoveredDateCount: 4)
        #expect(FXRepairQueueLogic.shouldSkipSweep(current: current, lastFutile: current))
    }

    /// Las dos formas de que «algo haya cambiado». Si cualquiera de las dos dejara de reabrir el
    /// barrido, una cola curable se quedaría sin curar — que es peor que el bucle que esto arregla.
    ///
    /// La segunda es la que importa y la que motivó rehacer la huella: mide la COBERTURA en disco, no
    /// un contador de escrituras nuestras. Unas tasas que bajan por CloudKit o por el applier del Modo
    /// Nube no ejecutan una línea de nuestro código, y con un contador el barrido se habría saltado
    /// teniendo ya la cura en el disco.
    @Test func sweep_reopensWhenCoverageOrQueueMoved() {
        let futile = FXRepairQueueLogic.fingerprint(provisionalCount: 12, uncoveredDateCount: 4)

        let ratesArrived = FXRepairQueueLogic.fingerprint(
            provisionalCount: 12, uncoveredDateCount: 3)
        #expect(
            FXRepairQueueLogic.shouldSkipSweep(current: ratesArrived, lastFutile: futile) == false)

        let queueGrew = FXRepairQueueLogic.fingerprint(provisionalCount: 13, uncoveredDateCount: 4)
        #expect(FXRepairQueueLogic.shouldSkipSweep(current: queueGrew, lastFutile: futile) == false)
    }

    /// La huella no puede confundir dos estados distintos por concatenarlos mal (`1|23` vs `12|3`).
    @Test func fingerprint_isUnambiguous() {
        #expect(
            FXRepairQueueLogic.fingerprint(provisionalCount: 1, uncoveredDateCount: 23)
                != FXRepairQueueLogic.fingerprint(provisionalCount: 12, uncoveredDateCount: 3))
    }

    // MARK: - AC 1, extremo a extremo: `ensureRates` sobre el store real

    /// **Estos dos tests existen porque los de lógica pura de arriba NO prueban el camino.** Entre la
    /// decisión de cobertura y el refetch hay un `#Predicate` nuevo sobre `dateKey` (rango de Strings),
    /// y en este repo un `#Predicate` puede compilar limpio y reventar al EJECUTARSE contra el store
    /// —la regla del `#Predicate` genérico y la del `localizedStandardContains` sobre opcional son las
    /// dos cicatrices—. Aquí el predicado se ejecuta de verdad, y el provider falso deja ver la única
    /// decisión que importa: si se pide la fecha o no. Sin red.
    @Test func ensureRates_withFullCoverage_doesNotHitProvider() async throws {
        let date = Date.now
        let preferred = CurrencyDefaults.currentPreferred
        let foreign = foreignCode

        let context = try makeContext(
            on: date, rates: ["USD": 1.0, preferred: 3.75, foreign: 150.0])
        let provider = RecordingRateProvider()
        let service = ExchangeRateService(provider: provider)

        await service.ensureRates(
            for: DateInterval(start: date, end: date), needing: [foreign, preferred],
            context: context)

        #expect(
            provider.timeseriesCalls.isEmpty,
            "la fila cubre las dos divisas: pedirla otra vez sería trabajo por nada")
    }

    /// **El test del ticket, en el camino real.** Con el código anterior esta llamada NO pedía nada:
    /// `rateExists` veía la fila, respondía «no falta nada» y el reparador se quedaba sin la divisa que
    /// necesitaba, arranque tras arranque.
    @Test func ensureRates_withPartialRow_refetchesThatDate() async throws {
        let date = Date.now
        let preferred = CurrencyDefaults.currentPreferred
        let foreign = foreignCode

        // Fila PARCIAL: existe y trae la preferida, pero no la divisa que hace falta.
        let context = try makeContext(on: date, rates: ["USD": 1.0, preferred: 3.75])
        let provider = RecordingRateProvider()
        let service = ExchangeRateService(provider: provider)

        await service.ensureRates(
            for: DateInterval(start: date, end: date), needing: [foreign, preferred],
            context: context)

        #expect(
            provider.timeseriesCalls.count == 1,
            """
            Una fila a la que le falta la divisa pedida TIENE que volver a pedirse. Si esto sale en \
            cero, la cola de reparación no tiene salida: la conversión seguirá degradando y la \
            transacción se re-marcará provisional en cada arranque.
            """)
        let requested = try #require(provider.timeseriesCalls.first)
        #expect(
            Self.dateFormatter.string(from: requested.start)
                == Self.dateFormatter.string(from: date))
    }
    // MARK: - Lo que trajo la review adversarial

    /// **El tope de la API.** `preloadHistoricalIfNeeded` ya troceaba mes a mes con el motivo escrito
    /// al lado —«exchangerate.host allows max 365 days per request»— pero `ensureRates` no troceaba
    /// nada. Daba igual mientras preguntaba por EXISTENCIA de fila: sobre un histórico ya descargado
    /// no pedía nunca. Al pasar a cobertura por divisa, un histórico entero sin una divisa es el caso
    /// NORMAL, y con él la petición de varios años que el proveedor rechaza entera — o sea, cero
    /// curación y el usuario esperando delante del spinner de cambio de divisa.
    @Test func longRange_isChunkedIntoRequestsTheProviderAccepts() async throws {
        let calendar = Calendar.current
        let end = Date.now
        let start = try #require(calendar.date(byAdding: .day, value: -900, to: end))

        // Contexto SIN ninguna fila: los 901 días cuentan como descubiertos.
        let context = try makeContext(on: end, rates: [:])
        let provider = RecordingRateProvider()
        let service = ExchangeRateService(provider: provider)

        await service.ensureRates(
            for: DateInterval(start: start, end: end), needing: ["JPY"], context: context)

        #expect(provider.timeseriesCalls.count >= 3, "901 días no caben en menos de 3 peticiones")
        for call in provider.timeseriesCalls {
            let days =
                (calendar.dateComponents([.day], from: call.start, to: call.end).day ?? 0) + 1
            #expect(days <= 365, "una petición de \(days) días: la API rechaza más de 365")
        }
    }

    /// **La cola pide sus FECHAS, no su rango.** Con dos transacciones separadas por años, pedir el
    /// intervalo `min…max` refetchea el histórico completo en cada intento —si al proveedor le falta
    /// esa divisa, le falta todos los días— y eso cae en el camino crítico del arranque.
    @Test func uncoveredDates_answersForTheGivenDatesOnly() throws {
        let calendar = Calendar.current
        let today = Date.now
        let longAgo = try #require(calendar.date(byAdding: .day, value: -800, to: today))

        let context = try makeContext(on: today, rates: ["USD": 1.0, "PEN": 3.75])
        let service = ExchangeRateService(provider: RecordingRateProvider())

        let uncovered = service.uncoveredDates(
            among: [longAgo, today], needing: ["PEN"], context: context)

        #expect(
            uncovered.count == 1,
            "solo la fecha antigua está descubierta; el rango entre ambas no se pregunta")
        #expect(
            Self.dateFormatter.string(from: try #require(uncovered.first))
                == Self.dateFormatter.string(from: longAgo))
    }

    /// **La última fecha de la cola no puede perderse por la hora del día.** Recorrer el rango día a
    /// día parte de la hora de `min` y compara contra `max`: con horas distintas —lo normal en cuanto
    /// se mezclan un import a medianoche y una entrada manual por la tarde— el último día podía no
    /// generarse nunca, y es justo la transacción más nueva, la que más probablemente está pendiente.
    @Test func uncoveredDates_includesTheLatestDateWhenTimesOfDayDiffer() throws {
        let calendar = Calendar.current
        let midnight = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 0, minute: 0)))
        let evening = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 21, minute: 30)))

        let context = try makeContext(on: midnight, rates: [:])
        let service = ExchangeRateService(provider: RecordingRateProvider())

        let uncovered = service.uncoveredDates(
            among: [midnight, evening], needing: ["PEN"], context: context)
        let keys = Set(uncovered.map { Self.dateFormatter.string(from: $0) })

        #expect(
            keys.contains(Self.dateFormatter.string(from: evening)),
            "la fecha más reciente de la cola tiene que poder pedirse")
        #expect(keys.count == 2)
    }
}

// MARK: - Provider falso

/// Registra qué se le pidió y no toca la red. Solo `fetchTimeseries` importa aquí: es el camino de
/// `ensureRates`. Devuelve vacío a propósito — lo que se mide es la DECISIÓN de pedir, no lo que
/// llegue después.
@MainActor
private final class RecordingRateProvider: ExchangeRateProviderProtocol {
    private(set) var timeseriesCalls: [(start: Date, end: Date, symbols: [String])] = []

    func fetchLatest(base: String, symbols: [String]) async throws -> LiveRateResult {
        LiveRateResult(rates: [:], timestamp: nil)
    }

    func fetchTimeseries(
        base: String, symbols: [String], startDate: Date, endDate: Date
    ) async throws -> [String: [String: Double]] {
        timeseriesCalls.append((startDate, endDate, symbols))
        return [:]
    }
}

// MARK: - La premisa del guard, medida en el canal nube

/// **Este archivo entero existe por una afirmación que no estaba medida en ningún sitio del repo.**
/// El guard de igualdad de `recalculatePreferredCurrency` se justifica diciendo que asignar un valor
/// idéntico ensucia la fila igual y acaba emitiendo el grupo `money` al canal nube. Medido antes de
/// escribir esto: `updatedAttributes` —de donde salen las columnas del delta
/// (`CloudSyncEngine.translateChange`)— aparece cuatro veces en todo el repo y **ninguna regla, test o
/// documento afirma ni niega ese comportamiento de SwiftData**.
///
/// Y `context.hasChanges`, que es lo que asertan los tests de arriba, **no es la misma señal**: mide el
/// contexto, no el change-set que el History entrega al drain. Aquí se cuenta lo que de verdad
/// importa —filas de `SyncOutbox`— siguiendo la lección del repo: *re-escribir el mismo valor deja el
/// store idéntico y el mutante no cae*, así que hay que **contar escrituras**, no leer el estado final.
///
/// Andamio (containers on-disk con los 3 stores, `.serialized`) tomado de `CloudSyncEngineTests`: el
/// History es por-CONTAINER y el motor lee de ahí.
@Suite("FX · la reescritura idéntica y el canal nube", .serialized)
@MainActor
struct FXRepairQueueOutboxTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FXRepairOutbox-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "FXR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "FXR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "FXR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Reescribir una columna del grupo `money` con su MISMO valor: ¿emite?
    @Test func identicalRewriteOfMoneyColumn_versusRealChange() throws {
        let dir = freshDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let context = try makeContext(dir)

        let tx = TransactionItem(
            date: Date(timeIntervalSince1970: 1_700_000_000), amount: 10, currencyCode: "USD")
        tx.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(tx)
        try context.save()

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)
        let afterInsert = try context.fetch(FetchDescriptor<SyncOutbox>()).count
        #expect(afterInsert > 0, "premisa: el insert emite; sin esto lo de abajo no mide nada")

        // Reescritura IDÉNTICA.
        tx.exchangeRate = tx.exchangeRate
        try context.save()
        engine.drainOnce(context: context)
        let afterIdentical = try context.fetch(FetchDescriptor<SyncOutbox>()).count

        // CONTROL POSITIVO: un valor DISTINTO en la misma columna TIENE que emitir. Sin esta mitad, un
        // drain que no emitiera nunca dejaría la aserción de arriba verde sin significar nada.
        tx.exchangeRate = 3.75
        try context.save()
        engine.drainOnce(context: context)
        let afterRealChange = try context.fetch(FetchDescriptor<SyncOutbox>()).count

        #expect(
            afterRealChange > afterIdentical,
            "control positivo: un cambio real de exchangeRate emite al canal")

        // Lo que se mide. El valor de esta aserción está en el número, no en el veredicto: si SwiftData
        // NO ensuciara ante una asignación idéntica, el guard seguiría siendo correcto (ahorra el save)
        // pero la justificación del comentario habría que reescribirla.
        #expect(
            afterIdentical == afterInsert,
            """
            Una reescritura idéntica produjo \(afterIdentical - afterInsert) fila(s) nueva(s) en el \
            outbox. Eso es exactamente el daño que el guard de igualdad corta: el grupo `money` entero \
            emitido con un HLC fresco sin que ningún valor haya cambiado.
            """)
    }

}
