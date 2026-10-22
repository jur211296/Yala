//
//  GroupBridgeStatsAdjustmentTests.swift
//  YalaTests
//
//  Pinnea la matemática de neteo "mi parte" del SSOT `GroupBridgeStatsAdjustment`: la pata REAL
//  Caso A se ajusta a `-myShare` (= real + Σ patas de préstamo) y las patas de préstamo se
//  suprimen; Caso B / solo-grupos / saldos iniciales / settlements / TX personales quedan intactos.
//
//  Requiere `ModelContext` porque el helper lee relaciones `@Model` (`account`/`subcategory`) y
//  keyea por `persistentModelID`. `@Suite(.serialized)` por el reuso per-file de `makeTestContext`.
//
//  MUTANTE VERIFICADO: revertir el neteo (`native = realLeg.amount` sin `+ Σ loanBySign`) o quitar
//  la supresión hace fallar `casoAFull_*` y `multiCurrency_*`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupBridgeStatsAdjustment · neteo mi parte", .serialized)
@MainActor
struct GroupBridgeStatsAdjustmentTests {

    // MARK: - Infra

    private func makeLeg(
        _ context: ModelContext,
        amount: Double,
        system: Bool,
        splitExpenseID: String?,
        splitSettlementID: String? = nil,
        subcategory: Subcategory? = nil,
        account: Account? = nil,
        preferred: Double? = nil
    ) -> TransactionItem {
        let acc: Account?
        if let account {
            acc = account
        } else {
            let a = makeTestAccount(context: context, name: system ? "Grupos" : "Efectivo")
            a.isSystemAccount = system
            acc = a
        }
        let tx = TransactionItem(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            amount: amount,
            currencyCode: "USD",
            category: subcategory?.safeCategory,
            subcategory: subcategory,
            account: acc,
            amountInPreferredCurrency: preferred ?? amount
        )
        tx.splitExpenseID = splitExpenseID
        tx.splitSettlementID = splitSettlementID
        context.insert(tx)
        return tx
    }

    private func systemSubcat(_ context: ModelContext, name: String) -> Subcategory {
        let cat = makeTestCategory(context: context, name: "SistemaGrupos", isIncome: true)
        let sub = makeTestSubcategory(context: context, name: name, category: cat)
        sub.isSystem = true
        return sub
    }

    // MARK: - Caso A full

    @Test func casoAFull_realLeg_showsMyShare_lentSuppressed() throws {
        let ctx = try makeTestContext()
        let eid = UUID().uuidString
        let real = makeLeg(ctx, amount: -300, system: false, splitExpenseID: eid)
        let lent = makeLeg(ctx, amount: 200, system: true, splitExpenseID: eid,
                           subcategory: systemSubcat(ctx, name: "loanToGroups"))
        try ctx.save()

        let adj = GroupBridgeStatsAdjustment.build(from: [real, lent])

        #expect(adj.amount(real) == -100)                       // -300 + 200 = -myShare
        #expect(adj.amountInPreferredCurrency(real) == -100)
        #expect(adj.isSuppressed(lent))
        #expect(!adj.isSuppressed(real))
        // Income-aware: la real contribuye -100, la lent se salta (nil).
        #expect(adj.incomeAwarePreferred(real) == -100)
        #expect(adj.incomeAwarePreferred(lent) == nil)
    }

    @Test func casoAFull_lentZero_showsTotalAsMyShare() throws {
        let ctx = try makeTestContext()
        let eid = UUID().uuidString
        // Yo solo en el split: myShare == total, no hay pata lent.
        let real = makeLeg(ctx, amount: -250, system: false, splitExpenseID: eid)
        try ctx.save()

        let adj = GroupBridgeStatsAdjustment.build(from: [real])
        #expect(adj.amount(real) == -250)                       // -total = -myShare
        #expect(!adj.isSuppressed(real))
    }

    @Test func multiCurrency_netsInPreferred() throws {
        let ctx = try makeTestContext()
        let eid = UUID().uuidString
        // Gasto en EUR, preferida USD a tasa 2: real -300 EUR = -600 USD; lent +200 EUR = +400 USD.
        let real = makeLeg(ctx, amount: -300, system: false, splitExpenseID: eid, preferred: -600)
        let lent = makeLeg(ctx, amount: 200, system: true, splitExpenseID: eid,
                           subcategory: systemSubcat(ctx, name: "loanToGroups"), preferred: 400)
        try ctx.save()

        let adj = GroupBridgeStatsAdjustment.build(from: [real, lent])
        #expect(adj.amount(real) == -100)                       // nativo
        #expect(adj.amountInPreferredCurrency(real) == -200)    // -600 + 400 = -myShare en USD
        #expect(adj.isSuppressed(lent))
    }

    // MARK: - Caso B (ya correcto)

