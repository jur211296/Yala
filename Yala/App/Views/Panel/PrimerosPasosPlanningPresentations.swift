//
//  PrimerosPasosPlanningPresentations.swift
//  Yala
//
//  Los pasos 3, 4 y 5 de Primeros pasos 2.3, presentados desde el Panel (su mazo los abre): el primer presupuesto
//  (Y23-11), el primer pago planificado (Y23-12) y el onboarding de Grupos como página del tutorial (Y23-13), los tres a
//  pantalla completa. Al cerrarse, el mazo avanza (hecho u omitido) y la guía «dónde vive cada cosa» (Y23-15) dice dónde
//  quedó lo creado: presupuestos y pagos en Más; grupos en su pestaña, al volver al Panel. En su propio modificador para
//  no alargar la cadena de `PanelSheetsModifier`.
//

import SwiftData
import SwiftUI

struct PrimerosPasosPlanningPresentations: ViewModifier {
    @Binding var sheets: PanelSheetState
    let viewModel: PanelViewModel

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SceneNavigation.self) private var navigation
    @Environment(\.modelContext) private var modelContext

    /// Cómo terminó cada flujo, copiado antes de cerrar su pantalla: lo aplica su `onDismiss`.
    @State private var budgetResult: PrimerosPasosPlanningResult = .closed
    @State private var paymentResult: PrimerosPasosPlanningResult = .closed
    @State private var groupsExit: GroupsTutorialExitRecord?
    /// Se guardó algo en la pantalla abierta. Aquí y no dentro de ella: si su contenido se rehace antes de cerrarla, su
    /// estado nace de cero y «Atrás» contestaría «cerrado» con el presupuesto o el pago ya guardados.
    @State private var savedInFlow = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $sheets.showFirstBudgetFlow, onDismiss: afterBudget) { budgetFlow }
            .fullScreenCover(isPresented: $sheets.showFirstScheduledPaymentFlow, onDismiss: afterPayment) { paymentFlow }
            .fullScreenCover(isPresented: $sheets.showGroupsTutorial, onDismiss: afterGroups) { groupsFlow }
    }

    private var budgetFlow: some View {
        FirstBudgetFlowView(onSaved: { savedInFlow = true }) { result in
            budgetResult = result
            sheets.showFirstBudgetFlow = false
        }
    }

    private var paymentFlow: some View {
        FirstScheduledPaymentFlowView(onSaved: { savedInFlow = true }) { result in
            paymentResult = result
            sheets.showFirstScheduledPaymentFlow = false
        }
    }

    private var groupsFlow: some View {
        GroupsTutorialFlowView { exit, link in
            groupsExit = GroupsTutorialExitRecord(exit: exit, link: link)
            sheets.showGroupsTutorial = false
        }
    }

    // MARK: - Al cerrarse

    private func afterBudget() {
        let result = budgetResult
        budgetResult = .closed
        finish(.firstBudget, result: result, guide: .budgets)
    }

    private func afterPayment() {
        let result = paymentResult
        paymentResult = .closed
        finish(.scheduledPayment, result: result, guide: .scheduledPayments)
    }

    /// Hecho → el mazo avanza y, con el Panel ya asentado, la guía de Más. Omitido → el mazo avanza. Cerrado → sigue ahí.
    private func finish(_ step: SetupStepID, result: PrimerosPasosPlanningResult, guide: PlaceGuide) {
        viewModel.reloadAndRecalculate()
        let saved = savedInFlow
        savedInFlow = false
        switch saved ? .created : result {
        case .created:
            SetupChecklistManager.shared.markCompleted(step)
            startGuideSoon(guide)
        case .skipped:
            SetupChecklistManager.shared.markSkipped(step)
        case .closed:
            break
        }
    }

    /// Y23-13: la marca del onboarding y el paso 5 según cómo salió (`GroupsTutorialLogic`). Crear y unirse siguen por los
    /// caminos de siempre: el formulario de grupo en la pestaña Grupos (con su puerta de cuenta y consentimiento) y la
    /// unión por enlace.
    private func afterGroups() {
        guard let record = groupsExit else { return }
        groupsExit = nil
        if GroupsTutorialLogic.marksOnboardingSeen(record.exit) {
            seedSystemGroupCategoriesIfNeeded(in: modelContext)
            appPreferences.hasShownGroupsOnboarding = true
        }
        // El mazo pasa al 6; el grupo, cuando llegue, da el paso por hecho (`autoDetect` al volver al Panel).
        if GroupsTutorialLogic.advancesDeck(record.exit) {
            SetupChecklistManager.shared.markSkipped(.groups)
        }
        sheets.pendingGroupsPlaceGuide = GroupsTutorialLogic.showsPlaceGuide(record.exit)
        switch record.exit {
        case .createGroup:
            navigation.pendingNewGroupForm = true
            navigation.selectMainTab(.groups)
        case .joinWithLink:
            if let link = record.link { AppBootstrapper.shared.handleInviteLink(link) }
        case .closed, .skipped, .seenNotNow:
            break
        }
    }

    private func startGuideSoon(_ guide: PlaceGuide) {
        Task { @MainActor in
            // Que la pantalla termine de cerrarse y el Panel se asiente antes de oscurecerlo.
            do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
            PlaceGuideCenter.shared.start(guide)
        }
    }
}

/// Cómo terminó el tutorial de Grupos y, si se une, el enlace.
struct GroupsTutorialExitRecord: Equatable {
    let exit: GroupsTutorialLogic.Exit
    let link: URL?
}

/// La guía «Tus grupos, a un toque» (Y23-13), al volver al Panel tras ir a crear o a unirse a un grupo.
struct PrimerosPasosGroupsGuideObserver: ViewModifier {
    @Binding var sheets: PanelSheetState
    let isPageShown: Bool

    func body(content: Content) -> some View {
        content.onChange(of: isPageShown) { _, shown in showGuideIfPending(shown) }
    }

    private func showGuideIfPending(_ shown: Bool) {
        guard shown, sheets.pendingGroupsPlaceGuide else { return }
        sheets.pendingGroupsPlaceGuide = false
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
            PlaceGuideCenter.shared.start(.groups)
        }
    }
}
