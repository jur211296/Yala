//
//  PanelShell.swift
//  Yala
//
//  Lightweight wrapper that owns sheet state, FAB state, and onChange modifiers.
//  Hosts .sheet() and all SessionState onChange observers so that
//  UISheetPresentationController.layoutBelowIfNeeded and observation
//  cancel/re-register during tab switches hit PanelShell (trivial body)
//  instead of PanelView (heavy body with NavigationStack + widgets).
//

import SwiftUI

struct PanelShell: View {
    @State private var viewModel = PanelViewModel()
    @State private var sheets = PanelSheetState()
    /// Reintento del drenaje mientras el Panel retiene solo por una hoja que ningún flag publica (la de otra pestaña).
    @State private var unpublishedPresentationRedrain: Task<Void, Never>?
    @Environment(SessionState.self) private var sessionState
    @Environment(SceneNavigation.self) private var navigation

    var body: some View {
        PanelView(viewModel: viewModel, sheets: $sheets)
            .modifier(PanelSheetsModifier(
                sheets: $sheets,
                viewModel: viewModel
            ))
            .modifier(PanelRecordSheetsModifier(sheets: $sheets, viewModel: viewModel))
            .modifier(PanelDataObservers(
                viewModel: viewModel,
                sessionState: sessionState
            ))
            .modifier(PanelSessionObservers(
                viewModel: viewModel,
                sessionState: sessionState
            ))
            .sheet(isPresented: $sheets.showSubscriptionFromBanner) {
                NavigationStack {
                    SubscriptionView(source: sheets.subscriptionBannerSource)
                }
            }
            // Consumer gate: drain only when Panel is the active tab, so
            // intents don't present behind a hidden view.
            .routerConsumer(.panel) {
                drainPanelIfActive()
            }
            // «¿Era de prueba?» llega armado desde un editor (primer gasto, presupuesto o pago) y entra por el mismo
            // candado que los intents del Panel: ver `presentPendingPracticeCleanup`.
            .modifier(PanelPracticeCleanupTrigger(onPending: drainPanelIfActive))
            .onChange(of: navigation.selectedMainTab) { _, _ in
                drainPanelIfActive()
            }
            // Gate .panel intents while ChatSheet is open: prevents draining
            // sheet-presenting intents before ChatSheet's dismiss animation completes.
            .onChange(of: sheets.showChatSheet) { _, isOpen in
                if isOpen {
                    AppRouter.shared.markUnready(.panel, in: navigation.id)
                } else {
                    AppRouter.shared.markReady(.panel, in: navigation.id)
                    drainPanelIfActive()
                }
            }
            // Re-drains de Clase D: liberar un blocker superior (cover del shell,
            // sheet de MainTab) o cerrar un sheet propio no bumpea revision — cada
            // dimensión del gate re-drena explícitamente (molde del ChatSheet).
            .onChange(of: navigation.shellModalBlocker) { _, newBlocker in
                if newBlocker == nil { drainPanelIfActive() }
            }
            .onChange(of: navigation.isMainTabModalVisible) { _, visible in
                if !visible { drainPanelIfActive() }
            }
            .onChange(of: sheets.hasActivePresentation) { _, active in
                if !active { drainPanelIfActive() }
            }
            .onChange(of: navigation.showNewTransactionFromChat) { _, showing in
                if !showing { drainPanelIfActive() }
            }
            .onDisappear { cancelUnpublishedPresentationRedrain() }
    }

