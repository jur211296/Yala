//
//  DeferredIntentBufferSharedImageTests.swift
//  YalaTests
//
//  El buffer real (UserDefaults aislado + fichero en disco) con una foto compartida aplazada. Ticket
//  share-image-reading-does-not-always-start: hasta el 2026-10-10 `deferIntent` la descartaba en silencio.
//

import Foundation
import Testing
@testable import Yala

@Suite("DeferredIntentBuffer · foto compartida")
@MainActor
struct DeferredIntentBufferSharedImageTests {

    private func makeBuffer() -> DeferredIntentBuffer {
        DeferredIntentBuffer(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    private func makePhoto() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try Data([0xFF, 0xD8, 0xFF]).write(to: url)
        return url
    }

    @Test func aplazada_conLaFotoEnDisco_vuelveAlDrenar() throws {
        let buffer = makeBuffer()
        let photo = try makePhoto()
        defer { try? FileManager.default.removeItem(at: photo) }

        buffer.deferIntent(.presentSharedImage(photo))
        #expect(!buffer.isEmpty, "La foto aplazada tiene que quedar guardada, no descartarse.")
        #expect(buffer.drainAll() == [.presentSharedImage(photo)])
        #expect(buffer.isEmpty)
    }

    /// La hoja ya la leyó (y la borró) o la purgó el App Group: el drenaje no la resucita.
    @Test func aplazada_conLaFotoYaBorrada_noVuelve() throws {
        let buffer = makeBuffer()
        let photo = try makePhoto()

        buffer.deferIntent(.presentSharedImage(photo))
        try FileManager.default.removeItem(at: photo)
        #expect(buffer.drainAll().isEmpty)
    }

    /// El orden de llegada se conserva: la navegación al Panel sale antes que la hoja de lectura.
    @Test func aplazada_conservaElOrdenConLaNavegacion() throws {
        let buffer = makeBuffer()
        let photo = try makePhoto()
        defer { try? FileManager.default.removeItem(at: photo) }

        buffer.deferIntent(.navigate(.panel))
        buffer.deferIntent(.presentSharedImage(photo))
        #expect(buffer.drainAll() == [.navigate(.panel), .presentSharedImage(photo)])
    }
}
