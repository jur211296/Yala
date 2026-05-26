//
//  TagCatalogEnvironment.swift
//  Yala
//
//  SwiftUI EnvironmentKey for a global `[UUID: Tag]` catalog.
//
//  Used by display Rows + Logic readers to resolve Tag objects from the
//  `resolvedTagIDs(scheduleBackfill:)` SSOT without each consumer having to
//  declare its own `@Query<Tag>`. Built once by `TagCatalogProvider` at the
//  root of the view hierarchy and propagated via SwiftUI environment.
//
//  Default value `[:]` ensures the catalog is non-nil for all consumers; an
//  empty catalog gracefully shows no chips (instead of crashing) if the
//  provider is not yet mounted (e.g. during cold launch before `@Query`
//  resolves) or if a sheet hosts content outside the propagation tree.
//

import Foundation
import SwiftUI

private struct TagCatalogKey: EnvironmentKey {
    static let defaultValue: [UUID: Tag] = [:]
}

extension EnvironmentValues {
    var tagCatalog: [UUID: Tag] {
        get { self[TagCatalogKey.self] }
        set { self[TagCatalogKey.self] = newValue }
    }
}
