//
//  PlanningNecesariasLote04Tests.swift
//  YalaTests
//
//  Lote 04 de mejoras necesarias 2.3 (Planificación). Un caso por punto:
//  (1) un mes saltado no se rotula pagado y la ayuda de «No se apunta nada» nombra Saltar;
//  (2) un período cerrado dice «Te sobró», no «Te quedan»;
//  (3) un presupuesto «Único» de un solo día se puede guardar;
//  (4) reactivar un presupuesto inactivo respeta el límite del plan gratis;
//  (5) los selectores de Pagos planificados tienen nombre y la fila de presupuesto dice lo que queda y los días.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - (1) Saltar no es pagar

@Suite("Lote 04 · (1) un mes saltado no es un mes pagado")
struct SkippedMonthIsNotPaidTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return calendar
    }()

    private func day(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 12)) ?? .distantPast
    }

    @Test func todasSaltadas_esSaltado() {
        let dates = [day(10)]
        #expect(ScheduledPaymentDetailLogic.settledMonth(datesThisMonth: dates) { _ in false } == .skipped)
    }

    @Test func todasPagadas_esPagado() {
        let dates = [day(3), day(10), day(17), day(24)]
        #expect(ScheduledPaymentDetailLogic.settledMonth(datesThisMonth: dates) { _ in true } == .paid)
    }

    @Test func unasPagadasYOtrasSaltadas_esAlDia() {
        let dates = [day(3), day(10), day(17), day(24)]
        let paid: Set<Date> = [day(3), day(17)]
        #expect(ScheduledPaymentDetailLogic.settledMonth(datesThisMonth: dates) { paid.contains($0) } == .mixed)
    }

    /// La línea gris de debajo de los botones se leía también como explicación de «Ya lo pagué». Ahora nombra el
    /// gesto: en los idiomas de referencia empieza por el condicional de Saltar.
    @Test func laAyudaNombraSaltar() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let expected: [(locale: String, prefix: String)] = [("es-419", "Si "), ("en", "If you skip"), ("pt-BR", "Se você pular")]
        for (locale, prefix) in expected {
            let url = root.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "no se leyó \(locale)")
            for key in ["scheduled.l10.action.skipHelp", "scheduled.l10.action.skipHelpMonth", "scheduled.l10.action.skipHelpDate"] {
                let value = try #require(table[key], "falta \(key) en \(locale)")
                #expect(value.hasPrefix(prefix), "«\(value)» (\(locale)) no dice que es lo que pasa al saltar")
            }
        }
    }
}

// MARK: - (2) Mes cerrado: «Te sobró»

@Suite("Lote 04 · (2) un período cerrado dice lo que sobró")
struct ClosedPeriodLeftoverTests {

    @Test func cerradoConAlgoSinGastar_esLoQueSobro() {
        #expect(BudgetRemainingLogic.figureLabel(limit: 1800, spent: 1534, daysRemaining: -1) == .leftover)
    }

    @Test func enCurso_esLoQueQueda() {
        #expect(BudgetRemainingLogic.figureLabel(limit: 1800, spent: 1534, daysRemaining: 12) == .remaining)
        #expect(BudgetRemainingLogic.figureLabel(limit: 1800, spent: 0, daysRemaining: 0) == .remaining)
    }

    @Test func pasarse_seDiceIgualAbiertoOCerrado() {
        #expect(BudgetRemainingLogic.figureLabel(limit: 600, spent: 700, daysRemaining: -1) == .over)
        #expect(BudgetRemainingLogic.figureLabel(limit: 600, spent: 700, daysRemaining: 5) == .over)
    }
}

// MARK: - (3) «Único» de un solo día

@Suite("Lote 04 · (3) un presupuesto Único de un día se guarda")
struct UniqueOneDayBudgetTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour)) ?? .distantPast
    }

    /// Los selectores son de día y guardan la hora del toque: inicio a las 15:00 y fin a las 09:00 del MISMO día es un
    /// presupuesto de un día. Con «inicio < fin» el ✓ se apagaba.
    @Test func mismoDia_valeAunqueLaHoraDelInicioSeaPosterior() {
        #expect(BudgetEditorView.uniqueRangeIsValid(start: date(10, 15), end: date(10, 9), calendar: calendar))
        #expect(BudgetEditorView.uniqueRangeIsValid(start: date(10, 9), end: date(10, 9), calendar: calendar))
    }

    @Test func variosDias_vale() {
        #expect(BudgetEditorView.uniqueRangeIsValid(start: date(10, 9), end: date(20, 9), calendar: calendar))
    }

    @Test func finAntesDelInicio_noVale() {
        #expect(!BudgetEditorView.uniqueRangeIsValid(start: date(10, 9), end: date(9, 23), calendar: calendar))
    }
}

// MARK: - (4) Reactivar respeta el límite del plan gratis

