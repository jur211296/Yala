//
//  GroupsAssociationKillSwitchTests.swift
//  YalaTests
//
//  Ticket `associate-cta-ignores-the-groups-kill-switch` (2026-10-02): con el canal de Grupos matado en
//  remoto, «Asociar una cuenta para grupos» y «Entrar» de Ajustes → «¿Dónde viven tus datos?» llevaban a un
//  sign-in real contra un backend en pausa. Eran los únicos productores de `.presentGroupsSignIn` que no
//  miraban el flag.
//
//  Dos redes, porque una sola no basta:
//   - **La tabla** (`GroupsAssociationLogic.signInEntry`): qué puerta pinta cada celda con el canal
//     encendido y apagado.
//   - **El cableado** (source-scan): la tabla puede estar perfecta y verde mientras la vista no la llame, o
//     lea el flag ANTES del refresco forzado — que es medir el snapshot de hasta 6 h del bug.
//     El canal apagado no se puede ejercitar en el harness: `CloudRemoteFlags.decide()` devuelve
//     `absentDefault` bajo test (ON en `Yala Dev`). Es la misma asimetría que `GroupCreateRoutingLogic`.
//

import Foundation
import Testing
@testable import Yala

@Suite("GroupsAssociationLogic · la puerta al sign-in respeta el kill-switch de Grupos")
struct GroupsAssociationSignInEntryTests {

    @Test("Canal encendido: «Asociar» sin cuenta y «Entrar» con la cuenta asociada sin sesión — el flujo de siempre")
    func channelOnKeepsTheEntries() {
        #expect(GroupsAssociationLogic.signInEntry(.noAccount, channelOn: true) == .associate)
        #expect(GroupsAssociationLogic.signInEntry(.associatedNeedsSignIn, channelOn: true) == .signIn)
    }

    @Test("Canal apagado: ninguna de las dos puertas, y la sección lo dice")
    func channelOffPausesTheEntries() {
        #expect(GroupsAssociationLogic.signInEntry(.noAccount, channelOn: false) == .channelPaused)
        #expect(GroupsAssociationLogic.signInEntry(.associatedNeedsSignIn, channelOn: false) == .channelPaused)
    }

    /// Las celdas que no ofrecen entrar no pasan a «en pausa»: la nota diría que algo no está disponible
    /// donde nunca se ofreció nada.
    @Test("Las celdas sin puerta no anuncian pausa, con el canal como esté", arguments: [true, false])
    func cellsWithoutEntryStaySilent(channelOn: Bool) {
        for state: GroupsAssociationLogic.SectionState in [.associated, .sameAccountAsPersonal, .notApplicable] {
            #expect(GroupsAssociationLogic.signInEntry(state, channelOn: channelOn) == .none, "\(state)")
        }
    }

    /// El desasociar es un teardown: el kill apaga el CANAL, no la salida. Esta tabla no lo toca.
    @Test("El desasociar no depende del canal")
    func detachIsNotGatedByTheChannel() {
        #expect(GroupsAssociationLogic.offersDetach(.associated))
        #expect(GroupsAssociationLogic.offersDetach(.associatedNeedsSignIn))
    }
}

@Suite("GroupsAssociationSection · el CTA decide con el canal re-medido (source-scan)")
struct GroupsAssociationKillSwitchWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Código sin comentarios (de bloque y de línea): los docblocks de esta sección NOMBRAN lo que fijan, y
    /// contar la prosa haría que documentarlo bastara.
    private static func code(_ path: String) throws -> String {
        let raw = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        return raw.replacing(/\/\*[\s\S]*?\*\//, with: " ")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func flat(_ source: String) -> String {
        source.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static var section: String {
        get throws { flat(try code("Yala/App/Views/Settings/GroupsAssociationSection.swift")) }
    }

    /// El cuerpo de `requestSignIn()`, hasta la siguiente función.
    private static func requestSignInBody() throws -> String {
        let source = try Self.section
        let start = try #require(source.range(of: "private func requestSignIn() {"))
        let rest = source[start.upperBound...]
        let end = rest.range(of: "private func ")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }

    @Test("Los dos botones pasan por `requestSignIn`; ninguno llama a `onAssociate` directo")
    func bothButtonsGoThroughTheGate() throws {
        let source = try Self.section
        #expect(source.components(separatedBy: "Button(action: requestSignIn)").count - 1 == 2, """
            «Asociar» y «Entrar» tienen que pasar los dos por `requestSignIn`: un botón que no lo haga vuelve a \
            emitir el sign-in con el canal matado.
            """)
        #expect(!source.contains("action: onAssociate"), """
            Un botón llama a `onAssociate` directo: se salta el canal re-medido.
            """)
    }

    @Test("El refresco forzado va ANTES de leer el flag, y solo el canal encendido emite el intent")
    func refreshBeforeReadingTheFlag() throws {
        let body = try Self.requestSignInBody()
        let refresh = try #require(body.range(of: "await RemoteConfigClient.shared.refreshIfDue(force: true)"),
                                   "`requestSignIn` ya no fuerza el refresco: decide con un snapshot de hasta 6 h.")
        let read = try #require(body.range(of: "if CloudSyncFlags.groupsBackendEnabled { onAssociate() } else {"),
                                "`onAssociate()` ya no vive dentro de la rama del canal encendido.")
        #expect(refresh.upperBound <= read.lowerBound, """
            El flag se lee ANTES del refresco forzado: es medir el snapshot viejo, que es exactamente el bug.
            """)
        #expect(body.components(separatedBy: "onAssociate()").count - 1 == 1, """
            `onAssociate()` aparece fuera de la rama del canal encendido.
            """)
    }

    @Test("La puerta se pinta desde la tabla, con el flag COMPUESTO")
    func entryComesFromTheTableWithTheCompositeFlag() throws {
        let source = try Self.section
        #expect(source.contains("GroupsAssociationLogic.signInEntry(state, channelOn: channelOn)"))
        #expect(source.contains("private var channelOn: Bool { _ = refreshTick return CloudSyncFlags.groupsBackendEnabled }"), """
            `channelOn` dejó de leer el getter compuesto. El remoto a secas ignora el compilado y la capacidad \
            compilada ignora el kill, que es lo que este ticket arregla.
            """)
        // Desde el `switch` de la puerta: el fichero tiene otro `case .channelPaused:` antes, el del aviso de bloqueo
        // del desasociar, que es otro enum.
        let entrySwitch = try #require(source.range(of: "switch signInEntry {"))
        let paused = try #require(source[entrySwitch.upperBound...].range(of: "case .channelPaused:"))
        let after = source[paused.upperBound...]
        let end = try #require(after.range(of: "case .none:"))
        #expect(!after[..<end.lowerBound].contains("Button"), "En pausa vuelve a haber un botón.")
        #expect(after[..<end.lowerBound].contains("L10n.Storage.Groups.channelPausedNote"))
    }
}
