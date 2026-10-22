//
//  ModelConfigurationCloudKitWiringTests.swift
//  YalaTests
//
//  `cloudKitDatabase: .none` en TODO `ModelConfiguration` de un test.
//
//  POR QUÉ ESTE FICHERO EXISTE, Y POR QUÉ ES SOURCE-SCAN. El default de `cloudKitDatabase` es
//  `.automatic`, y con un schema que tiene RELACIONES eso hace que SwiftData adjunte
//  `NSPersistentCloudKitContainer` incluso a un store in-memory (`URL: file:///dev/null`). En el
//  simulador, que no tiene cuenta iCloud, su `_performSetupRequest:` falla con
//  `CKAccountStatusNoAccount` (134400), `recoverFromError:` tampoco puede, y el store se queda SIN
//  conexión SQL ⇒ el `save()` siguiente muere con `NSInternalInconsistencyException "No eligible
//  connection available"` desde `-[NSSQLDefaultConnectionManager handleStoreRequest:]`. Es una
//  excepción ObjC: el `do/catch` de Swift NO la ve, así que no hay rojo — hay `SIGABRT`, runner
//  reiniciado y exit 65 sin aserción que leer.
//
//  Eso tumbó los 3 tests de `InitialBalanceServiceMultiCurrencyTests` desde que la suite nació
//  (2026-05-04, `17638122`) hasta el 2026-08-02, y nunca se ejecutaron. El conocimiento YA EXISTÍA
//  desde el 2026-07-04, pero vivía como COMENTARIO dentro de `TestHelpers.testContainer(for:)`, y
//  por eso no llegó a los dos sitios que escribieron su config a mano. La convención ya falló una
//  vez aquí ⇒ la red tiene que ser estructural, no un párrafo en markdown.
//
//  NO se puede pinnear por comportamiento: reproducir el crash MATA el proceso de test, así que un
//  test que lo ejerciera se llevaría la suite entera por delante. La única red posible es leer el
//  fuente. Molde: `CloudSync/AttestWiringTests.swift`, misma clase de invariante (un default legal
//  que el compilador no comprueba) y mismo anti-falso-verde.
//
//  LAS DOS MUTACIONES QUE DEBEN DAR EXIT 65 — si solo cae una, este test comprueba la forma y no el
//  fondo:
//    1. quitar `cloudKitDatabase:` de cualquier `ModelConfiguration` de `YalaTests/`
//    2. cambiar un `.none` por `.automatic` (cumple la letra y reintroduce el crash)
//
//  ESTE FICHERO SE EXCLUYE DEL BARRIDO A PROPÓSITO, y no es cosmético: el patrón que busca aparece
//  como literal en su propio código y en su propia prosa, así que escanearse a sí mismo contaría
//  call-sites fantasma. `AttestWiringTests` no tiene el problema porque solo mira directorios de
//  producción; este mira `YalaTests`, o sea su propia casa.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("SwiftData · cloudKitDatabase en configs de test (source-scan)")
struct ModelConfigurationCloudKitWiringTests {

    /// Excepciones DELIBERADAS. `SpikeSRuntimeTests` mide justamente qué hace `.automatic` en un sim
    /// sin cuenta iCloud: es la medición, no el descuido. Su propio docblock declara que está aislado
    /// en su archivo para que, si desestabiliza el proceso, solo caiga esa suite. Sobrevive además
    /// porque su schema (`Schema([SpikeSRT.Item.self])`) no tiene relaciones ⇒ no se adjunta el mirror.
    private static let whitelist: Set<String> = [
        "YalaTests/Spikes/SpikeSRuntimeTests.swift"
    ]

    /// Suelo del barrido, NO conteo exacto — y la desviación respecto de `AttestWiringTests` es
    /// consciente. Allí el `expected` es exacto porque son 9 construcciones de un puñado de clases;
    /// aquí son >130 call-sites que crecen con cada suite nueva, así que un número exacto obligaría a
    /// tocar este fichero en cada test que use un `ModelContext` y se convertiría en ruido que se
    /// actualiza sin leer. El suelo sigue cazando el fallo que importa: un escáner roto, un directorio
    /// renombrado o un `enumerator` que no devuelve nada dan 0 y la suite se pondría verde sin
    /// comprobar nada — la familia de «Executed 0 tests».
    private static let minimumCallSites = 100

