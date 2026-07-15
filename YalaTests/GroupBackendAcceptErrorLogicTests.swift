//
//  GroupBackendAcceptErrorLogicTests.swift
//  YalaTests
//
//  Contrato C4 (G4-invites): los 12 casos de `GroupsRPCError` → 5 `ErrorKind` + isPermanent + slug.
//

import Foundation
import Testing

@testable import Yala

struct GroupBackendAcceptErrorLogicTests {

    typealias L = GroupBackendAcceptErrorLogic

    @Test func classify_allTwelveCases() {
        #expect(L.classify(.invalidInvite) == .invalidInvite)
        #expect(L.classify(.sessionExpired) == .sessionRequired)
        #expect(L.classify(.notAuthorized) == .notAuthorized)
        #expect(L.classify(.transient(status: 503)) == .transient)
        #expect(L.classify(.transient(status: -1)) == .transient)
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
    }

    @Test func slug_stableAndCarriesCodeForPermanentRejected() {
        #expect(L.slug(for: .invalidInvite) == "invalidInvite")
        #expect(L.slug(for: .notAuthorized) == "notAuthorized")
        #expect(L.slug(for: .sessionExpired) == "sessionRequired")
        #expect(L.slug(for: .transient(status: 500)) == "transient")
        #expect(L.slug(for: .badInput) == "generic")
        #expect(L.slug(for: .permanentRejected(code: "yala_weird")) == "generic:yala_weird")
    }
}
