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

struct CategoryChip: Identifiable {
    var id: PersistentIdentifier { categoryID }
    let categoryID: PersistentIdentifier
}

struct SubcategoryChip: Identifiable {
    var id: String { subcategoryID?.hashValue.description ?? name }
    let name: String
    let iconName: String?
    let colorHex: String?
    let subcategoryID: PersistentIdentifier?
}

struct TagChip: Identifiable {
    let id: PersistentIdentifier
    let tagID: PersistentIdentifier
    let name: String
    let iconName: String
    let colorHex: String?
}

struct NatureChipData: Identifiable {
    var id: String { nature.rawValue }
    let nature: SubcategoryNature
}
