//
//  OnboardingLote1DecisionsTests.swift
//  YalaTests
//
//  Las decisiones de Jürgen del lote 1 de la auditoría UX 2.2 (2026-10-13) que tienen lógica:
//   · L1-9  «¿Dónde está tu dinero?»: «¿Cómo organizas?» y «Tipo de cuenta» en un solo paso.
//   · L1-1  el logo del arranque: 2,5 s solo en la primera impresión.
//   · L1-12 cuándo sale la oferta de prueba de Yala Pro.
//  Pure-logic + el cableado por source-scan donde la decisión vive en una vista.
//

import Foundation
import Testing

@testable import Yala

@Suite("UX 2.2 · L1-9 · «¿Dónde está tu dinero?»")
struct OnboardingAccountChoiceLogicTests {

    @Test("al entrar del alta nueva no hay nada elegido, y «Siguiente» espera")
    func freshEntry_hasNoChoice() {
        #expect(OnboardingAccountChoiceLogic.selectedChoice(mode: .fullControl, accountType: .general) == nil)
        #expect(OnboardingNextEnablement.isNextDisabled(
            step: .accountType, userName: "QA", accountName: "",
            isAccountTypeValid: OnboardingAccountChoiceLogic.selectedChoice(
                mode: .fullControl, accountType: .general) != nil,
            initialBalanceText: ""))
    }

    @Test("«Todo junto» guarda lo mismo que «una sola cuenta» de antes")
    func single_isTheOldDayToDay() {
        let applied = OnboardingAccountChoiceLogic.apply(.single)
        #expect(applied.mode == .dayToDay)
        #expect(applied.accountType == .general)
        #expect(applied.mindset == "patrimonial")
        #expect(OnboardingAccountChoiceLogic.selectedChoice(mode: applied.mode, accountType: applied.accountType) == .single)
    }

    @Test("un tipo guarda lo mismo que «cada cuenta por separado» + ese tipo", arguments: [
        AccountType.checking, .savings, .creditCard, .cash
    ])
    func type_isTheOldFullControl(_ type: AccountType) {
        let applied = OnboardingAccountChoiceLogic.apply(.type(type))
        #expect(applied.mode == .fullControl)
        #expect(applied.accountType == type)
        #expect(applied.mindset == "cashFlow")
        #expect(OnboardingAccountChoiceLogic.selectedChoice(mode: applied.mode, accountType: applied.accountType) == .type(type))
    }

    @Test("una sola opción marcada a la vez: «Todo junto» y un tipo no se marcan juntos")
    func exactlyOneMarked() {
        for mode in [OnboardingUsageMode.dayToDay, .fullControl] {
            for type in [AccountType.general] + OnboardingAccountChoiceLogic.accountTypes {
                let choice = OnboardingAccountChoiceLogic.selectedChoice(mode: mode, accountType: type)
                let marked = ([OnboardingAccountChoice.single] + OnboardingAccountChoiceLogic.accountTypes.map { .type($0) })
                    .filter { $0 == choice }
                #expect(marked.count <= 1)
            }
        }
        // `.dayToDay` con un tipo concreto o `.fullControl` con `.general` no son estados de una elección.
        #expect(OnboardingAccountChoiceLogic.selectedChoice(mode: .dayToDay, accountType: .savings) == nil)
        #expect(OnboardingAccountChoiceLogic.selectedChoice(mode: .expensesOnly, accountType: .general) == nil)
    }

    @Test("la lista de tipos es la de antes y en el mismo orden")
    func typesUnchanged() {
        #expect(OnboardingAccountChoiceLogic.accountTypes == [.checking, .savings, .creditCard, .cash])
    }
}

@Suite("UX 2.2 · L1-1 · el logo del arranque")
struct SplashDurationLogicTests {

    @Test("2,5 s mientras el onboarding no está hecho; después, sin mínimo")
    func onlyTheFirstImpressionWaits() {
        #expect(SplashDurationLogic.minimumSeconds(hasCompletedOnboarding: false) == 2.5)
        #expect(SplashDurationLogic.minimumSeconds(hasCompletedOnboarding: true) == 0)
    }

    @Test("el splash lee la decisión y no un mínimo fijo")
    func splashIsWired() throws {
        let src = try SourceScan.code("Yala/App/ContentView.swift")
        #expect(src.contains("SplashDurationLogic.minimumSeconds(hasCompletedOnboarding: hasCompletedOnboarding)"))
        #expect(!src.contains("minimumSplashDuration"), "volvió el mínimo fijo de 2,5 s para todos los arranques")
    }
}

@Suite("UX 2.2 · L1-12 · cuándo sale la oferta de prueba")
struct TrialOfferMomentLogicTests {

