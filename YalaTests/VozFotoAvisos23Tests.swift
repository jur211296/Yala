//
//  VozFotoAvisos23Tests.swift
//  YalaTests
//
//  Lógica de la revisión 2.3 de Nuevo registro en voz y foto: el anuncio a VoiceOver (decisión 62), cuándo se pregunta
//  antes de descartar lo entendido (decisión 81) y a qué altura va la hoja de la foto (decisión 80). El recorrido en
//  pantalla lo fija `VozFotoAvisos23UITests`.
//

import SwiftUI
import Testing
@testable import Yala

@Suite("Voz y foto 2.3 · anuncios, pregunta y altura")
struct VozFotoAvisos23Tests {
    // MARK: - Decisión 62

    @Test func announcement_joinsTitleAndDetail_withAFullStopEach() {
        #expect(
            EntryPhaseFeedbackLogic.announcement(title: "No encontré un importe", detail: "Prueba con otra foto")
                == "No encontré un importe. Prueba con otra foto."
        )
    }

    @Test func announcement_keepsTheTitlesOwnEnding_andSkipsAnEmptyDetail() {
        #expect(EntryPhaseFeedbackLogic.announcement(title: "Escuchando…") == "Escuchando…")
        #expect(EntryPhaseFeedbackLogic.announcement(title: "Esto entendí", detail: "  ") == "Esto entendí.")
        #expect(EntryPhaseFeedbackLogic.announcement(title: "¿Seguro?", detail: nil) == "¿Seguro?")
    }

    @Test func announcement_withNothingToSay_isEmpty() {
        #expect(EntryPhaseFeedbackLogic.announcement(title: "", detail: nil).isEmpty)
    }

    // MARK: - Decisión 81

    @Test func asks_onlyWhileReviewing_withSomethingUnsaved() {
        #expect(EntryPhaseFeedbackLogic.asksBeforeDiscarding(isReviewing: true, unsavedCount: 2))
        #expect(!EntryPhaseFeedbackLogic.asksBeforeDiscarding(isReviewing: true, unsavedCount: 0), "Todo guardado: nada que perder.")
        #expect(!EntryPhaseFeedbackLogic.asksBeforeDiscarding(isReviewing: false, unsavedCount: 0), "Desde un fallo no pregunta.")
    }

    // MARK: - Decisión 80

    @Test func severalToReview_offersOnlyTheLargeHeight() {
        let detents = ImageEntrySheetHeightLogic.detents(showsSeveralToReview: true, dynamicTypeSize: .large)
        #expect(detents == [.large])
        #expect(ImageEntrySheetHeightLogic.background(detents: detents, selectedDetent: .large, usesLargeSheets: false) == .subtle)
    }

    @Test func otherwise_opensAtMediumHeight_likeTheRecordSelectors() {
        let detents = ImageEntrySheetHeightLogic.detents(showsSeveralToReview: false, dynamicTypeSize: .large)
        #expect(detents == [.medium, .large])
        #expect(ImageEntrySheetHeightLogic.background(detents: detents, selectedDetent: .medium, usesLargeSheets: false) == .transparent)
        #expect(
            ImageEntrySheetHeightLogic.detents(showsSeveralToReview: false, dynamicTypeSize: .accessibility2) == [.large],
            "Con texto de accesibilidad ya abría grande."
        )
    }
}
