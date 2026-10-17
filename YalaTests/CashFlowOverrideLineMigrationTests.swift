//
//  CashFlowOverrideLineMigrationTests.swift
//  YalaTests
//
//  Ticket `personal-cloudkit-cashflow-override-line-declared-as-reference`. En Production el campo de
//  `CashFlowOverride.line` (`CD_line`) es REFERENCE y la app escribe STRING: iCloud rechazaba todo ajuste de
//  un mes. La relación pasó a `cashFlowLine` (campo nuevo `CD_cashFlowLine`, STRING) y los ajustes viejos se
//  migran solos en cada arranque (`CashFlowOverrideLineMigration`).
//
//  Lo que fija esta suite:
//  - **datos viejos**: un ajuste guardado como lo guardaba la app (`override.line = line`) pasa a la relación
//    nueva, queda con `line == nil` (un registro con `CD_line` puesto lo vuelve a rechazar iCloud) y la
//    pantalla lo sigue viendo;
//  - **idempotente**: la segunda pasada no toca nada;
//  - **sin duplicados**: nunca quedan dos ajustes del mismo mes en una línea;
//  - **nadie vuelve a escribir `line`**: ni el formulario del ajuste ni el apply del Modo Nube.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · los ajustes de un mes pasan al campo nuevo de iCloud", .serialized)
struct CashFlowOverrideLineMigrationTests {

    private func makeLine(_ name: String, plan: CashFlowPlan, in context: ModelContext) -> CashFlowLine {
        let line = CashFlowLine(name: name)
        context.insert(line)
        line.plan = plan
        return line
    }

    private func makePlan(in context: ModelContext) -> CashFlowPlan {
        let plan = CashFlowPlan(name: "2026")
        context.insert(plan)
        return plan
    }

    /// Un ajuste exactamente como lo guardaba la app hasta este cambio.
    @discardableResult
    private func legacyOverride(
        _ monthKey: String, amount: Double, on line: CashFlowLine, in context: ModelContext
    ) -> CashFlowOverride {
        let override = CashFlowOverride(monthKey: monthKey, amount: amount)
        context.insert(override)
        override.line = line
        return override
    }

    private func allOverrides(_ context: ModelContext) throws -> [CashFlowOverride] {
        try context.fetch(FetchDescriptor<CashFlowOverride>())
    }

    // MARK: - Datos viejos

    @Test("Un ajuste viejo pasa a la relación nueva, deja el campo viejo vacío y la línea lo sigue viendo")
    func legacyOverride_movesToTheNewRelation() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let line = makeLine("Sueldo", plan: plan, in: context)
        let override = legacyOverride("2026-04", amount: 800, on: line, in: context)
        try context.save()

        let outcome = CashFlowOverrideLineMigration.migrateIfNeeded(in: context)

