//
//  TestProcessGuardTests.swift
//  YalaTests
//
//  El pin de `TestProcessGuard`. SON DOS MITADES Y NINGUNA CUBRE A LA OTRA:
//
//   · Comportamiento — que capturar y restaurar deja el almacén como estaba, con "ausente"
//     distinguido de "presente". Se ejercita con un `UserDefaults` de juguete porque el guard real
//     ya capturó al cargar el bundle y no se puede re-armar sin pisar la captura viva.
//   · Cableado — que el bundle DECLARA este tipo como `NSPrincipalClass` y que el `init` arma de
//     verdad. Sin esto, borrar `INFOPLIST_KEY_NSPrincipalClass` del `.pbxproj` deja el guard sin
//     ejecutarse NUNCA y los tests de comportamiento siguen todos en VERDE: es exactamente el modo
//     de fallo que este fichero existe para impedir, y el mismo de `AttestWiringTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Protección de proceso del espejo del widget", .serialized)
struct TestProcessGuardTests {

    // MARK: - Comportamiento

    @Test func restore_devuelveLosValoresQueHabiaAntes() throws {
        let store = makeIsolatedDefaults(prefix: "test.processguard.valores")
        store.set(Data("blob".utf8), forKey: "widget_data_cache")
        store.set(5, forKey: "firstWeekday")
        store.set("thisMonth", forKey: "defaultPeriod")

        let snapshot = TestProcessGuard.capture(from: store)

        // Lo que hace un test cualquiera al pasar por un ViewModel.
        store.set(Data("basura-de-test".utf8), forKey: "widget_data_cache")
        store.set(2, forKey: "firstWeekday")
        store.set("allTime", forKey: "defaultPeriod")

        TestProcessGuard.restore(snapshot, into: store)

        #expect(store.data(forKey: "widget_data_cache") == Data("blob".utf8))
        #expect(store.integer(forKey: "firstWeekday") == 5)
        #expect(store.string(forKey: "defaultPeriod") == "thisMonth")
    }

    /// `widget_data_cache` AUSENTE no es lo mismo que vacío: restaurar un `nil` con `set(nil)`
    /// dejaría la clave escrita y el widget leería un blob que nadie puso.
    @Test func restore_devuelveAusenteAAusente() throws {
        let store = makeIsolatedDefaults(prefix: "test.processguard.ausente")

        let snapshot = TestProcessGuard.capture(from: store)
        for key in TestProcessGuard.protectedKeys { store.set("escrito-por-un-test", forKey: key) }
        TestProcessGuard.restore(snapshot, into: store)

        for key in TestProcessGuard.protectedKeys {
            #expect(store.object(forKey: key) == nil, "«\(key)» quedó escrita en el App Group.")
        }
    }

    /// Las CUATRO, no una. Si alguien recorta la lista, el espejo vuelve a filtrar por la que falte.
    /// La cuarta (`widget_session_seal`) la publican las fronteras M1, no `saveSnapshot`.
    @Test func protege_lasCuatroClavesDelEspejoDelWidget() {
        #expect(Set(TestProcessGuard.protectedKeys) == [
            "widget_data_cache", "firstWeekday", "defaultPeriod", "widget_session_seal",
        ])
    }

    // MARK: - Cableado

    /// La mitad que carga el peso. El guard no lo invoca ningún test: lo invoca XCTest al cargar el
    /// bundle, y esa instrucción vive en el `.pbxproj`. Si desaparece de ahí —o el nombre ObjC
    /// deja de casar— el guard no corre jamás y NADA más lo detecta.
    @Test func elBundleDeclaraEsteTipoComoPrincipalClass() throws {
        let pbxproj = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // YalaTests/
            .deletingLastPathComponent()      // repo
            .appending(path: "Yala.xcodeproj/project.pbxproj")
        let source = try String(contentsOf: pbxproj, encoding: .utf8)

        let declaraciones = source
            .components(separatedBy: "INFOPLIST_KEY_NSPrincipalClass = YalaTestProcessGuard;")
            .count - 1
        // Las CUATRO configuraciones del target (Debug, Release, Debug-Dev, Release-Dev): con una
        // sola puesta, el guard se cae en las corridas de las otras y el hueco es invisible.
        #expect(
            declaraciones == 4,
            """
            El bundle de YalaTests declara `NSPrincipalClass = YalaTestProcessGuard` en \
            \(declaraciones) configuraciones y deben ser 4. Sin la key, XCTest no instancia el \
            guard, `atexit` no se registra y el espejo del App Group (`widget_data_cache`, \
            `firstWeekday`, `defaultPeriod`) vuelve a quedarse sucio tras cada corrida — con TODOS \
            los tests de comportamiento de esta suite en verde.
            """
        )

        // Y que el nombre ObjC del tipo siga siendo ese: el `.pbxproj` referencia un string.
        let guardSource = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appending(path: "TestProcessGuard.swift"),
            encoding: .utf8)
        #expect(
            guardSource.contains("@objc(YalaTestProcessGuard)"),
            "El nombre ObjC del guard cambió: el `NSPrincipalClass` del `.pbxproj` ya no resuelve."
        )
    }

    /// Que el `init` ARME, y no solo exista. Si alguien vacía el `init`, el principal class se
    /// instancia igual y no captura nada.
    @Test func elInitArmaLaProteccion() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appending(path: "TestProcessGuard.swift"),
            encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        // Acotado al CUERPO del `init`, y no «del `init` hasta el final del fichero»: medido, esa
        // primera versión NO caía al vaciar el `init`, porque `armForCurrentProcess()` sigue
        // apareciendo más abajo en su propia DEFINICIÓN. Un escáner que busca un símbolo en un
        // rango demasiado ancho comprueba que el símbolo existe, no que alguien lo llame.
        let initStart = try #require(
            source.range(of: "override init() {"),
            "El escáner no encontró el `init` del guard — se movió o se renombró.")
        let afterInit = source[initStart.upperBound...]
        let initEnd = try #require(
            afterInit.range(of: "\n    }"),
            "El escáner no encontró el cierre del `init`.")
        let initBody = afterInit[..<initEnd.lowerBound]
        #expect(
            initBody.contains("armForCurrentProcess()"),
            "El `init` del principal class ya no arma la protección: quedaría decorativo."
        )
        #expect(
            source.contains("atexit {"),
            "`armForCurrentProcess` ya no registra el `atexit`: se captura y no se restaura nunca."
        )
    }
}
