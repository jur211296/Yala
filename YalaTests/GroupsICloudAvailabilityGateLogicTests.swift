//
//  GroupsICloudAvailabilityGateLogicTests.swift
//  YalaTests
//
//  Tabla completa del gate "Grupos necesita iCloud" (molde GroupsBetaGateLogicTests).
//

import Testing

@testable import Yala

@Suite("GroupsICloudAvailabilityGateLogic · gate por cuenta iCloud")
struct GroupsICloudAvailabilityGateLogicTests {

    @Test func sinCuenta_fueraDeUITest_muestraElGate() {
        #expect(GroupsICloudAvailabilityGateLogic.shouldShowGate(
            isAccountAvailable: false, isUITest: false
        ) == true)
    }

    @Test func conCuenta_noMuestraElGate() {
        #expect(GroupsICloudAvailabilityGateLogic.shouldShowGate(
            isAccountAvailable: true, isUITest: false
        ) == false)
    }

    /// Exención uitest: el sim no tiene cuenta y los XCUITests de Grupos lanzan sin
    /// `-uitest-fake-icloud` — sin esto, el gate los interceptaría a todos.
    @Test func sinCuenta_enUITest_exento() {
        #expect(GroupsICloudAvailabilityGateLogic.shouldShowGate(
            isAccountAvailable: false, isUITest: true
        ) == false)
    }

    @Test func conCuenta_enUITest_noMuestraElGate() {
        #expect(GroupsICloudAvailabilityGateLogic.shouldShowGate(
            isAccountAvailable: true, isUITest: true
        ) == false)
    }
}
