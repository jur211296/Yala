//
//  DevSeedTags.swift
//  Yala
//
//  Creates 5 tags for dev seed data.
//

#if DEBUG
import Foundation
import SwiftData

struct DevSeedTags {

    @MainActor
    static func create(in context: ModelContext) -> [Tag] {
        let definitions: [(name: String, color: String, icon: String)] = [
            ("Trabajo", "#0A84FF", "briefcase.fill"),
            ("Vacaciones", "#FF9F0A", "airplane"),
            ("Compartido", "#30D158", "person.2.fill"),
            ("Urgente", "#FF375F", "exclamationmark.triangle.fill"),
            ("Fijo", "#5E5CE6", "pin.fill"),
        ]

        return definitions.map { def in
            let tag = Tag(name: def.name, colorHex: def.color, iconName: def.icon)
            context.insert(tag)
            return tag
        }
    }
}
#endif
