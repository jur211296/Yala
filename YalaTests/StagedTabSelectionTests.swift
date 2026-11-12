//
//  StagedTabSelectionTests.swift
//  YalaTests
//
//  Card pjum (2026-10-31): las páginas de una fila de chips se montan debajo, invisibles, y se enseñan cuando ya han
//  aparecido, para que chip y página cambien a la vez (`StagedTabPages`). Lo que fija este fichero es la lógica pura de
//  qué hay montado y qué se ve; que de verdad cambien juntos se vio en vídeo (capturas del PR).
//

import Testing
@testable import Yala

@Suite("Páginas de una fila de chips — montar debajo y enseñar")
struct StagedTabSelectionTests {

    private enum Page: Hashable { case a, b, c }

    @Test func starts_showingOnlyItsPage() {
        let selection = StagedTabSelection(Page.a)
        #expect(selection.shown == .a)
        #expect(selection.staged == nil)
        #expect(selection.mounted == [.a])
    }

    @Test func request_mountsTheNewPageUnderneath_withoutShowingIt() {
        var selection = StagedTabSelection(Page.a)
        let mounts = selection.request(.b)
        #expect(mounts)
        #expect(selection.shown == .a, "Hasta que aparezca, se sigue viendo la de antes (y el chip de antes).")
        #expect(selection.mounted == [.a, .b])
    }

    @Test func reveal_showsTheStagedPage_andUnmountsTheOldOneAtOnce() {
        var selection = StagedTabSelection(Page.a)
        _ = selection.request(.b)
        let revealed = selection.reveal(.b)
        #expect(revealed)
        #expect(selection.shown == .b)
        // La vieja se va en el mismo instante: con ella montada el título grande no pasaba a la nueva.
        #expect(selection.mounted == [.b])
    }

    @Test func aLaterTap_replacesThePageStillMounting() {
        var selection = StagedTabSelection(Page.a)
        _ = selection.request(.b)
        _ = selection.request(.c)
        #expect(selection.mounted == [.a, .c])
        let lateReveal = selection.reveal(.b)
        #expect(!lateReveal, "La que se sustituyó no se enseña al aparecer tarde.")
        #expect(selection.shown == .a)
        let revealedC = selection.reveal(.c)
        #expect(revealedC)
        #expect(selection.shown == .c)
    }

    @Test func tappingTheShownPage_cancelsTheOneMounting() {
        var selection = StagedTabSelection(Page.a)
        _ = selection.request(.b)
        let mountsShown = selection.request(.a)
        #expect(!mountsShown)
        #expect(selection.mounted == [.a])
        let revealedCancelled = selection.reveal(.b)
        #expect(!revealedCancelled)
    }

    @Test func reveal_ofTheShownPage_doesNothing() {
        var selection = StagedTabSelection(Page.a)
        let revealedShown = selection.reveal(.a)
        #expect(!revealedShown)
        #expect(selection.shown == .a)
    }

    @Test func jump_changesAtOnce() {
        var selection = StagedTabSelection(Page.a)
        _ = selection.request(.b)
        selection.jump(to: .c)
        #expect(selection.shown == .c)
        #expect(selection.mounted == [.c])
    }
}
