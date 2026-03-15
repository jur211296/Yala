import Foundation

/// Service for accessing the shared App Group container
/// Used for communication between the main app and Share Extension
enum SharedContainerService {

    /// App Group identifier read from Info.plist (set via Build Settings)
    /// Falls back to production value for migration safety
    static var appGroupIdentifier: String {
        Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String
            ?? "group.com.jurgenschmidt.yala"
    }

    /// URL to the shared container directory
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// Directory for pending shared images
    static var pendingImagesURL: URL? {
        containerURL?.appendingPathComponent("PendingImages", isDirectory: true)
    }

    /// Creates the pending images directory if it doesn't exist
    static func ensurePendingImagesDirectory() {
        guard let url = pendingImagesURL else { return }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            #if DEBUG
            print("SharedContainerService: Error creating pending images directory: \(error)")
            #endif
        }
    }

    /// Returns all pending image URLs
    static func pendingImageURLs() -> [URL] {
        guard let url = pendingImagesURL else { return [] }
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            return contents.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" }
        } catch {
            #if DEBUG
            print("SharedContainerService: Error listing pending images: \(error)")
            #endif
            return []
        }
    }

    /// Removes a processed image
    static func removePendingImage(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Removes pending images older than the given age in seconds
    static func clearOldPendingImages(olderThan maxAge: TimeInterval) {
        guard let url = pendingImagesURL else { return }
        let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )
        let cutoff = Date.now.addingTimeInterval(-maxAge)
        for fileURL in contents ?? [] {
            guard let values = try? fileURL.resourceValues(forKeys: [.creationDateKey]),
                  let created = values.creationDate,
                  created < cutoff else { continue }
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
