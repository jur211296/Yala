//
//  InboxHeroSubtitleLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para InboxHeroSubtitleLogic.subtitle(pendingCount:).
//  Sin SwiftData, sin UI, sin singletons.
//

import Foundation
import Testing

@testable import Yala

struct InboxHeroSubtitleLogicTests {

    @Test func subtitle_zero_returnsAllDone() {
        let result = InboxHeroSubtitleLogic.subtitle(pendingCount: 0)
        #expect(result == .allDone)
    }

    @Test func subtitle_negative_returnsAllDone() {
        let result = InboxHeroSubtitleLogic.subtitle(pendingCount: -3)
        #expect(result == .allDone)
    }

    @Test func subtitle_one_returnsOnePending() {
        let result = InboxHeroSubtitleLogic.subtitle(pendingCount: 1)
        #expect(result == .onePending)
    }

    @Test func subtitle_two_returnsMultiplePending() {
        let result = InboxHeroSubtitleLogic.subtitle(pendingCount: 2)
        #expect(result == .multiplePending(2))
    }

    @Test func subtitle_large_returnsMultiplePending() {
        let result = InboxHeroSubtitleLogic.subtitle(pendingCount: 999)
        #expect(result == .multiplePending(999))
    }
}
