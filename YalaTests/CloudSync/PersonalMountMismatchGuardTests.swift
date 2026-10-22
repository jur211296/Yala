//
//  PersonalMountMismatchGuardTests.swift
//  YalaTests / CloudSync
//
//  A3 de D-A7 · el guard de mount-mismatch del store PERSONAL, en sus dos mitades y ninguna cubre a la
//  otra: el CABLEADO en `CloudSyncRuntime.canRunDomain` (comportamiento) y que ese cableado siga
//  existiendo y leyendo el testigo REAL (source-scan). La lógica pura vive en `CloudMigrationI14Tests`.
//
//  El escenario que esto protege: el alta born-cloud escribe el par `.cloud` + `mirrorOffArmed` en
//  caliente y pide el relanzamiento. Entre esas dos cosas el proceso sigue con el mirror de CloudKit
//  montado, el par está COMPLETO (⇒ `isCloudWithMirrorOn` es `false`) y la fase journaleada es
//  `notStarted` (⇒ ESTABLE): los dos términos que ya existían dejan pasar, y el motor arrancaría a
//  escribir el mismo store que el mirror.
//
//  **Este fichero se RESCATÓ el 2026-09-13, y el motivo es la lección.** El barrido de la sesión de
//  visita lo borró entero porque uno de sus cuatro casos era de M1 — pero los otros tres, y una de las
//  dos aserciones de cableado, sostienen un invariante que sigue **vivo**: el de la regla `L133` de
//  `.claude/rules/swiftdata-cloudkit.md` («motor de sync Y espejo de CloudKit escribiendo el mismo
//  store, sin ningún gate de fase que lo notara»). Con el fichero fuera, `canRunDomain` se quedaba sin
//  un solo test y el único escáner superviviente (`AdoptEngineInSessionTests`) pide la subcadena
//  `personalMountMismatch` **a secas**, que la satisface ya la línea de derivación ⇒ **borrar el
//  argumento de la llamada al gate dejaba la suite entera en verde y el guard en decoración.**
//
//  ⇒ **al borrar una suite, mira si alguno de sus casos sostiene un invariante AJENO.** Se descubre
//  leyendo los casos, no el nombre del fichero. Es la misma lección que `WidgetSnapshotLegacyDecodeTests`
//  escribió el mismo día, aplicada aquí después de no haberla aplicado.
//

import Foundation
import Testing

@testable import Yala

@Suite("A3 · guard de mount-mismatch del store personal (cableado)", .serialized)
@MainActor
struct PersonalMountMismatchGuardTests {

    /// Deja el proceso como estaba: los testigos son estado GLOBAL y una suite que no restaure contamina
    /// a las demás (lección de `.claude/rules/testing.md` sobre el estado compartido).
    private func restoreGlobals() {
        CloudSyncFlags._testResetStorageModeOverride()
        SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.iCloudMirror)
    }

    @Test("par COMPLETO + mount `.icloud` ⇒ el motor NO arranca (la aserción que carga el peso)")
    func cloudPairComplete_butMirrorMounted_blocksDomain() {
        CloudSyncFlags.storageMode = .cloud
        SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.iCloudMirror)  // proceso PRE-relanzamiento
        defer { restoreGlobals() }

        // Premisas explícitas: si alguna dejara de cumplirse, este test pasaría por la razón equivocada.
        #expect(SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror)
        #expect(MigrationRuntimeGate.canRun(read: MigrationPhaseStore.shared.currentPhaseRead, cloudWithMirrorOn: false, personalMountMismatch: false),
                "la fase tiene que ser ESTABLE: si no, bloquearía el término de fase y no el nuevo")

        #expect(CloudSyncRuntime.canRunDomain() == false)
    }

    @Test("mismo estado con el device YA RELANZADO ⇒ el motor SÍ arranca (el guard no apaga al sano)")
    func cloudPairComplete_afterRelaunch_allowsDomain() {
        // La otra mitad del par: sin esto, un guard que devolviera `false` siempre pasaría el test de
        // arriba y dejaría el Modo Nube muerto para todo el mundo.
        CloudSyncFlags.storageMode = .cloud
        SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.cloudMirrorOff)
        defer { restoreGlobals() }

        #expect(CloudSyncRuntime.canRunDomain() == true)
    }

    @Test("en `.icloud` el término es inerte con CUALQUIER mount (no-regresión del 99 % del parque)")
    func icloudMode_unaffectedByMountWitness() {
        // Un device 2.x jamás puede ver este guard: el gate corta antes en `storageMode == .cloud`. Se
        // recorren TODAS las decisiones de mount (`allCases`, así una decisión nueva entra sola en el
        // barrido) para que el pin no dependa del default.
        CloudSyncFlags.storageMode = .icloud
        defer { restoreGlobals() }

        for mounted in SwiftDataConfiguration.PersonalStoreDecision.allCases {
            SwiftDataConfiguration._testSetPersonalStoreMountedDecision(mounted)
            #expect(CloudSyncRuntime.canRunDomain() == false, "montado=\(mounted)")
        }
    }
}

// MARK: - Cableado (source-scan)

/// Por qué además del test de comportamiento: la lógica pura puede estar perfecta y sus tablas verdes
/// mientras NADIE la invoca — es la familia de `AttestWiringTests`. Aquí el escáner cubre además algo que
/// ninguna aserción de comportamiento ve: que el cableado lea el TESTIGO del mount de este proceso y no
/// la key persistida, que dice qué modo QUIERE el device y no qué montó.
@Suite("A3 · guard de mount-mismatch personal (source-scan del cableado)")
struct PersonalMountMismatchWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static let runtimePath = "Yala/Services/CloudSync/CloudSyncRuntime.swift"

    private static func runtimeSource() throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(runtimePath), encoding: .utf8)
    }

    /// Cuerpo de `canRunDomain()` (de su llave de apertura a la de cierre, balanceando) y SIN líneas de
    /// comentario. Acotar al CUERPO no es cosmético: un rango ancho comprobaría que los símbolos EXISTEN
    /// en el fichero, no que se usen aquí — y contar la prosa haría que documentar el invariante lo
    /// "cumpliera" (las dos lecciones de `TestProcessGuardTests`).
    private static func canRunDomainBody(_ source: String) throws -> String {
        let marker = "static func canRunDomain() -> Bool {"
        let start = try #require(source.range(of: marker))
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("`canRunDomain` deriva el mismatch del TESTIGO del mount y se lo pasa al gate")
    func canRunDomain_wiresTheMountWitnessIntoTheGate() throws {
        let body = try Self.canRunDomainBody(try Self.runtimeSource())
        #expect(body.contains("MigrationRuntimeGate.isPersonalMountMismatch("),
                "la decisión tiene que salir de la lógica pura, no de una comparación escrita aquí")
        #expect(body.contains("SwiftDataConfiguration.personalStoreMountedDecision"), """
            el input tiene que ser el TESTIGO del mount de ESTE proceso. La key persistida no sirve: dice
            qué modo quiere el device, no qué montó el proceso.
            """)
        #expect(body.contains("personalMountMismatch: personalMountMismatch"), """
            el valor derivado tiene que LLEGAR a `MigrationRuntimeGate.canRun`. Derivarlo y no pasarlo
            deja el guard como decoración: la lógica pura seguiría verde y el motor arrancaría igual.

            Ésta es la aserción que el barrido de la sesión de visita estuvo a punto de llevarse: el otro
            escáner del repo pide la subcadena a secas, que la línea de derivación ya satisface.
            """)
    }
}
