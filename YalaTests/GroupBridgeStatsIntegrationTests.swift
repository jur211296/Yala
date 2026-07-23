//
//  GroupBridgeStatsIntegrationTests.swift
//  YalaTests
//
//  Drift-guard: pinnea que las calculadoras de stats, alimentadas con un `GroupBridgeStatsAdjustment`
//  construido de un gasto de grupo Caso A bridgeado (pata real `-total` + pata lent `+lent`), muestran
//  "MI PARTE" (neto = -myShare) y NO el total que pagué — ni el "ingreso fantasma" +lent en CashFlow.
//
//  Escenario canónico: pagué 300, mi parte 100, lent = 200. Cuenta real = "Efectivo"; cuenta de
//  sistema = "Grupos"; la pata lent cuelga de una subcat de sistema income (loanToGroups).
//
//  `@Suite(.serialized)` por el reuso per-file de `makeTestContext`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Stats · gasto de grupo Caso A = mi parte (integración)", .serialized)
@MainActor
struct GroupBridgeStatsIntegrationTests {

    private static let testDate = Date(timeIntervalSince1970: 1_700_000_000)

    /// Interval que contiene `testDate`.
    private var interval: DateInterval {
        DateInterval(
            start: Self.testDate.addingTimeInterval(-86_400),
            end: Self.testDate.addingTimeInterval(86_400)
        )
    }

    private struct Fixture {
        let real: TransactionItem     // -300, cuenta real, categoría "Comida", con tag
        let lent: TransactionItem     // +200, cuenta sistema, subcat loanToGroups (income)
        let tag: YalaTag
        let adjustment: GroupBridgeStatsAdjustment
    }

    /// Crea la pareja Caso A y su adjustment.
    private func makeCasoAFixture(_ ctx: ModelContext) throws -> Fixture {
        let eid = UUID().uuidString

        // Cuenta real + categoría/subcat de usuario + tag.
        let realAcc = makeTestAccount(context: ctx, name: "Efectivo")
        let expenseCat = makeTestCategory(context: ctx, name: "Comida", isIncome: false)
        let userSub = makeTestSubcategory(context: ctx, name: "Restaurantes", category: expenseCat)
        let tag = makeTestTag(context: ctx, name: "Viaje")

        let real = TransactionItem(
            date: Self.testDate, amount: -300, currencyCode: "USD",
            category: expenseCat, subcategory: userSub, account: realAcc,
            tags: [tag], amountInPreferredCurrency: -300
        )
        real.preferredCurrencyCode = "USD"
        real.splitExpenseID = eid
        ctx.insert(real)

        // Cuenta de sistema + subcat de sistema income (loanToGroups) para la pata lent.
        let sysAcc = makeTestAccount(context: ctx, name: "Grupos")
        sysAcc.isSystemAccount = true
        let incomeCat = makeTestCategory(context: ctx, name: "Préstamo a grupos", isIncome: true)
        let loanSub = makeTestSubcategory(context: ctx, name: "loanToGroups", category: incomeCat)
        loanSub.isSystem = true

        let lent = TransactionItem(
            date: Self.testDate, amount: 200, currencyCode: "USD",
            category: incomeCat, subcategory: loanSub, account: sysAcc,
            amountInPreferredCurrency: 200
        )
        lent.preferredCurrencyCode = "USD"
        lent.splitExpenseID = eid
        ctx.insert(lent)
        try ctx.save()

        let adjustment = GroupBridgeStatsAdjustment.build(
            from: [real, lent], loanToGroupsSubcatIDs: [loanSub.persistentModelID]
        )
        return Fixture(real: real, lent: lent, tag: tag, adjustment: adjustment)
    }

    // MARK: - CashFlow: gasto neteado + SIN ingreso fantasma

    @Test func cashFlow_casoA_expenseIsMyShare_noPhantomIncome() throws {
        let ctx = try makeTestContext()
        let fx = try makeCasoAFixture(ctx)

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [fx.real, fx.lent],
            interval: interval,
            grouping: .day,
            currencyCode: "USD",
            adjustment: fx.adjustment
        )

        #expect(result.totalExpense == 100)   // mi parte, no 300
        #expect(result.totalIncome == 0)      // la lent (+200) NO cuenta como ingreso
        #expect(result.netFlow == -100)       // = -myShare
    }

    @Test func cashFlow_casoA_withoutAdjustment_stillInflated() throws {
        // Control: sin adjustment (.none) el bug persiste (gasto=300, ingreso fantasma=200).
        let ctx = try makeTestContext()
        let fx = try makeCasoAFixture(ctx)

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [fx.real, fx.lent], interval: interval, grouping: .day, currencyCode: "USD"
        )
        #expect(result.totalExpense == 300)
        #expect(result.totalIncome == 200)
        #expect(result.netFlow == -100)       // el neto siempre fue correcto; lo inflado son los buckets
    }

    // MARK: - Tag: la etiqueta suma mi parte

    @Test func tagSpending_casoA_tagShowsMyShare() throws {
        let ctx = try makeTestContext()
        let fx = try makeCasoAFixture(ctx)
        let allTags = try ctx.fetch(FetchDescriptor<YalaTag>())

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [fx.real, fx.lent],
            interval: interval,
            currencyCode: "USD",
            allTags: allTags,
            adjustment: fx.adjustment
        )

        let viajeTotal = result.first { $0.tag.persistentModelID == fx.tag.persistentModelID }?.amount
        #expect(viajeTotal == 100)            // mi parte, no 300
    }

    // MARK: - Categoría: el bucket de "Comida" es mi parte

    @Test func topCategories_casoA_bucketIsMyShare() throws {
        let ctx = try makeTestContext()
        let fx = try makeCasoAFixture(ctx)

        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: [fx.real, fx.lent],
            interval: interval,
            currencyCode: "USD",
            adjustment: fx.adjustment
        )

        // "Comida" (la categoría del gasto real) debe valer mi parte; la lent (income) no entra
        // a los buckets de gasto (nature income) y además está suprimida.
        let comida = result.first { $0.category.name == "Comida" }?.amount
        #expect(comida == 100)
        #expect(!result.contains { $0.category.name == "Préstamo a grupos" })
    }

    // MARK: - Weekday: el día del gasto suma mi parte

    @Test func weekday_casoA_dayIsMyShare() throws {
        let ctx = try makeTestContext()
        let fx = try makeCasoAFixture(ctx)

        let result = WeekdaySpendingCalculator.calculate(
            transactions: [fx.real, fx.lent],
            interval: interval,
            currencyCode: "USD",
            adjustment: fx.adjustment
        )
        let total = result.reduce(0) { $0 + $1.total }
        #expect(total == 100)                 // mi parte, no 300
    }
}
