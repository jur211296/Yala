//
//  DraftToGroupExpenseTemplateLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `DraftToGroupExpenseTemplateLogic` — construye el
//  `GroupExpensePrefillTemplate` desde un draft personal de gasto. Sin SwiftData
//  (se invoca con `accountPrefill: nil`; el resto son valores planos).
//

import Foundation
import Testing

@testable import Yala

@Suite("Draft → Group Expense Template")
struct DraftToGroupExpenseTemplateLogicTests {

    /// Fecha fija y PASADA para todos los casos. Fija porque `.now` haría el test dependiente del
    /// reloj; pasada porque el bug que cubre este archivo es que la fecha se sustituía por HOY, y
    /// contra un `.now` de fixture ese fallo es invisible (fue justo lo que impidió verlo en el QA
    /// del simulador: el seed fecha los borradores hoy, así que el escenario no discriminaba).
    private static let draftDate = Date(timeIntervalSince1970: 1_750_000_000)  // 2025-06-15

    @Test func negativeAmount_normalizedToPositive() {
        let t = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: -42.5, cachedCurrencyCode: "PEN", note: "Cena",
            activeMemberIDs: [], groupCurrencyCode: "USD", date: Self.draftDate
        )
        #expect(t.totalAmount == 42.5)
    }

    @Test func positiveAmount_unchanged() {
        let t = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: 30, cachedCurrencyCode: "PEN", note: "x",
            activeMemberIDs: [], groupCurrencyCode: "USD", date: Self.draftDate
        )
        #expect(t.totalAmount == 30)
    }

    @Test func cachedCurrency_takesPrecedence() {
        let t = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: -10, cachedCurrencyCode: "PEN", note: "x",
            activeMemberIDs: [], groupCurrencyCode: "USD", date: Self.draftDate
        )
        #expect(t.currencyCode == "PEN")
    }

    @Test func nilCachedCurrency_fallsBackToGroup() {
        let t = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: -10, cachedCurrencyCode: nil, note: "x",
            activeMemberIDs: [], groupCurrencyCode: "USD", date: Self.draftDate
        )
        #expect(t.currencyCode == "USD")
    }

    @Test func splitTypeIsEqual_andValuesEmpty() {
        let t = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: -10, cachedCurrencyCode: "USD", note: "x",
            activeMemberIDs: [UUID(), UUID()], groupCurrencyCode: "USD", date: Self.draftDate
        )
        #expect(t.splitType == .equal)
        #expect(t.values.isEmpty)
    }

    @Test func participantsDescriptionAndAccount_carriedThrough() {
        let ids = [UUID(), UUID(), UUID()]
        let t = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: -10, cachedCurrencyCode: "USD", note: "Almuerzo equipo",
            activeMemberIDs: ids, groupCurrencyCode: "USD", date: Self.draftDate
        )
        #expect(t.participantIDs == ids)
        #expect(t.description == "Almuerzo equipo")
        #expect(t.accountPrefill == nil)
    }

    // MARK: - La fecha del draft (regresión)

    /// El bug: la plantilla llevaba monto, descripción, moneda, reparto y cuenta — y **no** la
    /// fecha. `GroupExpenseViewModel.date` arranca en `.now`, así que convertir un borrador de
    /// hace días producía un gasto de grupo fechado HOY, en silencio.
    @Test func draftDate_isCarriedThrough_notReplacedByToday() {
        let t = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: -10, cachedCurrencyCode: "PEN", note: "Almuerzo del martes",
            activeMemberIDs: [], groupCurrencyCode: "PEN", date: Self.draftDate
        )
        #expect(t.date == Self.draftDate)
    }

    /// Control del test anterior: sin esto, `date == draftDate` pasaría igual si alguien fijara la
    /// fecha a una constante. Aquí la aserción es que la plantilla REFLEJA su entrada, y de paso
    /// que la fecha no se normaliza a medianoche ni se toca de ninguna otra forma — el instante
    /// exacto tiene que llegar intacto, porque quien decide el formato es la pantalla.
    @Test func draftDate_reflectsItsInput_withoutNormalizing() {
        let other = Date(timeIntervalSince1970: 1_700_123_456)  // distinto y con hora "sucia"
        let t = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: -10, cachedCurrencyCode: "PEN", note: "x",
            activeMemberIDs: [], groupCurrencyCode: "PEN", date: other
        )
        #expect(t.date == other)
        #expect(t.date != Self.draftDate)
    }
}
