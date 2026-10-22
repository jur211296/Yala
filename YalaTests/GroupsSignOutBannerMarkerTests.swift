//
//  GroupsSignOutBannerMarkerTests.swift
//  YalaTests
//
//  Marker one-shot del banner de re-entrada del tab Grupos (D2, §3.3.3). Defaults AISLADOS por test
//  (`makeIsolatedDefaults`) — jamás `.standard`.
//

import Foundation
import Testing

@testable import Yala

@Suite("GroupsSignOutBannerMarker · marker one-shot del banner de re-entrada (D2)")
struct GroupsSignOutBannerMarkerTests {

    @Test
    func defaultsToNotPending() {
        let d = makeIsolatedDefaults()
        #expect(GroupsSignOutBannerMarker.isPending(d) == false)
    }

    @Test
    func markPending_thenIsPending() {
        let d = makeIsolatedDefaults()
        GroupsSignOutBannerMarker.markPending(d)
        #expect(GroupsSignOutBannerMarker.isPending(d) == true)
    }

    @Test
    func clear_burnsTheMarker() {
        let d = makeIsolatedDefaults()
        GroupsSignOutBannerMarker.markPending(d)
        GroupsSignOutBannerMarker.clear(d)
        #expect(GroupsSignOutBannerMarker.isPending(d) == false)
    }

    @Test
    func clear_isIdempotent_whenNotPending() {
        let d = makeIsolatedDefaults()
        GroupsSignOutBannerMarker.clear(d)  // no-op, no debe crashear ni marcar pendiente
        #expect(GroupsSignOutBannerMarker.isPending(d) == false)
    }

    @Test
    func markPending_isIdempotent() {
        let d = makeIsolatedDefaults()
        GroupsSignOutBannerMarker.markPending(d)
        GroupsSignOutBannerMarker.markPending(d)
        #expect(GroupsSignOutBannerMarker.isPending(d) == true)
        GroupsSignOutBannerMarker.clear(d)
        #expect(GroupsSignOutBannerMarker.isPending(d) == false)
    }
}