    @Test func casoB_myShareVirtual_unchanged() throws {
        let ctx = try makeTestContext()
        let eid = UUID().uuidString
        let cat = makeTestCategory(context: ctx, name: "Comida")
        let userSub = makeTestSubcategory(context: ctx, name: "Antojos", category: cat)
        let virtual = makeLeg(ctx, amount: -100, system: true, splitExpenseID: eid, subcategory: userSub)
        try ctx.save()

        let adj = GroupBridgeStatsAdjustment.build(from: [virtual])
        #expect(adj.amount(virtual) == -100)                    // ya es -myShare
        #expect(!adj.isSuppressed(virtual))
        #expect(adj.incomeAwarePreferred(virtual) == -100)
    }

    // MARK: - solo-grupos (TX1 -myShare + TX2 +total loanToGroups)

    @Test func sesiónSoloGrupos_pair_tx1Unchanged_tx2Suppressed() throws {
        let ctx = try makeTestContext()
        let eid = UUID().uuidString
        let userCat = makeTestCategory(context: ctx, name: "Comida")
        let userSub = makeTestSubcategory(context: ctx, name: "Antojos", category: userCat)
        let loanSub = systemSubcat(ctx, name: "loanToGroups")
        let tx1 = makeLeg(ctx, amount: -100, system: true, splitExpenseID: eid, subcategory: userSub)
        let tx2 = makeLeg(ctx, amount: 300, system: true, splitExpenseID: eid, subcategory: loanSub)
        try ctx.save()

        let adj = GroupBridgeStatsAdjustment.build(
            from: [tx1, tx2], loanToGroupsSubcatIDs: [loanSub.persistentModelID]
        )
        #expect(adj.amount(tx1) == -100)                        // ya es -myShare
        #expect(!adj.isSuppressed(tx1))
        #expect(adj.isSuppressed(tx2))                          // ingreso derivado → suprimido
    }

    // MARK: - Pata de préstamo SUELTA (payer con myShare==0) → suprimida por rol

    @Test func lonesomeLoanLeg_suppressedWhenRoleKnown() throws {
        let ctx = try makeTestContext()
        let eid = UUID().uuidString
        let loanSub = systemSubcat(ctx, name: "loanToGroups")
        let lone = makeLeg(ctx, amount: 300, system: true, splitExpenseID: eid, subcategory: loanSub)
        try ctx.save()

        // Con rol conocido → suprime el ingreso fantasma.
        let adj = GroupBridgeStatsAdjustment.build(
            from: [lone], loanToGroupsSubcatIDs: [loanSub.persistentModelID]
        )
        #expect(adj.isSuppressed(lone))

        // Sin rol (set vacío) → conservador: NO suprime (comportamiento previo).
        let adjNoRole = GroupBridgeStatsAdjustment.build(from: [lone])
        #expect(!adjNoRole.isSuppressed(lone))
    }

    // MARK: - Saldos iniciales (fuera de scope: se PRESERVAN)

    @Test func openingBalanceOwed_preserved_notSuppressed() throws {
        let ctx = try makeTestContext()
        let eid = UUID().uuidString
        let owedSub = systemSubcat(ctx, name: "openingBalanceOwed")
        let loanSub = systemSubcat(ctx, name: "loanToGroups")   // otro rol, para el set
        let owed = makeLeg(ctx, amount: 300, system: true, splitExpenseID: eid, subcategory: owedSub)
        try ctx.save()

        let adj = GroupBridgeStatsAdjustment.build(
            from: [owed], loanToGroupsSubcatIDs: [loanSub.persistentModelID]
        )
        #expect(!adj.isSuppressed(owed))                        // +income preservado
        #expect(adj.amount(owed) == 300)
    }

    @Test func openingBalanceDebt_unchanged() throws {
        let ctx = try makeTestContext()
        let eid = UUID().uuidString
        let debtSub = systemSubcat(ctx, name: "openingBalanceDebt")
        let debt = makeLeg(ctx, amount: -300, system: true, splitExpenseID: eid, subcategory: debtSub)
        try ctx.save()

        let adj = GroupBridgeStatsAdjustment.build(from: [debt])
        #expect(adj.amount(debt) == -300)                       // -myShare (deuda), sin cambio
        #expect(!adj.isSuppressed(debt))
    }

    // MARK: - Settlement (splitSettlementID) y TX personal: intactos

    @Test func settlement_notGrouped_unchanged() throws {
        let ctx = try makeTestContext()
        let settle = makeLeg(ctx, amount: -80, system: true, splitExpenseID: nil,
                             splitSettlementID: UUID().uuidString,
                             subcategory: systemSubcat(ctx, name: "settlementSent"))
        try ctx.save()

        let adj = GroupBridgeStatsAdjustment.build(from: [settle])
        #expect(adj.amount(settle) == -80)
        #expect(!adj.isSuppressed(settle))
    }

    @Test func personalTx_unchanged() throws {
        let ctx = try makeTestContext()
        let cat = makeTestCategory(context: ctx, name: "Comida")
        let sub = makeTestSubcategory(context: ctx, name: "Almuerzo", category: cat)
        let personal = makeLeg(ctx, amount: -42, system: false, splitExpenseID: nil, subcategory: sub)
        try ctx.save()

        let adj = GroupBridgeStatsAdjustment.build(from: [personal])
        #expect(adj.amount(personal) == -42)
        #expect(!adj.isSuppressed(personal))
    }

