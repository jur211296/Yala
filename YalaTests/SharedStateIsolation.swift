//
//  SharedStateIsolation.swift
//  YalaTests
//
//  Punto ÚNICO de setup/teardown para los tests que escriben en almacenes COMPARTIDOS —los que
//  sobreviven al proceso y comparten los dos hosts del scheme `Yala Dev` (mismo bundle
//  `…yala.dev`): el App Group, `UserDefaults.standard` e iCloud KV.
//
//  POR QUÉ NO SON SUITES AISLADAS. Sería lo preferible —no ensuciar gana a limpiar lo que se
//  ensucia—, pero en estos casos no se puede: el SUT resuelve el almacén por dentro y no acepta
//  inyección. `LanguageManager.bootstrapMigrationIfNeeded()` va a `sharedDefaults`
//  (`L10n.swift:129`) y `LastUsedAccountStore.read()` a `WidgetURLHelper.appGroupIdentifier`
//  (`QuickExpenseIntent.swift:325-329`). Un suite aislado no ejercitaría lo que estos tests
//  existen para probar. ⇒ tocan el almacén REAL y hay que restaurarlo.
//
//  POR QUÉ UN TRAIT Y NO UN `defer` POR TEST. Un `defer` es correcto y se olvida.
//  `AppLanguageSyncTests` tenía 9 tests y 3 `defer`, y los 4 de migración dejaban el override
//  puesto: correr la suite dejaba `appLanguageOverride = de` en `group.com.jurgenschmidt.yala.dev`
//  y, como `/gate` corre los unitarios ANTES que los XCUITest, el siguiente XCUITest arrancaba la
//  app en ALEMÁN con un rojo que no menciona el idioma. `ApplePayDraftServiceTests` era peor de
//  leer: su docblock prometía limpiar «en `init` y en `deinit`» y es un `struct`, que **no puede
//  tener `deinit`** — la garantía no existía y nadie lo notó en ninguna revisión. Declarado en el
//  `@Suite`, el trait cubre también a todo test que se añada mañana.
//
//  EL SCOPE LIMPIA LA ENTRADA, no solo restaura la salida. Es lo que hace que un test no dependa
//  de lo que dejó la corrida anterior en el simulador, y lo que permite borrar los `removeObject`
//  de los `init()`: el setter de `overrideLanguage` es no-op si el valor no cambia
//  (`guard newValue != current`), así que un simulador que ya viniera con "fr" hacía fallar
//  `setOverride_postsLanguageDidChange` por el entorno y no por el código.
//
//  ORDEN MEDIDO (2026-08-05), porque la respuesta intuitiva era la contraria: **el scope envuelve
//  TAMBIÉN la construcción del tipo de suite**, así que el `init()` corre DESPUÉS del capture y del
//  clear. Verificado por mutación, no por lectura: con el trait puesto y el `removeObject` de vuelta
//  en el `init()` de `ApplePayDraftServiceTests`, un centinela plantado a mano en el App Group
//  SOBREVIVE a los 17 tests; quitando además el trait —el estado original— DESAPARECE. ⇒ lo que
//  causaba la fuga era la ausencia de restauración, y el borrado del `init()` es **redundante** con
//  el clear, no dañino por sí mismo.
//
//  Aun así los `init()` se dejaron sin tocar estado compartido, y conviene que siga así: esa
//  inocuidad depende POR COMPLETO de que nadie quite el trait, y el borrado a mano es justo el
//  patrón que se copia a la siguiente suite que alguien escriba.
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

/// Una celda de estado compartido: dónde vive un valor y con qué nombre.
struct SharedStateCell {
    let store: any KeyValueStoring
    let key: String
    /// Solo para los mensajes de fallo — "App Group", "standard", "iCloud KV".
    let storeLabel: String

    init(_ store: any KeyValueStoring, _ key: String, _ storeLabel: String) {
        self.store = store
        self.key = key
        self.storeLabel = storeLabel
    }
}

