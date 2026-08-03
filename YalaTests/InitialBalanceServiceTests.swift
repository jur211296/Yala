//
//  InitialBalanceServiceTests.swift
//  YalaTests
//
//  Unit tests for InitialBalanceService pure static logic (balance calculation, date computation).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct InitialBalanceServiceTests {

    // MARK: - Helpers

    private func makeAccount(name: String = "Test", currencyCode: String = "PEN") -> Account {
        Account(
            name: name,
            currencyCode: currencyCode,
            colorHex: "#000000",
            iconName: "creditcard",
            type: "bank"
        )
    }

    private func makeTransaction(
        amount: Double,
        date: Date = Date(),
        account: Account? = nil,
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "PEN",
            note: nil
        )
        tx.account = account
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    // MARK: - Type Constants

    @Test func typeConstants() {
        #expect(InitialBalanceService.typeInitialBalance == "initial_balance")
        #expect(InitialBalanceService.typeAdjustment == "adjustment")
    }

    // MARK: - currentBalance

    @MainActor @Test func currentBalance_emptyTransactions() {
        let account = makeAccount()
        let result = InitialBalanceService.currentBalance(for: account, allTransactions: [])
        #expect(result == 0.0)
    }

    @MainActor @Test func currentBalance_sumsAmounts() {
        let account = makeAccount()
        let tx1 = makeTransaction(amount: 100, account: account)
        let tx2 = makeTransaction(amount: -30, account: account)
        let tx3 = makeTransaction(amount: 50, account: account)

        let result = InitialBalanceService.currentBalance(
            for: account, allTransactions: [tx1, tx2, tx3]
        )
        #expect(result == 120.0)
    }

    @MainActor @Test func currentBalance_filtersOtherAccounts() {
        let myAccount = makeAccount(name: "Mine")
        let otherAccount = makeAccount(name: "Other")
        let tx1 = makeTransaction(amount: 100, account: myAccount)
        let tx2 = makeTransaction(amount: 500, account: otherAccount)

        let result = InitialBalanceService.currentBalance(
            for: myAccount, allTransactions: [tx1, tx2]
        )
        #expect(result == 100.0)
    }

    @MainActor @Test func currentBalance_includesAdjustments() {
        let account = makeAccount()
        let tx1 = makeTransaction(amount: 1000, account: account, balanceAdjustmentType: "initial_balance")
        let tx2 = makeTransaction(amount: -50, account: account)

        let result = InitialBalanceService.currentBalance(
            for: account, allTransactions: [tx1, tx2]
        )
        #expect(result == 950.0)
    }

    // MARK: - calculateInitialBalanceDate

    @MainActor @Test func calculateInitialBalanceDate_noTransactions_returnsFirstOfCurrentMonth() {
        let account = makeAccount()
        let result = InitialBalanceService.calculateInitialBalanceDate(
            for: account, allTransactions: []
        )

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: result)
        #expect(components.day == 1)
    }

    @MainActor @Test func calculateInitialBalanceDate_usesEarliestTransaction() {
        let account = makeAccount()
        let calendar = Calendar.current

        let earlyDate = calendar.date(from: DateComponents(year: 2025, month: 3, day: 15))!
        let lateDate = calendar.date(from: DateComponents(year: 2025, month: 6, day: 20))!

        let tx1 = makeTransaction(amount: -50, date: lateDate, account: account)
        let tx2 = makeTransaction(amount: -30, date: earlyDate, account: account)

        let result = InitialBalanceService.calculateInitialBalanceDate(
            for: account, allTransactions: [tx1, tx2]
        )

        let resultComponents = calendar.dateComponents([.year, .month, .day], from: result)
        #expect(resultComponents.year == 2025)
        #expect(resultComponents.month == 3)
        #expect(resultComponents.day == 1)
    }

    @MainActor @Test func calculateInitialBalanceDate_ignoresAdjustmentTransactions() {
        let account = makeAccount()
        let calendar = Calendar.current

        let adjustmentDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let realDate = calendar.date(from: DateComponents(year: 2025, month: 5, day: 10))!

        let adjustmentTx = makeTransaction(
            amount: 1000, date: adjustmentDate, account: account,
            balanceAdjustmentType: "initial_balance"
        )
        let realTx = makeTransaction(amount: -50, date: realDate, account: account)

        let result = InitialBalanceService.calculateInitialBalanceDate(
            for: account, allTransactions: [adjustmentTx, realTx]
        )

        let resultComponents = calendar.dateComponents([.year, .month, .day], from: result)
        #expect(resultComponents.year == 2025)
        #expect(resultComponents.month == 5)
        #expect(resultComponents.day == 1)
    }

    @MainActor @Test func calculateInitialBalanceDate_ignoresOtherAccountTransactions() {
        let myAccount = makeAccount(name: "Mine")
        let otherAccount = makeAccount(name: "Other")
        let calendar = Calendar.current

        let earlyDate = calendar.date(from: DateComponents(year: 2024, month: 2, day: 5))!
        let lateDate = calendar.date(from: DateComponents(year: 2025, month: 8, day: 15))!

        let otherTx = makeTransaction(amount: -100, date: earlyDate, account: otherAccount)
        let myTx = makeTransaction(amount: -50, date: lateDate, account: myAccount)

        let result = InitialBalanceService.calculateInitialBalanceDate(
            for: myAccount, allTransactions: [otherTx, myTx]
        )

        let resultComponents = calendar.dateComponents([.year, .month, .day], from: result)
        #expect(resultComponents.year == 2025)
        #expect(resultComponents.month == 8)
        #expect(resultComponents.day == 1)
    }
}

