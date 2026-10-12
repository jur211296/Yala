//
//  RouterConsumerGateLogic.swift
//  Yala
//
//  Guard de drain para los consumidores .mainTab y .panel (Clase D del bug
//  TestFlight 2.0.5): ambos drenaban A CIEGAS bajo covers/sheets de nodos
//  superiores — el intent se consumía, el flag del sheet se seteaba tapado y
//  la presentación no aparecía jamás (o "saltaba" al cerrar el cover).
//
//  Espejo de ContentViewReadinessLogic para los nodos inferiores, pero como
//  guard de drain, NO como readiness del router: `readyConsumers` queda
//  intacto (mounted + gate del ChatSheet). Con el gate cerrado, el consumidor
//  hace peek/return y el intent ESPERA en cola; los `onChange` de los flags
//  publicados re-drenan al liberarse (liberar un blocker no bumpea revision).
//

import Foundation

enum RouterConsumerGateLogic {

    enum MainTabDrainDecision: Equatable {
        case drain
        case hold
    }

    /// Intents de `.mainTab` que presentan un sheet propio (ocupan el
    /// presentation slot de MainTabView). `navigate` y `requestAppStoreReview`
    /// NO: un tab-switch bajo un cover es válido (comportamiento de siempre)
    /// y el review prompt es un overlay de sistema sin anchor propio.
    static func presentsModal(_ intent: RouterIntent) -> Bool {
        switch intent {
        case .presentDowngradeResolution, .presentTrialExpired, .presentMilestoneUpgrade:
            return true
        default:
            return false
        }
    }

    /// Decisión peek-first de `.mainTab`: los intents no-modales drenan
    /// siempre; los modales solo con el shell libre y sin sheet propio arriba.
    /// `.hold` deja el intent EN COLA (no se pierde).
    ///
    /// `windowPresentationVisible` es la misma pregunta a UIKit que hace el Panel (`panelCanDrain`): una hoja de OTRA
    /// pestaña no publica ningún flag, y prueba expirada, downgrade e hitos la tumbaban al presentarse encima (ticket
    /// `invite-and-app-notices-present-over-other-tab-sheets`). Los tres son diferibles
    /// (`waitsForForeignPresentation`): esperan a que se cierre.
    static func mainTabDecision(
        intent: RouterIntent,
        shellBlocker: String?,
        ownModalVisible: Bool,
        windowPresentationVisible: Bool = false
    ) -> MainTabDrainDecision {
        guard presentsModal(intent) else { return .drain }
        guard shellBlocker == nil && !ownModalVisible else { return .hold }
        return windowPresentationVisible && waitsForForeignPresentation(intent) ? .hold : .drain
    }

    /// ¿`.mainTab` retiene `intent` SOLO por una presentación que ningún flag publica? Entonces nadie avisará al
    /// cerrarse y `MainTabView` tiene que volver a mirar por su cuenta (molde de `panelHoldsOnlyForUnpublishedPresentation`).
    /// Es también lo que deja pasar por delante a lo que no presenta hoja (`navigate`): esa espera es nueva y no debe
    /// dejar un cambio de pestaña detrás de un aviso durante todo lo que dure un formulario.
    static func mainTabHoldsOnlyForUnpublishedPresentation(
        intent: RouterIntent,
        shellBlocker: String?,
        ownModalVisible: Bool,
        windowPresentationVisible: Bool
    ) -> Bool {
        windowPresentationVisible
            && mainTabDecision(intent: intent, shellBlocker: shellBlocker, ownModalVisible: ownModalVisible,
                               windowPresentationVisible: true) == .hold
            && mainTabDecision(intent: intent, shellBlocker: shellBlocker, ownModalVisible: ownModalVisible,
                               windowPresentationVisible: false) == .drain
    }

    // MARK: - Avisos de `.contentView` y `.mainTab` con una hoja de otra pestaña

