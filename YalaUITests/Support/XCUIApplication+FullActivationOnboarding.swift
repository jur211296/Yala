//
//  XCUIApplication+FullActivationOnboarding.swift
//  YalaUITests
//
//  Bienvenida 2.3 (Y23-04): el alta de la bienvenida es la conversación de tres preguntas, y `-uitest-onboarding` la
//  monta a ella. El onboarding de ocho pasos (`OnboardingView`) sigue vivo en «Activar Yala completo»
//  (`FullModeActivationView`), y sus XCUITest entran por ahí.
//
//  Camino (molde de `FullModeActivationChooserUITests.launchGroupsOnlyAndOpenTheActivation`): sesión solo-grupos
//  (`groupInvite`) → Ajustes → «Activar Yala completo». Sin `-uitest-cloud-chooser` ni App Attest fingido,
//  `WelcomeNewOptionsGate.live` deja solo la opción privada: la activación hace bypass a la puerta de iCloud, que bajo
//  XCUITest deja pasar, y llega al onboarding.
//
//  Qué pasos salen (`OnboardingStepPlan.skippedSteps` con el resumen de `FullModeActivationLogic.buildSummary`): el
//  nombre sale porque `-uitest-reset` borra `userName`; las categorías se saltan si la semilla dejó categorías propias;
//  la divisa se salta si el grupo más reciente o la preferencia dan una (por eso la esperan condicional quienes la
//  cruzan).
//

import XCTest

extension XCUIApplication {

    /// Lanza una sesión solo-grupos, abre «Activar Yala completo» y espera el primer paso del onboarding (nombre).
    func launchIntoFullActivationOnboarding(file: StaticString = #filePath, line: UInt = #line) {
        launchForUITest(groupInvite: true)
        XCTAssertTrue(waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.", file: file, line: line)
        openProfile()
        let activate = buttons["profile_activate_full_yala"]
        XCTAssertTrue(activate.waitForExistence(timeout: 10),
                      "No apareció «Activar Yala completo» en el Perfil de un usuario solo-grupos.", file: file, line: line)
        activate.tap()
        XCTAssertTrue(textFields["onboarding_name_field"].waitForExistence(timeout: 30),
                      "«Activar Yala completo» no llegó al paso de nombre del onboarding.", file: file, line: line)
    }
}