    // MARK: - Ventana lazy: pata con cuenta sin hidratar → grupo no tocado

    @Test func lazyAccountNil_groupSkipped() throws {
        let ctx = try makeTestContext()
        let eid = UUID().uuidString
        let real = makeLeg(ctx, amount: -300, system: false, splitExpenseID: eid)
        // Pata lent sin cuenta (simula relación no hidratada).
        let lent = TransactionItem(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            amount: 200, currencyCode: "USD", account: nil, amountInPreferredCurrency: 200
        )
        lent.splitExpenseID = eid
        ctx.insert(lent)
        try ctx.save()

        let adj = GroupBridgeStatsAdjustment.build(from: [real, lent])
        #expect(adj.amount(real) == -300)                       // grupo NO ajustado (conservador)
        #expect(!adj.isSuppressed(lent))
    }

    // MARK: - La incertidumbre de tasa viaja con el monto

    /// Pareja del ticket `bridge-de-grupos-pierde-la-marca-de-sus-patas`, con las cuatro
    /// combinaciones de flags. La pata de préstamo está SUPRIMIDA del recorrido, así que su flag no
    /// lo lee nadie — pero su monto sí entra en el importe sintetizado.
    ///
    /// El numerador son **magnitudes sumadas, nunca el neto**: es el contrato explícito de
    /// `ApproximateMarkThreshold`, escrito con esta misma pareja («1.000 y 900 dudosos no dejan 100
    /// de incertidumbre: dejan 1.900»). Cada fila de abajo es un veredicto distinto, así que
    /// devolver el neto marcado, o un booleano, o cero, pone alguna en rojo.
    @Test(arguments: [
        (realProv: false, lentProv: true,  esperado: 900.0),   // el caso del ticket
        (realProv: true,  lentProv: false, esperado: 1_000.0), // el que ya se detectaba
        (realProv: true,  lentProv: true,  esperado: 1_900.0), // el ejemplo del contrato
        (realProv: false, lentProv: false, esperado: 0.0),     // control positivo
    ])
    func synthesizedAmount_accumulatesMagnitudesOfEveryProvisionalLeg(
        caso: (realProv: Bool, lentProv: Bool, esperado: Double)
    ) throws {
        let ctx = try makeTestContext()
        let eid = UUID().uuidString
        let real = makeLeg(ctx, amount: -1_000, system: false, splitExpenseID: eid)
        real.isExchangeRateProvisional = caso.realProv
        let lent = makeLeg(ctx, amount: 900, system: true, splitExpenseID: eid,
                           subcategory: systemSubcat(ctx, name: "loanToGroups"))
        lent.isExchangeRateProvisional = caso.lentProv
        try ctx.save()

        let adj = GroupBridgeStatsAdjustment.build(from: [real, lent])

        // Premisa: el bridge SÍ neteó. Sin esto, apagar el bridge deja el caso «las dos exactas»
        // en verde por el camino equivocado (la fila cae al flag de la propia transacción).
        #expect(adj.amountInPreferredCurrency(real) == -100, "el importe no cambia: -1.000 + 900")
        #expect(adj.isSuppressed(lent), "premisa: la pata de préstamo está suprimida")
        // La magnitud que se le pasa es el NETO que el llamador está sumando (100). Para una fila
        // ajustada se ignora, y ahí está el fondo del asunto: la incertidumbre no es el neto.
        #expect(adj.approximateMagnitude(real, magnitude: 100) == caso.esperado)
    }

    /// Una TX sin ajuste aporta su propia magnitud, o cero. Es lo que hace que cablear el accessor
    /// en los calculadores no cambie nada para quien no usa grupos.
    @Test func unadjustedTx_contributesItsOwnMagnitude() throws {
        let ctx = try makeTestContext()
        let suelta = makeLeg(ctx, amount: -50, system: false, splitExpenseID: nil)
        suelta.isExchangeRateProvisional = true
        try ctx.save()

        let adj = GroupBridgeStatsAdjustment.build(from: [suelta])
        #expect(adj.approximateMagnitude(suelta, magnitude: 50) == 50)
        suelta.isExchangeRateProvisional = false
        #expect(adj.approximateMagnitude(suelta, magnitude: 50) == 0)
    }

    // MARK: - .none = identidad

    @Test func none_isIdentity() throws {
        let ctx = try makeTestContext()
        let real = makeLeg(ctx, amount: -300, system: false, splitExpenseID: UUID().uuidString)
        try ctx.save()
        let adj = GroupBridgeStatsAdjustment.none
        #expect(adj.amount(real) == -300)
        #expect(adj.amountInPreferredCurrency(real) == -300)
        #expect(!adj.isSuppressed(real))
        #expect(adj.incomeAwarePreferred(real) == -300)
        real.isExchangeRateProvisional = true
        #expect(adj.approximateMagnitude(real, magnitude: 300) == 300,
                "con `.none` la magnitud dudosa es la de la propia fila")
    }
}