/// Qué protege cada trait.
///
/// Enum y no un closure de celdas para que el trait salga `Sendable` sin trucos (`TestScoping` lo
/// exige); las celdas se resuelven en `MainActor` al entrar en el scope.
///
/// **Cada celda se resuelve por el MISMO camino que el código que la escribe**, no por el que
/// resulte más corto: idioma vía `LanguageManager.sharedDefaults`, última-cuenta vía
/// `WidgetURLHelper.appGroupIdentifier`. Hoy los dos resuelven al mismo suite —lo pinnea
/// `StoreKitManagerAppGroupTests.appGroupResolvers_coinciden`— y si algún día divergen, cada celda
/// seguirá protegiendo el sitio que de verdad se ensucia.
enum SharedStateScope: Sendable {
    /// El idioma in-app. Cuatro celdas, no una: el override viaja además por `.standard` (origen
    /// legacy de la migración) y por iCloud KV, y `PreferenceSyncService` re-aplica el de iKV al
    /// App Group (`:366-383`) ⇒ limpiar solo el App Group deja la puerta de atrás abierta.
    case appLanguage
    /// La última cuenta usada, que `ApplePayDraftService` lee para elegir cuenta al materializar
    /// la cola de Apple Pay.
    case lastUsedAccount

    /// El espejo del App Group que barre `DataWipeService.resetAllUserPreferences()`
    /// (`DataWipeService.swift:401-404`) — TRES claves, no una. Le llega cualquier test que ejecute
    /// `wipeAllUserData` de verdad (`:195`, PASO 2, incondicional), y esos tests protegían solo
    /// `UserDefaults.standard` con snapshot/restore del dominio: el App Group quedaba fuera.
    case wipeAppGroupMirror

    @MainActor
    var cells: [SharedStateCell] {
        switch self {
        case .appLanguage:
            let shared = LanguageManager.sharedDefaults
            return [
                SharedStateCell(shared, LanguageManager.overrideKey, "App Group"),
                // El centinela es `private` en `LanguageManager`, así que aquí va por literal. Si
                // allí se renombra, `bootstrapMigration_emptyStandardAndSuite_setsSentinel` cae antes.
                SharedStateCell(shared, SharedStateScope.migrationSentinelKey, "App Group"),
                SharedStateCell(UserDefaults.standard, LanguageManager.overrideKey, "standard"),
                SharedStateCell(NSUbiquitousKeyValueStore.default, LanguageManager.overrideKey, "iCloud KV"),
            ]
        case .lastUsedAccount:
            guard let appGroup = UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier) else { return [] }
            return [SharedStateCell(appGroup, AppPreferences.Keys.lastUsedAccountID, "App Group")]

        case .wipeAppGroupMirror:
            // `SharedContainerService`, que es por donde lo resuelve `DataWipeService`. Hoy coincide
            // con `WidgetURLHelper` —lo pinnea `StoreKitManagerAppGroupTests.appGroupResolvers_coinciden`—
            // y si algún día divergen, cada celda seguirá protegiendo el sitio que de verdad se ensucia.
            guard let appGroup = UserDefaults(suiteName: SharedContainerService.appGroupIdentifier) else { return [] }
            return [
                SharedStateCell(appGroup, AppPreferences.Keys.expensesOnlyMode, "App Group"),
                SharedStateCell(appGroup, "firstWeekday", "App Group"),
                SharedStateCell(appGroup, AppPreferences.Keys.lastUsedAccountID, "App Group"),
            ]
        }
    }

    static let migrationSentinelKey = "appLanguageOverrideMigratedV1"
}

// MARK: - Snapshot

/// Estado de N celdas, con "ausente" distinguido de "presente con valor" — restaurar un `nil` como
/// `set(nil)` dejaría la clave escrita.
///
/// Guarda el objeto tal cual lo devuelve `object(forKey:)`, sin tiparlo: así un `Bool` sigue siendo
/// `Bool` al volver (el centinela de migración lo es, y `false` presente y ausente son estados
/// DISTINTOS: confundirlos re-dispara la migración).
struct SharedStateSnapshot {
    private let captured: [(cell: SharedStateCell, value: Any?)]

    static func capture(_ cells: [SharedStateCell]) -> Self {
        Self(captured: cells.map { ($0, $0.store.object(forKey: $0.key)) })
    }

    /// Deja cada celda exactamente como la encontró `capture`.
    func restore() {
        for (cell, value) in captured {
            if let value {
                cell.store.set(value, forKey: cell.key)
            } else {
                cell.store.removeObject(forKey: cell.key)
            }
        }
    }

    /// Borra las celdas — entrada determinista, independiente de lo que dejara la corrida anterior.
    static func clear(_ cells: [SharedStateCell]) {
        for cell in cells { cell.store.removeObject(forKey: cell.key) }
    }
}

// MARK: - Serialización entre suites

/// Marca de "ya estoy dentro de un scope" para que un scope ANIDADO no vuelva a pedir el turno y se
/// espere a sí mismo. `@TaskLocal` porque se hereda por las tareas hijas, que es como Swift Testing
/// encadena un trait con el siguiente y con el cuerpo del test.
enum SharedStateSerialization {
    @TaskLocal static var isInsideScope = false
}

