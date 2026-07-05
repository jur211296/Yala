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

    /// Returns all pending image URLs, ordenadas por fecha de creación DESCENDENTE
    /// (más reciente primero). `contentsOfDirectory` no garantiza orden, así que sin este
    /// sort `.first` elegiría una imagen arbitraria cuando hay 2+ pendientes — la
    /// recuperación debe presentar la ÚLTIMA compartida.
    static func pendingImageURLs() -> [URL] {
        guard let url = pendingImagesURL else { return [] }
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            let images = contents.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" }
            let dated = images.map { imageURL -> (url: URL, date: Date) in
                let date = (try? imageURL.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return (imageURL, date)
            }
            return orderByCreationDescending(dated)
        } catch {
            #if DEBUG
            print("SharedContainerService: Error listing pending images: \(error)")
            #endif
            return []
        }
    }

    /// Pure-logic testeable del orden de `pendingImageURLs`: más reciente primero.
    static func orderByCreationDescending(_ items: [(url: URL, date: Date)]) -> [URL] {
        items.sorted { $0.date > $1.date }.map(\.url)
    }

    /// Removes a processed image
    static func removePendingImage(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            #if DEBUG
            print("SharedContainerService: Error removing pending image: \(error)")
            #endif
        }
    }

    /// Removes pending images older than the given age in seconds
    static func clearOldPendingImages(olderThan maxAge: TimeInterval) {
        guard let url = pendingImagesURL else { return }
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
        } catch {
            #if DEBUG
            print("SharedContainerService: Error listing pending images for cleanup: \(error)")
            #endif
            return
        }
        let cutoff = Date.now.addingTimeInterval(-maxAge)
        for fileURL in contents {
            guard let values = try? fileURL.resourceValues(forKeys: [.creationDateKey]),
                  let created = values.creationDate,
                  created < cutoff else { continue }
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                #if DEBUG
                print("SharedContainerService: Error removing old image \(fileURL.lastPathComponent): \(error)")
                #endif
            }
        }
    }
}
