//
//  ProfileImageStorage.swift
//  Yala
//
//  Stores profile image in Documents directory instead of UserDefaults.
//

import Foundation

enum ProfileImageStorage {
    private static let fileName = "profile.jpg"

    private static var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fileName)
    }

    /// Save image data to Documents/profile.jpg
    static func save(_ data: Data) {
        guard let url = fileURL else { return }
        try? data.write(to: url)
    }

    /// Load image data from Documents/profile.jpg
    static func load() -> Data? {
        guard let url = fileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Delete the profile image file
    static func delete() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Migrate from UserDefaults to file if needed (one-time)
    static func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        let key = "userProfileImageData"
        guard let data = defaults.data(forKey: key) else { return }
        save(data)
        defaults.removeObject(forKey: key)
    }
}
