//
//  CloudAttestPanelBannerUITests.swift
//  YalaUITests
//
//  El aviso fijo del canal PERSONAL en el Panel (ticket
//  `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data`).
//
//  **Aquí solo cabe el caso NEGATIVO, y no es una renuncia: es el que protege a todo el mundo.** Ver el aviso exige
//  el device en `storageMode == .cloud`, y no hay seam de uitest que lo ponga —escribir ese modo cambia el montaje
//  del store personal—; es el mismo precedente que ya documenta `SessionExitsPerCellUITests` («la E (nube completa)
//  no tiene seam de `storageMode == .cloud` y la cubre la tabla unitaria»). Lo que sí se puede montar es la
//  población MAYORITARIA: un teléfono con la racha terminal, sesión en la nube y los datos personales en su iCloud
//  privado. A ésa, el aviso le mentiría — su racha puede ser entera de Grupos, y su teléfono no manda un solo
//  movimiento personal a nuestro servidor.
//
//  **Qué mata a este caso, MEDIDO y no supuesto** (2026-09-15, tras añadir el cuarto término). El aviso tiene DOS
//  condiciones sobre el canal —`personalDataLivesInCloud` (`storageMode == .cloud`) y `channelIsStable`
//  (`uiState == .cloudActive`)— y en este simulador las dos son falsas, así que **tumbar una sola deja el caso en
//  verde**: con `personalDataLivesInCloud: true` el XCUI pasó igual. Lo que lo pone rojo es tumbar **las dos**
//  (exit 65, verificado). O sea: este caso protege a la población `.icloud` contra que el aviso deje de gatear por
//  el canal ENTERO, y no fija cuál de los dos términos lo hace. Quién fija cada uno por separado: la tabla de
//  `CloudAttestNoticeLogicTests` y el source-scan de `CloudAttestNoticeWiringTests`, que sí los distinguen.
//
//  **La racha se siembra por el camino de PRODUCCIÓN**: `-uitest-groups-attest-terminal` escribe tres rechazos con
//  relojes separados (`GroupsAttestStreakStore.recordRejection`) y deja que `GroupsAttestVerdictLogic` decida. Un
//  seam que forzara `isTerminal = true` dejaría ciego a este caso (`.claude/rules/testing.md`).
//
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, a11y ids).
//

import XCTest

final class CloudAttestPanelBannerUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// El id va en el CONTENEDOR del aviso y lo heredan sus textos, así que se consulta por cualquier tipo de
    /// descendiente — mismo molde que `groups_attest_terminal_banner`.
    private func banner(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["panel_attest_terminal_banner"].firstMatch
    }

    /// **Con los datos personales en el iCloud privado, no hay aviso** — aunque el veredicto sea cierto y la sesión
    /// en la nube esté viva. Es la población de casi todo el mundo hoy: un falso positivo aquí le diría a cada
    /// usuario de iCloud que su teléfono no sincroniza, encima de un Panel que sincroniza perfectamente.
    func test_attestTerminal_withPersonalDataOnICloud_hidesNotice() {
        let app = XCUIApplication()
        // Sin tocar el modo de almacenamiento: el default del simulador es `.icloud`, que es justo la mitad que
        // discrimina. La racha y la sesión SÍ se siembran, para que la ausencia del aviso signifique algo — una
        // aserción negativa sobre un input que ya la garantiza no prueba nada.
        app.launchForUITest(seed: "minimal", cloudSession: true, groupsAttestTerminal: true)

        // Se espera a que el Panel REAL monte antes de afirmar la ausencia: sobre una pantalla a medio cargar, la
        // ausencia se cumpliría sola. `panel_quick_actions` está dentro del mismo `VStack` que el aviso y justo
        // debajo del hero, así que su presencia prueba que la pila ya se pintó.
        let quickActions = app.descendants(matching: .any)["panel_quick_actions"].firstMatch
        XCTAssertTrue(
            quickActions.waitForExistence(timeout: 30),
            "El Panel no llegó a montar su fila de acciones; la ausencia del aviso no mediría nada."
        )

        XCTAssertFalse(
            banner(in: app).exists,
            """
            `panel_attest_terminal_banner` salió con los datos personales en el iCloud privado: el Panel anuncia \
            que unos movimientos no llegan a una cuenta en la nube que este teléfono no usa para lo personal.
            """
        )
    }
}
