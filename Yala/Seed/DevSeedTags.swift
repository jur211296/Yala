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
            (L10n.DevSeed.tagWork, "#0A84FF", "briefcase.fill"),
            (L10n.DevSeed.tagVacation, "#FF9F0A", "airplane"),
            (L10n.DevSeed.tagShared, "#30D158", "person.2.fill"),
            (L10n.DevSeed.tagUrgent, "#FF375F", "exclamationmark.triangle.fill"),
            (L10n.DevSeed.tagFixed, "#5E5CE6", "pin.fill"),
        ]

        return definitions.map { def in
            let tag = Tag(name: def.name, colorHex: def.color, iconName: def.icon)
            context.insert(tag)
            return tag
        }
    }
}
#endif
