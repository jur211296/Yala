//
//  FavoritePaymentTagsCSVTests.swift
//  YalaTests
//
//  Pure-logic tests for FavoritePayment+TagsCSVMirror. No ModelContext.
//

import Foundation
import Testing

@testable import Yala

@Suite("FavoritePayment Tags CSV Mirror")
struct FavoritePaymentTagsCSVTests {

    // MARK: - Auto-mirror in init

    @Test func init_withEmptyTags_encodesNilCSV() {
        let favorite = FavoritePayment(name: "Gym")
        #expect(favorite.tagIDs == nil)
        #expect(favorite.tagIDsSet == nil)
    }

    @Test func init_withTags_autoMirrorsToCSV() {
        let t1 = Tag(name: "a")
        let t2 = Tag(name: "b")
        let favorite = FavoritePayment(name: "Coffee", tags: [t1, t2])
        let expected: Set<UUID> = [t1.id, t2.id]
        #expect(favorite.tagIDsSet == expected)
    }

    // MARK: - setTags dual-write

    @Test func setTags_emptyArray_encodesNil() {
        let favorite = FavoritePayment(name: "x", tags: [Tag(name: "old")])
        favorite.setTags(from: [])
        #expect(favorite.tagIDs == nil)
        #expect(favorite.tagIDsSet == nil)
        #expect(favorite.tags?.isEmpty == true)
    }

    @Test func setTags_multipleTags_encodesAll() {
        let favorite = FavoritePayment(name: "x")
        let t1 = Tag(name: "a")
        let t2 = Tag(name: "b")
        let t3 = Tag(name: "c")
        favorite.setTags(from: [t1, t2, t3])
        let expected: Set<UUID> = [t1.id, t2.id, t3.id]
        #expect(favorite.tagIDsSet == expected)
    }

    // MARK: - resolvedTagIDs preference

    @Test func resolvedTagIDs_prefersCSVOverM2M() {
        let favorite = FavoritePayment(name: "x")
        let csvTag = Tag(name: "csv")
        let m2mTag = Tag(name: "m2m")
        // Sim a CSV state that diverges from M2M (no debería ocurrir en flow normal,
        // pero el resolver siempre prefiere CSV).
        favorite.tagIDs = CSVMirrorCodec.encode([csvTag.id])
        favorite.tags = [m2mTag]
        #expect(favorite.resolvedTagIDs() == Set([csvTag.id]))
    }

    @Test func resolvedTagIDs_fallsBackToM2MWhenCSVNil() {
        let favorite = FavoritePayment(name: "x")
        let t1 = Tag(name: "a")
        favorite.tags = [t1]
        favorite.tagIDs = nil
        #expect(favorite.resolvedTagIDs() == Set([t1.id]))
    }
}
