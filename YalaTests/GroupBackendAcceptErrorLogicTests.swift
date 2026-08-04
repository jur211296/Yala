//
//  GroupBackendAcceptErrorLogicTests.swift
//  YalaTests
//
//  Contrato C4 (G4-invites): los 13 casos de `GroupsRPCError` → 6 `ErrorKind` + isPermanent + slug.
//

import Foundation
import Testing

@testable import Yala

struct GroupBackendAcceptErrorLogicTests {

    typealias L = GroupBackendAcceptErrorLogic

    @Test func classify_allThirteenCases() {
        #expect(L.classify(.invalidInvite) == .invalidInvite)
        #expect(L.classify(.sessionExpired) == .sessionRequired)
        #expect(L.classify(.notAuthorized) == .notAuthorized)
        #expect(L.classify(.transient(status: 503)) == .transient)
        #expect(L.classify(.transient(status: -1)) == .transient)
        // Kill-switch server-side del canal (403 yala_groups_disabled): kind PROPIO, jamás `.generic`.
        // Colapsarlo en `.generic` limpiaría el intent y quemaría la invitación del usuario por una
        // decisión de configuración que se revierte con un deploy.
        #expect(L.classify(.channelDisabled) == .channelDisabled)
        // Resto → generic.
        #expect(L.classify(.badInput) == .generic)
        #expect(L.classify(.groupExists) == .generic)
        #expect(L.classify(.invalidGroupID) == .generic)
        #expect(L.classify(.memberNotFound) == .generic)
        #expect(L.classify(.cannotRemoveOwner) == .generic)
        #expect(L.classify(.ownerCannotLeave) == .generic)
        #expect(L.classify(.permanentRejected(code: "yala_xyz")) == .generic)
        #expect(L.classify(.decoding) == .generic)
    }

    @Test func isPermanent_onlyPermanentKinds() {
        #expect(L.isPermanent(.invalidInvite))
        #expect(L.isPermanent(.notAuthorized))
        #expect(L.isPermanent(.generic))
        // NO permanentes: el reconciler reintenta / re-presenta sign-in.
        #expect(!L.isPermanent(.transient))
        #expect(!L.isPermanent(.sessionRequired))
        // El canal apagado se LEVANTA con un deploy y sin que el usuario haga nada ⇒ el intent se
        // conserva y el join se completa solo. Si esto fuera `true`, el invitado tendría que pedir un
        // enlace nuevo que tampoco haría falta.
        #expect(!L.isPermanent(.channelDisabled))
    }

    @Test func slug_stableAndCarriesCodeForPermanentRejected() {
        #expect(L.slug(for: .invalidInvite) == "invalidInvite")
        #expect(L.slug(for: .notAuthorized) == "notAuthorized")
        #expect(L.slug(for: .sessionExpired) == "sessionRequired")
        #expect(L.slug(for: .transient(status: 500)) == "transient")
        #expect(L.slug(for: .badInput) == "generic")
        #expect(L.slug(for: .permanentRejected(code: "yala_weird")) == "generic:yala_weird")
        // Slug PROPIO (no "generic", no "transient"): en un incidente el canario tiene que decir que el
        // join se aplazó por el kill-switch y no por una red mala.
        #expect(L.slug(for: .channelDisabled) == "channelDisabled")
    }
}
