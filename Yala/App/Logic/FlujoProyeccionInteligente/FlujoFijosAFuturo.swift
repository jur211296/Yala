//
//  FlujoFijosAFuturo.swift
//  Yala
//
//  «Considerar a futuro» de la hoja de no considerados (decisión de Jürgen del 19-nov-2026, 10:47: «si veo que hay 1000
//  soles considerados en compras, poder decir no consideres eso a futuro»): las partidas fijas que la persona apagó y que
//  ya no se proyectan en los meses que vienen. Lo leen el flujo de caja, el Panel, Tendencias y el widget de Saldo por el
//  mismo cálculo (`CashFlowProjectionCalculator.calculate`), así que dan la misma cifra.
//
//  Se guarda en ESTE dispositivo (preferencia local, `UserDefaults`), con la clave estable de cada fijo
//  (`FlujoProyeccionInteligente.Fijo.claveEstable`). No viaja a otro teléfono: es una decisión del Paso 0 del encargo,
//  anotada como límite. Se borra con el resto de preferencias al vaciar los datos.
//

import Foundation

enum FlujoFijosAFuturo {

    static let defaultsKey = "cashFlow.futureExcludedFixed"

    #if DEBUG
    /// Los tests de paridad fijan aquí un almacén aislado: el Panel, el widget y Tendencias leen sin parámetro.
    nonisolated(unsafe) static var _testDefaults: UserDefaults?
    #endif

    private static var almacen: UserDefaults {
        #if DEBUG
        if let _testDefaults { return _testDefaults }
        #endif
        return .standard
    }

    /// Las claves apagadas.
    static func excluidos(defaults: UserDefaults? = nil) -> Set<String> {
        Set((defaults ?? almacen).stringArray(forKey: defaultsKey) ?? [])
    }

    /// Lo olvida todo (al reiniciar el plan).
    static func olvidarTodo(defaults: UserDefaults? = nil) {
        (defaults ?? almacen).removeObject(forKey: defaultsKey)
    }

    /// Enciende o apaga una partida. Devuelve el conjunto que queda guardado.
    @discardableResult
    static func considerar(_ clave: String, _ considerar: Bool, defaults: UserDefaults? = nil) -> Set<String> {
        let defaults = defaults ?? almacen
        var actuales = excluidos(defaults: defaults)
        if considerar { actuales.remove(clave) } else { actuales.insert(clave) }
        if actuales.isEmpty {
            defaults.removeObject(forKey: defaultsKey)
        } else {
            defaults.set(actuales.sorted(), forKey: defaultsKey)
        }
        return actuales
    }
}
