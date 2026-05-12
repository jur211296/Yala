//
//  RecordsMotivationalLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para RecordsMotivationalLogic.subtitle(forCount:).
//  Sin SwiftData, sin UI, sin singletons. Cubre casos límite (0, negativo)
//  y los dos casos no-vacíos (1 → .one, N≥2 → .many(N)).
//

import Foundation
import Testing

@testable import Yala

struct RecordsMotivationalLogicTests {

    @Test func subtitle_zero_returnsNil() {
        let result = RecordsMotivationalLogic.subtitle(forCount: 0)
        #expect(result == nil)
    }

    @Test func subtitle_negative_returnsNil() {
        let result = RecordsMotivationalLogic.subtitle(forCount: -1)
        #expect(result == nil)
    }

    @Test func subtitle_one_returnsOneCase() {
        let result = RecordsMotivationalLogic.subtitle(forCount: 1)
        #expect(result == .one)
    }

    @Test func subtitle_two_returnsManyTwo() {
        let result = RecordsMotivationalLogic.subtitle(forCount: 2)
        #expect(result == .many(2))
    }

    @Test func subtitle_largeCount_returnsManyValue() {
        let result = RecordsMotivationalLogic.subtitle(forCount: 999)
        #expect(result == .many(999))
    }
}
