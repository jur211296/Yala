//
//  Bienvenida23PasosTests.swift
//  YalaTests
//
//  Lote 03 de la bienvenida 2.3 (docs/onboarding-2-3/SPEC.md): el paso 1 «Crea tu primera cuenta» (Y23-07) y el paso 2
//  «Aprender a registrar» (Y23-08 guía de foco, Y23-09 prueba de cortesía, Y23-10 cierre con «¿Borramos los de
//  prueba?»).
//

import Foundation
import Testing

@testable import Yala

// MARK: - Y23-07 · las preguntas del paso 1

@Suite("Bienvenida 2.3 · paso 1, las preguntas (Y23-07)")
struct FirstAccountFlowLogicTests {
    typealias Logic = FirstAccountFlowLogic

    /// Una pregunta de saldo por moneda, y en tarjeta cierre, pago y recordatorio.
    @Test func card_inTwoCurrencies_asksEachBalanceThenTheCardDays() {
        let steps = Logic.steps(kind: .creditCard, currencyCount: 2, paymentDay: nil)
        #expect(steps == [.kind, .currencies, .name, .balance(index: 0), .balance(index: 1),
                          .statementDay, .paymentDay, .reminder, .done])
    }

    /// Sin día de pago no hay qué recordar: se salta el recordatorio.
    @Test func card_withoutPaymentDay_skipsTheReminder() {
        for answer in [Logic.DayAnswer.unknown, .preferNotToSay] {
            let steps = Logic.steps(kind: .creditCard, currencyCount: 1, paymentDay: answer)
            #expect(!steps.contains(.reminder))
            #expect(Logic.next(after: .paymentDay, kind: .creditCard, currencyCount: 1, paymentDay: answer) == .done)
        }
    }

    @Test func cash_hasNoCardQuestions() {
        #expect(Logic.steps(kind: .cash, currencyCount: 1, paymentDay: nil)
                == [.kind, .currencies, .name, .balance(index: 0), .done])
    }

    /// Hasta cuatro monedas por cuenta (decidido en la ficha), sin repetir.
    @Test func currencies_upToFour_withoutRepeats() {
        #expect(Logic.canAddCurrency(count: 3))
        #expect(!Logic.canAddCurrency(count: 4))
        #expect(Logic.normalizedCurrencies(["PEN", "usd", "USD", "EUR", "GBP", "JPY"]) == ["PEN", "USD", "EUR", "GBP"])
    }

    /// Recordatorio 0/1/3/5; sin día de cierre, solo el mismo día.
    @Test func reminderOptions_followTheStatementDay() {
        #expect(Logic.reminderOptions(statementDay: 18) == [0, 1, 3, 5])
        #expect(Logic.reminderOptions(statementDay: nil) == [0])
        #expect(Logic.storedReminder(lead: 3, paymentDay: .day(5), statementDay: .day(18)) == 3)
        #expect(Logic.storedReminder(lead: 3, paymentDay: .day(5), statementDay: .unknown) == 0)
        #expect(Logic.storedReminder(lead: 1, paymentDay: .unknown, statementDay: .day(18)) == nil)
        #expect(Logic.storedReminder(lead: nil, paymentDay: .day(5), statementDay: .day(18)) == nil)
    }

    /// El permiso de notificaciones solo si se eligió un recordatorio (Y23-17).
    @Test func notificationPermission_onlyWhenAReminderIsChosen() {
        #expect(Logic.asksNotificationPermission(lead: 0))
        #expect(!Logic.asksNotificationPermission(lead: nil))
    }

    /// En tarjeta lo que se debe va en negativo; en las demás manda el botón + / −.
    @Test func storedBalance_signRules() {
        #expect(Logic.storedBalance(kind: .creditCard, magnitude: 620, isNegative: false) == -620)
        #expect(Logic.storedBalance(kind: .creditCard, magnitude: 0, isNegative: false) == 0)
        #expect(Logic.storedBalance(kind: .checking, magnitude: 1200, isNegative: false) == 1200)
        #expect(Logic.storedBalance(kind: .checking, magnitude: 40, isNegative: true) == -40)
    }

    /// «No sé, ayúdame a sacarlo»: en tarjeta, límite menos lo que te queda; en las demás, la suma.
    @Test func helper_cardDebtAndSum() {
        #expect(Logic.cardDebt(limit: 5000, remaining: 4380) == 620)
        #expect(Logic.cardDebt(limit: 100, remaining: 300) == 0)
        #expect(abs(Logic.cardUsedFraction(limit: 5000, remaining: 4380) - 0.124) < 0.000_001)
        #expect(Logic.helperTotal([1200, 300, 150]) == 1650)
    }

    @Test func days_from1to31() {
        #expect(Logic.isValidDay(1) && Logic.isValidDay(31))
        #expect(!Logic.isValidDay(0) && !Logic.isValidDay(32))
    }

    @Test func name_emptyFallsBackToTheSuggested() {
        #expect(Logic.finalName(typed: "  ", suggested: "Mi dinero") == "Mi dinero")
        #expect(Logic.finalName(typed: " Visa del trabajo ", suggested: "Tarjeta") == "Visa del trabajo")
    }
}

