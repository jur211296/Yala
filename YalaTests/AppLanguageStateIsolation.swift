//
//  AppLanguageStateIsolation.swift
//  YalaTests
//
//  Punto ÚNICO de setup/teardown para los tests que tocan el estado de idioma.
//
//  POR QUÉ NO ES UN SUITE AISLADO. Sería lo preferible —no ensuciar gana a limpiar lo que se
//  ensucia—, pero aquí no se puede: el SUT es `LanguageManager.bootstrapMigrationIfNeeded()`, que
//  resuelve `sharedDefaults` internamente (`L10n.swift:129` → `UserDefaults(suiteName:)` del App
//  Group) y no acepta almacén inyectado. Un suite aislado no ejercitaría la migración que estos
//  tests existen para probar. ⇒ toca el almacén REAL y hay que restaurarlo.
//
//  POR QUÉ UN TRAIT Y NO UN `defer` POR TEST. Un `defer` es correcto y se olvida: el fichero tenía
//  9 tests y 3 `defer`, y los 4 de migración dejaban el override puesto (medido el 2026-08-05:
//  correr la suite dejaba `appLanguageOverride = de` en `group.com.jurgenschmidt.yala.dev`). El
//  App Group sobrevive al proceso y el scheme `Yala Dev` lo comparte entre el host de los unit
//  tests y el de los XCUITest ⇒ el siguiente XCUITest arrancaba la app en ALEMÁN y su rojo no
//  mencionaba el idioma. Es el gemelo en dirección inversa de `-uitest-pro`
//  (`UITestProTierIsolationTests`), y la misma lección: el estado global no lo ve el compilador.
//  Declarado en el `@Suite`, el trait cubre también a todo test que se añada mañana.
//
//  QUÉ CUBRE, Y POR QUÉ ESAS CUATRO CELDAS. Las tres puertas por las que el override llega a un
//  arranque posterior de la app, más el centinela que decide la migración:
//    · App Group `appLanguageOverride`          — lo que lee `LanguageManager.resolved` al arrancar.
//    · App Group `appLanguageOverrideMigratedV1` — el centinela; borrarlo re-dispara la migración.
//    · `UserDefaults.standard[appLanguageOverride]` — origen legacy de la migración, y el MISMO
//      almacén para los dos hosts del scheme (mismo bundle `…yala.dev`).
//    · iCloud KV `appLanguageOverride`          — lo escribe el setter (`L10n.swift:59-65`) y
//      `PreferenceSyncService` lo re-aplica al App Group (`:366-383`) ⇒ dejarlo sucio ahí
//      re-contamina por la puerta de atrás aunque el App Group quedara limpio.
//
//  ADEMÁS NORMALIZA LA ENTRADA. El scope limpia las cuatro celdas ANTES de cada test, no solo
//  después: el setter de `overrideLanguage` es no-op si el valor no cambia (`guard newValue !=`),
//  así que un simulador que ya viniera con "fr" haría que `setOverride_postsLanguageDidChange`
//  no recibiera notificación y fallara por el entorno, no por el código.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Almacenes

/// Lo mínimo que necesita el snapshot. `UserDefaults` y `NSUbiquitousKeyValueStore` ya lo cumplen
/// con la firma que tienen, así que los conformances son vacíos.
protocol KeyValueStoring: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: KeyValueStoring {}
extension NSUbiquitousKeyValueStore: KeyValueStoring {}

/// Los tres almacenes compartidos que tocan los tests de idioma.
struct AppLanguageStores {
    let shared: any KeyValueStoring
    let standard: any KeyValueStoring
    let ubiquitous: any KeyValueStoring

    /// Los almacenes REALES. `shared` se resuelve por el mismo camino que producción para que el
    /// snapshot no pueda apuntar a otro sitio que el que ensucian los tests.
    @MainActor
    static var live: Self {
        Self(
            shared: LanguageManager.sharedDefaults,
            standard: UserDefaults.standard,
            ubiquitous: NSUbiquitousKeyValueStore.default
        )
    }
}

// MARK: - Snapshot

