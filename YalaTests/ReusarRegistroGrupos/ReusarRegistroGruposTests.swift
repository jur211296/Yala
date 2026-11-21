//
//  ReusarRegistroGruposTests.swift
//  YalaTests
//
//  «Reusar» con gastos de grupo (encargo del 21-nov): qué filas de grupo entran en «Elige un registro», cuándo salen
//  apagadas y por qué, y qué copia el pago compartido que crean (grupo, moneda, total y reparto).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Reglas puras

@Suite("Reusar con grupos · qué fila entra, cuándo se apaga y qué reparto copia")
struct ReusarRegistroGruposLogicTests {

    typealias Logic = RecurringFromRecordLogic

    private static func leg(
        expense: Bool = true, settlement: Bool = false, lineLeg: Bool = false, adjustment: Bool = false,
        linked: Bool = false, amount: Double = -120, bridgeSystem: Bool = false
    ) -> Logic.GroupLegFacts {
        Logic.GroupLegFacts(
            hasSplitExpenseID: expense, hasSplitSettlementID: settlement, isSplitLineLeg: lineLeg,
            hasBalanceAdjustmentType: adjustment, isLinkedToScheduledPayment: linked, amount: amount,
            subcategoryIsBridgeSystem: bridgeSystem)
    }

    @Test("entra la fila con el gasto: la pata real o tu parte, negativa y sin subcategoría de sistema")
    func entraElGasto() {
        #expect(Logic.isReusableGroupExpense(Self.leg()))
        #expect(Logic.isReusableGroupExpense(Self.leg(amount: -100)))
    }

    @Test("fuera: préstamo a grupos, liquidaciones, patas de líneas, ventas, ya enlazadas, lo que no es de grupo")
    func fuera() {
        #expect(!Logic.isReusableGroupExpense(Self.leg(amount: 60, bridgeSystem: true)), "pata de préstamo")
        #expect(!Logic.isReusableGroupExpense(Self.leg(bridgeSystem: true)), "subcategoría de sistema")
        #expect(!Logic.isReusableGroupExpense(Self.leg(amount: 60)), "positivo")
        #expect(!Logic.isReusableGroupExpense(Self.leg(settlement: true)), "liquidación")
        #expect(!Logic.isReusableGroupExpense(Self.leg(lineLeg: true)), "pata derivada")
        #expect(!Logic.isReusableGroupExpense(Self.leg(adjustment: true)), "venta (por cobrar)")
        #expect(!Logic.isReusableGroupExpense(Self.leg(linked: true)), "ya es de un recurrente")
        #expect(!Logic.isReusableGroupExpense(Self.leg(expense: false)), "no viene de un grupo")
    }

    @Test("disponibilidad: sin grupo u oculto, archivado, sin ser miembro activo, y disponible")
    func disponibilidad() {
        #expect(Logic.groupAvailability(groupExists: false, isHiddenForAll: false, isArchived: false,
                                        currentMemberIsActive: true) == .groupGone)
        #expect(Logic.groupAvailability(groupExists: true, isHiddenForAll: true, isArchived: false,
                                        currentMemberIsActive: true) == .groupGone)
        #expect(Logic.groupAvailability(groupExists: true, isHiddenForAll: false, isArchived: true,
                                        currentMemberIsActive: true) == .archived)
        #expect(Logic.groupAvailability(groupExists: true, isHiddenForAll: false, isArchived: false,
                                        currentMemberIsActive: false) == .notMember)
        #expect(Logic.groupAvailability(groupExists: true, isHiddenForAll: false, isArchived: false,
                                        currentMemberIsActive: true) == .available)
    }

    private let yo = UUID()
    private let pia = UUID()
    private let leo = UUID()

    @Test("a partes iguales: participan quienes tenían parte, sin valores")
    func iguales() throws {
        let split = try #require(Logic.groupSplit(
            splitType: "equal", total: 120, shares: [(yo, 60), (pia, 60)], activeMemberIDs: [yo, pia]))
        #expect(split == Logic.GroupSplit(splitType: .equal, participantIDs: [yo, pia], values: [:]))
    }

    @Test("exacto: los montos de cada uno; quien tenía 0 no participa")
    func exacto() throws {
        let split = try #require(Logic.groupSplit(
            splitType: "exact", total: 300, shares: [(yo, 100), (pia, 200), (leo, 0)],
            activeMemberIDs: [yo, pia, leo]))
        #expect(split.splitType == .exact)
        #expect(split.participantIDs == [yo, pia])
        #expect(split.values == [yo: 100, pia: 200])
    }

    @Test("porcentaje: la parte de cada uno sobre el total, a dos decimales")
    func porcentaje() throws {
        let split = try #require(Logic.groupSplit(
            splitType: "percentage", total: 90, shares: [(yo, 30), (pia, 60)], activeMemberIDs: [yo, pia]))
        #expect(split.splitType == .percentage)
        #expect(split.values == [yo: 33.33, pia: 66.67])
    }

    @Test("partes: la proporción entera; si no cuadra, exacto")
    func partes() throws {
        let entera = try #require(Logic.groupSplit(
            splitType: "shares", total: 90, shares: [(yo, 30), (pia, 60)], activeMemberIDs: [yo, pia]))
        #expect(entera == Logic.GroupSplit(splitType: .shares, participantIDs: [yo, pia], values: [yo: 1, pia: 2]))
        let rara = try #require(Logic.groupSplit(
            splitType: "shares", total: 100, shares: [(yo, 30), (pia, 70)], activeMemberIDs: [yo, pia]))
        #expect(rara.splitType == .exact)
        #expect(rara.values == [yo: 30, pia: 70])
    }

    @Test("si alguien ya no está y no era a partes iguales, pasa a partes iguales entre los que quedan")
    func alguienSalio() throws {
        let split = try #require(Logic.groupSplit(
            splitType: "exact", total: 300, shares: [(yo, 100), (pia, 100), (leo, 100)], activeMemberIDs: [yo, pia]))
        #expect(split == Logic.GroupSplit(splitType: .equal, participantIDs: [yo, pia], values: [:]))
        // A partes iguales se queda igual, sin el que salió.
        let iguales = try #require(Logic.groupSplit(
            splitType: "equal", total: 300, shares: [(yo, 100), (pia, 100), (leo, 100)], activeMemberIDs: [yo, pia]))
        #expect(iguales.participantIDs == [yo, pia])
    }

    @Test("sin nadie con parte que siga activo, no hay reparto")
    func nadie() {
        #expect(Logic.groupSplit(splitType: "equal", total: 60, shares: [(leo, 60)], activeMemberIDs: [yo]) == nil)
        #expect(Logic.groupSplit(splitType: "equal", total: 60, shares: [], activeMemberIDs: [yo]) == nil)
    }
}

