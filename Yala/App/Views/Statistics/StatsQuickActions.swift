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
    /// Qué falta para registrar (card 7jfp): sin cuenta o sin categorías, la fila dice qué falta y ofrece la salida,
    /// como la del Panel, en vez de quedarse apagada sin explicación.
    let missingStep: PanelQuickActionsGateLogic.State
    let onCreateFirstAccount: () -> Void
    let onCreateCategories: () -> Void
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

extension EnvironmentValues {
    /// La subpestaña de Estadísticas que se está pintando, para su guía de primera visita. `nil` fuera de Estadísticas
    /// (Registros comparte `RecordsTabView` y tiene su propia guía): ahí `StatsGuideSlot` no pinta nada.
    @Entry var statsGuideTab: DetailViewTab? = nil
}

/// La guía de primera visita de cada subpestaña, como primera pieza de su scroll: se va con el contenido al desplazar.
/// Antes la montaba `DetailContainerView` encima de las páginas y se quedaba fija, con las tarjetas pasando por debajo.
struct StatsGuideSlot: View {
    @Environment(\.statsGuideTab) private var tab

    var body: some View {
        switch tab {
        case .insights: ContextualGuideBanner.insights()
        case .trends: ContextualGuideBanner.trends()
        case .categories: ContextualGuideBanner.categories()
        case .records: ContextualGuideBanner.records()
        case nil: EmptyView()
        }
    }
}

/// El hueco de la fila, bajo el hero de cada subpestaña.
struct StatsQuickActionsSlot: View {
    @Environment(\.statsQuickActions) private var actions

    var body: some View {
        if let actions {
            PanelQuickActionsRow(
                canCreateRecords: actions.canCreateRecords,
                hasAccounts: actions.missingStep != .needsAccount,
                onCreateFirstAccount: actions.onCreateFirstAccount,
                needsCategories: actions.missingStep == .needsCategories,
                onCreateCategories: actions.onCreateCategories,
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