/// Estado de las claves de idioma en los almacenes compartidos, con "ausente" distinguido de
/// "presente con valor" — restaurar un `nil` como `set(nil)` dejaría la clave escrita.
struct AppLanguageStateSnapshot: Equatable, Sendable {
    /// El centinela es `private` en `LanguageManager`, así que aquí va por literal. Si allí se
    /// renombra, `bootstrapMigration_emptyStandardAndSuite_setsSentinel` cae primero.
    static let migrationSentinelKey = "appLanguageOverrideMigratedV1"

    var sharedOverride: String?
    var sharedMigrationSentinel: Bool?
    var standardOverride: String?
    var ubiquitousOverride: String?

    static func capture(from stores: AppLanguageStores) -> Self {
        let key = LanguageManager.overrideKey
        return Self(
            sharedOverride: stores.shared.object(forKey: key) as? String,
            sharedMigrationSentinel: stores.shared.object(forKey: migrationSentinelKey) as? Bool,
            standardOverride: stores.standard.object(forKey: key) as? String,
            ubiquitousOverride: stores.ubiquitous.object(forKey: key) as? String
        )
    }

    /// Deja las cuatro celdas exactamente como las encontró `capture`.
    func restore(into stores: AppLanguageStores) {
        let key = LanguageManager.overrideKey
        Self.write(sharedOverride, forKey: key, in: stores.shared)
        Self.write(sharedMigrationSentinel, forKey: Self.migrationSentinelKey, in: stores.shared)
        Self.write(standardOverride, forKey: key, in: stores.standard)
        Self.write(ubiquitousOverride, forKey: key, in: stores.ubiquitous)
    }

    /// Borra las cuatro celdas — entrada determinista, independiente de lo que dejara la corrida
    /// anterior en el simulador.
    static func clear(in stores: AppLanguageStores) {
        let key = LanguageManager.overrideKey
        stores.shared.removeObject(forKey: key)
        stores.shared.removeObject(forKey: migrationSentinelKey)
        stores.standard.removeObject(forKey: key)
        stores.ubiquitous.removeObject(forKey: key)
    }

    private static func write(_ value: Any?, forKey key: String, in store: any KeyValueStoring) {
        if let value {
            store.set(value, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
    }
}

// MARK: - Scope

/// Captura → limpia → ejecuta → restaura. Es la función que ejercita el pin de comportamiento
/// (`AppLanguageStateIsolationTests`): un `Test` no se puede construir a mano, así que el trait
/// delega aquí en vez de llevar la lógica dentro.
@MainActor
func withAppLanguageStateIsolated(
    in stores: AppLanguageStores,
    perform body: () async throws -> Void
) async throws {
    let snapshot = AppLanguageStateSnapshot.capture(from: stores)
    AppLanguageStateSnapshot.clear(in: stores)
    do {
        try await body()
    } catch {
        // La restauración NO puede depender de que el test pase: un `#expect` que falla lanza, y
        // la limpieza escrita al final del cuerpo (como estaba en `:147`) se la salta.
        snapshot.restore(into: stores)
        throw error
    }
    snapshot.restore(into: stores)
}

/// Trait de suite: envuelve cada test con `withAppLanguageStateIsolated`.
struct AppLanguageStateIsolation: SuiteTrait, TestTrait, TestScoping {
    /// Recursivo para que aplique a los tests contenidos y no solo a la suite.
    var isRecursive: Bool { true }

    /// El `@concurrent` del closure es parte de la firma que pide `TestScoping`. Este target
    /// compila con `nonisolated(nonsending)` por defecto y el módulo `Testing` no, así que sin
    /// anotarlo el parámetro se infiere `nonisolated(nonsending)` y el conformance no casa.
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @concurrent @Sendable () async throws -> Void
    ) async throws {
        try await withAppLanguageStateIsolated(in: .live) {
            try await function()
        }
    }
}

extension Trait where Self == AppLanguageStateIsolation {
    /// Aísla el estado de idioma de los almacenes compartidos (App Group, `.standard`, iCloud KV).
    static var appLanguageStateIsolated: Self { Self() }
}