    private static let scannedRoots = ["YalaTests", "YalaUITests"]

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static var ownRelativePath: String {
        let name = URL(fileURLWithPath: #filePath).lastPathComponent
        return "YalaTests/" + name
    }

    /// Todos los `.swift` de los directorios de test, como (ruta relativa, contenido), sin la lista
    /// blanca ni este propio fichero.
    private static func testSources() -> [(path: String, text: String)] {
        var out: [(String, String)] = []
        for root in scannedRoots {
            let base = repoRoot.appendingPathComponent(root)
            guard let walker = FileManager.default.enumerator(
                at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let relative = root + "/" + url.path.replacingOccurrences(
                    of: base.path + "/", with: "")
                if relative == ownRelativePath || whitelist.contains(relative) { continue }
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                out.append((relative, text))
            }
        }
        return out
    }

    /// Quita las líneas que son COMENTARIO ENTERO. Sin esto, un `ModelConfiguration(` citado en la
    /// prosa de un docblock —que en este repo pasa constantemente— contaría como call-site. Los
    /// comentarios de final de línea se conservan: recortar desde el primer `//` destrozaría cualquier
    /// `URL(string: "https://…")`.
    private static func stripWholeLineComments(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Lista de argumentos de cada `ModelConfiguration(...)` del fuente, con paréntesis balanceados.
    /// Descarta los matches precedidos por un carácter de identificador o por `.`, y no cuenta los
    /// paréntesis que caen dentro de un literal de string.
    private static func configurationArguments(in source: String) -> [String] {
        let chars = Array(stripWholeLineComments(source))
        let needle = Array("ModelConfiguration" + "(")
        var found: [String] = []
        var i = 0

        while i + needle.count <= chars.count {
            guard Array(chars[i..<(i + needle.count)]) == needle else { i += 1; continue }
            if i > 0 {
                let prev = chars[i - 1]
                if prev.isLetter || prev.isNumber || prev == "_" || prev == "." { i += 1; continue }
            }
            var depth = 0
            var inString = false
            var j = i + needle.count - 1
            while j < chars.count {
                let c = chars[j]
                if c == "\"" { inString.toggle() }
                if !inString {
                    if c == "(" { depth += 1 }
                    if c == ")" { depth -= 1; if depth == 0 { break } }
                }
                j += 1
            }
            let end = min(j, chars.count - 1)
            let open = i + needle.count
            if open <= end { found.append(String(chars[open..<end])) }
            i = end + 1
        }
        return found
    }

    private static func allCallSites() -> [(path: String, args: String)] {
        testSources().flatMap { source in
            configurationArguments(in: source.text).map { (source.path, $0) }
        }
    }

    // MARK: - Mutación 1: la config no declara cloudKitDatabase

    @Test func everyTestConfiguration_declaresCloudKitDatabase() {
        let offenders = Self.allCallSites()
            .filter { !$0.args.contains("cloudKitDatabase") }
            .map(\.path)

        #expect(
            offenders.isEmpty,
            """
            ModelConfiguration sin `cloudKitDatabase: .none` en: \(Set(offenders).sorted())
            El default es `.automatic` y con un schema con relaciones adjunta el mirror de CloudKit \
            incluso a un store in-memory → en un sim sin cuenta iCloud el `save()` mata el proceso \
            con NSInternalInconsistencyException "No eligible connection available". \
            Ver .claude/rules/testing.md.
            """
        )
    }

    // MARK: - Mutación 2: declara cloudKitDatabase, pero .automatic

    @Test func noTestConfiguration_optsIntoAutomatic() {
        let offenders = Self.allCallSites()
            .filter { $0.args.contains(".automatic") }
            .map(\.path)

        #expect(
            offenders.isEmpty,
            """
            ModelConfiguration con `cloudKitDatabase: .automatic` en: \(Set(offenders).sorted())
            Cumple la letra de la regla y reintroduce el crash. Si de verdad quieres medir \
            `.automatic`, aísla la suite en su propio fichero y añádelo a la lista blanca de este \
            test explicando por qué, como `Spikes/SpikeSRuntimeTests`.
            """
        )
    }

    // MARK: - Anti-falso-verde

    @Test func scan_reachesTheTestSources_soAGreenMeansSomething() {
        let count = Self.allCallSites().count
        #expect(
            count >= Self.minimumCallSites,
            """
            El barrido encontró \(count) call-sites y esperaba al menos \(Self.minimumCallSites). \
            Un número muy bajo (y sobre todo 0) significa que el escáner NO está leyendo las fuentes \
            —directorio renombrado o movido, `#filePath` que ya no resuelve al repo—, no que el repo \
            esté limpio. Arregla el barrido antes de bajar el suelo.
            """
        )
    }

    // MARK: - La lista blanca tiene que seguir justificándose

    @Test func whitelist_entriesStillExist_andStillNeedTheExemption() throws {
        for relative in Self.whitelist {
            let url = Self.repoRoot.appendingPathComponent(relative)
            let text = try #require(
                try? String(contentsOf: url, encoding: .utf8),
                "La excepción \(relative) ya no existe: quítala de la lista blanca."
            )
            #expect(
                text.contains(".automatic"),
                """
                \(relative) está en la lista blanca pero ya no usa `.automatic`: la exención sobra y \
                deja un hueco por el que puede colarse una config sin `cloudKitDatabase`. Quítala.
                """
            )
        }
    }
}