// MARK: - Sobre datos

@Suite("Reusar con grupos · lista, disponibilidad y prellenado sobre el almacén", .serialized)
@MainActor
struct ReusarRegistroGruposServiceTests {

    private struct Escena {
        let context: ModelContext
        let group: SplitGroup
        let me: SplitMember
        let pia: SplitMember
        let account: Account
        let realLeg: TransactionItem
        let loanLeg: TransactionItem
        let otherPaidLeg: TransactionItem
        let personal: TransactionItem
    }

    /// «Jurpi» (yo y Pía): «Luz» 120 que pagué yo a partes iguales (pata real + préstamo), «Mantenimiento» 300 que pagó
    /// Pía, exacto (yo 100), y un gasto personal.
    private func montar() throws -> Escena {
        let context = try makeTestContext()
        let group = SplitGroup(name: "Jurpi", currencyCode: "PEN")
        context.insert(group)
        let zone = group.cloudKitZoneID
        let me = SplitMember(groupZoneID: zone, displayName: "Yo", status: .active, isCurrentUser: true)
        let pia = SplitMember(groupZoneID: zone, displayName: "Pía", status: .active)
        context.insert(me); context.insert(pia)
        let account = makeTestAccount(context: context, name: "BCP", currencyCode: "PEN")
        let system = Account(name: "Grupos", currencyCode: "PEN", colorHex: "#000000", iconName: "person.2",
                             type: "cash")
        system.isSystemAccount = true
        context.insert(system)
        let category = makeTestCategory(context: context, name: "Hogar")
        let utilities = makeTestSubcategory(context: context, name: "Luz y agua", category: category)
        let loan = makeTestSubcategory(context: context, name: "Préstamo a grupos", category: category)
        loan.isSystem = true

        let luz = SplitExpense(groupZoneID: zone, amount: 120, currencyCode: "PEN", expenseDescription: "Luz",
                               paidByMemberID: me.id.uuidString, splitType: "equal")
        context.insert(luz)
        context.insert(SplitShare(expenseID: luz.id, memberID: me.id.uuidString, amount: 60, groupZoneID: zone))
        context.insert(SplitShare(expenseID: luz.id, memberID: pia.id.uuidString, amount: 60, groupZoneID: zone))
        let mant = SplitExpense(groupZoneID: zone, amount: 300, currencyCode: "PEN", expenseDescription: "Mantenimiento",
                                paidByMemberID: pia.id.uuidString, splitType: "exact")
        context.insert(mant)
        context.insert(SplitShare(expenseID: mant.id, memberID: me.id.uuidString, amount: 100, groupZoneID: zone))
        context.insert(SplitShare(expenseID: mant.id, memberID: pia.id.uuidString, amount: 200, groupZoneID: zone))

        func leg(_ amount: Double, _ expense: SplitExpense, _ sub: Subcategory?, _ acc: Account, _ hour: Int)
            -> TransactionItem {
            let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
            let tx = TransactionItem(date: date, amount: amount, currencyCode: "PEN", note: expense.expenseDescription,
                                     category: sub?.category, subcategory: sub, account: acc)
            tx.splitExpenseID = expense.id.uuidString
            tx.splitGroupZoneID = zone
            tx.splitTotalAmount = expense.amount
            tx.splitType = expense.splitType
            context.insert(tx)
            return tx
        }
        let realLeg = leg(-120, luz, utilities, account, 12)
        let loanLeg = leg(60, luz, loan, system, 11)
        let otherPaidLeg = leg(-100, mant, utilities, system, 10)
        let personal = TransactionItem(date: .now, amount: -30, currencyCode: "PEN", note: "Café",
                                       category: category, subcategory: utilities, account: account)
        context.insert(personal)
        try context.save()
        return Escena(context: context, group: group, me: me, pia: pia, account: account, realLeg: realLeg,
                      loanLeg: loanLeg, otherPaidLeg: otherPaidLeg, personal: personal)
    }

