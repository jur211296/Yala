//
//  MemoriaPorCicloTests.swift
//  YalaTests / EficienciaMemoriaPorVuelta
//
//  Lote 6 de eficiencia (26-nov-2026). El informe del iPhone 14 midió que la memoria de Yala subía ~25 MiB por cada vuelta
//  a primer plano (238 → 363 MiB en 5 ciclos, 16.004 movimientos) y sospechaba que las recargas completas (Panel,
//  Spotlight) dejaban vivas las filas de SwiftData. Tras los lotes 1-5 se midió en el mismo iPhone: estable (108 → 110 MiB
//  en 10 ciclos), también forzando la recarga completa del Panel y de Spotlight en cada vuelta (105-109 MiB). No hubo nada
//  que corregir en la app.
//
//  Se fija la clase de fallo: N recargas completas del Panel, y N lecturas de Spotlight, sobre un almacén en disco no hacen
//  crecer la huella física del proceso a partir del segundo ciclo (el primero llena cachés y el montón de malloc). El
//  control positivo es la fuga que se sospechaba: un contexto por ciclo que no se suelta, con sus filas leídas. Si el
//  instrumento no la ve, el caso negativo no prueba nada.
//

import Darwin
import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Lote 6 · la memoria no sube por cada recarga completa", .serialized)
@MainActor
struct MemoriaPorCicloTests {

    /// Movimientos del almacén: suficientes para que una fuga por ciclo se separe del ruido del proceso de tests.
    private static let movimientos = 4_000
    private static let ciclos = 8
    /// Lo que puede crecer la huella del ciclo 2 al último sin que cuente como fuga. Medido en el simulador (iOS 27.2):
    /// sin fuga, 0-0,4 MiB; reteniendo un contexto por recarga, ~1,1 MiB por ciclo en el Panel y ~5,6 en Spotlight.
    private static let toleranciaMiB = 4.0

    /// El ViewModel guarda `sessionState` en `weak`: el test la retiene.
    private let session = SessionState()
    private let base = Date(timeIntervalSince1970: 1_700_000_000)
    private let appCompleta = SpotlightIndexLogic.Context(
        isGroupsFocusedShell: false, isExpensesOnlyMode: false, includeGroupTransactions: true)

