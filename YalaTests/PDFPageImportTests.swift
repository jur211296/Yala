//
//  PDFPageImportTests.swift
//  YalaTests
//
//  Un estado de cuenta en PDF se lee página a página (ticket pdf-statement-reads-only-the-first-page, decisión 1B de
//  Jürgen): hasta 10 páginas por tanda, cada una una foto; más de 10 se avisan; con contraseña, se pide y se desbloquea en
//  el dispositivo. Hasta el 2026-10-08 solo se leía la página 1 y un PDF con contraseña era «ilegible».
//

import Foundation
import PDFKit
import Testing
import UIKit

@testable import Yala

@MainActor
struct PDFPageImportTests {

    // MARK: - Datos

    private static func pdf(pages: Int) -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 300)).pdfData { context in
            for page in 1...pages {
                context.beginPage()
                ("Página \(page)" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: nil)
            }
        }
    }

    private static func lockedPDF(pages: Int, password: String = "1234") throws -> Data {
        let document = try #require(PDFDocument(data: pdf(pages: pages)))
        let data = try #require(document.dataRepresentation(options: [
            PDFDocumentWriteOption.userPasswordOption: password,
            PDFDocumentWriteOption.ownerPasswordOption: password,
        ]))
        #expect(PDFDocument(data: data)?.isLocked == true, "El PDF del test tiene que llegar bloqueado")
        return data
    }

    private static func png() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
    }

    private func pageCount(_ result: PDFPageImport.OpenResult) -> (read: Int, total: Int)? {
        guard case .pages(let pages, let total) = result else { return nil }
        return (pages.count, total)
    }

    // MARK: - El troceo

    @Test(arguments: [(1, 1), (3, 3), (10, 10), (11, 10)])
    func readsEveryPage_upToTheLimit(pages: Int, expected: Int) throws {
        let result = PDFPageImport.open(Self.pdf(pages: pages), password: nil, room: PDFPageImport.maxPagesPerBatch)
        let counts = try #require(pageCount(result), "Un PDF de \(pages) páginas tenía que abrirse")
        #expect(counts.read == expected)
        #expect(counts.total == pages)
    }

    /// El rojo del ticket: con el código de antes, de un PDF de tres páginas solo salía la primera.
    @Test func threePagePDF_givesThreeImages_notOnlyTheFirst() {
        var batch = ImageFileBatch(files: [.pdf(Self.pdf(pages: 3))])
        #expect(batch.advance() == .finished)
        #expect(batch.images.count == 3)
        #expect(batch.documentPages.count == 3, "Las tres son páginas de PDF: una vacía no se avisa como fallo")
        #expect(batch.pagesLeftOut == 0)
    }

    @Test func elevenPagePDF_readsTen_andCountsTheOneLeftOut() {
        var batch = ImageFileBatch(files: [.pdf(Self.pdf(pages: 11))])
        #expect(batch.advance() == .finished)
        #expect(batch.images.count == 10)
        #expect(batch.pagesLeftOut == 1)
    }

    @Test func pagesToRender_neverExceedsTheRoomLeft() {
        #expect(PDFPageImport.pagesToRender(pageCount: 3, room: 10) == 3)
        #expect(PDFPageImport.pagesToRender(pageCount: 11, room: 10) == 10)
        #expect(PDFPageImport.pagesToRender(pageCount: 5, room: 2) == 2)
        #expect(PDFPageImport.pagesToRender(pageCount: 5, room: 0) == 0)
        #expect(PDFPageImport.pagesToRender(pageCount: 5, room: -1) == 0)
    }

    /// El tope es de la TANDA, sumando ficheros (decisión de Jürgen del 2026-10-08): dos PDFs de 6 dan 10 y 2 fuera.
    @Test func severalFiles_shareTheLimit() {
        var batch = ImageFileBatch(files: [.pdf(Self.pdf(pages: 6)), .pdf(Self.pdf(pages: 6))])
        #expect(batch.advance() == .finished)
        #expect(batch.images.count == 10)
        #expect(batch.pagesLeftOut == 2)
    }

    /// Una imagen y un PDF: la imagen no es página de PDF (si no trae importe, se avisa como siempre).
    @Test func imageAndPDF_onlyThePagesAreDocumentPages() throws {
        var batch = ImageFileBatch(files: [.image(Self.png()), .pdf(Self.pdf(pages: 2))])
        #expect(batch.advance() == .finished)
        #expect(batch.images.count == 3)
        let image = try #require(batch.images.first)
        #expect(!batch.documentPages.contains(ObjectIdentifier(image)))
        #expect(batch.documentPages.count == 2)
    }

    /// En la práctica guiada el tope es una: el resto del PDF cuenta como fuera.
    @Test func limitOfOne_readsOnlyTheFirstPage() {
        var batch = ImageFileBatch(files: [.pdf(Self.pdf(pages: 3))], limit: 1)
        #expect(batch.advance() == .finished)
        #expect(batch.images.count == 1)
        #expect(batch.pagesLeftOut == 2)
    }

    @Test func notAPDF_isUnreadable() {
        guard case .unreadable = PDFPageImport.open(Data("no es un PDF".utf8), password: nil, room: 10) else {
            Issue.record("Lo que no es PDF tiene que salir ilegible")
            return
        }
        var batch = ImageFileBatch(files: [.pdf(Data("no es un PDF".utf8))])
        #expect(batch.advance() == .finished)
        #expect(batch.images.isEmpty)
        #expect(batch.unreadableFiles == 1)
    }

    // MARK: - La contraseña

    @Test func lockedPDF_withoutPassword_asksForIt() throws {
        let data = try Self.lockedPDF(pages: 3)
        guard case .needsPassword = PDFPageImport.open(data, password: nil, room: 10) else {
            Issue.record("Un PDF con contraseña tiene que pedirla, no darse por ilegible")
            return
        }
        #expect(PDFPageImport.canOpen(data), "El soltar tiene que guardarlo para que la hoja pida la contraseña")
    }

    @Test func lockedPDF_withTheRightPassword_readsEveryPage() throws {
        let data = try Self.lockedPDF(pages: 3)
        let counts = try #require(pageCount(PDFPageImport.open(data, password: "1234", room: 10)))
        #expect(counts.read == 3)
        #expect(counts.total == 3)
    }

    @Test func lockedPDF_withAWrongPassword_saysSo_notUnreadable() throws {
        let data = try Self.lockedPDF(pages: 3)
        guard case .wrongPassword = PDFPageImport.open(data, password: "0000", room: 10) else {
            Issue.record("Una contraseña que no abre tiene que decirse como incorrecta")
            return
        }
    }

    /// El recorrido de la hoja: pide, falla, vuelve a pedir diciendo que era incorrecta, y con la buena lee las tres.
    @Test func batch_stopsAtTheLockedPDF_untilTheRightPasswordArrives() throws {
        var batch = ImageFileBatch(files: [.pdf(try Self.lockedPDF(pages: 3))])
        #expect(batch.advance() == .needsPassword(wrongPassword: false))
        #expect(batch.images.isEmpty)
        #expect(batch.advance(password: "0000") == .needsPassword(wrongPassword: true))
        #expect(batch.advance(password: "1234") == .finished)
        #expect(batch.images.count == 3)
    }

    /// La contraseña vale solo para el PDF que la pidió: no abre otro PDF bloqueado que venga detrás.
    @Test func password_appliesOnlyToTheFileThatAskedForIt() throws {
        var batch = ImageFileBatch(files: [.pdf(try Self.lockedPDF(pages: 1)), .pdf(try Self.lockedPDF(pages: 2))])
        #expect(batch.advance() == .needsPassword(wrongPassword: false))
        #expect(batch.advance(password: "1234") == .needsPassword(wrongPassword: false))
        #expect(batch.images.count == 1)
        #expect(batch.advance(password: "1234") == .finished)
        #expect(batch.images.count == 3)
    }

    /// Cancelar la contraseña salta ese PDF y sigue con lo demás.
    @Test func skippingTheLockedPDF_keepsTheRest() throws {
        var batch = ImageFileBatch(files: [.pdf(try Self.lockedPDF(pages: 2)), .pdf(Self.pdf(pages: 3))])
        #expect(batch.advance() == .needsPassword(wrongPassword: false))
        batch.skipLockedFile()
        #expect(batch.advance() == .finished)
        #expect(batch.images.count == 3)
        #expect(batch.skippedLockedFiles == 1)
        #expect(batch.unreadableFiles == 0)
    }

    /// Sin hueco en la tanda no se pide la contraseña de un PDF que no se va a leer; sus páginas cuentan como fuera.
    @Test func lockedPDF_withNoRoomLeft_doesNotAskForThePassword() throws {
        let images = (0..<10).map { _ in ImageFileBatch.File.image(Self.png()) }
        var batch = ImageFileBatch(files: images + [.pdf(try Self.lockedPDF(pages: 2))])
        #expect(batch.advance() == .finished)
        #expect(batch.images.count == 10)
        #expect(batch.pagesLeftOut == 2)
    }
}

