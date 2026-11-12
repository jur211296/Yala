//
//  ProfileImageDownsampleTests.swift
//  YalaTests
//
//  YALA-IOS-9 y YALA-IOS-A (2026-11-06): con una foto de perfil de 48 MP guardada a resolución completa, cada botón de
//  perfil de la barra superior (uno por pestaña) la decodificaba entera en cada dibujado: medido en el simulador, el
//  Panel solo llegaba a 672 MB y entrar y salir de Yala a 1,4 GB (sin foto: 106-178 MB). La foto se guarda reducida y
//  la que ya estaba guardada grande se reduce al leerla.
//

import Foundation
import ImageIO
import Testing
import UIKit

@testable import Yala

@MainActor
@Suite(.serialized)
struct ProfileImageDownsampleTests {

    private func jpeg(width: Int, height: Int) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            UIColor.systemIndigo.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return try #require(image.jpegData(compressionQuality: 0.7))
    }

    private func pixelSize(_ data: Data) throws -> (Int, Int) {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let props = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return (try #require(props[kCGImagePropertyPixelWidth] as? Int), try #require(props[kCGImagePropertyPixelHeight] as? Int))
    }

    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("profile-\(UUID().uuidString).jpg")
    }

    private func removeTempFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("ProfileImageDownsampleTests: Error: \(error)")
        }
    }

    @Test func aBigPhotoIsReducedToTheMaxSide() throws {
        let big = try jpeg(width: 4032, height: 3024)
        let reduced = try #require(ProfileImageStorage.downsampledJPEG(big, maxPixelSize: 512))
        let (w, h) = try pixelSize(reduced)
        #expect(max(w, h) == 512)
        #expect(w > h) // conserva la orientación
    }

    @Test func aPhotoThatAlreadyFitsIsLeftAlone() throws {
        let small = try jpeg(width: 400, height: 300)
        #expect(ProfileImageStorage.downsampledJPEG(small, maxPixelSize: 512) == nil)
        #expect(ProfileImageStorage.downsampledJPEG(Data("no es una imagen".utf8), maxPixelSize: 512) == nil)
    }

    @Test func saveStoresTheReducedPhoto_andDecodesItOnce() throws {
        let url = tempFile()
        defer { removeTempFile(url) }
        let storage = ProfileImageStorage(fileURL: url)

        storage.save(try jpeg(width: 4032, height: 3024))

        let onDisk = try Data(contentsOf: url)
        #expect(max(try pixelSize(onDisk).0, try pixelSize(onDisk).1) <= ProfileImageStorage.maxPixelSize)
        #expect(storage.imageData == onDisk)
        let image = try #require(storage.image)
        #expect(max(image.size.width * image.scale, image.size.height * image.scale) <= CGFloat(ProfileImageStorage.maxPixelSize))
    }

    /// Quien ya tenía la foto grande guardada (2.1, 2.2): se reduce y se reescribe al leerla.
    @Test func aBigPhotoAlreadyOnDiskIsReducedWhenRead() throws {
        let url = tempFile()
        defer { removeTempFile(url) }
        try jpeg(width: 3024, height: 4032).write(to: url)

        let storage = ProfileImageStorage(fileURL: url)

        let onDisk = try Data(contentsOf: url)
        let (w, h) = try pixelSize(onDisk)
        #expect(max(w, h) <= ProfileImageStorage.maxPixelSize)
        #expect(h > w)
        #expect(storage.imageData == onDisk)
        #expect(storage.image != nil)
    }

    @Test func deleteClearsTheDecodedImageToo() throws {
        let url = tempFile()
        let storage = ProfileImageStorage(fileURL: url)
        storage.save(try jpeg(width: 1000, height: 1000))
        #expect(storage.image != nil)

        storage.delete()

        #expect(storage.image == nil)
        #expect(storage.imageData == nil)
    }
}
