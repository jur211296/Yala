//
//  WidgetHeaderInfoSlot.swift
//  Yala
//
//  Resuelve el slot pedagógico opcional del header de un widget Panel.
//  Si `injected` está presente, lo renderiza; si no, fallback al
//  `InfoHintButton` legacy con el title/message dados — útil cuando el widget
//  se reusa fuera del Panel (ej. CategoriesTabView, TrendsTabView), donde el
//  rollout pedagógico aún no aplica.
//
//  Centraliza la decisión `if let injected { ... } else { InfoHintButton(...) }`
//  que antes se duplicaba en ~14 sitios entre los 11 widgets del Panel.
//

import SwiftUI

struct WidgetHeaderInfoSlot: View {
    let injected: AnyView?
    let legacyTitle: String
    let legacyMessage: String

    var body: some View {
        if let injected {
            injected
        } else {
            InfoHintButton(title: legacyTitle, message: legacyMessage)
        }
    }
}
