//
//  PhotoIntake.swift
//  Yala
//
//  Cómo entra una foto que Yala va a leer (recibo, alerta del banco, captura, página de un archivo) o a guardar como
//  foto de perfil. Se reduce AL ENTRAR, no al subir ni al guardar: con `UIImage(data:)`, SwiftUI decodifica la foto a
//  tamaño completo al pintarla, aunque sea en una miniatura, y esa copia vive mientras la foto está en pantalla. Medido el
//  2026-11-12 (YALA-IOS-B, iPhone 16 Pro Max en el simulador): diez fotos de 48 MP en la hoja de lectura subieron la app
//  de 65 MB a 1.929 MB; reducidas al entrar, de 66 MB a 67 MB.
//
//  Para leer, el lado mayor es el del gateway (`PhotoUploadSizing`) con un mínimo de 2048 px, lo que pide una vista a
//  pantalla completa en un iPad. Para la foto de perfil, el tamaño con que se guarda. Nunca se amplía.
//

import ImageIO
import UIKit

nonisolated enum PhotoIntake {

    /// El mínimo del lado mayor al entrar.
    static let minimumIntakeEdge = 2048

    /// El lado mayor al que entra una foto para leerla.
    static func intakeMaxEdge(remote: Int?) -> Int {
        max(minimumIntakeEdge, PhotoUploadSizing.maxEdge(remote: remote))
    }

    /// El de ahora: el del gateway si ya lo dijo (`/config`), con el mínimo.
    static func currentIntakeMaxEdge() -> Int {
        intakeMaxEdge(remote: CloudRemoteConfigStore.readSnapshot()?.photoMaxEdge)
    }

    /// La foto de `data` reducida a `maxEdge` px de lado mayor, con la orientación aplicada y ya decodificada. `nil` si
    /// no es una imagen. Una foto que ya cabe sale a su tamaño.
    static func image(from data: Data, maxEdge: Int) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary),
              CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxEdge,
        ]
        let index = CGImageSourceGetPrimaryImageIndex(source)
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Lo mismo, fuera del hilo principal: reducir una de 48 MP cuesta ~85 ms (medido en el simulador), y una tanda de
    /// diez en el hilo principal congelaba la pantalla cerca de un segundo.
    @concurrent
    static func imageOffMainActor(from data: Data, maxEdge: Int) async -> UIImage? {
        image(from: data, maxEdge: maxEdge)
    }

    /// Una foto que ya llega como `UIImage` (la cámara) reducida a `maxEdge` px de lado mayor. Si ya cabe, la misma.
    static func image(reducing image: UIImage, maxEdge: Int) -> UIImage {
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        guard let target = PhotoUploadSizing.targetPixelSize(for: pixels, maxEdge: maxEdge) else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// El lado mayor de una foto en píxeles.
    static func longestPixelEdge(of image: UIImage) -> Int {
        Int(max(image.size.width * image.scale, image.size.height * image.scale))
    }
}
