//
//  UITestProTierIsolationTests.swift
//  YalaTests
//
//  El seam `-uitest-pro` no puede dejar rastro en disco.
//
//  POR QUÉ EXISTE. El scheme `Yala Dev` usa el MISMO bundle (`…yala.dev`) para el host de los
//  XCUITest y para el de los unit tests ⇒ `UserDefaults.standard` y el App Group son el mismo
//  almacén para los dos targets, y sobreviven a la corrida. Hasta el 2026-08-05 `-uitest-pro` se
//  implementaba llamando a `toggleDevProTier()`, que PERSISTE `dev.forceProTier`: correr los
//  XCUITest y después los unitarios dejaba `FeatureGateService.shared.isProUser == true` y ponía en
//  rojo a `ProUpsellServiceOneShotTests`, en un cambio que no tocaba nada de Pro. En el orden
//  inverso pasaba todo, así que el rojo se lee como una regresión del código bajo revisión.
//
//  SON DOS TESTS PORQUE SON DOS MITADES. El de comportamiento prueba que el MÉTODO no persiste;
//  el source-scan prueba que el bootstrap USA ese método. Ninguno cubre al otro: el host de unit
//  tests no lleva `-uitest`, así que el call site real (`applyUITestHooksEarly`) es inalcanzable
//  desde aquí, y un `toggleDevProTier()` que volviera ahí reintroduciría el bug entero con el test
//  de comportamiento en verde.
//

import Foundation
import Testing

@testable import Yala

@Suite("-uitest-pro · seam efímero", .serialized)
@MainActor
struct UITestProTierIsolationTests {

    /// Las cuatro keys de `UserDefaults.standard` que escribía el camino anterior.
    private static let stickyKeys = [
        "dev.forceProTier",   // el que rompía ProUpsellServiceOneShotTests
        "dev.forceFreeTier",  // la otra cara del toggle (rama OFF)
        "yala.wasProUser",    // sucia ⇒ `justDowngraded` en el siguiente launch SIN el arg
        "chatFABVisible",     // se escribía a `true`, que ya es el default de AppPreferences
    ]

    /// Ejercita el método REAL sobre el singleton REAL, partiendo de un simulador YA contaminado
    /// (que es el estado en el que quedaron todos los que corrieron la versión anterior).
    @Test func applyUITestProTier_noDejaRastroEnUserDefaults() {
        let defaults = UserDefaults.standard
        let appGroup = UserDefaults(suiteName: SharedContainerService.appGroupIdentifier)

        let previous = Self.stickyKeys.map { ($0, defaults.object(forKey: $0)) }
        let previousAppGroup = appGroup?.object(forKey: AppPreferences.Keys.isProUser)
        defer {
            // Orden load-bearing: apagar PRIMERO (vuelve a purgar) y restaurar DESPUÉS, o la
            // restauración se perdería. Deja además el singleton sin Pro para el resto del proceso.
            StoreKitManager.shared.applyUITestProTier(false)
            for (key, value) in previous {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
            if let previousAppGroup {
                appGroup?.set(previousAppGroup, forKey: AppPreferences.Keys.isProUser)
            } else {
                appGroup?.removeObject(forKey: AppPreferences.Keys.isProUser)
            }
        }

        for key in Self.stickyKeys {
            defaults.set(true, forKey: key)
        }

        StoreKitManager.shared.applyUITestProTier(true)

        #expect(StoreKitManager.shared.isProUser, "El seam tiene que fijar Pro en memoria.")
        for key in Self.stickyKeys {
            #expect(
                defaults.object(forKey: key) == nil,
                "«\(key)» sobrevivió al seam de uitest — vuelve a contaminar al host de unit tests."
            )
        }
    }

    /// El pin del CALL SITE. `expected` no es decoración: sin él, un método renombrado o un fichero
    /// movido dejarían el escáner sin encontrar nada y la suite pasaría en verde sin comprobar nada.
    @Test func bootstrapCablaElSeamEfimero_yNoElTogglePersistente() throws {
        let bootstrapper = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
            .appending(path: "Yala/App/AppBootstrapper.swift")

        // Sin las líneas de comentario: el porqué del seam se explica AHÍ nombrando los dos
        // métodos, y contar prosa haría que documentar el invariante lo rompiera.
        let source = try String(contentsOf: bootstrapper, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        let applications = source.components(separatedBy: "applyUITestProTier(").count - 1
        #expect(applications == 1, "Se esperaba exactamente 1 aplicación del seam efímero, hay \(applications).")

        let toggles = source.components(separatedBy: "toggleDevProTier(").count - 1
        #expect(
            toggles == 0,
            """
            AppBootstrapper vuelve a llamar a toggleDevProTier(): eso PERSISTE `dev.forceProTier` y \
            reintroduce el rojo de ProUpsellServiceOneShotTests tras correr los XCUITest.
            """
        )
    }
}
