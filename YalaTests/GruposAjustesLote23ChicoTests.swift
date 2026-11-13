//
//  GruposAjustesLote23ChicoTests.swift
//  YalaTests
//
//  Lote chico de 2.3, Grupos (decisión 36 y la card de «Debes S/ 0.00» junto a «Le debes a Ana»):
//
//  1 · la cabecera de la lista suma cada grupo con SUS opciones, igual que su tarjeta. Con el código de antes juntaba las
//      deudas de todos los grupos y las simplificaba siempre: con «Menos pagos» apagado decía «Debes S/ 10» y «Te deben 0»
//      mientras la tarjeta decía «Le debes a Ana S/ 40 · Beto te debe S/ 30»;
//  2 · un grupo nuevo nace con «Menos pagos» encendido (el modelo sigue en `false` para lo que ya existe);
//  3 · la línea al pie de Saldos sale solo cuando juntar cambia algo en un grupo de 3 o más.
//
//  Datos de «Piso compartido» (la semilla `-uitest-seed-group-cross-debts`): Ana pagó una cena de 120 a tres, tú un taxi
//  de 80 con Beto, y Beto ya te pagó 10. De cada par: tú → Ana 40, Beto → Ana 40, Beto → tú 30. Juntadas: Beto → Ana 70,
//  tú → Ana 10.
//

import Foundation
import Testing
@testable import Yala

@MainActor
struct GruposAjustesLote23ChicoTests {

    // MARK: - Fixture

    @MainActor
    private struct Piso {
        let me: SplitMember
        let ana: SplitMember
        let beto: SplitMember
        let expenses: [SplitExpense]
        let shares: [SplitShare]
        let settlements: [SplitSettlement]

        var members: [SplitMember] { [me, ana, beto] }

        func source(simplify: Bool) -> GroupBalanceService.GroupSummarySource {
            .init(expenses: expenses, shares: shares, settlements: settlements, simplifyDebts: simplify,
                  singleCurrency: nil)
        }
    }

    private func piso(zone: String = "piso", currency: String = "PEN") -> Piso {
        let me = SplitMember(groupZoneID: zone, displayName: "Lucía", isCurrentUser: true)
        let ana = SplitMember(groupZoneID: zone, displayName: "Ana")
        let beto = SplitMember(groupZoneID: zone, displayName: "Beto")
        let cena = SplitExpense(groupZoneID: zone, amount: 120, currencyCode: currency, expenseDescription: "Cena",
                                paidByMemberID: ana.id.uuidString)
        let taxi = SplitExpense(groupZoneID: zone, amount: 80, currencyCode: currency, expenseDescription: "Taxi",
                                paidByMemberID: me.id.uuidString)
        var shares = [me, ana, beto].map {
            SplitShare(expenseID: cena.id, memberID: $0.id.uuidString, amount: 40)
        }
        shares += [me, beto].map { SplitShare(expenseID: taxi.id, memberID: $0.id.uuidString, amount: 40) }
        let pago = SplitSettlement(groupZoneID: zone, fromMemberID: beto.id.uuidString, toMemberID: me.id.uuidString,
                                   amount: 10, currencyCode: currency)
        pago.isConfirmed = true
        return Piso(me: me, ana: ana, beto: beto, expenses: [cena, taxi], shares: shares, settlements: [pago])
    }

    /// Lo que suma la tarjeta del grupo, por sentido y divisa (`GroupsViewModel.computeCurrentUserDebts`).
    private func cardTotals(_ piso: Piso, simplify: Bool) -> (iOwe: [String: Double], owedToMe: [String: Double]) {
        let rows = GroupsViewModel.computeCurrentUserDebts(
            members: piso.members, expenses: piso.expenses, shares: piso.shares, settlements: piso.settlements,
            simplifyDebts: simplify)
        var iOwe: [String: Double] = [:]
        var owed: [String: Double] = [:]
        for row in rows {
            switch row.perspective {
            case .iOwe: iOwe[row.currencyCode, default: 0] += row.amount
            case .theyOweMe: owed[row.currencyCode, default: 0] += row.amount
            }
        }
        return (iOwe, owed)
    }

    // MARK: - 1 · Cabecera de la lista = suma de las tarjetas

    @Test func header_withMenosPagosOff_sumsEachPairLikeTheCard() {
        let piso = piso()
        let summary = GroupBalanceService.globalSummary(
            groups: [piso.source(simplify: false)], currentUserMemberIDs: [piso.me.id.uuidString])

        // La tarjeta dice «Le debes a Ana S/ 40 · Beto te debe S/ 30». El código de antes daba 10 y nada.
        #expect(summary.totalIOwe["PEN"] == 40)
        #expect(summary.totalOwedToMe["PEN"] == 30)
        let card = cardTotals(piso, simplify: false)
        #expect(summary.totalIOwe == card.iOwe)
        #expect(summary.totalOwedToMe == card.owedToMe)
    }

    @Test func header_withMenosPagosOn_sumsTheSimplifiedDebts() {
        let piso = piso()
        let summary = GroupBalanceService.globalSummary(
            groups: [piso.source(simplify: true)], currentUserMemberIDs: [piso.me.id.uuidString])

        #expect(summary.totalIOwe["PEN"] == 10)
        #expect(summary.totalOwedToMe["PEN"] == nil)
        let card = cardTotals(piso, simplify: true)
        #expect(summary.totalIOwe == card.iOwe)
        #expect(summary.totalOwedToMe == card.owedToMe)
    }

