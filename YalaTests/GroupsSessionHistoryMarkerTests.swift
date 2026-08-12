//
//  GroupsSessionHistoryMarkerTests.swift
//  YalaTests
//
//  C2 · el latch «este device tuvo sesión de Grupos alguna vez». Es lo único que separa el empty state de
//  re-entrada («tus grupos están en tu cuenta») del de alta («crea tu cuenta»), así que su comportamiento
//  y su ARMADO son dos cosas distintas y necesitan dos mitades.
//

import Foundation
import Testing

@testable import Yala

@Suite("GroupsSessionHistoryMarker · el latch de sesión previa (C2)")
struct GroupsSessionHistoryMarkerTests {

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    @Test func nace_apagado() {
        #expect(GroupsSessionHistoryMarker.hadSessionEver(isolatedDefaults()) == false)
    }

    @Test func armar_lo_enciende_y_es_idempotente() {
        let d = isolatedDefaults()
        GroupsSessionHistoryMarker.markSessionSeen(d)
        #expect(GroupsSessionHistoryMarker.hadSessionEver(d) == true)
        GroupsSessionHistoryMarker.markSessionSeen(d)
        #expect(GroupsSessionHistoryMarker.hadSessionEver(d) == true)
    }

    /// **Monotónico a propósito: no existe `clear()`.** Un latch que se pudiera apagar volvería a mentirle
    /// a quien ya tuvo cuenta, que es el fallo que existe para cerrar — y lo que afirma no deja de ser
    /// cierto por cerrar sesión. Lo único que lo retira es el handover, y eso va por `DataWipeService`
    /// (pinneado en el source-scan de abajo), no por una API pública que cualquiera pueda llamar.
    @Test func noHayApagadoPublico_esUnLatch() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Yala/App/Logic/GroupsSessionHistoryMarker.swift")
        let code = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(!code.contains("func clear("), """
            apareció un apagado en el latch. Apagarlo le devuelve a quien SÍ tuvo cuenta el empty state de \
            «crea una cuenta», que es exactamente el fallo que este marcador existe para cerrar — y es lo \
            que descalificó a `GroupsSignOutBannerMarker` para este papel (es one-shot: se quema al \
            mostrarse y se desarma al re-firmar).
            """)
        #expect(code.contains("func markSessionSeen("), "desapareció el armado del latch")
    }

    /// La key vive FUERA de `cloudSync.*`, y esto no es cosmético: ese prefijo está **excluido a propósito**
    /// del wipe (`DataWipeService.removeUserPreferenceKeys`, «infra del propio sign-out/wipe … JAMÁS
    /// aquí»), así que allí el latch habría sobrevivido al handover y le habría dicho al humano NUEVO que
    /// tiene grupos esperando en una cuenta que nunca creó.
    @Test func laKeyNoViveEnCloudSync_porqueElHandoverTieneQueRetirarla() {
        #expect(!GroupsSessionHistoryMarker.key.hasPrefix("cloudSync."), """
            la key del latch volvió al namespace `cloudSync.*`, que el wipe NO barre. El latch sobreviviría \
            al «empiezo de cero» del Welcome.
            """)
        #expect(GroupsSessionHistoryMarker.key == "groups.hadSessionEver")
    }
}

// MARK: - El cableado

/// El latch puede ser perfecto y no armarse nunca. Los DOS armadores tienen razones distintas y ninguno
/// cubre al otro: el sign-in cubre a quien firma desde hoy; el `onAppear` del tab cubre al parque que YA
/// tenía sesión antes de esta versión —para quien no habrá ningún evento de sign-in futuro— y a quien firmó
/// por el camino de nube completo, que no pasa por el closure de `GroupsSignInView`.
@Suite("C2 · cableado del latch de sesión (source-scan)")
struct GroupsSessionHistoryWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func count(_ needle: String, in source: String) -> Int {
        source.components(separatedBy: needle).count - 1
    }

    @Test("los DOS armadores están cableados")
    func bothArmersAreWired() throws {
        let modifier = try Self.code("Yala/App/Views/Shared/GroupsBackendInviteModifier.swift")
        #expect(Self.count("GroupsSessionHistoryMarker.markSessionSeen()", in: modifier) == 1, """
            el sign-in de Grupos dejó de armar el latch. Quien firme desde ahora leerá «crea una cuenta» al \
            cerrar sesión, con una cuenta ya creada.
            """)

        let container = try Self.code("Yala/App/Views/Groups/GroupsContainerView.swift")
        #expect(Self.count("GroupsSessionHistoryMarker.markSessionSeen()", in: container) == 1, """
            el tab dejó de armar el latch con sesión viva. **No es un cinturón**: es lo ÚNICO que cubre al \
            parque anterior a C2 (que no tendrá ningún evento de sign-in futuro) y a quien firmó por el \
            camino de nube completo. Sin él, todos ellos leen «crea una cuenta».
            """)
        #expect(container.contains("if CloudAuthService.shared.hasSession {"),
                "el armado del tab dejó de gatearse por la sesión VIVA")
    }

    /// La otra mitad del namespace: el handover tiene que NOMBRAR la key. Sin esta línea el latch sobrevive
    /// al «empiezo de cero» y el humano nuevo hereda la afirmación del anterior.
    @Test("el handover retira el latch")
    func handoverClearsTheLatch() throws {
        let wipe = try Self.code("Yala/Utils/DataWipeService.swift")
        #expect(Self.count("defaults.removeObject(forKey: GroupsSessionHistoryMarker.key)", in: wipe) == 1, """
            `removeGroupsDomainPreferenceKeys` dejó de barrer el latch. Un «empiezo de cero» entregaría al \
            humano NUEVO un empty state que le dice «tus grupos están en tu cuenta».
            """)
    }
}
