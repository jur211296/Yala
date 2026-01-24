//
//  TagTests.swift
//  NetoTests
//
//  Unit tests for Tag model static methods (pure functions, no SwiftData).
//

import Foundation
import Testing

@testable import Yala

// MARK: - Tag Static Methods Tests

struct TagTests {

    // MARK: - defaultColors Tests

    @Test func defaultColors_has15Colors() {
        #expect(Tag.defaultColors.count == 15)
    }

    @Test func defaultColors_allAreValidHex() {
        for color in Tag.defaultColors {
            #expect(color.hasPrefix("#"))
            #expect(color.count == 7)  // #RRGGBB format
        }
    }

    @Test func defaultColors_allAreUnique() {
        let uppercased = Tag.defaultColors.map { $0.uppercased() }
        let unique = Set(uppercased)
        #expect(unique.count == Tag.defaultColors.count)
    }

    @Test func defaultColors_noBlackOrWhite() {
        let blackish = ["#000000", "#111111", "#222222"]
        let whitish = ["#FFFFFF", "#FEFEFE", "#FDFDFD"]
        let forbidden = Set(blackish + whitish)

        for color in Tag.defaultColors {
            #expect(!forbidden.contains(color.uppercased()))
        }
    }

    // MARK: - nextAvailableColor Tests

    @Test func nextAvailableColor_returnsFirstWhenNoneUsed() {
        let result = Tag.nextAvailableColor(excluding: [])
        #expect(result == Tag.defaultColors[0])
    }

    @Test func nextAvailableColor_skipsUsedColors() {
        // Use first color
        let used = [Tag.defaultColors[0]]
        let result = Tag.nextAvailableColor(excluding: used)
        #expect(result == Tag.defaultColors[1])
    }

    @Test func nextAvailableColor_isCaseInsensitive() {
        // Use first color in lowercase
        let used = [Tag.defaultColors[0].lowercased()]
        let result = Tag.nextAvailableColor(excluding: used)
        #expect(result == Tag.defaultColors[1])
    }

    @Test func nextAvailableColor_cyclesWhenAllUsed() {
        // Use all 15 colors
        let result = Tag.nextAvailableColor(excluding: Tag.defaultColors)
        #expect(result == Tag.defaultColors[0])
    }

    @Test func nextAvailableColor_findsGapsInMiddle() {
        // Use colors 0, 1, 3 (skip 2)
        let used = [
            Tag.defaultColors[0],
            Tag.defaultColors[1],
            Tag.defaultColors[3],
        ]
        let result = Tag.nextAvailableColor(excluding: used)
        #expect(result == Tag.defaultColors[2])
    }

    @Test func nextAvailableColor_handlesPartialUsage() {
        // Use first 10 colors
        let used = Array(Tag.defaultColors.prefix(10))
        let result = Tag.nextAvailableColor(excluding: used)
        #expect(result == Tag.defaultColors[10])
    }
}
