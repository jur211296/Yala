//
//  ApplePayAutomationGuideView.swift
//  Yala
//
//  «Registrar con Apple Pay» como guía por pasos (`YalaStepGuide`, referencia del 2026-09-15). Hasta el 2026-10-02
//  era un carrusel de vídeo más en Tutoriales; es el único tutorial que se hace FUERA de Yala —en Atajos—, y por eso
//  el primero que pasa a la forma de la referencia (lo pidió Jürgen).
//
//  Lo que pone cada rasgo: los cuatro pasos y sus textos son los del tutorial; el primero abre Atajos y queda hecho al
//  abrirse; «Lo que vas a ver» es la captura de ese paso; la cabecera cuenta los pagos de Apple Pay que esperan en la
//  bandeja, que es la señal de que la automatización ya funciona.
//
//  Desde la auditoría UX 2.2 (lote 15, L15-9, opción C) los textos valen para el Atajos de iOS 26 y el de iOS 27 —en
//  27 «Automatización» dejó de ser una pestaña y vive en Biblioteca— y «Lo que vas a ver» son capturas de iOS 27
//  (`tutorial-applePay-stepN` en el catálogo de imágenes) en vez de los vídeos de iOS 26.
//

import SwiftData
import SwiftUI

struct ApplePayAutomationGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Borradores de Apple Pay sin aprobar: el dato vivo de la cabecera.
    @Query(filter: ApplePayAutomationGuideView.pendingApplePayDrafts)
    private var pendingDrafts: [InboxDraft]

    @State private var showSupport = false

    private let tutorial = Tutorial.applePay

    static let pendingApplePayDrafts: Predicate<InboxDraft> = {
        let source = DraftSourceType.applePay.rawValue
        let pending = DraftStatus.pending.rawValue
        return #Predicate<InboxDraft> { $0.sourceTypeRaw == source && $0.statusRaw == pending }
    }()

    var body: some View {
        YalaStepGuide(
            navigationTitle: tutorial.title,
            rootIdentifier: "applepay_guide_root",
            progressID: StepGuideProgressStore.applePay,
            header: StepGuideHeader(
                systemImage: tutorial.icon,
                tint: tutorial.color,
                title: tutorial.title,
                lines: [tutorial.introDescription, L10n.Tutorials.applePayPendingDrafts(pendingDrafts.count)]),
            steps: steps,
            guarantee: L10n.Tutorials.applePayGuarantee,
            successTitle: L10n.Action.done,
            onSuccess: finish,
            onStuck: { showSupport = true },
            preview: { activeIndex in screenshotPreview(for: activeIndex) })
        .sheet(isPresented: $showSupport) {
            SupportFormSheet()
        }
    }

    /// Los pasos del tutorial. El primero lleva su acción: abrir Atajos ES el paso, así que queda hecho si iOS
    /// abrió la app (sin Atajos instalada, `openURL` contesta que no y el paso sigue activo).
    private var steps: [StepGuideStep] {
        tutorial.steps.map { step in
            var guideStep = StepGuideStep(id: step.id, title: step.title, detail: step.description)
            if step.id == 0 {
                guideStep.action = StepGuideStep.Action(
                    title: L10n.Tutorials.applePayOpenShortcuts,
                    systemImage: "arrow.up.forward.app",
                    perform: { markDone in openShortcuts(then: markDone) })
            }
            return guideStep
        }
    }

    private func openShortcuts(then markDone: @escaping () -> Void) {
        guard let url = URL(string: "shortcuts://") else { return }
        openURL(url) { accepted in
            if accepted { markDone() }
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: tutorial.completionKey)
        dismiss()
    }

    // MARK: - Lo que vas a ver

    /// La captura del paso activo; con todos hechos, la del último.
    @ViewBuilder
    private func screenshotPreview(for activeIndex: Int?) -> some View {
        let allSteps = tutorial.steps
        if let step = (activeIndex.flatMap { allSteps.indices.contains($0) ? allSteps[$0] : nil }) ?? allSteps.last,
           let name = step.screenshotName, let image = UIImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 380)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .frame(maxWidth: .infinity)
                .accessibilityLabel(step.title)
                .accessibilityIdentifier("step_guide_preview")
        }
    }
}