    /// **¿Espera este aviso a que se cierre una hoja abierta en la ventana que ningún flag publica?** La clasificación del
    /// ticket `invite-and-app-notices-present-over-other-tab-sheets` (tabla en `docs/entry-points.md`).
    ///
    /// Un aviso que se presenta desde el anchor de `ContentView` o de `MainTabView` con una hoja de otra pestaña abierta
    /// la tumba, y lo escrito en un formulario a medias se pierde. Los **diferibles** (`true`) esperan a que se cierre.
    /// Los **críticos** (`false`) salen como siempre: protegen la cuenta o los datos y no pueden quedarse en cola detrás de
    /// un formulario. Un caso dudoso cuenta como crítico.
    ///
    /// El `switch` no tiene `default` a propósito: un caso nuevo de `RouterIntent` no compila hasta que alguien decida
    /// si espera o no.
    static func waitsForForeignPresentation(_ intent: RouterIntent) -> Bool {
        switch intent {
        // Diferibles: invitaciones a grupos, ofertas, celebraciones y avisos informativos.
        case .showInboxAlert, .presentTrialOffer, .presentWhatsNew,
             .showInviteError, .showGroupArchivedNotice,
             .presentGroupsConsent, .presentGroupsSignIn, .presentGroupBackendInviteOnboarding,
             .presentGroupsInviteNeutralGate,
             .presentDowngradeResolution, .presentTrialExpired, .presentMilestoneUpgrade:
            return true
        // Críticos: integridad de la cuenta o de los datos.
        case .remoteWipe, .iCloudMismatch, .appleIDChangedClosePrivate, .presentRemoteWipeNotice,
             .presentLateICloudMirrorNotice, .remoteOnboardingCompleted:
            return false
        // Dudosos ⇒ como críticos. El error de un gasto de grupo que no llegó a su sitio, y dos respuestas a un toque
        // DENTRO de la app que no son avisos: «Activar Yala completo» se toca desde la propia hoja de Ajustes, y
        // esperar a que se cierre dejaría el toque sin respuesta; el paso del organizador lo encadena su propio flujo.
        case .showGroupSyncError, .presentFullModeActivation, .presentGroupsOrganizerStep:
            return false
        // No presentan una hoja de Yala: cambiar de pestaña no cierra la hoja (medido el 2026-10-11) y pedir reseña es
        // un overlay del sistema.
        case .navigate, .requestAppStoreReview:
            return false
        // De otros consumidores, con su propio candado (`panelCanDrain`, el de Planificación).
        case .presentInboxSheet, .presentSharedImage, .presentNewTransaction, .presentNewTransactionFromChatDraft,
             .presentVoiceEntry, .presentImageEntry, .presentUpgradeSheet, .requestAIConsent,
             .autoOpenBudgetEditor, .autoOpenScheduledEditor:
            return false
        }
    }

    /// ¿`.contentView` retiene `intent` por una hoja que ningún flag publica? Solo con la matriz del shell LIBRE: con
    /// ella tapada el consumidor ya no drena, y cuando drena igual —la invitación que derriba la cadena del Welcome
    /// (B4-04)— lo que la ventana tiene presentado es ese cover yéndose, y retener ahí colgaría la invitación que lo
    /// cerró. Quien llama mide la ventana ANTES de ese derribo.
    static func contentViewHoldsForForeignPresentation(
        _ intent: RouterIntent,
        shellClear: Bool,
        windowPresentationVisible: Bool
    ) -> Bool {
        shellClear && windowPresentationVisible && waitsForForeignPresentation(intent)
    }

    /// Gate de drain de `.panel`: conjunción de las 6 dimensiones que pueden
    /// tapar (o des-anclar) un sheet del Panel. Preserva los 2 gates
    /// preexistentes (tab activo + ChatSheet) y añade los nodos superiores.
    ///
    /// `windowPresentationVisible` es la pregunta a UIKit (`ModalPresentationProbe.isAnythingPresented(in:)`) por la
    /// ventana del Panel: cubre las hojas de OTRA pestaña, que no publican ningún flag. Una entrada desde fuera
    /// (`.navigate(.panel)` + `.presentSharedImage`, `.navigate(.inbox)` + `.presentInboxSheet`) cambia de pestaña por
    /// debajo de esa hoja sin cerrarla, y el Panel presentaba encima: la segunda presentación tumbaba la primera y un
    /// «Nuevo registro» a medias en Estadísticas se perdía (medido el 2026-10-11, ticket
    /// `entry-to-panel-closes-sheets-of-other-tabs`). Ahora espera, como ya esperaba tras las hojas del propio Panel.
    static func panelCanDrain(
        selectedTab: AppTab,
        chatSheetOpen: Bool,
        shellBlocker: String?,
        mainTabModalVisible: Bool,
        panelModalVisible: Bool,
        windowPresentationVisible: Bool
    ) -> Bool {
        selectedTab == .panel
            && !chatSheetOpen
            && shellBlocker == nil
            && !mainTabModalVisible
            && !panelModalVisible
            && !windowPresentationVisible
    }

    /// ¿El Panel retiene SOLO por una presentación que ningún flag publica? Entonces nadie avisará al cerrarse (las
    /// demás dimensiones re-drenan con sus `onChange`) y el Panel tiene que volver a mirar por su cuenta.
    static func panelHoldsOnlyForUnpublishedPresentation(
        selectedTab: AppTab,
        chatSheetOpen: Bool,
        shellBlocker: String?,
        mainTabModalVisible: Bool,
        panelModalVisible: Bool,
        windowPresentationVisible: Bool
    ) -> Bool {
        windowPresentationVisible
            && panelCanDrain(
                selectedTab: selectedTab, chatSheetOpen: chatSheetOpen, shellBlocker: shellBlocker,
                mainTabModalVisible: mainTabModalVisible, panelModalVisible: panelModalVisible,
                windowPresentationVisible: false)
    }
}