// MARK: - Multi-Currency Snapshot Consistency
//
// Estos tests verifican que `setInitialBalance` y `createAdjustment` mantienen
// `amountInPreferredCurrency` y `preferredCurrencyCode` consistentes con la
// moneda preferida del usuario tras la inserción (fix B1 del Anexo A del plan
// Live Balance multi-currency). Tocan `UserDefaults.standard` por la lectura
// de `CurrencyDefaults.currentPreferred`, por eso la suite es `.serialized`.

@MainActor
@Suite(.serialized)
struct InitialBalanceServiceMultiCurrencyTests {

    private let preferredCurrencyKey = "defaultCurrencyCode"

    private func makeIsolatedContext() throws -> ModelContext {
        let schema = Schema([
            Account.self, TransactionItem.self, Subcategory.self, YalaCategory.self,
            ExchangeRate.self, Tag.self, Budget.self, ScheduledPayment.self, InboxDraft.self,
        ])
        // `cloudKitDatabase: .none` NO es cosmético: con el default `.automatic`, y con un schema
        // que tiene relaciones, SwiftData adjunta `NSPersistentCloudKitContainer` incluso a un store
        // in-memory (`file:///dev/null`). En el simulador, que no tiene cuenta iCloud, su setup falla
        // con `CKAccountStatusNoAccount` (134400), `recoverFromError:` tampoco puede, y la conexión
        // SQL queda desmontada ⇒ el `save()` siguiente muere con la excepción ObjC
        // `NSInternalInconsistencyException "No eligible connection available"`, que el `do/catch`
        // de Swift NO atrapa: SIGABRT y runner reiniciado. Mismo motivo (y mismo comentario) que en
        // `TestHelpers.testContainer(for:)`.
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Persiste un rate con fecha lejana en el pasado para que `getRatesForDate`
    /// lo encuentre vía el fallback "most recent on or before" para cualquier
    /// fecha que use el test (`setInitialBalance` usa el primer día del mes
    /// más antiguo, que puede no coincidir con "hoy").
    private func persistRate(
        context: ModelContext,
        rates: [String: Double] = ["USD": 1.0, "PEN": 3.5, "EUR": 0.92],
        dateKey: String = "2020-01-01"
    ) throws {
        let rate = try ExchangeRate(
            dateKey: dateKey,
            base: "USD",
            ratesDictionary: rates
        )
        context.insert(rate)
        try context.save()
    }

    /// Helper: setea moneda preferida temporalmente, restaura al final.
    private func withPreferredCurrency(_ code: String, _ block: () throws -> Void) rethrows {
        let original = UserDefaults.standard.string(forKey: preferredCurrencyKey)
        UserDefaults.standard.set(code, forKey: preferredCurrencyKey)
        defer {
            if let original = original {
                UserDefaults.standard.set(original, forKey: preferredCurrencyKey)
            } else {
                UserDefaults.standard.removeObject(forKey: preferredCurrencyKey)
            }
        }
        try block()
    }

    private func makeSubcategory(in context: ModelContext) -> Subcategory {
        let category = YalaCategory(name: "Otros", colorHex: "#000000", isIncome: false)
        context.insert(category)
        let subcategory = Subcategory(
            name: "Ajuste de saldo",
            colorHex: "#000000",
            natureRawValue: "sin_clasificacion",
            iconName: "plusminus",
            category: category
        )
        context.insert(subcategory)
        return subcategory
    }

    @Test func setInitialBalance_setsPreferredCurrencyConsistently() throws {
        try withPreferredCurrency("PEN") {
            let context = try makeIsolatedContext()
            try persistRate(context: context)

            let account = Account(
                name: "USD account",
                currencyCode: "USD",
                colorHex: "#000000",
                iconName: "creditcard",
                type: "bank"
            )
            context.insert(account)
            let subcategory = makeSubcategory(in: context)

            let tx = InitialBalanceService.setInitialBalance(
                amount: 1000,
                for: account,
                subcategory: subcategory,
                allTransactions: [],
                context: context
            )

            // Snapshot consistente con moneda preferida del usuario, no con la
            // moneda nativa de la cuenta.
            #expect(tx.preferredCurrencyCode == "PEN")
            // 1000 USD * 3.5 = 3500 PEN (al TC del día persistido).
            #expect(abs(tx.amountInPreferredCurrency - 3500) < 0.01)
            // Tx nativa sigue en USD.
            #expect(tx.currencyCode == "USD")
            #expect(tx.amount == 1000)
        }
    }

    @Test func setInitialBalance_removesAllInitialBalanceZombies() throws {
        try withPreferredCurrency("USD") {
            let context = try makeIsolatedContext()
            try persistRate(context: context)

            let account = Account(
                name: "Test",
                currencyCode: "USD",
                colorHex: "#000000",
                iconName: "creditcard",
                type: "bank"
            )
            context.insert(account)
            let subcategory = makeSubcategory(in: context)

            // Tres "zombies" de saldo inicial preexistentes (simulando un bug previo).
            var allTx: [TransactionItem] = []
            for amount in [100.0, 200.0, 300.0] {
                let zombie = TransactionItem(
                    date: Date(),
                    amount: amount,
                    currencyCode: "USD",
                    note: nil
                )
                zombie.account = account
                zombie.subcategory = subcategory
                zombie.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
                context.insert(zombie)
                allTx.append(zombie)
            }
            try context.save()

            // Llamar setInitialBalance con el listado actual.
            _ = InitialBalanceService.setInitialBalance(
                amount: 999,
                for: account,
                subcategory: subcategory,
                allTransactions: allTx,
                context: context
            )
            try context.save()

            // Solo debe quedar 1 initial_balance para esta cuenta (el nuevo).
            let descriptor = FetchDescriptor<TransactionItem>()
            let remaining = try context.fetch(descriptor)
            let initialBalances = remaining.filter {
                $0.account?.persistentModelID == account.persistentModelID
                    && $0.balanceAdjustmentType == InitialBalanceService.typeInitialBalance
            }
            #expect(initialBalances.count == 1)
            #expect(initialBalances.first?.amount == 999)
        }
    }

    @Test func createAdjustment_setsPreferredCurrencyConsistently() throws {
        try withPreferredCurrency("PEN") {
            let context = try makeIsolatedContext()
            try persistRate(context: context)

            let account = Account(
                name: "USD account",
                currencyCode: "USD",
                colorHex: "#000000",
                iconName: "creditcard",
                type: "bank"
            )
            context.insert(account)
            let subcategory = makeSubcategory(in: context)

            // targetBalance 200 USD, currentBalance 50 USD → adjustment +150 USD.
            let tx = InitialBalanceService.createAdjustment(
                targetBalance: 200,
                currentBalance: 50,
                for: account,
                subcategory: subcategory,
                date: Date.now,
                context: context
            )

            #expect(tx.amount == 150)  // ajuste en moneda nativa
            #expect(tx.currencyCode == "USD")
            #expect(tx.preferredCurrencyCode == "PEN")
            // 150 USD * 3.5 = 525 PEN.
            #expect(abs(tx.amountInPreferredCurrency - 525) < 0.01)
            #expect(tx.balanceAdjustmentType == InitialBalanceService.typeAdjustment)
        }
    }
}
