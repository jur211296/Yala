//
//  AppLanguageStateIsolationTests.swift
//  YalaTests
//
//  El pin de `AppLanguageStateIsolation`. SON DOS MITADES Y NINGUNA CUBRE A LA OTRA:
//
//   · Comportamiento — que el scope restaura de verdad, incluso cuando el cuerpo lanza. Se ejercita
//     `withAppLanguageStateIsolated` directamente porque un `Test` no se puede construir a mano, así
//     que el `provideScope` del trait es inalcanzable desde aquí.
//   · Cableado (source-scan) — que `AppLanguageSyncTests` LLEVA el trait y que el trait DELEGA en esa
//     función. Sin esto, quitar `.appLanguageStateIsolated` del `@Suite` devolvería la fuga entera
//     con el test de comportamiento en verde: exactamente el modo de fallo que este fichero existe
//     para impedir.
//

import Foundation
import Testing

@testable import Yala

@Suite("Aislamiento del estado de idioma", .serialized, .appLanguageStateIsolated)
@MainActor
struct AppLanguageStateIsolationTests {

    private static let sentinelKey = AppLanguageStateSnapshot.migrationSentinelKey

    /// Almacenes de juguete: `UserDefaults` de verdad, en suites con UUID, para que el pin ejercite
    /// el mismo tipo que corre en producción y no un fake que podría divergir.
    private func makeFakeStores() -> AppLanguageStores {
        AppLanguageStores(
            shared: makeIsolatedDefaults(prefix: "test.lang.shared"),
            standard: makeIsolatedDefaults(prefix: "test.lang.standard"),
            ubiquitous: makeIsolatedDefaults(prefix: "test.lang.ikv")
        )
    }

    // MARK: - Comportamiento

    @Test func scope_devuelveClavesAusentesAAusentes() async throws {
        let stores = makeFakeStores()
        let key = LanguageManager.overrideKey

        try await withAppLanguageStateIsolated(in: stores) {
            stores.shared.set("de", forKey: key)
            stores.shared.set(true, forKey: Self.sentinelKey)
            stores.standard.set("pt", forKey: key)
            stores.ubiquitous.set("fr", forKey: key)
        }

        #expect(stores.shared.object(forKey: key) == nil, "El override quedó escrito en el App Group.")
        #expect(stores.shared.object(forKey: Self.sentinelKey) == nil, "El centinela de migración quedó escrito.")
        #expect(stores.standard.object(forKey: key) == nil, "El override quedó escrito en .standard.")
        #expect(stores.ubiquitous.object(forKey: key) == nil, "El override quedó escrito en iCloud KV.")
    }

    @Test func scope_devuelveLosValoresQueHabiaAntes() async throws {
        let stores = makeFakeStores()
        let key = LanguageManager.overrideKey
        stores.shared.set("es-419", forKey: key)
        stores.shared.set(true, forKey: Self.sentinelKey)
        stores.standard.set("legacy", forKey: key)
        stores.ubiquitous.set("en", forKey: key)

        try await withAppLanguageStateIsolated(in: stores) {
            stores.shared.set("de", forKey: key)
            stores.shared.removeObject(forKey: Self.sentinelKey)
            stores.standard.set("pt", forKey: key)
            stores.ubiquitous.set("fr", forKey: key)
        }

        #expect(stores.shared.object(forKey: key) as? String == "es-419")
        #expect(stores.shared.object(forKey: Self.sentinelKey) as? Bool == true)
        #expect(stores.standard.object(forKey: key) as? String == "legacy")
        #expect(stores.ubiquitous.object(forKey: key) as? String == "en")
    }

    /// El centinela es `Bool`, no `String`: `false` presente y ausente son estados DISTINTOS, y
    /// restaurar `false` como "quitar la clave" re-dispararía la migración en el siguiente arranque.
    @Test func scope_distingueCentinelaFalseDeCentinelaAusente() async throws {
        let stores = makeFakeStores()
        stores.shared.set(false, forKey: Self.sentinelKey)

        try await withAppLanguageStateIsolated(in: stores) {
            stores.shared.set(true, forKey: Self.sentinelKey)
        }

        #expect(stores.shared.object(forKey: Self.sentinelKey) as? Bool == false)
        #expect(stores.shared.object(forKey: Self.sentinelKey) != nil, "`false` no es lo mismo que ausente.")
    }