/// Turno global para TODOS los scopes de estado compartido.
///
/// **POR QUÉ EXISTE, medido el 2026-08-05.** `.serialized` ordena los tests DENTRO de una suite,
/// pero Swift Testing corre suites DISTINTAS en paralelo aunque se pase `-parallel-testing-enabled NO`
/// (está en la regla de testing). Dos scopes que solapan una celda se pisan al restaurar:
///
///   A captura `true` → A limpia → B captura AUSENTE (lo que dejó A) → B limpia
///   → A restaura `true` → B restaura AUSENTE  ⇒ **gana B y el valor se pierde.**
///
/// No es teoría: con DOS suites usando el scope de idioma, `appLanguageOverrideMigratedV1`
/// sobrevivía a la corrida completa; al añadir la tercera (`LocaleResolutionTests`) desaparecía.
/// Aislar cada suite por su cuenta NO basta — hace falta que los scopes no se solapen en el tiempo.
actor SharedStateGate {
    static let shared = SharedStateGate()

    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        while busy {
            await withCheckedContinuation { waiters.append($0) }
        }
        busy = true
    }

    func release() {
        busy = false
        if !waiters.isEmpty { waiters.removeFirst().resume() }
    }
}

// MARK: - Scope

/// Turno → captura → limpia → ejecuta → restaura → cede el turno. Es la función que ejercita el pin
/// de comportamiento (`SharedStateIsolationTests`): un `Test` no se puede construir a mano, así que
/// el trait delega aquí en vez de llevar la lógica dentro.
@MainActor
func withSharedStateIsolated(
    cells: [SharedStateCell],
    perform body: () async throws -> Void
) async throws {
    // Anidado (una suite con dos traits, o un test que abre su propio scope dentro del de su suite):
    // el turno ya es nuestro. Volver a pedirlo sería esperarse a uno mismo.
    guard !SharedStateSerialization.isInsideScope else {
        try await runIsolated(cells: cells, perform: body)
        return
    }

    await SharedStateGate.shared.acquire()
    do {
        try await SharedStateSerialization.$isInsideScope.withValue(true) {
            try await runIsolated(cells: cells, perform: body)
        }
    } catch {
        await SharedStateGate.shared.release()
        throw error
    }
    await SharedStateGate.shared.release()
}

@MainActor
private func runIsolated(
    cells: [SharedStateCell],
    perform body: () async throws -> Void
) async throws {
    let snapshot = SharedStateSnapshot.capture(cells)
    SharedStateSnapshot.clear(cells)
    do {
        try await body()
    } catch {
        // La restauración NO puede depender de que el test pase: un `#expect` que falla lanza, y
        // una limpieza escrita al final del cuerpo se la salta.
        snapshot.restore()
        throw error
    }
    snapshot.restore()
}

@MainActor
func withSharedStateIsolated(
    _ scope: SharedStateScope,
    perform body: () async throws -> Void
) async throws {
    try await withSharedStateIsolated(cells: scope.cells, perform: body)
}

/// Trait de suite: envuelve cada test con `withSharedStateIsolated`.
struct SharedStateIsolation: SuiteTrait, TestTrait, TestScoping {
    let scope: SharedStateScope

    /// Recursivo para que aplique a los tests contenidos y no solo a la suite.
    var isRecursive: Bool { true }

    /// El `@concurrent` del closure es parte de la firma que pide `TestScoping`. Este target
    /// compila con `nonisolated(nonsending)` por defecto y el módulo `Testing` no, así que sin
    /// anotarlo el parámetro se infiere `nonisolated(nonsending)` y el conformance no casa — con un
    /// error que señala al protocolo, no al parámetro.
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @concurrent @Sendable () async throws -> Void
    ) async throws {
        try await withSharedStateIsolated(scope) {
            try await function()
        }
    }
}

extension Trait where Self == SharedStateIsolation {
    /// Aísla el idioma in-app (App Group, `.standard`, iCloud KV).
    static var appLanguageStateIsolated: Self { Self(scope: .appLanguage) }
    /// Aísla `lastUsedAccountID` del App Group.
    static var lastUsedAccountIsolated: Self { Self(scope: .lastUsedAccount) }
    /// Aísla las tres claves del App Group que barre un `wipeAllUserData` real.
    static var wipeAppGroupMirrorIsolated: Self { Self(scope: .wipeAppGroupMirror) }
}
