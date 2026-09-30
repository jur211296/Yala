//
//  XCUIApplication+Window.swift
//  YalaUITests
//
//  Estrechar y ensanchar la ventana de Yala en un iPad con «Apps en ventanas» (Ajustes → Multitarea y gestos).
//
//  Todo se hace con los elementos de SpringBoard, que da los marcos en coordenadas de PANTALLA: el de la app
//  (`app.frame`) es local a la ventana y empieza siempre en 0, así que un arrastre calculado con él se sale de la
//  ventana en cuanto no ocupa la pantalla entera. Medido el 2026-09-29 en iOS 27.0:
//
//  - `card:<bundle>:…` es la ventana y su marco en pantalla; arrastrar su esquina inferior derecha la redimensiona.
//  - `resize-grabber` («Redimensionar …») es el asa de la esquina: existe mientras la ventana se puede
//    redimensionar, también a pantalla completa. Con «Apps en pantalla completa» no está.
//  - `window-controls:<bundle>` (solo con la ventana más pequeña que la pantalla) son los tres puntos de arriba a
//    la izquierda. Tocarlos los despliega (cerrar, minimizar, maximizar) y el tercero, a unos 85 pt de su borde izquierdo, devuelve la ventana a pantalla completa.
//    No salen en el árbol una vez desplegados, por eso se toca por coordenada.
//  - La ventana RECUERDA su tamaño entre arranques: un test que la deja estrecha hace que el siguiente arranque
//    estrecho. `maximizeWindow()` lo arregla sin borrar el simulador.
//

import XCTest

extension XCUIApplication {
    private var springboard: XCUIApplication { XCUIApplication(bundleIdentifier: "com.apple.springboard") }

    private var bundleID: String { "com.jurgenschmidt.yala.dev" }

    private var windowCard: XCUIElement {
        springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "card:\(bundleID)")).firstMatch
    }

    private var windowControls: XCUIElement {
        springboard.descendants(matching: .any).matching(identifier: "window-controls:\(bundleID)").firstMatch
    }

    private var screenWidth: CGFloat { XCUIScreen.main.screenshot().image.size.width }

    /// Hay ventanas redimensionables: iPad con «Apps en ventanas». Con «Apps en pantalla completa» o en iPhone,
    /// SpringBoard no pinta el asa de redimensionar.
    var hasResizableWindow: Bool {
        springboard.descendants(matching: .any).matching(identifier: "resize-grabber").firstMatch
            .waitForExistence(timeout: 5)
    }

    /// La ventana ocupa la pantalla entera.
    var windowIsFullScreen: Bool { windowCard.frame.width >= screenWidth - 1 }

    /// Devuelve la ventana a pantalla completa con el botón de maximizar de sus controles.
    func maximizeWindow(file: StaticString = #filePath, line: UInt = #line) {
        guard !windowIsFullScreen else { return }
        let controls = windowControls
        XCTAssertTrue(controls.waitForExistence(timeout: 5), "No aparecen los controles de la ventana.", file: file, line: line)
        controls.tap()
        let c = controls.frame
        springboard.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: c.minX + 85, dy: c.midY))
            .tap()
        XCTAssertTrue(waitForWindow(fullScreen: true), "La ventana no volvió a pantalla completa.", file: file, line: line)
    }

    /// Arrastra la esquina inferior derecha de la ventana hasta dejarla al 40 % de su ancho: la ventana pasa a
    /// compacta (pestañas abajo).
    func narrowWindow(file: StaticString = #filePath, line: UInt = #line) {
        let f = windowCard.frame
        let origin = springboard.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: f.maxX - 4, dy: f.maxY - 4))
            .press(
                forDuration: 0.6,
                thenDragTo: origin.withOffset(CGVector(dx: f.minX + f.width * 0.4, dy: f.maxY - 4)))
        XCTAssertTrue(waitForWindow(fullScreen: false), "La ventana no se estrechó.", file: file, line: line)
    }

    private func waitForWindow(fullScreen: Bool, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate { _, _ in self.windowIsFullScreen == fullScreen }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
