//
//  ReceiptDropHandlerTests.swift
//  YalaTests
//
//  Soltar un recibo en el iPad (ticket ipad-drop-unreadable-file-fails-silently): lo que no se puede abrir termina en el
//  fallo de la hoja, nunca en silencio. Hasta el 2026-10-07 cada fallo solo escribía en el log después de que el sistema
//  ya hubiera dado el soltar por aceptado.
//

import Foundation
import PDFKit
import Testing
import UIKit

@testable import Yala

@MainActor
struct ReceiptDropHandlerTests {

    // MARK: - Datos

    private static func png() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
    }

    private static func onePagePDF() -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 300)).pdfData { context in
            context.beginPage()
            ("Total 12,50" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: nil)
        }
    }

    /// Un PDF bien formado —catálogo, árbol de páginas y `xref`— sin ninguna página: el «PDF vacío» del ticket. Se escribe
    /// a mano porque `PDFDocument().dataRepresentation()` da `nil` y `UIGraphicsPDFRenderer` mete una página aunque no se
    /// pida.
    private static func zeroPagePDF() -> Data {
        let objects = ["<< /Type /Catalog /Pages 2 0 R >>", "<< /Type /Pages /Kids [] /Count 0 >>"]
        var pdf = "%PDF-1.4\n"
        var offsets: [Int] = []
        for (index, body) in objects.enumerated() {
            offsets.append(pdf.utf8.count)
            pdf += "\(index + 1) 0 obj\n\(body)\nendobj\n"
        }
        let xref = pdf.utf8.count
        pdf += "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"
        for offset in offsets { pdf += String(format: "%010d 00000 n \n", offset) }
        pdf += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n"
        return Data(pdf.utf8)
    }

    /// El mismo PDF de una página, protegido con contraseña de apertura.
    private static func lockedPDF() -> Data? {
        guard let document = PDFDocument(data: onePagePDF()) else { return nil }
        return document.dataRepresentation(options: [
            PDFDocumentWriteOption.userPasswordOption: "1234",
            PDFDocumentWriteOption.ownerPasswordOption: "1234",
        ])
    }

    /// Lo que el sink recibe: cuántas veces guardó, qué presentó y qué fallo enseñó.
    private final class Recorder {
        var stored = 0
        var presented: [URL] = []
        var failures: [ImageEntryFailure] = []

        func sink(storeSucceeds: Bool = true) -> ReceiptDropHandler.Sink {
            ReceiptDropHandler.Sink(
                store: { _ in
                    self.stored += 1
                    return storeSucceeds ? URL(fileURLWithPath: "/tmp/drop-test.jpg") : nil
                },
                present: { self.presented.append($0) },
                fail: { self.failures.append($0) }
            )
        }
    }

    // MARK: - Qué sale de lo soltado

    @Test func readableImage_isReadable() {
        guard case .readable(let jpeg) = ReceiptDropHandler.outcome(for: Self.png(), isPDF: false) else {
            Issue.record("Una imagen legible tiene que salir como JPEG")
            return
        }
        #expect(UIImage(data: jpeg) != nil)
    }

    @Test func readablePDF_isItsFirstPage() {
        guard case .readable(let jpeg) = ReceiptDropHandler.outcome(for: Self.onePagePDF(), isPDF: true) else {
            Issue.record("Un PDF de una página tiene que salir como su primera página")
            return
        }
        #expect(UIImage(data: jpeg) != nil)
    }

    @Test func dataThatCouldNotBeLoaded_isAnUnreadableFile() {
        #expect(ReceiptDropHandler.outcome(for: nil, isPDF: true) == .failed(.unreadableFile))
        #expect(ReceiptDropHandler.outcome(for: nil, isPDF: false) == .failed(.unreadableFile))
    }

    @Test func damagedImage_isAnUnreadableFile() {
        #expect(ReceiptDropHandler.outcome(for: Data("no es una imagen".utf8), isPDF: false) == .failed(.unreadableFile))
    }

    @Test func somethingThatIsNotAPDF_isAnUnreadableFile() {
        #expect(ReceiptDropHandler.outcome(for: Data("no es un PDF".utf8), isPDF: true) == .failed(.unreadableFile))
        #expect(ReceiptDropHandler.outcome(for: Data(), isPDF: true) == .failed(.unreadableFile))
    }

    /// Medido el 2026-10-07: PDFKit no abre un PDF sin páginas (`PDFDocument(data:)` da `nil`), así que cae en el mismo
    /// `guard` que un fichero que no es PDF.
    @Test func pdfWithoutPages_isAnUnreadableFile() {
        let data = Self.zeroPagePDF()
        #expect(ReceiptDropHandler.outcome(for: data, isPDF: true) == .failed(.unreadableFile))
    }

    /// Protegido con contraseña, PDFKit lo abre bloqueado y AUN ASÍ entrega su primera página (medido el 2026-10-07): sin
    /// el `isLocked`, el soltar lo daba por legible.
    @Test func passwordProtectedPDF_isAnUnreadableFile() throws {
        let data = try #require(Self.lockedPDF())
        let document = try #require(PDFDocument(data: data))
        #expect(document.isLocked, "El PDF del test tiene que llegar bloqueado, o el caso no prueba nada")
        #expect(ReceiptDropHandler.outcome(for: data, isPDF: true) == .failed(.unreadableFile))
    }

    // MARK: - Ningún camino acaba en silencio

    /// El control del ticket: con el código de antes, `receive` hacía `return` y el usuario no veía nada.
    @Test func unreadableDrop_endsInTheFailure_notInSilence() {
        let recorder = Recorder()
        ReceiptDropHandler.receive(Data("no es un PDF".utf8), isPDF: true, sink: recorder.sink())
        #expect(recorder.failures == [.unreadableFile])
        #expect(recorder.presented.isEmpty)
        #expect(recorder.stored == 0, "Lo ilegible no se guarda en PendingImages: la recuperación lo re-emitiría")
    }

    @Test func dropWhoseDataNeverArrived_endsInTheFailure() {
        let recorder = Recorder()
        ReceiptDropHandler.receive(nil, isPDF: false, sink: recorder.sink())
        #expect(recorder.failures == [.unreadableFile])
        #expect(recorder.presented.isEmpty)
    }

    /// Si el archivo está bien y falla guardarlo, lo que falló es lo nuestro: el fallo genérico, no «no pude abrirlo».
    @Test func readableDropThatCannotBeStored_endsInTheGenericFailure() {
        let recorder = Recorder()
        ReceiptDropHandler.receive(Self.png(), isPDF: false, sink: recorder.sink(storeSucceeds: false))
        #expect(recorder.failures == [.generic])
        #expect(recorder.presented.isEmpty)
    }

    /// El camino feliz sigue igual: se guarda una vez y se presenta, sin fallo.
    @Test func readableDrop_isStoredAndPresented() {
        let recorder = Recorder()
        ReceiptDropHandler.receive(Self.onePagePDF(), isPDF: true, sink: recorder.sink())
        #expect(recorder.stored == 1)
        #expect(recorder.presented.count == 1)
        #expect(recorder.failures.isEmpty)
    }

    // MARK: - El fallo nuevo

    /// Un archivo ilegible es el problema: reintentarlo falla igual.
    @Test func unreadableFile_doesNotRetryTheSameFile() {
        #expect(!ImageEntryFailure.unreadableFile.retriesSamePhotos)
    }
}
