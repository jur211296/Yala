//
//  SharedPhotoPanelSheetLogicTests.swift
//  YalaTests
//
//  Una foto compartida cierra una hoja del Panel solo si no tiene nada por guardar y está sola en la ventana (ticket
//  `shared-photo-waits-silently-behind-an-open-panel-sheet`, opción B). Ante la duda, espera. Pure-logic.
//

import Foundation
import Testing
@testable import Yala

@Suite("SharedPhotoPanelSheetLogic")
struct SharedPhotoPanelSheetLogicTests {

    private let photo = RouterIntent.presentSharedImage(URL(fileURLWithPath: "/tmp/batch_x_01_01.jpg"))

    /// La Bandeja abierta sola, con el Panel delante y nada encima: el caso que se cierra.
    private func inboxAlone() -> SharedPhotoPanelSheetLogic.Snapshot {
        SharedPhotoPanelSheetLogic.Snapshot(
            intent: photo, selectedTab: .panel, shellBlocker: nil, mainTabModalVisible: false,
            chatDraftFormOpen: false, onlyInboxOpen: true, onlyImageEntryOpen: false, imageEntryChoosing: false,
            imageEntrySetupTrial: false, noPanelSheetFlag: false, cleanWidgetInfoVisible: false, presentationDepth: 1)
    }

    private func imageEntryAlone() -> SharedPhotoPanelSheetLogic.Snapshot {
        var s = inboxAlone()
        s.onlyInboxOpen = false
        s.onlyImageEntryOpen = true
        s.imageEntryChoosing = true
        return s
    }

    private func widgetInfoAlone() -> SharedPhotoPanelSheetLogic.Snapshot {
        var s = inboxAlone()
        s.onlyInboxOpen = false
        s.noPanelSheetFlag = true
        s.cleanWidgetInfoVisible = true
        return s
    }

    // MARK: - Lo que se cierra

    @Test func inboxAlone_closes() {
        #expect(SharedPhotoPanelSheetLogic.sheetToClose(inboxAlone()) == .inbox)
    }

    @Test func imageEntryChoosing_closes() {
        #expect(SharedPhotoPanelSheetLogic.sheetToClose(imageEntryAlone()) == .imageEntryChoosing)
    }

    @Test func cleanWidgetInfo_closes() {
        #expect(SharedPhotoPanelSheetLogic.sheetToClose(widgetInfoAlone()) == .widgetInfo)
    }

    // MARK: - Lo que espera

    @Test(arguments: [
        RouterIntent.presentVoiceEntry, .presentImageEntry, .presentNewTransaction, .presentInboxSheet,
        .requestAIConsent(.image), .navigate(.panel),
    ])
    func otherIntents_wait(intent: RouterIntent) {
        var s = inboxAlone()
        s.intent = intent
        #expect(SharedPhotoPanelSheetLogic.sheetToClose(s) == nil)
    }

    @Test func noIntent_waits() {
        var s = inboxAlone()
        s.intent = nil
        #expect(SharedPhotoPanelSheetLogic.sheetToClose(s) == nil)
    }

    /// Algo encima de la hoja (un borrador de la Bandeja en edición, el selector de fotos, un aviso): puede tener datos.
    @Test(arguments: [0, 2, 3])
    func somethingOnTopOrNothingPresented_waits(depth: Int) {
        for base in [inboxAlone(), imageEntryAlone(), widgetInfoAlone()] {
            var s = base
            s.presentationDepth = depth
            #expect(SharedPhotoPanelSheetLogic.sheetToClose(s) == nil)
        }
    }

    @Test(arguments: [AppTab.statistics, .planning, .records, .groups])
    func panelNotInFront_waits(tab: AppTab) {
        for base in [inboxAlone(), imageEntryAlone(), widgetInfoAlone()] {
            var s = base
            s.selectedTab = tab
            #expect(SharedPhotoPanelSheetLogic.sheetToClose(s) == nil)
        }
    }

    @Test func shellCovered_waits() {
        var s = inboxAlone()
        s.shellBlocker = "inboxAlert"
        #expect(SharedPhotoPanelSheetLogic.sheetToClose(s) == nil)
    }

    @Test func mainTabSheet_waits() {
        var s = inboxAlone()
        s.mainTabModalVisible = true
        #expect(SharedPhotoPanelSheetLogic.sheetToClose(s) == nil)
    }

    @Test func chatDraftForm_waits() {
        for base in [inboxAlone(), widgetInfoAlone()] {
            var s = base
            s.chatDraftFormOpen = true
            #expect(SharedPhotoPanelSheetLogic.sheetToClose(s) == nil)
        }
    }

    /// La Bandeja con otra hoja del Panel puesta a la vez (las dos banderas): no se cierra nada.
    @Test func inboxWithAnotherPanelFlag_waits() {
        var s = inboxAlone()
        s.onlyInboxOpen = false
        #expect(SharedPhotoPanelSheetLogic.sheetToClose(s) == nil)
    }

    /// Una contraseña a medias, una lectura, la revisión o un fallo: la hoja de imagen fuera de «elige una foto».
    @Test func imageEntryPastChoosing_waits() {
        var s = imageEntryAlone()
        s.imageEntryChoosing = false
        #expect(SharedPhotoPanelSheetLogic.sheetToClose(s) == nil)
    }

    /// Cerrar la práctica guiada la daría por saltada.
    @Test func imageEntrySetupTrial_waits() {
        var s = imageEntryAlone()
        s.imageEntrySetupTrial = true
        #expect(SharedPhotoPanelSheetLogic.sheetToClose(s) == nil)
    }

    /// El «?» con un tamaño cambiado por guardar no publica `cleanWidgetInfoVisible`.
    @Test func widgetInfoWithUnsavedSize_waits() {
        var s = widgetInfoAlone()
        s.cleanWidgetInfoVisible = false
        #expect(SharedPhotoPanelSheetLogic.sheetToClose(s) == nil)
    }

    /// Una hoja sin bandera del Panel que no es el «?» (una de otra pestaña que se quedó al cambiar al Panel): espera.
    @Test func unpublishedSheetThatIsNotWidgetInfo_waits() {
        var s = widgetInfoAlone()
        s.cleanWidgetInfoVisible = false
        #expect(SharedPhotoPanelSheetLogic.sheetToClose(s) == nil)
        s.cleanWidgetInfoVisible = true
        s.noPanelSheetFlag = false
        #expect(SharedPhotoPanelSheetLogic.sheetToClose(s) == nil)
    }

    // MARK: - PanelSheetState.isOnlyPresenting

    @Test func isOnlyPresenting_requiresTheFlagAndNoOther() {
        var sheets = PanelSheetState()
        #expect(!sheets.isOnlyPresenting(\.showInbox))
        sheets.showInbox = true
        #expect(sheets.isOnlyPresenting(\.showInbox))
        #expect(!sheets.isOnlyPresenting(\.showImageSelection))
        sheets.showAIConsentAlert = true
        #expect(!sheets.isOnlyPresenting(\.showInbox))
    }
}
