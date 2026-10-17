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

    /// Tres `id` en orden conocido, para que el superviviente no dependa del azar de `UUID()`.
    static let low = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    static let mid = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    static let high = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3))
    static let high2 = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4))

    /// Un ajuste como lo deja la versión de hoy (relación nueva), o como llega de otro teléfono por iCloud.
    @discardableResult
    private func newOverride(
        _ monthKey: String, amount: Double, id: UUID, on line: CashFlowLine?, in context: ModelContext
    ) -> CashFlowOverride {
        let override = CashFlowOverride(monthKey: monthKey, amount: amount)
        context.insert(override)
        override.id = id
        override.cashFlowLine = line
        return override
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

    @Test("Un viejo y uno nuevo del mismo mes: gana el de menor id, esté en la relación que esté")
    func legacyAndNewOverrideOfTheSameMonth_keepTheLowestID() throws {
        for legacyIsLower in [true, false] {
            let context = try makeTestContext()
            let plan = makePlan(in: context)
            let line = makeLine("Sueldo", plan: plan, in: context)
            let current = CashFlowOverride(monthKey: "2026-04", amount: 950)
            context.insert(current)
            current.cashFlowLine = line
            let legacy = legacyOverride("2026-04", amount: 800, on: line, in: context)
            legacyOverride("2026-05", amount: 700, on: line, in: context)
            current.id = legacyIsLower ? Self.high : Self.low
            legacy.id = legacyIsLower ? Self.low : Self.high
            try context.save()

            let outcome = CashFlowOverrideLineMigration.migrateIfNeeded(in: context)

            #expect(outcome == .init(moved: legacyIsLower ? 2 : 1, cleared: 0, duplicatesRemoved: 1))
            let overrides = try allOverrides(context)
            #expect(overrides.count == 2)
            let april = overrides.filter { $0.monthKey == "2026-04" }
            #expect(april.map(\.id) == [Self.low], "legacyIsLower=\(legacyIsLower)")
            #expect(april.map(\.amount) == [legacyIsLower ? 800 : 950])
            #expect(overrides.allSatisfy { $0.cashFlowLine?.id == line.id && $0.line == nil })
        }
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

    // MARK: - Dos teléfonos con el mismo mes (ticket cashflow-two-devices-with-the-same-month-adjustment-end-up-with-two)

    @Test("Dos ajustes del mismo mes que llegan por iCloud dejan uno, el de menor id, en cualquier orden de llegada")
    func twoNewOverridesOfTheSameMonth_leaveTheLowestID() throws {
        for insertLowFirst in [true, false] {
            let context = try makeTestContext()
            let plan = makePlan(in: context)
            let line = makeLine("Renta", plan: plan, in: context)
            let ids = insertLowFirst ? [Self.low, Self.high] : [Self.high, Self.low]
            for id in ids {
                newOverride("2026-04", amount: id == Self.low ? -300 : -320, id: id, on: line, in: context)
            }
            try context.save()

            let outcome = CashFlowOverrideLineMigration.migrateIfNeeded(in: context)

            #expect(outcome == .init(moved: 0, cleared: 0, duplicatesRemoved: 1))
            let overrides = try allOverrides(context)
            #expect(overrides.map(\.id) == [Self.low], "insertLowFirst=\(insertLowFirst)")
            #expect(overrides.first?.amount == -300)
            #expect(line.monthOverride(for: "2026-04")?.id == Self.low)
        }
    }

    @Test("Antes de la pasada, la pantalla ya enseña el ajuste que va a quedarse")
    func readersShowTheSurvivorBeforeThePass() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let line = makeLine("Renta", plan: plan, in: context)
        newOverride("2026-04", amount: -320, id: Self.high, on: line, in: context)
        newOverride("2026-04", amount: -300, id: Self.low, on: line, in: context)
        newOverride("2026-05", amount: -310, id: Self.mid, on: line, in: context)
        try context.save()

        #expect(line.monthOverride(for: "2026-04")?.amount == -300)
        #expect(line.monthOverride(for: "2026-06") == nil)
        #expect(line.shownMonthOverrides.map(\.monthKey) == ["2026-04", "2026-05"])
        #expect(line.shownMonthOverrides.map(\.id) == [Self.low, Self.mid])
    }

    /// Lo que hace que los dos teléfonos converjan aunque vean los ajustes en distinto orden: cada pasada borra solo
    /// lo que no es el mínimo de lo que tiene, así que nunca borra el mínimo de todos.
    @Test("Una pasada con solo parte de los ajustes nunca borra el que acabará quedándose")
    func aPassOnASubset_neverDeletesTheGlobalSurvivor() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let line = makeLine("Renta", plan: plan, in: context)
        newOverride("2026-04", amount: -320, id: Self.high, on: line, in: context)
        newOverride("2026-04", amount: -310, id: Self.mid, on: line, in: context)
        try context.save()

        #expect(CashFlowOverrideLineMigration.migrateIfNeeded(in: context).duplicatesRemoved == 1)
        #expect(try allOverrides(context).map(\.id) == [Self.mid])

        // Llega el del otro teléfono, con un id menor.
        newOverride("2026-04", amount: -300, id: Self.low, on: line, in: context)
        try context.save()

        #expect(CashFlowOverrideLineMigration.migrateIfNeeded(in: context).duplicatesRemoved == 1)
        #expect(try allOverrides(context).map(\.id) == [Self.low])
    }

    /// El gemelo de `.dev`: una build vieja de Yala Dev escribe `line`. Antes ganaba el que ya estaba en la relación
    /// nueva, así que el resultado dependía de qué llegó antes a cada teléfono.
    @Test("Un ajuste viejo que llega DESPUÉS de migrar elige el mismo superviviente que si hubiera llegado antes")
    func lateLegacyOverride_choosesTheSameSurvivorAsAnEarlyOne() throws {
        // Teléfono A: el viejo llega primero y migra; el nuevo llega después.
        let a = try makeTestContext()
        let lineA = makeLine("Renta", plan: makePlan(in: a), in: a)
        legacyOverride("2026-04", amount: -300, on: lineA, in: a).id = Self.low
        try a.save()
        CashFlowOverrideLineMigration.migrateIfNeeded(in: a)
        newOverride("2026-04", amount: -320, id: Self.high, on: lineA, in: a)
        try a.save()
        CashFlowOverrideLineMigration.migrateIfNeeded(in: a)
        let survivorA = try allOverrides(a).map(\.id)

        // Teléfono B: al revés.
        let b = try makeTestContext()
        let lineB = makeLine("Renta", plan: makePlan(in: b), in: b)
        newOverride("2026-04", amount: -320, id: Self.high, on: lineB, in: b)
        try b.save()
        CashFlowOverrideLineMigration.migrateIfNeeded(in: b)
        legacyOverride("2026-04", amount: -300, on: lineB, in: b).id = Self.low
        try b.save()
        CashFlowOverrideLineMigration.migrateIfNeeded(in: b)
        let survivorB = try allOverrides(b).map(\.id)

        #expect(survivorA == [Self.low])
        #expect(survivorB == survivorA)
        #expect(try allOverrides(b).first?.cashFlowLine?.id == lineB.id)
    }

    @Test("La pasada del paso 0.0 solo funde los meses que traen legado; los duplicados de iCloud esperan a la completa")
    func legacyScope_leavesImportedDuplicatesForTheGatedPass() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let line = makeLine("Renta", plan: plan, in: context)
        newOverride("2026-04", amount: -320, id: Self.high, on: line, in: context)
        newOverride("2026-04", amount: -300, id: Self.low, on: line, in: context)
        newOverride("2026-05", amount: -310, id: Self.high2, on: line, in: context)
        legacyOverride("2026-05", amount: -305, on: line, in: context).id = Self.mid
        try context.save()

        let early = CashFlowOverrideLineMigration.migrateIfNeeded(in: context, scope: .groupsWithLegacy)

        #expect(early == .init(moved: 1, cleared: 0, duplicatesRemoved: 1))
        #expect(try allOverrides(context).filter { $0.monthKey == "2026-04" }.count == 2, "abril no trae legado")
        #expect(try allOverrides(context).filter { $0.monthKey == "2026-05" }.map(\.id) == [Self.mid])

        let late = CashFlowOverrideLineMigration.migrateIfNeeded(in: context, scope: .all)

        #expect(late == .init(moved: 0, cleared: 0, duplicatesRemoved: 1))
        #expect(try allOverrides(context).filter { $0.monthKey == "2026-04" }.map(\.id) == [Self.low])
    }

    @Test("La pantalla cuenta el legado sin migrar: enseña el mismo que conservará la pasada")
    func readersCountAnUnmigratedLegacyOverride() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let line = makeLine("Renta", plan: plan, in: context)
        let other = makeLine("Luz", plan: plan, in: context)
        newOverride("2026-04", amount: -320, id: Self.high, on: line, in: context)
        legacyOverride("2026-04", amount: -300, on: line, in: context).id = Self.low
        // Un ajuste con las dos relaciones es de su línea nueva: en la vieja no cuenta.
        let both = legacyOverride("2026-05", amount: -50, on: line, in: context)
        both.id = Self.mid
        both.cashFlowLine = other
        try context.save()

        #expect(line.monthOverride(for: "2026-04")?.id == Self.low)
        #expect(line.monthOverride(for: "2026-05") == nil)
        #expect(line.shownMonthOverrides.map(\.id) == [Self.low])
        #expect(other.monthOverride(for: "2026-05")?.id == Self.mid)

        CashFlowOverrideLineMigration.migrateIfNeeded(in: context)

        #expect(line.monthOverride(for: "2026-04")?.id == Self.low)
    }

    /// Source-scan del arranque: la pasada temprana no funde lo importado, y la completa espera a la puerta del import.
    @Test("El arranque: el paso 0.0 va con .groupsWithLegacy y la pasada completa detrás de awaitPersonalStoreReady")
    func bootstrapperRunsTheFullPassBehindTheImportGate() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(
            contentsOf: root.appendingPathComponent("Yala/App/AppBootstrapper.swift"), encoding: .utf8)
        let code = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
        let calls = code.enumerated().filter { $0.element.contains("CashFlowOverrideLineMigration.migrateIfNeeded(") }
        #expect(calls.map(\.element) == [
            "CashFlowOverrideLineMigration.migrateIfNeeded(in: context, scope: .groupsWithLegacy)",
            "CashFlowOverrideLineMigration.migrateIfNeeded(in: context, scope: .all)",
        ])
        let full = try #require(calls.last?.offset)
        let before = code[max(0, full - 5)..<full].joined(separator: " ")
        #expect(before.contains("guard await awaitPersonalStoreReady() else {"), "\(before)")
        #expect(before.contains("Task { @MainActor in"), "\(before)")
    }

    // MARK: - Un ajuste que llegó a una versión vieja (ticket cashflow-override-synced-to-an-old-version-stays-invisible-after-updating)

    @Test("Un ajuste sin ninguna línea se conserva: la pasada no lo borra ni lo cuenta")
    func overrideWithoutAnyLine_isKept() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let line = makeLine("Renta", plan: plan, in: context)
        newOverride("2026-04", amount: -300, id: Self.low, on: nil, in: context)
        newOverride("2026-04", amount: -320, id: Self.high, on: nil, in: context)
        newOverride("2026-04", amount: -310, id: Self.mid, on: line, in: context)
        try context.save()

        let outcome = CashFlowOverrideLineMigration.migrateIfNeeded(in: context)

        #expect(outcome == .init())
        #expect(try allOverrides(context).count == 3)
    }

    /// Cuando el espejo le pone la línea al ajuste huérfano (al re-bajar el registro tras actualizar), se ve; y si choca
    /// con uno que este teléfono apuntó entretanto, la regla de siempre elige el mismo que el otro teléfono.
    @Test("Cuando el huérfano recibe su línea se ve, y si choca con otro del mismo mes se funde por la regla común")
    func orphanThatGetsItsLine_isShown_andACollisionIsResolved() throws {
        let context = try makeTestContext()
        let plan = makePlan(in: context)
        let line = makeLine("Renta", plan: plan, in: context)
        let orphan = newOverride("2026-04", amount: -300, id: Self.low, on: nil, in: context)
        newOverride("2026-04", amount: -320, id: Self.high, on: line, in: context)
        try context.save()
        CashFlowOverrideLineMigration.migrateIfNeeded(in: context)
        #expect(line.monthOverride(for: "2026-04")?.id == Self.high)

        orphan.cashFlowLine = line
        try context.save()

        #expect(line.monthOverride(for: "2026-04")?.id == Self.low)
        #expect(CashFlowOverrideLineMigration.migrateIfNeeded(in: context).duplicatesRemoved == 1)
        #expect(try allOverrides(context).map(\.id) == [Self.low])
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
