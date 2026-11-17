//
//  GruposCapturaTests.swift
//  YalaTests
//
//  Voz, Foto y Yala IA de Grupos idénticos a personal, y el «+» flotante del grupo solo al desplazar (encargo del
//  2026-11-16). Tres cosas: lo capturado acaba en el gasto del grupo (su moneda, sus miembros, nada a la Bandeja ni al
//  cupo de personal), lo que nadie nombra se reparte entre todos, y el flotante sigue al scroll con la pieza de las
//  otras vistas.
//

import Foundation
import Testing
@testable import Yala

private func source(_ relative: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let text = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    // Sin comentarios: documentar la regla no puede ponerla en verde ni en rojo.
    return text.split(separator: "\n", omittingEmptySubsequences: false)
        .map { line -> Substring in
            guard let range = line.range(of: "//") else { return line }
            return line[..<range.lowerBound]
        }
        .joined(separator: "\n")
}

@MainActor
@Suite("Grupos · captura: lo capturado va al gasto del grupo")
struct GruposCapturaEnrutadoTests {

    private let me = SplitMember(displayName: "Yo", isCurrentUser: true)
    private let ana = SplitMember(displayName: "Ana")
    private let beto = SplitMember(displayName: "Beto")

    private func model() -> GroupCaptureModel {
        GroupCaptureModel(members: [me, ana, beto], currentMemberID: me.id.uuidString, currencyCode: "PEN")
    }

    @Test("el reparto llega a Nuevo gasto con la moneda del grupo, sus miembros y el total exacto")
    func templateGoesToTheGroup() throws {
        let model = model()
        model.lines = [
            ReceiptSplitLine(description: "Lomo", amount: 38, kind: .item, assignees: [ana.id.uuidString]),
            ReceiptSplitLine(description: "Ají", amount: 32, kind: .item, assignees: [beto.id.uuidString]),
        ]
        let template = try #require(model.template(date: Date(timeIntervalSince1970: 1_800_000_000)))
        #expect(template.currencyCode == "PEN")
        #expect(abs(template.totalAmount - 70) < 0.001)
        #expect(Set(template.participantIDs).isSubset(of: [me.id, ana.id, beto.id]))
        #expect(abs((template.values[ana.id] ?? 0) - 38) < 0.001)
        #expect(abs((template.values[beto.id] ?? 0) - 32) < 0.001)
        #expect(template.description == "Lomo, Ají")
    }

    @Test("lo que nadie nombra se reparte entre todos (la división por defecto)")
    func unnamedLineIsSplitAmongEveryone() throws {
        let model = model()
        model.lines = [ReceiptSplitLine(description: "Chicha", amount: 18, kind: .item)]
        let template = try #require(model.template())
        for member in [me, ana, beto] {
            #expect(abs((template.values[member.id] ?? 0) - 6) < 0.001, "\(member.displayName) no paga su tercio")
        }
    }

    @Test("sin nada que repartir, no hay plantilla ni «Usar este reparto»")
    func nothingToSplit() {
        let model = model()
        #expect(model.template() == nil)
        #expect(!GroupReceiptSplitReview.canUse(model))
        #expect(GroupReceiptSplitReview.blockedReason(model) == L10n.ReceiptSplit.nothingToSplit)
    }

    @Test("propina sin incluir no entra en el total hasta que se elige cómo se reparte")
    func extrasStayOutUntilIncluded() throws {
        let model = model()
        model.lines = [
            ReceiptSplitLine(description: "Pizza", amount: 30, kind: .item),
            ReceiptSplitLine(description: "Servicio", amount: 3, kind: .service),
        ]
        #expect(abs(try #require(model.template()).totalAmount - 30) < 0.001)
        let service = try #require(model.lines.last?.id)
        model.update(service) { $0.extraShare = .equal }
        #expect(abs(try #require(model.template()).totalAmount - 33) < 0.001)
    }

    @Test("el motor usa las tareas de recibo (cupo de Grupos), nunca las de personal ni la Bandeja")
    func usesTheGroupPipeline() throws {
        let code = try source("Yala/App/Views/Groups/Captura/GroupCaptureModel.swift")
        #expect(code.contains("task: .receiptTranscribe"))
        #expect(code.contains("ReceiptSplitService.shared.readPhoto("))
        #expect(code.contains("ReceiptSplitService.shared.readNote("))
        #expect(!code.contains(".voiceTranscribe"))
        #expect(!code.contains("InboxDraft"))
        #expect(!code.contains("approveDraft"))
        // Sin candado: el plan solo elige el texto del cupo agotado, nunca cierra la puerta.
        #expect(!code.contains("canAccess"))
    }
}

@Suite("Grupos · captura: las hojas son las de personal")
struct GruposCapturaPiezasDePersonalTests {

