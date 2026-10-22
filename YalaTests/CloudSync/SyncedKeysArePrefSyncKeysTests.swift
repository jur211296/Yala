//
//  SyncedKeysArePrefSyncKeysTests.swift
//  YalaTests
//
//  Pinnea el contrato que faltaba: **toda key marcada `synced: true` tiene que ser `PrefSyncKey`.**
//
//  Por qué existe. `persist*(…, synced: true)` empuja la key al outbox de preferencias y al iCloud KV,
//  pero el que la APLICA al bajar es el merge, y el merge solo conoce los casos del enum `PrefSyncKey`.
//  Una key marcada `synced: true` que no esté en ese enum hace un viaje **de ida y sin vuelta**: gasta
//  cuota y tráfico, y el dispositivo receptor no la materializa jamás. Es invisible para el usuario —no
//  hay error, no hay log— y solo se nota cuando alguien compara dos teléfonos.
//
//  Medido el 2026-09-02: eran CINCO de las 37 `synced: true` (`moreSectionOrder`, `sankeyLabelMode` y
//  las tres de `panelHeroKPIs`). Las cinco eran ajustes de PRESENTACIÓN, así que la decisión del owner
//  fue bajarlas a `synced: false` —local por dispositivo, que para un orden de tarjetas es lo correcto—
//  en vez de enseñarle al merge a resolverlas. Lo que NO era defendible es el estado en que estaban:
//  el coste de las dos opciones y el beneficio de ninguna.
//
//  Es un source-scan a propósito. El fallo que persigue —alguien escribe `synced: true` en una property
//  nueva sin añadir su caso al enum— no lo caza ningún test de comportamiento: el push funciona, el
//  merge simplemente ignora lo que no conoce, y todo sale verde.
//

import Foundation
import Testing

@testable import Yala

@Suite("Prefs · toda key `synced: true` es `PrefSyncKey` (source-scan)")
struct SyncedKeysArePrefSyncKeysTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CloudSync
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Las keys que `AppPreferences` empuja con `synced: true`, leídas del literal `Keys.<algo>`.
    private static func syncedKeys() throws -> [String] {
        let src = try code("Yala/App/Services/AppPreferences.swift")
        var out: [String] = []
        for linea in src.split(separator: "\n", omittingEmptySubsequences: false) {
            let l = linea.trimmingCharacters(in: .whitespaces)
            guard !l.hasPrefix("//"), l.contains("synced: true"), l.contains("forKey: Keys.") else { continue }
            guard let r = l.range(of: "forKey: Keys.") else { continue }
            let cola = l[r.upperBound...]
            let nombre = cola.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            if !nombre.isEmpty { out.append(String(nombre)) }
        }
        return out
    }

    /// Los `case` del enum `PrefSyncKey`.
    private static func prefSyncKeys() throws -> Set<String> {
        let src = try code("Yala/Services/CloudSync/PreferenceMergeLogic.swift")
        guard let inicio = src.range(of: "enum PrefSyncKey") else {
            Issue.record("no se encontró `enum PrefSyncKey` — ¿se renombró?")
            return []
        }
        // Del enum hasta el cierre de su bloque, contando llaves.
        var profundidad = 0
        var cuerpo = ""
        var empezado = false
        for ch in src[inicio.upperBound...] {
            if ch == "{" { profundidad += 1; empezado = true }
            if empezado { cuerpo.append(ch) }
            if ch == "}" { profundidad -= 1; if profundidad == 0 { break } }
        }
        var out: Set<String> = []
        for linea in cuerpo.split(separator: "\n") {
            let l = linea.trimmingCharacters(in: .whitespaces)
            guard l.hasPrefix("case ") else { continue }
            // `case a, b, c` y `case a` — se parten por coma.
            for trozo in l.dropFirst(5).split(separator: ",") {
                let nombre = trozo.trimmingCharacters(in: .whitespaces)
                    .prefix { $0.isLetter || $0.isNumber || $0 == "_" }
                if !nombre.isEmpty { out.insert(String(nombre)) }
            }
        }
        return out
    }

    @Test("ninguna key sube sin que el merge sepa bajarla")
    func everySyncedKeyIsAPrefSyncKey() throws {
        let synced = try Self.syncedKeys()
        let conocidas = try Self.prefSyncKeys()

        // Control positivo: si cualquiera de los dos escáneres deja de leer, la resta de abajo da vacío
        // y el test pasa en verde sin haber comprobado nada. Es el modo de fallo clásico del source-scan.
        #expect(synced.count >= 25, """
            el escáner encontró \(synced.count) llamadas `synced: true` en AppPreferences; esperaba unas 32. \
            ¿Cambió la forma de `persist*(…, forKey: Keys.X, synced: true)`?
            """)
        #expect(conocidas.count >= 25, """
            el escáner encontró \(conocidas.count) `case` en `PrefSyncKey`; esperaba unos 40. \
            ¿Cambió la forma del enum?
            """)

        let huerfanas = Set(synced).subtracting(conocidas).sorted()
        #expect(huerfanas.isEmpty, """
            estas keys se marcan `synced: true` pero NO son `PrefSyncKey`: \(huerfanas).

            Hacen un viaje de ida y sin vuelta: se suben al outbox y al iCloud KV, y el dispositivo que
            las recibe no las materializa nunca, porque el merge solo resuelve los casos del enum.

            Hay dos salidas y ninguna es «dejarlo así»:
              1. añadir su `case` a `PrefSyncKey` (y decidir su forma en el wire y su resolución LWW), o
              2. bajarla a `synced: false` si es un ajuste local por dispositivo.
            """)
    }
}
