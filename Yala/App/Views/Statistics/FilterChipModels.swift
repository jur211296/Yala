//
//  FilterChipModels.swift
//  Yala
//
//  Shared chip models for filter display in Statistics tabs.
//

import SwiftData

struct AccountChip: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
}

struct TagChip: Identifiable {
    let id: PersistentIdentifier
    let tagID: PersistentIdentifier
    let name: String
    let iconName: String
    let colorHex: String?
}

struct NeedChipData: Identifiable {
    var id: String { need.rawValue }
    let need: SubcategoryNeed
}
