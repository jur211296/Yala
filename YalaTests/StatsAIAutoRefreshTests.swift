//
//  StatsAIAutoRefreshTests.swift
//  YalaTests
//
//  Los textos con IA de Estadísticas se generan solos (encargo `estadisticas-ia-automatica`, 2026-11-03): la decisión
//  (`StatsAIAutoRefreshLogic`), su almacén (`StatsAIAutoRefreshStore`) y el camino automático de Tendencias
//  (`TrendsAIViewModel.autoRefresh`). El de Resumen va en `StatsAIAutoRefreshInsightsTests`.
//

import Foundation
import Testing

@testable import Yala

// MARK: - La decisión

struct StatsAIAutoRefreshLogicTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let snapshot = StatsAIAutoRefreshLogic.Snapshot(transactionCount: 20, totals: [1000, 500])
    private let nothingToday = StatsAIAutoRefreshLogic.Today(automaticCount: 0, anyCount: 0, lastForSlot: nil)

    private func saved(
        fingerprint: String = "old",
        hoursAgo: Double = 1,
        snapshot: StatsAIAutoRefreshLogic.Snapshot? = nil
    ) -> StatsAIAutoRefreshLogic.Saved {
        StatsAIAutoRefreshLogic.Saved(
            fingerprint: fingerprint,
            savedAt: now.addingTimeInterval(-hoursAgo * 3600),
            snapshot: snapshot ?? self.snapshot
        )
    }

    private func decide(
        isPro: Bool = true,
        hasConsent: Bool = true,
        count: Int = 20,
        saved: StatsAIAutoRefreshLogic.Saved?,
        fingerprint: String = "new",
        snapshot: StatsAIAutoRefreshLogic.Snapshot? = nil,
        today: StatsAIAutoRefreshLogic.Today? = nil
    ) -> StatsAIAutoRefreshLogic.Decision {
        StatsAIAutoRefreshLogic.decide(
            isPro: isPro,
            hasConsent: hasConsent,
            transactionCount: count,
            saved: saved,
            fingerprint: fingerprint,
            snapshot: snapshot ?? self.snapshot,
            today: today ?? nothingToday,
            now: now
        )
    }

    // MARK: Gating

    @Test("Sin Pro, sin consentimiento o con menos de 5 registros: nada")
    func gating() {
        #expect(decide(isPro: false, saved: nil) == .notAllowed)
        #expect(decide(hasConsent: false, saved: nil) == .notAllowed)
        #expect(decide(count: 4, saved: nil) == .notAllowed)
        #expect(decide(count: 5, saved: nil) == .generate(.firstTime), "Control: con 5 sí.")
    }

    // MARK: Disparador

    @Test("Sin nada guardado para la ranura, se genera")
    func firstTime() {
        #expect(decide(saved: nil) == .generate(.firstTime))
    }

    @Test("Mismas cifras que lo guardado: se queda, aunque tenga más de 24 h")
    func sameFingerprint_keepsEvenWhenOld() {
        #expect(decide(saved: saved(fingerprint: "same", hoursAgo: 1), fingerprint: "same") == .keepSaved)
        #expect(decide(saved: saved(fingerprint: "same", hoursAgo: 72), fingerprint: "same") == .keepSaved)
    }

    @Test("Un cambio relevante regenera")
    func relevantChange_generates() {
        let moved = StatsAIAutoRefreshLogic.Snapshot(transactionCount: 23, totals: [1000, 500])
        #expect(decide(saved: saved(), snapshot: moved) == .generate(.relevantChange))
    }

    @Test("Un cambio pequeño con lo guardado reciente: se queda")
    func smallChange_recent_keeps() {
        let nudged = StatsAIAutoRefreshLogic.Snapshot(transactionCount: 21, totals: [1050, 500])
        #expect(decide(saved: saved(hoursAgo: 3), snapshot: nudged) == .keepSaved)
    }

    @Test("Un cambio pequeño con lo guardado de más de 24 h: una regeneración al día")
    func smallChange_stale_generatesOncePerDay() {
        let nudged = StatsAIAutoRefreshLogic.Snapshot(transactionCount: 21, totals: [1050, 500])
        #expect(decide(saved: saved(hoursAgo: 25), snapshot: nudged) == .generate(.daily))
        let alreadyToday = StatsAIAutoRefreshLogic.Today(automaticCount: 1, anyCount: 1, lastForSlot: nil)
        #expect(decide(saved: saved(hoursAgo: 25), snapshot: nudged, today: alreadyToday) == .keepSaved,
                "La página ya generó hoy: «una al día» salvo cambio relevante.")
        #expect(decide(saved: saved(hoursAgo: 23.9), snapshot: nudged) == .keepSaved, "Vecino: 23,9 h aún vale.")
        #expect(decide(saved: saved(hoursAgo: 24), snapshot: nudged) == .generate(.daily), "Vecino: 24 h justas, toca.")
    }

    // MARK: Antirrebote

    @Test("Antirrebote: la misma ranura generada hace menos de 10 min no se vuelve a pedir")
    func cooldown() {
        let moved = StatsAIAutoRefreshLogic.Snapshot(transactionCount: 30, totals: [2000, 500])
        let justNow = StatsAIAutoRefreshLogic.Today(
            automaticCount: 1, anyCount: 1, lastForSlot: now.addingTimeInterval(-599)
        )
        #expect(decide(saved: saved(), snapshot: moved, today: justNow) == .keepSaved)
        let tenMinutes = StatsAIAutoRefreshLogic.Today(
            automaticCount: 1, anyCount: 1, lastForSlot: now.addingTimeInterval(-600)
        )
        #expect(decide(saved: saved(), snapshot: moved, today: tenMinutes) == .generate(.relevantChange))
        // También sin nada guardado: un intento que falló no se repite en cada recálculo.
        #expect(decide(saved: nil, today: justNow) == .keepSaved)
    }

    // MARK: Techo

    @Test("Techo duro: 4 automáticas por página y día, también ante un cambio relevante")
    func dailyCap() {
        let moved = StatsAIAutoRefreshLogic.Snapshot(transactionCount: 30, totals: [2000, 500])
        let three = StatsAIAutoRefreshLogic.Today(automaticCount: 3, anyCount: 3, lastForSlot: nil)
        let four = StatsAIAutoRefreshLogic.Today(automaticCount: 4, anyCount: 4, lastForSlot: nil)
        #expect(decide(saved: saved(), snapshot: moved, today: three) == .generate(.relevantChange))
        #expect(decide(saved: saved(), snapshot: moved, today: four) == .keepSaved)
        #expect(decide(saved: nil, today: four) == .keepSaved)
        // Lo manual no cuenta para el techo.
        let manual = StatsAIAutoRefreshLogic.Today(automaticCount: 0, anyCount: 9, lastForSlot: nil)
        #expect(decide(saved: nil, today: manual) == .generate(.firstTime))
    }

    // MARK: Umbral

    @Test("Umbral: ±3 registros o un total que se mueve un 10 %")
    func threshold() {
        let base = StatsAIAutoRefreshLogic.Snapshot(transactionCount: 20, totals: [1000, 500])
        func relevant(_ count: Int, _ totals: [Double]) -> Bool {
            StatsAIAutoRefreshLogic.isRelevantChange(
                from: base, to: StatsAIAutoRefreshLogic.Snapshot(transactionCount: count, totals: totals)
            )
        }
        #expect(!relevant(22, [1000, 500]))
        #expect(relevant(23, [1000, 500]))
        #expect(relevant(17, [1000, 500]))
        #expect(!relevant(20, [1099, 500]))
        #expect(relevant(20, [1100, 500]))
        #expect(relevant(20, [1000, 450]))
        #expect(relevant(20, [1000]), "Otra forma de pantalla cuenta como relevante.")
        // Un total que parte de cero no divide por cero.
        let zero = StatsAIAutoRefreshLogic.Snapshot(transactionCount: 20, totals: [0])
        #expect(StatsAIAutoRefreshLogic.isRelevantChange(
            from: zero, to: StatsAIAutoRefreshLogic.Snapshot(transactionCount: 20, totals: [1])
        ))
    }
}

