//
//  GroupsExportBuilderTests.swift
//  YalaTests
//
//  G5-D2: export ampliado con grupos. Fija la generación PURA del CSV de grupos a partir de bundles
//  conocidos (gastos/shares/settlements/members) — incluye member anonimizado (sentinel de cuenta
//  eliminada) y balance multi-moneda. `@Model` directos, sin contexto (más rápido y sin acoplamiento).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct GroupsExportBuilderTests {

    // MARK: - Helpers

    private func makeGroup(name: String, zoneID: String) -> SplitGroup {
        let g = SplitGroup(name: name)
        g.cloudKitZoneID = zoneID
        return g
    }

    private func makeMember(
        id: UUID,
        zoneID: String,
        displayName: String,
        isCurrentUser: Bool = false,
        status: SplitMemberStatus = .active
    ) -> SplitMember {
        let m = SplitMember(
            groupZoneID: zoneID,
            displayName: displayName,
            status: status,
            isCurrentUser: isCurrentUser
        )
        m.id = id
        return m
    }

    private func makeExpense(
        id: UUID = UUID(),
        zoneID: String,
        amount: Double,
        currencyCode: String = "PEN",
        description: String = "Cena",
        date: Date,
        paidBy: UUID
    ) -> SplitExpense {
        let e = SplitExpense(
            groupZoneID: zoneID,
            amount: amount,
            currencyCode: currencyCode,
            expenseDescription: description,
            date: date,
            paidByMemberID: paidBy.uuidString
        )
        e.id = id
        return e
    }

    private func makeShare(expenseID: UUID, zoneID: String, memberID: UUID, amount: Double) -> SplitShare {
        SplitShare(expenseID: expenseID, memberID: memberID.uuidString, amount: amount, groupZoneID: zoneID)
    }

    private func makeSettlement(
        zoneID: String,
        from: UUID,
        to: UUID,
        amount: Double,
        currencyCode: String = "PEN",
        date: Date,
        confirmed: Bool = true
    ) -> SplitSettlement {
        let s = SplitSettlement(
            groupZoneID: zoneID,
            fromMemberID: from.uuidString,
            toMemberID: to.uuidString,
            amount: amount,
            currencyCode: currencyCode,
            date: date
        )
        s.isConfirmed = confirmed
        return s
    }

    private func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private func lines(_ data: Data?) -> [String] {
        guard let data else { return [] }
        let body = data.count >= 3 ? data.dropFirst(3) : data  // strip BOM
        let str = String(data: body, encoding: .utf8) ?? ""
        return str.components(separatedBy: "\n")
    }

    // MARK: - Empty

    @Test func emptyBundles_returnsNil() {
        #expect(GroupsExportBuilder.makeGroupsCSVData(bundles: []) == nil)
    }

    // MARK: - Header row

    @Test func header_hasTenLocalizedColumns() {
        let zone = "z1"
        let me = makeMember(id: UUID(), zoneID: zone, displayName: "Ana", isCurrentUser: true)
        let bundle = GroupExportBundle(
            group: makeGroup(name: "Viaje", zoneID: zone),
            members: [me], expenses: [], shares: [], settlements: []
        )
        let out = lines(GroupsExportBuilder.makeGroupsCSVData(bundles: [bundle]))
        let header = out.first ?? ""
        let cols = header.components(separatedBy: ",")
        #expect(cols.count == 10)
        #expect(cols[0] == L10n.Export.Groups.headerGroup)
        #expect(cols[1] == L10n.Export.Groups.headerType)
        #expect(cols[6] == L10n.Export.Groups.headerPaidBy)
        #expect(cols[7] == L10n.Export.Groups.headerAmount)
        #expect(cols[8] == L10n.Export.Groups.headerMyShare)
        #expect(cols[9] == L10n.Export.Groups.headerCurrency)
    }

    // MARK: - Expense row + my share + my balance

    @Test func expense_currentUser_rowAndBalance() {
        let zone = "z1"
        let anaID = UUID()
        let betoID = UUID()
        let ana = makeMember(id: anaID, zoneID: zone, displayName: "Ana", isCurrentUser: true)
        let beto = makeMember(id: betoID, zoneID: zone, displayName: "Beto")

        let expID = UUID()
        // Ana paga 100, split 50/50.
        let exp = makeExpense(id: expID, zoneID: zone, amount: 100, description: "Cena", date: makeDate(2025, 6, 1), paidBy: anaID)
        let shareA = makeShare(expenseID: expID, zoneID: zone, memberID: anaID, amount: 50)
        let shareB = makeShare(expenseID: expID, zoneID: zone, memberID: betoID, amount: 50)

        let bundle = GroupExportBundle(
            group: makeGroup(name: "Viaje", zoneID: zone),
            members: [ana, beto], expenses: [exp], shares: [shareA, shareB], settlements: []
        )
        let out = lines(GroupsExportBuilder.makeGroupsCSVData(bundles: [bundle]))

        // línea 1: header, línea 2: gasto, línea 3: mi balance
        #expect(out.count == 3)

        let expenseCols = out[1].components(separatedBy: ",")
        #expect(expenseCols[0] == "Viaje")
        #expect(expenseCols[1] == L10n.Export.Groups.typeExpense)
        #expect(expenseCols[2] == "2025-06-01")
        #expect(expenseCols[3] == "Cena")
        #expect(expenseCols[4] == "")               // from
        #expect(expenseCols[5] == "")               // to
        #expect(expenseCols[6] == "Ana")            // paidBy
        #expect(expenseCols[7] == "100.00")         // amount (total)
        #expect(expenseCols[8] == "50.00")          // my share
        #expect(expenseCols[9] == "PEN")

        // Ana: pagó 100, debe 50 → neto +50.
        let balCols = out[2].components(separatedBy: ",")
        #expect(balCols[1] == L10n.Export.Groups.typeBalance)
        #expect(balCols[7] == "50.00")              // amount = neto
        #expect(balCols[9] == "PEN")
    }

    // MARK: - Anonymized member (sentinel)

    @Test func anonymizedPayer_mapsToDeletedUserLabel() {
        let zone = "z1"
        let ghostID = UUID()
        let meID = UUID()
        let ghost = makeMember(id: ghostID, zoneID: zone, displayName: SplitMember.deletedUserSentinel, status: .removed)
        let me = makeMember(id: meID, zoneID: zone, displayName: "Ana", isCurrentUser: true)

        let expID = UUID()
        let exp = makeExpense(id: expID, zoneID: zone, amount: 20, description: "Taxi", date: makeDate(2025, 6, 2), paidBy: ghostID)
        let shareMe = makeShare(expenseID: expID, zoneID: zone, memberID: meID, amount: 20)

        let bundle = GroupExportBundle(
            group: makeGroup(name: "Viaje", zoneID: zone),
            members: [ghost, me], expenses: [exp], shares: [shareMe], settlements: []
        )
        let out = lines(GroupsExportBuilder.makeGroupsCSVData(bundles: [bundle]))
        let expenseCols = out[1].components(separatedBy: ",")
        #expect(expenseCols[6] == L10n.Groups.Member.deletedUser)
        #expect(expenseCols[6] != SplitMember.deletedUserSentinel)
    }

    // MARK: - Settlement row

    @Test func settlement_fromToResolved() {
        let zone = "z1"
        let anaID = UUID()
        let betoID = UUID()
        let ana = makeMember(id: anaID, zoneID: zone, displayName: "Ana", isCurrentUser: true)
        let beto = makeMember(id: betoID, zoneID: zone, displayName: "Beto")

        // Beto le paga 30 a Ana.
        let settlement = makeSettlement(zoneID: zone, from: betoID, to: anaID, amount: 30, date: makeDate(2025, 6, 3))

        let bundle = GroupExportBundle(
            group: makeGroup(name: "Viaje", zoneID: zone),
            members: [ana, beto], expenses: [], shares: [], settlements: [settlement]
        )
        let out = lines(GroupsExportBuilder.makeGroupsCSVData(bundles: [bundle]))
        // header + settlement (sin gastos → sin balance rows porque no hay actividad de Ana)
        let settlementRow = out.first(where: { $0.components(separatedBy: ",")[1] == L10n.Export.Groups.typeSettlement })
        let cols = (settlementRow ?? "").components(separatedBy: ",")
        #expect(cols[1] == L10n.Export.Groups.typeSettlement)
        #expect(cols[2] == "2025-06-03")
        #expect(cols[4] == "Beto")     // from
        #expect(cols[5] == "Ana")      // to
        #expect(cols[7] == "30.00")    // amount
        #expect(cols[9] == "PEN")
    }

    // MARK: - Multi-currency balance

    @Test func multiCurrency_oneBalanceRowPerCurrency_sorted() {
        let zone = "z1"
        let anaID = UUID()
        let betoID = UUID()
        let ana = makeMember(id: anaID, zoneID: zone, displayName: "Ana", isCurrentUser: true)
        let beto = makeMember(id: betoID, zoneID: zone, displayName: "Beto")

        // PEN: Ana paga 100, split 50/50 → Ana neto +50.
        let penID = UUID()
        let penExp = makeExpense(id: penID, zoneID: zone, amount: 100, currencyCode: "PEN", date: makeDate(2025, 6, 1), paidBy: anaID)
        let penA = makeShare(expenseID: penID, zoneID: zone, memberID: anaID, amount: 50)
        let penB = makeShare(expenseID: penID, zoneID: zone, memberID: betoID, amount: 50)

        // USD: Ana paga 40, shares Ana 10 / Beto 30 → Ana neto +30.
        let usdID = UUID()
        let usdExp = makeExpense(id: usdID, zoneID: zone, amount: 40, currencyCode: "USD", date: makeDate(2025, 6, 2), paidBy: anaID)
        let usdA = makeShare(expenseID: usdID, zoneID: zone, memberID: anaID, amount: 10)
        let usdB = makeShare(expenseID: usdID, zoneID: zone, memberID: betoID, amount: 30)

        let bundle = GroupExportBundle(
            group: makeGroup(name: "Viaje", zoneID: zone),
            members: [ana, beto],
            expenses: [penExp, usdExp],
            shares: [penA, penB, usdA, usdB],
            settlements: []
        )
        let out = lines(GroupsExportBuilder.makeGroupsCSVData(bundles: [bundle]))

        let balanceRows = out.filter { $0.components(separatedBy: ",")[1] == L10n.Export.Groups.typeBalance }
        #expect(balanceRows.count == 2)
        // Ordenadas por moneda: PEN antes que USD.
        let penCols = balanceRows[0].components(separatedBy: ",")
        let usdCols = balanceRows[1].components(separatedBy: ",")
        #expect(penCols[9] == "PEN")
        #expect(penCols[7] == "50.00")
        #expect(usdCols[9] == "USD")
        #expect(usdCols[7] == "30.00")
    }

    // MARK: - Not a current-user member

    @Test func noCurrentUser_myShareEmpty_noBalanceRows() {
        let zone = "z1"
        let anaID = UUID()
        let betoID = UUID()
        // Nadie es current user (invitado que aún no materializó su member, o solo-lectura).
        let ana = makeMember(id: anaID, zoneID: zone, displayName: "Ana")
        let beto = makeMember(id: betoID, zoneID: zone, displayName: "Beto")

        let expID = UUID()
        let exp = makeExpense(id: expID, zoneID: zone, amount: 100, date: makeDate(2025, 6, 1), paidBy: anaID)
        let shareA = makeShare(expenseID: expID, zoneID: zone, memberID: anaID, amount: 50)
        let shareB = makeShare(expenseID: expID, zoneID: zone, memberID: betoID, amount: 50)

        let bundle = GroupExportBundle(
            group: makeGroup(name: "Viaje", zoneID: zone),
            members: [ana, beto], expenses: [exp], shares: [shareA, shareB], settlements: []
        )
        let out = lines(GroupsExportBuilder.makeGroupsCSVData(bundles: [bundle]))

        // Sin current user: header + gasto, sin fila de balance.
        #expect(out.count == 2)
        let expenseCols = out[1].components(separatedBy: ",")
        #expect(expenseCols[8] == "")   // my share vacío
        let hasBalance = out.contains { $0.components(separatedBy: ",")[1] == L10n.Export.Groups.typeBalance }
        #expect(!hasBalance)
    }

    // MARK: - Inactive current-user (pending) → treated as non-participant for "mine"

    @Test func pendingCurrentUser_treatedAsNonParticipant() {
        let zone = "z1"
        let anaID = UUID()
        // Soy current user pero PENDING (no active) → "mis members" queda vacío.
        let ana = makeMember(id: anaID, zoneID: zone, displayName: "Ana", isCurrentUser: true, status: .pendingApproval)

        let expID = UUID()
        let exp = makeExpense(id: expID, zoneID: zone, amount: 100, date: makeDate(2025, 6, 1), paidBy: anaID)
        let shareA = makeShare(expenseID: expID, zoneID: zone, memberID: anaID, amount: 100)

        let bundle = GroupExportBundle(
            group: makeGroup(name: "Viaje", zoneID: zone),
            members: [ana], expenses: [exp], shares: [shareA], settlements: []
        )
        let out = lines(GroupsExportBuilder.makeGroupsCSVData(bundles: [bundle]))
        #expect(out.count == 2)   // header + gasto, sin balance
        let expenseCols = out[1].components(separatedBy: ",")
        #expect(expenseCols[8] == "")   // my share vacío (no soy member activo)
    }
}