@Suite("Lote 04 · (4) reactivar un presupuesto respeta el límite gratis", .serialized)
@MainActor
struct BudgetReactivationPlanLimitTests {

    private func activeCount(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<Budget>(predicate: #Predicate { $0.isActive }))
    }

    private func editor(_ context: ModelContext) -> BudgetEditorViewModel {
        let vm = BudgetEditorViewModel()
        vm.setContext(context, deletionService: EntityDeletionService.shared)
        // El plan gratis: 3 activos (`ProFeature.budgets.freeLimit`).
        vm.canHaveAnotherActiveBudget = { $0 < (ProFeature.budgets.freeLimit ?? 3) }
        return vm
    }

    private func save(_ vm: BudgetEditorViewModel, _ budget: Budget, isActive: Bool) -> PersistentIdentifier? {
        vm.saveBudget(
            existing: budget, name: budget.name, limitAmount: budget.limitAmount, currencyCode: budget.currencyCode,
            periodType: .monthly, startDate: .now, endDate: .now, isActive: isActive,
            selectedAccounts: [], selectedSubcategories: [], selectedTags: [], selectedNeeds: [],
            alertEnabled: false, alertThresholds: [], includeSharedExpenses: false
        )
    }

    /// Reproduce el hallazgo: con 3 activos, encender «Activo» en el cuarto lo dejaba activo (4 de 3).
    @Test func conElLimiteLleno_noSeReactiva() throws {
        let context = try makeTestContext()
        for name in ["Comida", "Movilidad", "Salidas"] { _ = makeTestBudget(context: context, name: name) }
        let paused = makeTestBudget(context: context, name: "Mascota", isActive: false)
        try context.save()
        let vm = editor(context)

        #expect(vm.activationExceedsPlanLimit(existing: paused, isActive: true))
        #expect(save(vm, paused, isActive: true) == nil, "Guardó un cuarto presupuesto activo con el plan gratis.")
        #expect(try activeCount(context) == 3)
        #expect(paused.isActive == false)
    }

    @Test func conSitio_seReactiva() throws {
        let context = try makeTestContext()
        for name in ["Comida", "Movilidad"] { _ = makeTestBudget(context: context, name: name) }
        let paused = makeTestBudget(context: context, name: "Mascota", isActive: false)
        try context.save()
        let vm = editor(context)

        #expect(!vm.activationExceedsPlanLimit(existing: paused, isActive: true))
        #expect(save(vm, paused, isActive: true) != nil)
        #expect(try activeCount(context) == 3)
    }

    /// Editar uno que ya está activo con el límite lleno no es activar nada: se guarda.
    @Test func editarUnoYaActivo_conElLimiteLleno_seGuarda() throws {
        let context = try makeTestContext()
        let budgets = ["Comida", "Movilidad", "Salidas"].map { makeTestBudget(context: context, name: $0) }
        try context.save()
        let vm = editor(context)

        #expect(!vm.activationExceedsPlanLimit(existing: budgets[0], isActive: true))
        #expect(save(vm, budgets[0], isActive: true) != nil)
    }
}

// MARK: - (5) VoiceOver

@Suite("Lote 04 · (5) VoiceOver: selectores con nombre y la fila dice lo que queda")
struct PlanningVoiceOverWiringTests {

    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    private static func code(_ path: String) throws -> String {
        var raw = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        raw = raw.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: " ", options: .regularExpression)
        raw = raw.replacingOccurrences(of: #"(?m)//.*$"#, with: " ", options: .regularExpression)
        return raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    /// Un `Picker("")` o `Picker("Tab")` es lo que VoiceOver lee como nombre: nada, o «Tab».
    @Test func losSelectoresDePagosTienenNombre() throws {
        for path in ["Yala/App/Views/Planning/ScheduledPaymentsView.swift",
                     "Yala/App/Views/Planning/ScheduledPaymentEditorView.swift"] {
            let source = try Self.code(path)
            #expect(!source.contains(#"Picker("","#), "\(path): un selector sin nombre")
            #expect(!source.contains(#"Picker("Tab","#), "\(path): el segmentado se llama «Tab»")
        }
    }

    /// La fila combina sus hijos con etiqueta propia: tiene que decir lo que queda (o sobró, o te pasaste) y los días.
    @Test func laFilaDePresupuestoDiceLoQueQuedaYLosDias() throws {
        let source = try Self.code("Yala/App/Views/Planning/BudgetRowView.swift")
        let start = try #require(source.range(of: "private var accessibilityLabelText: String {"))
        let tail = String(source[start.upperBound...].prefix(400))
        #expect(tail.contains("remainingSpoken"), "La etiqueta de VoiceOver no dice lo que queda.")
        #expect(tail.contains("L10n.UXL9.shortDays(summary.daysRemaining)"), "La etiqueta de VoiceOver no dice los días.")
    }
}
