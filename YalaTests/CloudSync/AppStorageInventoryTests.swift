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
//  **Lo que la retirada SÍ le cambió es el porqué, y este párrafo ES esa re-decisión** (2026-09-13, el
//  barrido de M1). El texto anterior decía: «lo que el conteo protege es el inventario de
//  `SessionPreferenceKeys` … cuando caiga con el resto de M1, este test se re-decide con él — no antes,
//  y no en silencio». Cayó. Y el test habría seguido VERDE midiendo un propósito inexistente, con un
//  mensaje de fallo que mandaba a clasificar la key en un tipo borrado: exactamente el «en silencio»
//  que esa frase quería evitar. Lo cazó una review adversarial leyendo este docblock contra el diff.
//
//  **Lo que el conteo protege HOY.** Un `@AppStorage` es una key de `UserDefaults.standard` escrita
//  desde una vista, fuera de `AppPreferences` — o sea, fuera del sitio donde el barrido de datos del
//  usuario sabe mirar (`DataWipeService.removeUserPreferenceKeys` es una lista LITERAL). Una key nueva
//  ahí sobrevive a «Vaciar datos» y al relevo de humano sin que nadie lo decida. El conteo obliga a
//  pronunciarse: o la key entra en esa lista, o se declara a conciencia que es de DISPOSITIVO y
//  sobrevive a propósito.
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
                `UserDefaults.standard` desde una vista, fuera de `AppPreferences`: decide si la key del \
                nuevo entra en la lista de `DataWipeService.removeUserPreferenceKeys` —o si sobrevive al \
                borrado a propósito, por ser de dispositivo— y actualiza este conteo.
                """)
    }
}
