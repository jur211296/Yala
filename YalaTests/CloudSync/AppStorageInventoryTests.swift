//
//  AppStorageInventoryTests.swift
//  YalaTests / CloudSync
//
//  **El inventario de `@AppStorage` de los tres ficheros que los declaran, y por qué sobrevive a su
//  suite original.**
//
//  Nació dentro de `SessionDefaultsWiringTests` como uno más de los escáneres de cableado de la puerta
//  de dominio por sesión (M1). Esa puerta se retiró el 2026-09-12 —`SessionDefaults.current`,
//  `resolve` y `sessionSuite` ya no existen— y con ella murieron los otros doce de sus trece escáneres: todos
//  comprobaban que un consumidor llamara a un símbolo que hoy no está. Éste NO: cuenta declaraciones de
//  `@AppStorage`, que siguen existiendo y siguen teniendo una consecuencia.
//
//  **Lo que la retirada SÍ le cambió es el porqué.** Antes, un `@AppStorage` nuevo heredaba el store de
//  la raíz (`YalaApp` fijaba `.defaultAppStorage`) y por eso había que clasificarlo. Hoy todos leen
//  `UserDefaults.standard` directamente, así que lo que el conteo protege es el inventario de
//  `SessionPreferenceKeys`: una key nueva sin clasificar deja un hueco en lo que el barrido de datos
//  del usuario conoce. Cuando `SessionPreferenceKeys` caiga con el resto de M1, este test se re-decide
//  con él — no antes, y no en silencio.
//

import Foundation
import Testing

@testable import Yala

private let repo: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

/// El código de un fichero SIN comentarios de línea: estos ficheros explican sus invariantes en prosa
/// y nombran los símbolos al hacerlo. Contar la prosa haría que documentar un invariante lo rompiera
/// — pasó ya en este repo con el escáner de los seams de `-uitest`.
private func appStorageCode(_ path: String) -> String {
    let url = repo.appendingPathComponent(path)
    guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return "" }
    return raw.split(separator: "\n", omittingEmptySubsequences: false)
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        .joined(separator: "\n")
}

@Suite("Inventario de `@AppStorage` (source-scan)")
struct AppStorageInventoryTests {

    static let appStorageFiles = [
        "Yala/App/ContentView.swift",
        "Yala/App/Theme/ViewModifiers.swift",
        "Yala/App/Views/Shared/ContextualGuideBanner.swift",
    ]

    /// **Sin esto, el conteo de abajo puede pasar VACUAMENTE.** Un fichero movido o renombrado hace que
    /// `appStorageCode` devuelva cadena vacía, que da cero declaraciones — y cero nunca sería `== 10`,
    /// pero el mensaje señalaría al sitio equivocado. Esto lo nombra.
    @Test("todo fichero escaneado existe y tiene contenido")
    func everyScannedFileIsReadable() {
        for path in Self.appStorageFiles {
            #expect(!appStorageCode(path).isEmpty, "el escáner no puede leer `\(path)` — ¿se movió o se renombró?")
        }
    }

    @Test("los `@AppStorage` siguen siendo los 10 medidos — uno nuevo obliga a re-decidir")
    func appStorageCountIsPinned() {
        // DOS grafías, como en el inventario de F2: el atributo, y la construcción MANUAL del banner
        // de guías, que no lleva `@` y por eso un escáner anclado a `@AppStorage` la pierde entera.
        var declarations = 0
        for path in Self.appStorageFiles {
            declarations += appStorageCode(path).components(separatedBy: "@AppStorage").count - 1
            declarations += appStorageCode(path).components(separatedBy: "= AppStorage(wrappedValue:").count - 1
        }
        #expect(declarations == 10, """
                hay \(declarations) usos de `@AppStorage`, se esperaban 10. Todos leen \
                `UserDefaults.standard`: comprueba que la key del nuevo esté clasificada en \
                `SessionPreferenceKeys` y actualiza este conteo.
                """)
    }
}
