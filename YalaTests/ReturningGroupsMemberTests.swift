//
//  ReturningGroupsMemberTests.swift
//  YalaTests
//
//  Card «Al volver a entrar por "Vengo por un grupo" con la misma cuenta, Yala pide otra vez el consentimiento de
//  Grupos y tu nombre» (QA guiado del 19-oct, A · C6).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Vengo por un grupo · quien vuelve con la misma cuenta no contesta otra vez")
struct ReturningGroupsMemberTests {

    private let sub = "5D1C6A0E-AAAA-4BBB-8CCC-000000000001"

    private func member(_ name: String, userID: String? = nil, key: String? = nil,
                        status: SplitMemberStatus = .active, joined: TimeInterval = 0) -> ReturningGroupsMemberLogic.Member {
        .init(userID: userID, memberKey: key, status: status.rawValue, displayName: name,
              joinedAt: Date(timeIntervalSince1970: 1_800_000_000 + joined))
    }

    @Test("La fila activa de la cuenta con nombre da su nombre; la más reciente gana")
    func returningName() {
        let members = [member("Jür", userID: sub, joined: 0),
                       member("Jürgen", key: sub.lowercased(), joined: 100),
                       member("Pía", userID: "otra")]
        #expect(ReturningGroupsMemberLogic.returningName(members: members, currentUserID: sub) == "Jürgen")
    }

    @Test("Sin fila suya (cuenta nueva o el canal aún no bajó nada), se pregunta")
    func newAccountAsks() {
        #expect(ReturningGroupsMemberLogic.returningName(members: [member("Pía", userID: "otra")], currentUserID: sub) == nil)
        #expect(ReturningGroupsMemberLogic.returningName(members: [], currentUserID: sub) == nil)
    }

    @Test("Una fila que ya no está activa, o sin nombre, no cuenta; sin sesión tampoco")
    func onlyActiveNamedRowsOfTheSession() {
        #expect(ReturningGroupsMemberLogic.returningName(
            members: [member("Jür", userID: sub, status: .left)], currentUserID: sub) == nil)
        #expect(ReturningGroupsMemberLogic.returningName(
            members: [member("   ", userID: sub)], currentUserID: sub) == nil)
        #expect(ReturningGroupsMemberLogic.returningName(
            members: [member("Jür", userID: sub)], currentUserID: nil) == nil)
    }

    @Test("Solo esperan los destinos que siguen la cadena; el bloqueo y la adopción presentan en el acto")
    func whoWaits() {
        #expect(GroupsSignInSettle.waitsBeforeRouting(.continueGroupsSetup))
        #expect(GroupsSignInSettle.waitsBeforeRouting(.associateGroupsAccount))
        #expect(GroupsSignInSettle.waitsBeforeRouting(nil))
        #expect(!GroupsSignInSettle.waitsBeforeRouting(.blockedAccountIsComplete))
        #expect(!GroupsSignInSettle.waitsBeforeRouting(.adoptAsCompleteAndOpenGroups))
    }

    // MARK: - Cableado

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    private static func code(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relative), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("La puerta espera la lectura del consentimiento de la cuenta antes de decidir")
    func consentDoorWaits() throws {
        let code = try Self.code("Yala/App/Views/Shared/GroupsBackendInviteModifier.swift")
        #expect(code.contains("consentRefresh = Task { @MainActor in await GroupsConsentRegistrar.shared.handleSignIn() }"),
                "la lectura del consentimiento volvió a lanzarse sin guardarla para esperarla")
        let inicio = try #require(code.range(of: ".sheet(isPresented: $showGroupsSignIn, onDismiss: {"))
        let tramo = code[inicio.upperBound...].prefix(1800)
        // Los destinos que siguen la cadena esperan; solo el bloqueo y la adopción deciden antes.
        let filtro = try #require(tramo.range(of: "guard GroupsSignInSettle.waitsBeforeRouting(destino) else {"))
        let espera = try #require(tramo.range(of: "await GroupsSignInSettle.wait(consentRefresh: refresh"))
        #expect(filtro.lowerBound < espera.lowerBound)
        let decide = try #require(tramo.range(of: "routeIdentityDestination(destino)", range: espera.upperBound..<tramo.endIndex),
                                  "tras esperar, la puerta ya no decide")
        #expect(espera.lowerBound < decide.lowerBound, "la puerta decide antes de leer el consentimiento de la cuenta")
    }

    @Test("El paso del nombre completa el alta con el nombre que la cuenta ya tiene, antes de abrir el formulario")
    func namePathUsesTheReturningName() throws {
        let code = try Self.code("Yala/App/ContentView.swift")
        let inicio = try #require(code.range(of: "case .presentName:"))
        let tramo = code[inicio.upperBound...].prefix(700)
        let nombre = try #require(tramo.range(of: "if let name = returningGroupsMemberName() {"))
        let formulario = try #require(tramo.range(of: "showGroupsOrganizerName = true"))
        #expect(nombre.lowerBound < formulario.lowerBound)
        #expect(tramo.contains("GroupsOrganizerOnboarding.completeSetup(displayName: name, context: modelContext)"))
        #expect(tramo.contains("navigation.selectedMainTab = .groups"))
    }
}
