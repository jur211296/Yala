//
//  SharedImageBatchTests.swift
//  YalaTests
//
//  Varias fotos compartidas de una vez viajan como una tanda por `PendingImages/` (ticket
//  tablero-yala-no-aparece-al-compartir-varias-capt-3ut5). Fija el reparto —qué fotos son de la misma tanda y en qué
//  orden se leen—, el tope y el aviso de las que no entraron, y que la extensión y la app hablen del mismo número.
//

import Foundation
import Testing
@testable import Yala

@Suite("SharedImageBatch")
struct SharedImageBatchTests {

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/PendingImages/\(name)")
    }

    // MARK: - Nombre de cada foto

    @Test func fileName_roundTrips() throws {
        let name = SharedImageBatch.fileName(batchID: "ABC123", index: 3, sharedCount: 12)
        #expect(name == "batch_ABC123_03_12.jpg")
        let member = try #require(SharedImageBatch.member(fromFileName: name))
        #expect(member == SharedImageBatch.Member(batchID: "ABC123", index: 3, sharedCount: 12))
    }

    @Test func newBatchID_hasNoSeparator() {
        let id = SharedImageBatch.newBatchID()
        #expect(!id.contains("_"))
        #expect(!id.contains("-"))
        #expect(SharedImageBatch.member(fromFileName: SharedImageBatch.fileName(batchID: id, index: 0, sharedCount: 2))
            != nil)
    }

    @Test(arguments: [
        "\(UUID().uuidString).jpg", // lo que guardaba la extensión hasta el 2026-10-11
        "recibo.pdf", // un recibo soltado en el iPad
        "batch__00_3.jpg", // sin tanda
        "batch_ABC_x_3.jpg", // posición que no es un número
        "batch_ABC_03_3.jpg", // posición fuera de lo compartido
        "batch_ABC_00_3.jpg.part", // a medio escribir
        "other_ABC_00_3.jpg",
    ])
    func member_rejectsNamesOutsideABatch(_ name: String) {
        #expect(SharedImageBatch.member(fromFileName: name) == nil)
    }

    // MARK: - Reparto

    @Test func batch_keepsOnlyItsOwnPhotos_inSharedOrder() {
        let a0 = url(SharedImageBatch.fileName(batchID: "A", index: 0, sharedCount: 3))
        let a1 = url(SharedImageBatch.fileName(batchID: "A", index: 1, sharedCount: 3))
        let a2 = url(SharedImageBatch.fileName(batchID: "A", index: 2, sharedCount: 3))
        let b0 = url(SharedImageBatch.fileName(batchID: "B", index: 0, sharedCount: 2))
        let legacy = url("\(UUID().uuidString).jpg")
        // `pendingImageURLs` ordena por fecha de creación descendente: la URL que llega es la última escrita.
        let candidates = [a2, legacy, b0, a0, a1]
        #expect(SharedImageBatch.batch(containing: a2, among: candidates) == [a0, a1, a2])
        #expect(SharedImageBatch.batch(containing: b0, among: candidates) == [b0])
    }

    @Test func batch_ordersPastNinePhotosByPosition() {
        let urls = (0..<10).map { url(SharedImageBatch.fileName(batchID: "A", index: $0, sharedCount: 10)) }
        #expect(SharedImageBatch.batch(containing: urls[9], among: urls.reversed()) == urls)
    }

    @Test func batch_ofAFileWithoutBatch_isThatFileAlone() {
        let legacy = url("\(UUID().uuidString).jpg")
        let other = url(SharedImageBatch.fileName(batchID: "A", index: 0, sharedCount: 2))
        #expect(SharedImageBatch.batch(containing: legacy, among: [legacy, other]) == [legacy])
    }

    @Test func batch_includesTheRequestedPhoto_evenIfTheListingMissedIt() {
        let a0 = url(SharedImageBatch.fileName(batchID: "A", index: 0, sharedCount: 2))
        let a1 = url(SharedImageBatch.fileName(batchID: "A", index: 1, sharedCount: 2))
        #expect(SharedImageBatch.batch(containing: a1, among: [a0]) == [a0, a1])
    }

    // MARK: - Tope y aviso

    @Test(arguments: [
        (shared: 2, leftOut: 0),
        (shared: 10, leftOut: 0),
        (shared: 11, leftOut: 1),
        (shared: 27, leftOut: 17),
        (shared: 100, leftOut: 90),
    ])
    func leftOutCount_isWhatTheCapKeptOut(_ row: (shared: Int, leftOut: Int)) {
        let anchor = url(SharedImageBatch.fileName(batchID: "A", index: 0, sharedCount: row.shared))
        #expect(SharedImageBatch.leftOutCount(for: anchor) == row.leftOut)
    }

    @Test func leftOutCount_ofAFileWithoutBatch_isZero() {
        #expect(SharedImageBatch.leftOutCount(for: url("\(UUID().uuidString).jpg")) == 0)
    }

    @Test func cap_isTheSameAsPhotosAndPDF() {
        #expect(SharedImageBatch.maxImages == PDFPageImport.maxPagesPerBatch)
    }

    /// Yala aparece en el menú de compartir hasta el número que dice `YalaShare/Info.plist`: tiene que ser el de la app,
    /// y mayor que el tope, o con más fotos que el tope Yala desaparecería sin avisar (el bug).
    @Test func shareExtensionActivation_matchesTheAppAndExceedsTheCap() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("YalaShare/Info.plist"))
        let plist = try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let rule = try #require(
            ((plist["NSExtension"] as? [String: Any])?["NSExtensionAttributes"] as? [String: Any])?[
                "NSExtensionActivationRule"] as? [String: Any])
        let maxCount = try #require(rule["NSExtensionActivationSupportsImageWithMaxCount"] as? Int)
        #expect(maxCount == SharedImageBatch.maxSharedImages)
        #expect(maxCount > SharedImageBatch.maxImages)
    }

    // MARK: - En disco (App Group)

    @Test func pendingBatch_andItsRemoval_touchOnlyThatBatch() throws {
        SharedContainerService.ensurePendingImagesDirectory()
        let directory = try #require(SharedContainerService.pendingImagesURL)
        let ours = SharedImageBatch.newBatchID()
        let theirs = SharedImageBatch.newBatchID()
        let mine = (0..<3).map {
            directory.appendingPathComponent(SharedImageBatch.fileName(batchID: ours, index: $0, sharedCount: 3))
        }
        let other = directory.appendingPathComponent(SharedImageBatch.fileName(batchID: theirs, index: 0, sharedCount: 2))
        let partial = directory.appendingPathComponent(
            SharedImageBatch.fileName(batchID: theirs, index: 1, sharedCount: 2) + SharedImageBatch.partialSuffix)
        let all = mine + [other, partial]
        defer {
            for file in all where FileManager.default.fileExists(atPath: file.path) {
                SharedContainerService.removePendingImage(at: file)
            }
        }
        for file in all {
            try Data([0x01]).write(to: file)
        }

        let listed = SharedContainerService.pendingImageURLs().map(\.lastPathComponent)
        #expect(!listed.contains(partial.lastPathComponent), "Una foto a medio escribir no se lista.")

        let batch = SharedContainerService.pendingImageBatch(containing: mine[1]).map(\.lastPathComponent)
        #expect(batch == mine.map(\.lastPathComponent))

        SharedContainerService.removePendingImageBatch(containing: mine[2])
        for file in mine {
            #expect(!FileManager.default.fileExists(atPath: file.path))
        }
        #expect(FileManager.default.fileExists(atPath: other.path), "La puerta Pro no se lleva otra tanda.")
    }
}