        #expect(outcome == .init(moved: 1, cleared: 0, duplicatesRemoved: 0))
        #expect(override.cashFlowLine?.id == line.id)
        #expect(override.line == nil)
        #expect(override.amount == 800)
        #expect(line.monthOverrides?.map(\.id) == [override.id])
        #expect((line.overrides ?? []).isEmpty)
        // Y en el store, no solo en memoria.
        let fresh = ModelContext(context.container)
        let stored = try #require(try fresh.fetch(FetchDescriptor<CashFlowOverride>()).first)
        #expect(stored.cashFlowLine?.id == line.id)
        #expect(stored.line == nil)
    }

    @Test("Varios ajustes viejos en varias líneas migran todos, cada uno a su línea")
    func severalLegacyOverrides_allMove() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let sueldo = makeLine("Sueldo", plan: plan, in: context)
        let renta = makeLine("Renta", plan: plan, in: context)
        legacyOverride("2026-04", amount: 800, on: sueldo, in: context)
        legacyOverride("2026-05", amount: 900, on: sueldo, in: context)
        legacyOverride("2026-04", amount: -300, on: renta, in: context)
        try context.save()

        let outcome = CashFlowOverrideLineMigration.migrateIfNeeded(in: context)

        #expect(outcome.moved == 3)
        #expect(Set((sueldo.monthOverrides ?? []).map(\.monthKey)) == ["2026-04", "2026-05"])
        #expect((renta.monthOverrides ?? []).map(\.amount) == [-300])
        #expect(try allOverrides(context).allSatisfy { $0.line == nil })
    }

    // MARK: - Idempotente

    @Test("La segunda pasada no toca nada")
    func migration_isIdempotent() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let line = makeLine("Sueldo", plan: plan, in: context)
        legacyOverride("2026-04", amount: 800, on: line, in: context)
        try context.save()

        CashFlowOverrideLineMigration.migrateIfNeeded(in: context)
        let before = try allOverrides(context).map { "\($0.id)|\($0.monthKey)|\($0.amount)|\(String(describing: $0.cashFlowLine?.id))" }
        let second = CashFlowOverrideLineMigration.migrateIfNeeded(in: context)
        let after = try allOverrides(context).map { "\($0.id)|\($0.monthKey)|\($0.amount)|\(String(describing: $0.cashFlowLine?.id))" }

        #expect(second == .init())
        #expect(!second.touchedAnything)
        #expect(before == after)
        #expect(!context.hasChanges)
    }

    @Test("Sin ajustes viejos no guarda nada")
    func noLegacyOverrides_noSave() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let line = makeLine("Sueldo", plan: plan, in: context)
        let override = CashFlowOverride(monthKey: "2026-04", amount: 800)
        context.insert(override)
        override.cashFlowLine = line
        try context.save()

        #expect(CashFlowOverrideLineMigration.migrateIfNeeded(in: context) == .init())
        #expect(override.cashFlowLine?.id == line.id)
    }

    // MARK: - Sin duplicados

    @Test("Si la línea ya tiene ese mes en la relación nueva, el viejo es un duplicado y se va")
    func legacyDuplicateOfANewOverride_isRemoved() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let line = makeLine("Sueldo", plan: plan, in: context)
        let current = CashFlowOverride(monthKey: "2026-04", amount: 950)
        context.insert(current)
        current.cashFlowLine = line
        legacyOverride("2026-04", amount: 800, on: line, in: context)
        legacyOverride("2026-05", amount: 700, on: line, in: context)
        try context.save()

        let outcome = CashFlowOverrideLineMigration.migrateIfNeeded(in: context)

        #expect(outcome == .init(moved: 1, cleared: 0, duplicatesRemoved: 1))
        let overrides = try allOverrides(context)
        #expect(overrides.count == 2)
        let april = overrides.filter { $0.monthKey == "2026-04" }
        #expect(april.map(\.amount) == [950], "el del mes que ya existía en la relación nueva gana")
        #expect(overrides.allSatisfy { $0.cashFlowLine?.id == line.id && $0.line == nil })
    }

    @Test("Dos ajustes viejos del mismo mes dejan uno, y siempre el mismo (el de menor id)")
    func twoLegacyOverridesOfTheSameMonth_leaveOne() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let line = makeLine("Sueldo", plan: plan, in: context)
        let a = legacyOverride("2026-04", amount: 800, on: line, in: context)
        let b = legacyOverride("2026-04", amount: 850, on: line, in: context)
        try context.save()
        let survivorID = [a.id, b.id].min { $0.uuidString < $1.uuidString }

        let outcome = CashFlowOverrideLineMigration.migrateIfNeeded(in: context)

        #expect(outcome == .init(moved: 1, cleared: 0, duplicatesRemoved: 1))
        let overrides = try allOverrides(context)
        #expect(overrides.map(\.id) == [survivorID].compactMap { $0 })
        #expect(overrides.first?.cashFlowLine?.id == line.id)
    }

    @Test("El mismo mes en dos líneas distintas no es un duplicado")
    func sameMonthOnTwoLines_isNotADuplicate() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let sueldo = makeLine("Sueldo", plan: plan, in: context)
        let renta = makeLine("Renta", plan: plan, in: context)
        legacyOverride("2026-04", amount: 800, on: sueldo, in: context)
        let other = CashFlowOverride(monthKey: "2026-04", amount: -300)
        context.insert(other)
        other.cashFlowLine = renta
        try context.save()

        let outcome = CashFlowOverrideLineMigration.migrateIfNeeded(in: context)

        #expect(outcome == .init(moved: 1, cleared: 0, duplicatesRemoved: 0))
        #expect(try allOverrides(context).count == 2)
    }

    @Test("Un ajuste con las dos relaciones puestas conserva la nueva y vacía la vieja")
    func overrideWithBothRelations_keepsTheNewOne() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let nueva = makeLine("Nueva", plan: plan, in: context)
        let vieja = makeLine("Vieja", plan: plan, in: context)
        let override = legacyOverride("2026-04", amount: 800, on: vieja, in: context)
        override.cashFlowLine = nueva
        try context.save()

        let outcome = CashFlowOverrideLineMigration.migrateIfNeeded(in: context)

        #expect(outcome == .init(moved: 0, cleared: 1, duplicatesRemoved: 0))
        #expect(override.cashFlowLine?.id == nueva.id)
        #expect(override.line == nil)
    }

    // MARK: - Borrar una línea

    @Test("Borrar una línea se lleva sus ajustes de las dos relaciones")
    func deletingALine_cascadesBothRelations() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let line = makeLine("Sueldo", plan: plan, in: context)
        legacyOverride("2026-04", amount: 800, on: line, in: context)
        let current = CashFlowOverride(monthKey: "2026-05", amount: 900)
        context.insert(current)
        current.cashFlowLine = line
        try context.save()

        context.delete(line)
        try context.save()

        #expect(try allOverrides(context).isEmpty)
    }

    // MARK: - Nadie vuelve a escribir `line`

    @Test("El formulario del ajuste escribe la relación nueva y sustituye un viejo del mismo mes")
    func setOverride_writesTheNewRelation_andReplacesALegacyOne() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let line = makeLine("Sueldo", plan: plan, in: context)
        legacyOverride("2026-04", amount: 800, on: line, in: context)
        try context.save()
        let viewModel = CashFlowPlanViewModel()
        viewModel.setContext(context)

        viewModel.setOverride(line: line, monthKey: "2026-04", amount: 1_000, note: "bono")

        let overrides = try allOverrides(context)
        #expect(overrides.count == 1)
        #expect(overrides.first?.amount == 1_000)
        #expect(overrides.first?.cashFlowLine?.id == line.id)
        #expect(overrides.first?.line == nil)
    }

    @Test("Quitar el ajuste de un mes quita también uno viejo de ese mes")
    func removeOverride_removesALegacyOneToo() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let line = makeLine("Sueldo", plan: plan, in: context)
        legacyOverride("2026-04", amount: 800, on: line, in: context)
        try context.save()
        let viewModel = CashFlowPlanViewModel()
        viewModel.setContext(context)

        viewModel.removeOverride(line: line, monthKey: "2026-04")

        #expect(try allOverrides(context).isEmpty)
    }

    /// Un source-scan, porque el campo viejo existe en el modelo y el compilador no impide asignarlo: solo la
    /// migración lo toca, y solo para vaciarlo.
    @Test("En Yala/ solo la migración asigna `CashFlowOverride.line`, y siempre a nil")
    func onlyTheMigrationAssignsTheLegacyRelation() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let yala = root.appendingPathComponent("Yala")
        let enumerator = try #require(FileManager.default.enumerator(at: yala, includingPropertiesForKeys: nil))
        var offenders: [String] = []
        var migrationAssignments: [String] = []
        let assignment = /\.line\s*=(?!=)\s*([^\n]*)/
        // La inversa legado también pone `line` al escribirse.
        let inverse = /\.overrides\s*(=(?!=)|\?*\.append|\?*\.insert)/
        // Las únicas `self.line =` legítimas: vistas que reciben una `CashFlowLine`, no un ajuste.
        let viewsHoldingALine: Set<String> = ["CashFlowLineConfigSheet.swift", "CashFlowSetupView.swift"]
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for line in text.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                let lineText = String(line).trimmingCharacters(in: .whitespaces)
                if String(line).firstMatch(of: inverse) != nil {
                    offenders.append("\(url.lastPathComponent): \(lineText)")
                    continue
                }
                guard let match = String(line).firstMatch(of: assignment) else { continue }
                if lineText.hasPrefix("self.line =") && viewsHoldingALine.contains(url.lastPathComponent) { continue }
                if url.lastPathComponent == "CashFlowOverrideLineMigration.swift" {
                    migrationAssignments.append(String(match.output.1).trimmingCharacters(in: .whitespaces))
                } else {
                    offenders.append("\(url.lastPathComponent): \(lineText)")
                }
            }
        }
        #expect(offenders.isEmpty, "Asigna la relación legado `line`, que iCloud rechaza en Production: \(offenders)")
        #expect(!migrationAssignments.isEmpty, "el escáner no encontró ni la migración: no está mirando nada")
        #expect(migrationAssignments.allSatisfy { $0 == "nil" }, "la migración solo puede vaciar `line`: \(migrationAssignments)")
    }
}
