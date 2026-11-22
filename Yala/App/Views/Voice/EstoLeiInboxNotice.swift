//
//  EstoLeiInboxNotice.swift
//  Yala
//
//  «Lo que leí quedó en tu Bandeja · Ver» al cerrar «Esto leí» o «Esto entendí» sin guardar (opción A de Jürgen,
//  2026-11-22, recorrido paso 5). Es el aviso flotante de siempre (`DraftDiscardUndoNotice`), que sobrevive al cierre de
//  la hoja; «Ver» abre la Bandeja por el router, como el aviso de nuevos borradores.
//

import Foundation

enum EstoLeiInboxNotice {
    @MainActor
    static func show(message: String) {
        DraftDiscardUndoNotice.show(
            message: message,
            systemImage: "tray",
            undoTitle: L10n.EstoLei.inboxNoticeView,
            noticeIdentifier: "esto_lei_inbox_notice",
            undoIdentifier: "esto_lei_inbox_view"
        ) {
            RouterEntryGate.shared.submit(.navigate(.inbox))
        }
    }
}
