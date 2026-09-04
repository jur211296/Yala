//
//  RouterIntentEmitterCoverageTests.swift
//  YalaTests
//
//  Pinnea dos cosas que el recorrido del invitado de Grupos pagó caras, y que ningún test de
//  comportamiento puede cazar porque el defecto es la AUSENCIA de un camino:
//
//  1. Que ningún `case` de `RouterIntent` se quede declarado sin que nadie lo emita.
//  2. Que ningún servicio de Grupos prometa «sin call-sites» sin el grep que lo demuestre al lado.
//
//  Por qué existe. Hasta el 2026-09-04 el router declaraba tres intents —`presentGroupInviteOnboarding`,
//  `presentGroupReconnect` y `offerRestoreBeforeInvite`— que NINGÚN `submit(...)` producía. Su único
//  productor había muerto el 2026-08-06 con `CKShareEntryHandler`, y detrás de ellos seguían compilando
//  (y traduciéndose a 16 idiomas) una vista entera con ocho modos, su handler de CTA y un alert con dos
//  wipes. Nadie podía llegar a nada de eso. Costó un mes de vida y una sesión de borrado.
//
//  El segundo escáner persigue el defecto GEMELO, que es peor porque va en la dirección contraria:
//  `GroupBackendInviteService` llevaba un docblock que decía «DARK (G4): sin call-sites de UI» cuando
//  `createInviteLink` colgaba de los dos botones reales de compartir enlace, e `InviteLinkService` decía
//  lo mismo de `buildBackendInviteURL` teniendo cuatro. Un docblock así no deja código muerto: invita a
//  BORRAR EL ÚNICO PRODUCTOR VIVO del recorrido. Es la familia del `AppAttestClient.ensureRegistered()`
//  de `.claude/rules/gateway-attest.md`, cuya promesa falsa costó una vuelta entera de diagnóstico del 401.
//
//  Son source-scans a propósito: el fallo que persiguen es que alguien añada un intent y no lo cablee,
//  o que escriba «sin call-sites» sin medirlo. Eso no lo caza ningún test de comportamiento — lo caza,
//  meses después, una sesión entera de arqueología.
//

import Foundation
import Testing

@testable import Yala