    @Test("cada botón abre su hoja: Voz, Foto y el chat de Yala IA")
    func eachSourceOpensItsSheet() throws {
        let entry = try source("Yala/App/Views/Groups/GroupReceiptEntry.swift")
        let start = try #require(entry.range(of: "private func captureSheet("))
        let body = entry[start.upperBound...].prefix(1400)
        let voice = try #require(body.range(of: "case .voice:\n            GroupVoiceCaptureView("))
        let photo = try #require(body.range(of: "case .photo:\n            GroupPhotoCaptureView("))
        let text = try #require(body.range(of: "case .text:\n            GroupAIChatView("))
        #expect(voice.lowerBound < photo.lowerBound && photo.lowerBound < text.lowerBound)
        // La hoja vieja con su propio diseño ya no se abre desde ningún botón.
        #expect(!entry.contains("GroupReceiptSplitView("))
    }

    @Test("Voz: la onda, el tiempo, la frase en vivo, el orbe y la media altura de personal")
    func voiceUsesThePersonalPieces() throws {
        let code = try source("Yala/App/Views/Groups/Captura/GroupVoiceCaptureView.swift")
        for piece in ["VoiceWaveform(", "VoiceRecordingTimeLabel(", "VoiceLiveTranscriptText(", "VoiceListeningOrb(",
                      "LiveSpeechPreviewService()", ".selectorSheetSizing(.mediumFirst", ".announcesEntryPhase(",
                      "L10n.Chat.listening", "L10n.Chat.transcribing", "L10n.Voice.understanding"] {
            #expect(code.contains(piece), "La voz de Grupos no usa \(piece)")
        }
    }

    @Test("Foto: Cámara, Fotos y Archivo, la foto que se lee y el alto de la foto de personal")
    func photoUsesThePersonalPieces() throws {
        let code = try source("Yala/App/Views/Groups/Captura/GroupPhotoCaptureView.swift")
        for piece in ["L10n.Image.Entry.camera", "L10n.Image.Entry.photos", "L10n.Image.Entry.file",
                      "ImageEntrySheetHeightLogic.detents(", ".growsSheetToLarge(", "GroupCaptureReadingPhoto(",
                      "L10n.Image.Entry.readingOne", "allowedContentTypes: [.image, .pdf]", "PhotoIntake.image("] {
            #expect(code.contains(piece), "La foto de Grupos no usa \(piece)")
        }
    }

    @Test("Yala IA: el hilo de burbujas, los tres puntos, la barra de mensajería y el panel de voz del chat")
    func chatUsesThePersonalPieces() throws {
        let code = try source("Yala/App/Views/Groups/Captura/GroupAIChatView.swift")
        for piece in ["ChatMessageBubble(", "ChatLoadingIndicator()", "ChatBubbleShape()", "VoiceListeningPanel(",
                      ".navigationTitle(L10n.Chat.assistantName)", "placement: .cancellationAction"] {
            #expect(code.contains(piece), "El chat de Grupos no usa \(piece)")
        }
    }
}

@Suite("Grupos · captura: el «+» flotante sigue al scroll")
struct GruposCapturaFlotanteTests {

    @Test("con la fila de arriba a la vista no sale; cuando el scroll se la lleva, sí")
    func followsTheTopRow() {
        #expect(TopPrimaryActionRevealLogic.floatingAfterVisibilityChange(
            topActionVisible: true, isPageShown: true, hasSeenTopAction: false) == false)
        #expect(TopPrimaryActionRevealLogic.floatingAfterVisibilityChange(
            topActionVisible: false, isPageShown: true, hasSeenTopAction: true) == true)
        // El primer «no visible» del montaje no se cree: el «+» no asoma al entrar arriba.
        #expect(TopPrimaryActionRevealLogic.floatingAfterVisibilityChange(
            topActionVisible: false, isPageShown: true, hasSeenTopAction: false) == nil)
    }

    @Test("el detalle cuelga el «+» de la fila de «Nuevo gasto» con la pieza de Panel, Presupuestos y Pagos")
    func detailUsesTheSharedReveal() throws {
        let detail = try source("Yala/App/Views/Groups/GroupDetailView.swift")
        #expect(detail.contains("!group.isMigratedFrozen && showFloatingNew {\n            newExpenseFAB"))
        #expect(detail.contains("showsFloatingNew: $showFloatingNew"))
        #expect(detail.contains(
            ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.normal), value: showFloatingNew)"))
        let records = try source("Yala/App/Views/Groups/GroupRecordsView.swift")
        let row = try #require(records.range(of: "quickActions\n                    .padding(.bottom, DS.Spacing.sm)"))
        #expect(records[row.upperBound...].prefix(200).contains(".modifier(FloatingNewReveal(showsFloating: showsFloatingNew))"))
        #expect(records.contains("content.revealsFloatingActionWhenScrolledAway(showsFloating)"))
        // No hay un mecanismo nuevo: nada de medir el scroll a mano.
        #expect(!records.contains("onScrollGeometryChange"))
    }
}
