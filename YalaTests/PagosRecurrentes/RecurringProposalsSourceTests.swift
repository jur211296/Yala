//
//  RecurringProposalsSourceTests.swift
//  YalaTests
//
//  El puente con el almacén (lote S1): qué registros cuentan como cobro, de dónde salen la cuenta y la categoría del
//  pago, y que crear el pago con el guardado del editor apaga la propuesta sin tocar los registros (decisión S4).
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@MainActor
@Suite("Pagos que se repiten · historial", .serialized)
struct RecurringProposalsSourceTests {

    private static let calendar = Calendar.current

    /// «Ahora» fijo a mitad de mes, en la zona del test.
    private static let now: Date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12)) ?? .now

    private static func monthsAgo(_ months: Int, day: Int) -> Date {
        let base = calendar.date(byAdding: .month, value: -months, to: now) ?? now
        var components = calendar.dateComponents([.year, .month], from: base)
        components.day = day
        components.hour = 10
        return calendar.date(from: components) ?? base
    }

    private struct Fixture {
        let context: ModelContext
        let account: Account
        let expense: YalaCategory
        let streaming: Subcategory
        let income: YalaCategory
        let salary: Subcategory
    }

    private func makeFixture() throws -> Fixture {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Visa BCP")
        let expense = makeTestCategory(context: context, name: "Ocio")
        let streaming = makeTestSubcategory(context: context, name: "Streaming", category: expense)
        let income = makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        let salary = makeTestSubcategory(context: context, name: "Sueldo", category: income)
        return Fixture(context: context, account: account, expense: expense, streaming: streaming,
                       income: income, salary: salary)
    }

    @discardableResult
    private func addCharges(
        _ fixture: Fixture, note: String, day: Int, amount: Double = -44.90, months: [Int] = [3, 2, 1, 0],
        category: YalaCategory? = nil, subcategory: Subcategory? = nil, account: Account? = nil,
        configure: (TransactionItem) -> Void = { _ in }
    ) -> [TransactionItem] {
        months.map { monthsBack in
            let tx = TransactionItem(
                date: Self.monthsAgo(monthsBack, day: day), amount: amount, currencyCode: "PEN", note: note,
                category: category ?? fixture.expense, subcategory: subcategory ?? fixture.streaming,
                account: account ?? fixture.account
            )
            configure(tx)
            fixture.context.insert(tx)
            return tx
        }
    }

    private func load(_ fixture: Fixture) throws -> [RecurringProposalsSource.Item] {
        try fixture.context.save()
        return try RecurringProposalsSource.load(context: fixture.context, now: Self.now, calendar: Self.calendar)
    }

    // MARK: - Qué cuenta como cobro

    @Test func gastoMensual_seProponeConSuCuentaYCategoria() throws {
        let fixture = try makeFixture()
        addCharges(fixture, note: "Netflix", day: 14)

        let item = try #require(try load(fixture).first)
        #expect(item.proposal.brandID == "netflix")
        #expect(item.account?.persistentModelID == fixture.account.persistentModelID)
        #expect(item.subcategory?.persistentModelID == fixture.streaming.persistentModelID)
    }

    @Test func ingresosTransferenciasYGastosDeGrupo_noCuentan() throws {
        let fixture = try makeFixture()
        addCharges(fixture, note: "Sueldo", day: 1, amount: 3000, category: fixture.income, subcategory: fixture.salary)
        addCharges(fixture, note: "Ahorro mensual", day: 2) { $0.transferPairID = UUID().uuidString }
        addCharges(fixture, note: "Ajuste", day: 3) { $0.balanceAdjustmentType = "adjustment" }
        addCharges(fixture, note: "Depa compartido", day: 4) { $0.splitGroupZoneID = "zona-grupo" }
        addCharges(fixture, note: "Cena del grupo", day: 5) { $0.splitExpenseID = UUID().uuidString }
        addCharges(fixture, note: "Liquidación", day: 6) { $0.splitSettlementID = UUID().uuidString }
        addCharges(fixture, note: "   ", day: 7)
        // Una devolución (positiva en una categoría de gasto) no es un cobro.
        addCharges(fixture, note: "Devolución tienda", day: 8, amount: 40)

        #expect(try load(fixture).isEmpty)
    }

    @Test func unaDevolucionNoRompeLaSerie() throws {
        let fixture = try makeFixture()
        addCharges(fixture, note: "Netflix", day: 5, amount: -40)
        // Devolución de Netflix dos días después del último cobro: con ella como «último cobro» no saldría nada.
        let refundDate = Self.calendar.date(byAdding: .day, value: 2, to: Self.monthsAgo(0, day: 5)) ?? Self.now
        fixture.context.insert(TransactionItem(
            date: refundDate, amount: 40, currencyCode: "PEN", note: "Netflix",
            category: fixture.expense, subcategory: fixture.streaming, account: fixture.account
        ))

        let item = try #require(try load(fixture).first)
        #expect(item.proposal.chargeCount == 4)
        #expect(item.proposal.amount == 40)
    }

    @Test func loQueGeneroUnPagoQueExiste_noCuenta_peroSiElPagoSeBorro() throws {
        let fixture = try makeFixture()
        let payment = ScheduledPayment(name: "Cable", amount: 90, currencyCode: "PEN", nextDueDate: Self.now)
        fixture.context.insert(payment)
        addCharges(fixture, note: "Cable", day: 9) { $0.scheduledPaymentID = payment.id.uuidString }
        #expect(try load(fixture).isEmpty)

        // Borrado el pago planificado, sus cobros vuelven a ser historial y se propone otra vez.
        fixture.context.delete(payment)
        #expect(try load(fixture).count == 1)
    }

    @Test func cuentaArchivadaEnElUltimoCobro_tomaLaAnteriorActiva() throws {
        let fixture = try makeFixture()
        let archived = makeTestAccount(context: fixture.context, name: "Tarjeta vieja")
        archived.isArchived = true
        addCharges(fixture, note: "Spotify", day: 18, amount: -18.90, months: [3, 2, 1])
        addCharges(fixture, note: "Spotify", day: 18, amount: -18.90, months: [0], account: archived)

        let item = try #require(try load(fixture).first)
        #expect(item.account?.persistentModelID == fixture.account.persistentModelID)
    }

    // MARK: - Crear el pago

    @Test func crearConElGuardadoDelEditor_apagaLaPropuesta_ySinTocarLosRegistros() throws {
        let fixture = try makeFixture()
        let charges = addCharges(fixture, note: "Netflix", day: 14)
        let item = try #require(try load(fixture).first)

        let plan = RecurringProposalPlan(
            proposal: item.proposal, firstCharge: item.proposal.nextDueDate, reminder: .default, calendar: Self.calendar
        )
        let editor = ScheduledPaymentEditorViewModel()
        editor.setContext(fixture.context, deletionService: EntityDeletionService.shared)
        let savedID = editor.savePayment(
            existing: nil, name: item.proposal.displayName, amount: item.proposal.amount, note: "",
            currencyCode: item.proposal.currencyCode, transactionType: "expense",
            paymentCategory: plan.paymentCategory, account: item.account, subcategory: item.subcategory,
            selectedTags: [], isRecurring: true, recurrenceType: plan.recurrenceType, recurrenceInterval: 1,
            paymentDate: plan.paymentDate, dayOfMonth: plan.dayOfMonth, selectedWeekdays: plan.weekdays,
            yearlyMonth: nil, yearlyDay: nil, endDate: nil, notifyOnDueDate: plan.notifyOnDueDate,
            notifyDaysBefore: plan.notifyDaysBefore, isActive: true, isVariableAmount: plan.isVariableAmount,
            brandLogoID: .some(nil)
        )

        let id = try #require(savedID)
        let payment = try #require(try fixture.context.fetch(
            FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == id })
        ).first)
        #expect(payment.name == "Netflix")
        #expect(payment.paymentCategory == PaymentCategory.subscription.rawValue)
        #expect(payment.recurrenceType == RecurrenceType.monthly.rawValue)
        #expect(payment.dayOfMonth == 14)
        #expect(payment.nextDueDate == Self.calendar.startOfDay(for: item.proposal.nextDueDate))
        #expect(payment.notifyDaysBefore == 1)
        #expect(payment.subscriptionBrand?.id == "netflix")

        // La propuesta ya no sale: hay un pago parecido.
        #expect(try load(fixture).isEmpty)
        // Los registros pasados no se enlazan ni cambian (S4).
        #expect(charges.allSatisfy { $0.scheduledPaymentID == nil })
    }
}
