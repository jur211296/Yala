//
//  XNativaHojaFotoTests.swift
//  YalaTests
//
//  La hoja de foto (personal y Grupos), encargo del 2026-11-17: la X del sistema en la fila del título, la descripción
//  editable en «Esto leí» y el cierre automático cuando ya se guardó todo. La lógica se prueba aquí; el cableado, por el
//  código; el recorrido en la hoja, en `XNativaHojaFotoUITests`.
//

import Foundation
import Testing
@testable import Yala

@Suite("Hoja de foto · descripción en línea")
struct XNativaHojaFotoNoteTests {
    @Test func confirmar_quitaEspaciosYSaltosALosLados() {
        #expect(DraftNoteInlineLogic.committed("  Municipalidad de Lima \n") == "Municipalidad de Lima")
    }

    @Test func vacio_esSinDescripcion() {
        #expect(DraftNoteInlineLogic.committed("   \n ") == "")
    }

    @Test func soloCambiaSiLoEscritoEsOtro() {
        #expect(!DraftNoteInlineLogic.changes(" Taxi ", from: "Taxi"))
        #expect(DraftNoteInlineLogic.changes("Taxi al centro", from: "Taxi"))
        #expect(DraftNoteInlineLogic.changes("", from: "Taxi"))
    }
}

@Suite("Hoja de foto · cierre automático")
struct XNativaHojaFotoAutoCloseTests {
    private func state(
        drafts: Int = 2, saved: Int = 2, failed: Bool = false, failedPhotos: Int = 0, leftOut: Int = 0
    ) -> ImageEntryAutoCloseLogic.State {
        .init(draftCount: drafts, savedCount: saved, saveFailed: failed, failedPhotos: failedPhotos, leftOut: leftOut)
    }

    @Test func todoGuardado_seCierra() {
        #expect(ImageEntryAutoCloseLogic.closesAfterSaving(state()))
        #expect(ImageEntryAutoCloseLogic.closesAfterSaving(state(drafts: 1, saved: 1)))
    }

    @Test func quedaUnoSinGuardar_noSeCierra() {
        // También el desmarcado de la hoja de varios: sigue en la Bandeja y la hoja lo dice.
        #expect(!ImageEntryAutoCloseLogic.closesAfterSaving(state(drafts: 7, saved: 5)))
    }

    @Test func conError_noSeCierra() {
        #expect(!ImageEntryAutoCloseLogic.closesAfterSaving(state(failed: true)))
    }

    @Test func conFotosSinLeerOQueNoEntraron_noSeCierra() {
        #expect(!ImageEntryAutoCloseLogic.closesAfterSaving(state(failedPhotos: 1)))
        #expect(!ImageEntryAutoCloseLogic.closesAfterSaving(state(leftOut: 3)))
    }

    @Test func sinRegistros_noSeCierraPorGuardar() {
        #expect(!ImageEntryAutoCloseLogic.closesAfterSaving(state(drafts: 0, saved: 0)))
    }

    @Test func laConfirmacionDuraUnInstante() {
        #expect(ImageEntryAutoCloseLogic.confirmationDelay >= .milliseconds(400))
        #expect(ImageEntryAutoCloseLogic.confirmationDelay <= .milliseconds(1000))
    }
}

@Suite("Hoja de foto · cableado")
struct XNativaHojaFotoWiringTests {
    private static func repoFile(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// El código sin comentarios, para que documentar lo que se cuenta no cambie la cuenta.
    private static func codeOnly(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { line in
                guard let range = line.range(of: "//") else { return line }
                return String(line[..<range.lowerBound])
            }
            .joined(separator: "\n")
    }

    @Test func laXEsLaDelSistema() throws {
        let button = Self.codeOnly(try Self.repoFile("Yala/App/Views/Image/EntrySheetCloseButton.swift"))
        #expect(button.contains("Button(role: .close"))
        #expect(button.contains("side: CGFloat = 44"))
    }

    @Test(arguments: [
        "Yala/App/Views/Image/ImageSelectionView.swift",
        "Yala/App/Views/Groups/Captura/GroupCaptureChrome.swift",
    ])
    func ningunaXHechaAMano(_ path: String) throws {
        let code = Self.codeOnly(try Self.repoFile(path))
        #expect(!code.contains("YalaToolbarButton(systemName: \"xmark\""), "\(path) vuelve a dibujar la X a mano.")
        #expect(code.contains("EntrySheetCloseButton"), "\(path) tiene que usar la X del sistema.")
    }

    @Test func laXConservaSusIdentificadores() throws {
        let personal = Self.codeOnly(try Self.repoFile("Yala/App/Views/Image/ImageSelectionView.swift"))
        #expect(personal.contains("EntrySheetCloseButton { dismiss() }\n                    .accessibilityIdentifier(\"image_close\")"))
        let grupos = Self.codeOnly(try Self.repoFile("Yala/App/Views/Groups/Captura/GroupCaptureChrome.swift"))
        #expect(grupos.contains("EntrySheetCloseButton(action: onClose)\n                    .accessibilityIdentifier(closeIdentifier)"))
    }

    @Test func soloLaHojaDeFotoEditaLaDescripcion() throws {
        let photo = Self.codeOnly(try Self.repoFile("Yala/App/Views/Image/ImageSelectionView.swift"))
        #expect(photo.contains("MultiDraftReviewList(drafts: drafts, selection: $selection, editsNoteInPlace: true)"))
        #expect(photo.contains("VoiceDraftReviewCard(draft: draft, editsNoteInPlace: true)"))
        let voice = Self.codeOnly(try Self.repoFile("Yala/App/Views/Voice/VoiceRecordingView.swift"))
        #expect(!voice.contains("editsNoteInPlace"), "La hoja de voz no pidió editar en línea.")
    }

    @Test func guardarCierraLaHojaCuandoNoQuedaNada() throws {
        let photo = Self.codeOnly(try Self.repoFile("Yala/App/Views/Image/ImageSelectionView.swift"))
        let saveAll = try #require(photo.range(of: "private func saveAll()"))
        let next = try #require(photo.range(of: "private func closeIfEverythingIsSaved()"))
        let body = photo[saveAll.upperBound..<next.lowerBound]
        #expect(body.contains("closeIfEverythingIsSaved()"), "Guardar tiene que mirar si ya está todo.")
        #expect(photo.contains("ImageEntryAutoCloseLogic.closesAfterSaving(state)"))
        // Lo guardado desde el formulario completo también cuenta.
        let afterDetails = try #require(photo.range(of: "private func afterDetails()"))
        #expect(photo[afterDetails.upperBound...].prefix(900).contains("closeIfEverythingIsSaved()"))
    }
}
