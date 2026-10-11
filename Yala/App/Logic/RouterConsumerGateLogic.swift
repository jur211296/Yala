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
    static func mainTabDecision(
        intent: RouterIntent,
        shellBlocker: String?,
        ownModalVisible: Bool
    ) -> MainTabDrainDecision {
        guard presentsModal(intent) else { return .drain }
        return (shellBlocker == nil && !ownModalVisible) ? .drain : .hold
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