    // MARK: - Almacén

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemoriaPorCiclo-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            #if DEBUG
            print("MemoriaPorCicloTests: Error: \(error)")
            #endif
        }
        return dir
    }

    private func makeContainer(_ dir: URL) throws -> ModelContainer {
        let personal = ModelConfiguration("MPC-Personal", schema: SwiftDataConfiguration.personalSchema,
                                          url: dir.appendingPathComponent("p.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration("MPC-Groups", schema: SwiftDataConfiguration.groupsSchema,
                                        url: dir.appendingPathComponent("g.sqlite"), cloudKitDatabase: .none)
        let meta = ModelConfiguration("MPC-Meta", schema: SwiftDataConfiguration.syncMetaSchema,
                                      url: dir.appendingPathComponent("m.sqlite"), cloudKitDatabase: .none)
        return try ModelContainer(for: SwiftDataConfiguration.schema, configurations: personal, groups, meta)
    }

    /// Gastos e ingresos con cuenta y categoría (las relaciones que leen el Panel y Spotlight), con nota.
    private func seed(_ container: ModelContainer) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let account = Account(name: "Principal", currencyCode: "PEN", colorHex: "#000000", iconName: "x", type: "cash")
        let comida = Category(name: "Comida", colorHex: "#FF0000", isIncome: false)
        let sueldo = Category(name: "Sueldo", colorHex: "#00FF00", isIncome: true)
        context.insert(account)
        context.insert(comida)
        context.insert(sueldo)
        for i in 0..<Self.movimientos {
            let ingreso = i % 10 == 0
            let tx = TransactionItem(date: base.addingTimeInterval(-Double(i) * 7_200),
                                     amount: ingreso ? 1_500 : -Double(10 + i % 90),
                                     currencyCode: "PEN", account: account)
            tx.category = ingreso ? sueldo : comida
            tx.note = "Movimiento \(i)"
            tx.createdAt = tx.date
            context.insert(tx)
        }
        try context.save()
    }

    // MARK: - Instrumento

    /// Huella física del proceso (lo que mide Activity Monitor en el iPhone), en MiB.
    private func huellaMiB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return .nan }
        return Double(info.phys_footprint) / 1_048_576
    }

    /// Corre `ciclos` vueltas de `trabajo` y devuelve la huella tras cada una (con el run loop asentado entre medias).
    private func huellaPorCiclo(_ trabajo: () async throws -> Void) async throws -> [Double] {
        var huellas: [Double] = []
        #if DEBUG
        print("MemoriaPorCicloTests: antes del primer ciclo \(String(format: "%.1f", huellaMiB())) MiB")
        #endif
        for _ in 0..<Self.ciclos {
            try await trabajo()
            try await Task.sleep(for: .milliseconds(50))
            huellas.append(huellaMiB())
        }
        #if DEBUG
        print("MemoriaPorCicloTests: huella por ciclo \(describir(huellas)) MiB")
        #endif
        return huellas
    }

    /// Lo que crece del ciclo 2 al último.
    private func crecimiento(_ huellas: [Double]) -> Double {
        guard huellas.count >= 2, let ultimo = huellas.last else { return .nan }
        return ultimo - huellas[1]
    }

    private func describir(_ huellas: [Double]) -> String {
        huellas.map { String(format: "%.1f", $0) }.joined(separator: " → ")
    }

    // MARK: - Panel

    private func esperarCalculo(_ viewModel: PanelViewModel, hasta objetivo: Int) async throws {
        // Un recálculo completo con 4.000 movimientos en el simulador tarda del orden de segundos (Debug).
        for _ in 0..<1_500 where viewModel.debugCalculationRuns < objetivo {
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(viewModel.debugCalculationRuns >= objetivo, "el recálculo del Panel no terminó")
    }

    @Test("Recargas completas del Panel: la huella no crece del ciclo 2 al último")
    func recargasDelPanel_noHacenCrecerLaMemoria() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try makeContainer(dir)
        try seed(container)
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        viewModel.setContext(context, defaultCurrencyCode: "PEN", sessionState: session)

        let huellas = try await huellaPorCiclo {
            let antes = viewModel.debugCalculationRuns
            viewModel.reloadAndRecalculate()
            try await esperarCalculo(viewModel, hasta: antes + 1)
        }

        #expect(viewModel.transactions.count == Self.movimientos, "cada vuelta recargó el historial entero")
        #expect(crecimiento(huellas) <= Self.toleranciaMiB,
                "la memoria crece con cada recarga del Panel: \(describir(huellas)) MiB")
    }

    // MARK: - Spotlight

    @Test("Lecturas completas de Spotlight: la huella no crece del ciclo 2 al último")
    func lecturasDeSpotlight_noHacenCrecerLaMemoria() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try makeContainer(dir)
        try seed(container)
        let context = ModelContext(container)
        context.autosaveEnabled = false

        var leidas = 0
        let huellas = try await huellaPorCiclo {
            let entradas = try await SpotlightIndexService.desiredEntries(context: context, spotlightContext: appCompleta)
            leidas = entradas.filter { $0.kind == .transaction }.count
        }

        #expect(leidas == Self.movimientos, "cada lectura recorrió el historial entero")
        #expect(crecimiento(huellas) <= Self.toleranciaMiB,
                "la memoria crece con cada lectura de Spotlight: \(describir(huellas)) MiB")
    }

    // MARK: - Control positivo

    @Test("Control: un contexto por ciclo que no se suelta, con sus filas, sí hace crecer la huella")
    func control_unContextoRetenidoPorCiclo_seVe() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try makeContainer(dir)
        try seed(container)

        // La fuga que sospechaba el informe: cada recarga lee en un contexto nuevo y nadie suelta el anterior.
        var retenidos: [(ModelContext, [TransactionItem])] = []
        let huellas = try await huellaPorCiclo {
            let context = ModelContext(container)
            context.autosaveEnabled = false
            var descriptor = FetchDescriptor<TransactionItem>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            descriptor.relationshipKeyPathsForPrefetching = [\.category, \.account]
            let filas = try context.fetch(descriptor)
            // Leer lo que leen el Panel y Spotlight materializa cada fila.
            _ = filas.reduce(0.0) { $0 + $1.amount + Double($1.note?.count ?? 0) + ($1.category?.isIncome == true ? 1 : 0) }
            retenidos.append((context, filas))
        }

        #expect(retenidos.count == Self.ciclos)
        #expect(crecimiento(huellas) > Self.toleranciaMiB,
                "el instrumento no ve la fuga de control (\(describir(huellas)) MiB): los casos de arriba no prueban nada")
    }
}
