//
//  ProfileImageStorage.swift
//  Yala
//
//  Stores profile image in Documents directory instead of UserDefaults.
//  Observable singleton so all views react to changes immediately.
//
//  La foto se guarda REDUCIDA (`maxPixelSize`) y se decodifica UNA vez (`image`). Antes se guardaba la foto de la
//  galería a resolución completa y cada botón de perfil —uno por pestaña— la decodificaba en cada dibujado: con una
//  foto de 48 MP (cámara del iPhone 18 Pro Max) cada copia son ~190 MB, el Panel solo llegaba a 672 MB y entrar y salir
//  de Yala pasaba de 1,4 GB, con cuelgues mientras se preparaba la imagen (YALA-IOS-9 y YALA-IOS-A, medido en el
//  simulador el 2026-11-06). La foto que ya estaba guardada grande se reduce la primera vez que se lee.
//

import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

@MainActor @Observable
final class ProfileImageStorage {
    static let shared = ProfileImageStorage()

    /// Lado mayor, en píxeles, de la foto guardada. El avatar más grande mide 90 pt (Ajustes) → 270 px a 3×.
    nonisolated static let maxPixelSize = 512

    private(set) var imageData: Data?

    /// La foto ya decodificada, compartida por todas las vistas. Ninguna vista decodifica `imageData` en su `body`.
    private(set) var image: UIImage?

    private let fileURL: URL?

    private convenience init() {
        self.init(
            fileURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("profile.jpg")
        )
    }

    /// `fileURL` inyectable para los tests; la app usa `shared` (Documents/profile.jpg).
    init(fileURL: URL?) {
        self.fileURL = fileURL
        guard let url = fileURL,
              FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let stored = try Data(contentsOf: url)
            if let reduced = Self.downsampledJPEG(stored, maxPixelSize: Self.maxPixelSize) {
                // Foto guardada antes de 2026-11-06 a resolución completa: se reduce una vez y se reescribe.
                write(reduced, to: url)
                setImageData(reduced)
            } else {
                setImageData(stored)
            }
        } catch {
            #if DEBUG
            print("ProfileImageStorage: Error loading existing file: \(error)")
            #endif
        }
    }

    /// Save image data to Documents/profile.jpg (reducida a `maxPixelSize`).
    func save(_ data: Data) {
        let reduced = Self.downsampledJPEG(data, maxPixelSize: Self.maxPixelSize) ?? data
        if let url = fileURL { write(reduced, to: url) }
        setImageData(reduced)
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
        setImageData(nil)
    }

    /// Migrate from UserDefaults to file if needed (one-time)
    func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        let key = "userProfileImageData"
        guard let data = defaults.data(forKey: key) else { return }
        save(data)
        defaults.removeObject(forKey: key)
    }

    // MARK: - Reducción

    /// JPEG con el lado mayor en `maxPixelSize`, o `nil` si `data` ya cabe (o no es una imagen). Usa ImageIO, que
    /// reduce al leer sin decodificar la foto entera en memoria.
    nonisolated static func downsampledJPEG(_ data: Data, maxPixelSize: Int) -> Data? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              max(width, height) > maxPixelSize else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, thumbnail, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    // MARK: - Privado

    private func setImageData(_ data: Data?) {
        imageData = data
        image = data.flatMap { UIImage(data: $0) }
    }

    private func write(_ data: Data, to url: URL) {
        do {
            try data.write(to: url)
        } catch {
            #if DEBUG
            print("ProfileImageStorage: Error saving: \(error)")
            #endif
        }
    }
}
