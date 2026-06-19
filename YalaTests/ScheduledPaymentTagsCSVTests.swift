//
//  ScheduledPaymentTagsCSVTests.swift
//  YalaTests
//
//  Pure-logic tests for ScheduledPayment+TagsCSVMirror. No ModelContext.
//

import Foundation
import Testing

@testable import Yala

@Suite("ScheduledPayment Tags CSV Mirror")
struct ScheduledPaymentTagsCSVTests {

    private func makePayment(tags: [Yala.Tag] = []) -> ScheduledPayment {
        ScheduledPayment(
            name: "Subscription",
            amount: 9.99,
            currencyCode: "USD",
            tags: tags,
            nextDueDate: Date.now
        )
    }

    // MARK: - Auto-mirror in init

    @Test func init_withEmptyTags_encodesNilCSV() {
        let payment = makePayment()
        #expect(payment.tagIDs == nil)
        #expect(payment.tagIDsSet == nil)
    }

    @Test func init_withTags_autoMirrorsToCSV() {
        let t1 = Tag(name: "a")
        let t2 = Tag(name: "b")
        let payment = makePayment(tags: [t1, t2])
        let expected: Set<UUID> = [t1.id, t2.id]
        #expect(payment.tagIDsSet == expected)
    }

    // MARK: - setTags dual-write

    @Test func setTags_emptyArray_encodesNil() {
        let payment = makePayment(tags: [Tag(name: "old")])
        payment.setTags(from: [])
        #expect(payment.tagIDs == nil)
        #expect(payment.tagIDsSet == nil)
        #expect(payment.tags?.isEmpty == true)
    }

    @Test func setTags_multipleTags_encodesAll() {
        let payment = makePayment()
        let t1 = Tag(name: "a")
        let t2 = Tag(name: "b")
        let t3 = Tag(name: "c")
        payment.setTags(from: [t1, t2, t3])
        let expected: Set<UUID> = [t1.id, t2.id, t3.id]
        #expect(payment.tagIDsSet == expected)
    }

    // MARK: - resolvedTagIDs preference

    @Test func resolvedTagIDs_prefersCSVOverM2M() {
        let payment = makePayment()
        let csvTag = Tag(name: "csv")
        let m2mTag = Tag(name: "m2m")
        payment.tagIDs = CSVMirrorCodec.encode([csvTag.id])
        payment.tags = [m2mTag]
        #expect(payment.resolvedTagIDs() == Set([csvTag.id]))
    }

    @Test func resolvedTagIDs_fallsBackToM2MWhenCSVNil() {
        let payment = makePayment()
        let t1 = Tag(name: "a")
        payment.tags = [t1]
        payment.tagIDs = nil
        #expect(payment.resolvedTagIDs() == Set([t1.id]))
    }
}
