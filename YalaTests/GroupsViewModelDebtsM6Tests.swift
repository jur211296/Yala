//
//  GroupsViewModelDebtsM6Tests.swift
//  YalaTests
//
//  M6 D3: tests pure-logic de `GroupsViewModel.computeCurrentUserDebts(...)`.
//  Estilo Splitwise: filtra debts del current user, agrega perspective + counterpartyName.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct GroupsViewModelDebtsM6Tests {

    // MARK: - Helpers

    private func makeMember(id: UUID = UUID(), name: String, isCurrentUser: Bool = false) -> SplitMember {
        let m = SplitMember(displayName: name, isCurrentUser: isCurrentUser)
        m.id = id
        return m
    }

    private func makeExpense(
        id: UUID = UUID(),
        amount: Double,
        currencyCode: String = "PEN",
        paidByMemberID: String
    ) -> SplitExpense {
        let e = SplitExpense(
            groupZoneID: "test-zone",
            amount: amount,
            currencyCode: currencyCode,
            expenseDescription: "Test",
            paidByMemberID: paidByMemberID
        )
        e.id = id
        return e
    }

    private func makeShare(expenseID: UUID, memberID: String, amount: Double) -> SplitShare {
        SplitShare(expenseID: expenseID, memberID: memberID, amount: amount)
    }

    private func makeDebtRow(
        counterparty: String = "X",
        amount: Double,
        currency: String = "PEN",
        perspective: GroupsViewModel.Perspective,
        converted: Bool = false
    ) -> GroupsViewModel.DebtRow {
        GroupsViewModel.DebtRow(
            id: "\(counterparty)-\(currency)-\(amount)",
            counterpartyName: counterparty,
            amount: amount,
            currencyCode: currency,
            perspective: perspective,
            wasConverted: converted
        )
    }

    // MARK: - Empty / no current user

    @Test func computeCurrentUserDebts_emptyWhenNoMembers() {
        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [], expenses: [], shares: [], settlements: [], simplifyDebts: true
        )
        #expect(result.isEmpty)
    }

    @Test func computeCurrentUserDebts_emptyWhenNoCurrentUser() {
        // Ningún miembro tiene isCurrentUser=true.
        let other = makeMember(name: "Maria")
        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [other], expenses: [], shares: [], settlements: [], simplifyDebts: true
        )
        #expect(result.isEmpty)
    }

    @Test func computeCurrentUserDebts_emptyWhenNoExpenses() {
        let me = makeMember(name: "Me", isCurrentUser: true)
        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me], expenses: [], shares: [], settlements: [], simplifyDebts: true
        )
        #expect(result.isEmpty)
    }

    // MARK: - Filter para current user

    @Test func computeCurrentUserDebts_filtersForCurrentUserOnly() {
        // Maria pagó $100, dividido entre Maria, Juan y yo (Me).
        // Debts: Juan→Maria $33.33, Me→Maria $33.33.
        // currentUserDebts solo debe incluir Me→Maria.
        let me = makeMember(name: "Me", isCurrentUser: true)
        let maria = makeMember(name: "Maria")
        let juan = makeMember(name: "Juan")
        let exp = makeExpense(amount: 99, paidByMemberID: maria.id.uuidString)
        let shares = [
            makeShare(expenseID: exp.id, memberID: me.id.uuidString, amount: 33),
            makeShare(expenseID: exp.id, memberID: juan.id.uuidString, amount: 33),
            makeShare(expenseID: exp.id, memberID: maria.id.uuidString, amount: 33)
        ]
        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me, maria, juan],
            expenses: [exp], shares: shares, settlements: [], simplifyDebts: true
        )
        #expect(result.count == 1)
        #expect(result.first?.counterpartyName == "Maria")
        #expect(result.first?.perspective == .iOwe)
        #expect(result.first?.amount == 33)
    }

    // MARK: - Perspectiva

    @Test func computeCurrentUserDebts_perspectiveIOweCorrect() {
        // Otro pagó, yo le debo.
        let me = makeMember(name: "Me", isCurrentUser: true)
        let maria = makeMember(name: "Maria")
        let exp = makeExpense(amount: 50, paidByMemberID: maria.id.uuidString)
        let shares = [
            makeShare(expenseID: exp.id, memberID: me.id.uuidString, amount: 25),
            makeShare(expenseID: exp.id, memberID: maria.id.uuidString, amount: 25)
        ]
        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me, maria], expenses: [exp], shares: shares, settlements: [], simplifyDebts: true
        )
        #expect(result.first?.perspective == .iOwe)
        #expect(result.first?.counterpartyName == "Maria")
        #expect(result.first?.amount == 25)
    }

    @Test func computeCurrentUserDebts_perspectiveTheyOweMeCorrect() {
        // Yo pagué, ella me debe.
        let me = makeMember(name: "Me", isCurrentUser: true)
        let maria = makeMember(name: "Maria")
        let exp = makeExpense(amount: 50, paidByMemberID: me.id.uuidString)
        let shares = [
            makeShare(expenseID: exp.id, memberID: me.id.uuidString, amount: 25),
            makeShare(expenseID: exp.id, memberID: maria.id.uuidString, amount: 25)
        ]
        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me, maria], expenses: [exp], shares: shares, settlements: [], simplifyDebts: true
        )
        #expect(result.first?.perspective == .theyOweMe)
        #expect(result.first?.counterpartyName == "Maria")
        #expect(result.first?.amount == 25)
    }

    // MARK: - Multi-currency

    @Test func computeCurrentUserDebts_handlesMultiCurrency() {
        // Maria pagó S/100 (dividido), Juan pagó USD 50 (dividido).
        let me = makeMember(name: "Me", isCurrentUser: true)
        let maria = makeMember(name: "Maria")
        let juan = makeMember(name: "Juan")

        let exp1 = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: maria.id.uuidString)
        let shares1 = [
            makeShare(expenseID: exp1.id, memberID: me.id.uuidString, amount: 50),
            makeShare(expenseID: exp1.id, memberID: maria.id.uuidString, amount: 50)
        ]

        let exp2 = makeExpense(amount: 50, currencyCode: "USD", paidByMemberID: juan.id.uuidString)
        let shares2 = [
            makeShare(expenseID: exp2.id, memberID: me.id.uuidString, amount: 25),
            makeShare(expenseID: exp2.id, memberID: juan.id.uuidString, amount: 25)
        ]

        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me, maria, juan],
            expenses: [exp1, exp2], shares: shares1 + shares2, settlements: [], simplifyDebts: true
        )
        #expect(result.count == 2)
        let currencies = Set(result.map(\.currencyCode))
        #expect(currencies == ["PEN", "USD"])
    }

    // MARK: - Sort by amount desc

    @Test func computeCurrentUserDebts_sortedByAmountDesc() {
        let me = makeMember(name: "Me", isCurrentUser: true)
        let maria = makeMember(name: "Maria")
        let juan = makeMember(name: "Juan")

        let exp1 = makeExpense(amount: 200, paidByMemberID: maria.id.uuidString)
        let shares1 = [
            makeShare(expenseID: exp1.id, memberID: me.id.uuidString, amount: 100),
            makeShare(expenseID: exp1.id, memberID: maria.id.uuidString, amount: 100)
        ]

        let exp2 = makeExpense(amount: 80, paidByMemberID: juan.id.uuidString)
        let shares2 = [
            makeShare(expenseID: exp2.id, memberID: me.id.uuidString, amount: 40),
            makeShare(expenseID: exp2.id, memberID: juan.id.uuidString, amount: 40)
        ]

        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me, maria, juan],
            expenses: [exp1, exp2], shares: shares1 + shares2, settlements: [], simplifyDebts: true
        )
        #expect(result.count == 2)
        #expect(result[0].amount == 100)
        #expect(result[1].amount == 40)
    }

    // MARK: - F3: convertTo / wasConverted (multi-currency display)

    @Test func computeCurrentUserDebts_withConvertTo_consolidatesCrossCurrency() {
        // Maria pagó S/100 (yo debo S/50), Juan pagó USD 50 (yo debo USD 25).
        // convertTo = "PEN", mock 1 USD = 3.8 PEN → debts USD consolidan a PEN.
        let me = makeMember(name: "Me", isCurrentUser: true)
        let maria = makeMember(name: "Maria")
        let juan = makeMember(name: "Juan")

        let exp1 = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: maria.id.uuidString)
        let shares1 = [
            makeShare(expenseID: exp1.id, memberID: me.id.uuidString, amount: 50),
            makeShare(expenseID: exp1.id, memberID: maria.id.uuidString, amount: 50)
        ]

        let exp2 = makeExpense(amount: 50, currencyCode: "USD", paidByMemberID: juan.id.uuidString)
        let shares2 = [
            makeShare(expenseID: exp2.id, memberID: me.id.uuidString, amount: 25),
            makeShare(expenseID: exp2.id, memberID: juan.id.uuidString, amount: 25)
        ]

        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me, maria, juan],
            expenses: [exp1, exp2], shares: shares1 + shares2, settlements: [],
            simplifyDebts: true,
            convertTo: "PEN",
            converter: MockCurrencyConverter(fixedRate: 3.8)
        )
        // Todos los rows quedan en PEN tras consolidatedDebts.
        let currencies = Set(result.map(\.currencyCode))
        #expect(currencies == ["PEN"])
        // Todos los rows marcados como wasConverted (había debts USD ≠ target).
        #expect(result.allSatisfy { $0.wasConverted })
    }

    @Test func computeCurrentUserDebts_withNilConvertTo_preservesMultiCurrency() {
        // Sin convertTo: rows separados por currency, wasConverted=false.
        let me = makeMember(name: "Me", isCurrentUser: true)
        let maria = makeMember(name: "Maria")
        let juan = makeMember(name: "Juan")

        let exp1 = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: maria.id.uuidString)
        let shares1 = [
            makeShare(expenseID: exp1.id, memberID: me.id.uuidString, amount: 50),
            makeShare(expenseID: exp1.id, memberID: maria.id.uuidString, amount: 50)
        ]

        let exp2 = makeExpense(amount: 50, currencyCode: "USD", paidByMemberID: juan.id.uuidString)
        let shares2 = [
            makeShare(expenseID: exp2.id, memberID: me.id.uuidString, amount: 25),
            makeShare(expenseID: exp2.id, memberID: juan.id.uuidString, amount: 25)
        ]

        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me, maria, juan],
            expenses: [exp1, exp2], shares: shares1 + shares2, settlements: [],
            simplifyDebts: true,
            convertTo: nil
        )
        let currencies = Set(result.map(\.currencyCode))
        #expect(currencies == ["PEN", "USD"])
        #expect(result.allSatisfy { !$0.wasConverted })
    }

    @Test func computeCurrentUserDebts_withConvertTo_sameCurrencyOnly_setsWasConvertedFalse() {
        // Todos los debts están ya en PEN, convertTo="PEN" → no hay conversión real.
        let me = makeMember(name: "Me", isCurrentUser: true)
        let maria = makeMember(name: "Maria")

        let exp = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: maria.id.uuidString)
        let shares = [
            makeShare(expenseID: exp.id, memberID: me.id.uuidString, amount: 50),
            makeShare(expenseID: exp.id, memberID: maria.id.uuidString, amount: 50)
        ]

        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me, maria],
            expenses: [exp], shares: shares, settlements: [],
            simplifyDebts: true,
            convertTo: "PEN",
            converter: MockCurrencyConverter(fixedRate: 3.8)
        )
        #expect(result.count == 1)
        #expect(result.first?.currencyCode == "PEN")
        #expect(result.first?.wasConverted == false)
    }

    @Test func computeCurrentUserDebts_handlesMissingExchangeRateGracefully() {
        // Mock con rate=1 simula "sin TC disponible" — la conversión USD→PEN devuelve el
        // mismo amount. Aún así, hay intención de convertir (debts USD existen) → wasConverted=true.
        let me = makeMember(name: "Me", isCurrentUser: true)
        let juan = makeMember(name: "Juan")

        let exp = makeExpense(amount: 50, currencyCode: "USD", paidByMemberID: juan.id.uuidString)
        let shares = [
            makeShare(expenseID: exp.id, memberID: me.id.uuidString, amount: 25),
            makeShare(expenseID: exp.id, memberID: juan.id.uuidString, amount: 25)
        ]

        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me, juan],
            expenses: [exp], shares: shares, settlements: [],
            simplifyDebts: true,
            convertTo: "PEN",
            converter: MockCurrencyConverter(fixedRate: 1.0)
        )
        #expect(result.count == 1)
        #expect(result.first?.currencyCode == "PEN")
        #expect(result.first?.wasConverted == true)
        // Amount = 25 (USD original) * 1 (mock rate) = 25 — sin crash.
        #expect(result.first?.amount == 25)
    }

    // MARK: - Respeta el toggle de simplificación (regresión: card vs detalle)

    @Test func computeCurrentUserDebts_respectsSimplifyToggle() {
        // Yo (Me) soy acreedor; Beto y Ana me deben, y Beto además le debe a Ana.
        // E1: Me paga 100 → Beto debe 60, Ana debe 30 (Me 10 propio, no genera deuda).
        // E2: Ana paga 40 → Beto debe 20 (Ana 20 propio).
        // Raw: Beto→Me 60, Ana→Me 30, Beto→Ana 20.  Net: Me +90, Beto -80, Ana -10.
        let me = makeMember(name: "Me", isCurrentUser: true)
        let beto = makeMember(name: "Beto")
        let ana = makeMember(name: "Ana")

        let e1 = makeExpense(amount: 100, paidByMemberID: me.id.uuidString)
        let e1Shares = [
            makeShare(expenseID: e1.id, memberID: beto.id.uuidString, amount: 60),
            makeShare(expenseID: e1.id, memberID: ana.id.uuidString, amount: 30),
            makeShare(expenseID: e1.id, memberID: me.id.uuidString, amount: 10)
        ]
        let e2 = makeExpense(amount: 40, paidByMemberID: ana.id.uuidString)
        let e2Shares = [
            makeShare(expenseID: e2.id, memberID: beto.id.uuidString, amount: 20),
            makeShare(expenseID: e2.id, memberID: ana.id.uuidString, amount: 20)
        ]
        let members = [me, beto, ana]
        let expenses = [e1, e2]
        let shares = e1Shares + e2Shares

        // Simplificado: Beto→Me 80, Ana→Me 10 (Me único acreedor; colapsa la deuda Beto→Ana).
        let simplified = GroupsViewModel.computeCurrentUserDebts(
            members: members, expenses: expenses, shares: shares, settlements: [],
            simplifyDebts: true
        )
        #expect(simplified.count == 2)
        #expect(simplified.allSatisfy { $0.perspective == .theyOweMe })
        #expect(simplified[0].counterpartyName == "Beto")
        #expect(simplified[0].amount == 80)
        #expect(simplified[1].counterpartyName == "Ana")
        #expect(simplified[1].amount == 10)

        // Sin simplificar: Beto→Me 60, Ana→Me 30 (la deuda Beto→Ana no involucra a Me → filtrada).
        let raw = GroupsViewModel.computeCurrentUserDebts(
            members: members, expenses: expenses, shares: shares, settlements: [],
            simplifyDebts: false
        )
        #expect(raw.count == 2)
        #expect(raw.allSatisfy { $0.perspective == .theyOweMe })
        #expect(raw[0].counterpartyName == "Beto")
        #expect(raw[0].amount == 60)
        #expect(raw[1].counterpartyName == "Ana")
        #expect(raw[1].amount == 30)

        // El toggle DEBE cambiar los montos mostrados (causa raíz del bug reportado).
        // Variables intermedias tipadas para no exceder el type-checker dentro de #expect.
        let simplifiedAmounts: [Double] = simplified.map(\.amount)
        let rawAmounts: [Double] = raw.map(\.amount)
        #expect(simplifiedAmounts != rawAmounts)
        // Pero el neto del current user es invariante (suma = 90 en ambos) → el header
        // "Te deben" cuadra independientemente del toggle.
        let simplifiedSum: Double = simplifiedAmounts.reduce(0, +)
        let rawSum: Double = rawAmounts.reduce(0, +)
        #expect(simplifiedSum == rawSum)
    }

    // MARK: - groupDebtsByDirection (trailing de la card)

    @Test func groupDebtsByDirection_emptyWhenNoDebts() {
        let result = GroupsViewModel.groupDebtsByDirection([])
        #expect(result.isEmpty)
        #expect(result.owedToMe.isEmpty)
        #expect(result.iOwe.isEmpty)
    }

    @Test func groupDebtsByDirection_sumsPerCurrencyWithinDirection() {
        // Pia y Juan me deben en PEN → se suman a una sola entrada PEN.
        let debts = [
            makeDebtRow(counterparty: "Pia", amount: 47.50, currency: "PEN", perspective: .theyOweMe),
            makeDebtRow(counterparty: "Juan", amount: 20.00, currency: "PEN", perspective: .theyOweMe)
        ]
        let result = GroupsViewModel.groupDebtsByDirection(debts)
        #expect(result.owedToMe.count == 1)
        #expect(result.owedToMe.first?.currencyCode == "PEN")
        #expect(result.owedToMe.first?.amount == 67.50)
        #expect(result.iOwe.isEmpty)
    }

    @Test func groupDebtsByDirection_separatesDirectionsAcrossCurrencies() {
        // Te deben en USD, debes en PEN (monedas distintas → ambos sentidos tras netear).
        let debts = [
            makeDebtRow(counterparty: "Pia", amount: 47.50, currency: "USD", perspective: .theyOweMe),
            makeDebtRow(counterparty: "Maria", amount: 1.00, currency: "PEN", perspective: .iOwe)
        ]
        let result = GroupsViewModel.groupDebtsByDirection(debts)
        #expect(result.owedToMe.map(\.currencyCode) == ["USD"])
        #expect(result.owedToMe.first?.amount == 47.50)
        #expect(result.iOwe.map(\.currencyCode) == ["PEN"])
        #expect(result.iOwe.first?.amount == 1.00)
        #expect(!result.isEmpty)
    }

    @Test func groupDebtsByDirection_netsWithinSameCurrency() {
        // Misma moneda con ambos signos: te deben 110, debes 420 → neto "debes 310" (un solo lado),
        // igual que la banda del header. NO muestra ambos sentidos en la misma moneda.
        let debts = [
            makeDebtRow(counterparty: "Pia", amount: 110, currency: "PEN", perspective: .theyOweMe),
            makeDebtRow(counterparty: "Ana", amount: 420, currency: "PEN", perspective: .iOwe)
        ]
        let result = GroupsViewModel.groupDebtsByDirection(debts)
        #expect(result.owedToMe.isEmpty)
        #expect(result.iOwe.count == 1)
        #expect(result.iOwe.first?.currencyCode == "PEN")
        #expect(result.iOwe.first?.amount == 310)
    }

    @Test func groupDebtsByDirection_capsAndCountsOverflow() {
        // 3 monedas me deben, cap 2 → 2 mostradas + overflow 1.
        let debts = [
            makeDebtRow(amount: 47.50, currency: "PEN", perspective: .theyOweMe),
            makeDebtRow(amount: 5.30, currency: "USD", perspective: .theyOweMe),
            makeDebtRow(amount: 3.00, currency: "EUR", perspective: .theyOweMe)
        ]
        let result = GroupsViewModel.groupDebtsByDirection(debts, maxPerDirection: 2)
        #expect(result.owedToMe.count == 2)
        #expect(result.owedToMeOverflow == 1)
        #expect(result.iOweOverflow == 0)
    }

    @Test func groupDebtsByDirection_sortsByCurrencyCode() {
        // Orden alfabético por código (consistente con la banda inline).
        let debts = [
            makeDebtRow(amount: 5.30, currency: "USD", perspective: .theyOweMe),
            makeDebtRow(amount: 47.50, currency: "PEN", perspective: .theyOweMe)
        ]
        let result = GroupsViewModel.groupDebtsByDirection(debts, maxPerDirection: 5)
        #expect(result.owedToMe.map(\.currencyCode) == ["PEN", "USD"])
    }
}