    @Test("tras guardar un registro sale, si está armada y no es Pro")
    func recordSaved_submits() {
        #expect(TrialOfferMomentLogic.shouldSubmit(.recordSaved(firstRecordPracticePending: false),
                                                   armed: true, momentReached: false, isProUser: false))
        #expect(!TrialOfferMomentLogic.shouldSubmit(.recordSaved(firstRecordPracticePending: false),
                                                    armed: false, momentReached: false, isProUser: false))
        #expect(!TrialOfferMomentLogic.shouldSubmit(.recordSaved(firstRecordPracticePending: false),
                                                    armed: true, momentReached: false, isProUser: true))
    }

    @Test("con «¿Era de prueba?» detrás, espera a la respuesta")
    func recordSaved_withPractice_waits() {
        #expect(!TrialOfferMomentLogic.shouldSubmit(.recordSaved(firstRecordPracticePending: true),
                                                    armed: true, momentReached: false, isProUser: false))
        #expect(TrialOfferMomentLogic.shouldSubmit(.firstRecordPracticeAnswered,
                                                   armed: true, momentReached: true, isProUser: false))
        // Pero el momento queda apuntado: un cierre de la app entre medias no la pierde.
        #expect(TrialOfferMomentLogic.reachesTheMoment(.recordSaved(firstRecordPracticePending: true)))
    }

    @Test("al arrancar solo sale si su momento ya llegó: el alta sola ya no la presenta")
    func launch_onlyAfterTheMoment() {
        #expect(!TrialOfferMomentLogic.shouldSubmit(.launch, armed: true, momentReached: false, isProUser: false))
        #expect(TrialOfferMomentLogic.shouldSubmit(.launch, armed: true, momentReached: true, isProUser: false))
        #expect(!TrialOfferMomentLogic.reachesTheMoment(.launch))
    }

    @Test("terminar «Primeros pasos» la vuelve a armar y la pide, salvo a un Pro")
    func setupChecklist_armsAndSubmits() {
        #expect(TrialOfferMomentLogic.arms(.setupChecklistCompleted, isProUser: false))
        #expect(!TrialOfferMomentLogic.arms(.setupChecklistCompleted, isProUser: true))
        #expect(!TrialOfferMomentLogic.arms(.recordSaved(firstRecordPracticePending: false), isProUser: false))
        #expect(TrialOfferMomentLogic.shouldSubmit(.setupChecklistCompleted,
                                                   armed: true, momentReached: false, isProUser: false))
    }

    @Test("el cierre del onboarding ya no pide la oferta; el drenaje apaga las dos marcas")
    func wiring() throws {
        let content = try SourceScan.code("Yala/App/ContentView.swift")
        #expect(!content.contains(".onChange(of: showOnboarding)"),
                "volvió el disparo de la oferta al cerrar el onboarding (UX 2.2 · L1-12)")
        let drain = try #require(content.range(of: "case .presentTrialOffer:"))
        let tramo = String(content[drain.upperBound...].prefix(600))
        #expect(tramo.contains("needsPostOnboardingTrial = false"))
        #expect(tramo.contains("trialOfferMomentReached = false"))
        #expect(content.contains("TrialOfferMoments.note(.launch)"))
        // Quien ya es Pro no espera ninguna oferta: sin el `!isProUser`, una oferta armada que nunca drena le
        // escondería Novedades en cada arranque.
        #expect(content.contains("if SessionState.shared.needsPostOnboardingTrial && !FeatureGateService.shared.isProUser {"))

        for file in ["Yala/App/Views/Transactions/TransactionSuccessView.swift",
                     "Yala/App/Views/Inbox/InboxApproveSuccessView.swift",
                     "Yala/App/Views/Inbox/InboxBulkApproveSuccessView.swift"] {
            #expect(try SourceScan.code(file).contains("TrialOfferMoments.noteRecordSaved()"),
                    "\(file) dejó de pedir la oferta al guardar")
        }
        let practice = try SourceScan.code("Yala/App/Views/Panel/PanelSheetsModifier.swift")
        #expect(practice.components(separatedBy: "TrialOfferMoments.notePracticeAnswered(").count - 1 == 2,
                "las dos respuestas de «¿Era de prueba?» tienen que soltar la oferta que esperaba")
        let checklist = try SourceScan.code("Yala/App/Models/SetupChecklistManager.swift")
        #expect(checklist.contains("var onAllStepsCompleted: () -> Void = { TrialOfferMoments.note(.setupChecklistCompleted) }"))
        #expect(checklist.contains("onAllStepsCompleted()"))
        #expect(try SourceScan.code("Yala/App/Views/Panel/PanelView.swift")
            .contains("checklist.wouldCompleteAll(by: .discoverFeatures)"),
                "el último paso de «Primeros pasos» volvería a abrir el paywall general encima de la oferta")
    }
}

/// Lectura de fuentes para los source-scans de este fichero. `code` quita las líneas de comentario: varios
/// de estos scans buscan una AUSENCIA, y documentar lo que se retiró no debe ponerlos en rojo.
private enum SourceScan {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }
}

@Suite("UX 2.2 · B1 · la calculadora de tarjeta no enseña «-0.00»")
struct BalanceCalculatorDisplayLogicTests {

    @Test("un cero negativo se enseña como cero, sin signo")
    func negativeZeroIsZero() {
        let shown = BalanceCalculatorDisplayLogic.displayed(-0.0)
        #expect(shown == 0)
        #expect(shown.sign == .plus, "con el campo vacío la tarjeta decía «S/ -0.00»")
    }

    @Test("los importes de verdad no cambian")
    func realAmountsUnchanged() {
        #expect(BalanceCalculatorDisplayLogic.displayed(-1800) == -1800)
        #expect(BalanceCalculatorDisplayLogic.displayed(1800) == 1800)
    }
}
