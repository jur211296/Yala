//
//  GroupsConsentPathLogicTests.swift
//  YalaTests
//
//  Card o8sc: cada aceptación del consentimiento de Grupos guarda en la cuenta por qué puerta entró la persona
//  (`organizer`, `invite` o `tab`). La hoja del consentimiento solo elegía entre las dos primeras, así que quien
//  aceptaba desde «Un último paso» en la pestaña quedaba registrado como `invite` (QA guiado de 2.1, 19-oct).
//

import Foundation
import Testing

@testable import Yala

@Suite("Grupos · la puerta del consentimiento")
struct GroupsConsentPathLogicTests {

    @Test("las tres puertas: organizador, invitación y pestaña")
    func threeDoors() {
        #expect(GroupsConsentPathLogic.path(organizerFlowActive: true, pendingJoinZone: nil) == "organizer")
        #expect(GroupsConsentPathLogic.path(organizerFlowActive: false, pendingJoinZone: "SplitGroup-1") == "invite")
        #expect(GroupsConsentPathLogic.path(organizerFlowActive: false, pendingJoinZone: "") == "tab")
        #expect(GroupsConsentPathLogic.path(organizerFlowActive: false, pendingJoinZone: nil) == "tab")
    }

    @Test("la rama del organizador manda aunque quede una zona apuntada")
    func organizerWins() {
        #expect(GroupsConsentPathLogic.path(organizerFlowActive: true, pendingJoinZone: "SplitGroup-1") == "organizer")
    }
}

/// Cableado: la hoja del consentimiento de la cadena decide su puerta con la función, y el educativo de la pestaña y el
/// de la rama del organizador conservan la suya. Sin esto la lógica podría estar perfecta y nadie llamarla.
@Suite("Grupos · la puerta del consentimiento (cableado)")
struct GroupsConsentPathWiringTests {

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    @Test("la hoja de la cadena elige la puerta con GroupsConsentPathLogic")
    func chainSheetUsesTheLogic() throws {
        let modifier = try source("Yala/App/Views/Shared/GroupsBackendInviteModifier.swift")
        #expect(modifier.contains(
            "GroupsConsentView(path: GroupsConsentPathLogic.path(\n                    organizerFlowActive: groupsOrganizerFlowActive, pendingJoinZone: pendingGroupsJoinZone))"))
        #expect(!modifier.contains("groupsOrganizerFlowActive ? \"organizer\" : \"invite\""),
                "vuelve la elección de dos puertas que registraba la pestaña como invitación")
    }

    @Test("los dos educativos conservan su puerta")
    func educationalsKeepTheirDoor() throws {
        #expect(try source("Yala/App/Theme/ViewModifiers.swift").contains("GroupsOnboardingView(consentPath: \"tab\")"))
        #expect(try source("Yala/App/Views/Shared/GroupsBackendInviteModifier.swift")
            .contains("GroupsOnboardingView(consentPath: \"organizer\", startsAtConsent: true)"))
    }
}