// MARK: - Context-based (gate + fetch + invariante del export personal)

/// Usa `makeTestContext` (container in-memory reusado por archivo) → `@Suite(.serialized)`
/// obligatorio por la regla de reuso de containers (TESTING-STRATEGY.md).
@MainActor
@Suite(.serialized)
struct GroupsExportBuilderContextTests {

    @Test func hasExportableGroups_falseWhenEmpty_trueWithActiveGroup() throws {
        let ctx = try makeTestContext()
        #expect(GroupsExportBuilder.hasExportableGroups(in: ctx) == false)

        let group = SplitGroup(name: "Viaje")
        ctx.insert(group)
        try ctx.save()
        #expect(GroupsExportBuilder.hasExportableGroups(in: ctx) == true)

        // Un grupo archivado NO cuenta.
        group.isArchived = true
        try ctx.save()
        #expect(GroupsExportBuilder.hasExportableGroups(in: ctx) == false)
    }

    @Test func makeGroupsCSVData_fromContext_includesGroupRows() throws {
        let ctx = try makeTestContext()
        let group = SplitGroup(name: "Viaje")
        let zone = group.cloudKitZoneID
        ctx.insert(group)

        let me = SplitMember(groupZoneID: zone, displayName: "Ana", status: .active, isCurrentUser: true)
        ctx.insert(me)

        let exp = SplitExpense(
            groupZoneID: zone, amount: 100, currencyCode: "PEN",
            expenseDescription: "Cena", date: Date.now, paidByMemberID: me.id.uuidString
        )
        ctx.insert(exp)
        ctx.insert(SplitShare(expenseID: exp.id, memberID: me.id.uuidString, amount: 100, groupZoneID: zone))
        try ctx.save()

        let data = GroupsExportBuilder.makeGroupsCSVData(in: ctx)
        #expect(data != nil)
        let str = String(data: (data ?? Data()).dropFirst(3), encoding: .utf8) ?? ""
        #expect(str.contains("Viaje"))
        #expect(str.contains(L10n.Export.Groups.typeExpense))
        #expect(str.contains(L10n.Export.Groups.typeBalance))
    }

