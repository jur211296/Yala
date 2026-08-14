//
//  TestProcessGuard.swift
//  YalaTests
//
//  Protección de PROCESO del espejo del App Group que escribe `WidgetDataCache`.
//
//  POR QUÉ NO UN TRAIT, que es el mecanismo de al lado (`SharedStateIsolation`). Un trait protege
//  las suites que lo DECLARAN, y aquí el escritor no vive en los tests: `WidgetDataCache.saveSnapshot`
//  escribe tres claves del App Group REAL —`widget_data_cache`, `firstWeekday`, `defaultPeriod`— y
//  lo invocan ~15 ViewModels de PRODUCCIÓN. El inventario por sonda KVO del 2026-08-05 dio **12
//  suites que ensucian el espejo y solo 3 con trait**, y esa lista crece con cada test que ejercite
//  un ViewModel. Repartir traits sería el juego del topo, y su pin envejecería igual que la lista
//  enumerada de `cadaSuiteQueEnsuciaLlevaSuTrait` — que se escribió con dos suites y para el mismo
//  día ya iban tres. ⇒ la unidad correcta aquí es el PROCESO, no la suite.
//
//  CÓMO SE ENGANCHA, y por qué es esta vía y no otra. Hace falta correr ANTES del primer test y
//  DESPUÉS del último. Swift no soporta `+load` para clases Swift y Swift Testing no expone ningún
//  hook de inicio de proceso, así que un `@Suite` que "ordene primero" no es una garantía: las
//  suites corren en paralelo aunque se pase `-parallel-testing-enabled NO`. Lo que sí es
//  determinista es el `NSPrincipalClass` del bundle de tests, que XCTest instancia al cargarlo,
//  antes de descubrir un solo caso — **medido**: con la key puesta, el `init` corre y se ve en el
//  log. La salida va por `atexit`, que corre al terminar el runner con normalidad.
//
//  LÍMITE CONOCIDO, dicho aquí para que nadie lo confunda con una garantía: si el proceso MUERE
//  (crash, `SIGKILL`, el watchdog del simulador) `atexit` no corre y el espejo se queda sucio. Es
//  estrictamente mejor que no tener nada —hoy se queda sucio SIEMPRE— pero no es transaccional.
//

import Foundation

@testable import Yala

@objc(YalaTestProcessGuard)
final class TestProcessGuard: NSObject {

    /// Las TRES que escribe `WidgetDataCache.saveSnapshot` (`WidgetDataCache.swift`), no una: además
    /// del blob de la caché espeja dos preferencias que lee el widget. `firstWeekday` la barre
    /// ADEMÁS `DataWipeService.resetAllUserPreferences`, así que está protegida por los dos lados —
    /// el trait cubre a quien ejecuta el wipe, esto cubre a quien pasa por un ViewModel.
    ///
    /// La CUARTA es el sello de sesión (`WidgetSessionSeal.activeSealKey`), y entra por la misma puerta
    /// aunque su escritor sea otro: `WidgetDataCache.republishActiveSeal` lo publica desde las fronteras
    /// M1, así que cualquier test que ejercite un hook de frontera con el seam REAL lo dejaría escrito.
    /// Y su fuga es peor que la de las otras tres: un sello huérfano en el App Group del simulador hace
    /// que el widget de un arranque MANUAL descarte su propio snapshot y se vea vacío sin explicación.
    nonisolated static let protectedKeys = [
        "widget_data_cache", "firstWeekday", "defaultPeriod", WidgetSessionSeal.activeSealKey,
    ]

    /// El estado capturado al cargar el bundle. `nonisolated(unsafe)` porque lo escribe una vez el
    /// `init` del principal class y lo lee una vez el `atexit`, sin concurrencia entre medias.
    nonisolated(unsafe) private static var captured: [(key: String, value: Any?)] = []

    nonisolated override init() {
        super.init()
        Self.armForCurrentProcess()
    }

    // MARK: - Piezas puras (las que ejercita el pin)

    /// Guarda "ausente" distinguido de "presente con valor": restaurar un `nil` con `set(nil)`
    /// dejaría la clave escrita, y `widget_data_cache` ausente no es lo mismo que vacío.
    nonisolated static func capture(from store: UserDefaults) -> [(key: String, value: Any?)] {
        protectedKeys.map { ($0, store.object(forKey: $0)) }
    }

    nonisolated static func restore(_ snapshot: [(key: String, value: Any?)], into store: UserDefaults) {
        for (key, value) in snapshot {
            if let value {
                store.set(value, forKey: key)
            } else {
                store.removeObject(forKey: key)
            }
        }
    }

    // MARK: - Cableado al proceso

    nonisolated static func armForCurrentProcess() {
        guard let appGroup = UserDefaults(suiteName: SharedContainerService.appGroupIdentifier) else { return }
        captured = capture(from: appGroup)
        atexit { TestProcessGuard.restoreForCurrentProcess() }
    }

    nonisolated static func restoreForCurrentProcess() {
        guard let appGroup = UserDefaults(suiteName: SharedContainerService.appGroupIdentifier) else { return }
        restore(captured, into: appGroup)
    }
}