    private func drainPanelIfActive() {
        // Clase D: con cualquier nodo superior tapando (o un sheet propio ya
        // arriba), el intent ESPERA en cola en vez de consumirse tapado —
        // `sheets.showInbox = true` bajo un paywall jamás presentaba (bug
        // TestFlight: tap de notificación que nunca abría la Bandeja).
        let panelModalVisible = sheets.hasActivePresentation || navigation.showNewTransactionFromChat
        // Una hoja de OTRA pestaña no publica nada: se pregunta a UIKit por la ventana. Ver `panelCanDrain`.
        let windowPresentationVisible = ModalPresentationProbe.isAnythingPresented(
            in: SceneRegistry.shared.windowScene(for: navigation.id))
        guard RouterConsumerGateLogic.panelCanDrain(
            selectedTab: navigation.selectedMainTab,
            chatSheetOpen: sheets.showChatSheet,
            shellBlocker: navigation.shellModalBlocker,
            mainTabModalVisible: navigation.isMainTabModalVisible,
            panelModalVisible: panelModalVisible,
            windowPresentationVisible: windowPresentationVisible
        ) else {
            if RouterConsumerGateLogic.panelHoldsOnlyForUnpublishedPresentation(
                selectedTab: navigation.selectedMainTab,
                chatSheetOpen: sheets.showChatSheet,
                shellBlocker: navigation.shellModalBlocker,
                mainTabModalVisible: navigation.isMainTabModalVisible,
                panelModalVisible: panelModalVisible,
                windowPresentationVisible: windowPresentationVisible
            ), AppRouter.shared.peekNext(for: .panel, in: navigation.id) != nil
                || SetupChecklistManager.shared.pendingPracticeCleanup != nil {
                scheduleUnpublishedPresentationRedrain()
            }
            closeDataFreeSheetForSharedPhoto()
            // Canario D4: solo con el tab correcto y por flags PUBLICADOS
            // (shellModalBlocker / isMainTabModalVisible) — tab equivocado,
            // chat abierto o sheet propio del panel son estado local real
            // del usuario, no un flag pegado.
            if navigation.selectedMainTab == .panel,
               let pending = AppRouter.shared.peekNext(for: .panel, in: navigation.id) {
                if let blocker = navigation.shellModalBlocker {
                    RouterHoldCanary.shared.noteHold(intentID: pending.id, blocker: blocker, consumer: "panel")
                } else if navigation.isMainTabModalVisible {
                    RouterHoldCanary.shared.noteHold(intentID: pending.id, blocker: "mainTabModal", consumer: "panel")
                }
                #if DEBUG
                print("PanelShell drain hold: \(pending.id) por \(navigation.shellModalBlocker ?? "modal visible")")
                #endif
            }
            return
        }
        if let intent = AppRouter.shared.drainNext(for: .panel, in: navigation.id) {
            RouterHoldCanary.shared.noteDrained(intentID: intent.id)
            handlePanelIntent(intent)
        }
        presentPendingPracticeCleanup()
    }

    /// Enciende «¿era de prueba?» con el candado del Panel ya abierto (lo comprueba `drainPanelIfActive`, el único
    /// llamador). Lo arma el editor al guardar —`SetupChecklistManager.markFirstCreation`— con su hoja todavía arriba, y
    /// el Panel lo encendía en el acto: el `.alert` desmontaba el formulario de Nuevo registro antes de su pantalla de
    /// éxito (ticket `first-expense-practice-alert-tears-down-the-success-screen`). Ahora espera, como los intents, a
    /// que no quede ninguna hoja en la ventana; cerrarla re-drena y llega aquí.
    ///
    /// Si el intent que se acaba de drenar presentó algo, el aviso espera también a que esa hoja se cierre: dos
    /// presentaciones en la misma pasada se tumban entre sí.
    private func presentPendingPracticeCleanup() {
        let checklist = SetupChecklistManager.shared
        guard let pending = checklist.pendingPracticeCleanup else { return }
        guard !sheets.hasActivePresentation, !navigation.showNewTransactionFromChat else { return }
        sheets.practiceCleanupItem = pending
        checklist.pendingPracticeCleanup = nil
    }

