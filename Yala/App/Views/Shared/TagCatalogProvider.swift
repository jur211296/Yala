//
//  TagCatalogProvider.swift
//  Yala
//
//  Root-level ViewModifier that builds a `[UUID: Tag]` catalog from a single
//  `@Query<Tag>` and injects it into the SwiftUI environment.
//
//  Performance: rebuilt whenever SwiftData reports a Tag change (creation,
//  edit, deletion). Tracked via `tagCatalogRebuilt` telemetry to validate
//  frequency post-deploy — if catalog rebuilds >10/session per p95, refactor
//  to an `@Observable` wrapper with `Equatable` on `Set<UUID>`.
//

import SwiftData
import SwiftUI

struct TagCatalogProvider: ViewModifier {

    @Query private var allTags: [Tag]

    func body(content: Content) -> some View {
        let catalog = Tag.byIDLookup(allTags)
        content
            .environment(\.tagCatalog, catalog)
            .onChange(of: allTags.count, initial: false) { _, _ in
                // Telemetry signal — only when count changes (proxy for catalog rebuild).
                // Edits to individual Tags also rebuild but are not tracked here to
                // keep telemetry volume low.
                MetricsService.canary(.tagCatalogRebuilt, value: Double(allTags.count))
            }
    }
}
