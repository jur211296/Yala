//
//  GroupExpenseSuccessBuildDataTests.swift
//  YalaTests
//
//  Cubre la construcción del payload de la pantalla de éxito de un gasto de grupo
//  (`GroupExpenseSuccessData`) — la transformación pura que hace `buildSuccessData()`
//  en `GroupExpenseFormView` (commit 4010da73): mapear el reparto (`shares` +
//  `memberNameLookup`) a `Participant`s y combinarlo con la deuda del usuario actual.
//
//  NOTA: `GroupExpenseFormView.buildSuccessData()` es `private` y vive dentro de una
//  SwiftUI View (lee `@State private var viewModel`, `group`, `memberNameLookup`), por lo
//  que NO es invocable desde tests. Estos tests ejercitan las MISMAS APIs públicas que ese
//  método compone — el init memberwise de `GroupExpenseSuccessData`/`.Participant` y
//  `GroupExpenseSuccessLogic.debt` — reproduciendo su lógica de armado (mapeo de
//  participantes con fallback de nombre y cableado de la deuda). La orquestación privada
//  (leer el VM post-save) queda fuera de cobertura por ser inaccesible.
//
//  Lógica pura: sin SwiftData/ModelContext ni singletons → no requiere .serialized.
//

import Foundation
import Testing

@testable import Yala

struct GroupExpenseSuccessBuildDataTests {

    private let me = "AAAAAAAA-0000-0000-0000-000000000001"
    private let other = "BBBBBBBB-0000-0000-0000-000000000002"
    private let third = "CCCCCCCC-0000-0000-0000-000000000003"

    /// Reproduce el mapeo de `buildSuccessData`: shares + lookup → Participants
    /// (mismo `?? "—"` de fallback), y `debt` cableado igual que en el método real.
    private func makeData(
        groupName: String = "Viaje",
        groupColorHex: String = "#112233",
        date: Date = Date(timeIntervalSince1970: 1_700_000_000),
        description: String = "Cena",
        total: Double,
        currencyCode: String = "PEN",
        shares: [(memberID: String, amount: Double)],
        nameLookup: [String: String],
        currentUserMemberID: String?,
        paidByMemberID: String,
        paidByIsMe: Bool,
        subcategoryName: String? = nil,
        accountName: String? = nil,
        accountColorHex: String? = nil,
        splitType: SplitType = .equal,
        isEditMode: Bool = false
    ) -> GroupExpenseSuccessData {
        let participants = shares.map { share in
            GroupExpenseSuccessData.Participant(
                id: share.memberID,
                name: nameLookup[share.memberID] ?? "—",
                amount: share.amount
            )
        }
        let debt = GroupExpenseSuccessLogic.debt(
            total: total,
            shares: shares,
            currentUserMemberID: currentUserMemberID,
            paidByMemberID: paidByMemberID
        )
        return GroupExpenseSuccessData(
            groupName: groupName,
            groupColorHex: groupColorHex,
            date: date,
            description: description,
            totalAmount: total,
            currencyCode: currencyCode,
            paidByName: nameLookup[paidByMemberID] ?? "—",
            paidByIsMe: paidByIsMe,
            subcategoryName: subcategoryName,
            accountName: accountName,
            accountColorHex: accountColorHex,
            splitType: splitType,
            participants: participants,
            debt: debt,
            isEditMode: isEditMode
        )
    }

    // MARK: - Monto y campos escalares

    @Test func totalAmount_isCarriedThrough() {
        let data = makeData(
            total: 100,
            shares: [(me, 50.0), (other, 50.0)],
            nameLookup: [me: "Yo", other: "Ana"],
            currentUserMemberID: me, paidByMemberID: me, paidByIsMe: true)
        #expect(data.totalAmount == 100)
    }

    @Test func scalarMetadata_isCarriedThrough() {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let data = makeData(
            groupName: "Roomies", groupColorHex: "#FF0000", date: fixedDate,
            description: "Internet", total: 60, currencyCode: "USD",
            shares: [(me, 30.0), (other, 30.0)],
            nameLookup: [me: "Yo", other: "Ana"],
            currentUserMemberID: me, paidByMemberID: me, paidByIsMe: true,
            splitType: .exact)
        #expect(data.groupName == "Roomies")
        #expect(data.groupColorHex == "#FF0000")
        #expect(data.date == fixedDate)
        #expect(data.description == "Internet")
        #expect(data.currencyCode == "USD")
        #expect(data.splitType == .exact)
    }

    // MARK: - Participantes (mapeo desde shares)

    @Test func participants_preserveShareOrderAndCount() {
        let data = makeData(
            total: 90,
            shares: [(me, 30.0), (other, 30.0), (third, 30.0)],
            nameLookup: [me: "Yo", other: "Ana", third: "Beto"],
            currentUserMemberID: me, paidByMemberID: me, paidByIsMe: true)
        #expect(data.participants.map(\.id) == [me, other, third])
    }

    @Test func participants_resolveNamesFromLookup() {
        let data = makeData(
            total: 100,
            shares: [(me, 40.0), (other, 60.0)],
            nameLookup: [me: "Yo", other: "Ana"],
            currentUserMemberID: me, paidByMemberID: me, paidByIsMe: true)
        #expect(data.participants.map(\.name) == ["Yo", "Ana"])
    }

