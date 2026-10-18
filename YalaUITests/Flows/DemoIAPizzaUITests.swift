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
//  Idioma: es-MX por defecto (lo que corre el CI). El vídeo de la ficha de cada idioma lo graba con
//  `TEST_RUNNER_YALA_DEMO_IDIOMA=en` o `=pt-BR` (xcodebuild quita el prefijo `TEST_RUNNER_`): semilla `ficha`, la
//  región y la divisa de esa ficha y lo que se escribe en ese idioma (`DemoIdioma`).
//

import XCTest

final class DemoIAPizzaUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// El idioma de la demo, de `YALA_DEMO_IDIOMA`; sin él, es-MX.
    private let idioma = DemoIdioma.actual

    /// Lo que se escribe en el chat. El perfil `pizza` contesta siempre lo mismo; esto es lo que se ve teclear.
    private var typedText: String { idioma.typedText }

    func test_registrarPizzaConYalaIA() {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true,
            seed: idioma.seed,
            deeplink: "records",
            aiChatReady: true,
            appleLanguages: idioma.appleLanguages,
            appleLocale: idioma.appleLocale,
            extraArguments: [
                "-uitest-chat-suggestions",
                "-uitest-chat-reply", "pizza",
                "-defaultCurrencyCode", idioma.currency,
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

        // 5 · La card del gasto: Pizza · su importe (280 pesos, 28 dólares, 90 reales) · Restaurantes, lista para registrar.
        let save = app.buttons["chat_draft_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 15), "Yala IA no contestó con la card del gasto.")
        let card = app.buttons["chat_draft_row"]
        XCTAssertTrue(card.exists, "Falta la fila de la card.")
        XCTAssertTrue(card.label.contains("Pizza"), "La card no dice Pizza: «\(card.label)».")
        XCTAssertTrue(card.label.contains(idioma.amount), "La card no trae el importe \(idioma.amount): «\(card.label)».")
        XCTAssertTrue(card.label.contains(idioma.restaurants), "La card no va a \(idioma.restaurants): «\(card.label)».")
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
        XCTAssertTrue(app.staticTexts[idioma.savedBadge].waitForExistence(timeout: 5), "La card no dice «\(idioma.savedBadge)».")
        marca("registrado")
        pausa(2.0)

        // 7 · Cerrar el chat: el gasto ya está en Registros.
        let close = app.buttons["chat_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Falta el botón de cerrar Yala IA.")
        close.tap()
        let row = pizzaRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "El gasto de la pizza no aparece en Registros.")
        XCTAssertTrue(row.label.contains(idioma.amount), "La fila de Registros no trae el importe \(idioma.amount): «\(row.label)».")
        XCTAssertTrue(row.label.contains(idioma.restaurants), "La fila de Registros no va a \(idioma.restaurants): «\(row.label)».")
        marca("registros")
        pausa(2.5)

        marca("fin")
    }

    // MARK: - Idioma

    /// Lo que cambia por idioma. `es-MX` es el de siempre; `en` y `pt-BR`, los del vídeo de la ficha 2.1, con su semilla
    /// en la divisa de la ficha. Las etiquetas (`restaurants`, `savedBadge`) son las de la app en ese idioma.
    struct DemoIdioma {
        let seed: String
        let appleLanguages: String
        let appleLocale: String
        let currency: String
        let typedText: String
        /// El importe que escribe y que contesta Yala IA (`DevSeedFicha.Cifras.pizza` de esa divisa).
        let amount: String
        let restaurants: String
        /// `chat.draft.savedBadge` de ese idioma. Era «Registrado» hasta los lotes 3 y 4 de la auditoría UX 2.2.
        let savedBadge: String

        static let esMX = DemoIdioma(
            seed: "ficha-mx-vida", appleLanguages: "(es-MX)", appleLocale: "es_MX", currency: "MXN",
            typedText: "Pizza con amigos 280", amount: "280", restaurants: "Restaurantes", savedBadge: "Guardado")
        static let en = DemoIdioma(
            seed: "ficha", appleLanguages: "(en-US)", appleLocale: "en_US", currency: "USD",
            typedText: "Pizza with friends 28", amount: "28", restaurants: "Restaurants", savedBadge: "Saved")
        static let ptBR = DemoIdioma(
            seed: "ficha", appleLanguages: "(pt-BR)", appleLocale: "pt_BR", currency: "BRL",
            typedText: "Pizza com os amigos 90", amount: "90", restaurants: "Restaurantes", savedBadge: "Salvo")

        static var actual: DemoIdioma {
            switch ProcessInfo.processInfo.environment["YALA_DEMO_IDIOMA"] {
            case "en": return .en
            case "pt-BR": return .ptBR
            default: return .esMX
            }
        }
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