// MARK: - El almacén

@MainActor
struct StatsAIAutoRefreshStoreTests {

    private func store() -> StatsAIAutoRefreshStore {
        StatsAIAutoRefreshStore(defaults: testDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    private let snapshot = StatsAIAutoRefreshLogic.Snapshot(transactionCount: 5, totals: [1])

    @Test("La ranura es estable y cambia con lo que la define")
    func slotKey() {
        let a = StatsAIAutoRefreshStore.slotKey(page: .summary, parts: ["period": "thisMonth", "filters": ["x": 1]])
        let b = StatsAIAutoRefreshStore.slotKey(page: .summary, parts: ["filters": ["x": 1], "period": "thisMonth"])
        #expect(a != nil)
        #expect(a == b)
        #expect(a != StatsAIAutoRefreshStore.slotKey(page: .trends, parts: ["period": "thisMonth", "filters": ["x": 1]]))
        #expect(a != StatsAIAutoRefreshStore.slotKey(page: .summary, parts: ["period": "lastMonth", "filters": ["x": 1]]))
    }

    @Test("Guarda la última respuesta de cada ranura")
    func saveAndRead() throws {
        let store = store()
        store.save(["uno"], page: .trends, slot: "A", fingerprint: "f1", snapshot: snapshot)
        store.save(["dos"], page: .trends, slot: "A", fingerprint: "f2", snapshot: snapshot)
        store.save(["otro"], page: .summary, slot: "A", fingerprint: "f3", snapshot: snapshot)
        let (entry, value) = try #require(store.response([String].self, page: .trends, slot: "A"))
        #expect(value == ["dos"])
        #expect(entry.fingerprint == "f2")
        #expect(store.response([String].self, page: .summary, slot: "A")?.1 == ["otro"])
        #expect(store.entry(page: .trends, slot: "B") == nil)
    }

    @Test("Cada página guarda como mucho sus ranuras más recientes")
    func capacity() {
        let store = store()
        for i in 0...StatsAIAutoRefreshStore.slotCapacity {
            store.save([i], page: .summary, slot: "s\(i)", fingerprint: "f", snapshot: snapshot)
        }
        store.save([0], page: .trends, slot: "t", fingerprint: "f", snapshot: snapshot)
        #expect(store.entry(page: .summary, slot: "s0") == nil)
        #expect(store.entry(page: .summary, slot: "s1") != nil)
        #expect(store.entry(page: .trends, slot: "t") != nil, "Las ranuras de otra página no cuentan.")
    }

    @Test("«Vaciar datos» borra las dos claves que el almacén escribe")
    func wipeKnowsTheKeys() throws {
        let defaults = testDefaults(suiteName: "test.\(UUID().uuidString)")!
        let store = StatsAIAutoRefreshStore(defaults: defaults)
        store.save(["x"], page: .summary, slot: "A", fingerprint: "f", snapshot: snapshot)
        store.recordGeneration(page: .summary, slot: "A", automatic: true)
        for key in StatsAIAutoRefreshStore.storageKeys {
            #expect(defaults.object(forKey: key) != nil, "El almacén no escribe «\(key)»: la lista del borrado divergió.")
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let wipe = try String(contentsOf: root.appendingPathComponent("Yala/Utils/DataWipeService.swift"), encoding: .utf8)
        #expect(wipe.contains("for key in StatsAIAutoRefreshStore.storageKeys { defaults.removeObject(forKey: key) }"))
    }

    @Test("El registro cuenta lo de hoy por página y separa lo automático")
    func ledger() {
        let store = store()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima")!
        let noon = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12))!
        let yesterday = noon.addingTimeInterval(-24 * 3600)
        store.recordGeneration(page: .summary, slot: "A", automatic: true, now: yesterday)
        store.recordGeneration(page: .summary, slot: "A", automatic: true, now: noon.addingTimeInterval(-60))
        store.recordGeneration(page: .summary, slot: "B", automatic: false, now: noon.addingTimeInterval(-30))
        store.recordGeneration(page: .trends, slot: "A", automatic: true, now: noon)
        let today = store.today(page: .summary, slot: "A", now: noon, calendar: calendar)
        #expect(today.automaticCount == 1)
        #expect(today.anyCount == 2)
        #expect(today.lastForSlot == noon.addingTimeInterval(-60))
    }
}

// MARK: - Tendencias, de punta a punta

@MainActor
struct TrendsAIAutoRefreshTests {