    /// La entrada se normaliza: si no, el setter de `overrideLanguage` (no-op cuando el valor no
    /// cambia) haría fallar por el entorno a los tests que esperan la notificación.
    @Test func scope_limpiaElEstadoAntesDeEjecutarElCuerpo() async throws {
        let stores = makeFakeStores()
        let key = LanguageManager.overrideKey
        stores.shared.set("de", forKey: key)
        stores.standard.set("de", forKey: key)
        stores.ubiquitous.set("de", forKey: key)

        var vistoDentro: [String?] = []
        try await withAppLanguageStateIsolated(in: stores) {
            vistoDentro = [
                stores.shared.object(forKey: key) as? String,
                stores.standard.object(forKey: key) as? String,
                stores.ubiquitous.object(forKey: key) as? String,
            ]
        }

        #expect(vistoDentro == [nil, nil, nil], "El cuerpo vio estado de una corrida anterior.")
        #expect(stores.shared.object(forKey: key) as? String == "de", "La limpieza no debe comerse la restauración.")
    }

    /// El modo de fallo que tenía el fichero original en `:147`: la limpieza escrita al final del
    /// cuerpo no corre cuando un `#expect` falla antes.
    @Test func scope_restauraAunqueElCuerpoLance() async throws {
        struct Boom: Error {}
        let stores = makeFakeStores()
        let key = LanguageManager.overrideKey
        stores.shared.set("es-419", forKey: key)

        await #expect(throws: Boom.self) {
            try await withAppLanguageStateIsolated(in: stores) {
                stores.shared.set("de", forKey: key)
                throw Boom()
            }
        }

        #expect(stores.shared.object(forKey: key) as? String == "es-419")
    }

    /// El mismo contrato contra los almacenes REALES (App Group incluido), que son los que filtran.
    /// Lo protege el trait de esta suite: el scope externo restaura lo que este test deja.
    @Test func scope_restauraLosAlmacenesReales() async throws {
        let stores = AppLanguageStores.live
        let key = LanguageManager.overrideKey
        stores.shared.set("es-419", forKey: key)
        stores.shared.set(true, forKey: AppLanguageStateSnapshot.migrationSentinelKey)

        try await withAppLanguageStateIsolated(in: stores) {
            LanguageManager.overrideLanguage = "de"
            LanguageManager.bootstrapMigrationIfNeeded()
        }

        #expect(
            stores.shared.object(forKey: key) as? String == "es-419",
            "El App Group real quedó con el idioma del test — el siguiente XCUITest arranca en ese idioma."
        )
    }

    // MARK: - Cableado (source-scan)

    /// Los conteos esperados no son decoración: sin ellos, un fichero movido o un símbolo renombrado
    /// dejarían al escáner sin encontrar nada y la suite pasaría en verde sin comprobar nada.
    @Test func elCableadoDelTraitSigueEnSuSitio() throws {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        // Las líneas de comentario van fuera: el porqué se explica ahí nombrando estos mismos
        // símbolos, y contar prosa haría que documentar el invariante lo rompiera.
        func code(of fileName: String) throws -> String {
            try String(contentsOf: testsDir.appending(path: fileName), encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
        }

        let suite = try code(of: "AppLanguageSyncTests.swift")
        let applied = suite.components(separatedBy: ".appLanguageStateIsolated").count - 1
        #expect(
            applied == 1,
            """
            AppLanguageSyncTests ya no declara `.appLanguageStateIsolated` (\(applied) apariciones). \
            Sin el trait, sus tests vuelven a dejar `appLanguageOverride` en el App Group real y el \
            siguiente XCUITest arranca la app en otro idioma.
            """
        )

        // Declaración + la llamada de `provideScope`. Si el trait se vacía, baja a 1.
        let trait = try code(of: "AppLanguageStateIsolation.swift")
        let delegations = trait.components(separatedBy: "withAppLanguageStateIsolated").count - 1
        #expect(
            delegations == 2,
            "Se esperaban la declaración del scope y su uso en `provideScope`, hay \(delegations)."
        )
    }
}
