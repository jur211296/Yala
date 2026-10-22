//
//  SplitMemberResolvedDisplayNameTests.swift
//  YalaTests
//
//  G5-D1b: al eliminar su cuenta, `groups_forget_user` anonimiza el `display_name` del member al sentinel
//  `__deleted_user__`. `SplitMember.resolvedDisplayName` lo mapea a la key l10n; cualquier otro nombre pasa
//  crudo. Estos tests fijan el mapeo (@Model directos, sin contexto — más rápido y sin acoplamiento).
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct SplitMemberResolvedDisplayNameTests {

    @Test func sentinel_mapsToLocalizedDeletedUser() {
        let member = SplitMember(groupZoneID: "z", displayName: SplitMember.deletedUserSentinel)
        #expect(member.resolvedDisplayName == L10n.Groups.Member.deletedUser)
        #expect(member.resolvedDisplayName != SplitMember.deletedUserSentinel)
    }

    @Test func normalName_passesThroughUnchanged() {
        let member = SplitMember(groupZoneID: "z", displayName: "Ana")
        #expect(member.resolvedDisplayName == "Ana")
    }

    @Test func emptyName_passesThroughUnchanged() {
        // El sentinel es un valor EXACTO; un nombre vacío NO es el sentinel y no se traduce.
        let member = SplitMember(groupZoneID: "z", displayName: "")
        #expect(member.resolvedDisplayName == "")
    }

    @Test func sentinelConstant_matchesServerContract() {
        // El sentinel del cliente DEBE coincidir con el de `groups_forget_user` server-side.
        #expect(SplitMember.deletedUserSentinel == "__deleted_user__")
    }
}
