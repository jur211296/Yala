//
//  PanelReturnFreshnessTests.swift
//  YalaTests
//
//  Lote P2 · rendimiento del Panel (2026-11-04).
//
//  - Volver al Panel sin cambios no recarga ni recalcula; con cualquier cambio, sí (card
//    `tablero-volver-al-panel-lo-recarga-y-recalcula-e-zpgm`, `PanelReloadFreshness`).
//  - Una petición que llega con un cálculo esperando se suma a él y no reinicia la espera, y el freno deja calcular con
//    la app en primer plano aunque aún no esté activa (card `tablero-el-primer-contenido-del-panel-espera-a-q-h1hy`).
//  - Cualquier guardado de SwiftData cuenta (`StoreSaveCounter`), también el de otro contexto.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - La firma, en tabla

@Suite("Panel · ¿hay que recargar al volver?")
struct PanelReloadFreshnessLogicTests {

    private let day = Date(timeIntervalSince1970: 1_798_000_000)   // un instante fijo, no el reloj
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return c
    }

    private func stamp(version: Int = 3, saves: Int = 7, at date: Date? = nil) -> PanelDataStamp {
        PanelReloadFreshness.stamp(dataVersion: version, storeSaves: saves, now: date ?? day, calendar: calendar)
    }

    @Test("Sin carga previa, siempre carga")
    func neverLoaded_reloads() {
        #expect(PanelReloadFreshness.needsReload(
            lastLoad: nil, now: stamp(), hasUnsavedChanges: false, hasInterruptedWork: false))
    }

    @Test("Control: nada cambió → no recarga")
    func nothingChanged_doesNotReload() {
        #expect(!PanelReloadFreshness.needsReload(
            lastLoad: stamp(), now: stamp(), hasUnsavedChanges: false, hasInterruptedWork: false))
    }

    @Test("Cada señal por separado obliga a recargar",
          arguments: ["dataVersion", "guardado", "día", "sin guardar", "interrumpido"])
    func eachSignal_forcesAReload(_ signal: String) {
        let last = stamp()
        var now = stamp()
        var unsaved = false
        var interrupted = false
        switch signal {
        case "dataVersion": now = stamp(version: 4)
        case "guardado": now = stamp(saves: 8)
        case "día": now = stamp(at: day.addingTimeInterval(86_400))
        case "sin guardar": unsaved = true
        default: interrupted = true
        }
        #expect(PanelReloadFreshness.needsReload(
            lastLoad: last, now: now, hasUnsavedChanges: unsaved, hasInterruptedWork: interrupted))
    }

    @Test("Mismo día, otra hora: no es un cambio")
    func sameDay_laterHour_isNoChange() {
        #expect(stamp(at: day) == stamp(at: day.addingTimeInterval(60)))
    }
}

// MARK: - El ViewModel

@MainActor
@Suite("Panel · volver sin cambios no recalcula", .serialized)
struct PanelReturnFreshnessViewModelTests {

    /// El ViewModel guarda `sessionState` en `weak`: el test la retiene.
    private let session = SessionState()

    private func makePanel() throws -> (PanelViewModel, ModelContext) {
        let context = try makeTestContext()
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        viewModel.setContext(context, defaultCurrencyCode: "PEN", sessionState: session)
        return (viewModel, context)
    }

    private func waitForRuns(_ viewModel: PanelViewModel, reaching target: Int) async throws {
        for _ in 0..<100 where viewModel.debugCalculationRuns < target {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Deja pasar la espera de 150 ms con margen, para afirmar que NO hubo cálculo.
    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(400))
    }

    /// Primera aparición: carga y calcula. Devuelve el contador tras ella.
    private func appearOnce(_ viewModel: PanelViewModel) async throws -> Int {
        let before = viewModel.debugCalculationRuns
        viewModel.reloadOnAppearIfStale()
        try await waitForRuns(viewModel, reaching: before + 1)
        #expect(viewModel.debugCalculationRuns == before + 1, "la primera aparición tiene que cargar")
        return viewModel.debugCalculationRuns
    }

    @Test("Volver sin cambios: ni recarga ni recalcula")
    func returnWithoutChanges_doesNothing() async throws {
        let (viewModel, _) = try makePanel()
        let runs = try await appearOnce(viewModel)
        viewModel.reloadOnAppearIfStale()
        try await settle()
        #expect(viewModel.debugCalculationRuns == runs)
    }

    @Test("Un aviso de datos mientras estaba oculto: la vuelta recarga")
    func dataVersionBump_reloads() async throws {
        let (viewModel, _) = try makePanel()
        let runs = try await appearOnce(viewModel)
        session.dataVersion += 1   // sin pasar por el observador: el caso de quien lo cancela al salir
        viewModel.reloadOnAppearIfStale()
        try await waitForRuns(viewModel, reaching: runs + 1)
        #expect(viewModel.debugCalculationRuns == runs + 1)
    }