    /// Invariante G5-D2: el export PERSONAL es byte-idéntico exista o no un grupo — la presencia de
    /// grupos jamás altera el archivo personal (el CSV de grupos es SEPARADO). Equivale al wizard con
    /// el toggle OFF: solo se comparte el archivo personal, sin cambios.
    @Test func personalExport_byteIdentical_regardlessOfGroups() throws {
        let ctx = try makeTestContext()

        // Corpus personal mínimo dentro del rango por defecto (last30Days).
        let tx = TransactionItem(date: Date.now, amount: -12.5, currencyCode: "USD")
        ctx.insert(tx)
        try ctx.save()

        let filters = ExportFilters.default
        let columns = ExportColumns.default

        let before = try TransactionsExportService.export(
            format: .csv, using: filters, columns: columns, in: ctx)
        let bytesBefore = try Data(contentsOf: before.fileURL)

        // Añadir un grupo con datos NO debe cambiar el export personal.
        let group = SplitGroup(name: "Viaje")
        let zone = group.cloudKitZoneID
        ctx.insert(group)
        let me = SplitMember(groupZoneID: zone, displayName: "Ana", status: .active, isCurrentUser: true)
        ctx.insert(me)
        let exp = SplitExpense(
            groupZoneID: zone, amount: 100, currencyCode: "PEN",
            expenseDescription: "Cena", date: Date.now, paidByMemberID: me.id.uuidString)
        ctx.insert(exp)
        ctx.insert(SplitShare(expenseID: exp.id, memberID: me.id.uuidString, amount: 100, groupZoneID: zone))
        try ctx.save()

        let after = try TransactionsExportService.export(
            format: .csv, using: filters, columns: columns, in: ctx)
        let bytesAfter = try Data(contentsOf: after.fileURL)

        #expect(bytesBefore == bytesAfter)
    }
}
