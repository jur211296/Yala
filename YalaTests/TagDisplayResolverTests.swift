//
//  TagDisplayResolverTests.swift
//  YalaTests
//
//  Pure-logic tests for `TagDisplayResolver.resolve(ids:catalog:limit:)`.
//  Tests the static resolver without SwiftData — Models can be instantiated
//  directly for catalog construction.
//

import Foundation
import Testing

@testable import Yala

@Suite("Tag Display Resolver")
struct TagDisplayResolverTests {

    private func makeCatalog(_ tags: [Yala.Tag]) -> [UUID: Yala.Tag] {
        Yala.Tag.byIDLookup(tags)
    }

    @Test func resolvesTagsViaCatalog() {
        let t1 = Tag(name: "a")
        let t2 = Tag(name: "b")
        let catalog = makeCatalog([t1, t2])
        let resolved = TagDisplayResolver.resolve(
            ids: [t1.id, t2.id],
            catalog: catalog
        )
        #expect(resolved.count == 2)
        #expect(Set(resolved.map(\.name)) == ["a", "b"])
    }

    @Test func skipsOrphanedUUIDs() {
        let t1 = Tag(name: "a")
        let orphanID = UUID()
        let catalog = makeCatalog([t1])
        let resolved = TagDisplayResolver.resolve(
            ids: [t1.id, orphanID],
            catalog: catalog
        )
        #expect(resolved.count == 1)
        #expect(resolved.first?.name == "a")
    }

    @Test func limitPrefixRespected() {
        let tags = (0..<5).map { Tag(name: "tag\($0)") }
        let catalog = makeCatalog(tags)
        let ids = Set(tags.map(\.id))
        let resolved = TagDisplayResolver.resolve(ids: ids, catalog: catalog, limit: 3)
        #expect(resolved.count == 3)
    }

    @Test func emptyTagIDs_returnsEmpty() {
        let catalog = makeCatalog([Tag(name: "a")])
        let resolved = TagDisplayResolver.resolve(ids: [], catalog: catalog)
        #expect(resolved.isEmpty)
    }

    @Test func emptyCatalog_returnsEmpty() {
        let resolved = TagDisplayResolver.resolve(
            ids: [UUID(), UUID()],
            catalog: [:]
        )
        #expect(resolved.isEmpty)
    }

    @Test func limitGreaterThanResolvedCount_returnsAll() {
        let t1 = Tag(name: "a")
        let catalog = makeCatalog([t1])
        let resolved = TagDisplayResolver.resolve(
            ids: [t1.id],
            catalog: catalog,
            limit: 10
        )
        #expect(resolved.count == 1)
    }
}