    @Test func participants_carryTheirShareAmount() {
        let data = makeData(
            total: 100,
            shares: [(me, 40.0), (other, 60.0)],
            nameLookup: [me: "Yo", other: "Ana"],
            currentUserMemberID: me, paidByMemberID: me, paidByIsMe: true)
        #expect(data.participants.map(\.amount) == [40.0, 60.0])
    }

    @Test func participants_missingNameFallsBackToDash() {
        // Nombre no resuelto en el lookup → placeholder "—" (mismo fallback del método real).
        let data = makeData(
            total: 100,
            shares: [(me, 50.0), (other, 50.0)],
            nameLookup: [me: "Yo"],  // 'other' ausente
            currentUserMemberID: me, paidByMemberID: me, paidByIsMe: true)
        #expect(data.participants.first(where: { $0.id == other })?.name == "—")
    }

    @Test func participants_participantIdIsStableMemberID() {
        // El id del Participant es el memberID (nombres pueden repetirse; id estable).
        let data = makeData(
            total: 100,
            shares: [(me, 50.0), (other, 50.0)],
            nameLookup: [me: "Ana", other: "Ana"],  // mismo nombre, distinto id
            currentUserMemberID: me, paidByMemberID: me, paidByIsMe: true)
        #expect(Set(data.participants.map(\.id)) == [me, other])
    }

    // MARK: - Pagador

    @Test func paidByName_resolvedFromLookup() {
        let data = makeData(
            total: 100,
            shares: [(me, 50.0), (other, 50.0)],
            nameLookup: [me: "Yo", other: "Ana"],
            currentUserMemberID: me, paidByMemberID: other, paidByIsMe: false)
        #expect(data.paidByName == "Ana")
    }

    @Test func paidByName_missingFallsBackToDash() {
        let data = makeData(
            total: 100,
            shares: [(me, 50.0), (other, 50.0)],
            nameLookup: [me: "Yo"],  // pagador 'other' ausente
            currentUserMemberID: me, paidByMemberID: other, paidByIsMe: false)
        #expect(data.paidByName == "—")
    }

    @Test func paidByIsMe_flagIsCarriedThrough() {
        let data = makeData(
            total: 100,
            shares: [(me, 50.0), (other, 50.0)],
            nameLookup: [me: "Yo", other: "Ana"],
            currentUserMemberID: me, paidByMemberID: me, paidByIsMe: true)
        #expect(data.paidByIsMe == true)
    }

    // MARK: - Deuda (cableado de GroupExpenseSuccessLogic.debt)

    @Test func debt_iPaid_theyOweMeTheRest() {
        // Yo pagué, mi parte 50 de 100 → me deben 50.
        let data = makeData(
            total: 100,
            shares: [(me, 50.0), (other, 50.0)],
            nameLookup: [me: "Yo", other: "Ana"],
            currentUserMemberID: me, paidByMemberID: me, paidByIsMe: true)
        #expect(data.debt == .theyOweMe(50))
    }

    @Test func debt_otherPaid_iOweMyShare() {
        // Pagó otro, mi parte 50 → le debo 50.
        let data = makeData(
            total: 100,
            shares: [(me, 50.0), (other, 50.0)],
            nameLookup: [me: "Yo", other: "Ana"],
            currentUserMemberID: me, paidByMemberID: other, paidByIsMe: false)
        #expect(data.debt == .iOwe(50))
    }

    @Test func debt_soleParticipant_settled() {
        // Yo pagué y era el único participante → sin deuda.
        let data = makeData(
            total: 100,
            shares: [(me, 100.0)],
            nameLookup: [me: "Yo"],
            currentUserMemberID: me, paidByMemberID: me, paidByIsMe: true)
        #expect(data.debt == .settled)
    }

    // MARK: - Caso A vs no-A (cuenta personal)

    @Test func caseA_accountFieldsPopulated() {
        // Caso A (pagué yo con cuenta real) → nombre/color de cuenta presentes.
        let data = makeData(
            total: 100,
            shares: [(me, 50.0), (other, 50.0)],
            nameLookup: [me: "Yo", other: "Ana"],
            currentUserMemberID: me, paidByMemberID: me, paidByIsMe: true,
            accountName: "BCP Soles", accountColorHex: "#0055FF")
        #expect(data.accountName == "BCP Soles")
        #expect(data.accountColorHex == "#0055FF")
    }

    @Test func nonCaseA_accountFieldsAreNil() {
        // Pagó otro → sin cuenta personal (los campos quedan nil).
        let data = makeData(
            total: 100,
            shares: [(me, 50.0), (other, 50.0)],
            nameLookup: [me: "Yo", other: "Ana"],
            currentUserMemberID: me, paidByMemberID: other, paidByIsMe: false,
            accountName: nil, accountColorHex: nil)
        #expect(data.accountName == nil)
        #expect(data.accountColorHex == nil)
    }

    // MARK: - Edit mode

    @Test func isEditMode_flagIsCarriedThrough() {
        let data = makeData(
            total: 100,
            shares: [(me, 50.0), (other, 50.0)],
            nameLookup: [me: "Yo", other: "Ana"],
            currentUserMemberID: me, paidByMemberID: me, paidByIsMe: true,
            isEditMode: true)
        #expect(data.isEditMode == true)
    }
}
