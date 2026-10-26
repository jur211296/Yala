//
//  StatsQuickActions.swift
//  Yala
//
//  La fila de acciones del Panel bajo el hero de las cuatro subpestañas de Estadísticas (card kzhe, Jürgen
//  2026-10-24). La monta cada subpestaña, porque el hero vive dentro de su scroll; quién decide qué hace cada botón
//  es `DetailContainerView`, que lo publica en el entorno con los mismos gates que el botón flotante.
//
//  Puramente presentacional, como `PanelQuickActionsRow`: no presenta nada. El permiso de IA, el paywall y la
//  presentación de Yala IA siguen colgados de `DetailContainerView`, un solo anchor por observable.
//

import SwiftUI

/// Lo que la fila necesita del contenedor de Estadísticas.
struct StatsQuickActions {
    let canCreateRecords: Bool
    let isVoiceLocked: Bool
    let isImageLocked: Bool
    let isChatLocked: Bool
    let isChatVisible: Bool
    let onManualTap: () -> Void
    let onVoiceTap: () -> Void
    let onImageTap: () -> Void
    let onChatTap: () -> Void
    /// `true` cuando el scroll se lleva la fila: entonces salen los flotantes.
    let showsFloating: Binding<Bool>
}

extension EnvironmentValues {
    /// `nil` fuera de Estadísticas (p. ej. las subvistas montadas desde Buscar): ahí no se pinta la fila.
    @Entry var statsQuickActions: StatsQuickActions? = nil
}

/// El hueco de la fila, bajo el hero de cada subpestaña.
struct StatsQuickActionsSlot: View {
    @Environment(\.statsQuickActions) private var actions

    var body: some View {
        if let actions {
            PanelQuickActionsRow(
                canCreateRecords: actions.canCreateRecords,
                isVoiceLocked: actions.isVoiceLocked,
                isImageLocked: actions.isImageLocked,
                isChatLocked: actions.isChatLocked,
                isChatVisible: actions.isChatVisible,
                onManualTap: actions.onManualTap,
                onVoiceTap: actions.onVoiceTap,
                onImageTap: actions.onImageTap,
                onChatTap: actions.onChatTap,
                identifierPrefix: "stats",
                marksTourAnchors: false
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .revealsFloatingActionWhenScrolledAway(actions.showsFloating)
        }
    }
}
