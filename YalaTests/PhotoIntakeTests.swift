//
//  PhotoIntakeTests.swift
//  YalaTests
//
//  YALA-IOS-B (2026-11-12): una foto que se iba a leer entraba a tamaño completo y SwiftUI la decodificaba entera al
//  pintarla, también en una miniatura. Diez de 48 MP subieron la app de 65 MB a 1.929 MB en el simulador. Esto fija que
//  entran reducidas, que se pintan sin esa copia y que todas las puertas de entrada pasan por `PhotoIntake`.
//

import Foundation
import ImageIO
import SwiftUI
import Testing
import UIKit
import UniformTypeIdentifiers

@testable import Yala

@MainActor
@Suite("Fotos que entran reducidas", .serialized)
struct PhotoIntakeTests {

    /// Un JPEG del tamaño dado, con la orientación EXIF que se pida.
    static func jpeg(width: Int, height: Int, orientation: Int = 1) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            for i in 0..<32 {
                UIColor(hue: CGFloat(i) / 32, saturation: 0.8, brightness: 0.9, alpha: 1).setFill()
                ctx.fill(CGRect(x: CGFloat(i * width / 32), y: 0, width: CGFloat(width / 32 + 1), height: CGFloat(height)))
            }
        }
        guard let cgImage = image.cgImage else { return Data() }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return Data()
        }
        CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        CGImageDestinationFinalize(destination)
        return output as Data
    }

    static func footprintMB() -> Int {
        MemoryDiagnosticsLogic.megabytes(MemoryFootprint.current()?.footprintBytes ?? 0)
    }

    @Test("una foto de 48 MP entra con el lado mayor pedido")
    func reducesABigPhoto() throws {
        let image = try #require(PhotoIntake.image(from: Self.jpeg(width: 8064, height: 6048), maxEdge: 2048))
        #expect(PhotoIntake.longestPixelEdge(of: image) == 2048)
        #expect(image.scale == 1)
    }

    @Test("una foto que ya cabe no se amplía")
    func keepsASmallPhoto() throws {
        let image = try #require(PhotoIntake.image(from: Self.jpeg(width: 800, height: 600), maxEdge: 2048))
        #expect(PhotoIntake.longestPixelEdge(of: image) == 800)
    }

    @Test("la orientación de la cámara se aplica al reducir")
    func appliesOrientation() throws {
        // EXIF 6: la foto se guardó apaisada y se ve en vertical.
        let image = try #require(PhotoIntake.image(from: Self.jpeg(width: 4000, height: 3000, orientation: 6), maxEdge: 2048))
        #expect(image.size.height > image.size.width)
        #expect(image.imageOrientation == .up)
    }

    @Test("lo que no es una imagen no entra")
    func rejectsNonImages() {
        #expect(PhotoIntake.image(from: Data("no es una foto".utf8), maxEdge: 2048) == nil)
        #expect(PhotoIntake.image(from: Data(), maxEdge: 2048) == nil)
    }

    @Test("fuera del hilo principal da la misma foto reducida")
    func offMainActorMatches() async throws {
        let image = try #require(await PhotoIntake.imageOffMainActor(from: Self.jpeg(width: 8064, height: 6048), maxEdge: 2048))
        #expect(PhotoIntake.longestPixelEdge(of: image) == 2048)
    }

    @Test("la foto de la cámara también se reduce, y la que cabe sale igual")
    func reducesACameraImage() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let big = UIGraphicsImageRenderer(size: CGSize(width: 5712, height: 4284), format: format).image { _ in }
        #expect(PhotoIntake.longestPixelEdge(of: PhotoIntake.image(reducing: big, maxEdge: 2048)) == 2048)
        let small = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 750), format: format).image { _ in }
        #expect(PhotoIntake.image(reducing: small, maxEdge: 2048) === small)
    }

    @Test("el lado al entrar es el del gateway, nunca por debajo de 2048")
    func intakeEdge() {
        #expect(PhotoIntake.intakeMaxEdge(remote: nil) == 2048)
        #expect(PhotoIntake.intakeMaxEdge(remote: 1536) == 2048)
        #expect(PhotoIntake.intakeMaxEdge(remote: 3000) == 3000)
        // Un valor fuera de rango del gateway cae al de por defecto, como en la subida.
        #expect(PhotoIntake.intakeMaxEdge(remote: 50_000) == 2048)
    }

    @Test("cuatro fotos de 48 MP pintadas con SwiftUI no suben la memoria cientos de MB")
    func paintedPhotosStaySmall() async throws {
        let data = Self.jpeg(width: 8064, height: 6048)
        let base = Self.footprintMB()
        let images = (0..<4).compactMap { _ in PhotoIntake.image(from: data, maxEdge: 2048) }
        #expect(images.count == 4)
        // La escena del host de tests: con ella la ventana pinta como en la app (y sin el `init(frame:)` obsoleto).
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: PaintedPhotos(images: images))
        window.makeKeyAndVisible()
        for _ in 0..<4 {
            window.layoutIfNeeded()
            CATransaction.flush()
            try await Task.sleep(for: .milliseconds(100))
        }
        let painted = Self.footprintMB()
        window.isHidden = true
        // A tamaño completo son ~185 MB por foto (medido: diez subieron 1.864 MB). Reducidas, ~12 MB cada una.
        #expect(painted - base < 200, "la memoria subió \(painted - base) MB al pintar cuatro fotos")
    }

    // MARK: - Puertas de entrada

    /// Las vistas por donde entra una foto que se va a leer o a guardar no la decodifican a tamaño completo.
    @Test("toda foto que se lee o se guarda como perfil entra por PhotoIntake")
    func everyEntryGoesThroughIntake() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        // Cuántos `UIImage(data:)` admite cada una. El de Datos personales carga la foto YA GUARDADA, que
        // `ProfileImageStorage` reduce a 512 px al guardar.
        let files: [(path: String, allowed: Int)] = [
            ("Yala/App/Views/Image/ImageSelectionView.swift", 0),
            ("Yala/App/Logic/PDFPageImport.swift", 0),
            ("Yala/App/Views/Groups/GroupReceiptSplitView.swift", 0),
            ("Yala/App/Views/Profile/PersonalDetailsView.swift", 1),
            ("Yala/App/Commands/RootCommandsModifier.swift", 0),
        ]
        for file in files {
            let code = try Self.codeOnly(String(contentsOf: root.appendingPathComponent(file.path), encoding: .utf8))
            let decodes = code.components(separatedBy: "UIImage(data:").count - 1
            #expect(decodes == file.allowed, "\(file.path) decodifica \(decodes) fotos enteras con UIImage(data:)")
            #expect(code.contains("PhotoIntake.image"), "\(file.path) no pasa por PhotoIntake")
        }
        let profile = try Self.codeOnly(String(
            contentsOf: root.appendingPathComponent("Yala/App/Views/Profile/PersonalDetailsView.swift"), encoding: .utf8))
        #expect(profile.contains("ProfileImageStorage.shared.imageData"))
        // La cámara entrega un UIImage: las dos vistas con cámara lo reducen al recibirlo.
        for file in ["Yala/App/Views/Image/ImageSelectionView.swift", "Yala/App/Views/Groups/GroupReceiptSplitView.swift"] {
            let code = try Self.codeOnly(String(contentsOf: root.appendingPathComponent(file), encoding: .utf8))
            #expect(code.contains("PhotoIntake.image(reducing:"), "\(file) guarda la foto de la cámara sin reducir")
        }
    }

    /// El código sin comentarios: documentar la regla no puede ponerla en rojo.
    static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let range = line.range(of: "//") else { return line }
                return line[..<range.lowerBound]
            }
            .joined(separator: "\n")
    }
}

private struct PaintedPhotos: View {
    let images: [UIImage]
    var body: some View {
        VStack {
            Image(uiImage: images[0]).resizable().scaledToFit().frame(height: 300)
            HStack {
                ForEach(images.indices, id: \.self) { index in
                    Image(uiImage: images[index]).resizable().scaledToFill().frame(width: 60, height: 45).clipped()
                }
            }
        }
    }
}
