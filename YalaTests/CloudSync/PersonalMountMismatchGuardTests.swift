//
//  PersonalMountMismatchGuardTests.swift
//  YalaTests / CloudSync
//
//  A3 de D-A7 · el guard de mount-mismatch del store PERSONAL, en sus dos mitades y ninguna cubre a la
//  otra: el CABLEADO en `CloudSyncRuntime.canRunDomain` (comportamiento) y que el cableado siga existiendo
//  y leyendo el testigo REAL (source-scan). La lógica pura vive en `CloudMigrationI14Tests`.
//
//  El escenario que esto protege: el alta born-cloud escribe el par `.cloud` + `mirrorOffArmed` en caliente
//  y pide el relanzamiento. Entre esas dos cosas el proceso sigue con el mirror de CloudKit montado, el par
//  está COMPLETO (⇒ `isCloudWithMirrorOn` es `false`) y la fase journaleada es `notStarted` (⇒ ESTABLE):
//  los dos términos que ya existían dejan pasar, y el motor arrancaría a escribir el mismo store que el
//  mirror. Hasta A3 lo único que lo impedía era la CONVENCIÓN de que el único camino a `.cloud` pasaba por
//  la máquina de migración.
//

import Foundation
import Testing

@testable import Yala

@Suite("A3 · guard de mount-mismatch del store personal (cableado)", .serialized)
@MainActor
struct PersonalMountMismatchGuardTests {

    /// Deja el proceso como estaba: los dos testigos son estado GLOBAL y una suite que no restaure
    /// contamina a las demás (lección de `.claude/rules/testing.md` sobre el estado compartido).
    private func restoreGlobals() {
        CloudSyncFlags._testResetStorageModeOverride()
        SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.iCloudMirror)
        SecondarySessionStore._testSetActiveOverride(nil)
    }

    @Test("par COMPLETO + mount `.icloud` ⇒ el motor NO arranca (la aserción que carga el peso)")
    func cloudPairComplete_butMirrorMounted_blocksDomain() {
        SecondarySessionStore._testSetActiveOverride(false)  // el guard M1 no interviene
        CloudSyncFlags.storageMode = .cloud
        SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.iCloudMirror)  // proceso PRE-relanzamiento
        defer { restoreGlobals() }

        // Premisas explícitas: si alguna dejara de cumplirse, este test pasaría por la razón equivocada.
        #expect(SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror)
        #expect(MigrationRuntimeGate.isDomainStablePhase(MigrationPhaseStore.shared.currentPhase),
                "la fase tiene que ser ESTABLE: si no, bloquearía el término de fase y no el nuevo")

        #expect(CloudSyncRuntime.canRunDomain() == false)
    }

    @Test("mismo estado con el device YA RELANZADO ⇒ el motor SÍ arranca (el guard no apaga al sano)")
    func cloudPairComplete_afterRelaunch_allowsDomain() {
        // La otra mitad del par: sin esto, un guard que devolviera `false` siempre pasaría el test de
        // arriba y dejaría el Modo Nube muerto para todo el mundo.
        SecondarySessionStore._testSetActiveOverride(false)
        CloudSyncFlags.storageMode = .cloud
        SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.cloudMirrorOff)
        defer { restoreGlobals() }

        #expect(CloudSyncRuntime.canRunDomain() == true)
    }

    @Test("en `.icloud` el término es inerte con CUALQUIER mount (no-regresión del 99 % del parque)")
    func icloudMode_unaffectedByMountWitness() {
        // Un device 2.x jamás puede ver este guard: el gate corta antes en `storageMode == .cloud`. Se
        // recorren TODAS las decisiones de mount (R1: `allCases`, así una decisión nueva entra sola en el
        // barrido) para que el pin no dependa del default.
        SecondarySessionStore._testSetActiveOverride(false)
        CloudSyncFlags.storageMode = .icloud
        defer { restoreGlobals() }

        for mounted in SwiftDataConfiguration.PersonalStoreDecision.allCases {
            SwiftDataConfiguration._testSetPersonalStoreMountedDecision(mounted)
            #expect(CloudSyncRuntime.canRunDomain() == false, "montado=\(mounted)")
        }
    }

    @Test("la secundaria OPERATIVA no queda atrapada por el guard nuevo (M1 sigue funcionando)")
    func secondaryMountedSession_isNotBlockedByTheNewTerm() {
        // En la secundaria montada, `personalStoreDecision` devuelve `.secondaryCloudSession`, que NO
        // adjunta mirror ⇒ NO hay mismatch. Si alguien reescribiera el predicado contra la key PERSISTIDA
        // (que en una secundaria sigue siendo `.icloud` por invariante) este test caería.
        SecondarySessionStore._testSetActiveOverride(true)
        SwiftDataConfiguration._testSetSecondaryStoreMounted(true)
        SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.secondaryCloudSession)
        defer {
            SwiftDataConfiguration._testSetSecondaryStoreMounted(false)
            restoreGlobals()
        }

        #expect(CloudSyncFlags.storageMode == .cloud, "el modo EFECTIVO lo deriva el descriptor")
        #expect(CloudSyncRuntime.canRunDomain() == true)
    }
}

// MARK: - Cableado (source-scan)

/// Por qué además del test de comportamiento: la lógica pura puede estar perfecta y sus tablas verdes
/// mientras NADIE la invoca — es la familia de `AttestWiringTests`. Aquí el escáner cubre además dos cosas
/// que ninguna aserción de comportamiento ve: que el cableado lea el TESTIGO del mount (y no la key
/// persistida, que en una sesión secundaria miente) y que el guard nuevo vaya DESPUÉS del guard M1, para
/// que la ventana de entrada de la secundaria siga contándose con su propio canario.
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
    /// comentario. Acotar al CUERPO no es cosmético: un rango ancho comprobaría que los símbolos EXISTEN en
    /// el fichero, no que se usen aquí — y contar la prosa haría que documentar el invariante lo "cumpliera"
    /// (las dos lecciones de `TestProcessGuardTests`).
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
            el input tiene que ser el TESTIGO del mount de ESTE proceso. La key persistida no sirve: dice qué
            modo quiere el device, no qué montó el proceso — y en una sesión secundaria además vale `.icloud`
            por invariante.
            """)
        #expect(body.contains("personalMountMismatch: personalMountMismatch"), """
            el valor derivado tiene que LLEGAR a `MigrationRuntimeGate.canRun`. Derivarlo y no pasarlo deja
            el guard como decoración: la lógica pura seguiría verde y el motor arrancaría igual.
            """)
    }

    @Test("el guard nuevo va DESPUÉS del guard M1 (cada ventana con su propio canario)")
    func newGuard_comesAfterTheSecondarySessionGuard() throws {
        // La ventana de entrada de la secundaria satisface las DOS condiciones a la vez (descriptor activo
        // sin store montado ⇒ el testigo personal tampoco es `.cloud`). Si el término nuevo se adelantara,
        // ese caso dejaría de emitir `cloudSecondaryMountMismatchBlocked` y el canario de M1 moriría en
        // silencio, con todos los tests en verde.
        let body = try Self.canRunDomainBody(try Self.runtimeSource())
        let m1 = try #require(body.range(of: "SwiftDataConfiguration.secondaryStoreMounted"))
        let a3 = try #require(body.range(of: "MigrationRuntimeGate.isPersonalMountMismatch("))
        #expect(m1.lowerBound < a3.lowerBound)
    }
}
