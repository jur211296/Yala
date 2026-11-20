//
//  PagoLogoPropio.swift
//  Yala
//
//  El logo propio de un pago planificado: una foto que la persona elige cuando su comercio no está en el banco de logos
//  (un colegio, el alquiler, el gimnasio del barrio). Encargo del 2026-11-20, decisión de Jürgen del 19-nov.
//
//  Tres piezas, una por pregunta:
//   - `PagoLogoPropioFoto`: cómo entra la foto. Se reduce al leerla (`PhotoIntake`, regla de `swiftui-ds.md`), se recorta
//     al cuadrado del centro y se guarda en 256 × 256 px, JPEG 0,8 (10–30 KB). JPEG y no HEIC: a este tamaño pesa poco y
//     cualquier versión lo decodifica igual. Sin recorte a mano: el círculo pinta el centro.
//   - `PagoLogoPropioImagenes`: la foto ya decodificada, recordada por pago. La lista, la línea de tiempo y el calendario
//     piden el logo en cada pintado; decodificar el JPEG cada vez costaría en el calendario (varios pagos por celda).
//   - `PagoLogoPropioText`: los textos, en su tabla propia (`PagoLogoPropio.strings`).
//

import SwiftUI
import UIKit

// MARK: - La foto

nonisolated enum PagoLogoPropioFoto {

    /// El lado del logo guardado, en píxeles.
    static let lado = 256

    /// Calidad del JPEG guardado.
    static let calidad: CGFloat = 0.8

    /// Lado mayor con que se lee la foto antes de recortarla: cuatro veces el guardado, así el cuadrado del centro de una
    /// foto apaisada (hasta 4:1) sigue teniendo los 256 px.
    static let ladoDeLectura = lado * 4

    /// La foto que se guarda en el pago a partir de lo que entregó la galería: cuadrada, 256 × 256 px, JPEG. `nil` si
    /// no es una imagen.
    static func datosParaGuardar(desde datos: Data) -> Data? {
        guard let leida = PhotoIntake.image(from: datos, maxEdge: ladoDeLectura) else { return nil }
        return datosParaGuardar(imagen: leida)
    }

    /// Lo mismo desde una imagen ya leída.
    static func datosParaGuardar(imagen: UIImage) -> Data? {
        guard let cg = imagen.cgImage else { return nil }
        let ancho = cg.width, alto = cg.height
        let lado = min(ancho, alto)
        guard lado > 0 else { return nil }
        let recorte = CGRect(x: (ancho - lado) / 2, y: (alto - lado) / 2, width: lado, height: lado)
        guard let cuadrada = cg.cropping(to: recorte) else { return nil }
        let destino = CGSize(width: Self.lado, height: Self.lado)
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        formato.opaque = true
        let reducida = UIGraphicsImageRenderer(size: destino, format: formato).image { contexto in
            // Fondo blanco: una foto con transparencia (un PNG) no sale negra en el JPEG.
            UIColor.white.setFill()
            contexto.fill(CGRect(origin: .zero, size: destino))
            UIImage(cgImage: cuadrada).draw(in: CGRect(origin: .zero, size: destino))
        }
        return reducida.jpegData(compressionQuality: calidad)
    }

    /// Nombre nuevo para el archivo de una foto en Supabase Storage (Modo Nube). Uno por foto: cambiarla cambia el
    /// nombre, y así el otro teléfono sabe que tiene que bajarla.
    static func nuevaReferencia() -> String {
        "\(UUID().uuidString.lowercased()).jpg"
    }

    /// Una referencia que este teléfono acepta: `<uuid>.jpg`, sin carpetas. Lo que baja del servidor con otra forma no
    /// se pide a Storage (no puede salir de la carpeta del usuario).
    static func esReferenciaValida(_ ref: String) -> Bool {
        guard ref.hasSuffix(".jpg") else { return false }
        return UUID(uuidString: String(ref.dropLast(4))) != nil
    }
}

// MARK: - Las fotos ya decodificadas

@MainActor
enum PagoLogoPropioImagenes {

    private struct Recordada {
        let firma: Int
        let imagen: UIImage
    }

    /// Techo de seguridad, como el de `PagoLogoComercio`.
    static let techo = 128

    private static var recordadas: [UUID: Recordada] = [:]

    /// La foto del pago, decodificada una vez por versión de la foto. `nil` si los datos no son una imagen.
    static func imagen(pago: UUID, datos: Data) -> UIImage? {
        let firma = datos.hashValue ^ datos.count
        if let recordada = recordadas[pago], recordada.firma == firma { return recordada.imagen }
        // Ya viene reducida a 256 px: `PhotoIntake` la deja como está y la entrega decodificada.
        guard let imagen = PhotoIntake.image(from: datos, maxEdge: PagoLogoPropioFoto.lado) else { return nil }
        if recordadas.count >= techo { recordadas.removeAll(keepingCapacity: true) }
        recordadas[pago] = Recordada(firma: firma, imagen: imagen)
        return imagen
    }

    #if DEBUG
    static func _testReset() { recordadas.removeAll() }
    #endif
}

// MARK: - Textos

/// Los textos del logo propio, en su tabla (`PagoLogoPropio.strings`), con la cadena de idiomas de la app (molde de
/// `ReusarRegistroText`).
enum PagoLogoPropioText {
    static let table = "PagoLogoPropio"

    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let fullKey = "pagoLogoPropio.\(key)"
        var value = resolution.bundle.localizedString(forKey: fullKey, value: sentinel, table: table)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        return value == sentinel ? fullKey : value
    }

    /// Cabecera de la sección del selector.
    static var section: String { string("section") }
    /// La opción para elegir una foto de la galería.
    static var usePhoto: String { string("usePhoto") }
    /// La foto ya elegida, en el selector y en la fila «Logo» del editor.
    static var yourPhoto: String { string("yourPhoto") }
    /// El botón para elegir otra foto, junto a la foto elegida.
    static var change: String { string("change") }
    /// Pie de la sección: cómo se ve y cómo se quita.
    static var footer: String { string("footer") }
    /// Cuando la foto elegida no se pudo leer.
    static var unreadable: String { string("unreadable") }
}