    @Test("la lista trae lo personal y un gasto por grupo, sin la pata de préstamo")
    func lista() throws {
        let e = try montar()
        let reusables = RecurringFromRecordService.reusableRecords([e.realLeg, e.loanLeg, e.otherPaidLeg, e.personal])
        #expect(reusables.map(\.note) == ["Luz", "Mantenimiento", "Café"])
        // Antes del 21-nov solo salía lo personal: el control de que el selector viejo no las trae.
        #expect([e.realLeg, e.otherPaidLeg].allSatisfy { !RecurringFromRecordService.offersMakeRecurring($0) })
    }

    @Test("una sola fila por gasto aunque lleguen dos patas negativas del mismo")
    func unaPorGasto() throws {
        let e = try montar()
        let gemela = TransactionItem(date: .now, amount: -60, currencyCode: "PEN", note: "Luz", account: e.account)
        gemela.splitExpenseID = e.realLeg.splitExpenseID
        gemela.splitGroupZoneID = e.realLeg.splitGroupZoneID
        e.context.insert(gemela)
        #expect(RecurringFromRecordService.reusableRecords([e.realLeg, gemela]).count == 1)
    }

    @Test("disponible, archivado, sin ser miembro activo y grupo que no está")
    func disponibilidad() throws {
        let e = try montar()
        let zone = e.group.cloudKitZoneID
        #expect(RecurringFromRecordService.groupAvailability(zone: zone, in: e.context) == .available)
        e.group.isArchived = true
        #expect(RecurringFromRecordService.groupAvailability(zone: zone, in: e.context) == .archived)
        e.group.isArchived = false
        e.me.status = SplitMemberStatus.left.rawValue
        #expect(RecurringFromRecordService.groupAvailability(zone: zone, in: e.context) == .notMember)
        #expect(RecurringFromRecordService.groupAvailability(zone: "otra-zona", in: e.context) == .groupGone)
        #expect(RecurringFromRecordService.groupAvailability(zone: "", in: e.context) == .groupGone)
    }

    @Test("pagaste tú: nace compartido con el grupo, el total, la moneda y el reparto a partes iguales")
    func pagasteTu() throws {
        let e = try montar()
        let prefill = RecurringFromRecordService.prefill(from: e.realLeg)
        let group = try #require(prefill.group)
        #expect(group.groupZoneID == e.group.cloudKitZoneID)
        #expect(group.currencyCode == "PEN")
        #expect(group.totalAmount == 120)
        #expect(group.splitType == .equal)
        #expect(Set(group.participantIDs) == [e.me.id, e.pia.id])
        #expect(prefill.amount == AmountInputHelper.formatWithGrouping(120))
        #expect(prefill.name == "Luz")
        #expect(prefill.subcategory?.name == "Luz y agua")
        #expect(prefill.account?.name == "BCP")
        #expect(prefill.tagIDs.isEmpty)
        #expect(prefill.transactionType == TransactionType.expense.rawValue)
    }

    @Test("pagó otro: el total del gasto (no tu parte), su reparto exacto y sin la cuenta de sistema")
    func pagoOtro() throws {
        let e = try montar()
        let prefill = RecurringFromRecordService.prefill(from: e.otherPaidLeg)
        let group = try #require(prefill.group)
        #expect(group.totalAmount == 300)
        #expect(group.splitType == .exact)
        #expect(group.values == [e.me.id: 100, e.pia.id: 200])
        #expect(prefill.amount == AmountInputHelper.formatWithGrouping(300))
        #expect(prefill.account == nil, "La cuenta de sistema «Grupos» no se puede elegir en el formulario.")
    }

    @Test("lo personal sigue como siempre: sin grupo y con su monto")
    func personalSigueIgual() throws {
        let e = try montar()
        let prefill = RecurringFromRecordService.prefill(from: e.personal)
        #expect(prefill.group == nil)
        #expect(prefill.amount == AmountInputHelper.formatWithGrouping(30))
    }

    @Test("el gasto ya no está en el teléfono: sin prellenado de grupo")
    func gastoBorrado() throws {
        let e = try montar()
        e.realLeg.splitExpenseID = UUID().uuidString
        #expect(RecurringFromRecordService.groupPrefill(from: e.realLeg, in: e.context) == nil)
    }
}
