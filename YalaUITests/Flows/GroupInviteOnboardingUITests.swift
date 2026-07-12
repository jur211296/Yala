//
//  GroupInviteOnboardingUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del onboarding de invitación HONESTO (fix bugs de la
//  corrida real 2026-07-11: "¡Todo listo!" falso sin member). CKShare NO
//  funciona en simulador → el accept real es device-only (guion en el vault);
//  aquí los steps se testean con la fase del GroupJoinIntentTracker CONGELADA
//  vía -uitest-join-phase. Convenciones: sin sleeps, scheme Yala Dev.
//
//  Invariante central (LA regresión): con fase no-active JAMÁS aparece el
//  texto de éxito (invite_ready_title / groups.invite.ready).
//

import XCTest

final class GroupInviteOnboardingUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Lanza el cover de invitación con la fase congelada y tapea "Unirme".
    private func launchAndJoin(phase: String, softTimeout: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            skipOnboarding: false,
            seed: nil,
            inviteOnboarding: true,
            joinPhase: phase,
            joinSoftTimeout: softTimeout
        )
        let join = app.buttons["invite_join_button"]
        XCTAssertTrue(join.waitForExistence(timeout: 30), "No apareció el botón Unirme del invite onboarding.")
        join.tap()
        return app
    }

    /// Fase en progreso → spinner honesto (y NUNCA la pantalla de éxito).
    func test_waitingForZone_showsJoiningSpinner_neverReady() {
        let app = launchAndJoin(phase: "waitingForZone")

        XCTAssertTrue(
            app.descendants(matching: .any)["invite_joining_spinner"].waitForExistence(timeout: 10),
            "No apareció el spinner de 'Conectando con tu grupo'."
        )
        // LA regresión del bug: éxito falso con la zona sin sincronizar.
        XCTAssertFalse(
            app.staticTexts["invite_ready_title"].exists,
            "REGRESIÓN: apareció '¡Todo listo!' sin member confirmado."
        )
    }

    /// Soft-timeout corto → estado "está tardando" con CTA de salida digna,
    /// que aterriza en el tab Grupos con el banner de sync visible.
    func test_softTimeout_showsTakingLong_exitLandsOnGroupsWithBanner() {
        let app = launchAndJoin(phase: "waitingForZone", softTimeout: "2")

        XCTAssertTrue(
            app.staticTexts["invite_slow_title"].waitForExistence(timeout: 15),
            "No apareció el estado 'está tardando' tras el soft-timeout."
        )
        XCTAssertFalse(
            app.staticTexts["invite_ready_title"].exists,
            "REGRESIÓN: apareció '¡Todo listo!' en el estado 'tardando'."
        )

        let exit = app.buttons["invite_slow_continue"]
        XCTAssertTrue(exit.waitForExistence(timeout: 5), "No apareció el CTA de salida.")
        exit.tap()

        // Aterriza en Grupos con la strip "Conectando con tu grupo…".
        XCTAssertTrue(
            app.descendants(matching: .any)["invite_sync_banner"].waitForExistence(timeout: 20),
            "No apareció el banner de sync en el tab Grupos tras salir en 'tardando'."
        )
    }

    /// Fase failed → error real con botón Reintentar (no éxito falso).
    func test_failedPhase_showsRetry() {
        let app = launchAndJoin(phase: "failed")

        XCTAssertTrue(
            app.buttons["invite_retry_button"].waitForExistence(timeout: 10),
            "No apareció el botón Reintentar en el estado de error."
        )
        XCTAssertTrue(
            app.buttons["invite_error_exit"].exists,
            "No apareció la salida secundaria del estado de error."
        )
        XCTAssertFalse(
            app.staticTexts["invite_ready_title"].exists,
            "REGRESIÓN: apareció '¡Todo listo!' en estado de error."
        )
    }

    /// Fase pendingApproval → step de "esperando aprobación" (el estado real
    /// de un invitado: el member nace pendingApproval hasta que el admin apruebe).
    func test_pendingApprovalPhase_showsWaitingStep() {
        let app = launchAndJoin(phase: "pendingApproval")

        XCTAssertTrue(
            app.buttons["invite_pending_continue"].waitForExistence(timeout: 10),
            "No apareció el step de 'esperando aprobación'."
        )
        XCTAssertFalse(
            app.staticTexts["invite_ready_title"].exists,
            "REGRESIÓN: apareció '¡Todo listo!' con member aún pendiente."
        )
    }

    /// Fase active (member confirmado) → SOLO entonces la pantalla de éxito.
    func test_activePhase_showsReady() {
        let app = launchAndJoin(phase: "active")

        XCTAssertTrue(
            app.staticTexts["invite_ready_title"].waitForExistence(timeout: 10),
            "No apareció '¡Todo listo!' con member activo confirmado."
        )
    }
}
