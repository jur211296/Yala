//
//  WelcomeGroupsExitTests.swift
//  YalaTests
//
//  Propuesta B del estudio de solo-grupos (decisión de Jürgen, 24-oct): «Es mi primera vez» gana una pregunta de pie
//  que lleva al 2.º nivel de grupos. Su «Volver» tiene que devolver a la pantalla de la que se vino, no subir un nivel
//  de más. El recorrido entero lo fija `WelcomeChooserUITests.testNewChooser_groupsFooter_opensGroupsAndBackReturnsHere`.
//

import Testing
@testable import Yala

@Suite("Welcome · salida a grupos desde «Es mi primera vez»")
struct WelcomeGroupsExitTests {

    @Test("El 2.º nivel de grupos vuelve a la pantalla que lo abrió")
    func groupsChooserOrigin() {
        #expect(WelcomeBackStepLogic.groupsChooserOrigin(openedFrom: .newChooser) == .newChooser)
        #expect(WelcomeBackStepLogic.groupsChooserOrigin(openedFrom: .chooser) == .chooser)
    }

    @Test("Un origen que no es una de las dos entradas cae al elector de primer nivel, que la persona vio")
    func unknownOriginFallsBackToTheChooser() {
        #expect(WelcomeBackStepLogic.groupsChooserOrigin(openedFrom: .hero) == .chooser)
        #expect(WelcomeBackStepLogic.groupsChooserOrigin(openedFrom: .existingChooser) == .chooser)
        #expect(WelcomeBackStepLogic.groupsChooserOrigin(openedFrom: .groupsGate(purpose: .createGroup)) == .chooser)
    }
}