    @Test("Un escritor que guarda sin avisar por dataVersion: la vuelta recarga y ve la fila")
    func silentSaveFromAnotherContext_reloads() async throws {
        let (viewModel, context) = try makePanel()
        let runs = try await appearOnce(viewModel)
        let before = viewModel.transactions.count
        // Otro contexto del mismo contenedor, como un servicio de fondo: guarda y no avisa.
        let other = ModelContext(context.container)
        let savesBefore = StoreSaveCounter.shared.count
        other.insert(TransactionItem(date: .now, amount: -12, currencyCode: "PEN", note: "silencioso"))
        try other.save()
        // `ModelContext.didSave` llega por la cola principal.
        for _ in 0..<50 where StoreSaveCounter.shared.count == savesBefore { try await Task.sleep(for: .milliseconds(10)) }
        #expect(StoreSaveCounter.shared.count > savesBefore, "el guardado de otro contexto tiene que contar")
        viewModel.reloadOnAppearIfStale()
        try await waitForRuns(viewModel, reaching: runs + 1)
        #expect(viewModel.debugCalculationRuns == runs + 1)
        #expect(viewModel.transactions.count == before + 1)
    }

    @Test("Cambios sin guardar en el contexto del Panel: la vuelta recarga")
    func unsavedChanges_reload() async throws {
        let (viewModel, context) = try makePanel()
        let runs = try await appearOnce(viewModel)
        context.insert(TransactionItem(date: .now, amount: -5, currencyCode: "PEN", note: "sin guardar"))
        viewModel.reloadOnAppearIfStale()
        try await waitForRuns(viewModel, reaching: runs + 1)
        #expect(viewModel.debugCalculationRuns == runs + 1)
        context.rollback()
    }

    @Test("Salir del Panel con un cálculo esperando: la vuelta lo hace")
    func interruptedRecalculation_isDoneOnReturn() async throws {
        let (viewModel, _) = try makePanel()
        let runs = try await appearOnce(viewModel)
        viewModel.recalculateData()          // un filtro cambió…
        viewModel.cancelRecalculation()      // …y el Panel se fue antes de los 150 ms
        try await settle()
        #expect(viewModel.debugCalculationRuns == runs, "control: el cancelado no corrió")
        viewModel.reloadOnAppearIfStale()
        try await waitForRuns(viewModel, reaching: runs + 1)
        #expect(viewModel.debugCalculationRuns == runs + 1)
    }

    @Test("Una petición con otra esperando se suma: una espera, un cálculo")
    func requestDuringTheWindow_joinsIt() async throws {
        let (viewModel, _) = try makePanel()
        let runs = try await appearOnce(viewModel)
        let windows = viewModel.debugRecalculationWindowsOpened
        viewModel.recalculateData()
        viewModel.reloadAndRecalculate()     // el aviso del final del arranque
        viewModel.recalculateData()
        #expect(viewModel.debugRecalculationWindowsOpened == windows + 1, "no reinicia la espera")
        try await waitForRuns(viewModel, reaching: runs + 1)
        try await settle()
        #expect(viewModel.debugCalculationRuns == runs + 1)
    }

    @Test("En segundo plano no calcula; en primer plano sin activar, sí")
    func foregroundBrake() async throws {
        let (viewModel, _) = try makePanel()
        viewModel.isApplicationInForeground = { false }
        viewModel.reloadAndRecalculate()
        try await settle()
        #expect(viewModel.debugCalculationRuns == 0)
        viewModel.isApplicationInForeground = { true }
        viewModel.reloadAndRecalculate()
        try await waitForRuns(viewModel, reaching: 1)
        #expect(viewModel.debugCalculationRuns == 1)
    }

    @Test("StoreSaveCounter: guardar en otro contexto del mismo contenedor suma")
    func storeSaveCounter_countsSavesFromAnyContext() async throws {
        let context = try makeTestContext()
        let counter = StoreSaveCounter()
        let other = ModelContext(context.container)
        other.insert(TransactionItem(date: .now, amount: -1, currencyCode: "PEN", note: "contador"))
        try other.save()
        for _ in 0..<50 where counter.count == 0 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(counter.count >= 1)
    }
}

// MARK: - El cableado

@Suite("Panel · cableado de la vuelta y del freno (source-scan)")
struct PanelReturnFreshnessWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("El onAppear del Panel pregunta antes de recargar")
    func onAppear_usesTheFreshnessCheck() throws {
        let view = try Self.source("Yala/App/Views/Panel/PanelView.swift")
        let start = try #require(view.range(of: ".onAppear {\n            LoadTimeMarks.begin(.panel)"))
        let body = view[start.upperBound...].prefix(1400)
        #expect(body.contains("viewModel.reloadOnAppearIfStale()"))
        #expect(!body.contains("viewModel.reloadAndRecalculate()"))
    }

    @Test("La carga toma la firma ANTES de leer, y el freno mira primer plano, no «activa»")
    func loadAndBrake() throws {
        let vm = try Self.source("Yala/App/ViewModels/PanelViewModel.swift")
        let load = try #require(vm.range(of: "    func loadData() {\n        guard let context = modelContext else { return }"))
        #expect(vm[load.upperBound...].prefix(260).contains("lastLoadStamp = currentDataStamp()"))
        #expect(vm.contains("{ UIApplication.shared.applicationState != .background }"))
        #expect(vm.contains("guard isApplicationInForeground() else {"))
        #expect(vm.contains("guard recalculateTask == nil else { return }"))
    }
}