// MARK: - Y23-08 · la guía de foco del formulario

@Suite("Bienvenida 2.3 · paso 2, la guía del formulario (Y23-08)")
struct NewRecordTutorialGuideTests {
    typealias Guide = NewRecordTutorialGuide

    /// Cada paso avanza al hacer la acción: sin monto, el monto; con monto y sin categoría, la categoría.
    @Test func step_followsWhatIsFilled() {
        #expect(Guide.step(hasAmount: false, hasCategory: false, current: 0) == Guide.Step.amount.rawValue)
        #expect(Guide.step(hasAmount: true, hasCategory: false, current: 0) == Guide.Step.category.rawValue)
        #expect(Guide.step(hasAmount: true, hasCategory: true, current: 1) == Guide.Step.account.rawValue)
        // Ya en «Guárdalo», volver a mirar no la devuelve atrás.
        #expect(Guide.step(hasAmount: true, hasCategory: true, current: 4) == Guide.Step.save.rawValue)
        // Si se borra el monto, vuelve a pedirlo.
        #expect(Guide.step(hasAmount: false, hasCategory: true, current: 4) == Guide.Step.amount.rawValue)
    }

    /// Con más de una cuenta se salta «Tu cuenta ya está puesta» (su texto dice que es la única).
    @Test func severalAccounts_skipTheAccountStep() {
        #expect(Guide.step(hasAmount: true, hasCategory: true, current: 1, hasSingleAccount: false)
                == Guide.Step.description.rawValue)
        #expect(Guide.step(hasAmount: true, hasCategory: true, current: 1, hasSingleAccount: true)
                == Guide.Step.account.rawValue)
        #expect(Guide.step(hasAmount: true, hasCategory: true, current: 4, hasSingleAccount: false)
                == Guide.Step.save.rawValue)
    }

    /// Con el teclado o una hoja encima, se esconde.
    @Test func hidesUnderTheKeyboardOrASheet() {
        #expect(Guide.isShowing(isActive: true, keyboardVisible: false, sheetOpen: false))
        #expect(!Guide.isShowing(isActive: true, keyboardVisible: true, sheetOpen: false))
        #expect(!Guide.isShowing(isActive: true, keyboardVisible: false, sheetOpen: true))
        #expect(!Guide.isShowing(isActive: false, keyboardVisible: false, sheetOpen: false))
    }

    /// Cinco pasos, en el orden de la ficha, con «Entendido» en la cuenta y «Escribir / Saltar» en el nombre.
    @MainActor @Test func fiveSteps_withTheirButtons() {
        let steps = Guide.steps
        #expect(steps.map(\.id) == [Guide.amountAnchor, Guide.categoryAnchor, Guide.accountAnchor,
                                    Guide.descriptionAnchor, Guide.saveAnchor])
        #expect(steps.allSatisfy { $0.advancesByAction })
        #expect(!steps[0].showsPrimaryButton && !steps[1].showsPrimaryButton && !steps[4].showsPrimaryButton)
        #expect(steps[2].primaryLabel == L10n.Common.understood)
        #expect(steps[3].primaryLabel != nil && steps[3].secondaryLabel != nil)
    }

    /// Los tours de siempre no cambian: un paso sin acción lleva su «Siguiente».
    @Test func classicSteps_keepTheirNextButton() {
        let step = CoachMarkStep(id: "x", title: "t", message: "m")
        #expect(!step.advancesByAction)
        #expect(step.showsPrimaryButton)
    }

    /// Las páginas cortas no avanzan solas con Reducir movimiento ni con VoiceOver (ficha, «Cómo usar…»).
    @Test func storyPage_staysStillWithReduceMotionOrVoiceOver() {
        #expect(TutorialStoryLogic.advancesAutomatically(part: 0, count: 4, reduceMotion: false, voiceOver: false))
        #expect(!TutorialStoryLogic.advancesAutomatically(part: 0, count: 4, reduceMotion: true, voiceOver: false))
        #expect(!TutorialStoryLogic.advancesAutomatically(part: 0, count: 4, reduceMotion: false, voiceOver: true))
        #expect(!TutorialStoryLogic.advancesAutomatically(part: 3, count: 4, reduceMotion: false, voiceOver: false))
        #expect(TutorialStoryLogic.tapped(part: 3, count: 4) == 3)
    }
}

// MARK: - Y23-10 · el Panel al terminar

@MainActor
@Suite("Bienvenida 2.3 · paso 2, el Panel al terminar (Y23-10)")
struct PanelAfterLearningToRecordTests {

    /// Debajo de la cuenta, solo «Últimos registros»: lo demás queda oculto, en orden canónico.
    @Test func onlyAccountsAndLatestRecordsStayVisible() {
        let hidden = PrimerosPasosPanelPresentations.sectionsHiddenAfterLearningToRecord(
            current: ["health", "latestRecords", "distribucion", "tools"])
        #expect(hidden == ["health", "tendencias", "distribucion", "planificacion", "tools"])
        #expect(!hidden.contains("accounts"))
        #expect(!hidden.contains("latestRecords"))
    }
}
