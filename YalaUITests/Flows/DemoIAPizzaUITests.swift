//
//  DemoIAPizzaUITests.swift
//  YalaUITests
//
//  Demo grabada de marketing: «registrar una pizza con Yala IA», de principio a fin. Abre Yala IA desde Registros,
//  escribe «Pizza con amigos 280» a ritmo de persona, Yala IA contesta con la card del gasto, se registra y el gasto
//  aparece en Registros.
//
//  Es un test de verdad (la card trae Pizza · 280 · Restaurantes y el gasto llega a la lista) y a la vez el guion de
//  un vídeo: las pausas existen para que cada momento se lea en pantalla, y en cada uno imprime una marca
//  `DEMO-MARCA:<id> t=<segundos desde 1970>` que el script de grabación de marketing lee de la salida de
//  `xcodebuild` para cortar y sacar capturas. El `t=` es el reloj del Mac (el simulador comparte reloj), así que no
//  depende de cuándo llegue la línea a la salida.
//
//  Sin red ni producción: semilla `ficha-mx-vida` (vida personal en MXN), sugerencias fijas
//  (`-uitest-chat-suggestions`) y la respuesta del chat fingida por `-uitest-chat-reply pizza`, que contesta por el
//  mismo camino que una respuesta real.
//

import XCTest

final class DemoIAPizzaUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Lo que se escribe en el chat. El perfil `pizza` contesta siempre lo mismo; esto es lo que se ve teclear.
    private let typedText = "Pizza con amigos 280"

    func test_registrarPizzaConYalaIA() {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true,
            seed: "ficha-mx-vida",
            deeplink: "records",
            aiChatReady: true,
            appleLanguages: "(es-MX)",
            appleLocale: "es_MX",
            extraArguments: [
                "-uitest-chat-suggestions",
                "-uitest-chat-reply", "pizza",
                "-defaultCurrencyCode", "MXN",
            ]
        )
        // Un año de vida personal tarda más en sembrarse que la semilla mínima.
        XCTAssertTrue(app.waitForUITestReady(timeout: 180), "uitest_ready ausente — bootstrap/seed no completó.")

        // 1 · Registros, con la entrada de Yala IA a la vista.
        let chatEntry = app.buttons["fab_chat"]
        XCTAssertTrue(chatEntry.waitForExistence(timeout: 20), "No aparece la entrada de Yala IA en Registros.")
        XCTAssertTrue(
            app.buttons.matching(identifier: "record_row").firstMatch.waitForExistence(timeout: 20),
            "Registros no enseña ningún movimiento de la semilla."
        )
        XCTAssertFalse(pizzaRow(in: app).exists, "La semilla no debe traer ya una pizza: el gasto lo crea la demo.")
        marca("inicio")
        pausa(2.0)

        // 2 · Yala IA abierto, vacío.
        chatEntry.tap()
        let input = app.textFields["chat_input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10), "No se abrió Yala IA.")
        XCTAssertTrue(
            app.buttons.matching(identifier: "chat_suggestion").firstMatch.waitForExistence(timeout: 10),
            "El chat vacío no enseña las sugerencias."
        )
        marca("chat-abierto")
        pausa(1.8)

        // 3 · Escribir, letra a letra.
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "No salió el teclado.")
        marca("escribiendo")
        for character in typedText {
            input.typeText(String(character))
        }
        XCTAssertEqual(input.value as? String, typedText, "La caja no tiene lo que se escribió.")
        pausa(1.2)

        // 4 · Enviar: el mensaje entra en el hilo y Yala IA «piensa».
        let send = app.buttons["chat_send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5), "Con texto, debe salir enviar.")
        send.tap()
        let sentMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", typedText)).firstMatch
        XCTAssertTrue(sentMessage.waitForExistence(timeout: 5), "El mensaje enviado no aparece en el hilo.")
        marca("enviado")

        // 5 · La card del gasto: Pizza · 280 · Restaurantes, lista para registrar.
        let save = app.buttons["chat_draft_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 15), "Yala IA no contestó con la card del gasto.")
        let card = app.buttons["chat_draft_row"]
        XCTAssertTrue(card.exists, "Falta la fila de la card.")
        XCTAssertTrue(card.label.contains("Pizza"), "La card no dice Pizza: «\(card.label)».")
        XCTAssertTrue(card.label.contains("280"), "La card no trae el importe 280: «\(card.label)».")
        XCTAssertTrue(card.label.contains("Restaurantes"), "La card no va a Restaurantes: «\(card.label)».")
        XCTAssertTrue(save.isEnabled, "La card completa debe poder registrarse.")
        marca("tarjeta")
        pausa(3.0)

        // 6 · Registrar: la card se queda en su sitio con su ✓.
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10), "Tras registrar, la card sigue pidiendo guardar.")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Pizza")).firstMatch.exists,
            "Tras registrar, la fila de la pizza desapareció del chat."
        )
        XCTAssertTrue(app.staticTexts["Registrado"].waitForExistence(timeout: 5), "La card no dice «Registrado».")
        marca("registrado")
        pausa(2.0)

        // 7 · Cerrar el chat: el gasto ya está en Registros.
        let close = app.buttons["chat_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Falta el botón de cerrar Yala IA.")
        close.tap()
        let row = pizzaRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "El gasto de la pizza no aparece en Registros.")
        XCTAssertTrue(row.label.contains("280"), "La fila de Registros no trae el importe 280: «\(row.label)».")
        XCTAssertTrue(row.label.contains("Restaurantes"), "La fila de Registros no va a Restaurantes: «\(row.label)».")
        marca("registros")
        pausa(2.5)

        marca("fin")
    }

    // MARK: - Ayudas

    /// La fila de Registros del gasto que crea la demo. Su etiqueta empieza por la nota (`RecordRowView`).
    private func pizzaRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons
            .matching(identifier: "record_row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Pizza,"))
            .firstMatch
    }

    /// Marca para el montaje: una línea en la salida de `xcodebuild` en cuanto el estado está en pantalla. Se vacía
    /// stdout en el acto para que la línea no espere al búfer.
    private func marca(_ id: String) {
        print(String(format: "DEMO-MARCA:%@ t=%.3f", id, Date().timeIntervalSince1970))
        fflush(stdout)
    }

    /// Pausa de vídeo: deja el momento quieto para que se lea. En un test normal sería un sleep frágil; aquí ES el
    /// producto, y siempre va DESPUÉS de esperar al estado, nunca en su lugar.
    private func pausa(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