    private func input(total: Double) -> TrendsAIInput {
        TrendsAIInput(
            // Con comparativa: sin ella el total no viaja en el payload y dos totales distintos dan la misma huella.
            metric: .expense, periodLabel: "Mes", comparisonLabel: "Oct", currentTotal: total, previousTotal: 900,
            history: [], historyUnit: nil, cashFlow: nil, weekdaySpending: [], weekdayNames: [:],
            currencyCode: "PEN", currencyDisplay: "S/", locale: "es", country: "PE", filtersActive: false
        )
    }

    private func autoRequest(total: Double = 1000, count: Int = 20) throws -> TrendsAIViewModel.AutoRequest {
        try #require(TrendsAIViewModel.AutoRequest.make(
            input: input(total: total), transactionCount: count, slotParts: ["period": "thisMonth"],
            tone: .normal, focus: .balanced
        ))
    }

    private final class Calls { var count = 0 }

    private func viewModel(
        isPro: Bool = true,
        hasConsent: Bool = true,
        isOnline: Bool = true,
        store: StatsAIAutoRefreshStore,
        calls: Calls,
        fails: Bool = false,
        answer: String = "Nuevo"
    ) -> TrendsAIViewModel {
        TrendsAIViewModel(
            request: { _, _ in
                calls.count += 1
                if fails { throw InsightsLLMError.parseFailed }
                return [TrendsAIBullet(id: 0, source: .trend, text: answer)]
            },
            isPro: { isPro }, hasConsent: { hasConsent }, isOnline: { isOnline },
            store: store
        )
    }

    private func store() -> StatsAIAutoRefreshStore {
        StatsAIAutoRefreshStore(defaults: testDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    @Test("Sin Pro o sin consentimiento: ninguna llamada")
    func gating_noCalls() async throws {
        let calls = Calls()
        let request = try autoRequest()
        await viewModel(isPro: false, store: store(), calls: calls).autoRefresh(request)
        await viewModel(hasConsent: false, store: store(), calls: calls).autoRefresh(request)
        #expect(calls.count == 0)
        let control = viewModel(store: store(), calls: calls)
        await control.autoRefresh(request)
        #expect(calls.count == 1, "Control: Pro con consentimiento sí llama.")
    }

    @Test("La primera vez genera y guarda; con los mismos datos, sale lo guardado sin llamar")
    func firstTime_thenSaved() async throws {
        let calls = Calls()
        let shared = store()
        let request = try autoRequest()
        let first = viewModel(store: shared, calls: calls)
        await first.autoRefresh(request)
        #expect(first.phase == .loaded([TrendsAIBullet(id: 0, source: .trend, text: "Nuevo")]))
        #expect(calls.count == 1)

        // Otra apertura (otra vista): lo guardado sale en el acto y no se vuelve a pedir.
        let reopened = viewModel(store: shared, calls: calls)
        reopened.restoreSaved(request)
        #expect(reopened.phase == .loaded([TrendsAIBullet(id: 0, source: .trend, text: "Nuevo")]))
        await reopened.autoRefresh(request, now: .now.addingTimeInterval(3600))
        #expect(calls.count == 1)
    }

    @Test("Un cambio relevante regenera por detrás: lo guardado sigue a la vista mientras llega")
    func relevantChange_regeneratesInBackground() async throws {
        let calls = Calls()
        let shared = store()
        await viewModel(store: shared, calls: calls, answer: "Viejo").autoRefresh(try autoRequest(total: 1000))

        var phaseDuringRequest: TrendsAIViewModel.Phase?
        var vmRef: TrendsAIViewModel?
        let vm = TrendsAIViewModel(
            request: { _, _ in
                calls.count += 1
                phaseDuringRequest = vmRef?.phase
                return [TrendsAIBullet(id: 0, source: .trend, text: "Nuevo")]
            },
            isPro: { true }, hasConsent: { true }, isOnline: { true }, store: shared
        )
        vmRef = vm
        let moved = try autoRequest(total: 1500)
        vm.restoreSaved(moved)
        await vm.autoRefresh(moved, now: .now.addingTimeInterval(11 * 60))
        #expect(calls.count == 2)
        #expect(phaseDuringRequest == .loaded([TrendsAIBullet(id: 0, source: .trend, text: "Viejo")]))
        #expect(vm.phase == .loaded([TrendsAIBullet(id: 0, source: .trend, text: "Nuevo")]))
    }

    @Test("Un cambio pequeño no regenera")
    func smallChange_keeps() async throws {
        let calls = Calls()
        let shared = store()
        await viewModel(store: shared, calls: calls).autoRefresh(try autoRequest(total: 1000))
        await viewModel(store: shared, calls: calls).autoRefresh(
            try autoRequest(total: 1020), now: .now.addingTimeInterval(11 * 60)
        )
        #expect(calls.count == 1)
    }

    @Test("Un fallo es silencioso: sin nada guardado vuelve el CTA, con algo guardado se queda")
    func failure_isSilent() async throws {
        let calls = Calls()
        let empty = viewModel(store: store(), calls: calls, fails: true)
        await empty.autoRefresh(try autoRequest())
        #expect(empty.phase == .idle, "Nada de `.failed`: ese aviso es del botón.")

        let shared = store()
        await viewModel(store: shared, calls: calls, answer: "Viejo").autoRefresh(try autoRequest(total: 1000))
        let failing = viewModel(store: shared, calls: calls, fails: true)
        let moved = try autoRequest(total: 1500)
        failing.restoreSaved(moved)
        await failing.autoRefresh(moved, now: .now.addingTimeInterval(11 * 60))
        #expect(failing.phase == .loaded([TrendsAIBullet(id: 0, source: .trend, text: "Viejo")]))
    }

    @Test("Sin red no llama ni gasta el intento")
    func offline_noCallNoLedger() async throws {
        let calls = Calls()
        let shared = store()
        let request = try autoRequest()
        await viewModel(isOnline: false, store: shared, calls: calls).autoRefresh(request)
        #expect(calls.count == 0)
        #expect(shared.today(page: .trends, slot: request.slot).automaticCount == 0)
        await viewModel(store: shared, calls: calls).autoRefresh(request)
        #expect(calls.count == 1, "Con red, la próxima apertura lo pide.")
    }

    @Test("Techo diario: tras 4 automáticas, ni una más hoy")
    func dailyCap_stopsCalls() async throws {
        let calls = Calls()
        let shared = store()
        // Un «ahora» fijo a media mañana: seis pasos de 11 min caen el mismo día a cualquier hora que corra el test.
        let start = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 10)))
        for step in 0..<6 {
            // Cada paso, un cambio relevante pasado el antirrebote.
            let request = try autoRequest(total: Double(1000 * (step + 1)))
            await viewModel(store: shared, calls: calls).autoRefresh(request, now: start.addingTimeInterval(Double(step) * 11 * 60))
        }
        #expect(calls.count == StatsAIAutoRefreshLogic.dailyCap)
        let nextDay = start.addingTimeInterval(24 * 3600)
        await viewModel(store: shared, calls: calls).autoRefresh(try autoRequest(total: 99_000), now: nextDay)
        #expect(calls.count == StatsAIAutoRefreshLogic.dailyCap + 1, "Al día siguiente el techo vuelve a empezar.")
    }
}
