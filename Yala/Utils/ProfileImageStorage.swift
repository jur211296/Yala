//
//  ProfileImageStorage.swift
//  Yala
//
//  Stores profile image in Documents directory instead of UserDefaults.
//  Observable singleton so all views react to changes immediately.
//

import Foundation

@MainActor @Observable
final class ProfileImageStorage {
    static let shared = ProfileImageStorage()

    private(set) var imageData: Data?

    private let fileName = "profile.jpg"

    private var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fileName)
    }

    private init() {
        guard let url = fileURL,
              FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            imageData = try Data(contentsOf: url)
        } catch {
            #if DEBUG
            print("ProfileImageStorage: Error loading existing file: \(error)")
            #endif
        }
    }

    /// Save image data to Documents/profile.jpg
    func save(_ data: Data) {
        guard let url = fileURL else { return }
        do {
            try data.write(to: url)
        } catch {
            #if DEBUG
            print("ProfileImageStorage: Error saving: \(error)")
            #endif
        }
        imageData = data
    }

    /// Delete the profile image file
    func delete() {
        guard let url = fileURL else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            #if DEBUG
            print("ProfileImageStorage: Error deleting: \(error)")
            #endif
        }
        imageData = nil
    }

    /// Migrate from UserDefaults to file if needed (one-time)
    func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        let key = "userProfileImageData"
        guard let data = defaults.data(forKey: key) else { return }
        save(data)
        defaults.removeObject(forKey: key)
    }
}
