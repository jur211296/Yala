//
//  StepGuideLogicTests.swift
//  YalaTests
//
//  El estado de la guía por pasos (`StepGuideProgress`, referencia del 2026-09-15): un solo paso accionable, el
//  progreso doble de arriba coherente con él, y que un toque tardío no se salte pasos. Más qué tutoriales usan la
//  guía en vez del carrusel.
//

import Testing

@testable import Yala

struct StepGuideLogicTests {

    // MARK: - Arranque

    @Test func start_firstStepIsTheOnlyActive() {
        let progress = StepGuideProgress(total: 4)
        #expect(progress.activeIndex == 0)
        #expect(progress.displayedStep == 1)
        #expect((0..<4).map(progress.phase(of:)) == [.active, .upcoming, .upcoming, .upcoming])
        #expect(!progress.isFinished)
    }

    /// «Paso 1 de 3» ya pinta la primera barra, como la referencia; las demás, vacías.
    @Test func start_fillsOnlyTheFirstBar() {
        let progress = StepGuideProgress(total: 3)
        #expect((0..<3).map(progress.isBarFilled) == [true, false, false])
    }

    // MARK: - Avanzar

    @Test func completingTheActiveStep_movesToTheNext() {
        var progress = StepGuideProgress(total: 3)
        progress.complete(0)
        #expect(progress.activeIndex == 1)
        #expect(progress.displayedStep == 2)
        #expect((0..<3).map(progress.phase(of:)) == [.done, .active, .upcoming])
        #expect((0..<3).map(progress.isBarFilled) == [true, true, false])
    }

    /// Un toque sobre un paso que ya no es el activo —doble toque en «Hecho», o la vuelta tardía de abrir Atajos—
    /// no avanza: si lo hiciera, se saltaría un paso que nadie hizo.
    @Test(arguments: [0, 2, 3, -1])
    func completingANonActiveStep_isIgnored(index: Int) {
        var progress = StepGuideProgress(total: 4)
        progress.complete(0)
        progress.complete(index)
        #expect(progress.activeIndex == 1)
        #expect(progress.completed == 1)
    }

    @Test func completingEveryStep_finishesWithoutActive() {
        var progress = StepGuideProgress(total: 3)
        for index in 0..<3 { progress.complete(index) }
        #expect(progress.isFinished)
        #expect(progress.activeIndex == nil)
        #expect((0..<3).map(progress.phase(of:)) == [.done, .done, .done])
        // El texto se queda en «Paso 3 de 3», nunca «Paso 4 de 3».
        #expect(progress.displayedStep == 3)
        #expect((0..<3).map(progress.isBarFilled) == [true, true, true])
    }

    @Test func finished_furtherCompletionsDoNothing() {
        var progress = StepGuideProgress(total: 2, completed: 2)
        progress.complete(2)
        #expect(progress.completed == 2)
    }

    // MARK: - Bordes

    @Test func init_clampsCompletedIntoRange() {
        #expect(StepGuideProgress(total: 3, completed: 9).completed == 3)
        #expect(StepGuideProgress(total: 3, completed: -2).completed == 0)
    }

    @Test func emptyGuide_hasNothingToShow() {
        let progress = StepGuideProgress(total: 0)
        #expect(progress.activeIndex == nil)
        #expect(progress.displayedStep == 0)
        #expect(progress.isFinished)
    }

    // MARK: - Qué tutoriales son guía por pasos

    /// Solo Apple Pay: es el único tutorial que se hace fuera de Yala (en Atajos). Los demás siguen en el carrusel.
    @MainActor @Test func onlyApplePayUsesTheStepGuide() {
        #expect(Tutorial.allCases.filter(\.usesStepGuide) == [.applePay])
    }
}
