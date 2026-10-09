//
//  PDFPageImport.swift
//  Yala
//
//  Un PDF se lee página a página (ticket pdf-statement-reads-only-the-first-page, decisión 1B de Jürgen del 2026-10-07):
//  cada página es una foto más del registro por imagen, hasta 10 por vez, y cada una gasta un uso de foto en la pasarela
//  (que cuenta por llamada a `photo.read`). Si el PDF tiene contraseña, se pide en la hoja y se desbloquea aquí, en el
//  dispositivo: la contraseña no se guarda ni viaja, solo sube la imagen de cada página.
//

import PDFKit
import UIKit

enum PDFPageImport {
    /// Cuántas páginas (o fotos) se leen como mucho en una tanda. Lo decidió Jürgen el 2026-10-07 (opción 1B); también es
    /// el tope de fotos de siempre, y queda bajo la ráfaga de Pro en la pasarela (15 por minuto).
    static let maxPagesPerBatch = 10

    /// Lo que sale de abrir un PDF.
    enum OpenResult {
        /// Las páginas que caben, ya pintadas, y cuántas tiene el documento.
        case pages([UIImage], totalPages: Int)
        /// Tiene contraseña de apertura y no se dio ninguna.
        case needsPassword
        /// La contraseña dada no lo abre.
        case wrongPassword
        /// No es un PDF, está dañado o no tiene páginas.
        case unreadable
    }

    /// Cuántas páginas se pintan de un documento de `pageCount` cuando en la tanda quedan `room` huecos.
    static func pagesToRender(pageCount: Int, room: Int) -> Int {
        max(0, min(pageCount, room))
    }

    /// Abre el PDF y pinta sus primeras páginas, hasta `room`. Sin hueco no pide contraseña: no se leería nada.
    static func open(_ data: Data, password: String?, room: Int) -> OpenResult {
        guard let document = PDFDocument(data: data) else { return .unreadable }
        if room <= 0 {
            return .pages([], totalPages: document.pageCount)
        }
        if document.isLocked {
            guard let password, !password.isEmpty else { return .needsPassword }
            guard document.unlock(withPassword: password) else { return .wrongPassword }
        }
        let total = document.pageCount
        guard total > 0 else { return .unreadable }
        let count = pagesToRender(pageCount: total, room: room)
        var pages: [UIImage] = []
        for index in 0..<count {
            guard let page = document.page(at: index) else { continue }
            pages.append(render(page))
        }
        guard !pages.isEmpty else { return .unreadable }
        return .pages(pages, totalPages: total)
    }

    /// ¿Se puede abrir como PDF? Bloqueado cuenta como sí: la contraseña se pide después, en la hoja. Lo usa el soltar en el
    /// iPad para no guardar en `PendingImages/` lo que nunca se va a poder leer.
    static func canOpen(_ data: Data) -> Bool {
        guard let document = PDFDocument(data: data) else { return false }
        return document.isLocked || document.pageCount > 0
    }

    /// Una página a 2× para que el texto de un extracto se lea. La foto se reduce después al lado mayor de la pasarela.
    static func render(_ page: PDFPage) -> UIImage {
        let bounds = page.bounds(for: .mediaBox)
        let size = CGSize(width: bounds.width * 2, height: bounds.height * 2)
        return page.thumbnail(of: size, for: .mediaBox)
    }
}

/// Los ficheros que se eligieron en Archivo o se soltaron, en orden, convertidos en las fotos que se van a leer: cada
/// imagen es una y cada página de PDF otra, hasta `limit` en total. Un PDF con contraseña DETIENE la tanda hasta que la
/// hoja la pide (`advance(password:)` otra vez con ella) o se salta (`skipLockedFile()`).
struct ImageFileBatch {
    enum File {
        case image(Data)
        case pdf(Data)
    }

    enum Step: Equatable {
        /// Ya no queda nada por abrir.
        case finished
        /// El primer fichero que queda es un PDF con contraseña. `wrongPassword` si ya se probó una y no lo abrió.
        case needsPassword(wrongPassword: Bool)
    }

    let limit: Int
    private var remaining: [File]
    /// Las fotos que se van a leer, en orden.
    private(set) var images: [UIImage] = []
    /// Las que son páginas de un PDF: una página sin movimientos (portada, condiciones) no se avisa como fallo.
    private(set) var documentPages: Set<ObjectIdentifier> = []
    /// Páginas de PDF que no entraron en la tanda por el tope.
    private(set) var pagesLeftOut = 0
    /// PDFs con contraseña que la persona decidió no abrir.
    private(set) var skippedLockedFiles = 0
    /// Ficheros que no se pudieron abrir.
    private(set) var unreadableFiles = 0

    init(files: [File], limit: Int = PDFPageImport.maxPagesPerBatch) {
        self.remaining = files
        self.limit = limit
    }

    /// Abre lo que queda hasta acabar o hasta el siguiente PDF con contraseña. `password` vale solo para el PRIMER fichero
    /// que queda: el que la pidió.
    mutating func advance(password: String? = nil) -> Step {
        var password = password
        while let file = remaining.first {
            switch file {
            case .image(let data):
                remaining.removeFirst()
                // Como siempre: por encima del tope, una imagen suelta se deja fuera sin aviso.
                guard images.count < limit else { continue }
                if let image = UIImage(data: data) {
                    images.append(image)
                } else {
                    unreadableFiles += 1
                }
            case .pdf(let data):
                switch PDFPageImport.open(data, password: password, room: limit - images.count) {
                case .needsPassword:
                    return .needsPassword(wrongPassword: false)
                case .wrongPassword:
                    return .needsPassword(wrongPassword: true)
                case .unreadable:
                    remaining.removeFirst()
                    unreadableFiles += 1
                case .pages(let pages, let totalPages):
                    remaining.removeFirst()
                    images.append(contentsOf: pages)
                    documentPages.formUnion(pages.map(ObjectIdentifier.init))
                    pagesLeftOut += totalPages - pages.count
                }
            }
            password = nil
        }
        return .finished
    }

    /// La persona no quiso dar la contraseña: ese PDF se salta y la tanda sigue con lo demás.
    mutating func skipLockedFile() {
        guard case .pdf = remaining.first else { return }
        remaining.removeFirst()
        skippedLockedFiles += 1
    }
}
