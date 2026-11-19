//
//  FlujoFijosAFuturo.swift
//  Yala
//
//  «Considerar a futuro» de la hoja de no considerados (decisión de Jürgen del 19-nov-2026, 10:47: «si veo que hay 1000
//  soles considerados en compras, poder decir no consideres eso a futuro»): las partidas fijas que la persona apagó y que
//  ya no se proyectan en los meses que vienen. Lo leen el flujo de caja, el Panel, Tendencias y el widget de Saldo por el
//  mismo cálculo (`CashFlowProjectionCalculator.calculate`), así que dan la misma cifra.
//
//  Viaja entre teléfonos (decisión de Jürgen del 19-nov-2026, 14:04): es una preferencia sincronizada,
//  `PrefSyncKey.cashFlowFutureExcludedFixed`, por el mismo canal que el diseño de las tarjetas o el estilo del perfil:
//  iCloud clave-valor con los datos en iCloud, la tabla de preferencias del Modo Nube con los datos en la nube. Ninguno de
//  los dos pide un despliegue: el servidor guarda clave/valor de texto. Se eligió frente a un campo en `CashFlowPlan`, que
//  pedía esquema nuevo en CloudKit Production, una columna en Supabase y un Worker nuevo.
//
//  El valor es una lista JSON ordenada con la clave estable de cada fijo (`FlujoProyeccionInteligente.Fijo.claveEstable`):
//  la clave puede llevar nombres con comas. `""` = nada apagado, y volver a encenderlo todo también viaja.
//
//  Hasta este cambio se guardaba solo en este teléfono, como lista (`cashFlow.futureExcludedFixed`). La lectura une esa
//  lista vieja mientras exista, para que nada apagado vuelva a proyectarse; y `migrarLoLocalSiHaceFalta`, al arrancar,
//  la sube al canal y la retira.
//

import Foundation

enum FlujoFijosAFuturo {

    /// La preferencia sincronizada (`PrefSyncKey.cashFlowFutureExcludedFixed`).
    static let defaultsKey = PrefSyncKey.cashFlowFutureExcludedFixed.rawValue
    /// La lista local de antes de sincronizar (19-nov-2026, mañana). Solo se lee para migrarla.
    static let legacyDefaultsKey = "cashFlow.futureExcludedFixed"

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

    /// Quién guarda el valor nuevo. En la app, el canal de preferencias (que además lo escribe en local); con un almacén
    /// pasado o de test, solo ese almacén: un test no encola preferencias ni toca el iCloud clave-valor del simulador.
    private static func publicar(_ valor: String, defaults: UserDefaults?) {
        if let defaults {
            defaults.set(valor, forKey: defaultsKey)
            return
        }
        #if DEBUG
        if let _testDefaults {
            _testDefaults.set(valor, forKey: defaultsKey)
            return
        }
        #endif
        PreferenceSyncService.shared.set(string: valor, forKey: defaultsKey)
    }

    // MARK: - Lectura

    /// Las claves apagadas: las de la preferencia sincronizada más las de la lista vieja que aún no se migró.
    static func excluidos(defaults: UserDefaults? = nil) -> Set<String> {
        let store = defaults ?? almacen
        return decodificar(store.string(forKey: defaultsKey))
            .union(store.stringArray(forKey: legacyDefaultsKey) ?? [])
    }

    // MARK: - Escritura

    /// Lo olvida todo (al reiniciar el plan). Viaja: los otros teléfonos vuelven a considerarlo todo.
    static func olvidarTodo(defaults: UserDefaults? = nil) {
        guardar([], defaults: defaults)
    }

    /// Enciende o apaga una partida. Devuelve el conjunto que queda guardado.
    @discardableResult
    static func considerar(_ clave: String, _ considerar: Bool, defaults: UserDefaults? = nil) -> Set<String> {
        var actuales = excluidos(defaults: defaults)
        if considerar { actuales.remove(clave) } else { actuales.insert(clave) }
        guardar(actuales, defaults: defaults)
        return actuales
    }

    /// Una sola vez por teléfono: sube lo que se apagó cuando se guardaba solo aquí y retira la lista vieja. Une lo que
    /// ya hubiera llegado de otro teléfono, para no pisarlo. Devuelve `true` si había algo que migrar.
    @discardableResult
    static func migrarLoLocalSiHaceFalta(defaults: UserDefaults? = nil) -> Bool {
        let store = defaults ?? almacen
        guard store.object(forKey: legacyDefaultsKey) != nil else { return false }
        guardar(excluidos(defaults: defaults), defaults: defaults)
        return true
    }

    private static func guardar(_ conjunto: Set<String>, defaults: UserDefaults?) {
        publicar(codificar(conjunto), defaults: defaults)
        (defaults ?? almacen).removeObject(forKey: legacyDefaultsKey)
    }

    // MARK: - Formato

    /// Lista JSON ordenada (`["in|n","out|c:…"]`); `""` sin nada apagado.
    static func codificar(_ conjunto: Set<String>) -> String {
        guard !conjunto.isEmpty else { return "" }
        do {
            let data = try JSONEncoder().encode(conjunto.sorted())
            return String(decoding: data, as: UTF8.self)
        } catch {
            #if DEBUG
            print("FlujoFijosAFuturo: Error: \(error)")
            #endif
            return ""
        }
    }

    /// Lo contrario de `codificar`. Un valor vacío o que no se entiende es «nada apagado».
    static func decodificar(_ texto: String?) -> Set<String> {
        guard let texto, !texto.isEmpty else { return [] }
        do {
            return Set(try JSONDecoder().decode([String].self, from: Data(texto.utf8)))
        } catch {
            #if DEBUG
            print("FlujoFijosAFuturo: Error: \(error)")
            #endif
            return []
        }
    }
}