// MARK: - Lo que la hoja decide con las páginas leídas

struct PDFPageReadOutcomeTests {

    /// Una portada sin movimientos no es un fallo que avisar (decisión de Jürgen del 2026-10-08).
    @Test func emptyPage_nextToReadPages_isNotAFailure() {
        #expect(ImageEntryFlowLogic.result(for: [.empty, .read, .read]) == .review(failedPhotos: 0))
    }

    /// Si NINGUNA página trae movimientos, el fallo «sin importes» de siempre.
    @Test func onlyEmptyPages_isTheNoAmountFailure() {
        #expect(ImageEntryFlowLogic.result(for: [.empty, .empty, .empty]) == .failure(.noAmount))
    }

    /// Nada leído, una página vacía y otra caída por red: manda la red, que es lo que el usuario puede arreglar.
    @Test func emptyPageAndNoConnection_isNoConnection() {
        #expect(ImageEntryFlowLogic.result(for: [.empty, .failed(.noConnection)]) == .failure(.noConnection))
    }

    /// El cupo de prueba se acaba a mitad: se revisa lo leído y el aviso ofrece Yala Pro, no reintentar.
    @Test func trialUsedUpMidway_offersPro_notRetry() {
        let outcomes: [ImageReadOutcome] = [.read, .failed(.trialUsedUp), .failed(.trialUsedUp)]
        #expect(ImageEntryFlowLogic.result(for: outcomes) == .review(failedPhotos: 2))
        #expect(ImageEntryFlowLogic.failedPhotosNotice(for: [.trialUsedUp, .trialUsedUp]) == .trialUsedUp(count: 2))
    }

    @Test func otherFailures_offerRetry() {
        #expect(ImageEntryFlowLogic.failedPhotosNotice(for: [.generic, .noAmount]) == .retry(count: 2))
        #expect(ImageEntryFlowLogic.failedPhotosNotice(for: []) == nil)
    }

    /// Una foto fallida por red antes de agotarse el cupo: reintentarla tampoco serviría, porque ya no queda cupo.
    @Test func mixedFailuresWithTrialUsedUp_offerPro() {
        #expect(ImageEntryFlowLogic.failedPhotosNotice(for: [.generic, .trialUsedUp]) == .trialUsedUp(count: 2))
    }

    /// Con el cupo agotado, las páginas siguientes no se piden; con cualquier otro fallo, sí.
    @Test func onlyTheTrialUsedUp_skipsTheRemainingReads() {
        #expect(ImageEntryFlowLogic.skipsRemainingReads(after: .trialUsedUp))
        #expect(!ImageEntryFlowLogic.skipsRemainingReads(after: .generic))
        #expect(!ImageEntryFlowLogic.skipsRemainingReads(after: .noConnection))
        #expect(!ImageEntryFlowLogic.skipsRemainingReads(after: .noAmount))
    }
}
