//
//  InboxNewItemsModalUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `inbox-new-items-modal` (escenarios 26.x): el
//  InboxAlertModal que normalmente dispara el sync de CloudKit. El hook
//  `-uitest-inbox-alert` encola `.showInboxAlert` con un payload de muestra tras
//  el seed (mismo path que el sync real), volviendo el modal determinista.
//  GOTCHA: el modal es un fullScreenCover que cubre el root → NO usar
//  waitForUITestReady (el uitest_ready queda tapado); esperar el botón del modal.
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class InboxNewItemsModalUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// El InboxAlertModal se presenta con el payload simulado por el hook.
    func test_inboxAlertModalPresentsOnLaunch() {
        let app = XCUIApplication()
        app.launchForUITest(inboxAlert: true)

        // El modal cubre el root → esperar su CTA directo (no uitest_ready).
        XCTAssertTrue(
            app.buttons["inbox_alert_view"].waitForExistence(timeout: 30),
            "No se presentó el InboxAlertModal (inbox_alert_view ausente)."
        )
        // El botón de descartar también está presente.
        XCTAssertTrue(
            app.buttons["inbox_alert_dismiss"].exists,
            "El modal no expone el botón de descartar (inbox_alert_dismiss)."
        )
    }

    /// Descartar el modal deja el Panel INTERACTUABLE (no solo visible).
    func test_inboxAlertModalDismisses() {
        let app = XCUIApplication()
        app.launchForUITest(inboxAlert: true)

        // Esperar a que bootstrap+seed terminen ANTES de descartar. El cover tapa el root
        // VISUALMENTE, pero la jerarquía de accesibilidad sigue expuesta (comprobado: con el cover
        // presente, `fab_new_transaction` ya se resuelve), así que `uitest_ready` sí se puede
        // esperar aquí. Importa porque descartar mientras el arranque sigue en curso es lo que deja
        // el cover pegado.
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let dismiss = app.buttons["inbox_alert_dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 30), "No apareció inbox_alert_dismiss.")
        dismiss.tap()

        // Tras descartar, el Panel debe quedar INTERACTUABLE.
        //
        // Lo que este test protege es el bug «toolbar muerta» de TestFlight 2.0.5: que el cover no
        // deje una capa fantasma que se coma los taps y vuelva la app inservible. Antes se afirmaba
        // eso indirectamente, esperando a que `inbox_alert_view` dejara de existir — es decir,
        // cronometrando el DESMONTAJE del `fullScreenCover`. Eso medía lo que no importa y lo hacía
        // en el reloj de SwiftUI/UIKit, que la app no controla: matriz 2×2 del 2026-07-28
        // (n=5/celda, 20 corridas, 0 descartadas por infraestructura) → iOS 26.4.1 0 % de fallo con
        // el caso en 8,6 s clavados, iOS 27.0 30 % con el mismo caso en 17-51 s. El propio
        // `test_inboxAlertModalPresentsOnLaunch`, que NO descarta nada, pasa de 6,4 s a 12,3 s en
        // 27.0: la lentitud es del runtime, no de este flujo.
        //
        // Así que se afirma la propiedad de verdad: el Panel vuelve a responder. Si el cover queda
        // pegado, ningún reintento consigue nada y esto es rojo — que es exactamente el bug 2.0.5.
        // Se tapea la píldora `panel_action_new` de la fila del hero, NO el FAB flotante. Desde
        // a4445a26 (2026-09-02) el flotante no está montado con el Panel arriba del todo, y aquí
        // no se puede bajar a buscarlo: el scroll es un GESTO, y si el cover se come los gestos
        // —que es exactamente el bug que este test caza— el rojo saldría como «no apareció el
        // FAB», culpando al rediseño en vez de al cover. La píldora está visible desde el primer
        // fotograma y abre el formulario directamente, sin menú intermedio, así que mide el tap
        // y solo el tap. Un cambio de vehículo, no de propiedad.
        let nuevoRegistro = app.buttons["panel_action_new"]
        XCTAssertTrue(
            nuevoRegistro.waitForExistence(timeout: 30),
            "No se descubrió el Panel tras cerrar el modal."
        )
        // El tap se REINTENTA, y esa es la parte que importa: `allowsHitTesting(false)` impide que
        // el backdrop capture el tap para sí, pero NO hace que el tap atraviese hasta el Panel —
        // mientras el cover sigue montado él es la vista presentada y se lo come. Así que un único
        // tap inmediato se PIERDE (medido: el Panel ya se resuelve 1,9 s tras el dismiss, pero no
        // responde; con el tap único el caso falla incluso esperando 120 s, porque no hay nada que
        // esperar). Reintentar hasta que responda afirma la propiedad de verdad —el Panel vuelve a
        // estar vivo— sin cronometrar el desmontaje.
        let amount = app.textFields["new_transaction_amount"]
        var responded = false
        for _ in 0..<10 {
            if amount.exists { responded = true; break }
            nuevoRegistro.tap()
            if amount.waitForExistence(timeout: 4) { responded = true; break }
        }
        XCTAssertTrue(
            responded,
            "El Panel no responde a NINGÚN tap tras cerrar el modal (cover pegado — bug 2.0.5)."
        )
    }
}
