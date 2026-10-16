//
//  DevSeedFichaTests.swift
//  YalaTests
//
//  El perfil `ficha` siembra las cifras que citan los textos de las capturas de la App Store de cada idioma
//  (`ficha-app-store/textos/<idioma>.js`, objeto `OBJ`). Si una cifra de la semilla se mueve, la captura enseña otra
//  cosa que la lámina dibujada a su lado: estos tests atan las dos.
//
//  Los nombres van por L10n y aquí se comparan contra el mismo L10n, así que valen en el idioma que tenga el simulador.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct DevSeedFichaTests {

    // MARK: - La tabla por divisa

    @Test func cifras_usd_areTheEnglishStoreFigures() {
        let c = DevSeedFicha.cifras(forMainCurrency: "USD")
        #expect(c.groupFactor == 1)
        #expect(c.groupSecondaryCurrency == "EUR")
        #expect(c.foreignCurrency == "EUR")
        #expect(c.foreignBalance == 1_850)
        #expect(c.phone == 65)
        #expect(c.spotify == 11.99)
        #expect(c.pizza == 28, "«Pizza with friends 28» del vídeo en inglés")
    }

    @Test func cifras_brl_areTheBrazilianStoreFigures() {
        let c = DevSeedFicha.cifras(forMainCurrency: "BRL")
        #expect(c.groupFactor == 2)
        #expect(c.groupSecondaryCurrency == nil)
        #expect(c.foreignCurrency == "USD")
        #expect(c.foreignBalance == 3_615)
        #expect(c.phone == 59.90)
        #expect(c.spotify == 21.90)
        #expect(c.pizza == 90, "«Pizza com os amigos 90»: 280 reales no eran creíbles")
    }

    @Test func cifras_pen_areTheSpanishSetUnchanged() {
        let c = DevSeedFicha.cifras(forMainCurrency: "PEN")
        #expect(c == DevSeedFicha.Cifras(groupFactor: 1, groupSecondaryCurrency: "USD", foreignCurrency: "USD",
                                         foreignBalance: 33_615, phone: 60, spotify: 18,
                                         cash: 380, cardDebt: -1_284.30, pizza: 280))
    }

    // MARK: - Grupos

    @Test func createFicha_usd_youAreOwed190DollarsAndEuros() throws {
        let context = try makeTestContext()
        DevSeedGroups.createFicha(in: context, mainCurrency: "USD")

        let nets = try myNets(inGroupNamed: L10n.DevSeed.Ficha.groupTrip, context)
        #expect(abs((nets["USD"] ?? 0) - 190) < 0.01, "Te deben $190.00 (OBJ 06_grupos): \(nets)")
        #expect(abs((nets["EUR"] ?? 0) - 46.67) < 0.02, "La parte en euros de Lisboa: \(nets)")
        #expect(try paid(L10n.DevSeed.Ficha.expenseGroceries, context) == 120)
        #expect(try paid(L10n.DevSeed.Ficha.expenseLocalMeal, context) == 180)
    }

    @Test func createFicha_brl_isAllInReaisAndDoubled() throws {
        let context = try makeTestContext()
        DevSeedGroups.createFicha(in: context, mainCurrency: "BRL")

        let nets = try myNets(inGroupNamed: L10n.DevSeed.Ficha.groupTrip, context)
        #expect(Set(nets.keys) == ["BRL"], "En Río no se paga en dólares: \(nets)")
        #expect(abs((nets["BRL"] ?? 0) - 380) < 0.01, "Te devem R$ 380,00 (OBJ 06_grupos): \(nets)")
        #expect(try paid(L10n.DevSeed.Ficha.expenseGroceries, context) == 240)
        #expect(try paid(L10n.DevSeed.Ficha.expenseLocalMeal, context) == 360)
    }

    // MARK: - Vida personal

    @Test func adaptPersonalData_usd_landsTheTravelAccountOnItsExactBalance() throws {
        let context = try makeTestContext()
        let (main, savings) = try seedMiniPersonalLife(in: context)
        let totalBefore = try totalInMainCurrency(context)

        DevSeedFicha.adaptPersonalData(in: context, mainCurrency: "USD")

        #expect(main.currencyCode == "USD")
        #expect(savings.currencyCode == "EUR")
        #expect(savings.name == L10n.DevSeed.Ficha.accountForeign("EUR"))
        let balance = (savings.transactions ?? []).reduce(0) { $0 + $1.amount }
        #expect(abs(balance - 1_850) < 0.001, "Travel EUR: €1,850.00 exactos (OBJ 09_divisas), no \(balance)")
        #expect((savings.transactions ?? []).allSatisfy { $0.currencyCode == "EUR" && $0.preferredCurrencyCode == "USD" })
        let notes = try context.fetch(FetchDescriptor<TransactionItem>()).compactMap(\.note)
        #expect(notes.contains(L10n.DevSeed.noteTransferTo(savings.name)), "La transferencia nombra la cuenta nueva")
        #expect(!notes.contains(L10n.DevSeed.noteTransferTo(L10n.DevSeed.accountSavings)))
        // Lo que la cuenta extranjera deja de valer lo recupera la principal. Mueven el total Teléfono, que pasa de 60 a
        // 65, y las dos cuentas nuevas: efectivo +140 y la tarjeta −612,40.
        let totalAfter = try totalInMainCurrency(context)
        #expect(abs(totalAfter - (totalBefore - 5 + 140 - 612.40)) < 0.05, "El total pasó de \(totalBefore) a \(totalAfter)")
    }

    @Test func adaptPersonalData_movesFreelanceIncomeToTheMainAccountWithItsValue() throws {
        let context = try makeTestContext()
        let (main, savings) = try seedMiniPersonalLife(in: context)

        DevSeedFicha.adaptPersonalData(in: context, mainCurrency: "USD")

        let freelance = try #require(try context.fetch(FetchDescriptor<TransactionItem>()).first { $0.note == "freelance" })
        #expect(freelance.account?.name == main.name, "Un ingreso freelance en «Travel EUR» no tiene sentido")
        #expect(freelance.amount == 500 * 3.7 && freelance.currencyCode == "USD", "Conserva el valor que tenía")
        #expect(!(savings.transactions ?? []).contains { $0.note == "freelance" })
    }

    @Test func adaptPersonalData_transferLegsStayNeutral() throws {
        let context = try makeTestContext()
        _ = try seedMiniPersonalLife(in: context)

        DevSeedFicha.adaptPersonalData(in: context, mainCurrency: "BRL")

        let legs = try context.fetch(FetchDescriptor<TransactionItem>()).filter { $0.transferPairID == "par" }
        #expect(legs.count == 2)
        let sum = legs.reduce(0) { $0 + $1.amountInPreferredCurrency }
        #expect(abs(sum) < 0.02, "Lo que sale de la principal es lo que llega a la extranjera: \(legs.map(\.amountInPreferredCurrency))")
    }

    @Test func adaptPersonalData_brl_repricesPhoneAndAddsTheRealRate() throws {
        let context = try makeTestContext()
        let (main, savings) = try seedMiniPersonalLife(in: context)
        let totalBefore = try totalInMainCurrency(context)

        DevSeedFicha.adaptPersonalData(in: context, mainCurrency: "BRL")

        #expect(main.currencyCode == "BRL")
        #expect(savings.currencyCode == "USD")
        let balance = (savings.transactions ?? []).reduce(0) { $0 + $1.amount }
        #expect(abs(balance - 3_615) < 0.001, "Viagem USD: US$ 3.615,00 exactos, no \(balance)")
        let phone = try #require(try context.fetch(FetchDescriptor<ScheduledPayment>()).first)
        #expect(phone.amount == 59.90)
        #expect(phone.currencyCode == "BRL")
        let phoneCharges = try context.fetch(FetchDescriptor<TransactionItem>())
            .filter { $0.scheduledPaymentID == phone.id.uuidString }
        #expect(!phoneCharges.isEmpty && phoneCharges.allSatisfy { $0.amount == -59.90 })
        let row = try #require(try context.fetch(FetchDescriptor<ExchangeRate>()).first)
        #expect(row.decodedRates()["BRL"] != nil, "Sin la tasa del real la conversión caería al respaldo con «≈»")
        // El cargo de Teléfono pasa de 60 a 59,90, y entran efectivo (+320) y la tarjeta (−1.480,90).
        #expect(abs(try totalInMainCurrency(context) - (totalBefore + 0.10 + 320 - 1_480.90)) < 0.05)
    }

    /// La captura de «Tus cuentas» dice efectivo, tarjeta y ahorro: la semilla tiene que traer las dos primeras, en la
    /// divisa principal y con su saldo inicial en la fecha del de la principal (la curva del Saldo no salta).
    @Test func adaptPersonalData_addsCashAndCreditCardInTheMainCurrency() throws {
        let context = try makeTestContext()
        let (main, _) = try seedMiniPersonalLife(in: context)
        let mainInitialDate = try #require((main.transactions ?? []).first {
            $0.balanceAdjustmentType == InitialBalanceService.typeInitialBalance
        }).date

        DevSeedFicha.adaptPersonalData(in: context, mainCurrency: "BRL")
        DevSeedFicha.adaptPersonalData(in: context, mainCurrency: "BRL")   // idempotente: no las duplica

        let accounts = try context.fetch(FetchDescriptor<Account>())
        let cash = try #require(accounts.first { $0.name == L10n.Account.AccountType.cash })
        let card = try #require(accounts.first { $0.name == L10n.Account.AccountType.creditCard })
        #expect(accounts.filter { $0.name == cash.name || $0.name == card.name }.count == 2)
        #expect(cash.type == AccountType.cash.rawValue && card.type == AccountType.creditCard.rawValue)
        #expect(cash.currencyCode == "BRL" && card.currencyCode == "BRL")
        for (account, balance) in [(cash, 320.0), (card, -1_480.90)] {
            let txs = account.transactions ?? []
            #expect(txs.count == 1)
            let initial = try #require(txs.first)
            #expect(initial.amount == balance && initial.amountInPreferredCurrency == balance)
            #expect(initial.balanceAdjustmentType == InitialBalanceService.typeInitialBalance)
            #expect(initial.date == mainInitialDate, "En otra fecha la curva del Saldo saltaría ese día")
            #expect(!initial.isExchangeRateProvisional)
        }
    }

    @Test func adaptPersonalData_pen_leavesTheSpanishSetAsItIs() throws {
        let context = try makeTestContext()
        let (main, savings) = try seedMiniPersonalLife(in: context, savingsTotal: 33_615)
        let amounts = (savings.transactions ?? []).map(\.amount).sorted()

        DevSeedFicha.adaptPersonalData(in: context, mainCurrency: "PEN")

        #expect(main.currencyCode == "PEN")
        #expect(savings.currencyCode == "USD")
        #expect((savings.transactions ?? []).map(\.amount).sorted() == amounts)
    }

    // MARK: - Ayudas

    /// Lo mínimo del generador de `realista`: la cuenta principal en soles con su saldo inicial, un cargo de Teléfono y
    /// la pata de salida de una transferencia; la de ahorros en dólares con su saldo inicial, la pata de llegada y un
    /// ingreso freelance; y la fila de tasas del día. Saldo de ahorros: `savingsTotal`.
    private func seedMiniPersonalLife(
        in context: ModelContext,
        savingsTotal: Double = 33_615
    ) throws -> (main: Account, savings: Account) {
        let main = Account(name: L10n.DevSeed.accountMain, currencyCode: "PEN", colorHex: "#6366F1",
                           iconName: "creditcard.fill", type: AccountType.checking.rawValue)
        let savings = Account(name: L10n.DevSeed.accountSavings, currencyCode: "USD", colorHex: "#6366F1",
                              iconName: "banknote.fill", type: AccountType.savings.rawValue)
        context.insert(main)
        context.insert(savings)

        let phone = ScheduledPayment(
            name: L10n.DevSeed.spPhone, amount: 60, currencyCode: "PEN",
            transactionType: TransactionType.expense.rawValue, account: main, subcategory: nil,
            isRecurring: true, recurrenceType: "monthly", recurrenceInterval: 1, nextDueDate: .now, dayOfMonth: 15,
            paymentCategory: "recurring", notifyOnDueDate: true, notifyDaysBefore: 3, isVariableAmount: false
        )
        context.insert(phone)

        @discardableResult
        func tx(_ amount: Double, _ currency: String, _ account: Account, note: String? = nil) -> TransactionItem {
            let item = TransactionItem(
                date: .now, amount: amount, currencyCode: currency, note: note, category: nil, subcategory: nil,
                account: account, exchangeRate: currency == "PEN" ? 1 : 3.7,
                amountInPreferredCurrency: currency == "PEN" ? amount : amount * 3.7, preferredCurrencyCode: "PEN"
            )
            context.insert(item)
            return item
        }
        let mainInitial = tx(5_000, "PEN", main)
        mainInitial.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        let charge = tx(-60, "PEN", main)
        charge.scheduledPaymentID = phone.id.uuidString
        let out = tx(-30_000 * 3.7, "PEN", main, note: L10n.DevSeed.noteTransferTo(L10n.DevSeed.accountSavings))
        out.transferPairID = "par"
        let initial = tx(2_000, "USD", savings)
        initial.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        let into = tx(30_000, "USD", savings, note: L10n.DevSeed.noteTransferFrom(L10n.DevSeed.accountMain))
        into.transferPairID = "par"
        _ = tx(500, "USD", savings, note: "freelance")
        // Otra transferencia, con sus dos patas, hasta el saldo pedido.
        let rest = savingsTotal - 32_500
        tx(-rest * 3.7, "PEN", main, note: L10n.DevSeed.noteTransferTo(L10n.DevSeed.accountSavings)).transferPairID = "par-2"
        tx(rest, "USD", savings, note: L10n.DevSeed.noteTransferFrom(L10n.DevSeed.accountMain)).transferPairID = "par-2"

        context.insert(try ExchangeRate(
            dateKey: "2026-10-13", base: "USD", ratesDictionary: ["USD": 1, "PEN": 3.7, "EUR": 0.92]
        ))
        try context.save()
        return (main, savings)
    }

    /// El total de todas las cuentas en la divisa principal, como lo suma «Tus finanzas».
    private func totalInMainCurrency(_ context: ModelContext) throws -> Double {
        try context.fetch(FetchDescriptor<TransactionItem>()).reduce(0) { $0 + $1.amountInPreferredCurrency }
    }

    /// Neto del usuario por divisa en el grupo, con el cálculo de la app.
    private func myNets(inGroupNamed name: String, _ context: ModelContext) throws -> [String: Double] {
        let group = try #require(try context.fetch(FetchDescriptor<SplitGroup>()).first { $0.name == name })
        let zoneID = group.cloudKitZoneID
        let members = try context.fetch(FetchDescriptor<SplitMember>()).filter { $0.groupZoneID == zoneID }
        let me = try #require(members.first { $0.isCurrentUser })
        let balances = GroupBalanceService.calculateBalances(
            expenses: try context.fetch(FetchDescriptor<SplitExpense>()).filter { $0.groupZoneID == zoneID },
            shares: try context.fetch(FetchDescriptor<SplitShare>()).filter { $0.groupZoneID == zoneID },
            members: members,
            settlements: []
        )
        var nets: [String: Double] = [:]
        for b in balances where b.memberID == me.id.uuidString { nets[b.currencyCode, default: 0] += b.netBalance }
        return nets
    }

    private func paid(_ description: String, _ context: ModelContext) throws -> Double? {
        try context.fetch(FetchDescriptor<SplitExpense>()).first { $0.expenseDescription == description }?.amount
    }
}
