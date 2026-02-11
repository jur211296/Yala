//
//  MerchantCanonicalizerTests.swift
//  YalaTests
//
//  Unit tests for MerchantCanonicalizer (pure functions, no SwiftData).
//

import Foundation
import Testing

@testable import Yala

struct MerchantCanonicalizerTests {

    // MARK: - canonicalize Tests

    @Test func canonicalize_removesDP() {
        #expect(MerchantCanonicalizer.canonicalize("DP*STARBUCKS") == "STARBUCKS")
    }

    @Test func canonicalize_removesIZI() {
        #expect(MerchantCanonicalizer.canonicalize("IZI*UBER") == "UBER")
    }

    @Test func canonicalize_removesSQ() {
        #expect(MerchantCanonicalizer.canonicalize("SQ *COFFEE") == "COFFEE")
    }

    @Test func canonicalize_removesPaypal() {
        #expect(MerchantCanonicalizer.canonicalize("PAYPAL *SHOP") == "SHOP")
    }

    @Test func canonicalize_removesMPOS() {
        #expect(MerchantCanonicalizer.canonicalize("MPOS*STORE") == "STORE")
    }

    @Test func canonicalize_removesSpecialChars() {
        let result = MerchantCanonicalizer.canonicalize("STAR #123!")
        #expect(result == "STAR 123")
    }

    @Test func canonicalize_collapsesSpaces() {
        #expect(MerchantCanonicalizer.canonicalize("STAR   BUCKS") == "STAR BUCKS")
    }

    @Test func canonicalize_trims() {
        #expect(MerchantCanonicalizer.canonicalize(" STARBUCKS ") == "STARBUCKS")
    }

    @Test func canonicalize_empty() {
        #expect(MerchantCanonicalizer.canonicalize("") == "")
    }

    // MARK: - similarity Tests

    @Test func similarity_identical() {
        #expect(MerchantCanonicalizer.similarity("STARBUCKS", "STARBUCKS") == 1.0)
    }

    @Test func similarity_different() {
        let result = MerchantCanonicalizer.similarity("ABC", "XYZ")
        #expect(result < 0.5)
    }

    @Test func similarity_emptyBoth() {
        #expect(MerchantCanonicalizer.similarity("", "") == 1.0)
    }
}