    /// Una foto compartida que espera detrás de una hoja del Panel sin nada por guardar (la Bandeja, el registro por
    /// imagen en «elige una foto», el «?» de un widget) la cierra, y la lectura sale en cuanto UIKit termina de
    /// cerrarla: el cierre re-drena por `hasActivePresentation`, y mientras la hoja se va, el reintento de 300 ms. Cualquier
    /// otra hoja sigue esperando a la persona. Decide `SharedPhotoPanelSheetLogic` (decisión de Jürgen del 2026-10-12).
    private func closeDataFreeSheetForSharedPhoto() {
        let snapshot = SharedPhotoPanelSheetLogic.Snapshot(
            intent: AppRouter.shared.peekNext(for: .panel, in: navigation.id),
            selectedTab: navigation.selectedMainTab,
            shellBlocker: navigation.shellModalBlocker,
            mainTabModalVisible: navigation.isMainTabModalVisible,
            chatDraftFormOpen: navigation.showNewTransactionFromChat,
            onlyInboxOpen: sheets.isOnlyPresenting(\.showInbox),
            onlyImageEntryOpen: sheets.isOnlyPresenting(\.showImageSelection),
            imageEntryChoosing: navigation.isImageEntryChoosing,
            imageEntrySetupTrial: sheets.isImageSetupTrial,
            noPanelSheetFlag: !sheets.hasActivePresentation,
            cleanWidgetInfoVisible: navigation.isCleanPanelWidgetInfoVisible,
            presentationDepth: ModalPresentationProbe.presentationDepth(
                in: SceneRegistry.shared.windowScene(for: navigation.id))
        )
        switch SharedPhotoPanelSheetLogic.sheetToClose(snapshot) {
        case .inbox:
            sheets.showInbox = false
        case .imageEntryChoosing:
            sheets.showImageSelection = false
        case .widgetInfo:
            // Se baja aquí para no volver a pedirlo en cada reintento mientras la hoja se cierra.
            navigation.isCleanPanelWidgetInfoVisible = false
            navigation.panelWidgetInfoCloseRequest += 1
        case nil:
            return
        }
        #if DEBUG
        print("PanelShell: la foto compartida cierra una hoja del Panel sin nada por guardar")
        #endif
    }

    /// Cerrar una hoja de otra pestaña no cambia nada que el Panel observe, así que nadie re-drenaría: se vuelve a mirar
    /// cada 300 ms mientras siga retenido solo por eso. Un reintento a la vez; cada vuelta que siga retenida programa la
    /// siguiente desde `drainPanelIfActive`, y la última, la que drena, no programa nada.
    private func scheduleUnpublishedPresentationRedrain() {
        guard unpublishedPresentationRedrain == nil else { return }
        unpublishedPresentationRedrain = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return  // Cancelado: el Panel se desmontó o dejó de estar delante.
            }
            unpublishedPresentationRedrain = nil
            drainPanelIfActive()
        }
    }

    private func cancelUnpublishedPresentationRedrain() {
        unpublishedPresentationRedrain?.cancel()
        unpublishedPresentationRedrain = nil
    }

    /// Drain handler for `.panel` intents. Mutates `sheets` which drive the
    /// `.sheet(isPresented:)` bindings in PanelSheetsModifier.
    private func handlePanelIntent(_ intent: RouterIntent) {
        // Lo que este intent encadene va a ESTA ventana, la que lo drenó.
        SceneRegistry.shared.noteFocused(navigation.id)
        switch intent {
        case .presentInboxSheet:
            sheets.showInbox = true
        case .presentSharedImage(let url):
            // La imagen viaja en el intent: la deja en ESTA ventana, que es la que la va a abrir.
            navigation.pendingSharedImageURL = url
            sheets.showImageSelection = true
        case .presentNewTransaction:
            sheets.showNewTransaction = true
        case .presentNewTransactionFromChatDraft(let prefill):
            navigation.pendingChatDraftPrefill = prefill
            navigation.showNewTransactionFromChat = true
        case .presentVoiceEntry:
            sheets.showVoiceRecording = true
        case .presentImageEntry:
            sheets.showImageSelection = true
        case .presentUpgradeSheet(let feature):
            switch feature {
            case .voice:
                sheets.showUpgradeForVoice = true
            case .image:
                sheets.showUpgradeForImage = true
            case .accounts:
                sheets.showUpgradeForAccounts = true
            case .chat:
                sheets.showUpgradeForChat = true
            }
        case .requestAIConsent(let input):
            sheets.pendingAIInput = input
            sheets.showAIConsentAlert = true
        default:
            break  // Non-panel intents ignored (router shouldn't route them here).
        }
    }
}

/// Re-drena el Panel cuando un editor arma «¿era de prueba?». Va en su propio `ViewModifier` para no alargar la cadena
/// del `body` de `PanelShell` (límite del type-checker del CI, `.claude/rules/swiftui-ds.md`).
private struct PanelPracticeCleanupTrigger: ViewModifier {
    let onPending: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: SetupChecklistManager.shared.pendingPracticeCleanup?.id) { _, id in
                if id != nil { onPending() }
            }
    }
}