@Suite("Router · todo intent declarado tiene emisor (source-scan)")
struct RouterIntentEmitterCoverageTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Ficheros de producción donde puede vivir un `submit(...)`.
    private static func swiftDeProduccion() throws -> [(ruta: String, texto: String)] {
        let raiz = repoRoot.appendingPathComponent("Yala")
        guard let it = FileManager.default.enumerator(at: raiz, includingPropertiesForKeys: nil) else {
            Issue.record("no se pudo enumerar `Yala/` — ¿se movió el árbol?")
            return []
        }
        var out: [(String, String)] = []
        for case let url as URL in it where url.pathExtension == "swift" {
            do {
                out.append((url.lastPathComponent, try String(contentsOf: url, encoding: .utf8)))
            } catch {
                // Un fichero ilegible NO se salta en silencio: si el escáner deja de leer parte del
                // árbol, este test pasaría en verde sin haber escaneado nada, que es el modo de fallo
                // que lo haría inútil.
                Issue.record("no se pudo leer \(url.lastPathComponent): \(error)")
            }
        }
        return out
    }

    /// Los `case` del enum `RouterIntent`, sin los de los enums vecinos del mismo fichero.
    private static func casesDeRouterIntent() throws -> [String] {
        let src = try code("Yala/App/Models/RouterIntent.swift")
        guard let inicio = src.range(of: "enum RouterIntent") else {
            Issue.record("no se encontró `enum RouterIntent` — ¿se renombró o se movió de fichero?")
            return []
        }
        // Del `enum RouterIntent` al primer cierre de declaración a nivel de fichero.
        let resto = src[inicio.upperBound...]
        let fin = resto.range(of: "\n}")?.lowerBound ?? resto.endIndex
        let cuerpo = resto[..<fin]

        var nombres: [String] = []
        for linea in cuerpo.split(separator: "\n") {
            let t = linea.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("case ") else { continue }
            // `case foo(Bar)` · `case foo` · `case foo, bar` (varios en una línea)
            let cuerpoCase = t.dropFirst("case ".count)
            for trozo in cuerpoCase.split(separator: ",") {
                let nombre = trozo
                    .prefix { $0.isLetter || $0.isNumber }
                    .trimmingCharacters(in: .whitespaces)
                if !nombre.isEmpty { nombres.append(nombre) }
            }
        }
        return nombres
    }

    // MARK: - 1 · Cero intents sin emisor

    @Test("ningún `case` de RouterIntent se queda sin un `submit(...)` que lo produzca")
    func cadaIntentDeclaradoTieneEmisor() throws {
        let cases = try Self.casesDeRouterIntent()

        // Control del instrumento: si el escáner deja de leer el enum, esto lo delata en vez de
        // pasar en verde con cero casos — el modo de fallo que hace inútil a un source-scan.
        #expect(cases.count >= 20, """
            El escáner sólo encontró \(cases.count) `case` en `RouterIntent`, y el enum tenía 28 el
            2026-09-04. O el router adelgazó muchísimo, o el parser dejó de entender el fichero.
            Míralo antes de creerte el verde de abajo.
            """)

        let produccion = try Self.swiftDeProduccion()
        #expect(produccion.count > 100, """
            El escáner sólo vio \(produccion.count) ficheros Swift bajo `Yala/`. Son cientos: si este
            número es pequeño, el enumerador no está leyendo el árbol y el test de abajo es humo.
            """)

        var huerfanos: [String] = []
        for nombre in cases {
            // `submit(.foo(` · `submit(.foo)` · `submit(\n    .foo(` — tolerante al salto de línea.
            let emitido = produccion.contains { _, texto in
                guard let r = texto.range(of: "submit(", options: [], range: nil) else { return false }
                _ = r
                var desde = texto.startIndex
                while let m = texto.range(of: "submit(", range: desde..<texto.endIndex) {
                    let cola = texto[m.upperBound...].prefix(120)
                    let limpio = cola.drop { $0 == " " || $0 == "\n" }
                    if limpio.hasPrefix(".\(nombre)"),
                       // que no case `.fooBar` cuando buscamos `.foo`
                       !(limpio.dropFirst(nombre.count + 1).first.map { $0.isLetter || $0.isNumber } ?? false) {
                        return true
                    }
                    desde = m.upperBound
                }
                return false
            }
            if !emitido { huerfanos.append(nombre) }
        }

        #expect(huerfanos.isEmpty, """
            Estos `case` de `RouterIntent` están declarados y NADIE los emite: \(huerfanos.joined(separator: ", ")).

            Un intent sin `submit(...)` es una promesa que la app no puede cumplir: todo lo que cuelga
            de él —vistas, modos, copy en 16 idiomas— queda inalcanzable y sigue compilando, así que
            nada avisa. Es exactamente lo que pasó con `presentGroupReconnect`, `presentGroupInviteOnboarding`
            y `offerRestoreBeforeInvite`, que sobrevivieron un mes a la muerte de su productor.

            Cablea el intent o retíralo con lo que cuelgue de él. Lo que no vale es dejarlo declarado.
            """)
    }

    // MARK: - 2 · Ningún docblock promete «sin call-sites» sin demostrarlo

    @Test("ningún servicio de Grupos dice «sin call-sites» sin el grep que lo respalde")
    func ningunaPromesaDeMuerteSinSuGrep() throws {
        let carpetas = ["Yala/Services/Groups", "Yala/Services/CloudSync/Groups"]
        var revisados = 0
        var infractores: [String] = []

        for carpeta in carpetas {
            let url = repoRootPath(carpeta)
            guard let it = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else {
                Issue.record("no se pudo enumerar `\(carpeta)` — ¿se movió?")
                continue
            }
            for case let f as URL in it where f.pathExtension == "swift" {
                let texto: String
                do {
                    texto = try String(contentsOf: f, encoding: .utf8)
                } catch {
                    Issue.record("no se pudo leer \(f.lastPathComponent): \(error)")
                    continue
                }
                revisados += 1
                // Sólo importa la promesa AFIRMADA, no la CITADA ni la narrada en pasado. Este repo
                // documenta sus propios errores («este docblock decía "sin call-sites"…», «X, que ya
                // estaba sin call-sites, se fue en la Fase 3»), y esa prosa es justo lo que queremos
                // que se escriba: describe un símbolo que YA NO EXISTE y no invita a borrar nada vivo.
                // Distinguirlas por comillas angulares y por marcadores de pasado es una heurística, y
                // conviene saberlo: si algún día deja de sostenerse, el arreglo es afinar ESTA lista,
                // no borrar el test.
                let pasado = ["«", "decía", "ya estaba", "era cierto", "se fue", "murió", "estuvo"]
                let afirmaEnPresente = texto
                    .split(separator: "\n")
                    .filter { $0.contains("sin call-sites") }
                    .contains { linea in !pasado.contains(where: { linea.contains($0) }) }
                guard afirmaEnPresente else { continue }
                // La promesa vale si trae al lado el grep que la sostiene.
                if !texto.contains("grep -rn") {
                    infractores.append(f.lastPathComponent)
                }
            }
        }

        // Control del instrumento.
        #expect(revisados >= 10, """
            El escáner sólo abrió \(revisados) ficheros en los servicios de Grupos, y son más de diez.
            Si esto baja, el verde de abajo no significa nada.
            """)

        #expect(infractores.isEmpty, """
            Estos servicios de Grupos afirman «sin call-sites» sin el grep que lo demuestre: \
            \(infractores.joined(separator: ", ")).

            Ese docblock no documenta código muerto: invita a BORRAR EL PRODUCTOR VIVO del recorrido.
            Ya pasó dos veces — `GroupBackendInviteService.createInviteLink` (dos botones reales) e
            `InviteLinkService.buildBackendInviteURL` (cuatro call-sites) — y es la familia del
            `AppAttestClient.ensureRegistered()` que costó una vuelta entera de diagnóstico del 401.

            O pegas el `grep -rn` que sostiene la afirmación, o la quitas.
            """)
    }

    private func repoRootPath(_ rel: String) -> URL {
        Self.repoRoot.appendingPathComponent(rel)
    }
}
