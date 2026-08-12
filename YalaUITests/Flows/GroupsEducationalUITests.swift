//
//  GroupsEducationalUITests.swift
//  YalaUITests
//
//  C2 · **la red determinista del PRIMER escalón de las cuatro puertas de Grupos.**
//
//  El educativo era, medido, inalcanzable desde XCUITest: `GroupsContainerView.evaluateGroupsOnboarding`
//  abre con `if UITestHooks.isActive { return }` («interceptaría taps») y `qa/coverage-index.json` ya
//  anotaba el hueco. C2 lo convierte en el paso 1 de la cadena, así que dejarlo sin cobertura habría hecho
//  nacer sin red justo la pieza nueva. El seam `-uitest-groups-educativo` invierte ese early-return **solo
//  para las corridas que lo piden**: el resto de la suite de Grupos sigue con el sheet desmontado, que es
//  por lo que el early-return existe.
//
//  Lo que estos casos NO cubren, y no se busque: la cadena completa desde el Welcome (educativo → login →
//  consent → alta) necesita una sesión de nube REAL, imposible en simulador. Eso es device-qa; aquí se
//  afirma que el educativo se MONTA cuando toca, que su marca lo retira, y que el cierre convierte.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, a11y ids).
//

import XCTest

final class GroupsEducationalUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// El educativo se monta al entrar al tab sin haberlo visto nunca, y llega hasta su cierre.
    ///
    /// **Se aterriza por DEEPLINK y NO con `groupInvite: true`, y eso es la medición del chip.** Ese arg
    /// deja la app en modo solo-grupos CON el onboarding ya marcado, que es exactamente el término LEGACY
    /// de `hasSeenAnyGroupsEducational`: «quien completó su alta en modo Grupos antes de C2 vio su
    /// educativo y no dejó marca». Con él, el educativo NO debe salir — y no sale (verificado: los dos
    /// casos fallaban así). Lo que este test necesita es un usuario que de verdad no lo haya visto.
    ///
    /// El deeplink además es la única forma fiable de llegar al tab en iOS 27: ningún swipe sintético
    /// materializa la card de `LazyVGrid` que lleva a Grupos (regla medida en `testing.md`).
    func test_educational_mountsOnFirstVisit_andReachesItsLastStep() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, deeplink: "groups", groupsEducativo: true)
        // Convención del repo: esperar la señal, jamás un sleep. El educativo lo monta el `onAppear` del
        // tab, que llega DESPUÉS del bootstrap; sin este anclaje el primer caso de la corrida mide el
        // arranque en vez del comportamiento (medido: fallaba solo el primero en ejecutarse).
        XCTAssertTrue(app.waitForUITestReady(), "La app no llegó a `uitest_ready`.")

        let cta = app.buttons["groups_onboarding_cta"]
        XCTAssertTrue(
            cta.waitForExistence(timeout: 30),
            """
            El educativo no se montó al entrar al tab sin haberlo visto. Con el seam puesto es el PRIMER
            escalón: si no aparece, la cadena entera empieza pidiendo identidad sin haber contado nada.
            """
        )

        // Tres steps: dos «Continuar» y el cierre. Se avanza por el id del CTA, que es estable en los tres.
        cta.tap()
        XCTAssertTrue(cta.waitForExistence(timeout: 5), "El educativo no avanzó al step 2.")
        cta.tap()
        XCTAssertTrue(cta.waitForExistence(timeout: 5), "El educativo no avanzó al step 3.")
    }

    /// **El cierre CONVIERTE (A1), y con el copy honesto de C2.** Sin sesión de nube el último step ofrece
    /// además el CTA de identidad — que para quien nunca tuvo cuenta dice «crear», no «iniciar sesión».
    /// Que el botón exista es lo que este caso afirma; el copy exacto lo fija la tabla de
    /// `GroupsOnboardingLogic` y la revisión humana contra BRAND-VOICE.
    func test_educational_lastStep_offersIdentityCTA_whenNoSession() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, deeplink: "groups", groupsEducativo: true)
        // Convención del repo: esperar la señal, jamás un sleep. El educativo lo monta el `onAppear` del
        // tab, que llega DESPUÉS del bootstrap; sin este anclaje el primer caso de la corrida mide el
        // arranque en vez del comportamiento (medido: fallaba solo el primero en ejecutarse).
        XCTAssertTrue(app.waitForUITestReady(), "La app no llegó a `uitest_ready`.")

        let cta = app.buttons["groups_onboarding_cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 30), "El educativo no se montó.")
        cta.tap()
        XCTAssertTrue(cta.waitForExistence(timeout: 5), "El educativo no avanzó al step 2.")
        cta.tap()

        let identityCTA = app.buttons["groups_onboarding_signin_cta"]
        XCTAssertTrue(
            identityCTA.waitForExistence(timeout: 5),
            """
            El cierre del educativo no ofrece el CTA de identidad. Sin sesión y con el canal ON debe
            hacerlo (`GroupsOnboardingLogic.shouldShowSignInCTA`): es la conversión del paso A1.
            """
        )
    }

    /// La otra dirección, y la que impide que el seam se lea como «el educativo sale siempre»: **sin el
    /// arg, el early-return sigue puesto**. Si alguien «simplifica» quitándolo, el sheet interceptaría los
    /// taps de toda la suite de Grupos — que es exactamente el fallo que ese early-return previene, y por
    /// el que el seam INVIERTE en vez de retirar.
    func test_educational_staysUnmounted_withoutTheSeam() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "La app no llegó a `uitest_ready`.")

        // Sin educativo visto, el empty state de debajo es el suyo: `needsEducational`. Que sea ESE y no
        // otro es lo que ancla la aserción negativa — sin el anclaje, «no existe» se cumpliría igual
        // durante el arranque y el test no probaría nada.
        XCTAssertTrue(
            app.descendants(matching: .any)["groups_empty_state_educational"].firstMatch
                .waitForExistence(timeout: 30),
            "El tab de Grupos no llegó a montar su empty state."
        )
        XCTAssertFalse(
            app.buttons["groups_onboarding_cta"].exists,
            "El educativo se montó SIN el seam: interceptará los taps del resto de la suite de Grupos."
        )
    }
}
