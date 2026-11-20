//
//  PagoLogoPropioLogicTests.swift
//  YalaTests / PagoLogoPropio
//
//  Logo propio de un pago planificado (encargo del 2026-11-20), la parte sin almacén:
//   - la foto que se guarda: cuadrada, 256 × 256 px, JPEG pequeño, del centro de la foto; lo que no es imagen no entra;
//   - las referencias de Storage: una por foto, y solo `<uuid>.jpg` (nada que salga de la carpeta del usuario);
//   - la decisión de la pasada de Storage (`PagoLogoPropioPlan`): qué se sube, qué se baja, qué se borra y cuándo;
//   - los textos, en su tabla, en los 16 idiomas.
//

import Foundation
import ImageIO
import Testing
import UIKit

@testable import Yala

@Suite("Logo propio · foto, referencias y plan de Storage")
@MainActor
struct PagoLogoPropioLogicTests {

    /// Una foto apaisada: mitad izquierda roja, mitad derecha azul, y una franja verde en el centro.
    private func landscapePhoto(width: Int = 1200, height: Int = 600) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
            UIColor.blue.setFill(); ctx.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))
            UIColor.green.setFill(); ctx.fill(CGRect(x: width / 2 - 50, y: 0, width: 100, height: height))
        }
        return image.pngData() ?? Data()
    }

    private func pixelSize(of data: Data) -> (Int, Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (w, h)
    }

    // MARK: - La foto

    @Test func storedPhoto_isASquareJPEGOf256_andSmall() throws {
        let stored = try #require(PagoLogoPropioFoto.datosParaGuardar(desde: landscapePhoto()))
        #expect(stored.starts(with: [0xFF, 0xD8]), "se guarda en JPEG")
        let size = try #require(pixelSize(of: stored))
        #expect(size.0 == 256 && size.1 == 256)
        #expect(stored.count < 100 * 1024, "cabe en el límite del bucket (100 KB): \(stored.count) bytes")
    }

    /// El recorte es el cuadrado del CENTRO: la franja verde del medio queda en el medio, y los bordes son los colores
    /// de cada mitad (con un recorte a la izquierda, el borde derecho saldría verde o rojo, nunca azul).
    @Test func storedPhoto_isTheCentreSquare() throws {
        let stored = try #require(PagoLogoPropioFoto.datosParaGuardar(desde: landscapePhoto()))
        let image = try #require(UIImage(data: stored)?.cgImage)
        let context = try #require(CGContext(data: nil, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 256 * 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 256, height: 256))
        let pixels = try #require(context.data?.assumingMemoryBound(to: UInt8.self))
        func rgb(_ x: Int, _ y: Int) -> (Int, Int, Int) {
            let i = (y * 256 + x) * 4
            return (Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2]))
        }
        let left = rgb(5, 128), centre = rgb(128, 128), right = rgb(250, 128)
        #expect(left.0 > 200 && left.2 < 60, "borde izquierdo rojo: \(left)")
        #expect(centre.1 > 200 && centre.0 < 60, "centro verde: \(centre)")
        #expect(right.2 > 200 && right.0 < 60, "borde derecho azul: \(right)")
    }

    @Test func notAnImage_isNotStored() {
        #expect(PagoLogoPropioFoto.datosParaGuardar(desde: Data("no es una foto".utf8)) == nil)
        #expect(PagoLogoPropioFoto.datosParaGuardar(desde: Data()) == nil)
    }

    // MARK: - Referencias

    @Test func eachPhotoGetsItsOwnReference_andOnlyThatShapeIsAccepted() {
        let a = PagoLogoPropioFoto.nuevaReferencia(), b = PagoLogoPropioFoto.nuevaReferencia()
        #expect(a != b)
        #expect(PagoLogoPropioFoto.esReferenciaValida(a))
        for bad in ["", "foto.jpg", "../otro/\(UUID().uuidString).jpg", "\(UUID().uuidString).png",
                    "\(UUID().uuidString)/x.jpg", UUID().uuidString] {
            #expect(!PagoLogoPropioFoto.esReferenciaValida(bad), "«\(bad)» no debería aceptarse")
        }
    }

    // MARK: - El plan de Storage

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let refA = "0f5e8a1c-1d2e-4f30-8a4b-5c6d7e8f9a0b.jpg"
    private let refB = "1a2b3c4d-1d2e-4f30-8a4b-5c6d7e8f9a0b.jpg"
    private let refOld = "2b3c4d5e-1d2e-4f30-8a4b-5c6d7e8f9a0b.jpg"

    @Test func plan_uploadsWhatIsNotThere_downloadsWhatIsMissingHere() {
        let p1 = UUID(), p2 = UUID(), p3 = UUID()
        let actions = PagoLogoPropioPlan.actions(
            local: [.init(id: p1, ref: refA, hasPhoto: true),     // elegida aquí, sin subir
                    .init(id: p2, ref: refB, hasPhoto: false),    // elegida en el otro teléfono
                    .init(id: p3, ref: nil, hasPhoto: true)],     // llegó de iCloud sin referencia
            remote: [.init(name: refB, createdAt: now)],
            pullComplete: true, now: now)
        #expect(actions.assignRef == [p3])
        #expect(actions.upload == [refA])
        #expect(actions.download == [refB])
        #expect(actions.delete.isEmpty)
    }

    /// La referencia que el otro teléfono aún no subió: no se baja (no hay nada) y se reintenta la pasada siguiente.
    @Test func plan_aReferenceNotYetUploaded_isNotDownloaded() {
        let actions = PagoLogoPropioPlan.actions(local: [.init(id: UUID(), ref: refA, hasPhoto: false)],
                                                 remote: [], pullComplete: true, now: now)
        #expect(actions.download.isEmpty && actions.upload.isEmpty)
    }

    @Test func plan_deletesAnOrphanOnlyAfterACompletePull_andOnlyWhenOld() {
        let old = now.addingTimeInterval(-PagoLogoPropioPlan.orphanGrace - 60)
        let young = now.addingTimeInterval(-60)
        let local: [PagoLogoPropioPlan.Local] = [.init(id: UUID(), ref: refA, hasPhoto: true)]
        let remote: [PagoLogoPropioPlan.Remote] = [.init(name: refA, createdAt: old),
                                                   .init(name: refOld, createdAt: old),
                                                   .init(name: refB, createdAt: young)]
        let complete = PagoLogoPropioPlan.actions(local: local, remote: remote, pullComplete: true, now: now)
        #expect(complete.delete == [refOld], "la nombrada se queda; la reciente puede ser de un pago que aún no bajó")
        let partial = PagoLogoPropioPlan.actions(local: local, remote: remote, pullComplete: false, now: now)
        #expect(partial.delete.isEmpty, "con un pull a medias no se sabe qué nombra el servidor")
        let unknownAge = PagoLogoPropioPlan.actions(local: local, remote: [.init(name: refOld, createdAt: nil)],
                                                    pullComplete: true, now: now)
        #expect(unknownAge.delete.isEmpty, "sin fecha no se borra")
    }

    @Test func plan_withoutTheList_onlyAssignsReferences() {
        let id = UUID()
        let actions = PagoLogoPropioPlan.actions(local: [.init(id: id, ref: nil, hasPhoto: true),
                                                         .init(id: UUID(), ref: refA, hasPhoto: true)],
                                                 remote: nil, pullComplete: true, now: now)
        #expect(actions == PagoLogoPropioPlan.Actions(assignRef: [id]))
    }

    /// Una referencia que no es nuestra forma (pudo llegar del servidor) nunca se pide ni protege nada.
    @Test func plan_ignoresMalformedReferences() {
        let old = now.addingTimeInterval(-PagoLogoPropioPlan.orphanGrace - 60)
        let actions = PagoLogoPropioPlan.actions(local: [.init(id: UUID(), ref: "../x.jpg", hasPhoto: false),
                                                         .init(id: UUID(), ref: refOld, hasPhoto: false)],
                                                 remote: [.init(name: refOld, createdAt: old)],
                                                 pullComplete: true, now: now)
        #expect(actions.download == [refOld])
        #expect(actions.delete.isEmpty)
    }

    // MARK: - Textos

    @Test func texts_existInTheSixteenLocales() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: root.path)
            .filter { $0.hasSuffix(".lproj") && $0 != "Base.lproj" }
        #expect(locales.count == 16)
        let keys = ["section", "usePhoto", "yourPhoto", "change", "footer", "unreadable"]
        for locale in locales {
            let url = root.appendingPathComponent("\(locale)/PagoLogoPropio.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "falta la tabla en \(locale)")
            for key in keys {
                #expect(!(table["pagoLogoPropio.\(key)"] ?? "").isEmpty, "\(locale) sin pagoLogoPropio.\(key)")
            }
        }
        #expect(!PagoLogoPropioText.usePhoto.hasPrefix("pagoLogoPropio."), "la tabla se lee desde la app")
    }
}
