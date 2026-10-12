//
//  SharedPhotoPanelSheetLogic.swift
//  Yala
//
//  Una foto compartida que llega con una hoja del Panel abierta que no tiene nada por guardar la cierra y empieza la
//  lectura (decisión de Jürgen del 2026-10-12, opción B del ticket `shared-photo-waits-silently-behind-an-open-panel-sheet`).
//  Hasta ese día esperaba en silencio a que la persona cerrara la hoja, y quien compartía veía la Bandeja como la dejó y
//  podía pensar que la lectura no había arrancado.
//
//  Qué se cierra, y solo si está SOLA en la ventana (nada encima: un editor, el selector de fotos, un aviso):
//  - la Bandeja;
//  - el registro por imagen en «elige una foto», fuera de la práctica guiada (cerrarla ahí la daría por saltada);
//  - el «?» de un widget del Panel sin un tamaño cambiado por guardar.
//  Todo lo demás —un formulario, Ajustes, el chat, una hoja de otra pestaña, lo que no se reconozca— sigue esperando a
//  que la persona lo cierre (#453): ante la duda, se espera. Solo la foto compartida; voz, imagen y nuevo registro desde
//  un widget siguen esperando.
//

import Foundation

enum SharedPhotoPanelSheetLogic {

    /// La hoja del Panel que una foto compartida puede cerrar.
    enum ClosableSheet: Equatable {
        case inbox
        case imageEntryChoosing
        case widgetInfo
    }

    /// Lo que el Panel ve al retener `intent`. Las tres banderas `only…` son «esa hoja, y ninguna otra de
    /// `PanelSheetState`» (`PanelSheetState.isOnlyPresenting`).
    struct Snapshot: Equatable {
        var intent: RouterIntent?
        var selectedTab: AppTab
        var shellBlocker: String?
        var mainTabModalVisible: Bool
        /// El Nuevo registro con el borrador del chat (`SceneNavigation.showNewTransactionFromChat`): fuera de
        /// `PanelSheetState`, y es un formulario.
        var chatDraftFormOpen: Bool
        var onlyInboxOpen: Bool
        var onlyImageEntryOpen: Bool
        var imageEntryChoosing: Bool
        var imageEntrySetupTrial: Bool
        /// Ninguna bandera de `PanelSheetState` puesta: lo presentado no es una hoja publicada del Panel.
        var noPanelSheetFlag: Bool
        var cleanWidgetInfoVisible: Bool
        /// `ModalPresentationProbe.presentationDepth(in:)`.
        var presentationDepth: Int
    }

    /// La hoja que hay que cerrar para que la foto compartida se lea, o `nil` si la foto espera.
    static func sheetToClose(_ s: Snapshot) -> ClosableSheet? {
        guard case .presentSharedImage = s.intent else { return nil }
        guard s.selectedTab == .panel,
              s.shellBlocker == nil,
              !s.mainTabModalVisible,
              !s.chatDraftFormOpen,
              s.presentationDepth == 1
        else { return nil }
        if s.onlyInboxOpen { return .inbox }
        if s.onlyImageEntryOpen && s.imageEntryChoosing && !s.imageEntrySetupTrial { return .imageEntryChoosing }
        if s.noPanelSheetFlag && s.cleanWidgetInfoVisible { return .widgetInfo }
        return nil
    }
}