    /// Dos grupos, uno con cada opción: cada uno suma lo suyo. Juntos y simplificados, el de «Menos pagos» apagado
    /// perdía la cifra de cada par.
    @Test func header_twoGroups_eachWithItsOwnOption() {
        let off = piso(zone: "off")
        let on = piso(zone: "on")
        let summary = GroupBalanceService.globalSummary(
            groups: [off.source(simplify: false), on.source(simplify: true)],
            currentUserMemberIDs: [off.me.id.uuidString, on.me.id.uuidString])

        #expect(summary.totalIOwe["PEN"] == 50)
        #expect(summary.totalOwedToMe["PEN"] == 30)
    }

    /// Con «una sola moneda», la cabecera suma en la divisa del grupo, como la tarjeta (antes, en la de cada gasto).
    @Test func header_singleCurrencyGroup_sumsInTheGroupCurrency() {
        let usd = piso(zone: "usd", currency: "USD")
        let source = GroupBalanceService.GroupSummarySource(
            expenses: usd.expenses, shares: usd.shares, settlements: usd.settlements, simplifyDebts: false,
            singleCurrency: "PEN")
        let summary = GroupBalanceService.globalSummary(
            groups: [source], currentUserMemberIDs: [usd.me.id.uuidString], converter: TimesThree())

        #expect(summary.totalIOwe == ["PEN": 120])
        #expect(summary.totalOwedToMe == ["PEN": 90])
    }

    /// Pagos por confirmar: los de todos los grupos.
    @Test func header_pendingSettlements_countAcrossGroups() {
        let a = piso(zone: "a")
        let b = piso(zone: "b")
        b.settlements.forEach { $0.isConfirmed = false }
        let summary = GroupBalanceService.globalSummary(
            groups: [a.source(simplify: false), b.source(simplify: false)],
            currentUserMemberIDs: [a.me.id.uuidString, b.me.id.uuidString])
        #expect(summary.pendingSettlements == 1)
    }

    // MARK: - 2 · Grupo nuevo con «Menos pagos» encendido

    @Test func newGroup_startsWithMenosPagosOn_existingModelDefaultStaysOff() {
        #expect(GroupFormDefaults.simplifyDebtsForNewGroup)
        // Lo que ya existe (y lo que baja del servidor sin el campo) no cambia: el modelo sigue naciendo apagado.
        #expect(SplitGroup().simplifyDebts == false)
    }

    // MARK: - 3 · La línea al pie de Saldos

    @Test func note_showsWhenSimplifyingChangesSomethingInAGroupOfThree() {
        let piso = piso()
        let simplified = GroupBalanceService.calculateDebts(
            expenses: piso.expenses, shares: piso.shares, settlements: piso.settlements, simplifyDebts: true)
        let pairs = GroupBalanceService.calculateDebts(
            expenses: piso.expenses, shares: piso.shares, settlements: piso.settlements, simplifyDebts: false)

        #expect(GroupMenosPagosNoteLogic.showsNote(
            simplifyDebts: true, activeMemberCount: 3, simplified: simplified, pairs: pairs))
        // Sin «Menos pagos», con dos personas o sin nada que juntar, no hay línea.
        #expect(!GroupMenosPagosNoteLogic.showsNote(
            simplifyDebts: false, activeMemberCount: 3, simplified: simplified, pairs: pairs))
        #expect(!GroupMenosPagosNoteLogic.showsNote(
            simplifyDebts: true, activeMemberCount: 2, simplified: simplified, pairs: pairs))
        #expect(!GroupMenosPagosNoteLogic.showsNote(
            simplifyDebts: true, activeMemberCount: 3, simplified: pairs, pairs: pairs))
    }

    @Test func note_ignoresOrderAndFractionsOfACent() {
        let a = Debt(fromMemberID: "a", toMemberID: "b", amount: 10, currencyCode: "PEN")
        let b = Debt(fromMemberID: "c", toMemberID: "b", amount: 5, currencyCode: "PEN")
        let bAlmost = Debt(fromMemberID: "c", toMemberID: "b", amount: 5.001, currencyCode: "PEN")
        #expect(!GroupMenosPagosNoteLogic.showsNote(
            simplifyDebts: true, activeMemberCount: 3, simplified: [a, b], pairs: [bAlmost, a]))
    }

    /// El detalle calcula las de cada par con «Menos pagos» y no las calcula sin él (cableado del ViewModel).
    @Test func detailViewModel_computesPairsOnlyWhenSimplifying() throws {
        let source = try String(contentsOf: Self.repoFile("Yala/App/ViewModels/GroupDetailViewModel.swift"),
                                encoding: .utf8)
        #expect(source.contains("let rawPairDebts = group.simplifyDebts"))
        #expect(source.contains("settlements: settlements, simplifyDebts: false)"))
    }

    private static func repoFile(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(path)
    }

    /// Un dólar, tres soles: para ver que la cabecera convierte como la tarjeta.
    private struct TimesThree: CurrencyConverting {
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal { amount * 3 }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal { amount * 3 }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality) { (amount * 3, .exact) }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality) { (amount * 3, .exact) }
    }
}
